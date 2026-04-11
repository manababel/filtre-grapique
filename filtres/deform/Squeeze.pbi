; -------------------------------------------------------------------------------
; Squeeze_MT - Compression/étirement non-uniforme avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: facteur horizontal (0-200, 100=neutre)
;                  - option[1]: facteur vertical (0-200, 100=neutre)
;                  - option[2]: position X du centre (0-100%, 50=centre)
;                  - option[3]: position Y du centre (0-100%, 50=centre)
;                  - option[4]: mode (0=linéaire, 1=radial, 2=exponentiel)
;
; Description:
;   Applique une compression ou un étirement non-uniforme de l'image.
;   Mode linéaire : compression/étirement constant
;   Mode radial : effet augmente avec la distance au centre
;   Mode exponentiel : compression/étirement progressif
;
; Optimisations:
;   - Précalcul des facteurs de compression
;   - Précalcul du centre de transformation
;   - Utilisation d'offsets directs pour accès mémoire
;   - Sélection optimisée du mode de transformation
; -------------------------------------------------------------------------------
Procedure Squeeze_MT(*p.parametre)
  Protected x.i, y.i
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul des facteurs de compression/étirement (centré sur 100)
  ; < 100 : compression (squeeze), > 100 : étirement (stretch)
  Protected factor_x.f = *p\option[0] / 100.0
  Protected factor_y.f = *p\option[1] / 100.0

  ; Précalcul du centre de transformation
  Protected cx.f = (*p\option[2] / 100.0) * lg
  Protected cy.f = (*p\option[3] / 100.0) * ht

  ; Mode de transformation (0=linéaire, 1=radial, 2=exponentiel)
  Protected mode.i = *p\option[4]

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected dx.f, dy.f, distance.f, normalized_dist.f
  Protected local_factor_x.f, local_factor_y.f
  Protected max_dist.f

  ; Précalcul de la distance maximale (pour normalisation en mode radial)
  If mode = 1
    max_dist = Sqr(lg * lg + ht * ht) * 0.5
  EndIf

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      
      ; Sélection du mode de transformation
      Select mode
        Case 0  ; ===== Mode linéaire (compression/étirement uniforme) =====
          ; Transformation directe avec facteur constant
          dx = x - cx
          dy = y - cy
          
          src_x = cx + dx / factor_x
          src_y = cy + dy / factor_y
          
        Case 1  ; ===== Mode radial (effet augmente avec la distance) =====
          ; Plus on s'éloigne du centre, plus l'effet est prononcé
          dx = x - cx
          dy = y - cy
          distance = Sqr(dx * dx + dy * dy)
          
          If distance > 0.001
            ; Normalisation de la distance (0 au centre, 1 aux bords)
            normalized_dist = distance / max_dist
            If normalized_dist > 1.0 : normalized_dist = 1.0 : EndIf
            
            ; Application du facteur progressif
            ; Au centre : facteur = 1.0 (pas d'effet)
            ; Aux bords : facteur = factor_x/factor_y (effet max)
            local_factor_x = 1.0 + (factor_x - 1.0) * normalized_dist
            local_factor_y = 1.0 + (factor_y - 1.0) * normalized_dist
            
            src_x = cx + dx / local_factor_x
            src_y = cy + dy / local_factor_y
          Else
            src_x = x
            src_y = y
          EndIf
          
        Case 2  ; ===== Mode exponentiel (compression/étirement non-linéaire) =====
          ; Effet exponentiel créant une courbure
          dx = x - cx
          dy = y - cy
          
          ; Application d'une fonction de puissance pour effet non-linéaire
          If dx >= 0
            src_x = cx + Pow(Abs(dx / (lg * 0.5)), 1.0 / factor_x) * (lg * 0.5)
          Else
            src_x = cx - Pow(Abs(dx / (lg * 0.5)), 1.0 / factor_x) * (lg * 0.5)
          EndIf
          
          If dy >= 0
            src_y = cy + Pow(Abs(dy / (ht * 0.5)), 1.0 / factor_y) * (ht * 0.5)
          Else
            src_y = cy - Pow(Abs(dy / (ht * 0.5)), 1.0 / factor_y) * (ht * 0.5)
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
        ; Pixel hors limites = noir transparent
        PokeL(*cible + offset_dst, $00000000)
      EndIf

      offset_dst + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; Squeeze - Filtre de compression/étirement non-uniforme
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une compression ou un étirement de l'image selon les axes X et Y.
;   Offre trois modes de transformation pour différents effets visuels.
;   Permet de créer des déformations allant de la simple mise à l'échelle
;   à des effets de perspective ou de lentille.
;
; Paramètres utilisateur:
;   [0] Facteur horizontal (0-200, défaut=100)
;       0-99  : Compression horizontale (squeeze)
;       100   : Pas de transformation
;       101-200: Étirement horizontal (stretch)
;       Exemple: 50 = image 2x plus étroite, 200 = image 2x plus large
;   [1] Facteur vertical (0-200, défaut=100)
;       0-99  : Compression verticale (squeeze)
;       100   : Pas de transformation
;       101-200: Étirement vertical (stretch)
;       Exemple: 50 = image 2x plus courte, 200 = image 2x plus haute
;   [2] Position X du centre (0-100%, défaut=50% = centre)
;       Point horizontal fixe de la transformation
;   [3] Position Y du centre (0-100%, défaut=50% = centre)
;       Point vertical fixe de la transformation
;   [4] Mode (0-2, défaut=0)
;       0 : Linéaire - Compression/étirement uniforme sur toute l'image
;       1 : Radial - Effet progressif du centre vers les bords
;       2 : Exponentiel - Déformation non-linéaire (effet de courbure)
;
; Utilisations:
;   - Correction d'aspect ratio (anamorphique)
;   - Effet de caricature (visage étiré/compressé)
;   - Déformation artistique
;   - Simulation de réflexion sur surface courbe
;   - Effet de lentille cylindrique
;   - Création de proportions stylisées
;   - Effet cartoon/manga (yeux agrandis)
;
; Différences entre les modes:
;   Mode Linéaire (0):
;     - Transformation uniforme sur toute l'image
;     - Équivalent à un Scale non-uniforme
;     - Préserve les lignes droites
;   
;   Mode Radial (1):
;     - Centre non affecté, effet augmente vers les bords
;     - Crée un effet de "bulle" ou "lentille"
;     - Idéal pour effets de caricature
;   
;   Mode Exponentiel (2):
;     - Compression/étirement non-linéaire
;     - Crée des courbures
;     - Effet plus organique et naturel
;
; Exemples de paramètres:
;   Visage caricature (large):
;     Facteur X=150, Y=80, Mode=1 (radial)
;     → Visage élargi avec joues gonflées
;   
;   Visage caricature (long):
;     Facteur X=80, Y=150, Mode=1 (radial)
;     → Visage allongé
;   
;   Correction anamorphique:
;     Facteur X=133, Y=100, Mode=0 (linéaire)
;     → Conversion 4:3 vers 16:9
;   
;   Effet miroir déformant:
;     Facteur X=60, Y=140, Mode=2 (exponentiel)
;     → Déformation de fête foraine
;
; Combinaisons créatives:
;   - X=50, Y=200 : Effet "reflet dans cuillère" vertical
;   - X=200, Y=50 : Effet "reflet dans cuillère" horizontal
;   - X=150, Y=150, Mode=1 : Effet loupe/fish-eye léger
;   - X=50, Y=50, Mode=1 : Effet "trou noir" (aspiration)
;
; Note: Différent de Scale car permet compression/étirement indépendant
; sur chaque axe et offre des modes de transformation non-linéaires.
; -------------------------------------------------------------------------------
Procedure Squeeze(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Squeeze (Compression/Étirement)"
    *param\remarque = "Compression ou étirement non-uniforme avec modes linéaire, radial et exponentiel"
    
    *param\info[0] = "Facteur X (0-99=compresse, 100=neutre, 101-200=étire)"
    *param\info[1] = "Facteur Y (0-99=compresse, 100=neutre, 101-200=étire)"
    *param\info[2] = "Centre X (% largeur)"
    *param\info[3] = "Centre Y (% hauteur)"
    *param\info[4] = "Mode (0=linéaire, 1=radial, 2=exponentiel)"
    *param\info[5] = "masque"
    
    ; Configuration facteur X (0-200, défaut 100 = neutre)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 200
    *param\info_data(0, 2) = 100
    
    ; Configuration facteur Y (0-200, défaut 100 = neutre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 200
    *param\info_data(1, 2) = 100
    
    ; Configuration centre X (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration centre Y (0-100%, défaut 50% = centre)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 100
    *param\info_data(3, 2) = 50
    
    ; Configuration mode (0-2, défaut 0 = linéaire)
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
  filter_start(@Squeeze_MT(), 5, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 222
; FirstLine = 204
; Folding = -
; EnableXP
; DPIAware