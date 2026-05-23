; --- Comparaison de similarité hq4x ---
Procedure.i hq4x_IsSame(c1.l, c2.l, thresh=30)
  If Abs(Red(c1)-Red(c2)) < thresh And Abs(Green(c1)-Green(c2)) < thresh And Abs(Blue(c1)-Blue(c2)) < thresh
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; --- Mélange pondéré (75/25) pour des transitions plus douces ---
Procedure.l hq4x_Mix(c1.l, c2.l, ratio.f = 0.5)
  Protected r = Red(c1)*(1-ratio) + Red(c2)*ratio
  Protected g = Green(c1)*(1-ratio) + Green(c2)*ratio
  Protected b = Blue(c1)*(1-ratio) + Blue(c2)*ratio
  ProcedureReturn RGB(r, g, b)
EndProcedure

Procedure ResizeHq4x_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0], ht_src = \image_ht[0]
    Protected lg_dst = lg_src * 4
    Protected x, y, i, j
    Protected.l w1, w2, w3, w4, w5, w6, w7, w8, w9
    Protected base_pos, dst_pitch = lg_dst << 2
    
    macro_calul_tread(ht_src)
    
    For y = thread_start To thread_stop - 1
      ; Clamping vertical
      ;Protected ym1 = Max(0, y-1), yp1 = Min(ht_src-1, y+1)
      
      For x = 0 To lg_src - 1
        ; Clamping horizontal
        ;Protected xm1 = Max(0, x-1), xp1 = Min(lg_src-1, x+1)
        
        ; Lecture des 9 voisins (P5 est le centre)
        ;w1 = PeekL(\addr[0] + ((ym1 * lg_src + xm1) << 2)) : w2 = PeekL(\addr[0] + ((ym1 * lg_src + x) << 2)) : w3 = PeekL(\addr[0] + ((ym1 * lg_src + xp1) << 2))
        ;w4 = PeekL(\addr[0] + ((y * lg_src + xm1) << 2))   : w5 = PeekL(\addr[0] + ((y * lg_src + x) << 2))   : w6 = PeekL(\addr[0] + ((y * lg_src + xp1) << 2))
        ;w7 = PeekL(\addr[0] + ((yp1 * lg_src + xm1) << 2)) : w8 = PeekL(\addr[0] + ((yp1 * lg_src + x) << 2)) : w9 = PeekL(\addr[0] + ((yp1 * lg_src + xp1) << 2))

        ; Grille 4x4 de destination par défaut (16 pixels)
        Protected.l Dim e(16)
        For i = 1 To 16 : e(i) = w5 : Next
        
        ; --- Logique Simplifiée hq4x ---
        ; Analyse des diagonales pour lisser les bords
        ; Si les voisins haut/gauche sont identiques entre eux mais différents du centre
        If hq4x_IsSame(w2, w4) And Not hq4x_IsSame(w2, w8) And Not hq4x_IsSame(w4, w6)
           Protected m = hq4x_Mix(w5, w2, 0.5)
           e(1) = m : e(2) = m : e(5) = m ; Coin haut-gauche plus doux
        EndIf
        
        If hq4x_IsSame(w2, w6) And Not hq4x_IsSame(w2, w8) And Not hq4x_IsSame(w6, w4)
           Protected m2 = hq4x_Mix(w5, w2, 0.5)
           e(3) = m2 : e(4) = m2 : e(8) = m2 ; Coin haut-droit
        EndIf
        
        If hq4x_IsSame(w8, w4) And Not hq4x_IsSame(w8, w2) And Not hq4x_IsSame(w4, w6)
           Protected m3 = hq4x_Mix(w5, w8, 0.5)
           e(9) = m3 : e(13) = m3 : e(14) = m3 ; Coin bas-gauche
        EndIf
        
        If hq4x_IsSame(w8, w6) And Not hq4x_IsSame(w8, w2) And Not hq4x_IsSame(w6, w4)
           Protected m4 = hq4x_Mix(w5, w8, 0.5)
           e(12) = m4 : e(15) = m4 : e(16) = m4 ; Coin bas-droit
        EndIf

        ; --- Écriture du bloc 4x4 ---
        base_pos = ((y * 4 * lg_dst) + (x * 4)) << 2
        For j = 0 To 3
          Protected line_offset = j * dst_pitch
          For i = 0 To 3
            PokeL(\addr[1] + base_pos + line_offset + (i << 2), e(j * 4 + i + 1))
          Next
        Next
        
      Next
    Next
  EndWith
EndProcedure
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 40
; FirstLine = 25
; Folding = -
; EnableXP
; DPIAware