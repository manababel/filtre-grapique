; ============================================================================
; Filtre Multiscale Edge - Détection de contours multi-échelle
; ============================================================================
; Détecte les contours à plusieurs échelles simultanément et les fusionne
; Combine l'information de noyaux 3x3, 5x5 et 7x7 pour une détection robuste
; Inspiré des approches de Lindeberg et de la théorie de l'espace d'échelle

Macro MultiscaleEdge_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Procedure.f MultiscaleEdge_Gradient3x3(Array values(1), offset)
  ; Gradient Sobel 3x3 à un offset donné
  Protected gx.f, gy.f , v
  
  v = (values(offset + 2) + (values(offset + 5) << 1) + values(offset + 8)) - (values(offset + 0) + (values(offset + 3) << 1) + values(offset + 6))
  gx = v
  v = (values(offset + 6) + (values(offset + 7) << 1) + values(offset + 8)) - (values(offset + 0) + (values(offset + 1) << 1) + values(offset + 2))
  gx = v
  ProcedureReturn Sqr(gx * gx + gy * gy)
EndProcedure

Procedure.f MultiscaleEdge_Gradient5x5(Array values(1))
  ; Gradient 5x5 avec noyau étendu
  Protected gx.f, gy.f
  Protected c = 12  ; Centre du noyau 5x5 (25 pixels, index 12)
  
  ; Sobel 5x5 simplifié
  gx = (values(4) - values(0)) * 1.0 + 
       (values(9) - values(5)) * 2.0 + 
       (values(14) - values(10)) * 2.0 + 
       (values(19) - values(15)) * 1.0 + 
       (values(24) - values(20)) * 1.0
  
  gy = (values(20) - values(0)) * 1.0 + 
       (values(21) - values(1)) * 2.0 + 
       (values(22) - values(2)) * 2.0 + 
       (values(23) - values(3)) * 1.0 + 
       (values(24) - values(4)) * 1.0
  
  ProcedureReturn Sqr(gx * gx + gy * gy) * 0.4
EndProcedure

Procedure.f MultiscaleEdge_Gradient7x7(Array values(1))
  ; Gradient 7x7 - très large échelle
  Protected gx.f, gy.f
  
  ; Gradient basé sur les coins du noyau 7x7
  gx = (values(48) + values(41) + values(34)) - (values(0) + values(7) + values(14))
  gy = (values(42) + values(43) + values(44)) - (values(0) + values(1) + values(2))
  
  ProcedureReturn Sqr(gx * gx + gy * gy) * 0.25
EndProcedure

Procedure.f MultiscaleEdge_LaplacianOfGaussian(Array values(1), scale)
  ; Approximation du Laplacien de Gaussienne pour détecter les contours
  Protected center, sum.f, mean.f, laplacian.f
  Protected i, count
  
  Select scale
    Case 0  ; 3x3
      center = 4
      count = 9
      ; LoG approximé : centre - moyenne voisinage
      For i = 0 To 8
        sum + values(i)
      Next
      mean = sum / 9.0
      laplacian = Abs(values(center) - mean) * 2.0
      
    Case 1  ; 5x5
      center = 12
      count = 25
      For i = 0 To 24
        sum + values(i)
      Next
      mean = sum / 25.0
      laplacian = Abs(values(center) - mean) * 1.5
      
    Case 2  ; 7x7
      center = 24
      count = 49
      For i = 0 To 48
        sum + values(i)
      Next
      mean = sum / 49.0
      laplacian = Abs(values(center) - mean) * 1.0
  EndSelect
  
  ProcedureReturn laplacian
EndProcedure

Procedure.f MultiscaleEdge_LocalVariance(Array values(1), size)
  ; Variance locale - mesure de texture/activité
  Protected i, sum.f, sumSq.f, mean.f, variance.f
  Protected count = size * size
  
  For i = 0 To count - 1
    sum + values(i)
    sumSq + values(i) * values(i)
  Next
  
  mean = sum / count
  variance = (sumSq / count) - (mean * mean)
  
  ProcedureReturn Sqr(variance) * 0.5
EndProcedure

