; ==============================================================================
; FILTRE FRACTALIUS
; ==============================================================================
; Crée un effet artistique combinant :
; - Détection de contours avancée
; - Éclairage volumétrique
; - Renforcement HDR des détails
; ==============================================================================

Procedure fractalius_MT(*p.parametre)
  ; ============================================================================
  ; DÉCLARATION DES VARIABLES
  ; ============================================================================
  
  ; --- Dimensions de l'image ---
  Protected w = *p\lg
  Protected h = *p\ht
  
  ; --- Coordonnées ---
  Protected x, y, dx, dy
  
  ; --- Composantes ARGB ---
  Protected a, r, g, b
  Protected rC, gC, bC
  
  ; --- Analyse locale (kernel 3x3) ---
  Protected sumR, sumG, sumB, count
  Protected valR, valG, valB
  
  ; --- Détection de contours ---
  Protected sobelX.f, sobelY.f
  Protected edgeMagnitude.f
  Protected edgeIntensity.f
  
  ; --- Matrice de convolution Sobel ---
  ; Pour détecter les variations horizontales et verticales
  Dim kernelX(2, 2)
  kernelX(0, 0) = -1 : kernelX(1, 0) = 0 : kernelX(2, 0) = 1
  kernelX(0, 1) = -2 : kernelX(1, 1) = 0 : kernelX(2, 1) = 2
  kernelX(0, 2) = -1 : kernelX(1, 2) = 0 : kernelX(2, 2) = 1
  
  Dim kernelY(2, 2)
  kernelY(0, 0) = -1 : kernelY(1, 0) = -2 : kernelY(2, 0) = -1
  kernelY(0, 1) =  0 : kernelY(1, 1) =  0 : kernelY(2, 1) =  0
  kernelY(0, 2) =  1 : kernelY(1, 2) =  2 : kernelY(2, 2) =  1
  
  ; --- Effet de lumière ---
  Protected glow.f, luminance.f
  Protected detail.f
  
  ; --- Pointeurs mémoire ---
  Protected *src.Pixel32
  Protected *dst.Pixel32
  
  ; ============================================================================
  ; LECTURE DES PARAMÈTRES
  ; ============================================================================
  
  ; --- Intensité de l'effet fractal ---
  Protected intensity.f = *p\option[0] * 0.01  ; 1-100 -> 0.01-1.0
  
  ; --- Force des contours ---
  Protected edgeStrength.f = *p\option[1] * 0.01  ; 1-100 -> 0.01-1.0
  
  ; --- Intensité de la lumière (glow) ---
  Protected glowAmount.f = *p\option[2] * 0.01  ; 0-100 -> 0.0-1.0
  
  ; --- Renforcement des détails ---
  Protected detailBoost.f = *p\option[3] * 0.01  ; 0-200 -> 0.0-2.0
  
  ; --- Saturation des couleurs ---
  Protected saturation.f = *p\option[4] * 0.01  ; 0-200 -> 0.0-2.0
  
  ; --- Seuil de détection des contours ---
  Protected edgeThreshold.f = *p\option[5] * 0.01  ; 1-100 -> 0.01-1.0
  
  ; --- Validation ---
  If intensity <= 0.0 : intensity = 0.01 : EndIf
  If edgeStrength <= 0.0 : edgeStrength = 0.01 : EndIf
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  
  Protected startY = (*p\thread_pos * h) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * h) / *p\thread_max
  
  ; Protection bordures (kernel 3x3 nécessite marge de 1 pixel)
  If startY < 1 : startY = 1 : EndIf
  If endY > h - 1 : endY = h - 1 : EndIf
  
  ; ============================================================================
  ; TRAITEMENT PRINCIPAL
  ; ============================================================================
  
  For y = startY To endY - 1
    For x = 1 To w - 2
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 1 : LECTURE DU PIXEL CENTRAL
      ; ------------------------------------------------------------------------
      *src = *p\addr[0] + ((y * w + x) << 2)
      GetARGB(*src\l, a, rC, gC, bC)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 2 : DÉTECTION DE CONTOURS (SOBEL)
      ; ------------------------------------------------------------------------
      ; Applique l'opérateur de Sobel pour détecter les variations d'intensité
      
      sobelX = 0.0
      sobelY = 0.0
      sumR = 0 : sumG = 0 : sumB = 0
      count = 0
      
      ; Parcours du voisinage 3×3
      For dy = -1 To 1
        For dx = -1 To 1
          
          ; Lecture du pixel voisin
          *src = *p\addr[0] + (((y + dy) * w + (x + dx)) << 2)
          GetARGB(*src\l, a, valR, valG, valB)
          
          ; Conversion en luminance (perception humaine)
          luminance = valR * 0.299 + valG * 0.587 + valB * 0.114
          
          ; Application des kernels Sobel
          sobelX + luminance * kernelX(dx + 1, dy + 1)
          sobelY + luminance * kernelY(dx + 1, dy + 1)
          
          ; Accumulation pour moyenne locale
          sumR + valR
          sumG + valG
          sumB + valB
          count + 1
          
        Next
      Next
      
      ; Magnitude du gradient (force du contour)
      edgeMagnitude = Sqr(sobelX * sobelX + sobelY * sobelY)
      
      ; Normalisation (0-1000 typique -> 0-1)
      edgeIntensity = edgeMagnitude / 1000.0
      If edgeIntensity > 1.0 : edgeIntensity = 1.0 : EndIf
      
      ; Application du seuil
      If edgeIntensity < edgeThreshold
        edgeIntensity = 0.0
      Else
        edgeIntensity = (edgeIntensity - edgeThreshold) / (1.0 - edgeThreshold)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 3 : CALCUL DE L'EFFET GLOW (LUMIÈRE VOLUMÉTRIQUE)
      ; ------------------------------------------------------------------------
      ; Les contours émettent de la lumière
      
      glow = edgeIntensity * glowAmount * 2.0
      
      ; Moyenne des couleurs locales pour la diffusion
      Protected avgR.f = sumR / count
      Protected avgG.f = sumG / count
      Protected avgB.f = sumB / count
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 4 : RENFORCEMENT DES DÉTAILS (HDR)
      ; ------------------------------------------------------------------------
      ; Accentue les micro-variations autour des contours
      
      detail = edgeIntensity * detailBoost
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 5 : COMPOSITION FINALE
      ; ------------------------------------------------------------------------
      
      ; Mélange entre couleur originale et effet fractal
      Protected finalR.f = rC
      Protected finalG.f = gC
      Protected finalB.f = bC
      
      ; Application de l'effet de contours lumineux
      finalR = finalR + (255 - finalR) * edgeIntensity * edgeStrength
      finalG = finalG + (255 - finalG) * edgeIntensity * edgeStrength
      finalB = finalB + (255 - finalB) * edgeIntensity * edgeStrength
      
      ; Application du glow (diffusion de lumière)
      finalR = finalR + avgR * glow
      finalG = finalG + avgG * glow
      finalB = finalB + avgB * glow
      
      ; Renforcement des détails
      finalR = finalR + (finalR - avgR) * detail
      finalG = finalG + (finalG - avgG) * detail
      finalB = finalB + (finalB - avgB) * detail
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 6 : CONTRÔLE DE SATURATION
      ; ------------------------------------------------------------------------
      
      ; Calcul de la luminance finale
      Protected lum.f = finalR * 0.299 + finalG * 0.587 + finalB * 0.114
      
      ; Interpolation entre gris (sat=0) et couleur saturée (sat>1)
      finalR = lum + (finalR - lum) * saturation
      finalG = lum + (finalG - lum) * saturation
      finalB = lum + (finalB - lum) * saturation
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 7 : MÉLANGE AVEC ORIGINAL (INTENSITY)
      ; ------------------------------------------------------------------------
      
      r = Int(rC + (finalR - rC) * intensity)
      g = Int(gC + (finalG - gC) * intensity)
      b = Int(bC + (finalB - bC) * intensity)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 8 : CLAMPING
      ; ------------------------------------------------------------------------
      
      If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 9 : ÉCRITURE DU RÉSULTAT
      ; ------------------------------------------------------------------------
      
      *dst = *p\addr[1] + ((y * w + x) << 2)
      *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      
    Next
  Next
  
