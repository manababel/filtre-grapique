; ============================================================================
; Filtre Wavelet Edge - Détection de contours par ondelettes
; ============================================================================

Macro WaveletEdge_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Procedure.f Wavelet_Haar_Horizontal(Array values(1), size)
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
  Protected.f h0 = 0.683, h1 = 1.183, h2 = -0.316, h3 = -0.183
  Protected.f result = 0
  If ArraySize(values()) >= 3
    result = Abs(values(0) * h0 + values(1) * h1 + values(2) * h2 + values(3) * h3)
  EndIf
  ProcedureReturn result
EndProcedure

Procedure.f Wavelet_Mexican_Hat(Array values(1), size)
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
  Protected result.f = 0
  Select waveletType
    Case 0 : result = Wavelet_Haar_Horizontal(values(), size)
    Case 1 : result = Wavelet_Daubechies_D4(values())
    Case 2 : result = Wavelet_Mexican_Hat(values(), size)
    Case 3 : result = Wavelet_Morlet(values(), size)
  EndSelect
  ProcedureReturn result
EndProcedure

Procedure WaveletEdge_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    
    Protected threshold.f = \option[0]
    Protected waveletType = \option[1]
    Protected toGray = \option[2]
    Protected inverse = \option[3]
    Protected decomp = \option[4]
    
    Clamp(threshold, 1, 100)
    threshold * 0.01
    
    Protected kSize
    Select decomp
      Case 0 : kSize = 3
      Case 1 : kSize = 5
      Case 2 : kSize = 7
      Default : kSize = 3
    EndSelect
    
    Protected kRadius = kSize >> 1
    Protected maxPixels = kSize * kSize
    
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
    
    Protected detailH.f, detailV.f, detailD.f
    Protected detailHR.f, detailVR.f, detailDR.f
    Protected detailHG.f, detailVG.f, detailDG.f
    Protected detailHB.f, detailVB.f, detailDB.f
    Protected edgeStrength.f, magnitude.f
    
    macro_calul_tread((ht - kSize + 1))
    
    Protected startPos = thread_start + kRadius
    Protected endPos   = thread_stop + kRadius
    
    Clamp(startPos, kRadius, ht - kRadius - 1)
    Clamp(endPos, kRadius, ht - kRadius - 1)
    
    If startPos > endPos : ProcedureReturn : EndIf
    
    For y = startPos To endPos
      For x = kRadius To lg - kRadius - 1
        idx = 0
        For j = -kRadius To kRadius
          For i = -kRadius To kRadius
            *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
            WaveletEdge_ReadPixel(idx)
            idx + 1
          Next
        Next
        
        If toGray
          For i = 0 To kSize - 1
            rowValues(i) = gray(kRadius * kSize + i)
          Next
          detailH = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
          For i = 0 To kSize - 1
            colValues(i) = gray(i * kSize + kRadius)
          Next
          detailV = Wavelet_Compute_Detail_Coefficients(colValues(), kSize, waveletType)
          For i = 0 To kSize - 1
            rowValues(i) = gray(i * kSize + i)
          Next
          detailD = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
          edgeStrength = Sqr(detailH * detailH + detailV * detailV + detailD * detailD)
          magnitude = edgeStrength * threshold * 20.0
          Clamp(magnitude, 0, 255)
          If inverse : magnitude = 255 - magnitude : EndIf
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
        Else
          ; Canal Rouge
          For i = 0 To kSize - 1 : rowValues(i) = r3(kRadius * kSize + i) : Next
          detailHR = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
          For i = 0 To kSize - 1 : colValues(i) = r3(i * kSize + kRadius) : Next
          detailVR = Wavelet_Compute_Detail_Coefficients(colValues(), kSize, waveletType)
          For i = 0 To kSize - 1 : rowValues(i) = r3(i * kSize + i) : Next
          detailDR = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
          ; Canal Vert
          For i = 0 To kSize - 1 : rowValues(i) = g3(kRadius * kSize + i) : Next
          detailHG = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
          For i = 0 To kSize - 1 : colValues(i) = g3(i * kSize + kRadius) : Next
          detailVG = Wavelet_Compute_Detail_Coefficients(colValues(), kSize, waveletType)
          For i = 0 To kSize - 1 : rowValues(i) = g3(i * kSize + i) : Next
          detailDG = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
          ; Canal Bleu
          For i = 0 To kSize - 1 : rowValues(i) = b3(kRadius * kSize + i) : Next
          detailHB = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
          For i = 0 To kSize - 1 : colValues(i) = b3(i * kSize + kRadius) : Next
          detailVB = Wavelet_Compute_Detail_Coefficients(colValues(), kSize, waveletType)
          For i = 0 To kSize - 1 : rowValues(i) = b3(i * kSize + i) : Next
          detailDB = Wavelet_Compute_Detail_Coefficients(rowValues(), kSize, waveletType)
          
          r = Sqr(detailHR * detailHR + detailVR * detailVR + detailDR * detailDR) * threshold * 20.0
          g = Sqr(detailHG * detailHG + detailVG * detailVG + detailDG * detailDG) * threshold * 20.0
          b = Sqr(detailHB * detailHB + detailVB * detailVB + detailDB * detailDB) * threshold * 20.0
          Clamp(r, 0, 255) : Clamp(g, 0, 255) : Clamp(b, 0, 255)
          If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b))
        EndIf
      Next
    Next
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3()) : FreeArray(gray())
    FreeArray(rowValues()) : FreeArray(colValues())
  EndWith
EndProcedure

Procedure WaveletEdgeEx(*FilterCtx.FilterParams)
  Restore WaveletEdge_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@WaveletEdge_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure WaveletEdge(source, cible, mask, seuil, type, nb, inverse, decomp)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = seuil
    \option[1] = type
    \option[2] = nb
    \option[3] = inverse
    \option[4] = decomp
  EndWith
  WaveletEdgeEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  WaveletEdge_data:
  Data.s "WaveletEdge"
  Data.s "Détection de contours par transformée en ondelettes"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_MultiScale
  
  Data.s "Seuil de détection"
  Data.i 1, 100, 30
  Data.s "Ondelette (0=Haar/1=Daub/2=MexHat/3=Morlet)"
  Data.i 0, 3, 0
  Data.s "Noir et blanc"
  Data.i 0, 1, 0
  Data.s "Inversion"
  Data.i 0, 1, 0
  Data.s "Décomposition (0=Niv1/1=Niv2/2=Niv3)"
  Data.i 0, 2, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 129
; FirstLine = 95
; Folding = --
; EnableXP
; DPIAware