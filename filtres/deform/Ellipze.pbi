; -------------------------------------------------------------------------------
; Ellipse_MT - Déformation elliptique (lentille) avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: force de déformation (0-600, 200=neutre)
;                  - option[1]: position X du centre (0-100%, 50=centre)
;                  - option[2]: position Y du centre (0-100%, 50=centre)
;                  - option[3]: rayon horizontal (0-100% de la largeur)
;                  - option[4]: rayon vertical (0-100% de la hauteur)
;
; Description:
;   Applique une déformation elliptique simulant une lentille ovale.
;   Similaire à Spherize mais avec des rayons indépendants en X et Y.
;   Force < 200 : effet concave (pincement)
;   Force = 200 : pas de déformation
;   Force > 200 : effet convexe (bombement)
;
; Optimisations:
;   - Précalcul du centre et des rayons
;   - Précalcul des inverses de rayons pour normalisation
;   - Utilisation d'offsets directs pour accès mémoire
;   - Calcul optimisé de la distance elliptique normalisée
;   - Test précoce pour pixels hors zone d'effet
; -------------------------------------------------------------------------------
Procedure Ellipse_MT(*p.parametre)
  Protected x.i, y.i
  Protected dx.f, dy.f, r.f
  Protected facteur.f, sqrt_r.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul du centre de l'effet
  Protected cx.f = (*p\option[1] / 100.0) * lg
  Protected cy.f = (*p\option[2] / 100.0) * ht

  ; Précalcul des rayons elliptiques en pixels
  Protected rayon_x.f = (lg * *p\option[3] / 100.0) + 10.0
  Protected rayon_y.f = (ht * *p\option[4] / 100.0) + 10.0

  ; Précalcul des inverses pour éviter divisions répétées
  Protected inv_rayon_x.f = 1.0 / rayon_x
  Protected inv_rayon_y.f = 1.0 / rayon_y

  ; Précalcul de la force de déformation (centré sur 200)
  ; force < 0 : concave, force = 0 : neutre, force > 0 : convexe
  Protected force.f = (*p\option[0] - 200.0) / 100.0

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Calcul de la position relative au centre, normalisée par les rayons
      dx = (x - cx) * inv_rayon_x
      dy = (y - cy) * inv_rayon_y

      ; Distance normalisée dans l'espace elliptique (r² au lieu de r pour optimisation)
      r = dx * dx + dy * dy

      ; Application de la déformation seulement dans l'ellipse (r ≤ 1)
      If r <= 1.0
        ; Calcul de la racine carrée de r pour l'angle
        sqrt_r = Sqr(r)
        
        ; Calcul du facteur de déplacement avec contrôle de force
        ; Sin(sqrt(r) * π/2) crée une transition douce du centre vers les bords
        facteur = Pow(Sin(sqrt_r * #PI * 0.5), 1.0 + force)
        
        ; Calcul des coordonnées source déformées (retour aux coordonnées absolues)
        src_x = cx + dx * rayon_x * facteur
        src_y = cy + dy * rayon_y * facteur
      Else
        ; Hors zone d'effet : pas de déformation
        src_x = x
        src_y = y
      EndIf

      ; Conversion en entiers et vérification des limites
      src_x_int = Int(src_x)
      src_y_int = Int(src_y)

      If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
        ; Échantillonnage du pixel source
        offset_src = (src_y_int * lg + src_x_int) * 4
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
; Ellipze - Filtre de déformation elliptique (lentille ovale)
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une déformation elliptique simulant une lentille optique ovale.
;   Extension de Spherize avec contrôle indépendant des rayons horizontal
;   et vertical, permettant des déformations non-circulaires.
;
; Paramètres utilisateur:
;   [0] Force de déformation (0-600, défaut=200)
;       0-199 : effet concave (pincement)
;       200   : pas de déformation
;       201-600: effet convexe (bombement)
;   [1] Position X du centre (0-100%, défaut=50% = centre)
;   [2] Position Y du centre (0-100%, défaut=50% = centre)
;   [3] Rayon horizontal (0-100% de la largeur, défaut=50%)
;   [4] Rayon vertical (0-100% de la hauteur, défaut=50%)
;
; Utilisations:
;   - Effet loupe ovale
;   - Correction de distorsion anamorphique
;   - Effets artistiques de déformation
;   - Simulation de lentilles cylindriques
; -------------------------------------------------------------------------------
Procedure Ellipze(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Ellipze (Déformation elliptique)"
    *param\remarque = "Lentille elliptique avec rayons horizontal et vertical indépendants"
    
    *param\info[0] = "Force (0-199=concave, 200=neutre, 201-600=convexe)"
    *param\info[1] = "Centre X (% largeur)"
    *param\info[2] = "Centre Y (% hauteur)"
    *param\info[3] = "Rayon X (% largeur)"
    *param\info[4] = "Rayon Y (% hauteur)"
    *param\info[5] = "masque"
    
    ; Configuration force (0-600, défaut 200 = neutre)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 600
    *param\info_data(0, 2) = 200
    
    ; Configuration centre X (0-100%, défaut 50% = centre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Configuration centre Y (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration rayon X (0-100% de la largeur, défaut 50%)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 100
    *param\info_data(3, 2) = 50
    
    ; Configuration rayon Y (0-100% de la hauteur, défaut 50%)
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 100
    *param\info_data(4, 2) = 50
    
    ; Configuration du masque
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 2
    *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (5 paramètres, 1 buffer destination)
  filter_start(@Ellipse_MT(), 5, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 187
; FirstLine = 118
; Folding = -
; EnableXP
; DPIAware