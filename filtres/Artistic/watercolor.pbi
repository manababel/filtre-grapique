Procedure watercolor_MT(*p.parametre)
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
  
  ; --- Accumulation pour moyennage ---
  Protected sumR.f, sumG.f, sumB.f  ; Sommes des composantes RGB
  Protected count.f                  ; Nombre de pixels échantillonnés
  
  ; --- Variation et texture ---
  Protected noise.f                  ; Bruit pour texture granuleuse
  Protected variation.f              ; Variation de couleur locale
  Protected edge.f                   ; Détection de contour pour préservation
  
  ; --- Saturation ---
  Protected hue.f, sat.f, val.f     ; Composantes HSV
  Protected minRGB.f, maxRGB.f, delta.f
  
  ; --- Pointeurs mémoire ---
  Protected *src.Pixel32            ; Pointeur vers pixel source (lecture)
  Protected *dst.Pixel32            ; Pointeur vers pixel destination (écriture)
  
  ; ============================================================================
  ; LECTURE DES PARAMÈTRES
  ; ============================================================================
  
  ; --- Paramètre 0 : Intensité de diffusion ---
  Protected diffusion.f = *p\option[0] * 0.01  ; 1-100 -> 0.01-1.0
  
  ; --- Paramètre 1 : Rayon de diffusion ---
  Protected radius = *p\option[1]
  If radius < 1 : radius = 1 : EndIf
  If radius > 10 : radius = 10 : EndIf
  
  ; --- Paramètre 2 : Intensité de texture/grain ---
  Protected grainStrength.f = *p\option[2] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 3 : Variation de couleur ---
  Protected colorVariation.f = *p\option[3] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 4 : Préservation des contours ---
  Protected edgePreserve.f = *p\option[4] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 5 : Boost de saturation ---
  Protected satBoost.f = *p\option[5] * 0.01  ; 0-200 -> 0-2.0
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  
  Protected startY = (*p\thread_pos * h) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * h) / *p\thread_max
  
  ; --- Protection des bordures ---
  Protected border = radius + 1
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
      ; ÉTAPE 2 : DÉTECTION DE CONTOUR (pour préservation)
      ; ------------------------------------------------------------------------
      ; Calcule la variance locale pour détecter les zones de fort contraste
      
      Protected grayC.f = rC * 0.299 + gC * 0.587 + bC * 0.114
      Protected edgeSum.f = 0.0
      Protected edgeCount = 0
      
      ; Échantillonne 4 pixels autour pour détecter les contours
      For i = -1 To 1 Step 2
        For j = -1 To 1 Step 2
          *src = *p\addr[0] + (((y + i) * w + (x + j)) << 2)
          GetARGB(*src\l, a, rN, gN, bN)
          Protected grayN.f = rN * 0.299 + gN * 0.587 + bN * 0.114
          edgeSum + Abs(grayC - grayN)
          edgeCount + 1
        Next
      Next
      
      edge = edgeSum / (edgeCount * 255.0)  ; Normalise entre 0 et 1
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 3 : DIFFUSION AQUARELLE (Moyennage pondéré)
      ; ------------------------------------------------------------------------
      ; Simule la diffusion de l'eau en mélangeant avec les pixels voisins
      ; Le poids diminue avec la distance (filtre gaussien approximé)
      
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : count = 0.0
      
      ; Rayon adaptatif : plus petit sur les contours
      Protected adaptiveRadius = radius * (1.0 - edge * edgePreserve)
      If adaptiveRadius < 1 : adaptiveRadius = 1 : EndIf
      
      Protected iRadius = Int(adaptiveRadius)
      
      For i = -iRadius To iRadius
        For j = -iRadius To iRadius
          
          ; Distance au centre
          Protected dist.f = Sqr(i*i + j*j)
          
          If dist <= adaptiveRadius
            ; Poids gaussien approximé
            Protected weight.f = 1.0 / (1.0 + dist * dist * 0.5)
            
            *src = *p\addr[0] + (((y + i) * w + (x + j)) << 2)
            GetARGB(*src\l, a, rN, gN, bN)
            
            sumR + rN * weight
            sumG + gN * weight
            sumB + bN * weight
            count + weight
          EndIf
          
        Next
      Next
      
      ; Moyennes pondérées
      Protected avgR.f = sumR / count
      Protected avgG.f = sumG / count
      Protected avgB.f = sumB / count
      
      ; Mélange entre original et diffusé
      Protected blendDiffusion.f = diffusion * (1.0 - edge * edgePreserve * 0.7)
      
      r = Int(rC * (1.0 - blendDiffusion) + avgR * blendDiffusion)
      g = Int(gC * (1.0 - blendDiffusion) + avgG * blendDiffusion)
      b = Int(bC * (1.0 - blendDiffusion) + avgB * blendDiffusion)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 4 : VARIATION DE COULEUR (Simule les pigments qui se mélangent)
      ; ------------------------------------------------------------------------
      ; Crée des variations aléatoires basées sur la position du pixel
      
      If colorVariation > 0.01
        ; Générateur pseudo-aléatoire basé sur la position
        Protected seed = (x * 12345 + y * 67890) & $7FFFFFFF
        Protected noise2 = ((seed % 1000) - 500) / 500.0  ; Valeur entre -1 et 1
        noise = noise
        
        variation = noise * colorVariation * 30.0
        
        r + Int(variation)
        g + Int(variation * 0.8)  ; Légèrement différent par canal
        b + Int(variation * 1.2)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 5 : BOOST DE SATURATION (Aquarelle = couleurs vibrantes)
      ; ------------------------------------------------------------------------
      
      If satBoost > 1.01
        ; Conversion RGB -> HSV
        minRGB = r
        If g < minRGB : minRGB = g : EndIf
        If b < minRGB : minRGB = b : EndIf
        
        maxRGB = r
        If g > maxRGB : maxRGB = g : EndIf
        If b > maxRGB : maxRGB = b : EndIf
        
        delta = maxRGB - minRGB
        
        ; Valeur (V)
        val = maxRGB / 255.0
        
        ; Saturation (S)
        If maxRGB > 0.0001
          sat = delta / maxRGB
        Else
          sat = 0.0
        EndIf
        
        ; Calcul de la teinte (H) - simplifié
        If delta > 0.0001
          If maxRGB = r
            Protected h_temp.f = (g - b) / delta
            While h_temp >= 6.0 : h_temp - 6.0 : Wend
            While h_temp < 0.0 : h_temp + 6.0 : Wend
            hue = 60.0 * h_temp
          ElseIf maxRGB = g
            hue = 60.0 * (((b - r) / delta) + 2.0)
          Else
            hue = 60.0 * (((r - g) / delta) + 4.0)
          EndIf
          
          If hue < 0 : hue + 360.0 : EndIf
        Else
          hue = 0.0
        EndIf
        
        ; Boost de saturation
        sat * satBoost
        If sat > 1.0 : sat = 1.0 : EndIf
        
        ; Conversion HSV -> RGB
        Protected c.f = val * sat
        Protected h_div_60.f = hue / 60.0
        Protected h_mod_2.f = h_div_60 - Int(h_div_60 / 2.0) * 2.0
        Protected x2.f = c * (1.0 - Abs(h_mod_2 - 1.0))
        Protected m.f = val - c
        
        Protected r1.f, g1.f, b1.f
        
        Protected h_sector = Int(hue / 60.0)
        If h_sector >= 6 : h_sector = 5 : EndIf
        If h_sector < 0 : h_sector = 0 : EndIf
        
        Select h_sector
          Case 0 : r1 = c : g1 = x2 : b1 = 0
          Case 1 : r1 = x2 : g1 = c : b1 = 0
          Case 2 : r1 = 0 : g1 = c : b1 = x2
          Case 3 : r1 = 0 : g1 = x2 : b1 = c
          Case 4 : r1 = x2 : g1 = 0 : b1 = c
          Case 5 : r1 = c : g1 = 0 : b1 = x2
        EndSelect
        
        r = Int((r1 + m) * 255.0)
        g = Int((g1 + m) * 255.0)
        b = Int((b1 + m) * 255.0)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 6 : TEXTURE GRANULEUSE (Simule le grain du papier)
      ; ------------------------------------------------------------------------
      
      If grainStrength > 0.01
        ; Bruit basé sur la position (différent de la variation de couleur)
        Protected seed2 = ((x * 54321 + y * 98765) * 3) & $7FFFFFFF
        Protected grain2 = ((seed2 % 1000) - 500) / 500.0
        Protected grain.f = grain2
        
        Protected grainEffect = grain * grainStrength * 40.0
        
        ; Applique plus de grain dans les zones claires (effet papier)
        Protected brightness.f = (r + g + b) / (3.0 * 255.0)
        grainEffect * (0.5 + brightness * 0.5)
        
        r + Int(grainEffect)
        g + Int(grainEffect)
        b + Int(grainEffect)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 7 : ÉCLAIRCISSEMENT DES ZONES CLAIRES (Effet eau)
      ; ------------------------------------------------------------------------
      ; L'aquarelle crée des zones plus claires là où l'eau est abondante
      
      Protected luminosity.f = (r + g + b) / (3.0 * 255.0)
      
      If luminosity > 0.6
        Protected lightenFactor.f = (luminosity - 0.6) * 0.3
        r = Int(r + (255 - r) * lightenFactor)
        g = Int(g + (255 - g) * lightenFactor)
        b = Int(b + (255 - b) * lightenFactor)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 8 : ASSOMBRISSEMENT DES CONTOURS
      ; ------------------------------------------------------------------------
      ; Les pigments s'accumulent sur les contours
      
      If edge > 0.3
        Protected darkenEdge.f = (edge - 0.3) * 0.4
        r = Int(r * (1.0 - darkenEdge))
        g = Int(g * (1.0 - darkenEdge))
        b = Int(b * (1.0 - darkenEdge))
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 9 : CLAMPING (LIMITATION DES VALEURS)
      ; ------------------------------------------------------------------------
      
      If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 10 : ÉCRITURE DU PIXEL RÉSULTAT
      ; ------------------------------------------------------------------------
      
      *dst = *p\addr[1] + ((y * w + x) << 2)
      *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      
    Next  ; Pixel suivant (x)
  Next    ; Ligne suivante (y)
  
