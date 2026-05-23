; ===== Nearest Neighbor Resize (multithread) =====
Procedure ResizeNearest_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0] ; Largeur source
    Protected ht_src = \image_ht[0] ; Hauteur source
    Protected lg_dst = \image_lg[1] ; Largeur cible (définie dans le contexte)
    Protected ht_dst = \image_ht[1] ; Hauteur cible
    
    Protected x, y, pos
    Protected src_x, src_y
    Protected *srcPix.Pixel32, *dstPix.Pixel32
    
    ; Calcul des ratios de redimensionnement
    Protected ratioX.f = lg_src / lg_dst
    Protected ratioY.f = ht_src / ht_dst
    
    ; Le multithreading s'applique sur la hauteur de l'image de DESTINATION
    macro_calul_tread(ht_dst)
    
    For y = thread_start To thread_stop - 1
      ; On calcule la coordonnée Y source une seule fois par ligne
      src_y = Int(y * ratioY)
      
      ; Sécurité clamping vertical
      If src_y < 0 : src_y = 0 : ElseIf src_y >= ht_src : src_y = ht_src - 1 : EndIf
      
      For x = 0 To lg_dst - 1
        ; Calcul de la coordonnée X source
        src_x = Int(x * ratioX)
        
        ; Sécurité clamping horizontal
        If src_x < 0 : src_x = 0 : ElseIf src_x >= lg_src : src_x = lg_src - 1 : EndIf
        
        ; --- Lecture du pixel source ---
        pos = (src_y * lg_src + src_x) << 2
        *srcPix = \addr[0] + pos
        
        ; --- Écriture dans la destination ---
        pos = (y * lg_dst + x) << 2
        *dstPix = \addr[1] + pos
        *dstPix\l = *srcPix\l
      Next
    Next
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeNearestEx(*FilterCtx.FilterParams)
  Restore ResizeNearest_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeNearest_sp())
EndProcedure

; ===== Appel simplifié =====
Procedure ResizeNearest(source, cible, lg, ht)
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = lg
    \image_ht[1] = ht
  EndWith
  ResizeNearestEx(FilterCtx)
EndProcedure

DataSection
  ResizeNearest_data:
  Data.s "ResizeNearest"
  Data.s "Redimensionnement Plus Proche Voisin"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Largeur Cible"
  Data.i 1, 4096, 800
  Data.s "Hauteur Cible"
  Data.i 1, 4096, 600
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 69
; FirstLine = 20
; Folding = -
; EnableXP
; DPIAware