Procedure MultiscaleEdge_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected sensitivity.f = *param\option[0]  ; Sensibilité (1-100)
  Protected scaleMode = *param\option[1]      ; 0=3 scales, 1=Fine, 2=Medium, 3=Coarse
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected fusion = *param\option[4]         ; 0=Weighted, 1=Max, 2=Average, 3=Adaptive
  
  ; Normalisation de la sensibilité
  Clamp(sensitivity, 1, 100)
  sensitivity * 0.02  ; 0.02 - 2.0
  
  ; Taille maximale de noyau : 7x7
  Protected kRadius = 3
  Protected maxPixels = 49  ; 7x7
  
  ; Tableaux pour les pixels
  Protected Dim r3(maxPixels - 1)
  Protected Dim g3(maxPixels - 1)
  Protected Dim b3(maxPixels - 1)
  Protected Dim gray(maxPixels - 1)
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected r, g, b
  Protected x, y, i, j, idx
  
  ; Variables multi-échelle
  Protected scale1.f, scale2.f, scale3.f  ; Gradients à différentes échelles
  Protected laplacian1.f, laplacian2.f, laplacian3.f  ; LoG à différentes échelles
  Protected variance1.f, variance2.f, variance3.f  ; Variance locale
  Protected fusedEdge.f, magnitude.f
  
  ; Poids adaptatifs pour la fusion
  Protected w1.f, w2.f, w3.f
  Protected totalWeight.f
  
  ; Limites de traitement pour ce thread
  Protected startPos = (*param\thread_pos * (ht - 6)) / *param\thread_max + kRadius
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 6)) / *param\thread_max + kRadius - 1
  
  Clamp(startPos, kRadius, ht - kRadius - 1)
  Clamp(endPos, kRadius, ht - kRadius - 1)
  
  If startPos > endPos
    ProcedureReturn
  EndIf
  
  ; ========================================================================
  ; Traitement des pixels
  ; ========================================================================
  For y = startPos To endPos
    For x = kRadius To lg - kRadius - 1
      
      ; Lecture du voisinage 7x7 complet
      idx = 0
      For j = -kRadius To kRadius
        For i = -kRadius To kRadius
          *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
          MultiscaleEdge_ReadPixel(idx)
          idx + 1
        Next
      Next
      
      If toGray
        ; ====================================================================
        ; MODE NIVEAU DE GRIS
        ; ====================================================================
        
        Select scaleMode
          Case 0  ; Trois échelles (3x3, 5x5, 7x7)
            ; Échelle fine (3x3) - détails
            scale1 = MultiscaleEdge_Gradient3x3(gray(), 16)  ; Centre à offset 16 pour 3x3 dans 7x7
            laplacian1 = MultiscaleEdge_LaplacianOfGaussian(gray(), 0)
            
            ; Échelle moyenne (5x5) - structures
            scale2 = MultiscaleEdge_Gradient5x5(gray())
            laplacian2 = MultiscaleEdge_LaplacianOfGaussian(gray(), 1)
            
            ; Échelle grossière (7x7) - contexte
            scale3 = MultiscaleEdge_Gradient7x7(gray())
            laplacian3 = MultiscaleEdge_LaplacianOfGaussian(gray(), 2)
            variance3 = MultiscaleEdge_LocalVariance(gray(), 7)
            
          Case 1  ; Fine only (détails uniquement)
            scale1 = MultiscaleEdge_Gradient3x3(gray(), 16) * 1.5
            laplacian1 = MultiscaleEdge_LaplacianOfGaussian(gray(), 0)
            scale2 = 0 : scale3 = 0
            laplacian2 = 0 : laplacian3 = 0 : variance3 = 0
            
          Case 2  ; Medium only (structures moyennes)
            scale1 = 0
            scale2 = MultiscaleEdge_Gradient5x5(gray()) * 2.0
            laplacian2 = MultiscaleEdge_LaplacianOfGaussian(gray(), 1)
            scale3 = 0
            laplacian1 = 0 : laplacian3 = 0 : variance3 = 0
            
          Case 3  ; Coarse only (grandes structures)
            scale1 = 0 : scale2 = 0
            scale3 = MultiscaleEdge_Gradient7x7(gray()) * 3.0
            laplacian3 = MultiscaleEdge_LaplacianOfGaussian(gray(), 2)
            variance3 = MultiscaleEdge_LocalVariance(gray(), 7)
            laplacian1 = 0 : laplacian2 = 0
        EndSelect
        
        ; Fusion des échelles
        Select fusion
          Case 0  ; Weighted (pondéré hiérarchique)
            w1 = 0.5  ; Détails fins - poids fort
            w2 = 0.3  ; Structures moyennes
            w3 = 0.2  ; Contexte global
            fusedEdge = (scale1 + laplacian1) * w1 + 
                       (scale2 + laplacian2) * w2 + 
                       (scale3 + laplacian3 + variance3) * w3
            
          Case 1  ; Maximum (contour le plus fort)
            Max(fusedEdge , (scale2 + laplacian2), (scale3 + laplacian3))
            Max(fusedEdge , (scale1 + laplacian1), fusedEdge)
            
          Case 2  ; Average (moyenne simple)
            If scaleMode = 0
              fusedEdge = ((scale1 + laplacian1) + (scale2 + laplacian2) + (scale3 + laplacian3)) / 3.0
            Else
              fusedEdge = scale1 + scale2 + scale3 + laplacian1 + laplacian2 + laplacian3
            EndIf
            
          Case 3  ; Adaptive (poids adaptatifs selon l'activité locale)
            ; Calcul des poids basés sur l'intensité de chaque échelle
            totalWeight = scale1 + scale2 + scale3 + 0.1  ; +0.1 pour éviter division par zéro
            w1 = scale1 / totalWeight
            w2 = scale2 / totalWeight
            w3 = scale3 / totalWeight
            fusedEdge = (scale1 + laplacian1) * w1 + 
                       (scale2 + laplacian2) * w2 + 
                       (scale3 + laplacian3) * w3
        EndSelect
        
        ; Application de la sensibilité
        magnitude = fusedEdge * sensitivity * 5.0
        
        Clamp(magnitude, 0, 255)
        If inverse : magnitude = 255 - magnitude : EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        ; Calcul multi-échelle pour chaque canal
        ; (Simplifié : on utilise le gradient maximum des 3 canaux)
        Protected maxGrad1.f, maxGrad2.f, maxGrad3.f
        
        Select scaleMode
          Case 0  ; Trois échelles
            scale1 = MultiscaleEdge_Gradient3x3(gray(), 16)
            scale2 = MultiscaleEdge_Gradient5x5(gray())
            scale3 = MultiscaleEdge_Gradient7x7(gray())
            variance3 = MultiscaleEdge_LocalVariance(gray(), 7)
            
          Case 1  ; Fine
            scale1 = MultiscaleEdge_Gradient3x3(gray(), 16) * 1.5
            scale2 = 0 : scale3 = 0 : variance3 = 0
            
          Case 2  ; Medium
            scale1 = 0
            scale2 = MultiscaleEdge_Gradient5x5(gray()) * 2.0
            scale3 = 0 : variance3 = 0
            
          Case 3  ; Coarse
            scale1 = 0 : scale2 = 0
            scale3 = MultiscaleEdge_Gradient7x7(gray()) * 3.0
            variance3 = MultiscaleEdge_LocalVariance(gray(), 7)
        EndSelect
        
        ; Fusion
        Select fusion
          Case 0  ; Weighted
            fusedEdge = scale1 * 0.5 + scale2 * 0.3 + (scale3 + variance3) * 0.2
          Case 1  ; Maximum
            Max(fusedEdge , scale2, scale3)
            Max(fusedEdge , scale1, fusedEdge)
          Case 2  ; Average
            If scaleMode = 0
              fusedEdge = (scale1 + scale2 + scale3) / 3.0
            Else
              fusedEdge = scale1 + scale2 + scale3
            EndIf
          Case 3  ; Adaptive
            totalWeight = scale1 + scale2 + scale3 + 0.1
            fusedEdge = (scale1 * scale1 + scale2 * scale2 + scale3 * scale3) / totalWeight
        EndSelect
        
        ; Application sur chaque canal avec variation
        magnitude = fusedEdge * sensitivity * 5.0
        r = magnitude * 1.0
        g = magnitude * 0.98
        b = magnitude * 0.96
        
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
  FreeArray(gray())
EndProcedure

Procedure MultiscaleEdge(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_MultiScale
    *param\name = "Multiscale Edge"
    *param\remarque = "Détection multi-échelle avec fusion intelligente"
    
    ; Description des paramètres
    *param\info[0] = "Sensibilité"
    *param\info[1] = "Échelles (0=All/1=Fine/2=Med/3=Coarse)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "Fusion (0=Pond/1=Max/2=Moy/3=Adapt)"
    *param\info[5] = "masque"
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 40
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 3   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 3   : *param\info_data(4, 2) = 0
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 2   : *param\info_data(5, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@MultiscaleEdge_MT(), 5)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 300
; FirstLine = 286
; Folding = --
; EnableXP
; DPIAware