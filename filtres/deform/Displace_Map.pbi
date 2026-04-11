; -------------------------------------------------------------------------------
; DisplaceMap_MT - Déplacement par carte de déplacement avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: intensité X (0-200, 100=neutre)
;                  - option[1]: intensité Y (0-200, 100=neutre)
;                  - option[2]: canal source pour X (0=R, 1=G, 2=B, 3=Luminosité)
;                  - option[3]: canal source pour Y (0=R, 1=G, 2=B, 3=Luminosité)
;                  - option[4]: mode de wrap (0=clamp, 1=wrap, 2=mirror)
;                  - addr[2]: carte de déplacement (displacement map)
;
; Description:
;   Utilise une carte de déplacement (displacement map) pour déformer l'image.
;   Chaque pixel de la carte contrôle le déplacement du pixel correspondant.
;   Très puissant pour des déformations complexes et personnalisées.
;
; Optimisations:
;   - Précalcul des facteurs d'intensité
;   - Accès direct aux canaux de couleur
;   - Utilisation d'offsets directs pour accès mémoire
;   - Gestion optimisée des différents modes de wrap
; -------------------------------------------------------------------------------
Procedure DisplaceMap_MT(*p.parametre)
  Protected x.i, y.i
  Protected displace_x.f, displace_y.f
  Protected src_x.i, src_y.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected *displace.Long = *p\addr[2]  ; Carte de déplacement
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Vérification de la présence de la carte de déplacement
  If *displace = 0
    ; Pas de carte de déplacement : copie directe
    For y = (*p\thread_pos * ht) / *p\thread_max To ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
      If y > ht - 1 : Break : EndIf
      CopyMemory(*source + y * lg * 4, *cible + y * lg * 4, lg * 4)
    Next
    ProcedureReturn
  EndIf

  ; Intensité du déplacement (centré sur 100)
  ; 0-99 : déplacement négatif, 100 : neutre, 101-200 : déplacement positif
  Protected intensity_x.f = (*p\option[0] - 100.0) / 100.0
  Protected intensity_y.f = (*p\option[1] - 100.0) / 100.0

  ; Canaux source pour X et Y (0=R, 1=G, 2=B, 3=Luminosité)
  Protected channel_x.i = *p\option[2]
  Protected channel_y.i = *p\option[3]

  ; Mode de wrap (0=clamp, 1=wrap, 2=mirror)
  Protected wrap_mode.i = *p\option[4]

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i, offset_disp.i
  Protected pixel_disp.l
  Protected r.i, g.i, b.i
  Protected value_x.f, value_y.f
  Protected max_displacement.f

  ; Déplacement maximum en pixels
  max_displacement = Sqr(lg * lg + ht * ht) * 0.5

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4
    offset_disp = y * lg * 4

    For x = 0 To lg - 1
      ; Lecture du pixel de la carte de déplacement
      pixel_disp = PeekL(*displace + offset_disp)
      
      ; Extraction des composantes RGB
      r = (pixel_disp >> 16) & $FF
      g = (pixel_disp >> 8) & $FF
      b = pixel_disp & $FF

      ; Sélection du canal pour le déplacement X
      Select channel_x
        Case 0  ; Rouge
          value_x = (r / 255.0) * 2.0 - 1.0  ; Normalisation -1 à +1
        Case 1  ; Vert
          value_x = (g / 255.0) * 2.0 - 1.0
        Case 2  ; Bleu
          value_x = (b / 255.0) * 2.0 - 1.0
        Case 3  ; Luminosité (moyenne RGB)
          value_x = ((r + g + b) / (3.0 * 255.0)) * 2.0 - 1.0
      EndSelect

      ; Sélection du canal pour le déplacement Y
      Select channel_y
        Case 0  ; Rouge
          value_y = (r / 255.0) * 2.0 - 1.0
        Case 1  ; Vert
          value_y = (g / 255.0) * 2.0 - 1.0
        Case 2  ; Bleu
          value_y = (b / 255.0) * 2.0 - 1.0
        Case 3  ; Luminosité
          value_y = ((r + g + b) / (3.0 * 255.0)) * 2.0 - 1.0
      EndSelect

      ; Calcul du déplacement en pixels
      displace_x = value_x * intensity_x * max_displacement
      displace_y = value_y * intensity_y * max_displacement

      ; Calcul des coordonnées source
      src_x = x + Int(displace_x)
      src_y = y + Int(displace_y)

      ; Gestion des bords selon le mode de wrap
      Select wrap_mode
        Case 0  ; Clamp (limite aux bords)
          If src_x < 0 : src_x = 0 : EndIf
          If src_x >= lg : src_x = lg - 1 : EndIf
          If src_y < 0 : src_y = 0 : EndIf
          If src_y >= ht : src_y = ht - 1 : EndIf
          
        Case 1  ; Wrap (bouclage)
          src_x = src_x % lg
          If src_x < 0 : src_x = src_x + lg : EndIf
          src_y = src_y % ht
          If src_y < 0 : src_y = src_y + ht : EndIf
          
        Case 2  ; Mirror (miroir)
          Protected temp_x.i, temp_y.i
          temp_x = src_x
          temp_y = src_y
          
          ; Miroir horizontal
          While temp_x < 0 Or temp_x >= lg
            If temp_x < 0
              temp_x = -temp_x - 1
            ElseIf temp_x >= lg
              temp_x = 2 * lg - temp_x - 1
            EndIf
          Wend
          
          ; Miroir vertical
          While temp_y < 0 Or temp_y >= ht
            If temp_y < 0
              temp_y = -temp_y - 1
            ElseIf temp_y >= ht
              temp_y = 2 * ht - temp_y - 1
            EndIf
          Wend
          
          src_x = temp_x
          src_y = temp_y
          
      EndSelect

      ; Échantillonnage du pixel source
      offset_src = (src_y * lg + src_x) * 4
      PokeL(*cible + offset_dst, PeekL(*source + offset_src))

      offset_dst + 4
      offset_disp + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; DisplaceMap - Filtre de déplacement par carte
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Utilise une image séparée (carte de déplacement) pour déformer l'image
;   source. Chaque pixel de la carte contrôle le déplacement du pixel
;   correspondant dans l'image. C'est l'outil le plus puissant et flexible
;   pour créer des déformations complexes et personnalisées.
;
; Paramètres utilisateur:
;   [0] Intensité X (0-200, défaut=100)
;       Contrôle l'amplitude du déplacement horizontal
;       0-99  : Déplacement vers la gauche
;       100   : Pas de déplacement
;       101-200: Déplacement vers la droite
;   [1] Intensité Y (0-200, défaut=100)
;       Contrôle l'amplitude du déplacement vertical
;       0-99  : Déplacement vers le haut
;       100   : Pas de déplacement
;       101-200: Déplacement vers le bas
;   [2] Canal X (0-3, défaut=0)
;       Canal de la carte utilisé pour déplacement horizontal
;       0 : Rouge - Utilise le canal rouge
;       1 : Vert - Utilise le canal vert
;       2 : Bleu - Utilise le canal bleu
;       3 : Luminosité - Utilise la moyenne des canaux
;   [3] Canal Y (0-3, défaut=1)
;       Canal de la carte utilisé pour déplacement vertical
;       (Mêmes options que Canal X)
;   [4] Mode wrap (0-2, défaut=1)
;       Gestion des pixels sortant des limites
;       0 : Clamp - Étire les pixels de bord
;       1 : Wrap - Bouclage (répétition)
;       2 : Mirror - Effet miroir aux bords
;
; Fonctionnement:
;   1. Pour chaque pixel (x, y):
;   2. Lire la couleur dans la carte de déplacement à (x, y)
;   3. Extraire les canaux spécifiés (ex: Rouge pour X, Vert pour Y)
;   4. Convertir 0-255 en déplacement -1 à +1
;   5. Appliquer intensité: déplacement × intensité × dimension
;   6. Échantillonner pixel source à (x + dépl_x, y + dépl_y)
;
; Carte de déplacement:
;   - Gris 50% (128) = pas de déplacement
;   - Noir (0) = déplacement maximum négatif
;   - Blanc (255) = déplacement maximum positif
;   - Gradients = déplacements progressifs
;
; Utilisations:
;   - Effets de verre/eau avec texture de bruit
;   - Distorsions complexes personnalisées
;   - Morphing entre images (carte de flux)
;   - Effets de chaleur avec carte animée
;   - Déformations organiques (peau, tissus)
;   - Effets de profondeur (normal maps)
;   - Simulation de réfraction
;   - Transitions créatives
;
; Exemples de cartes:
;   
;   Vagues d'eau:
;     Carte: Bruit de Perlin avec gradients doux
;     Canal X: Luminosité, Intensité: 110
;     Canal Y: Luminosité, Intensité: 105
;     → Ondulations fluides
;   
;   Verre dépoli:
;     Carte: Bruit aléatoire
;     Canal X: Rouge, Intensité: 115
;     Canal Y: Vert, Intensité: 115
;     → Effet de verre texturé
;   
;   Tourbillon:
;     Carte: Gradient radial avec rotation
;     Canal X: Rouge (tangentiel)
;     Canal Y: Vert (tangentiel)
;     → Effet de vortex
;   
;   Relief/Emboss:
;     Carte: Normal map (bump map)
;     Canal X: Rouge, Intensité: 105
;     Canal Y: Vert, Intensité: 105
;     → Simulation de relief 3D
;   
;   Déformation personnalisée:
;     Carte: Dessin manuel en niveaux de gris
;     Canaux: Luminosité pour X et Y
;     → Contrôle total artistique
;
; Création de cartes:
;   
;   Dans un logiciel de dessin:
;   1. Créer image RGB même taille que source
;   2. Rouge = déplacement horizontal (128 = neutre)
;   3. Vert = déplacement vertical (128 = neutre)
;   4. Bleu = optionnel ou identique
;   5. Flou gaussien pour déplacements doux
;   6. Contraste pour déplacements prononcés
;   
;   Cartes procédurales:
;   - Bruit de Perlin: ondulations organiques
;   - Voronoï: déformations cellulaires
;   - Fractales: motifs complexes
;   - Gradients: transitions linéaires
;
; Différences avec autres filtres:
;   - Glass: Déplacement aléatoire fixe
;   - Displace Map: Déplacement contrôlé pixel par pixel
;   - Liquify: Déformation interactive manuelle
;   - Displace Map: Déformation préprogrammée réutilisable
;   - Mesh Warp: Grille structurée
;   - Displace Map: Contrôle complet et libre
;
; Workflow typique:
;   1. Créer/générer carte de déplacement
;   2. Ajuster intensités X et Y selon besoin
;   3. Tester différents canaux pour effets variés
;   4. Choisir mode wrap selon composition
;   5. Affiner la carte pour résultat parfait
;
; Astuces:
;   - Floutez la carte pour déplacements doux
;   - Augmentez contraste pour déplacements nets
;   - Utilisez canaux différents pour effets complexes
;   - Animez la carte pour effets dynamiques
;   - Mode Mirror pour continuité aux bords
;   - Rouge + Vert = contrôle 2D indépendant
;
; Note technique:
;   La carte DOIT avoir les mêmes dimensions que l'image source.
;   Si absente, le filtre copie simplement l'image source.
;
; Formule de déplacement:
;   value = (canal / 255) × 2 - 1        // -1 à +1
;   déplacement = value × intensité × max_dist
;   pixel_final = source(x + dépl_x, y + dépl_y)
; -------------------------------------------------------------------------------
Procedure Displace_Map(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Displace Map (Carte de déplacement)"
    *param\remarque = "Déformation par carte externe avec contrôle total pixel par pixel"
    
    *param\info[0] = "Intensité X (0-99=gauche, 100=neutre, 101-200=droite)"
    *param\info[1] = "Intensité Y (0-99=haut, 100=neutre, 101-200=bas)"
    *param\info[2] = "Canal X (0=R, 1=G, 2=B, 3=Lum)"
    *param\info[3] = "Canal Y (0=R, 1=G, 2=B, 3=Lum)"
    *param\info[4] = "Wrap (0=clamp, 1=wrap, 2=mirror)"
    *param\info[5] = "masque"
    
    ; Configuration intensité X (0-200, défaut 100 = neutre)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 200
    *param\info_data(0, 2) = 100
    
    ; Configuration intensité Y (0-200, défaut 100 = neutre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 200
    *param\info_data(1, 2) = 100
    
    ; Configuration canal X (0-3, défaut 0 = rouge)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 3
    *param\info_data(2, 2) = 0
    
    ; Configuration canal Y (0-3, défaut 1 = vert)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 3
    *param\info_data(3, 2) = 1
    
    ; Configuration wrap (0-2, défaut 1 = wrap)
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 2
    *param\info_data(4, 2) = 1
    
    ; Configuration du masque
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 2
    *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (5 paramètres, 1 buffer destination, 1 carte)
  filter_start(@DisplaceMap_MT(), 5, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 310
; FirstLine = 292
; Folding = -
; EnableXP
; DPIAware