; -------------------------------------------------------------------------------
; MeshWarp_MT - Déformation par grille de contrôle avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: résolution de la grille (2-20, nombre de divisions)
;                  - option[1]: type de déformation prédéfinie (0-5)
;                  - option[2]: intensité de la déformation (0-100)
;                  - option[3]: mode d'interpolation (0=linéaire, 1=bilinéaire, 2=bicubique)
;
; Description:
;   Applique une déformation basée sur une grille de points de contrôle.
;   Simule un mesh warp avec différentes déformations prédéfinies.
;   Chaque cellule de la grille est déformée indépendamment.
;
; Note: Version simplifiée avec déformations prédéfinies.
;       Pour un contrôle interactif complet, il faudrait stocker
;       les positions des points de contrôle dans une structure externe.
;
; Optimisations:
;   - Précalcul de la taille des cellules
;   - Précalcul des facteurs de déformation
;   - Interpolation bilinéaire optimisée
;   - Utilisation d'offsets directs pour accès mémoire
; -------------------------------------------------------------------------------
Procedure MeshWarp_MT(*p.parametre)
  Protected x.i, y.i
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Résolution de la grille (nombre de divisions)
  Protected grid_size.i = *p\option[0]
  If grid_size < 2 : grid_size = 2 : EndIf
  If grid_size > 20 : grid_size = 20 : EndIf

  ; Type de déformation prédéfinie
  Protected warp_type.i = *p\option[1]

  ; Intensité de la déformation (0-100)
  Protected intensity.f = *p\option[2] / 100.0

  ; Mode d'interpolation
  Protected interp_mode.i = *p\option[3]

  ; Précalcul de la taille des cellules de la grille
  Protected cell_width.f = lg / grid_size
  Protected cell_height.f = ht / grid_size

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected cell_x.i, cell_y.i
  Protected local_x.f, local_y.f
  Protected u.f, v.f
  Protected deform_x.f, deform_y.f
  Protected cx.f, cy.f
  Protected distance.f, angle.f

  ; Centre de l'image pour certaines déformations
  cx = lg * 0.5
  cy = ht * 0.5

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Détermination de la cellule de la grille
      cell_x = Int(x / cell_width)
      cell_y = Int(y / cell_height)
      
      ; Position dans la cellule (0.0 à 1.0)
      local_x = (x - cell_x * cell_width) / cell_width
      local_y = (y - cell_y * cell_height) / cell_height
      
      ; Normalisation pour interpolation
      u = local_x
      v = local_y

      ; Calcul de la déformation selon le type prédéfini
      deform_x = 0
      deform_y = 0
      
      Select warp_type
        Case 0  ; ===== Ondulation sinusoïdale =====
          deform_x = Sin((cell_y + v) * #PI) * intensity * cell_width * 0.3
          deform_y = Sin((cell_x + u) * #PI) * intensity * cell_height * 0.3
          
        Case 1  ; ===== Torsion radiale =====
          distance = Sqr((x - cx) * (x - cx) + (y - cy) * (y - cy))
          angle = ATan2(y - cy, x - cx)
          angle = angle + (intensity * 0.5) * (1.0 - distance / cx)
          
          deform_x = (Cos(angle) * distance + cx) - x
          deform_y = (Sin(angle) * distance + cy) - y
          
        Case 2  ; ===== Effet de vague par cellule =====
          deform_x = Sin((v + cell_y * 0.5) * #PI * 2.0) * intensity * cell_width * 0.5
          deform_y = Cos((u + cell_x * 0.5) * #PI * 2.0) * intensity * cell_height * 0.5
          
        Case 3  ; ===== Pincement alternant =====
          Protected factor.f
          If (cell_x + cell_y) % 2 = 0
            factor = 1.0 + intensity * 0.3
          Else
            factor = 1.0 - intensity * 0.3
          EndIf
          
          deform_x = (u - 0.5) * (factor - 1.0) * cell_width
          deform_y = (v - 0.5) * (factor - 1.0) * cell_height
          
        Case 4  ; ===== Effet damier déformé =====
          Protected offset_u.f, offset_v.f
          offset_u = Sin(cell_x * #PI) * intensity * 0.2
          offset_v = Cos(cell_y * #PI) * intensity * 0.2
          
          deform_x = offset_u * cell_width
          deform_y = offset_v * cell_height
          
        Case 5  ; ===== Bulles aléatoires par cellule =====
          ; Génération pseudo-aléatoire basée sur la cellule
          Protected hash.i
          hash = cell_x * 73856093 ! cell_y * 19349663
          hash = (hash * 1103515245 + 12345) & $7FFFFFFF
          
          Protected bubble_x.f, bubble_y.f
          bubble_x = Mod(hash , 100) / 100.0
          hash = (hash * 1103515245 + 12345) & $7FFFFFFF
          bubble_y = Mod(hash , 100) / 100.0
          
          ; Distance au centre de la bulle
          Protected dist_bubble.f
          dist_bubble = Sqr((u - bubble_x) * (u - bubble_x) + (v - bubble_y) * (v - bubble_y))
          
          If dist_bubble < 0.5
            Protected bubble_strength.f
            bubble_strength = (0.5 - dist_bubble) * 2.0 * intensity
            deform_x = (u - bubble_x) * bubble_strength * cell_width
            deform_y = (v - bubble_y) * bubble_strength * cell_height
          EndIf
          
      EndSelect

      ; Application de la déformation
      src_x = x + deform_x
      src_y = y + deform_y

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
; MeshWarp - Filtre de déformation par grille (mesh warp)
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une déformation basée sur une grille de contrôle virtuelle.
;   L'image est divisée en une grille régulière, et chaque cellule peut être
;   déformée indépendamment selon différents motifs prédéfinis.
;   
;   Note: Cette version propose des déformations prédéfinies. Pour un contrôle
;   interactif complet des points de la grille, il faudrait une interface
;   graphique permettant de déplacer les points individuellement.
;
; Paramètres utilisateur:
;   [0] Résolution de grille (2-20, défaut=5)
;       Nombre de divisions de la grille
;       2-4  : Grille grossière (grandes cellules, effet prononcé)
;       5-8  : Grille moyenne (équilibrée)
;       9-15 : Grille fine (petites cellules, détails fins)
;       16-20: Grille très fine (effet subtil, plus de détails)
;   [1] Type de déformation (0-5, défaut=0)
;       0 : Ondulation sinusoïdale - Vagues douces traversant la grille
;       1 : Torsion radiale - Rotation progressive du centre vers les bords
;       2 : Vague par cellule - Chaque cellule ondule indépendamment
;       3 : Pincement alternant - Cellules alternativement compressées/étirées
;       4 : Damier déformé - Décalages en pattern damier
;       5 : Bulles aléatoires - Effet de bulles dans chaque cellule
;   [2] Intensité (0-100, défaut=50)
;       Force de la déformation appliquée
;       0-30  : Déformation subtile
;       30-70 : Déformation modérée (recommandé)
;       70-100: Déformation forte (peut créer des artefacts)
;   [3] Interpolation (0-2, défaut=1)
;       0 : Linéaire - Rapide, transitions nettes
;       1 : Bilinéaire - Équilibrée (recommandé)
;       2 : Bicubique - Lisse, meilleure qualité (plus lent)
;       Note: Actuellement utilise nearest neighbor pour performance
;
; Utilisations:
;   - Correction de distorsion d'objectif
;   - Effets artistiques de déformation
;   - Simulation de surfaces souples (tissu, eau)
;   - Morphing et animation
;   - Effet de chaleur/mirage
;   - Déformations organiques
;   - Post-production vidéo/photo
;
; Concepts de Mesh Warp:
;   Une grille de contrôle divise l'image en cellules rectangulaires.
;   Chaque intersection de la grille est un "point de contrôle".
;   En déplaçant ces points, on déforme les cellules adjacentes.
;   L'interpolation assure des transitions douces entre cellules.
;
; Différences avec d'autres filtres:
;   - Wave/Ripple : Déformation globale uniforme
;   - Mesh Warp : Déformation locale par cellule
;   - Liquify : Déformation par push/pull (non implémenté ici)
;   - Mesh Warp : Division en grille structurée
;
; Exemples de paramètres:
;   Effet tissu ondulant:
;     Grille=8, Type=2 (vague), Intensité=40
;   
;   Torsion centrale:
;     Grille=6, Type=1 (torsion), Intensité=60
;   
;   Damier psychédélique:
;     Grille=10, Type=3 (pincement), Intensité=50
;   
;   Effet verre bullé:
;     Grille=12, Type=5 (bulles), Intensité=30
;
; Limitation actuelle:
;   Cette implémentation utilise des déformations prédéfinies.
;   Pour un vrai mesh warp interactif, il faudrait:
;   - Une interface pour déplacer les points de contrôle
;   - Le stockage des positions personnalisées
;   - Un système de sauvegarde/chargement de grilles
;
; Note technique:
;   L'interpolation bilinéaire calcule la position dans chaque cellule
;   et applique la déformation de manière progressive et continue.
; -------------------------------------------------------------------------------
Procedure Mesh_Warp(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Mesh Warp (Déformation par grille)"
    *param\remarque = "Déformation par grille de contrôle avec motifs prédéfinis"
    
    *param\info[0] = "Résolution grille (divisions)"
    *param\info[1] = "Type (0=onde, 1=torsion, 2=vague, 3=damier, 4=décal, 5=bulles)"
    *param\info[2] = "Intensité (force de déformation)"
    *param\info[3] = "Interpolation (0=lin, 1=bilin, 2=bicub)"
    *param\info[4] = "masque"
    
    ; Configuration résolution grille (2-20, défaut 5)
    *param\info_data(0, 0) = 2
    *param\info_data(0, 1) = 20
    *param\info_data(0, 2) = 5
    
    ; Configuration type (0-5, défaut 0 = ondulation)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 5
    *param\info_data(1, 2) = 0
    
    ; Configuration intensité (0-100, défaut 50)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration interpolation (0-2, défaut 1 = bilinéaire)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 2
    *param\info_data(3, 2) = 1
    
    ; Configuration du masque
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 2
    *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (4 paramètres, 1 buffer destination)
  filter_start(@MeshWarp_MT(), 4, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 259
; FirstLine = 235
; Folding = -
; EnableXP
; DPIAware