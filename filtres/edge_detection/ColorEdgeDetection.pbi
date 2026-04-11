; ============================================================================
; Filtre Color Edge Detection - Détection de contours couleur
; ============================================================================
; Détecte les contours basés sur les variations de couleur plutôt que d'intensité
; Utilise différents espaces colorimétriques (RGB, HSV, Lab) pour capturer
; les transitions de couleur que les filtres en niveaux de gris manquent

Macro ColorEdge_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  *srcPixel + 4
EndMacro

Procedure ColorEdge_RGB_To_HSV(r, g, b, *h.Float, *s.Float, *v.Float)
  ; Conversion RGB vers HSV
  Protected.f rNorm = r / 255.0, gNorm = g / 255.0, bNorm = b / 255.0
  Protected.f cMax
  Max(cMax , gNorm, bNorm)
  Max(cMax , rNorm, cMax)
  Protected.f cMin
  Min(cMin , gNorm, bNorm)
  Min(cMin , rNorm, cMin)
  Protected.f delta = cMax - cMin
  
  ; Value
  *v\f = cMax
  
  ; Saturation
  If cMax > 0
    *s\f = delta / cMax
  Else
    *s\f = 0
  EndIf
  
  ; Hue
  If delta > 0
    If cMax = rNorm
      *h\f = 60.0 * Mod(((gNorm - bNorm) / delta) , 6)
    ElseIf cMax = gNorm
      *h\f = 60.0 * (((bNorm - rNorm) / delta) + 2.0)
    Else
      *h\f = 60.0 * (((rNorm - gNorm) / delta) + 4.0)
    EndIf
    If *h\f < 0 : *h\f + 360.0 : EndIf
  Else
    *h\f = 0
  EndIf
EndProcedure

Procedure ColorEdge_RGB_To_Lab(r, g, b, *L.Float, *a.Float, *b2.Float)
  ; Conversion RGB vers Lab (approximation simplifiée)
  Protected.f rNorm = r / 255.0, gNorm = g / 255.0, bNorm = b / 255.0
  
  ; Gamma correction (approximation)
  If rNorm > 0.04045 : rNorm = Pow((rNorm + 0.055) / 1.055, 2.4)
  Else : rNorm / 12.92 : EndIf
  If gNorm > 0.04045 : gNorm = Pow((gNorm + 0.055) / 1.055, 2.4)
  Else : gNorm / 12.92 : EndIf
  If bNorm > 0.04045 : bNorm = Pow((bNorm + 0.055) / 1.055, 2.4)
  Else : bNorm / 12.92 : EndIf
  
  ; RGB vers XYZ
  Protected.f x = (rNorm * 0.4124 + gNorm * 0.3576 + bNorm * 0.1805) * 100.0
  Protected.f y = (rNorm * 0.2126 + gNorm * 0.7152 + bNorm * 0.0722) * 100.0
  Protected.f z = (rNorm * 0.0193 + gNorm * 0.1192 + bNorm * 0.9505) * 100.0
  
  ; XYZ vers Lab (D65 illuminant)
  x / 95.047 : y / 100.0 : z / 108.883
  
  If x > 0.008856 : x = Pow(x, 1.0/3.0)
  Else : x = (7.787 * x) + (16.0/116.0) : EndIf
  If y > 0.008856 : y = Pow(y, 1.0/3.0)
  Else : y = (7.787 * y) + (16.0/116.0) : EndIf
  If z > 0.008856 : z = Pow(z, 1.0/3.0)
  Else : z = (7.787 * z) + (16.0/116.0) : EndIf
  
  *L\f = (116.0 * y) - 16.0
  *a\f = 500.0 * (x - y)
  *b2\f = 200.0 * (y - z)
EndProcedure

Procedure.f ColorEdge_Euclidean_Distance_RGB(r1, g1, b1, r2, g2, b2)
  ; Distance euclidienne dans l'espace RGB
  Protected dr = r2 - r1, dg = g2 - g1, db = b2 - b1
  ProcedureReturn Sqr(dr * dr + dg * dg + db * db)
EndProcedure

Procedure.f ColorEdge_Euclidean_Distance_HSV(h1.f, s1.f, v1.f, h2.f, s2.f, v2.f)
  ; Distance dans l'espace HSV (circulaire pour H)
  Protected.f dh = Abs(h2 - h1)
  If dh > 180.0 : dh = 360.0 - dh : EndIf
  dh / 180.0  ; Normalisation
  Protected.f ds = s2 - s1, dv = v2 - v1
  ProcedureReturn Sqr(dh * dh + ds * ds + dv * dv)
EndProcedure

