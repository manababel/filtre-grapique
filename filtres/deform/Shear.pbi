; -------------------------------------------------------------------------------
; Shear_MT - Cisaillement (déformation oblique) avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: cisaillement horizontal (0-200, 100=neutre)
;                  - option[1]: cisaillement vertical (0-200, 100=neutre)
;                  - option[2]: point d'ancrage X (0-100%, 50=centre)
;                  - option[3]: point d'ancrage Y (0-100%, 50=centre)
;
; Description:
;   Applique une déformation de cisaillement (shear) transformant l'image
;   en parallélogramme. Le cisaillement horizontal décale les lignes,
;   le cisaillement vertical décale les colonnes.
;
; Optimisations:
;   - Précalcul des facteurs de cisaillement
;   - Précalcul du point d'ancrage
;   - Utilisation d'offsets directs pour accès mémoire
;   - Calcul incrémental des offsets destination
; -------------------------------------------------------------------------------
Procedure Shear_MT(*p.parametre)
  Protected x.i, y.i
  Protected src_x.i, src_y.i
  Protected offset_x.f, offset_y.f
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul des facteurs de cisaillement (centré sur 100)
  ; 0-99 : cisaillement négatif, 100 : neutre, 101-200 : cisaillement positif
  ; Plage finale : -1.0 à +1.0
  Protected shear_x.f = (*p\option[0] - 100.0) / 100.0
  Protected shear_y.f = (*p\option[1] - 100.0) / 100.0

  ; Précalcul du point d'ancrage (point fixe de la transformation)
  Protected anchor_x.f = (*p\option[2] / 100.0) * lg
  Protected anchor_y.f = (*p\option[3] / 100.0) * ht

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected dy.f  ; Distance verticale depuis l'ancrage

  ; Traitement pixel par pixel
  For y = startY To stopY
    ; Précalcul de la distance verticale (constant pour toute la ligne)
    dy = y - anchor_y
    
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Calcul de la position source avec cisaillement
      ; Le cisaillement horizontal déplace en X proportionnellement à la distance en Y
      ; Le cisaillement vertical déplace en Y proportionnellement à la distance en X
      offset_x = shear_x * dy
      offset_y = shear_y * (x - anchor_x)
      
      src_x = x - Int(offset_x)
      src_y = y - Int(offset_y)

      ; Vérification des limites et échantillonnage
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ; Échantillonnage du pixel source
        offset_src = (src_y * lg + src_x) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))
      Else
        ; Pixel hors limites = noir transparent
        PokeL(*cible + offset_dst, $00000000)
      EndIf

      offset_dst + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; Shear - Filtre de cisaillement (déformation oblique)
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une transformation de cisaillement (shear) qui déforme l'image
;   en parallélogramme. Utile pour créer des effets de perspective simple,
;   d'italique, ou de déformation géométrique contrôlée.
;
; Paramètres utilisateur:
;   [0] Cisaillement horizontal (0-200, défaut=100)
;       0-99  : cisaillement vers la gauche
;       100   : pas de cisaillement
;       101-200: cisaillement vers la droite
;       Effet : les lignes se décalent horizontalement
;   [1] Cisaillement vertical (0-200, défaut=100)
;       0-99  : cisaillement vers le haut
;       100   : pas de cisaillement
;       101-200: cisaillement vers le bas
;       Effet : les colonnes se décalent verticalement
;   [2] Point d'ancrage X (0-100%, défaut=50% = centre)
;       Point horizontal qui reste fixe pendant la transformation
;   [3] Point d'ancrage Y (0-100%, défaut=50% = centre)
;       Point vertical qui reste fixe pendant la transformation
;
; Utilisations:
;   - Effet de perspective simple (fausse 3D)
;   - Texte italique ou oblique
;   - Correction de distorsion trapézoïdale
;   - Effets artistiques de déformation
;   - Transformation affine partielle
;
; Note mathématique:
;   Transformation de cisaillement :
;   x' = x + shear_x × (y - anchor_y)
;   y' = y + shear_y × (x - anchor_x)
; -------------------------------------------------------------------------------
Procedure Shear(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Shear (Cisaillement)"
    *param\remarque = "Déformation en parallélogramme avec cisaillement horizontal et/ou vertical"
    
    *param\info[0] = "Cisaillement X (0-99=gauche, 100=neutre, 101-200=droite)"
    *param\info[1] = "Cisaillement Y (0-99=haut, 100=neutre, 101-200=bas)"
    *param\info[2] = "Ancrage X (% largeur)"
    *param\info[3] = "Ancrage Y (% hauteur)"
    *param\info[4] = "masque"
    
    ; Configuration cisaillement X (0-200, défaut 100 = neutre)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 200
    *param\info_data(0, 2) = 100
    
    ; Configuration cisaillement Y (0-200, défaut 100 = neutre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 200
    *param\info_data(1, 2) = 100
    
    ; Configuration ancrage X (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration ancrage Y (0-100%, défaut 50% = centre)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 100
    *param\info_data(3, 2) = 50
    
    ; Configuration du masque
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 2
    *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (4 paramètres, 1 buffer destination)
  filter_start(@Shear_MT(), 4, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 121
; FirstLine = 26
; Folding = -
; EnableXP
; DPIAware