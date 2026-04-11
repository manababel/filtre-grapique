; -------------------------------------------------------------------------------
; Wave_MT - Ondulation linéaire (sinusoïdale) avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: amplitude de l'onde en pixels (0-100)
;                  - option[1]: longueur d'onde en pixels (1-500)
;                  - option[2]: direction (0=horizontal, 1=vertical, 2=les deux)
;                  - option[3]: phase en degrés (0-360°)
;                  - option[4]: type d'onde (0=sinus, 1=carré, 2=triangle, 3=dents de scie)
;
; Description:
;   Applique une ondulation sinusoïdale linéaire dans une direction spécifique.
;   Contrairement à Ripple qui déforme dans les deux directions simultanément,
;   Wave déforme dans une seule direction à la fois (ou les deux séparément).
;
; Optimisations:
;   - Précalcul des facteurs de normalisation
;   - Précalcul de la phase en radians
;   - Précalcul de l'inverse de la longueur d'onde
;   - Utilisation d'offsets directs pour accès mémoire
;   - Sélection optimisée du type d'onde
; -------------------------------------------------------------------------------
Procedure Wave_MT(*p.parametre)
  Protected x.i, y.i
  Protected offset_x.f, offset_y.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul de l'amplitude de l'onde
  Protected amplitude.f = *p\option[0]

  ; Précalcul de la longueur d'onde avec protection
  Protected wavelength.f = *p\option[1]
  If wavelength < 1.0 : wavelength = 1.0 : EndIf
  Protected inv_wavelength.f = (2.0 * #PI) / wavelength

  ; Direction de l'onde (0=horizontal, 1=vertical, 2=les deux)
  Protected direction.i = *p\option[2]

  ; Phase en radians
  Protected phase.f = (*p\option[3] / 360.0) * 2.0 * #PI

  ; Type d'onde (0=sinus, 1=carré, 2=triangle, 3=dents de scie)
  Protected wave_type.i = *p\option[4]

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected t.f, wave_value.f
  Protected frac_part.f

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      offset_x = 0
      offset_y = 0

      ; Direction horizontale (déplace verticalement selon X)
      If direction = 0 Or direction = 2
        t = x * inv_wavelength + phase
        
        ; Sélection du type d'onde
        Select wave_type
          Case 0  ; Sinusoïde (par défaut)
            wave_value = Sin(t)
            
          Case 1  ; Onde carrée
            wave_value = Sin(t)
            If wave_value >= 0
              wave_value = 1.0
            Else
              wave_value = -1.0
            EndIf
            
          Case 2  ; Onde triangulaire
            frac_part = (t / (2.0 * #PI)) - Int(t / (2.0 * #PI))
            If frac_part < 0 : frac_part + 1.0 : EndIf
            If frac_part < 0.25
              wave_value = frac_part * 4.0
            ElseIf frac_part < 0.75
              wave_value = 1.0 - (frac_part - 0.25) * 4.0
            Else
              wave_value = -1.0 + (frac_part - 0.75) * 4.0
            EndIf
            
          Case 3  ; Dents de scie
            frac_part = (t / (2.0 * #PI)) - Int(t / (2.0 * #PI))
            If frac_part < 0 : frac_part + 1.0 : EndIf
            wave_value = frac_part * 2.0 - 1.0
            
        EndSelect
        
        offset_y = amplitude * wave_value
      EndIf

      ; Direction verticale (déplace horizontalement selon Y)
      If direction = 1 Or direction = 2
        t = y * inv_wavelength + phase
        
        ; Sélection du type d'onde
        Select wave_type
          Case 0  ; Sinusoïde
            wave_value = Sin(t)
            
          Case 1  ; Onde carrée
            wave_value = Sin(t)
            If wave_value >= 0
              wave_value = 1.0
            Else
              wave_value = -1.0
            EndIf
            
          Case 2  ; Onde triangulaire
            frac_part = (t / (2.0 * #PI)) - Int(t / (2.0 * #PI))
            If frac_part < 0 : frac_part + 1.0 : EndIf
            If frac_part < 0.25
              wave_value = frac_part * 4.0
            ElseIf frac_part < 0.75
              wave_value = 1.0 - (frac_part - 0.25) * 4.0
            Else
              wave_value = -1.0 + (frac_part - 0.75) * 4.0
            EndIf
            
          Case 3  ; Dents de scie
            frac_part = (t / (2.0 * #PI)) - Int(t / (2.0 * #PI))
            If frac_part < 0 : frac_part + 1.0 : EndIf
            wave_value = frac_part * 2.0 - 1.0
            
        EndSelect
        
        offset_x = amplitude * wave_value
      EndIf

      ; Calcul des coordonnées source
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
; Wave - Filtre d'ondulation linéaire
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une ondulation linéaire (sinusoïdale ou autre) dans une direction
;   spécifique. Contrairement à Ripple qui crée des ondulations dans les deux
;   axes simultanément, Wave permet de contrôler précisément la direction et
;   offre plusieurs types de formes d'onde.
;
; Paramètres utilisateur:
;   [0] Amplitude (0-100 pixels, défaut=10)
;       Hauteur des vagues en pixels
;   [1] Longueur d'onde (1-500 pixels, défaut=50)
;       Distance entre deux crêtes de vague
;       Valeurs faibles : ondulations rapprochées
;       Valeurs élevées : ondulations espacées
;   [2] Direction (0-2, défaut=0)
;       0 : Horizontale - vagues horizontales (déplace verticalement)
;       1 : Verticale - vagues verticales (déplace horizontalement)
;       2 : Les deux - ondulations croisées
;   [3] Phase (0-360°, défaut=0)
;       Décalage initial de l'onde (utile pour animation)
;   [4] Type d'onde (0-3, défaut=0)
;       0 : Sinusoïde - onde douce et naturelle
;       1 : Carrée - transitions abruptes
;       2 : Triangulaire - montées/descentes linéaires
;       3 : Dents de scie - rampe progressive puis chute
;
; Utilisations:
;   - Effet de drapeau flottant (horizontal, sinus)
;   - Effet de rideau (vertical, sinus)
;   - Distorsion de chaleur/mirage (horizontal, faible amplitude)
;   - Effet de surface d'eau (horizontal, sinus)
;   - Glitch artistique (carré ou scie)
;   - Effet de vibration (faible amplitude, courte longueur d'onde)
;   - Animation de textures (variation de phase)
;
; Différences avec Ripple:
;   - Ripple : ondulations dans les 2 axes, période en % de l'image
;   - Wave : ondulation dans 1 axe au choix, longueur d'onde en pixels absolus
;   - Wave : 4 types d'onde différents (sinus, carré, triangle, scie)
;
; Exemples de paramètres:
;   Drapeau doux:
;     Amplitude=15, Longueur=80, Direction=0, Type=0 (sinus)
;   
;   Effet glitch:
;     Amplitude=30, Longueur=20, Direction=0, Type=1 (carré)
;   
;   Surface d'eau:
;     Amplitude=5, Longueur=60, Direction=0, Type=0 (sinus), Phase=variable
;
; Note: Pour créer une animation, variez le paramètre Phase de 0 à 360°.
; -------------------------------------------------------------------------------
Procedure Wave(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Wave (Ondulation linéaire)"
    *param\remarque = "Ondulation directionnelle avec différents types de formes d'onde"
    
    *param\info[0] = "Amplitude (pixels)"
    *param\info[1] = "Longueur d'onde (pixels)"
    *param\info[2] = "Direction (0=horiz, 1=vert, 2=les deux)"
    *param\info[3] = "Phase (degrés, pour animation)"
    *param\info[4] = "Type (0=sinus, 1=carré, 2=triangle, 3=scie)"
    *param\info[5] = "masque"
    
    ; Configuration amplitude (0-100 pixels, défaut 10)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 100
    *param\info_data(0, 2) = 10
    
    ; Configuration longueur d'onde (1-500 pixels, défaut 50)
    *param\info_data(1, 0) = 1
    *param\info_data(1, 1) = 500
    *param\info_data(1, 2) = 50
    
    ; Configuration direction (0-2, défaut 0 = horizontal)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 2
    *param\info_data(2, 2) = 0
    
    ; Configuration phase (0-360°, défaut 0)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 360
    *param\info_data(3, 2) = 0
    
    ; Configuration type d'onde (0-3, défaut 0 = sinus)
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 3
    *param\info_data(4, 2) = 0
    
    ; Configuration du masque
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 2
    *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (5 paramètres, 1 buffer destination)
  filter_start(@Wave_MT(), 5, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 224
; FirstLine = 206
; Folding = -
; EnableXP
; DPIAware