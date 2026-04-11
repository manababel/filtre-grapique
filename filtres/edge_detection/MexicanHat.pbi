; ============================================================================
; Filtre Mexican Hat (Laplacian of Gaussian) - Détection de contours
; ============================================================================

Macro MexicanHat_ReadGray(var)
  getrgb(PeekL(*srcPixel), r, g, b)
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Macro MexicanHat_ReadRGB(var)
  getrgb(PeekL(*srcPixel), r3(var), g3(var), b3(var))
  *srcPixel + 4
EndMacro

Procedure MexicanHat_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected mul.f = *param\option[0]
  Protected toGray = *param\option[1]
  Protected inverse = *param\option[2]
  Protected sigma.f = *param\option[3]
  
  ; Normalisation du multiplicateur (0-100 -> 0-2)
  Clamp(mul, 1, 100)
  mul = mul * 0.02
  
  ; Normalisation du sigma (1-100 -> 0.5-3.0)
  Clamp(sigma, 1, 100)
  sigma = 0.5 + (sigma - 1) * 0.025
  
  ; Tableaux pour stocker les valeurs RGB/Gray des 25 pixels du noyau 5x5
  Protected Dim r3(24)
  Protected Dim g3(24)
  Protected Dim b3(24)
  Protected Dim gray(24)
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected a, r, g, b
  Protected x, y, i
  Protected result_r.f, result_g.f, result_b.f, result_gray.f
  
  ; Précalcul du noyau Mexican Hat 5x5
  Protected Dim kernel.f(24)
  Protected sigma2.f = sigma * sigma
  Protected sigma4.f = sigma2 * sigma2
  Protected kernel_sum.f = 0
  Protected idx = 0
  
  ; Génération du noyau LoG (Laplacian of Gaussian)
  ; Formule: LoG(x,y) = -1/(π*σ^4) * [1 - (x²+y²)/(2σ²)] * exp(-(x²+y²)/(2σ²))
  For y = -2 To 2
    For x = -2 To 2
      Protected dist2.f = x * x + y * y
      Protected gauss.f = Exp(-dist2 / (2 * sigma2))
      kernel(idx) = (-1.0 / (3.14159 * sigma4)) * (1.0 - dist2 / (2 * sigma2)) * gauss
      kernel_sum + Abs(kernel(idx))
      idx + 1
    Next
  Next
  
  ; Normalisation du noyau pour éviter l'assombrissement
  If kernel_sum > 0
    For i = 0 To 24
      kernel(i) = kernel(i) / kernel_sum * 10.0
    Next
  EndIf
  
  ; Calcul des limites de traitement pour ce thread
  Protected startPos = (*param\thread_pos * (ht - 4)) / *param\thread_max + 2
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 4)) / *param\thread_max + 1
  
  ; Validation des limites (éviter les bords - 2 pixels de marge pour noyau 5x5)
  Clamp(startPos, 2, ht - 3)
  Clamp(endPos, 2, ht - 3)
  
  ; Vérification que la zone de traitement est valide
  If startPos > endPos
    ProcedureReturn
  EndIf
  
  ; ========================================================================
  ; Traitement des pixels
  ; ========================================================================
  For y = startPos To endPos
    For x = 2 To lg - 3
      
      If toGray
        ; ====================================================================
        ; MODE NIVEAU DE GRIS
        ; ====================================================================
        
        ; Lecture des 25 pixels du noyau 5x5 en niveaux de gris
        idx = 0
        For i = -2 To 2
          *srcPixel = *source + ((y + i) * lg + (x - 2)) * 4
          MexicanHat_ReadGray(idx) : idx + 1
          MexicanHat_ReadGray(idx) : idx + 1
          MexicanHat_ReadGray(idx) : idx + 1
          MexicanHat_ReadGray(idx) : idx + 1
          MexicanHat_ReadGray(idx) : idx + 1
        Next
        
        ; Convolution avec le noyau Mexican Hat
        result_gray = 0
        For i = 0 To 24
          result_gray + gray(i) * kernel(i)
        Next
        
        ; Application du multiplicateur
        result_gray = result_gray * mul
        
        ; Clamping et inversion
        Clamp(result_gray, 0, 255)
        If inverse : result_gray = 255 - result_gray : EndIf
        
        ; Écriture du pixel résultat (alpha = 255)
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(result_gray) * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        ; Lecture des 25 pixels du noyau 5x5 en couleur
        idx = 0
        For i = -2 To 2
          *srcPixel = *source + ((y + i) * lg + (x - 2)) * 4
          MexicanHat_ReadRGB(idx) : idx + 1
          MexicanHat_ReadRGB(idx) : idx + 1
          MexicanHat_ReadRGB(idx) : idx + 1
          MexicanHat_ReadRGB(idx) : idx + 1
          MexicanHat_ReadRGB(idx) : idx + 1
        Next
        
        ; Convolution avec le noyau Mexican Hat pour chaque canal
        result_r = 0 : result_g = 0 : result_b = 0
        For i = 0 To 24
          result_r + r3(i) * kernel(i)
          result_g + g3(i) * kernel(i)
          result_b + b3(i) * kernel(i)
        Next
        
        ; Application du multiplicateur
        result_r = result_r * mul
        result_g = result_g * mul
        result_b = result_b * mul
        
        ; Clamping et inversion
        Clamp(result_r, 0, 255)
        Clamp(result_g, 0, 255)
        Clamp(result_b, 0, 255)
        
        If inverse
          result_r = 255 - result_r
          result_g = 255 - result_g
          result_b = 255 - result_b
        EndIf
        
        ; Écriture du pixel résultat (alpha = 255)
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(result_r) << 16) | (Int(result_g) << 8) | Int(result_b))
      EndIf
      
    Next
  Next
  
  ; Libération des tableaux
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
  FreeArray(gray())
  FreeArray(kernel())
EndProcedure

Procedure MexicanHat(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Laplacian
    *param\name = "Mexican Hat (LoG)"
    *param\remarque = "Détection de contours par Laplacien de Gaussienne"
    
    ; Description des paramètres
    *param\info[0] = "Multiplicateur"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Inversion"
    *param\info[3] = "Sigma (échelle)"
    *param\info[4] = "masque"
    
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 50
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 1   : *param\info_data(3, 1) = 100 : *param\info_data(3, 2) = 30
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@MexicanHat_MT(), 4)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 184
; FirstLine = 147
; Folding = -
; EnableXP
; DPIAware