EndProcedure

; ==============================================================================
; PROCÉDURE D'INITIALISATION
; ==============================================================================

Procedure fractalius(*param.parametre)
  
  If *param\info_active
    
    ; --- Métadonnées ---
    *param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Other
    *param\name = "Fractalius"
    *param\remarque = "Effet fractal artistique avec contours lumineux"
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 0 : INTENSITÉ GLOBALE
    ; --------------------------------------------------------------------------
    *param\info[0] = "Intensité"
    *param\info_data(0, 0) = 1      ; Min
    *param\info_data(0, 1) = 100    ; Max
    *param\info_data(0, 2) = 70     ; Défaut
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 1 : FORCE DES CONTOURS
    ; --------------------------------------------------------------------------
    *param\info[1] = "Force contours"
    *param\info_data(1, 0) = 1
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 80
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 2 : INTENSITÉ LUMINEUSE (GLOW)
    ; --------------------------------------------------------------------------
    *param\info[2] = "Lumière (Glow)"
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 40
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 3 : RENFORCEMENT DÉTAILS
    ; --------------------------------------------------------------------------
    *param\info[3] = "Détails"
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 200
    *param\info_data(3, 2) = 100
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 4 : SATURATION
    ; --------------------------------------------------------------------------
    *param\info[4] = "Saturation"
    *param\info_data(4, 0) = 0      ; Noir et blanc
    *param\info_data(4, 1) = 200    ; Sur-saturé
    *param\info_data(4, 2) = 120    ; Légèrement augmentée
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 5 : SEUIL DE DÉTECTION
    ; --------------------------------------------------------------------------
    *param\info[5] = "Seuil contours"
    *param\info_data(5, 0) = 1
    *param\info_data(5, 1) = 100
    *param\info_data(5, 2) = 20
    
    *param\info[6] = "masque"
    *param\info_data(6, 0) = 0
    *param\info_data(6, 1) = 2
    *param\info_data(6, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multithreadé
  filter_start(@fractalius_MT(), 3, 1)
  
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 244
; FirstLine = 229
; Folding = -
; EnableXP
; DPIAware