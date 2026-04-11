; ============================================================================
; Filtre Texture Edge - Détection de contours par analyse de texture
; ============================================================================
; Détecte les transitions entre régions de textures différentes
; Utilise des descripteurs statistiques locaux pour caractériser les textures
; Idéal pour segmenter des zones avec motifs différents mais intensité similaire

Macro TextureEdge_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Procedure.f TextureEdge_Variance(Array values(1), size)
  ; Calcul de la variance locale (mesure de rugosité)
  Protected i, sum.f = 0, sumSq.f = 0, mean.f, variance.f
  
  For i = 0 To size - 1
    sum + values(i)
    sumSq + values(i) * values(i)
  Next
  
  mean = sum / size
  variance = (sumSq / size) - (mean * mean)
  
  ProcedureReturn variance
EndProcedure

Procedure.f TextureEdge_Entropy(Array values(1), size)
  ; Calcul de l'entropie locale (mesure de complexité)
  Protected Dim tab_histogram(255)
  Protected i, total = 0
  Protected.f entropy = 0, prob
  
  ; Construction de l'histogramme
  For i = 0 To size - 1
    tab_histogram(values(i)) + 1
    total + 1
  Next
  
  ; Calcul de l'entropie
  For i = 0 To 255
    If tab_histogram(i) > 0
      prob = tab_histogram(i) / total
      entropy - prob * Log(prob)
    EndIf
  Next
  
  FreeArray(tab_histogram())
  ProcedureReturn entropy
EndProcedure

Procedure.f TextureEdge_Contrast(Array values(1), size)
  ; Calcul du contraste local (différence max-min)
  Protected i, minVal = 255, maxVal = 0
  
  For i = 0 To size - 1
    If values(i) < minVal : minVal = values(i) : EndIf
    If values(i) > maxVal : maxVal = values(i) : EndIf
  Next
  
  ProcedureReturn (maxVal - minVal)
EndProcedure

Procedure.f TextureEdge_Energy(Array values(1), size)
  ; Calcul de l'énergie locale (uniformité)
  Protected i, sum.f = 0
  
  For i = 0 To size - 1
    sum + values(i) * values(i)
  Next
  
  ProcedureReturn sum / size
EndProcedure

Procedure.f TextureEdge_Homogeneity(Array values(1), size)
  ; Calcul de l'homogénéité locale (uniformité des valeurs)
  Protected i, j
  Protected.f sum = 0, diff
  Protected center = size >> 1
  
  For i = 0 To size - 1
    diff = Abs(values(i) - values(center))
    sum + 1.0 / (1.0 + diff)
  Next
  
  ProcedureReturn sum / size
EndProcedure

Procedure.f TextureEdge_LBP(Array values(1))
  ; Local Binary Pattern simplifié (descripteur de texture robuste)
  ; Compare le centre avec les 8 voisins
  Protected center = values(4)
  Protected.f pattern = 0
  Protected i
  Protected Dim neighbors(7)
  
  ; Ordre des voisins : 0,1,2,3,5,6,7,8 (skip 4 = centre)
  neighbors(0) = values(0)
  neighbors(1) = values(1)
  neighbors(2) = values(2)
  neighbors(3) = values(3)
  neighbors(4) = values(5)
  neighbors(5) = values(6)
  neighbors(6) = values(7)
  neighbors(7) = values(8)
  
  ; Construction du pattern binaire
  For i = 0 To 7
    If neighbors(i) >= center
      pattern + Pow(2, i)
    EndIf
  Next
  
  FreeArray(neighbors())
  ProcedureReturn pattern
EndProcedure

Procedure.f TextureEdge_GLCM_Contrast(Array values(1), size)
  ; Contraste GLCM (Gray Level Co-occurrence Matrix) simplifié
  ; Mesure la variation locale des transitions d'intensité
  Protected i, j
  Protected.f contrast = 0, diff
  
  For i = 0 To size - 2
    diff = Abs(values(i) - values(i + 1))
    contrast + diff * diff
  Next
  
  ProcedureReturn contrast / (size - 1)
EndProcedure

