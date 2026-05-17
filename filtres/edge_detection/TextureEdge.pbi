; ============================================================================
; Filtre Texture Edge - Détection de contours par analyse de texture
; ============================================================================

Macro TextureEdge_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Procedure.f TextureEdge_Variance(Array values(1), size)
  Protected i, sum.f = 0, sumSq.f = 0, mean.f
  For i = 0 To size - 1
    sum + values(i)
    sumSq + values(i) * values(i)
  Next
  mean = sum / size
  ProcedureReturn (sumSq / size) - (mean * mean)
EndProcedure

Procedure.f TextureEdge_Entropy(Array values(1), size)
  Protected Dim tab_histogram(255)
  Protected i, total = 0
  Protected.f entropy = 0, prob
  For i = 0 To size - 1
    tab_histogram(values(i)) + 1
    total + 1
  Next
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
  Protected i, minVal = 255, maxVal = 0
  For i = 0 To size - 1
    If values(i) < minVal : minVal = values(i) : EndIf
    If values(i) > maxVal : maxVal = values(i) : EndIf
  Next
  ProcedureReturn (maxVal - minVal)
EndProcedure

Procedure.f TextureEdge_Energy(Array values(1), size)
  Protected i, sum.f = 0
  For i = 0 To size - 1
    sum + values(i) * values(i)
  Next
  ProcedureReturn sum / size
EndProcedure

Procedure.f TextureEdge_Homogeneity(Array values(1), size)
  Protected i, center = size >> 1
  Protected.f sum = 0, diff
  For i = 0 To size - 1
    diff = Abs(values(i) - values(center))
    sum + 1.0 / (1.0 + diff)
  Next
  ProcedureReturn sum / size
EndProcedure

Procedure.f TextureEdge_LBP(Array values(1))
  Protected center = values(4)
  Protected.f pattern = 0
  Protected i
  Protected Dim neighbors(7)
  neighbors(0) = values(0) : neighbors(1) = values(1) : neighbors(2) = values(2)
  neighbors(3) = values(3) : neighbors(4) = values(5) : neighbors(5) = values(6)
  neighbors(6) = values(7) : neighbors(7) = values(8)
  For i = 0 To 7
    If neighbors(i) >= center : pattern + Pow(2, i) : EndIf
  Next
  FreeArray(neighbors())
  ProcedureReturn pattern
EndProcedure

Procedure.f TextureEdge_GLCM_Contrast(Array values(1), size)
  Protected i
  Protected.f contrast = 0, diff
  For i = 0 To size - 2
    diff = Abs(values(i) - values(i + 1))
    contrast + diff * diff
  Next
  ProcedureReturn contrast / (size - 1)
EndProcedure

Procedure.f TextureEdge_Laws_Energy(Array values(1), size)
  Protected.f E5, S5
  Protected center = size >> 1
  If size >= 5
    E5 = -values(center-2) - 2*values(center-1) + 2*values(center+1) + values(center+2)
    S5 = -values(center-2) + 2*values(center) - values(center+2)
    ProcedureReturn Sqr(E5*E5 + S5*S5)
  Else
    ProcedureReturn 0
  EndIf
EndProcedure

