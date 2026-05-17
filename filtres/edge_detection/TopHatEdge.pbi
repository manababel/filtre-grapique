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
  Protected i, maxVal = 0
  For i = 0 To size - 1
    If values(i) > maxVal : maxVal = values(i) : EndIf
  Next
  ProcedureReturn maxVal
EndProcedure

Procedure.i TopHat_Erode(Array values(1), size)
  Protected i, minVal = 255
  For i = 0 To size - 1
    If values(i) < minVal : minVal = values(i) : EndIf
  Next
  ProcedureReturn minVal
EndProcedure

Procedure TopHat_DilateRGB(Array r3(1), Array g3(1), Array b3(1), size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
  Protected i, maxR = 0, maxG = 0, maxB = 0
  For i = 0 To size - 1
    If r3(i) > maxR : maxR = r3(i) : EndIf
    If g3(i) > maxG : maxG = g3(i) : EndIf
    If b3(i) > maxB : maxB = b3(i) : EndIf
  Next
  PokeI(*rOut, maxR) : PokeI(*gOut, maxG) : PokeI(*bOut, maxB)
EndProcedure

Procedure TopHat_ErodeRGB(Array r3(1), Array g3(1), Array b3(1), size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
  Protected i, minR = 255, minG = 255, minB = 255
  For i = 0 To size - 1
    If r3(i) < minR : minR = r3(i) : EndIf
    If g3(i) < minG : minG = g3(i) : EndIf
    If b3(i) < minB : minB = b3(i) : EndIf
  Next
  PokeI(*rOut, minR) : PokeI(*gOut, minG) : PokeI(*bOut, minB)
EndProcedure

Procedure TopHat_CreateStructuringElement(Array element(1), shape, size)
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
        Case 4 : If y = center : element(idx) = 1 : Else : element(idx) = 0 : EndIf ; Ligne H
        Case 5 : If x = center : element(idx) = 1 : Else : element(idx) = 0 : EndIf ; Ligne V
      EndSelect
      idx + 1
    Next
  Next
EndProcedure

Procedure TopHatEdge_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    
    Protected strength.f = \option[0]    ; Force (1-100)
    Protected kernelSize = \option[1]    ; Taille noyau (0=3x3, 1=5x5, 2=7x7)
    Protected toGray = \option[2]
    Protected inverse = \option[3]
    Protected mode = \option[4]         ; 0=Both, 1=White, 2=Black, 3=Max
    
    Clamp(strength, 1, 100) : strength * 0.015
    
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
    
    TopHat_CreateStructuringElement(structElement(), 2, kSize)
    
    Protected *srcPixel.Long, *dstPixel.Long
    Protected r, g, b, x, y, i, j, idx
    Protected original, eroded, dilated, opening, closing, whiteTH, blackTH, edge, magnitude.f
    Protected originalR, originalG, originalB, erodedR, erodedG, erodedB, dilatedR, dilatedG, dilatedB
    Protected openingR, openingG, openingB, closingR, closingG, closingB
    Protected whiteR, whiteG, whiteB, blackR, blackG, blackB, edgeR, edgeG, edgeB
    
    macro_calul_tread((ht - kSize + 1))
    
    For y = thread_start + kRadius To thread_stop + kRadius - 1
      For x = kRadius To lg - kRadius - 1
        idx = 0
        For j = -kRadius To kRadius
          For i = -kRadius To kRadius
            *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
            TopHat_ReadPixel(idx)
            idx + 1
          Next
        Next
        
        If toGray
          original = gray((maxPixels >> 1))
          eroded = TopHat_Erode(gray(), maxPixels) : opening = eroded
          dilated = TopHat_Dilate(gray(), maxPixels) : closing = dilated
          
          whiteTH = original - opening : If whiteTH < 0 : whiteTH = 0 : EndIf
          blackTH = closing - original : If blackTH < 0 : blackTH = 0 : EndIf
          
          Select mode
            Case 0 : edge = whiteTH + blackTH
            Case 1 : edge = whiteTH
            Case 2 : edge = blackTH
            Case 3 : If whiteTH > blackTH : edge = whiteTH : Else : edge = blackTH : EndIf
          EndSelect
          
          magnitude = edge * strength * 10.0
          Clamp(magnitude, 0, 255)
          If inverse : magnitude = 255 - magnitude : EndIf
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
        Else
          originalR = r3((maxPixels >> 1)) : originalG = g3((maxPixels >> 1)) : originalB = b3((maxPixels >> 1))
          TopHat_ErodeRGB(r3(), g3(), b3(), maxPixels, @erodedR, @erodedG, @erodedB)
          openingR = erodedR : openingG = erodedG : openingB = erodedB
          TopHat_DilateRGB(r3(), g3(), b3(), maxPixels, @dilatedR, @dilatedG, @dilatedB)
          closingR = dilatedR : closingG = dilatedG : closingB = dilatedB
          
          whiteR = originalR - openingR : If whiteR < 0 : whiteR = 0 : EndIf
          whiteG = originalG - openingG : If whiteG < 0 : whiteG = 0 : EndIf
          whiteB = originalB - openingB : If whiteB < 0 : whiteB = 0 : EndIf
          
          blackR = closingR - originalR : If blackR < 0 : blackR = 0 : EndIf
          blackG = closingG - originalG : If blackG < 0 : blackG = 0 : EndIf
          blackB = closingB - originalB : If blackB < 0 : blackB = 0 : EndIf
          
          Select mode
            Case 0 : edgeR = whiteR + blackR : edgeG = whiteG + blackG : edgeB = whiteB + blackB
            Case 1 : edgeR = whiteR : edgeG = whiteG : edgeB = whiteB
            Case 2 : edgeR = blackR : edgeG = blackG : edgeB = blackB
            Case 3 : If whiteR > blackR : edgeR = whiteR : Else : edgeR = blackR : EndIf
                     If whiteG > blackG : edgeG = whiteG : Else : edgeG = blackG : EndIf
                     If whiteB > blackB : edgeB = whiteB : Else : edgeB = blackB : EndIf
          EndSelect
          
          r = edgeR * strength * 10.0 : g = edgeG * strength * 10.0 : b = edgeB * strength * 10.0
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

Procedure TopHatEdgeEx(*FilterCtx.FilterParams)
  Restore TopHatEdge_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  With *FilterCtx
    Create_MultiThread_MT(@TopHatEdge_MT())
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure TopHatEdge(source, cible, mask, force, noyau, gris, inversion, mode)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = force
    \option[1] = noyau
    \option[2] = gris
    \option[3] = inversion
    \option[4] = mode
  EndWith
  TopHatEdgeEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  TopHatEdge_data:
  Data.s "Top-Hat Edge"
  Data.s "Détection de contours par transformations Top-Hat (White + Black)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Morphological
  
  Data.s "Force"       
  Data.i 1, 100, 50
  Data.s "Taille noyau (0=3x3/1=5x5/2=7x7)"   
  Data.i 0, 2, 0
  Data.s "Noir et blanc"        
  Data.i 0, 1, 0
  Data.s "Inversion"  
  Data.i 0, 1, 0
  Data.s "Mode (0=Both/1=White/2=Black/3=Max)" 
  Data.i 0, 3, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 192
; FirstLine = 173
; Folding = --
; EnableXP
; DPIAware