Procedure.f TextureEdge_Laws_Energy(Array values(1), size)
  ; Énergie de Laws (filtres de texture)
  ; Approximation simplifiée avec masques L5, E5, S5
  Protected.f L5, E5, S5
  Protected center = size >> 1
  
  If size >= 5
    ; L5 (Level) : [1 4 6 4 1] - détecte les niveaux moyens
    L5 = values(center-2) + 4*values(center-1) + 6*values(center) + 4*values(center+1) + values(center+2)
    
    ; E5 (Edge) : [-1 -2 0 2 1] - détecte les contours
    E5 = -values(center-2) - 2*values(center-1) + 2*values(center+1) + values(center+2)
    
    ; S5 (Spot) : [-1 0 2 0 -1] - détecte les points
    S5 = -values(center-2) + 2*values(center) - values(center+2)
    
    ProcedureReturn Sqr(E5*E5 + S5*S5)
  Else
    ProcedureReturn 0
  EndIf
EndProcedure

Procedure TextureEdge_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected sensitivity.f = *param\option[0]   ; Sensibilité (1-100)
  Protected descriptor = *param\option[1]      ; Descripteur texture (0-7)
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected windowSize = *param\option[4]      ; Taille fenêtre (0=3x3, 1=5x5, 2=7x7)
  
  ; Normalisation de la sensibilité
  Clamp(sensitivity, 1, 100)
  sensitivity * 0.02  ; 0.02 - 2.0
  
  ; Détermination de la taille de la fenêtre
  Protected kSize
  Select windowSize
    Case 0 : kSize = 3
    Case 1 : kSize = 5
    Case 2 : kSize = 7
    Default : kSize = 5
  EndSelect
  
  Protected kRadius = kSize >> 1
  Protected maxPixels = kSize * kSize
  
  ; Tableaux pour les pixels
  Protected Dim r3(maxPixels - 1)
  Protected Dim g3(maxPixels - 1)
  Protected Dim b3(maxPixels - 1)
  Protected Dim gray(maxPixels - 1)
  
  ; Tableaux pour les descripteurs de texture (4 régions)
  Protected Dim textureNW(maxPixels - 1)  ; Nord-Ouest
  Protected Dim textureNE(maxPixels - 1)  ; Nord-Est
  Protected Dim textureSW(maxPixels - 1)  ; Sud-Ouest
  Protected Dim textureSE(maxPixels - 1)  ; Sud-Est
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected r, g, b
  Protected x, y, i, j, idx, subIdx
  
  ; Variables pour les descripteurs de texture
  Protected.f descNW, descNE, descSW, descSE
  Protected.f descCenter
  Protected.f diffH, diffV, diffD1, diffD2
  Protected.f textureGradient, edgeStrength
  Protected magnitude
  
  ; Limites de traitement pour ce thread
  Protected startPos = (*param\thread_pos * (ht - kSize + 1)) / *param\thread_max + kRadius
  Protected endPos   = ((*param\thread_pos + 1) * (ht - kSize + 1)) / *param\thread_max + kRadius - 1
  
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
      
      ; Lecture du voisinage complet
      idx = 0
      For j = -kRadius To kRadius
        For i = -kRadius To kRadius
          *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
          TextureEdge_ReadPixel(idx)
          idx + 1
        Next
      Next
      
      If toGray
        ; ====================================================================
        ; MODE NIVEAU DE GRIS
        ; ====================================================================
        
        ; Division de la fenêtre en 4 quadrants pour comparer les textures
        Protected halfSize = kSize >> 1
        
        ; Extraction des quadrants (pour fenêtre 5x5 par exemple)
        ; NW = Nord-Ouest, NE = Nord-Est, SW = Sud-Ouest, SE = Sud-Est
        
        If kSize >= 5
          ; Quadrant Nord-Ouest (coins supérieurs gauches)
          subIdx = 0
          For j = 0 To halfSize
            For i = 0 To halfSize
              textureNW(subIdx) = gray(j * kSize + i)
              subIdx + 1
            Next
          Next
          
          ; Quadrant Nord-Est
          subIdx = 0
          For j = 0 To halfSize
            For i = halfSize To kSize - 1
              textureNE(subIdx) = gray(j * kSize + i)
              subIdx + 1
            Next
          Next
          
          ; Quadrant Sud-Ouest
          subIdx = 0
          For j = halfSize To kSize - 1
            For i = 0 To halfSize
              textureSW(subIdx) = gray(j * kSize + i)
              subIdx + 1
            Next
          Next
          
          ; Quadrant Sud-Est
          subIdx = 0
          For j = halfSize To kSize - 1
            For i = halfSize To kSize - 1
              textureSE(subIdx) = gray(j * kSize + i)
              subIdx + 1
            Next
          Next
          
          Protected quadrantSize = (halfSize + 1) * (halfSize + 1)
          
          ; Calcul du descripteur pour chaque quadrant
          Select descriptor
            Case 0  ; Variance
              descNW = TextureEdge_Variance(textureNW(), quadrantSize)
              descNE = TextureEdge_Variance(textureNE(), quadrantSize)
              descSW = TextureEdge_Variance(textureSW(), quadrantSize)
              descSE = TextureEdge_Variance(textureSE(), quadrantSize)
              
            Case 1  ; Entropie
              descNW = TextureEdge_Entropy(textureNW(), quadrantSize)
              descNE = TextureEdge_Entropy(textureNE(), quadrantSize)
              descSW = TextureEdge_Entropy(textureSW(), quadrantSize)
              descSE = TextureEdge_Entropy(textureSE(), quadrantSize)
              
            Case 2  ; Contraste
              descNW = TextureEdge_Contrast(textureNW(), quadrantSize)
              descNE = TextureEdge_Contrast(textureNE(), quadrantSize)
              descSW = TextureEdge_Contrast(textureSW(), quadrantSize)
              descSE = TextureEdge_Contrast(textureSE(), quadrantSize)
              
            Case 3  ; Énergie
              descNW = TextureEdge_Energy(textureNW(), quadrantSize)
              descNE = TextureEdge_Energy(textureNE(), quadrantSize)
              descSW = TextureEdge_Energy(textureSW(), quadrantSize)
              descSE = TextureEdge_Energy(textureSE(), quadrantSize)
              
            Case 4  ; Homogénéité
              descNW = TextureEdge_Homogeneity(textureNW(), quadrantSize)
              descNE = TextureEdge_Homogeneity(textureNE(), quadrantSize)
              descSW = TextureEdge_Homogeneity(textureSW(), quadrantSize)
              descSE = TextureEdge_Homogeneity(textureSE(), quadrantSize)
              
            Case 5  ; LBP (Local Binary Pattern) - sur fenêtre 3x3 au centre de chaque quadrant
              If kSize = 3
                descCenter = TextureEdge_LBP(gray())
                descNW = descCenter : descNE = descCenter
                descSW = descCenter : descSE = descCenter
              Else
                ; Pour fenêtres plus grandes, on approxime
                descNW = TextureEdge_Variance(textureNW(), quadrantSize)
                descNE = TextureEdge_Variance(textureNE(), quadrantSize)
                descSW = TextureEdge_Variance(textureSW(), quadrantSize)
                descSE = TextureEdge_Variance(textureSE(), quadrantSize)
              EndIf
              
            Case 6  ; GLCM Contrast
              descNW = TextureEdge_GLCM_Contrast(textureNW(), quadrantSize)
              descNE = TextureEdge_GLCM_Contrast(textureNE(), quadrantSize)
              descSW = TextureEdge_GLCM_Contrast(textureSW(), quadrantSize)
              descSE = TextureEdge_GLCM_Contrast(textureSE(), quadrantSize)
              
            Case 7  ; Laws Energy
              descNW = TextureEdge_Laws_Energy(textureNW(), quadrantSize)
              descNE = TextureEdge_Laws_Energy(textureNE(), quadrantSize)
              descSW = TextureEdge_Laws_Energy(textureSW(), quadrantSize)
              descSE = TextureEdge_Laws_Energy(textureSE(), quadrantSize)
          EndSelect
          
          ; Calcul des différences entre quadrants
          diffH = Abs(descNW - descNE) + Abs(descSW - descSE)  ; Horizontal
          diffV = Abs(descNW - descSW) + Abs(descNE - descSE)  ; Vertical
          diffD1 = Abs(descNW - descSE)  ; Diagonale principale
          diffD2 = Abs(descNE - descSW)  ; Diagonale secondaire
          
        Else
          ; Pour fenêtre 3x3, calcul simplifié
          descCenter = 0
          Select descriptor
            Case 0 : descCenter = TextureEdge_Variance(gray(), 9)
            Case 1 : descCenter = TextureEdge_Entropy(gray(), 9)
            Case 2 : descCenter = TextureEdge_Contrast(gray(), 9)
            Case 3 : descCenter = TextureEdge_Energy(gray(), 9)
            Case 4 : descCenter = TextureEdge_Homogeneity(gray(), 9)
            Case 5 : descCenter = TextureEdge_LBP(gray())
            Case 6 : descCenter = TextureEdge_GLCM_Contrast(gray(), 9)
            Case 7 : descCenter = TextureEdge_Laws_Energy(gray(), 9)
          EndSelect
          
          diffH = descCenter * 0.5
          diffV = descCenter * 0.5
          diffD1 = descCenter * 0.3
          diffD2 = descCenter * 0.3
        EndIf
        
        ; Gradient de texture combiné
        textureGradient = Sqr(diffH * diffH + diffV * diffV + diffD1 * diffD1 + diffD2 * diffD2)
        
        ; Application de la sensibilité
        edgeStrength = textureGradient * sensitivity * 15.0
        
        Clamp(edgeStrength, 0, 255)
        If inverse : edgeStrength = 255 - edgeStrength : EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(edgeStrength) * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        ; Calcul du descripteur de texture sur chaque canal
        Protected.f descR, descG, descB
        
        Select descriptor
          Case 0 : descR = TextureEdge_Variance(r3(), maxPixels)
                   descG = TextureEdge_Variance(g3(), maxPixels)
                   descB = TextureEdge_Variance(b3(), maxPixels)
          Case 1 : descR = TextureEdge_Entropy(r3(), maxPixels)
                   descG = TextureEdge_Entropy(g3(), maxPixels)
                   descB = TextureEdge_Entropy(b3(), maxPixels)
          Case 2 : descR = TextureEdge_Contrast(r3(), maxPixels)
                   descG = TextureEdge_Contrast(g3(), maxPixels)
                   descB = TextureEdge_Contrast(b3(), maxPixels)
          Case 3 : descR = TextureEdge_Energy(r3(), maxPixels)
                   descG = TextureEdge_Energy(g3(), maxPixels)
                   descB = TextureEdge_Energy(b3(), maxPixels)
          Case 4 : descR = TextureEdge_Homogeneity(r3(), maxPixels)
                   descG = TextureEdge_Homogeneity(g3(), maxPixels)
                   descB = TextureEdge_Homogeneity(b3(), maxPixels)
          Case 6 : descR = TextureEdge_GLCM_Contrast(r3(), maxPixels)
                   descG = TextureEdge_GLCM_Contrast(g3(), maxPixels)
                   descB = TextureEdge_GLCM_Contrast(b3(), maxPixels)
          Case 7 : descR = TextureEdge_Laws_Energy(r3(), maxPixels)
                   descG = TextureEdge_Laws_Energy(g3(), maxPixels)
                   descB = TextureEdge_Laws_Energy(b3(), maxPixels)
          Default : descR = TextureEdge_Variance(gray(), maxPixels)
                    descG = descR : descB = descR
        EndSelect
        
        ; Application de la sensibilité
        r = descR * sensitivity * 15.0
        g = descG * sensitivity * 15.0
        b = descB * sensitivity * 15.0
        
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
  FreeArray(textureNW())
  FreeArray(textureNE())
  FreeArray(textureSW())
  FreeArray(textureSE())
EndProcedure

Procedure TextureEdge(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Specialized
    *param\name = "Texture Edge"
    *param\remarque = "Détection de contours par analyse de texture"
    
    ; Description des paramètres
    *param\info[0] = "Sensibilité"
    *param\info[1] = "Descripteur (0-7)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "Fenêtre (0=3x3/1=5x5/2=7x7)"
    *param\info[5] = "masque"
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 40
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 7   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 1
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 2   : *param\info_data(5, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@TextureEdge_MT(), 5)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 50
; FirstLine = 46
; Folding = --
; EnableXP
; DPIAware