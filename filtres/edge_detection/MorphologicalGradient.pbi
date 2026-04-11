; ============================================================================
; Filtre Morphological Gradient - Gradient morphologique
; ============================================================================
; Basé sur les opérations morphologiques de dilatation et érosion
; Gradient = Dilatation - Érosion
; Détecte les contours en analysant les variations d'intensité locales

Macro MorphGrad_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Procedure.i MorphGrad_Dilate(Array values(1), size)
  ; Dilatation : maximum local (expansion des zones claires)
  Protected i, maxVal = 0
  
  For i = 0 To size - 1
    If values(i) > maxVal
      maxVal = values(i)
    EndIf
  Next
  
  ProcedureReturn maxVal
EndProcedure

Procedure.i MorphGrad_Erode(Array values(1), size)
  ; Érosion : minimum local (contraction des zones claires)
  Protected i, minVal = 255
  
  For i = 0 To size - 1
    If values(i) < minVal
      minVal = values(i)
    EndIf
  Next
  
  ProcedureReturn minVal
EndProcedure

Procedure MorphGrad_DilateRGB(Array r3(1), Array g3(1), Array b3(1), size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
  ; Dilatation pour chaque canal couleur
  Protected i
  Protected maxR = 0, maxG = 0, maxB = 0
  
  For i = 0 To size - 1
    If r3(i) > maxR : maxR = r3(i) : EndIf
    If g3(i) > maxG : maxG = g3(i) : EndIf
    If b3(i) > maxB : maxB = b3(i) : EndIf
  Next
  
  PokeI(*rOut, maxR)
  PokeI(*gOut, maxG)
  PokeI(*bOut, maxB)
EndProcedure

Procedure MorphGrad_ErodeRGB(Array r3(1), Array g3(1), Array b3(1), size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
  ; Érosion pour chaque canal couleur
  Protected i
  Protected minR = 255, minG = 255, minB = 255
  
  For i = 0 To size - 1
    If r3(i) < minR : minR = r3(i) : EndIf
    If g3(i) < minG : minG = g3(i) : EndIf
    If b3(i) < minB : minB = b3(i) : EndIf
  Next
  
  PokeI(*rOut, minR)
  PokeI(*gOut, minG)
  PokeI(*bOut, minB)
EndProcedure

Procedure MorphGrad_CreateStructuringElement(Array element(1), shape, size)
  ; Création de l'élément structurant
  ; shape: 0=Carré, 1=Croix, 2=Disque, 3=Diamant
  Protected x, y, idx, center, radius.f, dist.f
  
  center = size >> 1
  radius = center
  idx = 0
  
  For y = 0 To size - 1
    For x = 0 To size - 1
      Select shape
        Case 0  ; Carré (rectangle plein)
          element(idx) = 1
          
        Case 1  ; Croix
          If x = center Or y = center
            element(idx) = 1
          Else
            element(idx) = 0
          EndIf
          
        Case 2  ; Disque (approximation circulaire)
          dist = Sqr((x - center) * (x - center) + (y - center) * (y - center))
          If dist <= radius
            element(idx) = 1
          Else
            element(idx) = 0
          EndIf
          
        Case 3  ; Diamant
          dist = Abs(x - center) + Abs(y - center)
          If dist <= center
            element(idx) = 1
          Else
            element(idx) = 0
          EndIf
      EndSelect
      idx + 1
    Next
  Next
EndProcedure

Procedure MorphologicalGradient_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected strength.f = *param\option[0]    ; Force du gradient (1-100)
  Protected kernelSize = *param\option[1]    ; Taille noyau (0=3x3, 1=5x5, 2=7x7)
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected shape = *param\option[4]         ; Forme élément structurant
  
  ; Normalisation de la force
  Clamp(strength, 1, 100)
  strength * 0.01  ; 0.01 - 1.0
  
  ; Détermination de la taille du noyau
  Protected kSize
  Select kernelSize
    Case 0 : kSize = 3
    Case 1 : kSize = 5
    Case 2 : kSize = 7
    Default : kSize = 3
  EndSelect
  
  Protected kRadius = kSize >> 1
  Protected maxPixels = kSize * kSize
  
  ; Tableaux pour les pixels
  Protected Dim r3(maxPixels - 1)
  Protected Dim g3(maxPixels - 1)
  Protected Dim b3(maxPixels - 1)
  Protected Dim gray(maxPixels - 1)
  Protected Dim grayFiltered(maxPixels - 1)
  Protected Dim structElement(maxPixels - 1)
  
  ; Création de l'élément structurant
  MorphGrad_CreateStructuringElement(structElement(), shape, kSize)
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected r, g, b
  Protected x, y, i, j, idx, filtIdx
  
  ; Variables morphologiques
  Protected dilated, eroded, gradient
  Protected dilatedR, dilatedG, dilatedB
  Protected erodedR, erodedG, erodedB
  Protected gradR, gradG, gradB
  Protected magnitude.f
  
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
      
      ; Lecture du voisinage selon la taille du noyau
      idx = 0
      For j = -kRadius To kRadius
        For i = -kRadius To kRadius
          *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
          MorphGrad_ReadPixel(idx)
          idx + 1
        Next
      Next
      
      If toGray
        ; ====================================================================
        ; MODE NIVEAU DE GRIS
        ; ====================================================================
        
        ; Application de l'élément structurant (masquage)
        filtIdx = 0
        For idx = 0 To maxPixels - 1
          If structElement(idx) = 1
            grayFiltered(filtIdx) = gray(idx)
            filtIdx + 1
          EndIf
        Next
        
        ; Opérations morphologiques
        dilated = MorphGrad_Dilate(grayFiltered(), filtIdx)
        eroded = MorphGrad_Erode(grayFiltered(), filtIdx)
        
        ; Calcul du gradient morphologique
        gradient = dilated - eroded
        
        ; Application de la force
        magnitude = gradient * strength * 10.0
        
        Clamp(magnitude, 0, 255)
        If inverse : magnitude = 255 - magnitude : EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        ; Opérations morphologiques sur chaque canal
        MorphGrad_DilateRGB(r3(), g3(), b3(), maxPixels, @dilatedR, @dilatedG, @dilatedB)
        MorphGrad_ErodeRGB(r3(), g3(), b3(), maxPixels, @erodedR, @erodedG, @erodedB)
        
        ; Calcul du gradient pour chaque canal
        gradR = dilatedR - erodedR
        gradG = dilatedG - erodedG
        gradB = dilatedB - erodedB
        
        ; Application de la force
        r = gradR * strength * 10.0
        g = gradG * strength * 10.0
        b = gradB * strength * 10.0
        
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
        PokeL(*dstPixel, $FF000000 | (r << 16) | (g << 8) | b)
      EndIf
      
    Next
  Next
  
  ; Libération des tableaux
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
  FreeArray(gray())
  FreeArray(grayFiltered())
  FreeArray(structElement())
EndProcedure

Procedure MorphologicalGradient(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Morphological
    *param\name = "Morphological Gradient"
    *param\remarque = "Gradient morphologique (Dilatation - Érosion)"
    
    ; Description des paramètres
    *param\info[0] = "Force du gradient"
    *param\info[1] = "Taille noyau (0=3x3/1=5x5/2=7x7)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "Forme (0=Carré/1=Croix/2=Disque/3=Diamant)"
    *param\info[5] = "masque"
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 50
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 2   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 3   : *param\info_data(4, 2) = 0
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 2   : *param\info_data(5, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@MorphologicalGradient_MT(), 5)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 271
; FirstLine = 229
; Folding = --
; EnableXP
; DPIAware