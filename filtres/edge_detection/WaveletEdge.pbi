; ============================================================================
; Filtre Wavelet Edge - Détection de contours par ondelettes
; ============================================================================
; Utilise la transformée en ondelettes de Haar pour détecter les contours
; Décompose l'image en coefficients d'approximation et de détails
; Les contours sont extraits des coefficients de détails (horizontal, vertical, diagonal)

Macro WaveletEdge_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Procedure.f Wavelet_Haar_Horizontal(Array values(1), size)
  ; Filtre Haar horizontal : détecte les contours verticaux
  ; Noyau Haar : [-1 +1]
  Protected sum.f = 0
  Protected i, half = size >> 1
  
  For i = 0 To half - 1
    sum + values(i)
  Next
  Protected left = sum / half
  
  sum = 0
  For i = half To size - 1
    sum + values(i)
  Next
  Protected right = sum / half
  
  ProcedureReturn Abs(right - left)
EndProcedure

Procedure.f Wavelet_Haar_Vertical(Array cols(1), size)
  ; Filtre Haar vertical : détecte les contours horizontaux
  Protected sum.f = 0
  Protected i, half = size >> 1
  
  For i = 0 To half - 1
    sum + cols(i)
  Next
  Protected top = sum / half
  
  sum = 0
  For i = half To size - 1
    sum + cols(i)
  Next
  Protected bottom = sum / half
  
  ProcedureReturn Abs(bottom - top)
EndProcedure

Procedure.f Wavelet_Daubechies_D4(Array values(1))
  ; Ondelette Daubechies D4 (4 coefficients)
  ; Coefficients : h0=0.683, h1=1.183, h2=-0.316, h3=-0.183
  Protected.f h0 = 0.683, h1 = 1.183, h2 = -0.316, h3 = -0.183
  Protected.f result = 0
  
  If ArraySize(values()) >= 3
    result = Abs(values(0) * h0 + values(1) * h1 + values(2) * h2 + values(3) * h3)
  EndIf
  
  ProcedureReturn result
EndProcedure

Procedure.f Wavelet_Mexican_Hat(Array values(1), size)
  ; Ondelette Mexican Hat (chapeau mexicain) / Ricker wavelet
  ; Dérivée seconde d'une Gaussienne
  Protected center = size >> 1
  Protected i, x.f, sigma.f = 1.0, coeff.f, sum.f = 0
  
  For i = 0 To size - 1
    x = (i - center)
    coeff = (1.0 - (x * x) / (sigma * sigma)) * Exp(-(x * x) / (2.0 * sigma * sigma))
    sum + values(i) * coeff
  Next
  
  ProcedureReturn Abs(sum)
EndProcedure

Procedure.f Wavelet_Morlet(Array values(1), size)
  ; Ondelette de Morlet
  ; Gaussienne modulée par une sinusoïde
  Protected center = size >> 1
  Protected i, x.f, sigma.f = 1.0, omega.f = 5.0, coeff.f, sum.f = 0
  
  For i = 0 To size - 1
    x = (i - center) / sigma
    coeff = Exp(-(x * x) / 2.0) * Cos(omega * x)
    sum + values(i) * coeff
  Next
  
  ProcedureReturn Abs(sum)
EndProcedure

Procedure.f Wavelet_Compute_Detail_Coefficients(Array values(1), size, waveletType)
  ; Calcul des coefficients de détails selon le type d'ondelette
  Protected result.f = 0
  
  Select waveletType
    Case 0  ; Haar
      result = Wavelet_Haar_Horizontal(values(), size)
      
    Case 1  ; Daubechies D4
      result = Wavelet_Daubechies_D4(values())
      
    Case 2  ; Mexican Hat
      result = Wavelet_Mexican_Hat(values(), size)
      
    Case 3  ; Morlet
      result = Wavelet_Morlet(values(), size)
  EndSelect
  
  ProcedureReturn result
EndProcedure

