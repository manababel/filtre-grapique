; -------------------------------------------------------------------------------
; Glass_MT - Effet verre dépoli (frosted glass) avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: intensité du flou (0-100, distance de déplacement max)
;                  - option[1]: taille de grain (1-100, échelle du bruit)
;                  - option[2]: mode (0=aléatoire pur, 1=perlin-like, 2=cellulaire)
;                  - option[3]: graine aléatoire (0-1000, pour variation)
;
; Description:
;   Simule l'effet d'un verre dépoli en déplaçant aléatoirement chaque pixel.
;   Chaque pixel est échantillonné à une position légèrement décalée,
;   créant un effet de diffusion optique réaliste.
;
; Optimisations:
;   - Générateur pseudo-aléatoire simple et rapide
;   - Précalcul de la graine et des facteurs d'échelle
;   - Utilisation d'offsets directs pour accès mémoire
;   - Calcul optimisé du bruit selon le mode
; -------------------------------------------------------------------------------
Procedure Glass_MT(*p.parametre)
  Protected x.i, y.i
  Protected offset_x.i, offset_y.i
  Protected src_x.i, src_y.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Intensité du flou (distance max de déplacement)
  Protected intensity.i = *p\option[0]
  If intensity < 1 : intensity = 1 : EndIf

  ; Taille de grain (échelle du bruit)
  Protected grain_size.i = *p\option[1]
  If grain_size < 1 : grain_size = 1 : EndIf

  ; Mode de génération du bruit
  Protected mode.i = *p\option[2]  ; 0=aléatoire, 1=perlin-like, 2=cellulaire

  ; Graine aléatoire pour variation
  Protected seed.i = *p\option[3]

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected hash.i, hash2.i
  Protected grid_x.i, grid_y.i
  Protected frac_x.i, frac_y.i
  Protected random_int.i

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      
      ; Sélection du mode de déplacement
      Select mode
        Case 0  ; ===== Mode aléatoire pur (bruit blanc) =====
          ; Génération pseudo-aléatoire simple basée sur position + graine
          hash = (x + seed) * 73856093 ! (y + seed) * 19349663
          hash = (hash * 1103515245 + 12345) & $7FFFFFFF
          
          ; Extraction de deux valeurs aléatoires
          offset_x = (hash % (intensity * 2 + 1)) - intensity
          hash = (hash * 1103515245 + 12345) & $7FFFFFFF
          offset_y = (hash % (intensity * 2 + 1)) - intensity
          
        Case 1  ; ===== Mode Perlin-like (bruit doux) =====
          ; Calcul de la position dans la grille de bruit (en integer)
          grid_x = x / grain_size
          grid_y = y / grain_size
          frac_x = x % grain_size
          frac_y = y % grain_size
          
          ; Génération de valeurs pseudo-aléatoires aux coins de la grille
          hash = (grid_x + seed) * 73856093 ! (grid_y + seed) * 19349663
          hash = (hash * 1103515245 + 12345) & $7FFFFFFF
          
          ; Conversion en valeur signée (-intensity à +intensity)
          random_int = (hash % (intensity * 2 + 1)) - intensity
          
          ; Application d'une atténuation simple basée sur la position dans la cellule
          ; Plus on est au centre de la cellule, plus l'effet est fort
          offset_x = random_int * (grain_size - frac_x) / grain_size
          offset_y = random_int * (grain_size - frac_y) / grain_size
          
        Case 2  ; ===== Mode cellulaire (effet cristallin) =====
          ; Division en cellules
          grid_x = x / grain_size
          grid_y = y / grain_size
          
          ; Hash basé sur la cellule
          hash = (grid_x + seed) * 73856093 ! (grid_y + seed) * 19349663
          hash = (hash * 1103515245 + 12345) & $7FFFFFFF
          
          ; Déplacement constant par cellule
          offset_x = (hash % (intensity * 2 + 1)) - intensity
          hash = (hash * 1103515245 + 12345) & $7FFFFFFF
          offset_y = (hash % (intensity * 2 + 1)) - intensity
          
      EndSelect

      ; Calcul des coordonnées source avec déplacement
      src_x = x + offset_x
      src_y = y + offset_y

      ; Vérification des limites et échantillonnage
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ; Échantillonnage du pixel source
        offset_src = (src_y * lg + src_x) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))
      Else
        ; Pixel hors limites : échantillonnage avec wrap (bouclage)
        If src_x < 0 : src_x = (src_x % lg) + lg : EndIf
        If src_x >= lg : src_x = src_x % lg : EndIf
        If src_y < 0 : src_y = (src_y % ht) + ht : EndIf
        If src_y >= ht : src_y = src_y % ht : EndIf
        
        offset_src = (src_y * lg + src_x) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))
      EndIf

      offset_dst + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; Glass - Filtre effet verre dépoli (frosted glass)
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Simule l'effet d'un verre dépoli ou texturé en déplaçant aléatoirement
;   chaque pixel. Crée un effet de diffusion optique réaliste similaire à
;   celui observé à travers du verre granuleux, sablé ou martelé.
;
; Paramètres utilisateur:
;   [0] Intensité (0-100, défaut=5)
;       Distance maximale de déplacement des pixels
;       0-10  : Léger flou (verre fin)
;       10-30 : Flou modéré (verre dépoli standard)
;       30-60 : Flou fort (verre très texturé)
;       60-100: Flou extrême (verre martelé, quasi-opaque)
;   [1] Taille de grain (1-100, défaut=3)
;       Échelle du motif de distorsion
;       1-5   : Grain très fin (verre lisse)
;       5-20  : Grain moyen (verre dépoli classique)
;       20-50 : Grain grossier (verre cathédrale)
;       50+   : Très gros grain (verre décoratif)
;   [2] Mode (0-2, défaut=0)
;       0 : Aléatoire - Bruit blanc chaotique (verre sablé)
;       1 : Perlin-like - Bruit doux et organique (verre ondulé)
;       2 : Cellulaire - Motif en blocs (verre cathédrale/pavés)
;   [3] Graine (0-1000, défaut=0)
;       Variation du motif aléatoire
;       Changez pour obtenir un motif différent avec les mêmes paramètres
;
; Utilisations:
;   - Effet de confidentialité (floutage artistique)
;   - Simulation de verre dépoli/texturé
;   - Effet de chaleur/distorsion atmosphérique
;   - Anonymisation créative
;   - Effet de surface givrée
;   - Simulation de verre cathédrale
;   - Transitions de rêve/flashback
;
; Différences avec d'autres effets:
;   - Blur : Flou uniforme par moyenne
;   - Glass : Déplacement aléatoire (distorsion optique)
;   - Pixelate : Réduction de résolution
;   - Glass : Préserve les détails mais les disperse
;
; Exemples de paramètres:
;   Verre de salle de bain:
;     Intensité=8, Grain=3, Mode=0 (aléatoire)
;   
;   Verre cathédrale:
;     Intensité=20, Grain=40, Mode=2 (cellulaire)
;   
;   Effet de chaleur:
;     Intensité=4, Grain=2, Mode=1 (perlin)
;   
;   Anonymisation douce:
;     Intensité=15, Grain=5, Mode=0
;
; Note technique:
;   Le filtre utilise un déplacement aléatoire au lieu d'un flou gaussien,
;   ce qui préserve la netteté locale tout en créant la diffusion.
;   Le mode cellulaire crée des "pavés" de distorsion cohérente.
; -------------------------------------------------------------------------------
Procedure Glass(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Glass (Verre dépoli)"
    *param\remarque = "Effet de verre texturé avec déplacement aléatoire des pixels"
    
    *param\info[0] = "Intensité (distance de déplacement)"
    *param\info[1] = "Taille de grain (échelle du motif)"
    *param\info[2] = "Mode (0=aléa, 1=perlin, 2=cellule)"
    *param\info[3] = "Graine (variation du motif)"
    *param\info[4] = "masque"
    
    ; Configuration intensité (0-100, défaut 5)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 100
    *param\info_data(0, 2) = 5
    
    ; Configuration taille de grain (1-100, défaut 3)
    *param\info_data(1, 0) = 1
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 3
    
    ; Configuration mode (0-2, défaut 0 = aléatoire)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 2
    *param\info_data(2, 2) = 0
    
    ; Configuration graine (0-1000, défaut 0)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 1000
    *param\info_data(3, 2) = 0
    
    ; Configuration du masque
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 2
    *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (4 paramètres, 1 buffer destination)
  filter_start(@Glass_MT(), 4, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 245
; FirstLine = 176
; Folding = -
; EnableXP
; DPIAware