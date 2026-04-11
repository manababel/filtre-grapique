Procedure gouache_MT(*p.parametre)
  ; ============================================================================
  ; DÉCLARATION DES VARIABLES
  ; ============================================================================
  
  ; --- Dimensions de l'image ---
  Protected w = *p\lg  ; Largeur de l'image en pixels
  Protected h = *p\ht  ; Hauteur de l'image en pixels
  
  ; --- Coordonnées ---
  Protected x, y, i, j  ; Positions et indices de boucle
  
  ; --- Composantes ARGB ---
  Protected a, r, g, b              ; Alpha, Rouge, Vert, Bleu du pixel de sortie
  Protected rC, gC, bC              ; RGB du pixel central
  Protected rN, gN, bN              ; RGB des pixels voisins
  
  ; --- Coups de pinceau ---
  Protected sumR.f, sumG.f, sumB.f  ; Sommes pour moyennage directionnel
  Protected count.f                  ; Nombre de pixels échantillonnés
  
  ; --- Texture et variation ---
  Protected noise.f                  ; Bruit pour texture de peinture
  Protected brushNoise.f             ; Variation de coup de pinceau
  
  ; --- Détection de structure ---
  Protected dx.f, dy.f               ; Gradients pour direction locale
  Protected angle.f                  ; Angle du coup de pinceau
  Protected edge.f                   ; Force du contour
  
  ; --- Pointeurs mémoire ---
  Protected *src.Pixel32            ; Pointeur vers pixel source (lecture)
  Protected *dst.Pixel32            ; Pointeur vers pixel destination (écriture)
  
  ; ============================================================================
  ; LECTURE DES PARAMÈTRES
  ; ============================================================================
  
  ; --- Paramètre 0 : Taille des coups de pinceau ---
  Protected brushSize = *p\option[0]
  If brushSize < 1 : brushSize = 1 : EndIf
  If brushSize > 12 : brushSize = 12 : EndIf
  
  ; --- Paramètre 1 : Intensité de texture ---
  Protected textureStrength.f = *p\option[1] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 2 : Opacité/Matité ---
  Protected opacity.f = *p\option[2] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 3 : Quantification des couleurs ---
  Protected colorLevels = *p\option[3]
  If colorLevels < 3 : colorLevels = 3 : EndIf
  If colorLevels > 24 : colorLevels = 24 : EndIf
  
  ; --- Paramètre 4 : Direction des coups de pinceau ---
  Protected brushDirection = *p\option[4]  ; 0=Auto, 1=H, 2=V, 3=Diag1, 4=Diag2
  
  ; --- Paramètre 5 : Contraste ---
  Protected contrastBoost.f = *p\option[5] * 0.01  ; 50-200 -> 0.5-2.0
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  
  Protected startY = (*p\thread_pos * h) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * h) / *p\thread_max
  
  ; --- Protection des bordures ---
  Protected border = brushSize + 1
  If startY < border : startY = border : EndIf
  If endY > h - border : endY = h - border : EndIf
  
  ; ============================================================================
  ; TRAITEMENT PRINCIPAL - BOUCLE SUR CHAQUE PIXEL
  ; ============================================================================
  
  For y = startY To endY - 1
    For x = border To w - border - 1
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 1 : LECTURE DU PIXEL CENTRAL
      ; ------------------------------------------------------------------------
      *src = *p\addr[0] + ((y * w + x) << 2)
      GetARGB(*src\l, a, rC, gC, bC)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 2 : DÉTECTION DE LA DIRECTION LOCALE (si mode auto)
      ; ------------------------------------------------------------------------
      
      If brushDirection = 0  ; Mode automatique
        ; Calcule le gradient pour déterminer la direction du pinceau
        *src = *p\addr[0] + ((y * w + (x - 1)) << 2)
        GetARGB(*src\l, a, rN, gN, bN)
        Protected grayL.f = rN * 0.299 + gN * 0.587 + bN * 0.114
        
        *src = *p\addr[0] + ((y * w + (x + 1)) << 2)
        GetARGB(*src\l, a, rN, gN, bN)
        Protected grayR.f = rN * 0.299 + gN * 0.587 + bN * 0.114
        
        *src = *p\addr[0] + (((y - 1) * w + x) << 2)
        GetARGB(*src\l, a, rN, gN, bN)
        Protected grayU.f = rN * 0.299 + gN * 0.587 + bN * 0.114
        
        *src = *p\addr[0] + (((y + 1) * w + x) << 2)
        GetARGB(*src\l, a, rN, gN, bN)
        Protected grayD.f = rN * 0.299 + gN * 0.587 + bN * 0.114
        
        dx = grayR - grayL
        dy = grayD - grayU
        
        ; Calcule l'angle perpendiculaire au gradient (direction du pinceau)
        angle = ATan2(dy, dx) + #PI / 2.0
        
        ; Détection de contour
        edge = Sqr(dx * dx + dy * dy) / 255.0
      Else
        ; Direction fixe selon le paramètre
        Select brushDirection
          Case 1 : angle = 0.0                ; Horizontal
          Case 2 : angle = #PI / 2.0          ; Vertical
          Case 3 : angle = #PI / 4.0          ; Diagonale 45°
          Case 4 : angle = -#PI / 4.0         ; Diagonale -45°
        EndSelect
        edge = 0.3
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 3 : ÉCHANTILLONNAGE DIRECTIONNEL (Coup de pinceau)
      ; ------------------------------------------------------------------------
      ; Simule un coup de pinceau en échantillonnant le long d'une direction
      
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : count = 0.0
      
      Protected cosAngle.f = Cos(angle)
      Protected sinAngle.f = Sin(angle)
      
      ; Échantillonne le long de la direction du pinceau
      For i = -brushSize To brushSize
        Protected offsetX.f = i * cosAngle
        Protected offsetY.f = i * sinAngle
        
        Protected px = x + Int(offsetX)
        Protected py = y + Int(offsetY)
        
        ; Vérifie les limites
        If px >= 0 And px < w And py >= 0 And py < h
          ; Poids basé sur la distance
          Protected dist.f = Abs(i)
          Protected weight.f = 1.0 / (1.0 + dist * 0.3)
          
          *src = *p\addr[0] + ((py * w + px) << 2)
          GetARGB(*src\l, a, rN, gN, bN)
          
          sumR + rN * weight
          sumG + gN * weight
          sumB + bN * weight
          count + weight
        EndIf
      Next
      
      ; Moyennes pondérées
      Protected avgR.f = sumR / count
      Protected avgG.f = sumG / count
      Protected avgB.f = sumB / count
      
      ; Mélange entre original et coup de pinceau
      r = Int(rC * 0.3 + avgR * 0.7)
      g = Int(gC * 0.3 + avgG * 0.7)
      b = Int(bC * 0.3 + avgB * 0.7)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 4 : QUANTIFICATION DES COULEURS (Couleurs mates)
      ; ------------------------------------------------------------------------
      ; La gouache a des couleurs opaques et moins nuancées
      
      Protected stepSize.f = 255.0 / (colorLevels - 1)
      
      r = Int(r / stepSize + 0.5) * stepSize
      g = Int(g / stepSize + 0.5) * stepSize
      b = Int(b / stepSize + 0.5) * stepSize
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 5 : BOOST DE CONTRASTE
      ; ------------------------------------------------------------------------
      ; La gouache a des contrastes plus marqués que l'aquarelle
      
      If contrastBoost <> 1.0
        ; Contraste autour du point médian (128)
        r = Int(128 + (r - 128) * contrastBoost)
        g = Int(128 + (g - 128) * contrastBoost)
        b = Int(128 + (b - 128) * contrastBoost)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 6 : TEXTURE DE PEINTURE ÉPAISSE
      ; ------------------------------------------------------------------------
      ; Simule l'épaisseur et les irrégularités de la gouache
      
      If textureStrength > 0.01
        ; Bruit pour texture globale
        Protected seed1 = (x * 23456 + y * 78901) & $7FFFFFFF
        Protected noise2
        noise2 = ((seed1 % 1000) - 500) / 500.0
        noise= noise2
        
        ; Bruit directionnel (suit le coup de pinceau)
        Protected seed2 = (Int(x * cosAngle + y * sinAngle) * 34567) & $7FFFFFFF
        Protected brushNoise2 = ((seed2 % 1000) - 500) / 500.0
        brushNoise = brushNoise2
        
        ; Combine les deux types de bruit
        Protected totalNoise.f = (noise * 0.4 + brushNoise * 0.6) * textureStrength * 30.0
        
        r + Int(totalNoise)
        g + Int(totalNoise * 0.9)
        b + Int(totalNoise * 1.1)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 7 : EFFET OPACITÉ/MATITÉ
      ; ------------------------------------------------------------------------
      ; La gouache a un aspect mat et couvrant
      ; Simule en réduisant légèrement les extrêmes
      
      Protected matteEffect.f = opacity * 0.15
      
      ; Rapproche légèrement les valeurs vers le milieu pour l'effet mat
      If r > 128
        r = Int(r - (r - 128) * matteEffect)
      Else
        r = Int(r + (128 - r) * matteEffect * 0.5)
      EndIf
      
      If g > 128
        g = Int(g - (g - 128) * matteEffect)
      Else
        g = Int(g + (128 - g) * matteEffect * 0.5)
      EndIf
      
      If b > 128
        b = Int(b - (b - 128) * matteEffect)
      Else
        b = Int(b + (128 - b) * matteEffect * 0.5)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 8 : VARIATIONS DE COUCHE (Épaisseur variable)
      ; ------------------------------------------------------------------------
      ; Simule les zones où la peinture est plus ou moins épaisse
      
      Protected layerSeed = ((x / 3) * 45678 + (y / 3) * 12345) & $7FFFFFFF
      Protected layerVariation2 = ((layerSeed % 1000) - 500) / 5000.0
      Protected layerVariation.f = layerVariation2
      
      Protected brightness.f = (r + g + b) / (3.0 * 255.0)
      
      ; Les zones claires peuvent être plus épaisses (plus opaques)
      If brightness > 0.5
        Protected thicknessEffect = layerVariation * 15.0
        r + Int(thicknessEffect)
        g + Int(thicknessEffect)
        b + Int(thicknessEffect)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 9 : RENFORCEMENT DES CONTOURS
      ; ------------------------------------------------------------------------
      ; La gouache crée des bords nets entre les zones de couleur
      
      If edge > 0.4
        ; Assombrit légèrement les contours
        Protected edgeDarken.f = (edge - 0.4) * 0.3
        r = Int(r * (1.0 - edgeDarken))
        g = Int(g * (1.0 - edgeDarken))
        b = Int(b * (1.0 - edgeDarken))
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 10 : CLAMPING (LIMITATION DES VALEURS)
      ; ------------------------------------------------------------------------
      
      If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 11 : ÉCRITURE DU PIXEL RÉSULTAT
      ; ------------------------------------------------------------------------
      
      *dst = *p\addr[1] + ((y * w + x) << 2)
      *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      
    Next  ; Pixel suivant (x)
  Next    ; Ligne suivante (y)
  
