; ==============================================================================
; FILTRE HDR ARTISTIC EFFECT
; ==============================================================================
; Crée un effet HDR artistique caractérisé par :
; - Tone mapping local (compression dynamique)
; - Halos lumineux autour des contours
; - Saturation extrême des couleurs
; - Renforcement des détails dans ombres et hautes lumières
; - Égalisation locale du contraste
; ==============================================================================

Procedure hdr_artistic_MT(*p.parametre)
  ; ============================================================================
  ; DÉCLARATION DES VARIABLES
  ; ============================================================================
  
  ; --- Dimensions de l'image ---
  Protected w = *p\lg
  Protected h = *p\ht
  
  ; --- Coordonnées ---
  Protected x, y, dx, dy
  Protected i, j
  
  ; --- Composantes ARGB ---
  Protected a, r, g, b
  Protected rC, gC, bC
  Protected valR, valG, valB
  
  ; --- Analyse locale ---
  Protected sumR.f, sumG.f, sumB.f
  Protected avgR.f, avgG.f, avgB.f
  Protected minLum.f, maxLum.f
  Protected localLum.f, luminance.f
  
  ; --- Tone mapping ---
  Protected compressedLum.f
  Protected localContrast.f
  Protected dynamicRange.f
  
  ; --- Détection de contours ---
  Protected sobelX.f, sobelY.f
  Protected edgeMagnitude.f
  Protected haloEffect.f
  
  ; --- Matrice Sobel pour détection contours ---
  Dim kernelX.f(2, 2)
  kernelX(0, 0) = -1 : kernelX(1, 0) = 0 : kernelX(2, 0) = 1
  kernelX(0, 1) = -2 : kernelX(1, 1) = 0 : kernelX(2, 1) = 2
  kernelX(0, 2) = -1 : kernelX(1, 2) = 0 : kernelX(2, 2) = 1
  
  Dim kernelY.f(2, 2)
  kernelY(0, 0) = -1 : kernelY(1, 0) = -2 : kernelY(2, 0) = -1
  kernelY(0, 1) =  0 : kernelY(1, 1) =  0 : kernelY(2, 1) =  0
  kernelY(0, 2) =  1 : kernelY(1, 2) =  2 : kernelY(2, 2) =  1
  
  ; --- Saturation ---
  Protected hue.f, sat.f, val.f
  Protected newSat.f
  
  ; --- HDR glow ---
  Protected glow.f, glowR.f, glowG.f, glowB.f
  
  ; --- Pointeurs mémoire ---
  Protected *src.Pixel32
  Protected *dst.Pixel32
  
  ; ============================================================================
  ; LECTURE DES PARAMÈTRES
  ; ============================================================================
  
  ; --- Intensité globale HDR ---
  Protected strength.f = *p\option[0] * 0.01  ; 1-100 -> 0.01-1.0
  
  ; --- Compression tonale (tone mapping) ---
  Protected toneCompression.f = *p\option[1] * 0.01  ; 0-200 -> 0.0-2.0
  
  ; --- Rayon du halo lumineux ---
  Protected haloRadius = *p\option[2]  ; 1-10 pixels
  
  ; --- Intensité du halo ---
  Protected haloIntensity.f = *p\option[3] * 0.01  ; 0-200 -> 0.0-2.0
  
  ; --- Boost de saturation ---
  Protected saturationBoost.f = *p\option[4] * 0.01  ; 0-300 -> 0.0-3.0
  
  ; --- Renforcement des détails ---
  Protected detailEnhance.f = *p\option[5] * 0.01  ; 0-200 -> 0.0-2.0
  
  ; --- Égalisation locale ---
  Protected localEqualization.f = *p\option[6] * 0.01  ; 0-100 -> 0.0-1.0
  
  ; --- Validation ---
  If strength <= 0.0 : strength = 0.01 : EndIf
  If haloRadius < 1 : haloRadius = 1 : EndIf
  If haloRadius > 10 : haloRadius = 10 : EndIf
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  
  Protected startY = (*p\thread_pos * h) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * h) / *p\thread_max
  
  ; Protection bordures (kernel + halo)
  Protected margin = haloRadius + 1
  If startY < margin : startY = margin : EndIf
  If endY > h - margin : endY = h - margin : EndIf
  
  ; ============================================================================
  ; TRAITEMENT PRINCIPAL
  ; ============================================================================
  
  For y = startY To endY - 1
    For x = margin To w - margin - 1
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 1 : LECTURE DU PIXEL CENTRAL
      ; ------------------------------------------------------------------------
      *src = *p\addr[0] + ((y * w + x) << 2)
      GetARGB(*src\l, a, rC, gC, bC)
      
      ; Luminance du pixel central
      luminance = rC * 0.299 + gC * 0.587 + bC * 0.114
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 2 : ANALYSE DU VOISINAGE LOCAL (TONE MAPPING)
      ; ------------------------------------------------------------------------
      ; On analyse une zone plus large pour le tone mapping local
      
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0
      minLum = 255.0
      maxLum = 0.0
      Protected count = 0
      
      ; Rayon d'analyse (kernel 5x5 ou plus selon haloRadius)
      Protected analysisRadius = haloRadius
      
      For dy = -analysisRadius To analysisRadius
        For dx = -analysisRadius To analysisRadius
          
          *src = *p\addr[0] + (((y + dy) * w + (x + dx)) << 2)
          GetARGB(*src\l, a, valR, valG, valB)
          
          localLum = valR * 0.299 + valG * 0.587 + valB * 0.114
          
          sumR + valR
          sumG + valG
          sumB + valB
          
          ; Calcul de la plage dynamique locale
          If localLum < minLum : minLum = localLum : EndIf
          If localLum > maxLum : maxLum = localLum : EndIf
          
          count + 1
        Next
      Next
      
      avgR = sumR / count
      avgG = sumG / count
      avgB = sumB / count
      
      ; Plage dynamique locale
      dynamicRange = maxLum - minLum
      If dynamicRange < 1.0 : dynamicRange = 1.0 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 3 : TONE MAPPING LOCAL (COMPRESSION DYNAMIQUE)
      ; ------------------------------------------------------------------------
      ; Formule HDR : compresse les hautes lumières, ouvre les ombres
      ; Utilise une courbe logarithmique
      
      ; Position relative dans la plage dynamique locale
      Protected normLum.f = (luminance - minLum) / dynamicRange
      If normLum < 0.0 : normLum = 0.0 : EndIf
      If normLum > 1.0 : normLum = 1.0 : EndIf
      
      ; Tone mapping avec fonction logarithmique
      ; log(1 + x*k) où k contrôle la compression
      Protected compressionFactor.f = toneCompression * 10.0
      compressedLum = Log(1.0 + normLum * compressionFactor) / Log(1.0 + compressionFactor)
      
      ; Remapping vers la plage originale
      compressedLum = minLum + compressedLum * dynamicRange
      
      ; Égalisation locale : pousse vers la moyenne
      compressedLum = compressedLum + (128.0 - compressedLum) * localEqualization * 0.3
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 4 : DÉTECTION DE CONTOURS POUR HALOS
      ; ------------------------------------------------------------------------
      ; Les contours créent des halos lumineux caractéristiques du HDR
      
      sobelX = 0.0
      sobelY = 0.0
      
      ; Kernel Sobel 3x3
      For dy = -1 To 1
        For dx = -1 To 1
          *src = *p\addr[0] + (((y + dy) * w + (x + dx)) << 2)
          GetARGB(*src\l, a, valR, valG, valB)
          
          localLum = valR * 0.299 + valG * 0.587 + valB * 0.114
          
          sobelX + localLum * kernelX(dx + 1, dy + 1)
          sobelY + localLum * kernelY(dx + 1, dy + 1)
        Next
      Next
      
      edgeMagnitude = Sqr(sobelX * sobelX + sobelY * sobelY)
      
      ; Normalisation du contour (0-1)
      Protected edgeStrength.f = edgeMagnitude / 1000.0
      If edgeStrength > 1.0 : edgeStrength = 1.0 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 5 : CALCUL DU HALO LUMINEUX
      ; ------------------------------------------------------------------------
      ; Le halo est créé par diffusion de lumière autour des contours
      
      haloEffect = 0.0
      glowR = 0.0 : glowG = 0.0 : glowB = 0.0
      Protected glowCount = 0
      
      If haloIntensity > 0.0 And edgeStrength > 0.1
        
        ; Accumulation de lumière dans un rayon autour du contour
        For dy = -haloRadius To haloRadius
          For dx = -haloRadius To haloRadius
            
            ; Distance au centre
            Protected dist.f = Sqr(dx * dx + dy * dy)
            
            If dist <= haloRadius
              *src = *p\addr[0] + (((y + dy) * w + (x + dx)) << 2)
              GetARGB(*src\l, a, valR, valG, valB)
              
              ; Poids selon distance (Gaussian-like)
              Protected weight.f = 1.0 - (dist / haloRadius)
              weight = weight * weight  ; Courbe quadratique
              
              glowR + valR * weight
              glowG + valG * weight
              glowB + valB * weight
              glowCount + 1
            EndIf
            
          Next
        Next
        
        If glowCount > 0
          glowR / glowCount
          glowG / glowCount
          glowB / glowCount
          
          ; Le halo est plus fort sur les contours
          haloEffect = edgeStrength * haloIntensity
        EndIf
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 6 : APPLICATION DU TONE MAPPING AUX COULEURS
      ; ------------------------------------------------------------------------
      
      ; Ratio de compression à appliquer aux canaux couleur
      Protected lumRatio.f = compressedLum / luminance
      If luminance < 1.0 : lumRatio = 1.0 : EndIf  ; Évite division par zéro
      
      Protected newR.f = rC * lumRatio
      Protected newG.f = gC * lumRatio
      Protected newB.f = bC * lumRatio
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 7 : RENFORCEMENT DES DÉTAILS
      ; ------------------------------------------------------------------------
      ; Accentue la différence avec la moyenne locale
      
      If detailEnhance > 0.0
        Protected detailR.f = (newR - avgR) * detailEnhance
        Protected detailG.f = (newG - avgG) * detailEnhance
        Protected detailB.f = (newB - avgB) * detailEnhance
        
        newR + detailR
        newG + detailG
        newB + detailB
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 8 : APPLICATION DU HALO LUMINEUX
      ; ------------------------------------------------------------------------
      
      If haloEffect > 0.0
        newR = newR + (glowR - newR) * haloEffect * 0.5
        newG = newG + (glowG - newG) * haloEffect * 0.5
        newB = newB + (glowB - newB) * haloEffect * 0.5
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 9 : BOOST DE SATURATION (SIGNATURE HDR)
      ; ------------------------------------------------------------------------
      
      If saturationBoost > 1.0
        ; Luminance du pixel traité
        Protected newLum.f = newR * 0.299 + newG * 0.587 + newB * 0.114
        
        ; Pousse les couleurs loin du gris
        newR = newLum + (newR - newLum) * saturationBoost
        newG = newLum + (newG - newLum) * saturationBoost
        newB = newLum + (newB - newLum) * saturationBoost
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 10 : MÉLANGE AVEC ORIGINAL (STRENGTH)
      ; ------------------------------------------------------------------------
      
      r = Int(rC + (newR - rC) * strength)
      g = Int(gC + (newG - gC) * strength)
      b = Int(bC + (newB - bC) * strength)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 11 : CLAMPING
      ; ------------------------------------------------------------------------
      
      If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 12 : ÉCRITURE DU RÉSULTAT
      ; ------------------------------------------------------------------------
      
      *dst = *p\addr[1] + ((y * w + x) << 2)
      *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      
    Next
  Next
  