Procedure TextureEdge_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    
    Protected sensitivity.f = \option[0]
    Protected descriptor = \option[1]
    Protected toGray = \option[2]
    Protected inverse = \option[3]
    Protected windowSize = \option[4]
    
    Clamp(sensitivity, 1, 100)
    sensitivity * 0.02
    
    Protected kSize
    Select windowSize
      Case 0 : kSize = 3
      Case 1 : kSize = 5
      Case 2 : kSize = 7
      Default : kSize = 5
    EndSelect
    
    Protected kRadius = kSize >> 1
    Protected maxPixels = kSize * kSize
    Protected quadrantSize = Pow((kRadius + 1), 2)
    
    Protected Dim r3(maxPixels - 1), Dim g3(maxPixels - 1), Dim b3(maxPixels - 1), Dim gray(maxPixels - 1)
    Protected Dim textureNW(quadrantSize - 1), Dim textureNE(quadrantSize - 1)
    Protected Dim textureSW(quadrantSize - 1), Dim textureSE(quadrantSize - 1)
    
    Protected *srcPixel.Long, *dstPixel.Long
    Protected r, g, b, x, y, i, j, idx, subIdx, halfSize = kRadius
    Protected.f descNW, descNE, descSW, descSE, descCenter
    Protected.f diffH, diffV, diffD1, diffD2, textureGradient, edgeStrength
    
    macro_calul_tread((ht - kSize))
    
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
            TextureEdge_ReadPixel(idx)
            idx + 1
          Next
        Next
        
        If toGray
          If kSize >= 5
            subIdx = 0
            For j = 0 To halfSize
              For i = 0 To halfSize
                textureNW(subIdx) = gray(j * kSize + i)
                textureNE(subIdx) = gray(j * kSize + (i + halfSize))
                textureSW(subIdx) = gray((j + halfSize) * kSize + i)
                textureSE(subIdx) = gray((j + halfSize) * kSize + (i + halfSize))
                subIdx + 1
              Next
            Next
            
            Select descriptor
              Case 0 : descNW = TextureEdge_Variance(textureNW(), quadrantSize) : descNE = TextureEdge_Variance(textureNE(), quadrantSize) : descSW = TextureEdge_Variance(textureSW(), quadrantSize) : descSE = TextureEdge_Variance(textureSE(), quadrantSize)
              Case 1 : descNW = TextureEdge_Entropy(textureNW(), quadrantSize) : descNE = TextureEdge_Entropy(textureNE(), quadrantSize) : descSW = TextureEdge_Entropy(textureSW(), quadrantSize) : descSE = TextureEdge_Entropy(textureSE(), quadrantSize)
              Case 2 : descNW = TextureEdge_Contrast(textureNW(), quadrantSize) : descNE = TextureEdge_Contrast(textureNE(), quadrantSize) : descSW = TextureEdge_Contrast(textureSW(), quadrantSize) : descSE = TextureEdge_Contrast(textureSE(), quadrantSize)
              Case 3 : descNW = TextureEdge_Energy(textureNW(), quadrantSize) : descNE = TextureEdge_Energy(textureNE(), quadrantSize) : descSW = TextureEdge_Energy(textureSW(), quadrantSize) : descSE = TextureEdge_Energy(textureSE(), quadrantSize)
              Case 4 : descNW = TextureEdge_Homogeneity(textureNW(), quadrantSize) : descNE = TextureEdge_Homogeneity(textureNE(), quadrantSize) : descSW = TextureEdge_Homogeneity(textureSW(), quadrantSize) : descSE = TextureEdge_Homogeneity(textureSE(), quadrantSize)
              Case 5 : descNW = TextureEdge_Variance(textureNW(), quadrantSize) : descNE = TextureEdge_Variance(textureNE(), quadrantSize) : descSW = TextureEdge_Variance(textureSW(), quadrantSize) : descSE = TextureEdge_Variance(textureSE(), quadrantSize)
              Case 6 : descNW = TextureEdge_GLCM_Contrast(textureNW(), quadrantSize) : descNE = TextureEdge_GLCM_Contrast(textureNE(), quadrantSize) : descSW = TextureEdge_GLCM_Contrast(textureSW(), quadrantSize) : descSE = TextureEdge_GLCM_Contrast(textureSE(), quadrantSize)
              Case 7 : descNW = TextureEdge_Laws_Energy(textureNW(), quadrantSize) : descNE = TextureEdge_Laws_Energy(textureNE(), quadrantSize) : descSW = TextureEdge_Laws_Energy(textureSW(), quadrantSize) : descSE = TextureEdge_Laws_Energy(textureSE(), quadrantSize)
            EndSelect
            diffH = Abs(descNW - descNE) + Abs(descSW - descSE)
            diffV = Abs(descNW - descSW) + Abs(descNE - descSE)
            diffD1 = Abs(descNW - descSE) : diffD2 = Abs(descNE - descSW)
          Else
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
            diffH = descCenter * 0.5 : diffV = descCenter * 0.5 : diffD1 = descCenter * 0.3 : diffD2 = descCenter * 0.3
          EndIf
          textureGradient = Sqr(diffH * diffH + diffV * diffV + diffD1 * diffD1 + diffD2 * diffD2)
          edgeStrength = textureGradient * sensitivity * 15.0
          Clamp(edgeStrength, 0, 255)
          If inverse : edgeStrength = 255 - edgeStrength : EndIf
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(edgeStrength) * $010101))
        Else
          Protected.f descR, descG, descB
          Select descriptor
            Case 0 : descR = TextureEdge_Variance(r3(), maxPixels) : descG = TextureEdge_Variance(g3(), maxPixels) : descB = TextureEdge_Variance(b3(), maxPixels)
            Case 1 : descR = TextureEdge_Entropy(r3(), maxPixels) : descG = TextureEdge_Entropy(g3(), maxPixels) : descB = TextureEdge_Entropy(b3(), maxPixels)
            Case 2 : descR = TextureEdge_Contrast(r3(), maxPixels) : descG = TextureEdge_Contrast(g3(), maxPixels) : descB = TextureEdge_Contrast(b3(), maxPixels)
            Case 3 : descR = TextureEdge_Energy(r3(), maxPixels) : descG = TextureEdge_Energy(g3(), maxPixels) : descB = TextureEdge_Energy(b3(), maxPixels)
            Case 4 : descR = TextureEdge_Homogeneity(r3(), maxPixels) : descG = TextureEdge_Homogeneity(g3(), maxPixels) : descB = TextureEdge_Homogeneity(b3(), maxPixels)
            Case 6 : descR = TextureEdge_GLCM_Contrast(r3(), maxPixels) : descG = TextureEdge_GLCM_Contrast(g3(), maxPixels) : descB = TextureEdge_GLCM_Contrast(b3(), maxPixels)
            Case 7 : descR = TextureEdge_Laws_Energy(r3(), maxPixels) : descG = TextureEdge_Laws_Energy(g3(), maxPixels) : descB = TextureEdge_Laws_Energy(b3(), maxPixels)
            Default : descR = TextureEdge_Variance(gray(), maxPixels) : descG = descR : descB = descR
          EndSelect
          r = descR * sensitivity * 15.0 : g = descG * sensitivity * 15.0 : b = descB * sensitivity * 15.0
          Clamp(r, 0, 255) : Clamp(g, 0, 255) : Clamp(b, 0, 255)
          If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b))
        EndIf
      Next
    Next
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3()) : FreeArray(gray())
    FreeArray(textureNW()) : FreeArray(textureNE()) : FreeArray(textureSW()) : FreeArray(textureSE())
  EndWith
EndProcedure

Procedure TextureEdgeEx(*FilterCtx.FilterParams)
  Restore TextureEdge_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@TextureEdge_MT())
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure TextureEdge(source, cible, mask, sensibilite, descripteur, nb, inverse, fenetre)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = sensibilite : \option[1] = descripteur : \option[2] = nb : \option[3] = inverse : \option[4] = fenetre
  EndWith
  TextureEdgeEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  TextureEdge_data:
  Data.s "Texture Edge"
  Data.s "Détection de contours par analyse de variations de textures locales"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Specialized
  
  Data.s "Sensibilité"
  Data.i 1, 100, 40
  Data.s "Descripteur (0=Var/1=Ent/2=Cont/3=Ener/4=Homo/5=LBP/6=GLCM/7=Laws)"
  Data.i 0, 7, 0
  Data.s "Noir et blanc"
  Data.i 0, 1, 0
  Data.s "Inversion"
  Data.i 0, 1, 0
  Data.s "Fenêtre (0=3x3/1=5x5/2=7x7)"
  Data.i 0, 2, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 132
; FirstLine = 128
; Folding = ---
; EnableXP
; DPIAware