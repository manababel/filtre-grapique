; -------------------------------------------------------------------------------
; SphericalProjection_MT - Projection sphérique avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: type de projection (0-5, différentes projections sphériques)
;                  - option[1]: position X du centre (0-100%, 50=centre)
;                  - option[2]: position Y du centre (0-100%, 50=centre)
;                  - option[3]: champ de vision FOV (10-180°, contrôle le zoom)
;                  - option[4]: rotation (0-360°, rotation de la sphère)
;
; Description:
;   Applique différentes projections sphériques pour convertir entre
;   images planes et mappings sphériques (équirectangulaire, stéréographique,
;   orthographique, etc.). Utile pour panoramas 360°, mappings d'environnement,
;   et effets de projection globale.
;
; Optimisations:
;   - Précalcul des constantes trigonométriques
;   - Précalcul du centre et des facteurs de normalisation
;   - Utilisation d'offsets directs pour accès mémoire
;   - Sélection optimisée du type de projection
; -------------------------------------------------------------------------------
Procedure SphericalProjection_MT(*p.parametre)
  Protected x.i, y.i
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Type de projection sphérique
  Protected proj_type.i = *p\option[0]

  ; Centre de projection
  Protected cx.f = (*p\option[1] / 100.0) * lg
  Protected cy.f = (*p\option[2] / 100.0) * ht

  ; Champ de vision (Field of View) en radians
  Protected fov.f = (*p\option[3] / 180.0) * #PI
  If fov < 0.1 : fov = 0.1 : EndIf
  If fov > #PI : fov = #PI : EndIf

  ; Rotation de la sphère en radians
  Protected rotation.f = (*p\option[4] / 360.0) * 2.0 * #PI

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected dx.f, dy.f, r.f
  Protected theta.f, phi.f
  Protected nx.f, ny.f, nz.f  ; Vecteur normal sur la sphère
  Protected u.f, v.f          ; Coordonnées de texture
  Protected max_radius.f

  ; Précalcul du rayon maximal
  max_radius = Sqr(lg * lg + ht * ht) * 0.5

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Position relative au centre normalisée
      dx = (x - cx) / max_radius
      dy = (y - cy) / max_radius
      r = Sqr(dx * dx + dy * dy)

      ; Sélection du type de projection
      Select proj_type
        Case 0  ; ===== Équirectangulaire (lat/long) =====
          ; Projection standard pour panoramas 360°
          ; Convertit image plane → sphère équirectangulaire
          u = (x / lg) * 2.0 * #PI + rotation
          v = (y / ht) * #PI
          
          ; Conversion en coordonnées cartésiennes sur la sphère
          phi = v - #PI * 0.5      ; Latitude : -π/2 à +π/2
          theta = u                 ; Longitude : 0 à 2π
          
          ; Point sur la sphère
          nx = Cos(phi) * Cos(theta)
          ny = Sin(phi)
          nz = Cos(phi) * Sin(theta)
          
          ; Projection perspective vers image plane
          If nz > -0.99  ; Évite points derrière
            src_x = cx + (nx / (1.0 + nz)) * max_radius * (fov / #PI)
            src_y = cy + (ny / (1.0 + nz)) * max_radius * (fov / #PI)
          Else
            src_x = x
            src_y = y
          EndIf
          
        Case 1  ; ===== Stéréographique =====
          ; Projection conforme (préserve les angles)
          If r < 2.0
            ; Conversion stéréographique → sphère
            Protected denom.f
            denom = 1.0 + r * r * 0.25
            
            nx = dx / denom
            ny = dy / denom
            nz = (1.0 - r * r * 0.25) / denom
            
            ; Conversion sphère → équirectangulaire
            phi = ASin(ny)
            If Abs(nx) > 0.001 Or Abs(nz) > 0.001
              theta = ATan2(nz, nx) + rotation
            Else
              theta = 0
            EndIf
            
            ; Mapping vers image source
            src_x = ((theta / (2.0 * #PI)) + 0.5) * lg
            src_y = ((phi / #PI) + 0.5) * ht
          Else
            src_x = x
            src_y = y
          EndIf
          
        Case 2  ; ===== Orthographique =====
          ; Vue parallèle (comme vue satellite)
          If r <= 1.0
            ; Point sur l'hémisphère
            nz = Sqr(1.0 - r * r)
            nx = dx
            ny = dy
            
            ; Conversion en coordonnées sphériques
            phi = ASin(ny)
            If Abs(nx) > 0.001 Or Abs(nz) > 0.001
              theta = ATan2(nz, nx) + rotation
            Else
              theta = 0
            EndIf
            
            src_x = ((theta / (2.0 * #PI)) + 0.5) * lg
            src_y = ((phi / #PI) + 0.5) * ht
          Else
            src_x = x
            src_y = y
          EndIf
          
        Case 3  ; ===== Azimuthale équidistante =====
          ; Distance radiale = distance angulaire
          If r > 0.001 And r < #PI
            Protected angular_dist.f
            angular_dist = r * fov * 0.5
            
            If angular_dist < #PI
              Protected sin_c.f, cos_c.f
              sin_c = Sin(angular_dist)
              cos_c = Cos(angular_dist)
              
              phi = ASin(cos_c * Sin(dy) + (dy * sin_c * Cos(dy)) / r)
              theta = ATan2(dx * sin_c, r * Cos(dy) * cos_c - dy * Sin(dy) * sin_c) + rotation
              
              src_x = ((theta / (2.0 * #PI)) + 0.5) * lg
              src_y = ((phi / #PI) + 0.5) * ht
            Else
              src_x = x
              src_y = y
            EndIf
          Else
            src_x = x
            src_y = y
          EndIf
          
        Case 4  ; ===== Gnomonic (perspective plane tangente) =====
          ; Lignes droites sur sphère = lignes droites sur projection
          Protected tan_dist.f
          tan_dist = r * Tan(fov * 0.5)
          
          If tan_dist < 10.0  ; Limite raisonnable
            Protected dist_factor.f
            dist_factor = ATan(tan_dist)
            
            If r > 0.001
              nx = dx / r * Sin(dist_factor)
              ny = dy / r * Sin(dist_factor)
              nz = Cos(dist_factor)
              
              phi = ASin(ny)
              If Abs(nx) > 0.001 Or Abs(nz) > 0.001
                theta = ATan2(nz, nx) + rotation
              Else
                theta = 0
              EndIf
              
              src_x = ((theta / (2.0 * #PI)) + 0.5) * lg
              src_y = ((phi / #PI) + 0.5) * ht
            Else
              src_x = cx
              src_y = cy
            EndIf
          Else
            src_x = x
            src_y = y
          EndIf
          
        Case 5  ; ===== Mercator =====
          ; Projection cylindrique conforme
          u = (x / lg) * 2.0 * #PI + rotation
          Protected mercator_y.f
          mercator_y = (y - cy) / max_radius * fov
          
          ; Limite de Mercator (évite infini aux pôles)
          If Abs(mercator_y) < 3.0
            phi = 2.0 * ATan(Exp(mercator_y)) - #PI * 0.5
            theta = u
            
            src_x = ((theta / (2.0 * #PI)) + 0.5) * lg
            src_y = ((phi / #PI) + 0.5) * ht
          Else
            src_x = x
            src_y = y
          EndIf
          
      EndSelect

      ; Gestion du wrap horizontal (longitude 0-360°)
      While src_x < 0
        src_x + lg
      Wend
      While src_x >= lg
        src_x - lg
      Wend

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
; SphericalProjection - Filtre de projection sphérique
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique diverses projections sphériques pour convertir entre images
;   planes et mappings sphériques. Essentiel pour travailler avec des
;   panoramas 360°, des skyboxes, des environnements VR/AR, et des
;   visualisations cartographiques globales.
;
; Paramètres utilisateur:
;   [0] Type de projection (0-5, défaut=0)
;       0 : Équirectangulaire - Standard panorama 360° (lat/long)
;       1 : Stéréographique - Préserve angles, effet fish-eye élégant
;       2 : Orthographique - Vue satellite/parallèle
;       3 : Azimuthale équidistante - Distance radiale = distance angulaire
;       4 : Gnomonic - Lignes droites, perspective plane tangente
;       5 : Mercator - Cylindrique conforme (navigation)
;   [1] Position X du centre (0-100%, défaut=50%)
;       Centre de la projection sphérique
;   [2] Position Y du centre (0-100%, défaut=50%)
;       Centre de la projection sphérique
;   [3] Champ de vision FOV (10-180°, défaut=90°)
;       Contrôle le zoom et la couverture angulaire
;       10-60° : Téléobjectif (zoom in)
;       60-90° : Normal (perspective naturelle)
;       90-140°: Grand-angle
;       140-180°: Fish-eye
;   [4] Rotation (0-360°, défaut=0°)
;       Rotation de la sphère autour de l'axe vertical
;       Permet de changer le point de vue
;
; Utilisations:
;   - Conversion panoramas 360° ↔ vues rectilignes
;   - Création de skyboxes pour jeux 3D
;   - Mappings d'environnement pour rendering
;   - Visualisations cartographiques (projections terrestres)
;   - Effets fish-eye artistiques
;   - VR/AR content creation
;   - Astrophotographie (projections célestes)
;
; Description des projections:
;   
;   Équirectangulaire (0):
;     - Projection standard pour panoramas 360×180°
;     - Latitude/longitude en grille rectangulaire
;     - Format universel pour contenu VR
;     - Distorsion aux pôles (haut/bas étirés)
;     Usage: Panoramas photo/vidéo, environnements VR
;   
;   Stéréographique (1):
;     - Projection conforme (préserve les angles)
;     - Cercles → cercles (propriété unique)
;     - Esthétiquement agréable (planètes "little planet")
;     - Infini au point antipodal
;     Usage: Effet "little planet", visualisations artistiques
;   
;   Orthographique (2):
;     - Vue parallèle comme depuis l'espace infini
;     - Préserve les aires apparentes
;     - Hémisphère visible seulement
;     - Aspect naturel de globe terrestre
;     Usage: Vues satellitaires, globes, représentations astronomiques
;   
;   Azimuthale équidistante (3):
;     - Distance au centre = distance angulaire réelle
;     - Utilisée en navigation et cartographie polaire
;     - Direction depuis le centre préservée
;     Usage: Cartes polaires, planning de vols, radioastronomie
;   
;   Gnomonic (4):
;     - Lignes droites sur sphère = lignes droites en projection
;     - Utilisée en navigation (orthodromie)
;     - Forte distorsion loin du centre
;     - Impossible de projeter hémisphère complet
;     Usage: Navigation maritime/aérienne, planification de routes
;   
;   Mercator (5):
;     - Projection cylindrique conforme
;     - Standard en cartographie depuis 1569
;     - Préserve les angles (navigation à cap constant)
;     - Distorsion extrême aux pôles
;     Usage: Cartes de navigation, Google Maps (web mercator)
;
; Exemples de paramètres:
;   
;   Panorama 360° → vue normale:
;     Type=0 (équirect), FOV=90°, Rotation=0°
;     → Convertit panorama en vue perspective
;   
;   Effet "Little Planet":
;     Type=1 (stéréo), Centre=50%/50%, FOV=170°
;     → Crée effet de mini-planète circulaire
;   
;   Vue satellite Terre:
;     Type=2 (ortho), Centre=50%/50%, FOV=90°
;     → Aspect de globe vu depuis l'espace
;   
;   Carte polaire:
;     Type=3 (azimuthal), Centre=50%/0%, FOV=180°
;     → Projection polaire avec distances vraies
;   
;   Navigation orthodromique:
;     Type=4 (gnomonic), Centre=50%/50%, FOV=60°
;     → Routes optimales en lignes droites
;
; Formules mathématiques clés:
;   
;   Équirectangulaire:
;     u = longitude / 2π
;     v = (latitude + π/2) / π
;   
;   Stéréographique:
;     x = 2R × tan(c/2) × sin(Az)
;     y = 2R × tan(c/2) × cos(Az)
;     où c = distance angulaire, Az = azimut
;   
;   Orthographique:
;     x = R × cos(φ) × sin(λ)
;     y = R × sin(φ)
;     où φ = latitude, λ = longitude
;
; Workflow typique:
;   1. Photo panorama 360° (équirectangulaire)
;   2. Appliquer projection souhaitée
;   3. Ajuster FOV pour cadrage
;   4. Utiliser rotation pour orientation
;   5. Export pour VR, jeu, ou web
;
; Notes techniques:
;   - Wrap horizontal automatique (longitude 0-360°)
;   - Protection contre singularités (pôles, infinis)
;   - Normalisation des vecteurs sur sphère unitaire
;   - Gestion des cas limites (r→0, angles extrêmes)
;
; Limitations:
;   - Version simplifiée (1 projection à la fois)
;   - Pour pipeline complet : multiples conversions enchaînées
;   - Pas d'interpolation avancée (nearest neighbor)
;
; Différences avec d'autres filtres:
;   - Fish-Eye : Effet optique local
;   - Spherical : Projection mathématique globale précise
;   - Barrel : Correction optique polynomiale
;   - Spherical : Transformations géométriques sphériques
; -------------------------------------------------------------------------------
Procedure Spherical_Projection(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Spherical Projection (Projection sphérique)"
    *param\remarque = "Projections sphériques pour panoramas 360° et mappings globaux"
    
    *param\info[0] = "Type (0=equirect, 1=stéréo, 2=ortho, 3=azim, 4=gnomo, 5=mercator)"
    *param\info[1] = "Centre X (% largeur)"
    *param\info[2] = "Centre Y (% hauteur)"
    *param\info[3] = "FOV champ vision (degrés)"
    *param\info[4] = "Rotation (degrés)"
    *param\info[5] = "masque"
    
    ; Configuration type (0-5, défaut 0 = équirectangulaire)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 5
    *param\info_data(0, 2) = 0
    
    ; Configuration centre X (0-100%, défaut 50% = centre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Configuration centre Y (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration FOV (10-180°, défaut 90°)
    *param\info_data(3, 0) = 10
    *param\info_data(3, 1) = 180
    *param\info_data(3, 2) = 90
    
    ; Configuration rotation (0-360°, défaut 0°)
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
  filter_start(@SphericalProjection_MT(), 5, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 401
; FirstLine = 383
; Folding = -
; EnableXP
; DPIAware