EndProcedure

; ==============================================================================
; PROCÉDURE D'INITIALISATION
; ==============================================================================

Procedure hdr_artistic(*param.parametre)
  
  If *param\info_active
    
    ; --- Métadonnées ---
    *param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Light
    *param\name = "HDR Artistic"
    *param\remarque = "Effet HDR artistique avec tone mapping local et halos lumineux"
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 0 : INTENSITÉ GLOBALE
    ; --------------------------------------------------------------------------
    *param\info[0] = "Intensité"
    *param\info_data(0, 0) = 1      ; Min
    *param\info_data(0, 1) = 100    ; Max
    *param\info_data(0, 2) = 80     ; Défaut
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 1 : COMPRESSION TONALE
    ; --------------------------------------------------------------------------
    *param\info[1] = "Tone mapping"
    *param\info_data(1, 0) = 0      ; Pas de compression
    *param\info_data(1, 1) = 200    ; Compression extrême
    *param\info_data(1, 2) = 120    ; Compression modérée
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 2 : RAYON DU HALO
    ; --------------------------------------------------------------------------
    *param\info[2] = "Rayon halo (pixels)"
    *param\info_data(2, 0) = 1      ; Halo fin
    *param\info_data(2, 1) = 10     ; Halo large
    *param\info_data(2, 2) = 4      ; Halo moyen
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 3 : INTENSITÉ DU HALO
    ; --------------------------------------------------------------------------
    *param\info[3] = "Intensité halo"
    *param\info_data(3, 0) = 0      ; Pas de halo
    *param\info_data(3, 1) = 200    ; Halo extrême
    *param\info_data(3, 2) = 80     ; Halo modéré
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 4 : SATURATION
    ; --------------------------------------------------------------------------
    *param\info[4] = "Saturation"
    *param\info_data(4, 0) = 0      ; Désaturé
    *param\info_data(4, 1) = 300    ; Hyper-saturé
    *param\info_data(4, 2) = 150    ; Saturé (typique HDR)
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 5 : DÉTAILS
    ; --------------------------------------------------------------------------
    *param\info[5] = "Détails"
    *param\info_data(5, 0) = 0      ; Pas de renforcement
    *param\info_data(5, 1) = 200    ; Détails extrêmes
    *param\info_data(5, 2) = 100    ; Détails normaux
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 6 : ÉGALISATION LOCALE
    ; --------------------------------------------------------------------------
    *param\info[6] = "Égalisation locale"
    *param\info_data(6, 0) = 0      ; Pas d'égalisation
    *param\info_data(6, 1) = 100    ; Égalisation forte
    *param\info_data(6, 2) = 40     ; Égalisation légère
    
    *param\info[7] = "masque"
    *param\info_data(7, 0) = 0
    *param\info_data(7, 1) = 2
    *param\info_data(7, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multithreadé
  filter_start(@hdr_artistic_MT(), 3, 1)
  
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 348
; FirstLine = 343
; Folding = -
; EnableXP
; DPIAware