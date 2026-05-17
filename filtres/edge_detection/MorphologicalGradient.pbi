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
    If values(i) > maxVal : maxVal = values(i) : EndIf
  Next
  ProcedureReturn maxVal
EndProcedure

Procedure.i MorphGrad_Erode(Array values(1), size)
  ; Érosion : minimum local (contraction des zones claires)
  Protected i, minVal = 255
  For i = 0 To size - 1
    If values(i) < minVal : minVal = values(i) : EndIf
  Next
  ProcedureReturn minVal
EndProcedure

Procedure MorphGrad_DilateRGB(Array r3(1), Array g3(1), Array b3(1), size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
  Protected i, maxR = 0, maxG = 0, maxB = 0
  For i = 0 To size - 1
    If r3(i) > maxR : maxR = r3(i) : EndIf
    If g3(i) > maxG : maxG = g3(i) : EndIf
    If b3(i) > maxB : maxB = b3(i) : EndIf
  Next
  PokeI(*rOut, maxR) : PokeI(*gOut, maxG) : PokeI(*bOut, maxB)
EndProcedure

Procedure MorphGrad_ErodeRGB(Array r3(1), Array g3(1), Array b3(1), size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
  Protected i, minR = 255, minG = 255, minB = 255
  For i = 0 To size - 1
    If r3(i) < minR : minR = r3(i) : EndIf
    If g3(i) < minG : minG = g3(i) : EndIf
    If b3(i) < minB : minB = b3(i) : EndIf
  Next
  PokeI(*rOut, minR) : PokeI(*gOut, minG) : PokeI(*bOut, minB)
EndProcedure

Procedure MorphGrad_CreateStructuringElement(Array element(1), shape, size)
  Protected x, y, idx, center, radius.f, dist.f
  center = size >> 1 : radius = center : idx = 0
  For y = 0 To size - 1
    For x = 0 To size - 1
      Select shape
        Case 0 : element(idx) = 1 ; Carré
        Case 1 : If x = center Or y = center : element(idx) = 1 : Else : element(idx) = 0 : EndIf ; Croix
        Case 2 : dist = Sqr((x - center) * (x - center) + (y - center) * (y - center))
                 If dist <= radius : element(idx) = 1 : Else : element(idx) = 0 : EndIf ; Disque
        Case 3 : dist = Abs(x - center) + Abs(y - center)
                 If dist <= center : element(idx) = 1 : Else : element(idx) = 0 : EndIf ; Diamant
      EndSelect
      idx + 1
    Next
  Next
EndProcedure

Procedure MorphologicalGradient_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    
    Protected strength.f = \option[0]    ; Force du gradient (1-100)
    Protected kernelSize = \option[1]    ; Taille noyau (0=3x3, 1=5x5, 2=7x7)
    Protected toGray = \option[2]
    Protected inverse = \option[3]
    Protected shape = \option[4]         ; Forme élément structurant
    
    Clamp(strength, 1, 100) : strength * 0.01
    
    Protected kSize
    Select kernelSize
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
    Protected Dim grayFiltered(maxPixels - 1)
    Protected Dim structElement(maxPixels - 1)
    
    MorphGrad_CreateStructuringElement(structElement(), shape, kSize)
    
    Protected *srcPixel.Long, *dstPixel.Long
    Protected r, g, b, x, y, i, j, idx, filtIdx
    Protected dilated, eroded, gradient, magnitude.f
    Protected dilatedR, dilatedG, dilatedB, erodedR, erodedG, erodedB, gradR, gradG, gradB
    
    macro_calul_tread((ht - kSize + 1))
    
    For y = thread_start + kRadius To thread_stop + kRadius - 1
      For x = kRadius To lg - kRadius - 1
        idx = 0
        For j = -kRadius To kRadius
          For i = -kRadius To kRadius
            *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
            MorphGrad_ReadPixel(idx)
            idx + 1
          Next
        Next
        
        If toGray
          filtIdx = 0
          For idx = 0 To maxPixels - 1
            If structElement(idx) = 1
              grayFiltered(filtIdx) = gray(idx)
              filtIdx + 1
            EndIf
          Next
          dilated = MorphGrad_Dilate(grayFiltered(), filtIdx)
          eroded = MorphGrad_Erode(grayFiltered(), filtIdx)
          gradient = dilated - eroded
          magnitude = gradient * strength * 10.0
          Clamp(magnitude, 0, 255)
          If inverse : magnitude = 255 - magnitude : EndIf
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
        Else
          MorphGrad_DilateRGB(r3(), g3(), b3(), maxPixels, @dilatedR, @dilatedG, @dilatedB)
          MorphGrad_ErodeRGB(r3(), g3(), b3(), maxPixels, @erodedR, @erodedG, @erodedB)
          gradR = dilatedR - erodedR : gradG = dilatedG - erodedG : gradB = dilatedB - erodedB
          r = gradR * strength * 10.0 : g = gradG * strength * 10.0 : b = gradB * strength * 10.0
          Clamp(r, 0, 255) : Clamp(g, 0, 255) : Clamp(b, 0, 255)
          If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (r << 16) | (g << 8) | b)
        EndIf
      Next
    Next
    
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3())
    FreeArray(gray()) : FreeArray(grayFiltered()) : FreeArray(structElement())
  EndWith
EndProcedure

Procedure MorphologicalGradientEx(*FilterCtx.FilterParams)
  Restore MorphologicalGradient_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  With *FilterCtx
    Create_MultiThread_MT(@MorphologicalGradient_MT())
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure MorphologicalGradient(source, cible, mask, force, noyau, gris, inversion, forme)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = force
    \option[1] = noyau
    \option[2] = gris
    \option[3] = inversion
    \option[4] = forme
  EndWith
  MorphologicalGradientEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  MorphologicalGradient_data:
  Data.s "Morphological Gradient"
  Data.s "Gradient morphologique (Dilatation - Érosion)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Morphological
  
  Data.s "Force du gradient"       
  Data.i 1, 100, 50
  Data.s "Taille noyau (0=3x3/1=5x5/2=7x7)"   
  Data.i 0, 2, 0
  Data.s "Noir et blanc"        
  Data.i 0, 1, 0
  Data.s "Inversion"  
  Data.i 0, 1, 0
  Data.s "Forme (0=Sq/1=Cr/2=Di/3=Dm)" 
  Data.i 0, 3, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 169
; FirstLine = 150
; Folding = --
; EnableXP
; DPIAware