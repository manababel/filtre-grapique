; ===== Seam Carving : Calcul de l'Énergie (Gradient de Sobel) =====
Procedure SeamCarving_Energy_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y, gx, gy
    Protected *p.Pixel32, *pL.Pixel32, *pR.Pixel32, *pU.Pixel32, *pD.Pixel32
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        ; On calcule l'énergie uniquement si on n'est pas sur le bord extrême
        If x > 0 And x < lg - 1 And y > 0 And y < ht - 1
          ; Voisins : L (Left), R (Right), U (Up), D (Down)
          *pL = \addr[0] + ((y * lg + (x - 1)) << 2)
          *pR = \addr[0] + ((y * lg + (x + 1)) << 2)
          ;gx = Abs(*pL\r - *pR\r) + Abs(*pL\g - *pR\g) + Abs(*pL\b - *pR\b)
          
          *pU = \addr[0] + (((y - 1) * lg + x) << 2)
          *pD = \addr[0] + (((y + 1) * lg + x) << 2)
          ;gy = Abs(*pU\r - *pD\r) + Abs(*pU\g - *pD\g) + Abs(*pU\b - *pD\b)
          
          ; Énergie normalisée sur 255 pour visualisation
          Protected energy = (gx + gy) / 3
          If energy > 255 : energy = 255 : EndIf
          
          *p = \addr[1] + ((y * lg + x) << 2)
          ;*p\r = energy : *p\g = energy : *p\b = energy : *p\a = 255
        Else
          ; Bords mis à zéro (ou énergie max pour éviter de les couper)
          *p = \addr[1] + ((y * lg + x) << 2)
          *p\l = 0
        EndIf
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure SeamCarving_EnergyEx(*FilterCtx.FilterParams)
  Restore SeamCarving_Energy_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  ; On appelle bien le thread dédié à l'énergie
  Create_MultiThread_MT(@SeamCarving_Energy_sp())
EndProcedure

; ===== Appel =====
Procedure SeamCarving_Energy(source, cible)
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    ; Pour l'énergie, la taille de destination est identique à la source
    \image_lg[1] = \image_lg[0]
    \image_ht[1] = \image_ht[0]
  EndWith
  SeamCarving_EnergyEx(FilterCtx)
EndProcedure

DataSection
  SeamCarving_Energy_data:
  Data.s "SeamCarving_Energy"
  Data.s "Seam Carving (Analyse d'Importance)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Seuil" : Data.i 0, 255, 128 ; Paramètre inutile ici mais garde la structure
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 28
; FirstLine = 4
; Folding = -
; EnableXP
; DPIAware