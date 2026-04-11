; -------------------------------------------------------------------------------
; Translate_MT - Translation (déplacement) d'image avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: décalage horizontal (0-200%, 100=neutre)
;                  - option[1]: décalage vertical (0-200%, 100=neutre)
;                  - option[2]: mode de gestion des bords (0=wrap, 1=transparent)
;
; Description:
;   Déplace l'image horizontalement et/ou verticalement.
;   Mode wrap (0) : l'image se répète (effet de bouclage)
;   Mode transparent (1) : zones vides remplies en noir transparent
;
; Optimisations:
;   - Précalcul des décalages en pixels
;   - Utilisation d'offsets directs pour accès mémoire
;   - Gestion optimisée du mode wrap avec modulo
;   - Calcul incrémental des offsets destination
; -------------------------------------------------------------------------------
Procedure Translate_MT(*p.parametre)
  Protected x.i, y.i
  Protected src_x.i, src_y.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul des décalages en pixels (centré sur 100%)
  ; 0-99 : décalage négatif, 100 : neutre, 101-200 : décalage positif
  Protected dx.i = ((*p\option[0] - 100) * lg) / 100
  Protected dy.i = ((*p\option[1] - 100) * ht) / 100

  ; Mode de gestion des bords (0=wrap/bouclage, 1=transparent)
  Protected mode.i = *p\option[2]

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
      ; Calcul de la position source (inverse du déplacement)
      src_x = x - dx
      src_y = y - dy

      ; Vérification des limites
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ; Position source valide : échantillonnage direct
        offset_src = (src_y * lg + src_x) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))
      Else
        ; Position source hors limites
        If mode
          ; Mode transparent : remplir en noir transparent
          PokeL(*cible + offset_dst, $00000000)
        Else
          ; Mode wrap : bouclage de l'image (effet de répétition)
          ; Normalisation des coordonnées avec modulo
          If src_x >= lg : src_x = src_x % lg : EndIf
          If src_x < 0   : src_x = (src_x % lg) + lg : EndIf
          If src_y >= ht : src_y = src_y % ht : EndIf
          If src_y < 0   : src_y = (src_y % ht) + ht : EndIf
          
          ; Échantillonnage avec coordonnées bouclées
          offset_src = (src_y * lg + src_x) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        EndIf
      EndIf

      offset_dst + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; Translate - Filtre de translation (déplacement) d'image
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Déplace l'image horizontalement et/ou verticalement avec deux modes
;   de gestion des bords :
;   - Mode wrap (bouclage) : l'image se répète pour remplir les zones vides
;   - Mode transparent : les zones vides sont remplies en noir transparent
;
; Paramètres utilisateur:
;   [0] Décalage horizontal (0-200%, défaut=100)
;       0-99  : déplacement vers la gauche
;       100   : pas de déplacement
;       101-200: déplacement vers la droite
;   [1] Décalage vertical (0-200%, défaut=100)
;       0-99  : déplacement vers le haut
;       100   : pas de déplacement
;       101-200: déplacement vers le bas
;   [2] Mode de gestion des bords (0=wrap/bouclage, 1=transparent, défaut=1)
;
; Utilisations:
;   - Recadrage d'image
;   - Création de textures seamless (mode wrap)
;   - Ajustement de composition
;   - Animation de défilement
; -------------------------------------------------------------------------------
Procedure Translate(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Translate (Translation)"
    *param\remarque = "Déplacement de l'image avec mode wrap ou transparent"
    
    *param\info[0] = "Décalage X (0-99=gauche, 100=neutre, 101-200=droite)"
    *param\info[1] = "Décalage Y (0-99=haut, 100=neutre, 101-200=bas)"
    *param\info[2] = "Mode bords (0=wrap/bouclage, 1=transparent)"
    *param\info[3] = "masque"
    
    ; Configuration décalage X (0-200%, défaut 100 = neutre)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 200
    *param\info_data(0, 2) = 100
    
    ; Configuration décalage Y (0-200%, défaut 100 = neutre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 200
    *param\info_data(1, 2) = 100
    
    ; Configuration mode (0=wrap, 1=transparent, défaut 1)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 1
    *param\info_data(2, 2) = 1
    
    ; Configuration du masque
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 2
    *param\info_data(3, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (3 paramètres + masque = 4, 1 buffer destination)
  filter_start(@Translate_MT(), 3, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 151
; FirstLine = 82
; Folding = -
; EnableXP
; DPIAware