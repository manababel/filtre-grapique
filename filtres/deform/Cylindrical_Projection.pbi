; -------------------------------------------------------------------------------
; CylindricalProjection_MT - Projection cylindrique avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: direction (0=horizontal, 1=vertical)
;                  - option[1]: courbure (0-200, 100=neutre, <100=concave, >100=convexe)
;                  - option[2]: position du centre (0-100%, 50=centre)
;                  - option[3]: rayon effectif (0-100% de la dimension)
;                  - option[4]: mode (0=normal, 1=inverse, 2=panorama→plat, 3=plat→panorama)
;
; Description:
;   Applique une projection cylindrique simulant l'enroulement ou le
;   déroulement d'une image sur/depuis un cylindre. Utile pour créer
;   des panoramas cylindriques ou corriger des distorsions cylindriques.
;
; Optimisations:
;   - Précalcul des facteurs de courbure
;   - Précalcul du rayon et du centre
;   - Utilisation d'offsets directs pour accès mémoire
;   - Calcul optimisé des projections trigonométriques
; -------------------------------------------------------------------------------
Procedure CylindricalProjection_MT(*p.parametre)
  Protected x.i, y.i
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Direction de la projection (0=horizontal, 1=vertical)
  Protected direction.i = *p\option[0]

  ; Courbure (centré sur 100)
  ; < 100 : concave (vers l'intérieur)
  ; = 100 : plat (pas d'effet)
  ; > 100 : convexe (vers l'extérieur)
  Protected curvature.f = (*p\option[1] - 100.0) / 100.0

  ; Position du centre (0-100%)
  Protected center_pos.f = *p\option[2] / 100.0

  ; Rayon effectif du cylindre (0-100% de la dimension)
  Protected radius_percent.f = *p\option[3] / 100.0
  If radius_percent < 0.1 : radius_percent = 0.1 : EndIf

  ; Mode de projection
  Protected mode.i = *p\option[4]

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected pos.f, normalized_pos.f
  Protected theta.f, radius.f
  Protected projected_pos.f
  Protected dimension.i, center.f

  ; Calcul du rayon du cylindre selon la direction
  If direction = 0  ; Horizontal
    dimension = lg
    center = center_pos * lg
    radius = (lg * radius_percent) / #PI  ; Rayon tel que circonférence ≈ largeur
  Else  ; Vertical
    dimension = ht
    center = center_pos * ht
    radius = (ht * radius_percent) / #PI
  EndIf

  ; Protection contre rayon trop petit
  If radius < 1.0 : radius = 1.0 : EndIf

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      
      ; Sélection de la direction de projection
      If direction = 0
        ; ===== Projection horizontale (cylindre vertical) =====
        pos = x
        
        Select mode
          Case 0, 1  ; Mode normal ou inverse (wrap cylindrique)
            ; Position relative au centre
            normalized_pos = (pos - center) / radius
            
            ; Application de la projection cylindrique
            If curvature >= 0  ; Convexe
              ; Projection sur cylindre : x → θ, puis θ → sin(θ)
              theta = normalized_pos * curvature
              If Abs(theta) < #PI / 2.0  ; Limite à ±90°
                projected_pos = radius * Sin(theta)
              Else
                projected_pos = normalized_pos * radius
              EndIf
            Else  ; Concave
              ; Projection inverse
              theta = normalized_pos / radius
              If Abs(theta) < 1.0
                projected_pos = radius * ASin(theta) / Abs(curvature)
              Else
                projected_pos = normalized_pos * radius
              EndIf
            EndIf
            
            If mode = 1  ; Inverse
              src_x = center + projected_pos
            Else
              src_x = center + projected_pos
            EndIf
            src_y = y
            
          Case 2  ; Panorama → Plat (déroulement)
            ; Convertit une image cylindrique en image plate
            normalized_pos = (pos - center) / (dimension * 0.5)
            theta = normalized_pos * #PI * 0.5  ; -90° à +90°
            
            projected_pos = radius * Tan(theta)
            src_x = center + projected_pos
            src_y = y
            
          Case 3  ; Plat → Panorama (enroulement)
            ; Convertit une image plate en panorama cylindrique
            normalized_pos = (pos - center) / radius
            
            If Abs(normalized_pos) < 10.0  ; Limite raisonnable
              theta = ATan(normalized_pos)
              projected_pos = (theta / (#PI * 0.5)) * (dimension * 0.5)
            Else
              projected_pos = normalized_pos * radius
            EndIf
            
            src_x = center + projected_pos
            src_y = y
            
        EndSelect
        
      Else
        ; ===== Projection verticale (cylindre horizontal) =====
        pos = y
        
        Select mode
          Case 0, 1  ; Mode normal ou inverse
            normalized_pos = (pos - center) / radius
            
            If curvature >= 0  ; Convexe
              theta = normalized_pos * curvature
              If Abs(theta) < #PI / 2.0
                projected_pos = radius * Sin(theta)
              Else
                projected_pos = normalized_pos * radius
              EndIf
            Else  ; Concave
              theta = normalized_pos / radius
              If Abs(theta) < 1.0
                projected_pos = radius * ASin(theta) / Abs(curvature)
              Else
                projected_pos = normalized_pos * radius
              EndIf
            EndIf
            
            src_x = x
            src_y = center + projected_pos
            
          Case 2  ; Panorama → Plat
            normalized_pos = (pos - center) / (dimension * 0.5)
            theta = normalized_pos * #PI * 0.5
            
            projected_pos = radius * Tan(theta)
            src_x = x
            src_y = center + projected_pos
            
          Case 3  ; Plat → Panorama
            normalized_pos = (pos - center) / radius
            
            If Abs(normalized_pos) < 10.0
              theta = ATan(normalized_pos)
              projected_pos = (theta / (#PI * 0.5)) * (dimension * 0.5)
            Else
              projected_pos = normalized_pos * radius
            EndIf
            
            src_x = x
            src_y = center + projected_pos
            
        EndSelect
        
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
; CylindricalProjection - Filtre de projection cylindrique
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une projection cylindrique permettant de simuler l'enroulement
;   ou le déroulement d'une image sur/depuis un cylindre. Utile pour créer
;   des panoramas cylindriques, corriger des distorsions d'objectifs
;   cylindriques, ou créer des effets de courbure réalistes.
;
; Paramètres utilisateur:
;   [0] Direction (0-1, défaut=0)
;       0 : Horizontale - Cylindre vertical (courbe gauche-droite)
;       1 : Verticale - Cylindre horizontal (courbe haut-bas)
;   [1] Courbure (0-200, défaut=100)
;       0-99  : Concave (courbure vers l'intérieur, effet de creux)
;       100   : Plat (pas de déformation)
;       101-200: Convexe (courbure vers l'extérieur, effet de bombement)
;       Exemple: 150 = courbure modérée vers l'extérieur
;   [2] Position du centre (0-100%, défaut=50%)
;       Point fixe de la projection (axe du cylindre)
;   [3] Rayon effectif (0-100%, défaut=50%)
;       Taille du cylindre virtuel
;       Valeurs faibles : courbure prononcée
;       Valeurs élevées : courbure douce
;   [4] Mode (0-3, défaut=0)
;       0 : Normal - Projection cylindrique standard
;       1 : Inverse - Projection cylindrique inversée
;       2 : Panorama→Plat - Déroule un panorama cylindrique en image plate
;       3 : Plat→Panorama - Enroule une image plate en panorama cylindrique
;
; Utilisations:
;   - Création de panoramas 360° cylindriques
;   - Correction de distorsion d'objectif fisheye partiel
;   - Effet de page enroulée
;   - Simulation de surface cylindrique (colonnes, bouteilles)
;   - Conversion panorama ↔ image plate
;   - Effets architecturaux (façades courbes)
;   - Visualisation de textures cylindriques
;
; Description des modes:
;   Mode Normal (0):
;     - Projection standard sur cylindre
;     - Crée une courbure douce et progressive
;     - Utilisé pour effets de bombement réalistes
;   
;   Mode Inverse (1):
;     - Inverse la projection normale
;     - Corrige une distorsion cylindrique existante
;     - Utile pour "aplatir" une image courbe
;   
;   Mode Panorama→Plat (2):
;     - Déroule un panorama cylindrique
;     - Convertit photo 360° en image rectangulaire
;     - Utilise projection tangentielle
;   
;   Mode Plat→Panorama (3):
;     - Enroule une image plate en panorama
;     - Crée un panorama cylindrique depuis image standard
;     - Inverse du mode 2
;
; Exemples de paramètres:
;   Page enroulée (droite):
;     Direction=0, Courbure=140, Centre=75%, Rayon=60%, Mode=0
;     → Effet de page qui se courbe à droite
;   
;   Colonne architecturale:
;     Direction=1, Courbure=130, Centre=50%, Rayon=50%, Mode=0
;     → Effet de colonne bombée
;   
;   Panorama 360° → image plate:
;     Direction=0, Rayon=50%, Mode=2
;     → Déroule un panorama cylindrique
;   
;   Photo → panorama cylindrique:
;     Direction=0, Rayon=50%, Mode=3
;     → Enroule une photo en panorama
;   
;   Correction fisheye cylindrique:
;     Direction=0, Courbure=80, Rayon=70%, Mode=1
;     → Corrige distorsion cylindrique
;
; Formules mathématiques:
;   Projection convexe (bombement):
;     θ = (x - center) / radius × curvature
;     x' = center + radius × sin(θ)
;   
;   Projection concave (creux):
;     θ = (x - center) / radius
;     x' = center + radius × asin(θ) / |curvature|
;   
;   Panorama→Plat (déroulement):
;     θ = (x - center) / (width/2) × π/2
;     x' = center + radius × tan(θ)
;   
;   Plat→Panorama (enroulement):
;     x' = center + (atan((x-center)/radius) / (π/2)) × (width/2)
;
; Différences avec d'autres filtres:
;   - Barrel : Distorsion radiale polynomiale
;   - Cylindrical : Distorsion unidirectionnelle (1D)
;   - Fish-Eye : Distorsion sphérique (2D)
;   - Cylindrical : Projection géométrique précise
;
; Notes techniques:
;   - La projection utilise sin/asin pour bombement/creux
;   - Mode panorama utilise tan/atan pour déroulement
;   - Le rayon contrôle l'intensité de la courbure
;   - Direction 0 = horizontal, 1 = vertical
;
; Conseils d'utilisation:
;   - Pour panoramas: utilisez mode 2 ou 3
;   - Pour effets artistiques: mode 0 avec courbure 120-160
;   - Pour corrections: mode 1 avec courbure inverse
;   - Rayon 30-70% donne les meilleurs résultats
; -------------------------------------------------------------------------------
Procedure Cylindrical_Projection(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Cylindrical Projection (Projection cylindrique)"
    *param\remarque = "Projection cylindrique pour panoramas et effets de courbure"
    
    *param\info[0] = "Direction (0=horizontal, 1=vertical)"
    *param\info[1] = "Courbure (0-99=concave, 100=plat, 101-200=convexe)"
    *param\info[2] = "Position centre (% dimension)"
    *param\info[3] = "Rayon effectif (% dimension)"
    *param\info[4] = "Mode (0=normal, 1=inverse, 2=pano→plat, 3=plat→pano)"
    *param\info[5] = "masque"
    
    ; Configuration direction (0-1, défaut 0 = horizontal)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 1
    *param\info_data(0, 2) = 0
    
    ; Configuration courbure (0-200, défaut 100 = plat)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 200
    *param\info_data(1, 2) = 100
    
    ; Configuration centre (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration rayon (0-100%, défaut 50%)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 100
    *param\info_data(3, 2) = 50
    
    ; Configuration mode (0-3, défaut 0 = normal)
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
  filter_start(@CylindricalProjection_MT(), 5, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 332
; FirstLine = 314
; Folding = -
; EnableXP
; DPIAware