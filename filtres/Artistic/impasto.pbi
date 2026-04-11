Procedure impasto_MT(*p.parametre)
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
  
  ; --- Relief et épaisseur ---
  Protected heightMap.f              ; Carte de hauteur (relief)
  Protected relief.f                 ; Intensité du relief local
  Protected thickness.f              ; Épaisseur de la peinture
  
  ; --- Coup de pinceau ---
  Protected sumR.f, sumG.f, sumB.f  ; Sommes pour effet directionnel
  Protected count.f                  ; Nombre de pixels échantillonnés
  
  ; --- Direction et structure ---
  Protected dx.f, dy.f               ; Gradients
  Protected angle.f                  ; Angle du coup de pinceau
  Protected brushStrength.f          ; Force du trait
  
  ; --- Texture ---
  Protected noise.f                  ; Bruit pour texture de peinture
  Protected impastoNoise.f          ; Texture spécifique impasto
  
  ; --- Éclairage du relief ---
  Protected nx.f, ny.f, nz.f        ; Normale du relief
  Protected len.f                    ; Longueur pour normalisation
  Protected lighting.f               ; Éclairage simulé
  
  ; --- Pointeurs mémoire ---
  Protected *src.Pixel32            ; Pointeur vers pixel source (lecture)
  Protected *dst.Pixel32            ; Pointeur vers pixel destination (écriture)
  
  ; ============================================================================
  ; LECTURE DES PARAMÈTRES
  ; ============================================================================
  
  ; --- Paramètre 0 : Épaisseur de la peinture ---
  Protected paintThickness.f = *p\option[0] * 0.01  ; 1-100 -> 0.01-1.0
  
  ; --- Paramètre 1 : Taille du pinceau ---
  Protected brushSize = *p\option[1]
  If brushSize < 2 : brushSize = 2 : EndIf
  If brushSize > 15 : brushSize = 15 : EndIf
  
  ; --- Paramètre 2 : Relief/Hauteur ---
  Protected reliefStrength.f = *p\option[2] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 3 : Texture de la matière ---
  Protected textureAmount.f = *p\option[3] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 4 : Direction des coups ---
  Protected strokeDirection = *p\option[4]  ; 0=Auto, 1-8=Directions fixes
  
  ; --- Paramètre 5 : Intensité de l'éclairage ---
  Protected lightIntensity.f = *p\option[5] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Direction de la lumière (fixe : nord-ouest en hauteur) ---
  Protected lx.f = -0.5
  Protected ly.f = -0.5
  Protected lz.f = 0.7
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  
  Protected startY = (*p\thread_pos * h) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * h) / *p\thread_max
  
  ; --- Protection des bordures ---
  Protected border = brushSize + 2
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
      ; ÉTAPE 2 : CALCUL DE LA CARTE DE HAUTEUR (Luminosité)
      ; ------------------------------------------------------------------------
      ; Les zones claires = épaisseur importante, zones sombres = moins de matière
      
      heightMap = (rC * 0.299 + gC * 0.587 + bC * 0.114) / 255.0
      
      ; Accentue le relief
      heightMap = heightMap * paintThickness
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 3 : DÉTECTION DE LA DIRECTION DU PINCEAU
      ; ------------------------------------------------------------------------
      
      If strokeDirection = 0  ; Mode automatique
        ; Calcule le gradient pour direction perpendiculaire
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
        
        dx = (grayR - grayL) / 255.0
        dy = (grayD - grayU) / 255.0
        
        ; Direction perpendiculaire au gradient
        angle = ATan2(dy, dx) + #PI / 2.0
        
        ; Force du trait basée sur le gradient
        brushStrength = Sqr(dx * dx + dy * dy)
      Else
        ; Direction fixe
        Protected angleStep.f = #PI / 4.0  ; 45 degrés
        angle = (strokeDirection - 1) * angleStep
        brushStrength = 0.5
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 4 : APPLICATION DU COUP DE PINCEAU ÉPAIS
      ; ------------------------------------------------------------------------
      ; Échantillonne le long de la direction avec poids variable
      
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : count = 0.0
      
      Protected cosAngle.f = Cos(angle)
      Protected sinAngle.f = Sin(angle)
      
      ; Échantillonne avec un pinceau épais
      For i = -brushSize To brushSize
        For j = -2 To 2  ; Largeur du pinceau
          Protected offsetX.f = i * cosAngle - j * sinAngle
          Protected offsetY.f = i * sinAngle + j * cosAngle
          
          Protected px = x + Int(offsetX)
          Protected py = y + Int(offsetY)
          
          If px >= 0 And px < w And py >= 0 And py < h
            ; Poids selon la distance au centre du trait
            Protected distCenter.f = Sqr(i * i * 0.5 + j * j * 2.0)
            Protected weight.f = 1.0 / (1.0 + distCenter * 0.2)
            
            *src = *p\addr[0] + ((py * w + px) << 2)
            GetARGB(*src\l, a, rN, gN, bN)
            
            sumR + rN * weight
            sumG + gN * weight
            sumB + bN * weight
            count + weight
          EndIf
        Next
      Next
      
      Protected avgR.f = sumR / count
      Protected avgG.f = sumG / count
      Protected avgB.f = sumB / count
      
      ; Mélange avec original (plus de matière = plus d'effet)
      Protected blendFactor.f = 0.2 + paintThickness * 0.6
      r = Int(rC * (1.0 - blendFactor) + avgR * blendFactor)
      g = Int(gC * (1.0 - blendFactor) + avgG * blendFactor)
      b = Int(bC * (1.0 - blendFactor) + avgB * blendFactor)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 5 : CALCUL DU RELIEF ET DE LA NORMALE
      ; ------------------------------------------------------------------------
      ; Pour simuler l'éclairage de la peinture épaisse
      
      If reliefStrength > 0.01
        ; Calcule la normale en fonction du gradient de hauteur
        Protected heightL.f, heightR.f, heightU.f, heightD.f
        
        *src = *p\addr[0] + ((y * w + (x - 1)) << 2)
        GetARGB(*src\l, a, rN, gN, bN)
        heightL = (rN * 0.299 + gN * 0.587 + bN * 0.114) / 255.0
        
        *src = *p\addr[0] + ((y * w + (x + 1)) << 2)
        GetARGB(*src\l, a, rN, gN, bN)
        heightR = (rN * 0.299 + gN * 0.587 + bN * 0.114) / 255.0
        
        *src = *p\addr[0] + (((y - 1) * w + x) << 2)
        GetARGB(*src\l, a, rN, gN, bN)
        heightU = (rN * 0.299 + gN * 0.587 + bN * 0.114) / 255.0
        
        *src = *p\addr[0] + (((y + 1) * w + x) << 2)
        GetARGB(*src\l, a, rN, gN, bN)
        heightD = (rN * 0.299 + gN * 0.587 + bN * 0.114) / 255.0
        
        ; Gradient du relief
        Protected dxRelief.f = (heightR - heightL) * reliefStrength * 3.0
        Protected dyRelief.f = (heightD - heightU) * reliefStrength * 3.0
        
        ; Calcul de la normale
        nx = -dxRelief
        ny = -dyRelief
        nz = 1.0
        
        ; Normalisation
        len = Sqr(nx * nx + ny * ny + nz * nz)
        If len > 0.0001
          nx = nx / len
          ny = ny / len
          nz = nz / len
        EndIf
        
        ; Produit scalaire avec la direction de la lumière
        Protected dot.f = nx * lx + ny * ly + nz * lz
        If dot < 0.0 : dot = 0.0 : EndIf
        
        ; Application de l'éclairage
        lighting = 0.4 + dot * 0.6 * lightIntensity
        
        r = Int(r * lighting)
        g = Int(g * lighting)
        b = Int(b * lighting)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 6 : TEXTURE ÉPAISSE DE LA PEINTURE
      ; ------------------------------------------------------------------------
      ; Simule les irrégularités de la peinture épaisse
      
      If textureAmount > 0.01
        ; Bruit de base pour texture globale
        Protected seed1 = (x * 34567 + y * 98765) & $7FFFFFFF
        Protected noiseVal1 = (seed1 % 1000) - 500
        noise = noiseVal1 / 500.0
        
        ; Bruit directionnel (suit le coup de pinceau)
        Protected coordAlong = Int(x * cosAngle + y * sinAngle)
        Protected seed2 = (coordAlong * 45678) & $7FFFFFFF
        Protected noiseVal2 = (seed2 % 1000) - 500
        impastoNoise = noiseVal2 / 500.0
        
        ; Combine les textures
        Protected totalTexture.f = (noise * 0.3 + impastoNoise * 0.7) * textureAmount * 40.0
        
        ; Plus de texture dans les zones épaisses
        totalTexture = totalTexture * (0.5 + heightMap)
        
        r + Int(totalTexture)
        g + Int(totalTexture * 0.95)
        b + Int(totalTexture * 1.05)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 7 : ACCUMULATION DE MATIÈRE SUR LES CONTOURS
      ; ------------------------------------------------------------------------
      ; La peinture s'accumule davantage sur les bords
      
      Protected edgeAccum.f = Sqr(dx * dx + dy * dy)
      
      If edgeAccum > 0.3
        ; Plus de matière = plus clair et plus texturé
        Protected accumEffect.f = (edgeAccum - 0.3) * paintThickness * 20.0
        r + Int(accumEffect)
        g + Int(accumEffect)
        b + Int(accumEffect)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 8 : VARIATIONS D'ÉPAISSEUR
      ; ------------------------------------------------------------------------
      ; Simule les zones où le pinceau a déposé plus ou moins de matière
      
      Protected thicknessSeed = ((x / 4) * 23456 + (y / 4) * 67890) & $7FFFFFFF
      Protected thicknessVal = (thicknessSeed % 1000) - 500
      thickness = thicknessVal / 5000.0
      
      Protected thicknessEffect.f = thickness * paintThickness * 25.0
      
      r + Int(thicknessEffect)
      g + Int(thicknessEffect * 0.98)
      b + Int(thicknessEffect * 1.02)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 9 : EMPÂTEMENT (zones très épaisses)
      ; ------------------------------------------------------------------------
      ; Dans les zones très claires, simule un empâtement prononcé
      
      If heightMap > 0.7
        Protected impastoEffect.f = (heightMap - 0.7) * paintThickness * 30.0
        r + Int(impastoEffect)
        g + Int(impastoEffect)
        b + Int(impastoEffect)
        
        ; Ajoute un léger reflet sur les zones très épaisses
        Protected highlight.f = (heightMap - 0.7) * lightIntensity * 15.0
        r + Int(highlight)
        g + Int(highlight)
        b + Int(highlight)
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

Procedure impasto(*param.parametre)
  
  ; Si appelé en mode "info", on configure les paramètres de l'interface
  If *param\info_active
    
    ; --- Métadonnées du filtre ---
    *param\typ = #FilterType_Artistic         ; Catégorie : artistique
    *param\subtype = #Artistic_Material
    *param\name = "Impasto - Peinture Épaisse" ; Nom affiché
    *param\remarque = "Simule une peinture très épaisse avec relief prononcé et texture"
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 0 : ÉPAISSEUR DE LA PEINTURE
    ; --------------------------------------------------------------------------
    *param\info[0] = "Épaisseur peinture"
    *param\info_data(0, 0) = 1     ; Valeur minimale (fine)
    *param\info_data(0, 1) = 100   ; Valeur maximale (très épaisse)
    *param\info_data(0, 2) = 60    ; Valeur par défaut (épaisse)
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 1 : TAILLE DU PINCEAU
    ; --------------------------------------------------------------------------
    *param\info[1] = "Taille pinceau"
    *param\info_data(1, 0) = 2     ; Min = petit pinceau
    *param\info_data(1, 1) = 15    ; Max = très large
    *param\info_data(1, 2) = 7     ; Défaut = moyen
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 2 : RELIEF/HAUTEUR
    ; --------------------------------------------------------------------------
    *param\info[2] = "Relief"
    *param\info_data(2, 0) = 0     ; Plat
    *param\info_data(2, 1) = 100   ; Relief très prononcé
    *param\info_data(2, 2) = 70    ; Défaut = relief fort
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 3 : TEXTURE DE LA MATIÈRE
    ; --------------------------------------------------------------------------
    *param\info[3] = "Texture matière"
    *param\info_data(3, 0) = 0     ; Lisse
    *param\info_data(3, 1) = 100   ; Très texturé
    *param\info_data(3, 2) = 65    ; Défaut = texturé
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 4 : DIRECTION DES COUPS
    ; --------------------------------------------------------------------------
    *param\info[4] = "Direction (0=Auto/1-8=Fixe)"
    *param\info_data(4, 0) = 0     ; 0 = Automatique
    *param\info_data(4, 1) = 8     ; 8 directions possibles
    *param\info_data(4, 2) = 0     ; Défaut = Auto
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 5 : INTENSITÉ DE L'ÉCLAIRAGE
    ; --------------------------------------------------------------------------
    *param\info[5] = "Éclairage relief"
    *param\info_data(5, 0) = 0     ; Pas d'éclairage
    *param\info_data(5, 1) = 100   ; Éclairage maximum
    *param\info_data(5, 2) = 80    ; Défaut = fort
    
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
  filter_start(@impasto_MT(), 3, 1)
  
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 350
; FirstLine = 315
; Folding = -
; EnableXP
; DPIAware