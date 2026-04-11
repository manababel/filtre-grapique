; -------------------------------------------------------------------------------
; Spherize_MT - Effet de sphérisation (lentille convexe/concave)
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: force de déformation (0-600, 100=neutre, <100=concave, >100=convexe)
;                  - option[1]: position X du centre (0-100%, 50=centre)
;                  - option[2]: position Y du centre (0-100%, 50=centre)
;                  - option[3]: rayon d'effet (0-100% de la diagonale)
;
; Description:
;   Applique une déformation sphérique simulant une lentille optique.
;   Force < 100 : effet concave (pincement)
;   Force = 100 : pas de déformation
;   Force > 100 : effet convexe (bombement)
;
; Optimisations:
;   - Précalcul du centre et du rayon normalisé
;   - Précalcul de l'inverse du rayon pour normalisation
;   - Utilisation d'offsets directs pour accès mémoire
;   - Test précoce pour pixels hors zone d'effet
; -------------------------------------------------------------------------------
Procedure Spherize_MT(*p.parametre)
  Protected x.i, y.i
  Protected dx.f, dy.f, r.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul du centre de l'effet
  Protected cx.f = (*p\option[1] / 100.0) * lg
  Protected cy.f = (*p\option[2] / 100.0) * ht

  ; Précalcul du rayon d'effet (en pixels, basé sur la diagonale)
  Protected diagonale.f = Sqr(lg * lg + ht * ht)
  Protected rayon.f = (diagonale * *p\option[3] / 100.0) + 1.0
  Protected inv_rayon.f = 1.0 / rayon  ; Précalcul pour éviter divisions

  ; Précalcul de la force de déformation (centré sur 100)
  ; force < 0 : concave, force = 0 : neutre, force > 0 : convexe
  Protected force.f = (*p\option[0] - 100.0) / 100.0

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected angle.f, facteur.f
  Protected offset_dst.i, offset_src.i

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Calcul de la position relative au centre, normalisée par le rayon
      dx = (x - cx) * inv_rayon
      dy = (y - cy) * inv_rayon

      ; Distance au centre (normalisée)
      r = Sqr(dx * dx + dy * dy)

      ; Application de la déformation seulement dans le rayon d'effet
      If r <= 1.0
        ; Calcul de l'angle de déformation (0 au centre, π/2 au bord)
        angle = r * #PI * 0.5
        
        ; Calcul du facteur de déplacement avec contrôle de force
        facteur = Pow(Sin(angle), 1.0 + force)
        
        ; Calcul des coordonnées source déformées
        src_x = cx + dx * facteur * rayon
        src_y = cy + dy * facteur * rayon
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
; Spherize - Filtre de sphérisation (effet lentille)
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une déformation sphérique simulant une lentille optique.
;   Permet de créer des effets de bombement (convexe) ou de pincement (concave).
;
; Paramètres utilisateur:
;   [0] Force de déformation (0-600, défaut=100)
;       0-99   : effet concave (pincement)
;       100    : pas de déformation
;       101-600: effet convexe (bombement)
;   [1] Position X du centre (0-100%, défaut=50% = centre)
;   [2] Position Y du centre (0-100%, défaut=50% = centre)
;   [3] Rayon d'effet (0-100% de la diagonale, défaut=50%)
;
; Utilisations:
;   - Effet loupe ou fish-eye
;   - Correction de distorsion optique
;   - Effets artistiques de déformation
;   - Simulation de lentilles sphériques
; -------------------------------------------------------------------------------
Procedure Spherize(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Spherize (Sphérisation)"
    *param\remarque = "Effet lentille convexe ou concave avec contrôle de force"
    
    *param\info[0] = "Force (0-99=concave, 100=neutre, 101-600=convexe)"
    *param\info[1] = "Centre X (% largeur)"
    *param\info[2] = "Centre Y (% hauteur)"
    *param\info[3] = "Rayon (% diagonale)"
    *param\info[4] = "masque"
    
    ; Configuration force (0-600, défaut 100 = neutre)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 600
    *param\info_data(0, 2) = 100
    
    ; Configuration centre X (0-100%, défaut 50% = centre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Configuration centre Y (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration rayon (0-100% de la diagonale, défaut 50%)
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
  filter_start(@Spherize_MT(), 4, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 172
; FirstLine = 103
; Folding = -
; EnableXP
; DPIAware