Procedure.f ColorEdge_DeltaE_Lab(L1.f, a1.f, b1.f, L2.f, a2.f, b2.f)
  ; Delta E (différence perceptuelle de couleur en Lab)
  Protected.f dL = L2 - L1, da = a2 - a1, db = b2 - b1
  ProcedureReturn Sqr(dL * dL + da * da + db * db)
EndProcedure

Procedure ColorEdgeDetection_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected sensitivity.f = *param\option[0]   ; Sensibilité (1-100)
  Protected colorSpace = *param\option[1]      ; Espace couleur (0=RGB, 1=HSV, 2=Lab)
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected method = *param\option[4]          ; 0=Sobel, 1=Gradient max, 2=Gradient composé
  
  ; Normalisation de la sensibilité
  Clamp(sensitivity, 1, 100)
  sensitivity * 0.02  ; 0.02 - 2.0
  
  ; Noyau 3x3
  Protected kRadius = 1
  Protected maxPixels = 9
  
  ; Tableaux pour les pixels
  Protected Dim r3(maxPixels - 1)
  Protected Dim g3(maxPixels - 1)
  Protected Dim b3(maxPixels - 1)
  
  ; Tableaux pour les conversions
  Protected Dim h3.f(maxPixels - 1)
  Protected Dim s3.f(maxPixels - 1)
  Protected Dim v3.f(maxPixels - 1)
  Protected Dim L3.f(maxPixels - 1)
  Protected Dim a3.f(maxPixels - 1)
  Protected Dim b3Lab.f(maxPixels - 1)
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected r, g, b
  Protected x, y, i, j, idx
  
  ; Variables pour le calcul de gradient couleur
  Protected.f distH, distV, distD1, distD2
  Protected.f gradientMagnitude, edgeStrength
  Protected magnitude
  
  ; Limites de traitement pour ce thread
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max + 1
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max
  
  Clamp(startPos, 1, ht - 2)
  Clamp(endPos, 1, ht - 2)
  
  If startPos > endPos
    ProcedureReturn
  EndIf
  
  ; ========================================================================
  ; Traitement des pixels
  ; ========================================================================
  For y = startPos To endPos
    For x = 1 To lg - 2
      
      ; Lecture du voisinage 3x3
      idx = 0
      For j = -1 To 1
        For i = -1 To 1
          *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
          ColorEdge_ReadPixel(idx)
          idx + 1
        Next
      Next
      
      ; Conversion dans l'espace colorimétrique choisi
      Select colorSpace
        Case 1  ; HSV
          For i = 0 To 8
            ColorEdge_RGB_To_HSV(r3(i), g3(i), b3(i), @h3(i), @s3(i), @v3(i))
          Next
          
        Case 2  ; Lab
          For i = 0 To 8
            ColorEdge_RGB_To_Lab(r3(i), g3(i), b3(i), @L3(i), @a3(i), @b3Lab(i))
          Next
      EndSelect
      
      If toGray
        ; ====================================================================
        ; MODE NIVEAU DE GRIS (visualisation de la force du contour couleur)
        ; ====================================================================
        
        Select method
          Case 0  ; Méthode Sobel sur les canaux couleur
            Select colorSpace
              Case 0  ; RGB
                ; Gradient horizontal (distances entre pixels gauche et droite)
                distH = (ColorEdge_Euclidean_Distance_RGB(r3(0), g3(0), b3(0), r3(2), g3(2), b3(2)) +
                        ColorEdge_Euclidean_Distance_RGB(r3(3), g3(3), b3(3), r3(5), g3(5), b3(5)) * 2.0 +
                        ColorEdge_Euclidean_Distance_RGB(r3(6), g3(6), b3(6), r3(8), g3(8), b3(8)))
                
                ; Gradient vertical
                distV = (ColorEdge_Euclidean_Distance_RGB(r3(0), g3(0), b3(0), r3(6), g3(6), b3(6)) +
                        ColorEdge_Euclidean_Distance_RGB(r3(1), g3(1), b3(1), r3(7), g3(7), b3(7)) * 2.0 +
                        ColorEdge_Euclidean_Distance_RGB(r3(2), g3(2), b3(2), r3(8), g3(8), b3(8)))
                
              Case 1  ; HSV
                distH = (ColorEdge_Euclidean_Distance_HSV(h3(0), s3(0), v3(0), h3(2), s3(2), v3(2)) +
                        ColorEdge_Euclidean_Distance_HSV(h3(3), s3(3), v3(3), h3(5), s3(5), v3(5)) * 2.0 +
                        ColorEdge_Euclidean_Distance_HSV(h3(6), s3(6), v3(6), h3(8), s3(8), v3(8)))
                
                distV = (ColorEdge_Euclidean_Distance_HSV(h3(0), s3(0), v3(0), h3(6), s3(6), v3(6)) +
                        ColorEdge_Euclidean_Distance_HSV(h3(1), s3(1), v3(1), h3(7), s3(7), v3(7)) * 2.0 +
                        ColorEdge_Euclidean_Distance_HSV(h3(2), s3(2), v3(2), h3(8), s3(8), v3(8)))
                
              Case 2  ; Lab
                distH = (ColorEdge_DeltaE_Lab(L3(0), a3(0), b3Lab(0), L3(2), a3(2), b3Lab(2)) +
                        ColorEdge_DeltaE_Lab(L3(3), a3(3), b3Lab(3), L3(5), a3(5), b3Lab(5)) * 2.0 +
                        ColorEdge_DeltaE_Lab(L3(6), a3(6), b3Lab(6), L3(8), a3(8), b3Lab(8)))
                
                distV = (ColorEdge_DeltaE_Lab(L3(0), a3(0), b3Lab(0), L3(6), a3(6), b3Lab(6)) +
                        ColorEdge_DeltaE_Lab(L3(1), a3(1), b3Lab(1), L3(7), a3(7), b3Lab(7)) * 2.0 +
                        ColorEdge_DeltaE_Lab(L3(2), a3(2), b3Lab(2), L3(8), a3(8), b3Lab(8)))
            EndSelect
            
            gradientMagnitude = Sqr(distH * distH + distV * distV)
            
          Case 1  ; Gradient maximum (distance max entre centre et voisins)
            Protected.f maxDist = 0, currentDist
            
            For i = 0 To 8
              If i = 4 : Continue : EndIf  ; Skip center
              
              Select colorSpace
                Case 0  ; RGB
                  currentDist = ColorEdge_Euclidean_Distance_RGB(r3(4), g3(4), b3(4), r3(i), g3(i), b3(i))
                Case 1  ; HSV
                  currentDist = ColorEdge_Euclidean_Distance_HSV(h3(4), s3(4), v3(4), h3(i), s3(i), v3(i))
                Case 2  ; Lab
                  currentDist = ColorEdge_DeltaE_Lab(L3(4), a3(4), b3Lab(4), L3(i), a3(i), b3Lab(i))
              EndSelect
              
              If currentDist > maxDist
                maxDist = currentDist
              EndIf
            Next
            
            gradientMagnitude = maxDist
            
          Case 2  ; Gradient composé (toutes les directions)
            Select colorSpace
              Case 0  ; RGB
                distH = ColorEdge_Euclidean_Distance_RGB(r3(3), g3(3), b3(3), r3(5), g3(5), b3(5))
                distV = ColorEdge_Euclidean_Distance_RGB(r3(1), g3(1), b3(1), r3(7), g3(7), b3(7))
                distD1 = ColorEdge_Euclidean_Distance_RGB(r3(0), g3(0), b3(0), r3(8), g3(8), b3(8))
                distD2 = ColorEdge_Euclidean_Distance_RGB(r3(2), g3(2), b3(2), r3(6), g3(6), b3(6))
              Case 1  ; HSV
                distH = ColorEdge_Euclidean_Distance_HSV(h3(3), s3(3), v3(3), h3(5), s3(5), v3(5))
                distV = ColorEdge_Euclidean_Distance_HSV(h3(1), s3(1), v3(1), h3(7), s3(7), v3(7))
                distD1 = ColorEdge_Euclidean_Distance_HSV(h3(0), s3(0), v3(0), h3(8), s3(8), v3(8))
                distD2 = ColorEdge_Euclidean_Distance_HSV(h3(2), s3(2), v3(2), h3(6), s3(6), v3(6))
              Case 2  ; Lab
                distH = ColorEdge_DeltaE_Lab(L3(3), a3(3), b3Lab(3), L3(5), a3(5), b3Lab(5))
                distV = ColorEdge_DeltaE_Lab(L3(1), a3(1), b3Lab(1), L3(7), a3(7), b3Lab(7))
                distD1 = ColorEdge_DeltaE_Lab(L3(0), a3(0), b3Lab(0), L3(8), a3(8), b3Lab(8))
                distD2 = ColorEdge_DeltaE_Lab(L3(2), a3(2), b3Lab(2), L3(6), a3(6), b3Lab(6))
            EndSelect
            
            gradientMagnitude = Sqr(distH * distH + distV * distV + distD1 * distD1 + distD2 * distD2)
        EndSelect
        
        ; Application de la sensibilité
        edgeStrength = gradientMagnitude * sensitivity * 10.0
        
        Clamp(edgeStrength, 0, 255)
        If inverse : edgeStrength = 255 - edgeStrength : EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(edgeStrength) * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR (préserve l'information de couleur du contour)
        ; ====================================================================
        
        ; Calcul du gradient (similaire mais on garde les couleurs)
        Select method
          Case 0, 2  ; Sobel ou composé
            Select colorSpace
              Case 0  ; RGB - on garde les gradients par canal
                Protected.f rxH, gxH, bxH, rxV, gxV, bxV
                Protected v
                v = (r3(2) + (r3(5) << 1) + r3(8)) - (r3(0) + (r3(3) << 1) + r3(6))
                rxH = v
                v = (g3(2) + (g3(5) << 1) + g3(8)) - (g3(0) + (g3(3) << 1) + g3(6))
                gxH = v
                v = (b3(2) + (b3(5) << 1) + b3(8)) - (b3(0) + (b3(3) << 1) + b3(6))
                bxH = v
                
                v = (r3(6) + (r3(7) << 1) + r3(8)) - (r3(0) + (r3(1) << 1) + r3(2))
                rxV = v
                v = (g3(6) + (g3(7) << 1) + g3(8)) - (g3(0) + (g3(1) << 1) + g3(2))
                gxV = v
                v = (b3(6) + (b3(7) << 1) + b3(8)) - (b3(0) + (b3(1) << 1) + b3(2))
                bxV = v 
                
                r = Sqr(rxH * rxH + rxV * rxV) * sensitivity * 2.0
                g = Sqr(gxH * gxH + gxV * gxV) * sensitivity * 2.0
                b = Sqr(bxH * bxH + bxV * bxV) * sensitivity * 2.0
                
              Default  ; HSV et Lab - on utilise la magnitude globale appliquée aux canaux
                gradientMagnitude = 0
                
                Select colorSpace
                  Case 1  ; HSV
                    distH = ColorEdge_Euclidean_Distance_HSV(h3(3), s3(3), v3(3), h3(5), s3(5), v3(5))
                    distV = ColorEdge_Euclidean_Distance_HSV(h3(1), s3(1), v3(1), h3(7), s3(7), v3(7))
                  Case 2  ; Lab
                    distH = ColorEdge_DeltaE_Lab(L3(3), a3(3), b3Lab(3), L3(5), a3(5), b3Lab(5))
                    distV = ColorEdge_DeltaE_Lab(L3(1), a3(1), b3Lab(1), L3(7), a3(7), b3Lab(7))
                EndSelect
                
                gradientMagnitude = Sqr(distH * distH + distV * distV) * sensitivity * 10.0
                
                ; On applique la magnitude aux canaux RGB originaux du centre
                r = (r3(4) / 255.0) * gradientMagnitude
                g = (g3(4) / 255.0) * gradientMagnitude
                b = (b3(4) / 255.0) * gradientMagnitude
            EndSelect
            
          Case 1  ; Gradient maximum - on utilise la couleur du pixel central
            Protected.f maxDist2 = 0, currentDist2
            
            For i = 0 To 8
              If i = 4 : Continue : EndIf
              
              Select colorSpace
                Case 0  ; RGB
                  currentDist2 = ColorEdge_Euclidean_Distance_RGB(r3(4), g3(4), b3(4), r3(i), g3(i), b3(i))
                Case 1  ; HSV
                  currentDist2 = ColorEdge_Euclidean_Distance_HSV(h3(4), s3(4), v3(4), h3(i), s3(i), v3(i))
                Case 2  ; Lab
                  currentDist2 = ColorEdge_DeltaE_Lab(L3(4), a3(4), b3Lab(4), L3(i), a3(i), b3Lab(i))
              EndSelect
              
              If currentDist2 > maxDist2
                maxDist2 = currentDist2
              EndIf
            Next
            
            gradientMagnitude = maxDist2 * sensitivity * 10.0
            
            r = (r3(4) / 255.0) * gradientMagnitude
            g = (g3(4) / 255.0) * gradientMagnitude
            b = (b3(4) / 255.0) * gradientMagnitude
        EndSelect
        
        Clamp(r, 0, 255)
        Clamp(g, 0, 255)
        Clamp(b, 0, 255)
        
        If inverse
          r = 255 - r
          g = 255 - g
          b = 255 - b
        EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b))
      EndIf
      
    Next
  Next
  
  ; Libération des tableaux
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
  FreeArray(h3())
  FreeArray(s3())
  FreeArray(v3())
  FreeArray(L3())
  FreeArray(a3())
  FreeArray(b3Lab())
EndProcedure

Procedure ColorEdgeDetection(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Specialized
    *param\name = "Color Edge Detection"
    *param\remarque = "Détection de contours basée sur les variations de couleur"
    
    ; Description des paramètres
    *param\info[0] = "Sensibilité"
    *param\info[1] = "Espace couleur (0=RGB/1=HSV/2=Lab)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "Méthode (0=Sobel/1=Max/2=Composé)"
    *param\info[5] = "masque"
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 40
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 2   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 2   : *param\info_data(5, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@ColorEdgeDetection_MT(), 5)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 304
; FirstLine = 285
; Folding = --
; EnableXP
; DPIAware