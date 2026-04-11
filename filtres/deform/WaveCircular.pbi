; -------------------------------------------------------------------------------
; WaveCircular_MT - Ondulations circulaires concentriques avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: amplitude de l'onde en pixels (0-100)
;                  - option[1]: position X du centre (0-100%, 50=centre)
;                  - option[2]: position Y du centre (0-100%, 50=centre)
;                  - option[3]: longueur d'onde (1-100% de la diagonale)
;                  - option[4]: phase de l'onde en degrés (0-360°)
;
; Description:
;   Applique des ondulations circulaires concentriques partant d'un point central.
;   Les pixels sont déplacés radialement selon une fonction sinusoïdale,
;   créant un effet de vagues se propageant depuis le centre.
;
; Optimisations:
;   - Précalcul du centre et des constantes d'onde
;   - Précalcul de la phase en radians
;   - Précalcul de l'inverse de la longueur d'onde
;   - Utilisation d'offsets directs pour accès mémoire
;   - Test précoce pour éviter division par zéro au centre
; -------------------------------------------------------------------------------
Procedure WaveCircular_MT(*p.parametre)
  Protected x.i, y.i
  Protected dx.f, dy.f, r.f
  Protected offset.f, displacement_factor.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul du centre de l'effet
  Protected cx.f = (*p\option[1] / 100.0) * lg
  Protected cy.f = (*p\option[2] / 100.0) * ht

  ; Précalcul de l'amplitude de l'onde
  Protected amplitude.f = *p\option[0]

  ; Précalcul de la longueur d'onde en pixels (basée sur la diagonale)
  Protected diagonale.f = Sqr(lg * lg + ht * ht)
  Protected wavelength.f = (*p\option[3] / 100.0) * diagonale
  
  ; Protection contre division par zéro et précalcul de l'inverse
  If wavelength < 0.1 : wavelength = 0.1 : EndIf
  Protected inv_wavelength.f = (2.0 * #PI) / wavelength

  ; Précalcul de la phase en radians
  Protected phase.f = (*p\option[4] / 360.0) * 2.0 * #PI

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected inv_r.f  ; Inverse de r pour éviter division répétée

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Calcul de la position relative au centre
      dx = x - cx
      dy = y - cy

      ; Distance au centre
      r = Sqr(dx * dx + dy * dy)

      ; Application de l'ondulation radiale
      If r > 0.001  ; Évite division par zéro au centre
        ; Calcul du décalage radial selon une sinusoïde
        offset = amplitude * Sin(r * inv_wavelength + phase)
        
        ; Facteur de déplacement radial (1 + offset/r)
        inv_r = 1.0 / r
        displacement_factor = 1.0 + offset * inv_r
        
        ; Nouvelle position déformée (déplacement radial)
        src_x = cx + dx * displacement_factor
        src_y = cy + dy * displacement_factor
      Else
        ; Au centre exact : pas de déformation
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
; WaveCircular - Filtre d'ondulations circulaires
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Crée des ondulations circulaires concentriques partant d'un point central.
;   L'effet simule des vagues se propageant radialement, comme des rides
;   à la surface de l'eau après l'impact d'une goutte.
;
; Paramètres utilisateur:
;   [0] Amplitude de l'onde en pixels (0-100, défaut=10)
;       Plus l'amplitude est élevée, plus les déformations sont prononcées
;   [1] Position X du centre (0-100%, défaut=50% = centre)
;   [2] Position Y du centre (0-100%, défaut=50% = centre)
;   [3] Longueur d'onde (1-100% de la diagonale, défaut=20%)
;       Contrôle l'espacement entre les vagues
;   [4] Phase de l'onde en degrés (0-360°, défaut=0°)
;       Décale le motif d'ondulation (utile pour animation)
;
; Utilisations:
;   - Effet de goutte d'eau
;   - Ondulations sonores/radar
;   - Effets de perturbation radiale
;   - Animation de propagation d'onde
; -------------------------------------------------------------------------------
Procedure WaveCircular(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Wave Circular (Ondulations circulaires)"
    *param\remarque = "Ondulations concentriques avec contrôle d'amplitude, longueur d'onde et phase"
    
    *param\info[0] = "Amplitude (pixels)"
    *param\info[1] = "Centre X (% largeur)"
    *param\info[2] = "Centre Y (% hauteur)"
    *param\info[3] = "Longueur d'onde (% diagonale)"
    *param\info[4] = "Phase (degrés)"
    *param\info[5] = "masque"
    
    ; Configuration amplitude (0-100 pixels, défaut 10)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 100
    *param\info_data(0, 2) = 10
    
    ; Configuration centre X (0-100%, défaut 50% = centre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Configuration centre Y (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration longueur d'onde (1-100% de la diagonale, défaut 20%)
    *param\info_data(3, 0) = 1
    *param\info_data(3, 1) = 100
    *param\info_data(3, 2) = 20
    
    ; Configuration phase (0-360°, défaut 0°)
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 360
    *param\info_data(4, 2) = 0
    
    ; Configuration du masque
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 2
    *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (5 paramètres, 1 buffer destination)
  filter_start(@WaveCircular_MT(), 5, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 188
; FirstLine = 119
; Folding = -
; EnableXP
; DPIAware