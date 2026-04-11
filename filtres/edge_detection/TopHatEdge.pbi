; ============================================================================
; Filtre Top-Hat Edge - Détection de contours par Top-Hat
; ============================================================================
; Utilise les transformations Top-Hat pour détecter les contours
; White Top-Hat = Image - Opening (détecte structures claires)
; Black Top-Hat = Closing - Image (détecte structures sombres)
; Top-Hat Edge = White Top-Hat + Black Top-Hat

Macro TopHat_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Procedure.i TopHat_Dilate(Array values(1), size)
  ; Dilatation : maximum local
  Protected i, maxVal = 0
  
  For i = 0 To size - 1
    If values(i) > maxVal
      maxVal = values(i)
    EndIf
  Next
  
  ProcedureReturn maxVal
EndProcedure

Procedure.i TopHat_Erode(Array values(1), size)
  ; Érosion : minimum local
  Protected i, minVal = 255
  
  For i = 0 To size - 1
    If values(i) < minVal
      minVal = values(i)
    EndIf
  Next
  
  ProcedureReturn minVal
EndProcedure

Procedure TopHat_DilateRGB(Array r3(1), Array g3(1), Array b3(1), size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
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

Procedure TopHat_ErodeRGB(Array r3(1), Array g3(1), Array b3(1), size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
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

Procedure TopHat_CreateStructuringElement(Array element(1), shape, size)
  ; Création de l'élément structurant
  ; shape: 0=Carré, 1=Croix, 2=Disque, 3=Diamant, 4=Ligne H, 5=Ligne V
  Protected x, y, idx, center, radius.f, dist.f, distManhattan
  
  center = size >> 1
  radius = center
  idx = 0
  
  For y = 0 To size - 1
    For x = 0 To size - 1
      Select shape
        Case 0  ; Carré
          element(idx) = 1
          
        Case 1  ; Croix
          If x = center Or y = center
            element(idx) = 1
          Else
            element(idx) = 0
          EndIf
          
        Case 2  ; Disque
          dist = Sqr((x - center) * (x - center) + (y - center) * (y - center))
          If dist <= radius
            element(idx) = 1
          Else
            element(idx) = 0
          EndIf
          
        Case 3  ; Diamant
          distManhattan = Abs(x - center) + Abs(y - center)
          If distManhattan <= center
            element(idx) = 1
          Else
            element(idx) = 0
          EndIf
          
        Case 4  ; Ligne horizontale
          If y = center
            element(idx) = 1
          Else
            element(idx) = 0
          EndIf
          
        Case 5  ; Ligne verticale
          If x = center
            element(idx) = 1
          Else
            element(idx) = 0
          EndIf
      EndSelect
      idx + 1
    Next
  Next
EndProcedure

Procedure TopHatEdge_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected strength.f = *param\option[0]    ; Force (1-100)
  Protected kernelSize = *param\option[1]    ; Taille noyau (0=3x3, 1=5x5, 2=7x7)
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected mode = *param\option[4]          ; 0=Both, 1=White, 2=Black, 3=Alternate
  
  ; Normalisation de la force
  Clamp(strength, 1, 100)
  strength * 0.015  ; 0.015 - 1.5
  
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
  Protected Dim structElement(maxPixels - 1)
  
  ; Création de l'élément structurant (disque par défaut)
  TopHat_CreateStructuringElement(structElement(), 2, kSize)
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected r, g, b
  Protected x, y, i, j, idx
  
  ; Variables morphologiques pour Top-Hat
  Protected original, dilated, eroded, opening, closing
  Protected whiteTopHat, blackTopHat, topHatEdge
  Protected originalR, originalG, originalB
  Protected dilatedR, dilatedG, dilatedB
  Protected erodedR, erodedG, erodedB
  Protected openingR, openingG, openingB
  Protected closingR, closingG, closingB
  Protected whiteR, whiteG, whiteB
  Protected blackR, blackG, blackB
  Protected edgeR, edgeG, edgeB
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
      
      ; Lecture du voisinage
      idx = 0
      For j = -kRadius To kRadius
        For i = -kRadius To kRadius
          *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
          TopHat_ReadPixel(idx)
          idx + 1
        Next
      Next
      
      If toGray
        ; ====================================================================
        ; MODE NIVEAU DE GRIS
        ; ====================================================================
        
        ; Pixel central (image originale)
        original = gray((maxPixels >> 1))
        
        ; Étape 1 : Érosion
        eroded = TopHat_Erode(gray(), maxPixels)
        
        ; Étape 2 : Dilatation de l'érosion = Opening
        ; (Simplification : on utilise directement les valeurs du voisinage)
        ; Pour un vrai opening, il faudrait 2 passes, mais on approxime ici
        opening = eroded  ; Approximation simplifiée
        
        ; Étape 3 : Dilatation
        dilated = TopHat_Dilate(gray(), maxPixels)
        
        ; Étape 4 : Érosion de la dilatation = Closing
        closing = dilated  ; Approximation simplifiée
        
        ; Calcul des Top-Hat
        ; White Top-Hat : Image - Opening (détecte les pics clairs)
        whiteTopHat = original - opening
        If whiteTopHat < 0 : whiteTopHat = 0 : EndIf
        
        ; Black Top-Hat : Closing - Image (détecte les vallées sombres)
        blackTopHat = closing - original
        If blackTopHat < 0 : blackTopHat = 0 : EndIf
        
        ; Combinaison selon le mode
        Select mode
          Case 0  ; Both : White + Black (détection complète)
            topHatEdge = whiteTopHat + blackTopHat
            
          Case 1  ; White only (contours clairs)
            topHatEdge = whiteTopHat
            
          Case 2  ; Black only (contours sombres)
            topHatEdge = blackTopHat
            
          Case 3  ; Alternate : max des deux
            Max(topHatEdge , whiteTopHat, blackTopHat)
        EndSelect
        
        ; Application de la force
        magnitude = topHatEdge * strength * 10.0
        
        Clamp(magnitude, 0, 255)
        If inverse : magnitude = 255 - magnitude : EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        ; Pixels centraux (image originale)
        originalR = r3((maxPixels >> 1))
        originalG = g3((maxPixels >> 1))
        originalB = b3((maxPixels >> 1))
        
        ; Érosion
        TopHat_ErodeRGB(r3(), g3(), b3(), maxPixels, @erodedR, @erodedG, @erodedB)
        
        ; Opening (approximation)
        openingR = erodedR
        openingG = erodedG
        openingB = erodedB
        
        ; Dilatation
        TopHat_DilateRGB(r3(), g3(), b3(), maxPixels, @dilatedR, @dilatedG, @dilatedB)
        
        ; Closing (approximation)
        closingR = dilatedR
        closingG = dilatedG
        closingB = dilatedB
        
        ; White Top-Hat pour chaque canal
        whiteR = originalR - openingR : If whiteR < 0 : whiteR = 0 : EndIf
        whiteG = originalG - openingG : If whiteG < 0 : whiteG = 0 : EndIf
        whiteB = originalB - openingB : If whiteB < 0 : whiteB = 0 : EndIf
        
        ; Black Top-Hat pour chaque canal
        blackR = closingR - originalR : If blackR < 0 : blackR = 0 : EndIf
        blackG = closingG - originalG : If blackG < 0 : blackG = 0 : EndIf
        blackB = closingB - originalB : If blackB < 0 : blackB = 0 : EndIf
        
        ; Combinaison selon le mode
        Select mode
          Case 0  ; Both
            edgeR = whiteR + blackR
            edgeG = whiteG + blackG
            edgeB = whiteB + blackB
            
          Case 1  ; White only
            edgeR = whiteR
            edgeG = whiteG
            edgeB = whiteB
            
          Case 2  ; Black only
            edgeR = blackR
            edgeG = blackG
            edgeB = blackB
            
          Case 3  ; Alternate
            Max(edgeR , whiteR, blackR)
            Max(edgeG , whiteG, blackG)
            Max(edgeB , whiteB, blackB)
        EndSelect
        
        ; Application de la force
        r = edgeR * strength * 10.0
        g = edgeG * strength * 10.0
        b = edgeB * strength * 10.0
        
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
  FreeArray(structElement())
EndProcedure

Procedure TopHatEdge(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Morphological
    *param\name = "Top-Hat Edge"
    *param\remarque = "Détection de contours par transformations Top-Hat"
    
    ; Description des paramètres
    *param\info[0] = "Force"
    *param\info[1] = "Taille noyau (0=3x3/1=5x5/2=7x7)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "Mode (0=Both/1=White/2=Black/3=Max)"
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
  filter_start(@TopHatEdge_MT(), 5)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 364
; FirstLine = 318
; Folding = --
; EnableXP
; DPIAware