EndProcedure

; ==============================================================================
; PROCÉDURE D'INITIALISATION DU FILTRE
; ==============================================================================

Procedure watercolor(*param.parametre)
  
  ; Si appelé en mode "info", on configure les paramètres de l'interface
  If *param\info_active
    
    ; --- Métadonnées du filtre ---
    *param\typ = #FilterType_Artistic         ; Catégorie : artistique
    *param\subtype = #Artistic_Material
    *param\name = "Aquarelle / Watercolor"    ; Nom affiché
    *param\remarque = "Simule un effet de peinture à l'eau avec diffusion, texture et saturation"
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 0 : INTENSITÉ DE DIFFUSION
    ; --------------------------------------------------------------------------
    *param\info[0] = "Diffusion"
    *param\info_data(0, 0) = 1     ; Valeur minimale (1%)
    *param\info_data(0, 1) = 100   ; Valeur maximale (100%)
    *param\info_data(0, 2) = 60    ; Valeur par défaut (60%)
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 1 : RAYON DE DIFFUSION
    ; --------------------------------------------------------------------------
    *param\info[1] = "Rayon diffusion"
    *param\info_data(1, 0) = 1     ; Min = 1 pixel
    *param\info_data(1, 1) = 10    ; Max = 10 pixels
    *param\info_data(1, 2) = 4     ; Défaut = 4 pixels
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 2 : GRAIN/TEXTURE
    ; --------------------------------------------------------------------------
    *param\info[2] = "Grain papier"
    *param\info_data(2, 0) = 0     ; Aucun grain
    *param\info_data(2, 1) = 100   ; Grain maximum
    *param\info_data(2, 2) = 40    ; Défaut = moyen
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 3 : VARIATION DE COULEUR
    ; --------------------------------------------------------------------------
    *param\info[3] = "Variation couleur"
    *param\info_data(3, 0) = 0     ; Aucune variation
    *param\info_data(3, 1) = 100   ; Variation maximale
    *param\info_data(3, 2) = 30    ; Défaut = légère
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 4 : PRÉSERVATION DES CONTOURS
    ; --------------------------------------------------------------------------
    *param\info[4] = "Préserver contours"
    *param\info_data(4, 0) = 0     ; Aucune préservation
    *param\info_data(4, 1) = 100   ; Préservation maximale
    *param\info_data(4, 2) = 50    ; Défaut = moyen
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 5 : BOOST DE SATURATION
    ; --------------------------------------------------------------------------
    *param\info[5] = "Saturation (100=normal)"
    *param\info_data(5, 0) = 50    ; Désaturé
    *param\info_data(5, 1) = 200   ; Très saturé
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
  filter_start(@watercolor_MT(), 3, 1)
  
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 323
; FirstLine = 295
; Folding = -
; EnableXP
; DPIAware