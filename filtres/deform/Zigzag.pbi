; -------------------------------------------------------------------------------
; Zigzag_MT - Déformation en zigzag (dents de scie) avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: amplitude du zigzag en pixels (0-100)
;                  - option[1]: nombre de zigzags (1-100)
;                  - option[2]: direction (0=horizontal, 1=vertical, 2=diagonal /, 3=diagonal \)
;                  - option[3]: forme (0=dents de scie, 1=triangle symétrique, 2=créneaux)
;                  - option[4]: lissage des angles (0-100, 0=angles vifs, 100=arrondi)
;
; Description:
;   Applique une déformation en zigzag avec des angles vifs ou arrondis.
;   Contrairement à Wave qui utilise des fonctions trigonométriques,
;   Zigzag crée des motifs géométriques anguleux.
;
; Optimisations:
;   - Précalcul de la taille de chaque segment
;   - Précalcul des facteurs de forme
;   - Utilisation d'offsets directs pour accès mémoire
;   - Calcul optimisé du motif en dents de scie
; -------------------------------------------------------------------------------
Procedure Zigzag_MT(*p.parametre)
  Protected x.i, y.i
  Protected offset_x.f, offset_y.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul de l'amplitude du zigzag
  Protected amplitude.f = *p\option[0]

  ; Nombre de zigzags avec protection
  Protected zigzag_count.i = *p\option[1]
  If zigzag_count < 1 : zigzag_count = 1 : EndIf

  ; Direction du zigzag (0=horiz, 1=vert, 2=diag/, 3=diag\)
  Protected direction.i = *p\option[2]

  ; Forme (0=dents de scie, 1=triangle, 2=créneaux)
  Protected shape.i = *p\option[3]

  ; Lissage (0-100)
  Protected smoothing.f = *p\option[4] / 100.0

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected position.f, segment_size.f
  Protected normalized_pos.f, zigzag_value.f
  Protected progress.f, smooth_factor.f

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      offset_x = 0
      offset_y = 0

      ; Sélection de la direction
      Select direction
        Case 0  ; ===== Horizontal (vagues horizontales) =====
          ; Position le long de l'axe X
          position = x
          segment_size = lg / zigzag_count
          
          ; Normalisation de la position dans [0, zigzag_count]
          normalized_pos = (position / segment_size)
          
          ; Calcul du zigzag selon la forme
          Select shape
            Case 0  ; Dents de scie (rampe montante)
              progress = normalized_pos - Int(normalized_pos)
              zigzag_value = progress
              
            Case 1  ; Triangle symétrique
              progress = normalized_pos - Int(normalized_pos)
              If progress < 0.5
                zigzag_value = progress * 2.0
              Else
                zigzag_value = 2.0 - progress * 2.0
              EndIf
              
            Case 2  ; Créneaux (carrés)
              progress = normalized_pos - Int(normalized_pos)
              If progress < 0.5
                zigzag_value = 0.0
              Else
                zigzag_value = 1.0
              EndIf
              
          EndSelect
          
          ; Application du lissage
          If smoothing > 0
            smooth_factor = Sin(zigzag_value * #PI)
            zigzag_value = zigzag_value * (1.0 - smoothing) + smooth_factor * smoothing
          EndIf
          
          ; Conversion en déplacement (-1 à +1)
          zigzag_value = zigzag_value * 2.0 - 1.0
          offset_y = amplitude * zigzag_value
          
        Case 1  ; ===== Vertical (vagues verticales) =====
          position = y
          segment_size = ht / zigzag_count
          normalized_pos = (position / segment_size)
          
          Select shape
            Case 0  ; Dents de scie
              progress = normalized_pos - Int(normalized_pos)
              zigzag_value = progress
              
            Case 1  ; Triangle
              progress = normalized_pos - Int(normalized_pos)
              If progress < 0.5
                zigzag_value = progress * 2.0
              Else
                zigzag_value = 2.0 - progress * 2.0
              EndIf
              
            Case 2  ; Créneaux
              progress = normalized_pos - Int(normalized_pos)
              If progress < 0.5
                zigzag_value = 0.0
              Else
                zigzag_value = 1.0
              EndIf
              
          EndSelect
          
          If smoothing > 0
            smooth_factor = Sin(zigzag_value * #PI)
            zigzag_value = zigzag_value * (1.0 - smoothing) + smooth_factor * smoothing
          EndIf
          
          zigzag_value = zigzag_value * 2.0 - 1.0
          offset_x = amplitude * zigzag_value
          
        Case 2  ; ===== Diagonal / (bas-gauche vers haut-droite) =====
          position = x + y
          segment_size = (lg + ht) / zigzag_count
          normalized_pos = (position / segment_size)
          
          Select shape
            Case 0
              progress = normalized_pos - Int(normalized_pos)
              zigzag_value = progress
            Case 1
              progress = normalized_pos - Int(normalized_pos)
              If progress < 0.5
                zigzag_value = progress * 2.0
              Else
                zigzag_value = 2.0 - progress * 2.0
              EndIf
            Case 2
              progress = normalized_pos - Int(normalized_pos)
              If progress < 0.5
                zigzag_value = 0.0
              Else
                zigzag_value = 1.0
              EndIf
          EndSelect
          
          If smoothing > 0
            smooth_factor = Sin(zigzag_value * #PI)
            zigzag_value = zigzag_value * (1.0 - smoothing) + smooth_factor * smoothing
          EndIf
          
          zigzag_value = zigzag_value * 2.0 - 1.0
          offset_x = amplitude * zigzag_value * 0.707  ; √2/2
          offset_y = -amplitude * zigzag_value * 0.707
          
        Case 3  ; ===== Diagonal \ (haut-gauche vers bas-droite) =====
          position = x - y + ht
          segment_size = (lg + ht) / zigzag_count
          normalized_pos = (position / segment_size)
          
          Select shape
            Case 0
              progress = normalized_pos - Int(normalized_pos)
              zigzag_value = progress
            Case 1
              progress = normalized_pos - Int(normalized_pos)
              If progress < 0.5
                zigzag_value = progress * 2.0
              Else
                zigzag_value = 2.0 - progress * 2.0
              EndIf
            Case 2
              progress = normalized_pos - Int(normalized_pos)
              If progress < 0.5
                zigzag_value = 0.0
              Else
                zigzag_value = 1.0
              EndIf
          EndSelect
          
          If smoothing > 0
            smooth_factor = Sin(zigzag_value * #PI)
            zigzag_value = zigzag_value * (1.0 - smoothing) + smooth_factor * smoothing
          EndIf
          
          zigzag_value = zigzag_value * 2.0 - 1.0
          offset_x = amplitude * zigzag_value * 0.707
          offset_y = amplitude * zigzag_value * 0.707
          
      EndSelect

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
; Zigzag - Filtre de déformation en zigzag
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Crée une déformation en zigzag avec des motifs géométriques anguleux.
;   Offre trois formes différentes (dents de scie, triangle, créneaux) et
;   un contrôle du lissage des angles. Idéal pour des effets rétro ou techniques.
;
; Paramètres utilisateur:
;   [0] Amplitude (0-100 pixels, défaut=20)
;       Hauteur des dents du zigzag
;   [1] Nombre de zigzags (1-100, défaut=10)
;       Combien de cycles complets dans l'image
;       Valeurs faibles : grands zigzags espacés
;       Valeurs élevées : petits zigzags serrés
;   [2] Direction (0-3, défaut=0)
;       0 : Horizontal - lignes en zigzag horizontales
;       1 : Vertical - lignes en zigzag verticales
;       2 : Diagonal / - zigzags en diagonale montante
;       3 : Diagonal \ - zigzags en diagonale descendante
;   [3] Forme (0-2, défaut=0)
;       0 : Dents de scie - montée progressive, chute brutale
;       1 : Triangle - montée et descente symétriques
;       2 : Créneaux - paliers horizontaux (effet marches)
;   [4] Lissage (0-100, défaut=0)
;       0   : Angles vifs et nets (zigzag pur)
;       50  : Légèrement arrondi
;       100 : Totalement lissé (devient sinusoïdal)
;
; Utilisations:
;   - Effet graphique rétro/vintage
;   - Bordures décoratives en zigzag
;   - Effet de cisailles ou déchirure
;   - Motifs techniques/industriels
;   - Effet de scanner/TV déréglé
;   - Transitions géométriques
;   - Art pixel/low-poly
;
; Différences avec Wave:
;   - Wave : formes d'onde mathématiques (sin, carré, etc.)
;   - Zigzag : motifs géométriques avec angles nets ou arrondis
;   - Zigzag : 4 directions incluant les diagonales
;
; Exemples de paramètres:
;   Dents de scie classique:
;     Amplitude=25, Nombre=15, Direction=0, Forme=0, Lissage=0
;   
;   Triangle doux:
;     Amplitude=20, Nombre=8, Direction=1, Forme=1, Lissage=40
;   
;   Effet escalier:
;     Amplitude=30, Nombre=12, Direction=0, Forme=2, Lissage=0
;   
;   Zigzag diagonal:
;     Amplitude=15, Nombre=20, Direction=2, Forme=1, Lissage=20
;
; Note: Le lissage à 100% transforme le zigzag en onde sinusoïdale,
; créant une transition progressive entre zigzag anguleux et wave douce.
; -------------------------------------------------------------------------------
Procedure Zigzag(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Zigzag (Dents de scie)"
    *param\remarque = "Déformation en zigzag avec formes géométriques et lissage configurable"
    
    *param\info[0] = "Amplitude (pixels)"
    *param\info[1] = "Nombre de zigzags"
    *param\info[2] = "Direction (0=horiz, 1=vert, 2=diag/, 3=diag\)"
    *param\info[3] = "Forme (0=scie, 1=triangle, 2=créneaux)"
    *param\info[4] = "Lissage (0=vif, 100=arrondi)"
    *param\info[5] = "masque"
    
    ; Configuration amplitude (0-100 pixels, défaut 20)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 100
    *param\info_data(0, 2) = 20
    
    ; Configuration nombre de zigzags (1-100, défaut 10)
    *param\info_data(1, 0) = 1
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 10
    
    ; Configuration direction (0-3, défaut 0 = horizontal)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 3
    *param\info_data(2, 2) = 0
    
    ; Configuration forme (0-2, défaut 0 = dents de scie)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 2
    *param\info_data(3, 2) = 0
    
    ; Configuration lissage (0-100, défaut 0 = angles vifs)
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 100
    *param\info_data(4, 2) = 0
    
    ; Configuration du masque
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 2
    *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (5 paramètres, 1 buffer destination)
  filter_start(@Zigzag_MT(), 5, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 302
; FirstLine = 284
; Folding = -
; EnableXP
; DPIAware