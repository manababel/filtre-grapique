; --- Helper pour comparer les couleurs (Seuil de perception) ---
Procedure.i hq3x_IsDiff(c1.l, c2.l)
  Protected r = Abs(Red(c1)-Red(c2))
  Protected g = Abs(Green(c1)-Green(c2))
  Protected b = Abs(Blue(c1)-Blue(c2))
  If r > 32 Or g > 32 Or b > 32 : ProcedureReturn 1 : EndIf
  ProcedureReturn 0
EndProcedure

; --- Mélange de 2 couleurs (50/50) ---
Procedure.l hq3x_Mix(c1.l, c2.l)
  Protected r = (Red(c1) + Red(c2)) >> 1
  Protected g = (Green(c1) + Green(c2)) >> 1
  Protected b = (Blue(c1) + Blue(c2)) >> 1
  ProcedureReturn RGB(r, g, b)
EndProcedure

Procedure ResizeHq3x_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = lg_src * 3
    Protected x, y, dx, dy
    Protected *dst.Pixel32
    
    ; Voisins (Matrice 3x3)
    Protected.l w1, w2, w3, w4, w5, w6, w7, w8, w9
    
    ; On travaille sur la hauteur source pour générer 3 lignes de destination d'un coup
    macro_calul_tread(ht_src)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg_src - 1
        
        ; 1. Lecture des 9 voisins (clamping simplifié)
        Protected xm1 = x - 1 : If xm1 < 0 : xm1 = 0 : EndIf
        Protected xp1 = x + 1 : If xp1 >= lg_src : xp1 = lg_src - 1 : EndIf
        Protected ym1 = y - 1 : If ym1 < 0 : ym1 = 0 : EndIf
        Protected yp1 = y + 1 : If yp1 >= ht_src : yp1 = ht_src - 1 : EndIf
        
        w1 = PeekL(\addr[0] + ((ym1 * lg_src + xm1) << 2)) : w2 = PeekL(\addr[0] + ((ym1 * lg_src + x) << 2))   : w3 = PeekL(\addr[0] + ((ym1 * lg_src + xp1) << 2))
        w4 = PeekL(\addr[0] + ((y * lg_src + xm1) << 2))   : w5 = PeekL(\addr[0] + ((y * lg_src + x) << 2))     : w6 = PeekL(\addr[0] + ((y * lg_src + xp1) << 2))
        w7 = PeekL(\addr[0] + ((yp1 * lg_src + xm1) << 2)) : w8 = PeekL(\addr[0] + ((yp1 * lg_src + x) << 2))   : w9 = PeekL(\addr[0] + ((yp1 * lg_src + xp1) << 2))

        ; 2. Calcul des 9 pixels de destination (Grille 3x3)
        ; Par défaut, tout est égal au pixel central
        Protected.l e1=w5, e2=w5, e3=w5, e4=w5, e5=w5, e6=w5, e7=w5, e8=w5, e9=w5
        
        ; 3. Logique de détection de bords (Simplification de la table hq3x)
        ; Si on détecte une diagonale, on lisse les coins
        If hq3x_IsDiff(w4, w6) And hq3x_IsDiff(w2, w8)
          ; Coin Haut-Gauche
          If hq3x_IsDiff(w1, w5) And hq3x_IsDiff(w4, w2) : e1 = hq3x_Mix(w4, w2) : EndIf
          ; Coin Haut-Droit
          If hq3x_IsDiff(w3, w5) And hq3x_IsDiff(w2, w6) : e3 = hq3x_Mix(w2, w6) : EndIf
          ; Coin Bas-Gauche
          If hq3x_IsDiff(w7, w5) And hq3x_IsDiff(w4, w8) : e7 = hq3x_Mix(w4, w8) : EndIf
          ; Coin Bas-Droit
          If hq3x_IsDiff(w9, w5) And hq3x_IsDiff(w8, w6) : e9 = hq3x_Mix(w8, w6) : EndIf
        EndIf
        
        ; 4. Écriture dans le buffer destination
        ; On calcule l'adresse du bloc 3x3 correspondant dans la destination
        Protected base_pos = ((y * 3 * lg_dst) + (x * 3)) << 2
        
        ; Ligne 1 du bloc
        PokeL(\addr[1] + base_pos, e1)
        PokeL(\addr[1] + base_pos + 4, e2)
        PokeL(\addr[1] + base_pos + 8, e3)
        ; Ligne 2 du bloc
        PokeL(\addr[1] + base_pos + (lg_dst << 2), e4)
        PokeL(\addr[1] + base_pos + (lg_dst << 2) + 4, e5)
        PokeL(\addr[1] + base_pos + (lg_dst << 2) + 8, e6)
        ; Ligne 3 du bloc
        PokeL(\addr[1] + base_pos + (lg_dst * 2 << 2), e7)
        PokeL(\addr[1] + base_pos + (lg_dst * 2 << 2) + 4, e8)
        PokeL(\addr[1] + base_pos + (lg_dst * 2 << 2) + 8, e9)
        
      Next
    Next
  EndWith
EndProcedure
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 17
; Folding = -
; EnableXP
; DPIAware