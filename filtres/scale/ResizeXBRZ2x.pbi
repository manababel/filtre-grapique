; ===== xBRZ 2x Resize (Multithread) =====


; --- Distance de couleur pondérée 32-bit (Expression pure, safe pour les conditions) ---
Procedure xbrz_Dist(c1, c2)
  Protected r , g , b
  r = (((c1 >> 16) & $FF) - ((c2 >> 16) & $FF)) * 306
  g = (((c1 >> 8) & $FF) - ((c2 >> 8) & $FF)) * 601
  b = ((c1 & $FF) - (c2 & $FF)) * 117
  r = Abs(r)
  g = Abs(g)
  b = Abs(b)
  ProcedureReturn ((r + g + b) >> 10)
EndProcedure

; --- Mélange linéaire de deux couleurs optimisé ---
Procedure.l xbrz_Mix50(c1.l, c2.l)
  Protected r, g, b
   
  ; Mélange direct des canaux décalés et division par 2 (>> 1)
  r = (((c1 >> 16) & $FF) + ((c2 >> 16) & $FF)) >> 1
  g = (((c1 >> 8)  & $FF) + ((c2 >> 8)  & $FF)) >> 1
  b = ((c1 & $FF) + (c2 & $FF)) >> 1
   
  ProcedureReturn (r << 16) | (g << 8) | b
EndProcedure

Procedure ResizeXBRZ2x_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
     
    Protected x, y
    Protected.i ym1, yp1, xm1, xp1
    Protected.l p1, p2, p3, p4, p5, p6, p7, p8, p9
    Protected.l e1, e2, e3, e4
   
    Protected *src.PixelArray32 = \addr[0]
    Protected *line_dst_top.PixelArray32
    Protected *line_dst_bottom.PixelArray32
    Protected.i pitch_dst = lg_dst ; Décalage d'une ligne en unités de pixels
    Protected.i idx_dst
     
    macro_calul_tread(ht_src)
     
    For y = thread_start To thread_stop - 1
      ; Gestion sécurisée des bords Y
      ym1 = y - 1 : If ym1 < 0 : ym1 = 0 : EndIf
      yp1 = y + 1 : If yp1 >= ht_src : yp1 = ht_src - 1 : EndIf
       
      ; Adresses des lignes cibles pour le bloc 2x2 de destination
      *line_dst_top    = \addr[1] + ((y * 2) * lg_dst << 2)
      *line_dst_bottom = *line_dst_top + (pitch_dst << 2)
      idx_dst = 0
       
      For x = 0 To lg_src - 1
        ; Gestion sécurisée des bords X
        xm1 = x - 1 : If xm1 < 0 : xm1 = 0 : EndIf
        xp1 = x + 1 : If xp1 >= lg_src : xp1 = lg_src - 1 : EndIf
         
        ; --- 1. Lecture de la grille 3x3 ---
        p1 = *src\pixel[ym1 * lg_src + xm1] : p2 = *src\pixel[ym1 * lg_src + x] : p3 = *src\pixel[ym1 * lg_src + xp1]
        p4 = *src\pixel[y   * lg_src + xm1] : p5 = *src\pixel[y   * lg_src + x] : p6 = *src\pixel[y   * lg_src + xp1]
        p7 = *src\pixel[yp1 * lg_src + xm1] : p8 = *src\pixel[yp1 * lg_src + x] : p9 = *src\pixel[yp1 * lg_src + xp1]

        ; Valeur par défaut (Pas de contour détecté)
        e1 = p5 : e2 = p5 : e3 = p5 : e4 = p5
         
        ; --- 2. Analyse des coins xBRZ ---
         
        ; Coin Haut-Gauche (e1)
        If xbrz_Dist(p4, p2) < xbrz_Dist(p5, p1)
          If xbrz_Dist(p5, p4) < xbrz_Dist(p5, p2) : e1 = xbrz_Mix50(p5, p4) : Else : e1 = xbrz_Mix50(p5, p2) : EndIf
        EndIf
         
        ; Coin Haut-Droit (e2)
        If xbrz_Dist(p2, p6) < xbrz_Dist(p5, p3)
          If xbrz_Dist(p5, p2) < xbrz_Dist(p5, p6) : e2 = xbrz_Mix50(p5, p2) : Else : e2 = xbrz_Mix50(p5, p6) : EndIf
        EndIf
         
        ; Coin Bas-Gauche (e3)
        If xbrz_Dist(p8, p4) < xbrz_Dist(p5, p7)
          If xbrz_Dist(p5, p8) < xbrz_Dist(p5, p4) : e3 = xbrz_Mix50(p5, p8) : Else : e3 = xbrz_Mix50(p5, p4) : EndIf
        EndIf
         
        ; Coin Bas-Droit (e4)
        If xbrz_Dist(p6, p8) < xbrz_Dist(p5, p9)
          If xbrz_Dist(p5, p6) < xbrz_Dist(p5, p8) : e4 = xbrz_Mix50(p5, p6) : Else : e4 = xbrz_Mix50(p5, p8) : EndIf
        EndIf

        ; --- 3. Écriture directe via tableau de structure ---
        *line_dst_top\pixel[idx_dst]         = e1
        *line_dst_top\pixel[idx_dst + 1]     = e2
        *line_dst_bottom\pixel[idx_dst]      = e3
        *line_dst_bottom\pixel[idx_dst + 1]  = e4
         
        ; On avance de 2 sous-pixels sur la ligne de destination
        idx_dst + 2
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeXBRZ2xEx(*FilterCtx.FilterParams)
  Restore ResizeXBRZ2x_data
  Protected last_data = Filter_InitAndValidate(1) 
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeXBRZ2x_sp())
EndProcedure

; ===== Appel simplifié =====
Procedure ResizeXBRZ2x(source, cible)
  Set_Source(source)
  Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = ImageWidth(source) * 2
    \image_ht[1] = ImageHeight(source) * 2
  EndWith
  ResizeXBRZ2xEx(FilterCtx)
EndProcedure

DataSection
  ResizeXBRZ2x_data:
  Data.s "ResizeXBRZ2x"
  Data.s "xBRZ lissage 2x (Rapide)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 1
; Folding = -
; EnableXP
; DPIAware