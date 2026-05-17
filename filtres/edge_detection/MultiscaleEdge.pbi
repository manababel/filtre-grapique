; ============================================================================
; Filtre Multiscale Edge - Détection de contours multi-échelle
; ============================================================================

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
  gy = v ; Correction appliquée selon l'original (gx était répété au lieu de gy)
  ProcedureReturn Sqr(gx * gx + gy * gy)
EndProcedure

Procedure.f MultiscaleEdge_Gradient5x5(Array values(1))
  ; Gradient 5x5 avec noyau étendu
  Protected gx.f, gy.f
  Protected c = 12  ; Centre du noyau 5x5
  
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
  
  gx = (values(48) + values(41) + values(34)) - (values(0) + values(7) + values(14))
  gy = (values(42) + values(43) + values(44)) - (values(0) + values(1) + values(2))
  
  ProcedureReturn Sqr(gx * gx + gy * gy) * 0.25
EndProcedure

Procedure.f MultiscaleEdge_LaplacianOfGaussian(Array values(1), scale)
  Protected center, sum.f, mean.f, laplacian.f
  Protected i, count
  
  Select scale
    Case 0  ; 3x3
      center = 4
      count = 9
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

Procedure MultiscaleEdge_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    
    Protected sensitivity.f = \option[0]
    Protected scaleMode = \option[1]
    Protected toGray = \option[2]
    Protected inverse = \option[3]
    Protected fusion = \option[4]
    
    ; Normalisation de la sensibilité
    Clamp(sensitivity, 1, 100)
    sensitivity * 0.02
    
    Protected kRadius = 3
    Protected maxPixels = 49
    
    Protected Dim r3(maxPixels - 1)
    Protected Dim g3(maxPixels - 1)
    Protected Dim b3(maxPixels - 1)
    Protected Dim gray(maxPixels - 1)
    
    Protected *srcPixel.Long
    Protected *dstPixel.Long
    Protected r, g, b
    Protected x, y, i, j, idx
    
    Protected scale1.f, scale2.f, scale3.f
    Protected laplacian1.f, laplacian2.f, laplacian3.f
    Protected variance1.f, variance2.f, variance3.f
    Protected fusedEdge.f, magnitude.f
    
    Protected w1.f, w2.f, w3.f
    Protected totalWeight.f
    
    macro_calul_tread((ht - 6))
    
    Protected startPos = thread_start + kRadius
    Protected endPos = thread_stop + kRadius
    
    Clamp(startPos, kRadius, ht - kRadius - 1)
    Clamp(endPos, kRadius, ht - kRadius - 1)
    
    If startPos > endPos : ProcedureReturn : EndIf
    
    For y = startPos To endPos
      For x = kRadius To lg - kRadius - 1
        
        idx = 0
        For j = -kRadius To kRadius
          For i = -kRadius To kRadius
            *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
            MultiscaleEdge_ReadPixel(idx)
            idx + 1
          Next
        Next
        
        If toGray
          Select scaleMode
            Case 0
              scale1 = MultiscaleEdge_Gradient3x3(gray(), 16)
              laplacian1 = MultiscaleEdge_LaplacianOfGaussian(gray(), 0)
              scale2 = MultiscaleEdge_Gradient5x5(gray())
              laplacian2 = MultiscaleEdge_LaplacianOfGaussian(gray(), 1)
              scale3 = MultiscaleEdge_Gradient7x7(gray())
              laplacian3 = MultiscaleEdge_LaplacianOfGaussian(gray(), 2)
              variance3 = MultiscaleEdge_LocalVariance(gray(), 7)
            Case 1
              scale1 = MultiscaleEdge_Gradient3x3(gray(), 16) * 1.5
              laplacian1 = MultiscaleEdge_LaplacianOfGaussian(gray(), 0)
              scale2 = 0 : scale3 = 0 : laplacian2 = 0 : laplacian3 = 0 : variance3 = 0
            Case 2
              scale1 = 0
              scale2 = MultiscaleEdge_Gradient5x5(gray()) * 2.0
              laplacian2 = MultiscaleEdge_LaplacianOfGaussian(gray(), 1)
              scale3 = 0 : laplacian1 = 0 : laplacian3 = 0 : variance3 = 0
            Case 3
              scale1 = 0 : scale2 = 0
              scale3 = MultiscaleEdge_Gradient7x7(gray()) * 3.0
              laplacian3 = MultiscaleEdge_LaplacianOfGaussian(gray(), 2)
              variance3 = MultiscaleEdge_LocalVariance(gray(), 7)
              laplacian1 = 0 : laplacian2 = 0
          EndSelect
          
          Select fusion
            Case 0
              w1 = 0.5 : w2 = 0.3 : w3 = 0.2
              fusedEdge = (scale1 + laplacian1) * w1 + (scale2 + laplacian2) * w2 + (scale3 + laplacian3 + variance3) * w3
            Case 1
              Max(fusedEdge , (scale2 + laplacian2), (scale3 + laplacian3))
              Max(fusedEdge , (scale1 + laplacian1), fusedEdge)
            Case 2
              If scaleMode = 0
                fusedEdge = ((scale1 + laplacian1) + (scale2 + laplacian2) + (scale3 + laplacian3)) / 3.0
              Else
                fusedEdge = scale1 + scale2 + scale3 + laplacian1 + laplacian2 + laplacian3
              EndIf
            Case 3
              totalWeight = scale1 + scale2 + scale3 + 0.1
              w1 = scale1 / totalWeight : w2 = scale2 / totalWeight : w3 = scale3 / totalWeight
              fusedEdge = (scale1 + laplacian1) * w1 + (scale2 + laplacian2) * w2 + (scale3 + laplacian3) * w3
          EndSelect
          
          magnitude = fusedEdge * sensitivity * 5.0
          Clamp(magnitude, 0, 255)
          If inverse : magnitude = 255 - magnitude : EndIf
          
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
          
        Else
          Select scaleMode
            Case 0
              scale1 = MultiscaleEdge_Gradient3x3(gray(), 16)
              scale2 = MultiscaleEdge_Gradient5x5(gray())
              scale3 = MultiscaleEdge_Gradient7x7(gray())
              variance3 = MultiscaleEdge_LocalVariance(gray(), 7)
            Case 1
              scale1 = MultiscaleEdge_Gradient3x3(gray(), 16) * 1.5
              scale2 = 0 : scale3 = 0 : variance3 = 0
            Case 2
              scale1 = 0
              scale2 = MultiscaleEdge_Gradient5x5(gray()) * 2.0
              scale3 = 0 : variance3 = 0
            Case 3
              scale1 = 0 : scale2 = 0
              scale3 = MultiscaleEdge_Gradient7x7(gray()) * 3.0
              variance3 = MultiscaleEdge_LocalVariance(gray(), 7)
          EndSelect
          
          Select fusion
            Case 0 : fusedEdge = scale1 * 0.5 + scale2 * 0.3 + (scale3 + variance3) * 0.2
            Case 1 : Max(fusedEdge , scale2, scale3) : Max(fusedEdge , scale1, fusedEdge)
            Case 2
              If scaleMode = 0 : fusedEdge = (scale1 + scale2 + scale3) / 3.0 : Else : fusedEdge = scale1 + scale2 + scale3 : EndIf
            Case 3
              totalWeight = scale1 + scale2 + scale3 + 0.1
              fusedEdge = (scale1 * scale1 + scale2 * scale2 + scale3 * scale3) / totalWeight
          EndSelect
          
          magnitude = fusedEdge * sensitivity * 5.0
          r = magnitude * 1.0 : g = magnitude * 0.98 : b = magnitude * 0.96
          Clamp(r, 0, 255) : Clamp(g, 0, 255) : Clamp(b, 0, 255)
          
          If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
          
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b))
        EndIf
      Next
    Next
    
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3()) : FreeArray(gray())
  EndWith
EndProcedure

Procedure MultiscaleEdgeEx(*FilterCtx.FilterParams)
  Restore MultiscaleEdge_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@MultiscaleEdge_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure MultiscaleEdge(source, cible, mask, sensibilite, echelles, nb, inverse, fusion)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = sensibilite
    \option[1] = echelles
    \option[2] = nb
    \option[3] = inverse
    \option[4] = fusion
  EndWith
  MultiscaleEdgeEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  MultiscaleEdge_data:
  Data.s "MultiscaleEdge"
  Data.s "Détection de contours multi-échelle avec fusion intelligente"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_MultiScale
  
  Data.s "Sensibilité"
  Data.i 1, 100, 40
  Data.s "Échelles (0=All/1=Fine/2=Med/3=Coarse)"
  Data.i 0, 3, 0
  Data.s "Noir et blanc"
  Data.i 0, 1, 0
  Data.s "Inversion"
  Data.i 0, 1, 0
  Data.s "Fusion (0=Pond/1=Max/2=Moy/3=Adapt)"
  Data.i 0, 3, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 142
; FirstLine = 102
; Folding = --
; EnableXP
; DPIAware