Procedure WaveletEdge_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected threshold.f = *param\option[0]    ; Seuil de détection (1-100)
  Protected waveletType = *param\option[1]    ; Type d'ondelette (0-3)
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected decomp = *param\option[4]         ; Niveau de décomposition (0-2)
  
  ; Normalisation du seuil
  Clamp(threshold, 1, 100)
  threshold * 0.01  ; 0.01 - 1.0
  
  ; Taille du noyau selon le niveau de décomposition
  Protected kSize
  Select decomp
    Case 0 : kSize = 3   ; Décomposition niveau 1
    Case 1 : kSize = 5   ; Décomposition niveau 2
    Case 2 : kSize = 7   ; Décomposition niveau 3
    Default : kSize = 3
  EndSelect
  
  Protected kRadius = kSize >> 1
  Protected maxPixels = kSize * kSize
  
  ; Tableaux pour les pixels et les coefficients
  Protected Dim r3(maxPixels - 1)
  Protected Dim g3(maxPixels - 1)
  Protected Dim b3(maxPixels - 1)
  Protected Dim gray(maxPixels - 1)
  Protected Dim rowValues(kSize - 1)
  Protected Dim colValues(kSize - 1)
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected r, g, b
  Protected x, y, i, j, idx
  
  ; Coefficients d'ondelettes
  Protected detailH.f, detailV.f, detailD.f  ; Horizontal, Vertical, Diagonal
  Protected detailHR.f, detailVR.f, detailDR.f
  Protected detailHG.f, detailVG.f, detailDG.f
  Protected detailHB.f, detailVB.f, detailDB.f
  Protected edgeStrength.f, magnitude.f
  
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
          WaveletEdge_ReadPixel(idx)
          idx + 1
        Next
      Next
      
      If toGray
        ; ====================================================================
        ; MODE NIVEAU DE GRIS
        ; ====================================================================
        
        ; Extraction de la ligne centrale (détails horizontaux)
        For i = 0 To kSize - 1
          rowValues(i) = gray(kRadius * kSize + i)
        Next
        detailH = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
        
        ; Extraction de la colonne centrale (détails verticaux)
        For i = 0 To kSize - 1
          colValues(i) = gray(i * kSize + kRadius)
        Next
        detailV = Wavelet_Compute_Detail_Coefficients(colValues(), kSize, waveletType)
        
        ; Détails diagonaux (approximation via la diagonale principale)
        For i = 0 To kSize - 1
          rowValues(i) = gray(i * kSize + i)
        Next
        detailD = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
        
        ; Combinaison des coefficients de détails
        ; La norme des coefficients donne la force du contour
        edgeStrength = Sqr(detailH * detailH + detailV * detailV + detailD * detailD)
        
        ; Application du seuil
        magnitude = edgeStrength * threshold * 20.0
        
        Clamp(magnitude, 0, 255)
        If inverse : magnitude = 255 - magnitude : EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        ; Canal Rouge
        For i = 0 To kSize - 1
          rowValues(i) = r3(kRadius * kSize + i)
        Next
        detailHR = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
        
        For i = 0 To kSize - 1
          colValues(i) = r3(i * kSize + kRadius)
        Next
        detailVR = Wavelet_Compute_Detail_Coefficients(colValues(), kSize, waveletType)
        
        For i = 0 To kSize - 1
          rowValues(i) = r3(i * kSize + i)
        Next
        detailDR = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
        
        ; Canal Vert
        For i = 0 To kSize - 1
          rowValues(i) = g3(kRadius * kSize + i)
        Next
        detailHG = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
        
        For i = 0 To kSize - 1
          colValues(i) = g3(i * kSize + kRadius)
        Next
        detailVG = Wavelet_Compute_Detail_Coefficients(colValues(), kSize, waveletType)
        
        For i = 0 To kSize - 1
          rowValues(i) = g3(i * kSize + i)
        Next
        detailDG = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
        
        ; Canal Bleu
        For i = 0 To kSize - 1
          rowValues(i) = b3(kRadius * kSize + i)
        Next
        detailHB = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
        
        For i = 0 To kSize - 1
          colValues(i) = b3(i * kSize + kRadius)
        Next
        detailVB = Wavelet_Compute_Detail_Coefficients(colValues(), kSize, waveletType)
        
        For i = 0 To kSize - 1
          rowValues(i) = b3(i * kSize + i)
        Next
        detailDB = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
        
        ; Combinaison pour chaque canal
        r = Sqr(detailHR * detailHR + detailVR * detailVR + detailDR * detailDR) * threshold * 20.0
        g = Sqr(detailHG * detailHG + detailVG * detailVG + detailDG * detailDG) * threshold * 20.0
        b = Sqr(detailHB * detailHB + detailVB * detailVB + detailDB * detailDB) * threshold * 20.0
        
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
  FreeArray(rowValues())
  FreeArray(colValues())
EndProcedure

Procedure WaveletEdge(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_MultiScale
    *param\name = "Wavelet Edge"
    *param\remarque = "Détection de contours par transformée en ondelettes"
    
    ; Description des paramètres
    *param\info[0] = "Seuil de détection"
    *param\info[1] = "Ondelette (0=Haar/1=Daub/2=MexHat/3=Morlet)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "Décomposition (0=Niv1/1=Niv2/2=Niv3)"
    *param\info[5] = "masque"
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 30
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 3   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 2   : *param\info_data(5, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@WaveletEdge_MT(), 5)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 315
; FirstLine = 273
; Folding = --
; EnableXP
; DPIAware