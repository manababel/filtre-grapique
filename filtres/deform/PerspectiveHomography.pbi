
; -------------------------------------------------------------------------------
; DrawTexturePerspective_MT - Transformation perspective avec homographie
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0-1]: coin haut-gauche (X, Y) en % décalage
;                  - option[2-3]: coin haut-droit (X, Y)
;                  - option[4-5]: coin bas-droit (X, Y)
;                  - option[6-7]: coin bas-gauche (X, Y)
;
; Description:
;   Applique une transformation perspective complète utilisant une matrice
;   d'homographie 3x3. Plus précis que l'interpolation bilinéaire pour les
;   déformations importantes.
;
; Algorithme:
;   1. Calcule les 4 coins destination à partir des options
;   2. Construit la matrice d'homographie inverse
;   3. Pour chaque pixel destination, calcule la position source
;   4. Échantillonne le pixel source
;
; Optimisations:
;   - Précalcul complet de la matrice d'homographie
;   - Test de déterminant pour éviter division par zéro
;   - Calcul incrémental des offsets
; -------------------------------------------------------------------------------
Procedure DrawTexturePerspective_MT(*p.parametre)
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht
  Protected *source = *p\addr[0]  
  Protected *cible  = *p\addr[1]  
  Protected x.i, y.i

  ; Précalcul des constantes
  Protected half_lg.f = lg * 0.5
  Protected half_ht.f = ht * 0.5
  Protected lg_max.f = lg - 1
  Protected ht_max.f = ht - 1

  ; Calcul des 4 coins destination à partir des options (en % de décalage)
  Protected x0.f = ((*p\option[0] - 50.0) / 50.0) * half_lg + 0.0
  Protected y0.f = ((*p\option[1] - 50.0) / 50.0) * half_ht + 0.0
  Protected x1.f = ((*p\option[2] - 50.0) / 50.0) * half_lg + lg_max
  Protected y1.f = ((*p\option[3] - 50.0) / 50.0) * half_ht + 0.0
  Protected x2.f = ((*p\option[4] - 50.0) / 50.0) * half_lg + lg_max
  Protected y2.f = ((*p\option[5] - 50.0) / 50.0) * half_ht + ht_max
  Protected x3.f = ((*p\option[6] - 50.0) / 50.0) * half_lg + 0.0
  Protected y3.f = ((*p\option[7] - 50.0) / 50.0) * half_ht + ht_max

  ; Construction de l'homographie inverse
  ; Basé sur la transformation projective de 4 points
  Protected dx1.f = x1 - x2
  Protected dx2.f = x3 - x2
  Protected dx3.f = x0 - x1 + x2 - x3
  Protected dy1.f = y1 - y2
  Protected dy2.f = y3 - y2
  Protected dy3.f = y0 - y1 + y2 - y3

  ; Calcul du déterminant
  Protected det.f = dx1 * dy2 - dx2 * dy1
  
  ; Vérification de la validité de la transformation
  If Abs(det) < 0.0001
    ; Transformation dégénérée : copie simple
    For y = 0 To ht - 1
      CopyMemory(*source + y * lg * 4, *cible + y * lg * 4, lg * 4)
    Next y
    ProcedureReturn
  EndIf

  ; Coefficients de la transformation
  Protected a13.f = (dx3 * dy2 - dx2 * dy3) / det
  Protected a23.f = (dx1 * dy3 - dx3 * dy1) / det

  ; Matrice d'homographie inverse [H⁻¹]
  Protected h11.f = x1 - x0 + a13 * x1
  Protected h12.f = x3 - x0 + a23 * x3
  Protected h13.f = x0
  Protected h21.f = y1 - y0 + a13 * y1
  Protected h22.f = y3 - y0 + a23 * y3
  Protected h23.f = y0
  Protected h31.f = a13
  Protected h32.f = a23
  Protected h33.f = 1.0

  ; Calcul de la portion de lignes à traiter
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de transformation
  Protected denom.f, u.f, v.f
  Protected u_int.i, v_int.i
  Protected offset_dst.i, offset_src.i

  ; Application de la transformation inverse
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Transformation homographique inverse : (x,y) → (u,v)
      denom = h31 * x + h32 * y + h33

      If Abs(denom) > 0.0001
        u = (h11 * x + h12 * y + h13) / denom
        v = (h21 * x + h22 * y + h23) / denom

        ; Vérification des limites et échantillonnage
        u_int = Int(u)
        v_int = Int(v)

        If u_int >= 0 And u_int < lg And v_int >= 0 And v_int < ht
          offset_src = (v_int * lg + u_int) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $FF000000)  ; Noir opaque
        EndIf
      Else
        PokeL(*cible + offset_dst, $FF000000)  ; Noir opaque
      EndIf

      offset_dst + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; PerspectiveHomography - Filtre de perspective avec homographie complète
;
; Description:
;   Version avancée avec transformation homographique précise.
;   Recommandé pour les déformations importantes.
; -------------------------------------------------------------------------------
Procedure PerspectiveHomography(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0;"Géométrique avancée"
    *param\name = "Perspective Homographique"
    *param\remarque = "Transformation perspective précise (matrice 3x3)"
    
    *param\info[0] = "Coin haut-gauche X (%)"
    *param\info[1] = "Coin haut-gauche Y (%)"
    *param\info[2] = "Coin haut-droit X (%)"
    *param\info[3] = "Coin haut-droit Y (%)"
    *param\info[4] = "Coin bas-droit X (%)"
    *param\info[5] = "Coin bas-droit Y (%)"
    *param\info[6] = "Coin bas-gauche X (%)"
    *param\info[7] = "Coin bas-gauche Y (%)"

    For i = 0 To 7
      *param\info_data(i, 0) = 0
      *param\info_data(i, 1) = 100
      *param\info_data(i, 2) = 50
    Next i

    ProcedureReturn
  EndIf

  filter_start(@DrawTexturePerspective_MT(), 8, 1)
EndProcedure


; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 30
; FirstLine = 69
; Folding = -
; EnableXP
; DPIAware