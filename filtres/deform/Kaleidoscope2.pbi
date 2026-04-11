; -------------------------------------------------------------------------------
; Kaleidoscope_MT - Effet kaléidoscope avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: nombre de segments (2-32, nombre de miroirs radiaux)
;                  - option[1]: position X du centre (0-100%, 50=centre)
;                  - option[2]: position Y du centre (0-100%, 50=centre)
;                  - option[3]: rotation en degrés (0-360°)
;                  - option[4]: mode de réflexion (0=simple, 1=double miroir)
;
; Description:
;   Crée un effet de kaléidoscope en répétant et reflétant un secteur
;   de l'image autour d'un point central. Simule un kaléidoscope optique
;   avec N miroirs disposés radialement.
;
; Optimisations:
;   - Précalcul du centre et des constantes angulaires
;   - Précalcul de l'angle de secteur
;   - Utilisation d'offsets directs pour accès mémoire
;   - Calcul optimisé des réflexions
; -------------------------------------------------------------------------------
Procedure Kaleidoscope2_MT(*p.parametre)
  Protected x.i, y.i
  Protected dx.f, dy.f, r.f, theta.f
  Protected sector_angle.f, normalized_angle.f
  Protected reflected_angle.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Nombre de segments (miroirs radiaux)
  Protected segments.i = *p\option[0]
  If segments < 2 : segments = 2 : EndIf
  If segments > 32 : segments = 32 : EndIf

  ; Précalcul du centre du kaléidoscope
  Protected cx.f = (*p\option[1] / 100.0) * lg
  Protected cy.f = (*p\option[2] / 100.0) * ht

  ; Rotation globale en radians
  Protected rotation.f = (*p\option[3] / 360.0) * 2.0 * #PI

  ; Mode de réflexion (0=simple, 1=double miroir)
  Protected mirror_mode.i = *p\option[4]

  ; Précalcul de l'angle de chaque secteur
  Protected two_pi.f = 2.0 * #PI
  Protected sector_size.f = two_pi / segments
  Protected half_sector.f = sector_size * 0.5

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected sector_index.i
  Protected angle_in_sector.f

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Calcul de la position relative au centre
      dx = x - cx
      dy = y - cy

      ; Conversion en coordonnées polaires
      r = Sqr(dx * dx + dy * dy)
      theta = ATan2(dy, dx)

      ; Application de la rotation globale
      theta + rotation

      ; Normalisation de l'angle dans [0, 2π]
      While theta < 0
        theta + two_pi
      Wend
      While theta >= two_pi
        theta - two_pi
      Wend

      ; Détermination du secteur et de l'angle dans ce secteur
      sector_index = Int(theta / sector_size)
      angle_in_sector = theta - (sector_index * sector_size)

      ; Application du mode de réflexion
      If mirror_mode = 0
        ; Mode simple : réflexion basique autour de l'axe du secteur
        ; Ramène l'angle dans le premier secteur [0, sector_size]
        If sector_index % 2 = 1
          ; Secteurs impairs : miroir
          reflected_angle = sector_size - angle_in_sector
        Else
          ; Secteurs pairs : direct
          reflected_angle = angle_in_sector
        EndIf
      Else
        ; Mode double miroir : réflexion triangulaire
        ; Crée un effet de miroir en "V" dans chaque secteur
        If angle_in_sector > half_sector
          reflected_angle = sector_size - angle_in_sector
        Else
          reflected_angle = angle_in_sector
        EndIf
      EndIf

      ; Reconstruction de l'angle final (toujours dans le premier secteur)
      theta = reflected_angle

      ; Conversion polaire → cartésienne
      src_x = cx + r * Cos(theta)
      src_y = cy + r * Sin(theta)

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
; Kaleidoscope - Filtre effet kaléidoscope
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Crée un effet de kaléidoscope optique en répétant et reflétant un secteur
;   angulaire de l'image. Simule l'effet de miroirs multiples disposés
;   radialement comme dans un vrai kaléidoscope.
;
; Paramètres utilisateur:
;   [0] Nombre de segments (2-32, défaut=6)
;       Nombre de "miroirs" radiaux / sections répétées
;       2  : symétrie simple (miroir)
;       3  : triangle (motif à 3 branches)
;       6  : hexagonal (kaléidoscope classique)
;       8  : octogonal (motif à 8 branches)
;       12 : effet flocon de neige
;   [1] Position X du centre (0-100%, défaut=50% = centre)
;   [2] Position Y du centre (0-100%, défaut=50% = centre)
;   [3] Rotation (0-360°, défaut=0°)
;       Rotation globale du motif kaléidoscopique
;   [4] Mode de réflexion (0-1, défaut=1)
;       0 : Simple - miroir alterné (secteurs pairs/impairs)
;       1 : Double - miroir en V dans chaque secteur (plus symétrique)
;
; Utilisations:
;   - Motifs décoratifs symétriques
;   - Art génératif et mandalas
;   - Effets psychédéliques
;   - Visualisations artistiques
;   - Création de patterns répétitifs
;   - Design de rosaces et motifs floraux
;
; Différence entre les modes:
;   Mode Simple (0) : 
;     - Chaque secteur pair = copie directe du secteur source
;     - Chaque secteur impair = miroir du secteur source
;     - Effet plus dynamique, moins symétrique
;   
;   Mode Double (1) :
;     - Chaque secteur contient un miroir en V
;     - Symétrie parfaite dans tous les secteurs
;     - Effet plus traditionnel de kaléidoscope
;
; Conseils créatifs:
;   - 3 segments : effet "Mercedes" ou triskèle
;   - 6 segments : kaléidoscope traditionnel, flocons
;   - 8 segments : mandalas, rosaces gothiques
;   - 12+ segments : motifs très denses, quasi-circulaires
;
; Note: L'image source n'a besoin que d'un petit secteur intéressant,
; le reste sera généré par symétrie. Testez sur des photos de fleurs,
; textures, ou formes géométriques pour des résultats spectaculaires !
; -------------------------------------------------------------------------------
Procedure Kaleidoscope2(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Kaleidoscope (Kaléidoscope)"
    *param\remarque = "Effet de miroirs radiaux multiples créant des motifs symétriques"
    
    *param\info[0] = "Segments (nombre de miroirs radiaux)"
    *param\info[1] = "Centre X (% largeur)"
    *param\info[2] = "Centre Y (% hauteur)"
    *param\info[3] = "Rotation (degrés)"
    *param\info[4] = "Mode (0=simple, 1=double miroir)"
    *param\info[5] = "masque"
    
    ; Configuration segments (2-32, défaut 6 = kaléidoscope classique)
    *param\info_data(0, 0) = 2
    *param\info_data(0, 1) = 32
    *param\info_data(0, 2) = 6
    
    ; Configuration centre X (0-100%, défaut 50% = centre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Configuration centre Y (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration rotation (0-360°, défaut 0°)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 360
    *param\info_data(3, 2) = 0
    
    ; Configuration mode de réflexion (0-1, défaut 1=double)
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 1
    *param\info_data(4, 2) = 1
    
    ; Configuration du masque
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 2
    *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (5 paramètres, 1 buffer destination)
  filter_start(@Kaleidoscope2_MT(), 5, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 229
; FirstLine = 178
; Folding = -
; EnableXP
; DPIAware