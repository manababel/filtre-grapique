Procedure gouache_MT(*FilterCtx.FilterParams)

  With *FilterCtx
  ; --- Dimensions de l'image ---
  Protected w = \image_lg[0]  ; Largeur de l'image en pixels
  Protected h = \image_ht[0]  ; Hauteur de l'image en pixels
  
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
  Protected brushSize = \option[0]
  If brushSize < 1 : brushSize = 1 : EndIf
  If brushSize > 12 : brushSize = 12 : EndIf
  
  ; --- Paramètre 1 : Intensité de texture ---
  Protected textureStrength.f = \option[1] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 2 : Opacité/Matité ---
  Protected opacity.f = \option[2] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 3 : Quantification des couleurs ---
  Protected colorLevels = \option[3]
  If colorLevels < 3 : colorLevels = 3 : EndIf
  If colorLevels > 24 : colorLevels = 24 : EndIf
  
  ; --- Paramètre 4 : Direction des coups de pinceau ---
  Protected brushDirection = \option[4]  ; 0=Auto, 1=H, 2=V, 3=Diag1, 4=Diag2
  
  ; --- Paramètre 5 : Contraste ---
  Protected contrastBoost.f = \option[5] * 0.01  ; 50-200 -> 0.5-2.0
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  
  Protected startY = (\thread_pos * h) / \thread_max
  Protected endY   = ((\thread_pos + 1) * h) / \thread_max
  
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
      *src = \addr[0] + ((y * w + x) << 2)
      GetARGB(*src\l, a, rC, gC, bC)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 2 : DÉTECTION DE LA DIRECTION LOCALE (si mode auto)
      ; ------------------------------------------------------------------------
      
      If brushDirection = 0  ; Mode automatique
        ; Calcule le gradient pour déterminer la direction du pinceau
        *src = \addr[0] + ((y * w + (x - 1)) << 2)
        GetARGB(*src\l, a, rN, gN, bN)
        Protected grayL.f = rN * 0.299 + gN * 0.587 + bN * 0.114
        
        *src = \addr[0] + ((y * w + (x + 1)) << 2)
        GetARGB(*src\l, a, rN, gN, bN)
        Protected grayR.f = rN * 0.299 + gN * 0.587 + bN * 0.114
        
        *src = \addr[0] + (((y - 1) * w + x) << 2)
        GetARGB(*src\l, a, rN, gN, bN)
        Protected grayU.f = rN * 0.299 + gN * 0.587 + bN * 0.114
        
        *src = \addr[0] + (((y + 1) * w + x) << 2)
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
          
          *src = \addr[0] + ((py * w + px) << 2)
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
      
      *dst = \addr[1] + ((y * w + x) << 2)
      *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      
    Next  ; Pixel suivant (x)
  Next    ; Ligne suivante (y)
  EndWith
EndProcedure

; -----------------------------------------------------------------------------
; PROCÉDURE D'APPEL : gouacheEx
; -----------------------------------------------------------------------------
Procedure gouacheEx(*FilterCtx.FilterParams)
  Restore gouache_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@gouache_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; -----------------------------------------------------------------------------
; INTERFACE SIMPLIFIÉE
; -----------------------------------------------------------------------------
Procedure gouache(source, cible, mask, brushSize=5, texture=50, matte=70, levels=10, dir=0, contrast=130)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = brushSize
    \option[1] = texture
    \option[2] = matte
    \option[3] = levels
    \option[4] = dir
    \option[5] = contrast
  EndWith
  gouacheEx(FilterCtx)
EndProcedure

; -----------------------------------------------------------------------------
; DONNÉES DU FILTRE
; -----------------------------------------------------------------------------
DataSection
  gouache_Data:
  Data.s "Gouache"
  Data.s "Simule une peinture à la gouache avec texture opaque et coups de pinceau"
  Data.i #FilterType_Artistic
  Data.i #Artistic_Material
  
  Data.s "Taille pinceau"
  Data.i 1, 12, 5
  
  Data.s "Texture"
  Data.i 0, 100, 50
  
  Data.s "Matité"
  Data.i 0, 100, 70
  
  Data.s "Niveaux couleur"
  Data.i 3, 24, 10
  
  Data.s "Direction (0=Auto/1=H/2=V/3=D1/4=D2)"
  Data.i 0, 4, 0
  
  Data.s "Contraste (100=normal)"
  Data.i 50, 200, 130
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 5
; Folding = -
; EnableXP
; DPIAware