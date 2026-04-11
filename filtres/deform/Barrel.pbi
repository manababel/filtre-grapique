; -------------------------------------------------------------------------------
; Barrel_MT - Distorsion en barillet/coussinet avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: coefficient de distorsion (0-200, 100=neutre)
;                  - option[1]: position X du centre (0-100%, 50=centre)
;                  - option[2]: position Y du centre (0-100%, 50=centre)
;                  - option[3]: correction secondaire (0-100, 0=désactivé)
;
; Description:
;   Applique une distorsion radiale simulant les aberrations optiques.
;   < 100 : distorsion en coussinet (pincushion) - bords pincés vers l'intérieur
;   = 100 : pas de distorsion
;   > 100 : distorsion en barillet (barrel) - bords bombés vers l'extérieur
;
; Optimisations:
;   - Précalcul du centre et des facteurs de normalisation
;   - Précalcul des coefficients de distorsion
;   - Utilisation d'offsets directs pour accès mémoire
;   - Calcul optimisé de la distance normalisée
; -------------------------------------------------------------------------------
Procedure Barrel_MT(*p.parametre)
  Protected x.i, y.i
  Protected dx.f, dy.f, r.f, r2.f
  Protected distortion_factor.f, corrected_r.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul du centre de la distorsion
  Protected cx.f = (*p\option[1] / 100.0) * lg
  Protected cy.f = (*p\option[2] / 100.0) * ht

  ; Précalcul de la distance de normalisation (demi-diagonale)
  Protected diagonale.f = Sqr(lg * lg + ht * ht)
  Protected norm_dist.f = diagonale * 0.5
  Protected inv_norm_dist.f = 1.0 / norm_dist

  ; Précalcul du coefficient de distorsion principal (centré sur 100)
  ; k1 : coefficient de distorsion radiale (plage typique : -0.5 à +0.5)
  ; < 0 : pincushion (coussinet), > 0 : barrel (barillet)
  Protected k1.f = (*p\option[0] - 100.0) / 100.0

  ; Coefficient de correction secondaire (distorsion d'ordre supérieur)
  ; Permet d'affiner la correction pour les distorsions complexes
  Protected k2.f = (*p\option[3] / 100.0) * 0.1

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected normalized_r.f, r4.f

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Calcul de la position relative au centre
      dx = x - cx
      dy = y - cy

      ; Distance au centre
      r = Sqr(dx * dx + dy * dy)

      ; Normalisation de la distance (0 au centre, ~1 aux bords)
      normalized_r = r * inv_norm_dist

      ; Calcul de la distorsion radiale (modèle de Brown-Conrady simplifié)
      ; r' = r × (1 + k1×r² + k2×r⁴)
      r2 = normalized_r * normalized_r
      r4 = r2 * r2
      distortion_factor = 1.0 + k1 * r2 + k2 * r4

      ; Application de la distorsion
      If r > 0.001  ; Évite division par zéro au centre
        corrected_r = r * distortion_factor
        
        ; Calcul des coordonnées source
        src_x = cx + (dx / r) * corrected_r
        src_y = cy + (dy / r) * corrected_r
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
; Barrel - Filtre de distorsion en barillet/coussinet
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Simule ou corrige les distorsions optiques radiales typiques des objectifs
;   photographiques. Utilise le modèle de distorsion de Brown-Conrady.
;
; Paramètres utilisateur:
;   [0] Distorsion (0-200, défaut=100)
;       0-99  : distorsion en coussinet (pincushion)
;               - Bords pincés vers l'intérieur
;               - Typique des téléobjectifs
;       100   : pas de distorsion
;       101-200: distorsion en barillet (barrel)
;               - Bords bombés vers l'extérieur
;               - Typique des grand-angles/fish-eye
;   [1] Position X du centre (0-100%, défaut=50% = centre)
;   [2] Position Y du centre (0-100%, défaut=50% = centre)
;   [3] Correction secondaire (0-100, défaut=0)
;       Affine la correction pour les distorsions complexes
;       Augmenter si la correction simple n'est pas suffisante
;
; Utilisations:
;   - Correction de distorsion d'objectif photo
;   - Simulation d'effet fish-eye léger
;   - Redressement de photos grand-angle
;   - Correction de GoPro et caméras d'action
;   - Effets artistiques de déformation optique
;
; Note technique:
;   Formule de distorsion radiale (Brown-Conrady) :
;   r' = r × (1 + k1×r² + k2×r⁴)
;   où r est la distance normalisée au centre
;
; Exemples de correction:
;   - GoPro Hero : k1 ≈ -30 à -40 (coussinet)
;   - Fish-eye léger : k1 ≈ +40 à +60 (barillet)
; -------------------------------------------------------------------------------
Procedure Barrel(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Barrel (Distorsion radiale)"
    *param\remarque = "Correction/simulation de distorsion en barillet ou coussinet"
    
    *param\info[0] = "Distorsion (0-99=coussinet, 100=neutre, 101-200=barillet)"
    *param\info[1] = "Centre X (% largeur)"
    *param\info[2] = "Centre Y (% hauteur)"
    *param\info[3] = "Correction secondaire (affine la distorsion)"
    *param\info[4] = "masque"
    
    ; Configuration distorsion (0-200, défaut 100 = neutre)
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
    
    ; Configuration correction secondaire (0-100, défaut 0)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 100
    *param\info_data(3, 2) = 0
    
    ; Configuration du masque
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 2
    *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (4 paramètres, 1 buffer destination)
  filter_start(@Barrel_MT(), 4, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 154
; FirstLine = 131
; Folding = -
; EnableXP
; DPIAware