; ============================================================================
; Filtre Beucher Gradient - Gradient morphologique de Beucher
; ============================================================================
; Variante du gradient morphologique proposée par Serge Beucher
; Utilise la moyenne des gradients internes et externes pour une meilleure
; localisation des contours
; Gradient de Beucher = (Dilatation - Image) + (Image - Érosion) / 2

Macro Beucher_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Procedure.i Beucher_Dilate(Array values(1), size)
  Protected i, maxVal = 0
  For i = 0 To size - 1
    If values(i) > maxVal : maxVal = values(i) : EndIf
  Next
  ProcedureReturn maxVal
EndProcedure

Procedure.i Beucher_Erode(Array values(1), size)
  Protected i, minVal = 255
  For i = 0 To size - 1
    If values(i) < minVal : minVal = values(i) : EndIf
  Next
  ProcedureReturn minVal
EndProcedure

Procedure Beucher_DilateRGB(Array r3(1), Array g3(1), Array b3(1), size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
  Protected i, maxR = 0, maxG = 0, maxB = 0
  For i = 0 To size - 1
    If r3(i) > maxR : maxR = r3(i) : EndIf
    If g3(i) > maxG : maxG = g3(i) : EndIf
    If b3(i) > maxB : maxB = b3(i) : EndIf
  Next
  PokeI(*rOut, maxR) : PokeI(*gOut, maxG) : PokeI(*bOut, maxB)
EndProcedure

Procedure Beucher_ErodeRGB(Array r3(1), Array g3(1), Array b3(1), size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
  Protected i, minR = 255, minG = 255, minB = 255
  For i = 0 To size - 1
    If r3(i) < minR : minR = r3(i) : EndIf
    If g3(i) < minG : minG = g3(i) : EndIf
    If b3(i) < minB : minB = b3(i) : EndIf
  Next
  PokeI(*rOut, minR) : PokeI(*gOut, minG) : PokeI(*bOut, minB)
EndProcedure

Procedure Beucher_CreateStructuringElement(Array element(1), shape, size)
  Protected x, y, idx, center, radius.f, dist.f, distManhattan
  center = size >> 1 : radius = center : idx = 0
  For y = 0 To size - 1
    For x = 0 To size - 1
      Select shape
        Case 0 : element(idx) = 1 ; Carré
        Case 1 : If x = center Or y = center : element(idx) = 1 : Else : element(idx) = 0 : EndIf ; Croix
        Case 2 : dist = Sqr((x - center) * (x - center) + (y - center) * (y - center))
                 If dist <= radius : element(idx) = 1 : Else : element(idx) = 0 : EndIf ; Disque
        Case 3 : distManhattan = Abs(x - center) + Abs(y - center)
                 If distManhattan <= center : element(idx) = 1 : Else : element(idx) = 0 : EndIf ; Diamant
        Case 4 : dist = Sqr((x - center) * (x - center) + (y - center) * (y - center))
                 distManhattan = Abs(x - center) + Abs(y - center)
                 If dist <= radius Or distManhattan <= center : element(idx) = 1 : Else : element(idx) = 0 : EndIf ; Octogone
      EndSelect
      idx + 1
    Next
  Next
EndProcedure

Procedure BeucherGradient_MT(*FilterCtx.FilterParams)
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
    Protected Dim structElement(maxPixels - 1)
    
    Beucher_CreateStructuringElement(structElement(), shape, kSize)
    
    Protected *srcPixel.Long, *dstPixel.Long
    Protected r, g, b, x, y, i, j, idx
    Protected original, dilated, eroded, beucherGrad, magnitude.f
    Protected originalR, originalG, originalB, dilatedR, dilatedG, dilatedB, erodedR, erodedG, erodedB
    Protected beucherR, beucherG, beucherB
    
    macro_calul_tread((ht - kSize + 1))
    
    For y = thread_start + kRadius To thread_stop + kRadius - 1
      For x = kRadius To lg - kRadius - 1
        idx = 0
        For j = -kRadius To kRadius
          For i = -kRadius To kRadius
            *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
            Beucher_ReadPixel(idx)
            idx + 1
          Next
        Next
        
        If toGray
          original = gray((maxPixels >> 1))
          dilated = Beucher_Dilate(gray(), maxPixels)
          eroded = Beucher_Erode(gray(), maxPixels)
          beucherGrad = ((dilated - original) + (original - eroded)) >> 1
          magnitude = beucherGrad * strength * 10.0
          Clamp(magnitude, 0, 255)
          If inverse : magnitude = 255 - magnitude : EndIf
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
        Else
          originalR = r3((maxPixels >> 1)) : originalG = g3((maxPixels >> 1)) : originalB = b3((maxPixels >> 1))
          Beucher_DilateRGB(r3(), g3(), b3(), maxPixels, @dilatedR, @dilatedG, @dilatedB)
          Beucher_ErodeRGB(r3(), g3(), b3(), maxPixels, @erodedR, @erodedG, @erodedB)
          beucherR = ((dilatedR - originalR) + (originalR - erodedR)) >> 1
          beucherG = ((dilatedG - originalG) + (originalG - erodedG)) >> 1
          beucherB = ((dilatedB - originalB) + (originalB - erodedB)) >> 1
          r = beucherR * strength * 10.0 : g = beucherG * strength * 10.0 : b = beucherB * strength * 10.0
          Clamp(r, 0, 255) : Clamp(g, 0, 255) : Clamp(b, 0, 255)
          If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (r << 16) | (g << 8) | b)
        EndIf
      Next
    Next
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3()) : FreeArray(gray()) : FreeArray(structElement())
  EndWith
EndProcedure

Procedure BeucherGradientEx(*FilterCtx.FilterParams)
  Restore BeucherGradient_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  With *FilterCtx
    Create_MultiThread_MT(@BeucherGradient_MT())
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure BeucherGradient(source, cible, mask, force, noyau, gris, inversion, forme)
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
  BeucherGradientEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  BeucherGradient_data:
  Data.s "Beucher Gradient"
  Data.s "Gradient de Beucher : moyenne gradients interne/externe"
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
  Data.s "Forme (0=Sq/1=Cr/2=Di/3=Dm/4=Oc)" 
  Data.i 0, 4, 2
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 165
; FirstLine = 146
; Folding = --
; EnableXP
; DPIAware