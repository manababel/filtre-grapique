; ===== 2xSaI Resize (Multithread) =====

; Macro pour mélanger deux couleurs 32-bit (ARGB)
Macro Resize2xSaI_Interpolate2(c1, c2)
  ((((c1 & $FF00FF) + (c2 & $FF00FF)) >> 1) & $FF00FF) | (((((c1 & $FF00FF00) >> 8) + ((c2 & $FF00FF00) >> 8)) >> 1) << 8)
EndMacro

; Macro pour 4 couleurs en une seule fois
Macro Resize2xSaI_Interpolate4(c1, c2, c3, c4)
  ((((c1 & $FF00FF) + (c2 & $FF00FF) + (c3 & $FF00FF) + (c4 & $FF00FF)) >> 2) & $FF00FF) | (((((c1 & $FF00FF00) >> 8) + ((c2 & $FF00FF00) >> 8) + ((c3 & $FF00FF00) >> 8) + ((c4 & $FF00FF00) >> 8)) >> 2) << 8)
EndMacro

Procedure Resize2xSaI_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    Protected x, y, pos1, pos_dst
    Protected.l colorA, colorB, colorC, colorD, colorE, colorF, colorG, colorH, colorI
    Protected p1, p2, p3, p4
    Protected.i next_row_dst = lg_dst ; Précalcul pour la deuxième ligne du bloc 2x2
    
    ; [I][A][B]
    ; [G][E][F]  <- E est le pixel courant
    ; [H][D][C]
    
    macro_calul_tread(ht_src) ; Définit thread_start et thread_stop
    
    For y = thread_start To thread_stop - 1
      ; Optimisation : On précalcule le départ de la ligne de destination
      pos_dst = (y * 2 * lg_dst) 
      
      For x = 0 To lg_src - 1
        pos1 = (y * lg_src) + x
        colorE = *src\pixel[pos1]
        
        ; --- Lecture sécurisée du voisinage 3x3 avec protection des limites ---
        
        ; Ligne Supérieure (A, B)
        If y > 0
          colorA = *src\pixel[pos1 - lg_src]
          If x < lg_src - 1
            colorB = *src\pixel[pos1 - lg_src + 1]
          Else
            colorB = colorE
          EndIf
        Else
          colorA = colorE
          colorB = colorE
        EndIf
        
        ; Ligne Centrale (F, G)
        If x < lg_src - 1
          colorF = *src\pixel[pos1 + 1]
        Else
          colorF = colorE
        EndIf
        
        If x > 0
          colorG = *src\pixel[pos1 - 1]
        Else
          colorG = colorE
        EndIf
        
        ; Ligne Inférieure (D)
        If y < ht_src - 1
          colorD = *src\pixel[pos1 + lg_src]
        Else
          colorD = colorE
        EndIf
        
        ; 2. Logique de décision de l'algorithme 2xSaI
        If colorE = colorD And colorG <> colorF
          ; Diagonale descendante détectée
          If (colorE = colorA And colorE = colorB) Or (colorG = colorA)
            p1 = colorE
          Else
            p1 = Resize2xSaI_Interpolate2(colorE, colorA)
          EndIf
          p4 = colorE
          p2 = Resize2xSaI_Interpolate2(colorE, colorF)
          p3 = Resize2xSaI_Interpolate2(colorE, colorG)
          
        ElseIf colorG = colorF And colorE <> colorD
          ; Diagonale montante détectée
          p1 = Resize2xSaI_Interpolate2(colorE, colorG)
          p2 = colorG
          p3 = colorG
          p4 = Resize2xSaI_Interpolate2(colorG, colorD)
          
        ElseIf colorE = colorD And colorG = colorF
          ; Intersection de lignes ou zone unie
          p1 = colorE
          p2 = Resize2xSaI_Interpolate2(colorE, colorF)
          p3 = Resize2xSaI_Interpolate2(colorE, colorG)
          p4 = colorD
          
        Else
          ; Rendu standard (Bilinéaire local)
          p1 = colorE
          p2 = Resize2xSaI_Interpolate2(colorE, colorF)
          p3 = Resize2xSaI_Interpolate2(colorE, colorG)
          p4 = Resize2xSaI_Interpolate4(colorE, colorF, colorG, colorD)
        EndIf

        ; 3. Écriture ultra-rapide du bloc 2x2 dans la destination
        ; Ligne haute du bloc 2x2
        *dst\pixel[pos_dst]     = p1 ; Haut-Gauche
        *dst\pixel[pos_dst + 1] = p2 ; Haut-Droite
        
        ; Ligne basse du bloc 2x2 (utilisation de next_row_dst évite une multiplication)
        *dst\pixel[pos_dst + next_row_dst]     = p3 ; Bas-Gauche
        *dst\pixel[pos_dst + next_row_dst + 1] = p4 ; Bas-Droite
        
        ; On avance de 2 pixels en destination pour le prochain itération de X
        pos_dst + 2
        
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure resize2xSaIEx(*FilterCtx.FilterParams)
  Restore Resize2xSaI_data
  Protected last_data = Filter_InitAndValidate(1) ; 1 => Tailles différentes
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@Resize2xSaI_sp())
EndProcedure

; ===== Appel =====
Procedure resize2xSaI(source, cible)
  Set_Source(source)
  Set_Cible(cible)
  Resize2xSaIEx(FilterCtx)
EndProcedure

DataSection
  Resize2xSaI_data:
  Data.s "resize2xSaI"
  Data.s "2xSaI (Smooth Interpolation)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 90
; FirstLine = 74
; Folding = -
; EnableXP
; DPIAware