; -------------------------------------------------------------------------------
; Liquify_MT - Effet de liquidification (push/pull) avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: rayon du pinceau (5-200 pixels)
;                  - option[1]: intensité de l'effet (0-100)
;                  - option[2]: position X du centre (0-100%)
;                  - option[3]: position Y du centre (0-100%)
;                  - option[4]: mode (0=push, 1=pull, 2=twirl CW, 3=twirl CCW, 4=bloat, 5=pinch)
;
; Description:
;   Simule un effet de liquidification comme dans Photoshop.
;   Permet de "pousser", "tirer", "tourner" ou "gonfler" l'image localement.
;   L'effet est appliqué dans un rayon défini avec atténuation progressive.
;
; Optimisations:
;   - Précalcul du rayon et de l'inverse du rayon
;   - Précalcul du centre d'effet
;   - Test précoce de distance pour éviter calculs inutiles
;   - Utilisation d'offsets directs pour accès mémoire
; -------------------------------------------------------------------------------
Procedure Liquify_MT(*p.parametre)
  Protected x.i, y.i
  Protected dx.f, dy.f, distance.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Rayon du pinceau (zone d'effet)
  Protected radius.f = *p\option[0]
  If radius < 5.0 : radius = 5.0 : EndIf
  If radius > 200.0 : radius = 200.0 : EndIf
  Protected radius_sq.f = radius * radius  ; Rayon au carré pour optimisation
  Protected inv_radius.f = 1.0 / radius

  ; Intensité de l'effet (0-100)
  Protected intensity.f = *p\option[1] / 100.0

  ; Centre de l'effet
  Protected cx.f = (*p\option[2] / 100.0) * lg
  Protected cy.f = (*p\option[3] / 100.0) * ht

  ; Mode de liquidification
  Protected mode.i = *p\option[4]

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected normalized_dist.f, strength.f
  Protected angle.f, rotation_angle.f
  Protected offset_x.f, offset_y.f
  Protected distance_sq.f

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Calcul de la position relative au centre
      dx = x - cx
      dy = y - cy

      ; Distance au carré (optimisation)
      distance_sq = dx * dx + dy * dy

      ; Test précoce : si hors du rayon d'effet, copie directe
      If distance_sq > radius_sq
        offset_src = (y * lg + x) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        offset_dst + 4
        Continue
      EndIf

      ; Calcul de la distance réelle
      distance = Sqr(distance_sq)

      ; Normalisation de la distance (0 au centre, 1 au bord du rayon)
      normalized_dist = distance * inv_radius

      ; Calcul de la force d'atténuation (1 au centre, 0 au bord)
      ; Utilisation d'une courbe douce (cosinus)
      strength = (Cos(normalized_dist * #PI) + 1.0) * 0.5 * intensity

      ; Application du mode de liquidification
      Select mode
        Case 0  ; ===== Push (pousser) =====
          ; Pousse les pixels radialement vers l'extérieur
          If distance > 0.001
            offset_x = dx / distance * strength * radius * 0.5
            offset_y = dy / distance * strength * radius * 0.5
          Else
            offset_x = 0
            offset_y = 0
          EndIf
          
          src_x = x - offset_x
          src_y = y - offset_y

        Case 1  ; ===== Pull (tirer) =====
          ; Tire les pixels radialement vers le centre
          If distance > 0.001
            offset_x = dx / distance * strength * radius * 0.5
            offset_y = dy / distance * strength * radius * 0.5
          Else
            offset_x = 0
            offset_y = 0
          EndIf
          
          src_x = x + offset_x
          src_y = y + offset_y

        Case 2  ; ===== Twirl Clockwise (tourbillon horaire) =====
          ; Rotation horaire autour du centre
          If distance > 0.001
            angle = ATan2(dy, dx)
            rotation_angle = strength * #PI * 0.5  ; Maximum 90° rotation
            angle = angle - rotation_angle
            
            src_x = cx + distance * Cos(angle)
            src_y = cy + distance * Sin(angle)
          Else
            src_x = x
            src_y = y
          EndIf

        Case 3  ; ===== Twirl Counter-Clockwise (tourbillon anti-horaire) =====
          ; Rotation anti-horaire autour du centre
          If distance > 0.001
            angle = ATan2(dy, dx)
            rotation_angle = strength * #PI * 0.5
            angle = angle + rotation_angle
            
            src_x = cx + distance * Cos(angle)
            src_y = cy + distance * Sin(angle)
          Else
            src_x = x
            src_y = y
          EndIf

        Case 4  ; ===== Bloat (gonfler) =====
          ; Gonfle/agrandit la zone centrale
          If distance > 0.001
            Protected bloat_factor.f
            bloat_factor = 1.0 - strength * 0.5  ; Réduction du rayon
            
            src_x = cx + dx * bloat_factor
            src_y = cy + dy * bloat_factor
          Else
            src_x = x
            src_y = y
          EndIf

        Case 5  ; ===== Pinch (pincer) =====
          ; Pince/réduit la zone centrale
          If distance > 0.001
            Protected pinch_factor.f
            pinch_factor = 1.0 + strength * 0.5  ; Augmentation du rayon
            
            src_x = cx + dx * pinch_factor
            src_y = cy + dy * pinch_factor
          Else
            src_x = x
            src_y = y
          EndIf

      EndSelect

      ; Conversion en entiers et vérification des limites
      src_x_int = Int(src_x)
      src_y_int = Int(src_y)

      If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
        ; Échantillonnage du pixel source
        offset_src = (src_y_int * lg + src_x_int) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))
      Else
        ; Pixel hors limites = copie du pixel original
        offset_src = (y * lg + x) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))
      EndIf

      offset_dst + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; Liquify - Filtre de liquidification (déformation locale interactive)
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Simule l'outil de liquidification (Liquify) des logiciels de retouche photo.
;   Permet de déformer localement l'image en "poussant", "tirant", "tournant"
;   ou "gonflant" les pixels dans un rayon défini. L'effet s'atténue
;   progressivement du centre vers les bords du pinceau.
;
; Paramètres utilisateur:
;   [0] Rayon du pinceau (5-200 pixels, défaut=50)
;       Taille de la zone d'effet
;       5-30  : Petit pinceau (détails fins)
;       30-80 : Pinceau moyen (retouches standards)
;       80-150: Grand pinceau (déformations larges)
;       150-200: Très grand pinceau (effets globaux)
;   [1] Intensité (0-100, défaut=50)
;       Force de la déformation
;       0-30  : Effet subtil (retouches délicates)
;       30-70 : Effet modéré (recommandé)
;       70-100: Effet fort (déformations prononcées)
;   [2] Position X du centre (0-100%, défaut=50%)
;       Position horizontale du centre d'effet
;   [3] Position Y du centre (0-100%, défaut=50%)
;       Position verticale du centre d'effet
;   [4] Mode (0-5, défaut=0)
;       0 : Push (Pousser) - Repousse les pixels vers l'extérieur
;       1 : Pull (Tirer) - Attire les pixels vers le centre
;       2 : Twirl CW (Tourbillon horaire) - Rotation dans le sens horaire
;       3 : Twirl CCW (Tourbillon anti-horaire) - Rotation inverse
;       4 : Bloat (Gonfler) - Agrandit la zone (effet loupe/fish-eye)
;       5 : Pinch (Pincer) - Réduit la zone (effet aspiration)
;
; Utilisations:
;   - Retouche de portraits (affiner nez, agrandir yeux, sourire)
;   - Correction de distorsions locales
;   - Caricatures et déformations artistiques
;   - Effets créatifs de morphing
;   - Correction de perspective locale
;   - Effets de mouvement fluide
;   - Stylisation de personnages
;
; Description des modes:
;   Push (0):
;     - Pousse les pixels radialement depuis le centre
;     - Utile pour élargir des zones (joues, épaules)
;     - Comme pousser dans de la pâte à modeler
;   
;   Pull (1):
;     - Attire les pixels vers le centre
;     - Utile pour affiner des zones (nez, taille)
;     - Effet d'aspiration douce
;   
;   Twirl CW/CCW (2/3):
;     - Tourne les pixels autour du centre
;     - Crée des spirales et tourbillons
;     - Maximum 90° de rotation au centre
;   
;   Bloat (4):
;     - Agrandit/gonfle la zone centrale
;     - Effet fish-eye ou loupe locale
;     - Utile pour agrandir les yeux en portrait
;   
;   Pinch (5):
;     - Réduit/pince la zone centrale
;     - Effet d'aspiration vers un point
;     - Inverse de Bloat
;
; Exemples de paramètres:
;   Agrandir les yeux (portrait):
;     Rayon=30, Intensité=40, Mode=4 (Bloat)
;     Position: centre de chaque œil
;   
;   Affiner le nez:
;     Rayon=25, Intensité=30, Mode=5 (Pinch)
;     Position: centre du nez
;   
;   Sourire plus large:
;     Rayon=40, Intensité=35, Mode=0 (Push)
;     Position: coins de la bouche
;   
;   Effet tourbillon artistique:
;     Rayon=100, Intensité=70, Mode=2 (Twirl CW)
;     Position: point focal
;
; Conseils d'utilisation:
;   - Commencez avec une intensité faible (20-30%)
;   - Utilisez plusieurs petites applications plutôt qu'une forte
;   - Pour les portraits, travaillez symétriquement
;   - Bloat est excellent pour les yeux (rayon 25-35)
;   - Pinch est idéal pour affiner (nez, menton)
;   - Push/Pull pour remodeler contours
;
; Limitation actuelle:
;   Cette version applique un effet unique à une position fixe.
;   Pour une vraie liquidification interactive, il faudrait:
;   - Application cumulative de multiples "coups de pinceau"
;   - Interface de dessin pour tracer les déformations
;   - Historique d'annulation/rétablissement
;   - Visualisation en temps réel du pinceau
;
; Note technique:
;   L'atténuation utilise une courbe cosinus pour une transition douce.
;   La formule: strength = (cos(dist × π) + 1) / 2
;   Cela donne une transition plus naturelle qu'une atténuation linéaire.
;
; Différences avec d'autres filtres:
;   - Mesh Warp : Grille structurée, déformation globale
;   - Liquify : Déformation locale libre, comme "peindre" la déformation
;   - Spherize/Pinch : Effet global fixe
;   - Liquify : Effet local positionnable
; -------------------------------------------------------------------------------
Procedure Liquify(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Liquify (Liquidification)"
    *param\remarque = "Déformation locale type push/pull avec atténuation progressive"
    
    *param\info[0] = "Rayon pinceau (pixels)"
    *param\info[1] = "Intensité (force de déformation)"
    *param\info[2] = "Position X (% largeur)"
    *param\info[3] = "Position Y (% hauteur)"
    *param\info[4] = "Mode (0=push, 1=pull, 2=twirl↻, 3=twirl↺, 4=bloat, 5=pinch)"
    *param\info[5] = "masque"
    
    ; Configuration rayon (5-200 pixels, défaut 50)
    *param\info_data(0, 0) = 5
    *param\info_data(0, 1) = 200
    *param\info_data(0, 2) = 50
    
    ; Configuration intensité (0-100, défaut 50)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Configuration position X (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration position Y (0-100%, défaut 50% = centre)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 100
    *param\info_data(3, 2) = 50
    
    ; Configuration mode (0-5, défaut 0 = push)
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 5
    *param\info_data(4, 2) = 0
    
    ; Configuration du masque
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 2
    *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (5 paramètres, 1 buffer destination)
  filter_start(@Liquify_MT(), 5, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 310
; FirstLine = 292
; Folding = -
; EnableXP
; DPIAware