EndProcedure

; ==============================================================================
; PROCÉDURE D'INITIALISATION DU FILTRE
; ==============================================================================

Procedure gouache(*param.parametre)
  
  ; Si appelé en mode "info", on configure les paramètres de l'interface
  If *param\info_active
    
    ; --- Métadonnées du filtre ---
    *param\typ = #FilterType_Artistic         ; Catégorie : artistique
    *param\subtype = #Artistic_Material
    *param\name = "Gouache"                   ; Nom affiché
    *param\remarque = "Simule une peinture à la gouache avec texture opaque et coups de pinceau"
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 0 : TAILLE DES COUPS DE PINCEAU
    ; --------------------------------------------------------------------------
    *param\info[0] = "Taille pinceau"
    *param\info_data(0, 0) = 1     ; Valeur minimale (très fin)
    *param\info_data(0, 1) = 12    ; Valeur maximale (très large)
    *param\info_data(0, 2) = 5     ; Valeur par défaut (moyen)
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 1 : INTENSITÉ DE TEXTURE
    ; --------------------------------------------------------------------------
    *param\info[1] = "Texture"
    *param\info_data(1, 0) = 0     ; Min = lisse
    *param\info_data(1, 1) = 100   ; Max = très texturé
    *param\info_data(1, 2) = 50    ; Défaut = moyen
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 2 : OPACITÉ/MATITÉ
    ; --------------------------------------------------------------------------
    *param\info[2] = "Matité"
    *param\info_data(2, 0) = 0     ; Transparent/brillant
    *param\info_data(2, 1) = 100   ; Très opaque/mat
    *param\info_data(2, 2) = 70    ; Défaut = assez mat
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 3 : NIVEAUX DE COULEUR
    ; --------------------------------------------------------------------------
    *param\info[3] = "Niveaux couleur"
    *param\info_data(3, 0) = 3     ; Peu de couleurs
    *param\info_data(3, 1) = 24    ; Beaucoup de couleurs
    *param\info_data(3, 2) = 10    ; Défaut = moyen
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 4 : DIRECTION DES COUPS DE PINCEAU
    ; --------------------------------------------------------------------------
    *param\info[4] = "Direction (0=Auto/1=H/2=V/3=D1/4=D2)"
    *param\info_data(4, 0) = 0     ; 0 = Automatique
    *param\info_data(4, 1) = 4     ; 4 = Diagonale 2
    *param\info_data(4, 2) = 0     ; Défaut = Auto
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 5 : CONTRASTE
    ; --------------------------------------------------------------------------
    *param\info[5] = "Contraste (100=normal)"
    *param\info_data(5, 0) = 50    ; Faible contraste
    *param\info_data(5, 1) = 200   ; Contraste élevé
    *param\info_data(5, 2) = 130   ; Défaut = légèrement boosté
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 6 : MASQUE (standard)
    ; --------------------------------------------------------------------------
    *param\info[6] = "masque"
    *param\info_data(6, 0) = 0 
    *param\info_data(6, 1) = 2
    *param\info_data(6, 2) = 0
    
    ProcedureReturn  ; Sort sans lancer le traitement
  EndIf
  
  ; Si pas en mode "info", on lance le traitement multithreadé
  ; Paramètres : fonction worker, nombre de passes, nombre de buffers
  filter_start(@gouache_MT(), 3, 1)
  
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 307
; FirstLine = 247
; Folding = -
; EnableXP
; DPIAware