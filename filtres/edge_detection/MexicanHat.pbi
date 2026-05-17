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

Procedure MexicanHat_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    
    Protected mul.f = \option[0]
    Protected toGray = \option[1]
    Protected inverse = \option[2]
    Protected sigma.f = \option[3]
    
    ; Normalisation du multiplicateur (0-100 -> 0-2)
    clamp(mul, 1, 100)
    mul = mul * 0.02
    
    ; Normalisation du sigma (1-100 -> 0.5-3.0)
    clamp(sigma, 1, 100)
    sigma = 0.5 + (sigma - 1) * 0.025
    
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
    
    ; Génération du noyau LoG
    For y = -2 To 2
      For x = -2 To 2
        Protected dist2.f = x * x + y * y
        Protected gauss.f = Exp(-dist2 / (2 * sigma2))
        kernel(idx) = (-1.0 / (#PI * sigma4)) * (1.0 - dist2 / (2 * sigma2)) * gauss
        kernel_sum + Abs(kernel(idx))
        idx + 1
      Next
    Next
    
    If kernel_sum > 0
      For i = 0 To 24
        kernel(i) = kernel(i) / kernel_sum * 10.0
      Next
    EndIf
    
    ; Calcul des limites de traitement
    macro_calul_tread((ht - 4))
    Protected startPos = thread_start + 2
    Protected endPos   = thread_stop + 1
    
    clamp(startPos, 2, ht - 3)
    clamp(endPos, 2, ht - 3)
    
    If startPos > endPos : ProcedureReturn : EndIf
    
    For y = startPos To endPos
      For x = 2 To lg - 3
        
        If toGray
          idx = 0
          For i = -2 To 2
            *srcPixel = *source + ((y + i) * lg + (x - 2)) * 4
            MexicanHat_ReadGray(idx) : idx + 1
            MexicanHat_ReadGray(idx) : idx + 1
            MexicanHat_ReadGray(idx) : idx + 1
            MexicanHat_ReadGray(idx) : idx + 1
            MexicanHat_ReadGray(idx) : idx + 1
          Next
          
          result_gray = 0
          For i = 0 To 24
            result_gray + gray(i) * kernel(i)
          Next
          
          result_gray * mul
          clamp(result_gray, 0, 255)
          If inverse : result_gray = 255 - result_gray : EndIf
          
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(result_gray) * $010101))
          
        Else
          idx = 0
          For i = -2 To 2
            *srcPixel = *source + ((y + i) * lg + (x - 2)) * 4
            MexicanHat_ReadRGB(idx) : idx + 1
            MexicanHat_ReadRGB(idx) : idx + 1
            MexicanHat_ReadRGB(idx) : idx + 1
            MexicanHat_ReadRGB(idx) : idx + 1
            MexicanHat_ReadRGB(idx) : idx + 1
          Next
          
          result_r = 0 : result_g = 0 : result_b = 0
          For i = 0 To 24
            result_r + r3(i) * kernel(i)
            result_g + g3(i) * kernel(i)
            result_b + b3(i) * kernel(i)
          Next
          
          result_r * mul : result_g * mul : result_b * mul
          clamp_rgb(result_r, result_g, result_b)
          
          If inverse
            result_r = 255 - result_r
            result_g = 255 - result_g
            result_b = 255 - result_b
          EndIf
          
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(result_r) << 16) | (Int(result_g) << 8) | Int(result_b))
        EndIf
      Next
    Next
    
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3())
    FreeArray(gray()) : FreeArray(kernel())
  EndWith
EndProcedure

Procedure MexicanHatEx(*FilterCtx.FilterParams)
  Restore MexicanHat_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@MexicanHat_MT())
  
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure MexicanHat(source, cible, mask, multiplicateur, noir_et_blanc, inversion, sigma)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiplicateur
    \option[1] = noir_et_blanc
    \option[2] = inversion
    \option[3] = sigma
  EndWith
  MexicanHatEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  MexicanHat_data:
  Data.s "Mexican Hat (LoG)"
  Data.s "Détection de contours par Laplacien de Gaussienne"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Laplacian
  
  Data.s "Multiplicateur"
  Data.i 1, 100, 50
  Data.s "Noir et blanc"
  Data.i 0, 1, 0
  Data.s "Inversion"
  Data.i 0, 1, 0
  Data.s "Sigma (échelle)"
  Data.i 1, 100, 30
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 154
; FirstLine = 132
; Folding = -
; EnableXP
; DPIAware