; -------------------------------------------------------------------------------
; FishEye_MT - Effet fish-eye (ultra grand-angle) avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: intensité de l'effet (0-200, 100=neutre)
;                  - option[1]: position X du centre (0-100%, 50=centre)
;                  - option[2]: position Y du centre (0-100%, 50=centre)
;                  - option[3]: rayon d'effet (0-100% de la diagonale)
;                  - option[4]: type de projection (0=stéréographique, 1=équidistante, 2=orthographique)
;
; Description:
;   Applique une distorsion fish-eye simulant un objectif ultra grand-angle.
;   Différent de Barrel par sa formule de projection plus extrême et
;   ses différents modes de mapping sphérique.
;
; Optimisations:
;   - Précalcul du centre et du rayon
;   - Précalcul de l'inverse du rayon pour normalisation
;   - Précalcul des facteurs d'intensité
;   - Utilisation d'offsets directs pour accès mémoire
;   - Sélection du modèle de projection optimisé
; -------------------------------------------------------------------------------
Procedure FishEye_MT(*p.parametre)
  Protected x.i, y.i
  Protected dx.f, dy.f, r.f
  Protected normalized_r.f, theta.f, mapped_r.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul du centre de l'effet
  Protected cx.f = (*p\option[1] / 100.0) * lg
  Protected cy.f = (*p\option[2] / 100.0) * ht

  ; Précalcul du rayon d'effet (en pixels, basé sur la diagonale)
  Protected diagonale.f = Sqr(lg * lg + ht * ht)
  Protected rayon.f = (diagonale * *p\option[3] / 100.0) + 1.0
  Protected inv_rayon.f = 1.0 / rayon

  ; Précalcul de l'intensité de l'effet (centré sur 100)
  ; < 100 : effet inverse (défisheye), > 100 : effet fish-eye
  Protected intensity.f = (*p\option[0] - 100.0) / 100.0

  ; Type de projection fish-eye
  Protected projection_type.i = *p\option[4]

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected angle.f, inv_r.f

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Calcul de la position relative au centre
      dx = x - cx
      dy = y - cy

      ; Distance au centre
      r = Sqr(dx * dx + dy * dy)

      ; Application du fish-eye seulement dans le rayon d'effet
      If r <= rayon And r > 0.001
        ; Normalisation de la distance (0 au centre, 1 au bord du rayon)
        normalized_r = r * inv_rayon

        ; Calcul de l'angle à partir de la distance normalisée
        theta = normalized_r * #PI * 0.5

        ; Sélection du modèle de projection fish-eye
        Select projection_type
          Case 0  ; Projection stéréographique (fish-eye standard)
            ; r' = 2 × tan(θ/2)
            mapped_r = 2.0 * Tan(theta * 0.5)
            
          Case 1  ; Projection équidistante (fish-eye linéaire)
            ; r' = θ
            mapped_r = theta
            
          Case 2  ; Projection orthographique (fish-eye hémisphérique)
            ; r' = sin(θ)
            mapped_r = Sin(theta)
            
        EndSelect

        ; Application de l'intensité
        ; intensity < 0 : défisheye (correction)
        ; intensity > 0 : fish-eye (distorsion)
        mapped_r = normalized_r + (mapped_r - normalized_r) * intensity

        ; Conversion en distance absolue
        mapped_r = mapped_r * rayon

        ; Calcul des coordonnées source (maintien de l'angle, modification du rayon)
        inv_r = 1.0 / r
        src_x = cx + dx * inv_r * mapped_r
        src_y = cy + dy * inv_r * mapped_r
      Else
        ; Hors zone d'effet ou au centre exact : pas de déformation
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
; FishEye - Filtre fish-eye (objectif ultra grand-angle)
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Simule un objectif fish-eye (ultra grand-angle) avec différents types
;   de projections sphériques. Contrairement à Barrel qui utilise un modèle
;   polynomial simple, Fish-Eye utilise des projections trigonométriques
;   pour un effet plus prononcé et photographiquement correct.
;
; Paramètres utilisateur:
;   [0] Intensité (0-200, défaut=100)
;       0-99  : correction fish-eye (défisheye)
;       100   : pas d'effet
;       101-200: effet fish-eye (distorsion)
;   [1] Position X du centre (0-100%, défaut=50% = centre)
;   [2] Position Y du centre (0-100%, défaut=50% = centre)
;   [3] Rayon d'effet (0-100% de la diagonale, défaut=70%)
;   [4] Type de projection (0-2, défaut=0)
;       0 : Stéréographique (fish-eye standard, plus naturel)
;       1 : Équidistante (linéaire, fish-eye technique)
;       2 : Orthographique (hémisphérique, fish-eye extrême)
;
; Utilisations:
;   - Simulation d'objectif fish-eye 180°
;   - Correction de photos fish-eye
;   - Effets artistiques ultra grand-angle
;   - Panoramas sphériques
;   - Mapping de skybox/environnement
;
; Différences avec Barrel:
;   - Barrel : modèle polynomial (Brown-Conrady), corrections légères
;   - FishEye : projections trigonométriques, effets extrêmes
;
; Types de projection:
;   Stéréographique : préserve les angles, aspect naturel
;   Équidistante    : préserve les distances angulaires
;   Orthographique  : préserve les aires, effet hémisphérique
; -------------------------------------------------------------------------------
Procedure Fish_Eye(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Fish-Eye (Ultra grand-angle)"
    *param\remarque = "Effet fish-eye avec projections sphériques configurables"
    
    *param\info[0] = "Intensité (0-99=défisheye, 100=neutre, 101-200=fish-eye)"
    *param\info[1] = "Centre X (% largeur)"
    *param\info[2] = "Centre Y (% hauteur)"
    *param\info[3] = "Rayon (% diagonale)"
    *param\info[4] = "Projection (0=stéréo, 1=équi, 2=ortho)"
    *param\info[5] = "masque"
    
    ; Configuration intensité (0-200, défaut 100 = neutre)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 200
    *param\info_data(0, 2) = 100
    
    ; Configuration centre X (0-100%, défaut 50% = centre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Configuration centre Y (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration rayon (0-100% de la diagonale, défaut 70%)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 100
    *param\info_data(3, 2) = 70
    
    ; Configuration type de projection (0-2, défaut 0=stéréographique)
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 2
    *param\info_data(4, 2) = 0
    
    ; Configuration du masque
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 2
    *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (5 paramètres, 1 buffer destination)
  filter_start(@FishEye_MT(), 5, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 173
; FirstLine = 155
; Folding = -
; EnableXP
; DPIAware