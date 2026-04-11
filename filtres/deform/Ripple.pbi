; -------------------------------------------------------------------------------
; Ripple_MT - Déformation sinusoïdale (ondulation) avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: amplitude horizontale en pixels (0-100)
;                  - option[1]: période horizontale en % de la hauteur (1-100%)
;                  - option[2]: amplitude verticale en pixels (0-100)
;                  - option[3]: période verticale en % de la largeur (1-100%)
;
; Description:
;   Applique une déformation sinusoïdale (effet d'ondulation) à l'image.
;   L'onde horizontale se propage verticalement (déplace les pixels sur X).
;   L'onde verticale se propage horizontalement (déplace les pixels sur Y).
;
; Optimisations:
;   - Précalcul des facteurs de normalisation
;   - Précalcul des constantes trigonométriques
;   - Utilisation d'offsets directs pour accès mémoire
;   - Évitement des divisions répétées
;   - Protection contre division par zéro sur les périodes
; -------------------------------------------------------------------------------
Procedure Ripple_MT(*p.parametre)
  Protected x.i, y.i
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul des amplitudes (conversion directe en float)
  Protected amp_x.f = *p\option[0]
  Protected amp_y.f = *p\option[2]

  ; Précalcul des périodes avec protection contre division par zéro
  Protected period_x.f = (*p\option[1] / 100.0) * ht
  Protected period_y.f = (*p\option[3] / 100.0) * lg
  
  If period_x < 0.1 : period_x = 0.1 : EndIf  ; Évite division par zéro
  If period_y < 0.1 : period_y = 0.1 : EndIf

  ; Précalcul des facteurs de normalisation pour la fonction sinus
  Protected inv_period_x.f = (2.0 * #PI) / period_x
  Protected inv_period_y.f = (2.0 * #PI) / period_y

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_x.f, offset_y.f
  Protected offset_dst.i, offset_src.i
  Protected y_sin_factor.f  ; Précalcul du facteur sinus pour Y (constant sur la ligne)

  ; Traitement pixel par pixel
  For y = startY To stopY
    ; Précalcul de l'offset horizontal pour cette ligne (économise calculs répétés)
    y_sin_factor = y * inv_period_x
    offset_x = amp_x * Sin(y_sin_factor)
    
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Calcul de l'offset vertical pour cette colonne
      offset_y = amp_y * Sin(x * inv_period_y)

      ; Calcul des coordonnées source avec déplacement sinusoïdal
      src_x = x + offset_x
      src_y = y + offset_y

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
; Ripple - Filtre de déformation sinusoïdale (ondulation)
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique un effet d'ondulation sinusoïdale à l'image.
;   Permet de créer des vagues horizontales et/ou verticales.
;
; Paramètres utilisateur:
;   [0] Amplitude horizontale en pixels (0-100, défaut=0)
;   [1] Période horizontale en % de la hauteur (1-100%, défaut=1%)
;   [2] Amplitude verticale en pixels (0-100, défaut=0)
;   [3] Période verticale en % de la largeur (1-100%, défaut=1%)
;
; Utilisations:
;   - Effet de drapeau flottant
;   - Simulation d'ondulations aquatiques
;   - Distorsions artistiques
;   - Effet de chaleur/mirage
; -------------------------------------------------------------------------------
Procedure Ripple(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Ripple (Ondulation)"
    *param\remarque = "Déformation sinusoïdale créant un effet d'ondulation"
    
    *param\info[0] = "Amplitude horizontale (pixels)"
    *param\info[1] = "Période horizontale (% hauteur)"
    *param\info[2] = "Amplitude verticale (pixels)"
    *param\info[3] = "Période verticale (% largeur)"
    *param\info[4] = "masque"
    
    *param\info_data(0, 0) = 0 : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 0
    *param\info_data(2, 0) = 0 : *param\info_data(2, 1) = 100 : *param\info_data(2, 2) = 0
    *param\info_data(1, 0) = 1 : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 1
    *param\info_data(3, 0) = 1 : *param\info_data(3, 1) = 100 : *param\info_data(3, 2) = 1
    *param\info_data(4, 0) = 0 : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (4 pour le masque, 1 nombre de thread)
  filter_start(@Ripple_MT(), 4, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 129
; FirstLine = 70
; Folding = -
; EnableXP
; DPIAware