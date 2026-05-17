; ============================================================================
; Filtre Color Edge Detection - Détection de contours couleur
; ============================================================================

Macro ColorEdge_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  *srcPixel + 4
EndMacro

Procedure ColorEdge_RGB_To_HSV(r, g, b, *h.Float, *s.Float, *v.Float)
  Protected.f rNorm = r / 255.0, gNorm = g / 255.0, bNorm = b / 255.0
  Protected.f cMax, cMin, delta
  Max(cMax , gNorm, bNorm) : Max(cMax , rNorm, cMax)
  Min(cMin , gNorm, bNorm) : Min(cMin , rNorm, cMin)
  delta = cMax - cMin
  *v\f = cMax
  If cMax > 0 : *s\f = delta / cMax : Else : *s\f = 0 : EndIf
  If delta > 0
    If cMax = rNorm : *h\f = 60.0 * Mod(((gNorm - bNorm) / delta) , 6)
    ElseIf cMax = gNorm : *h\f = 60.0 * (((bNorm - rNorm) / delta) + 2.0)
    Else : *h\f = 60.0 * (((rNorm - gNorm) / delta) + 4.0)
    EndIf
    If *h\f < 0 : *h\f + 360.0 : EndIf
  Else : *h\f = 0 : EndIf
EndProcedure

Procedure ColorEdge_RGB_To_Lab(r, g, b, *L.Float, *a.Float, *b2.Float)
  Protected.f rNorm = r / 255.0, gNorm = g / 255.0, bNorm = b / 255.0
  If rNorm > 0.04045 : rNorm = Pow((rNorm + 0.055) / 1.055, 2.4) : Else : rNorm / 12.92 : EndIf
  If gNorm > 0.04045 : gNorm = Pow((gNorm + 0.055) / 1.055, 2.4) : Else : gNorm / 12.92 : EndIf
  If bNorm > 0.04045 : bNorm = Pow((bNorm + 0.055) / 1.055, 2.4) : Else : bNorm / 12.92 : EndIf
  Protected.f x = (rNorm * 0.4124 + gNorm * 0.3576 + bNorm * 0.1805) * 100.0
  Protected.f y = (rNorm * 0.2126 + gNorm * 0.7152 + bNorm * 0.0722) * 100.0
  Protected.f z = (rNorm * 0.0193 + gNorm * 0.1192 + bNorm * 0.9505) * 100.0
  x / 95.047 : y / 100.0 : z / 108.883
  If x > 0.008856 : x = Pow(x, 1.0/3.0) : Else : x = (7.787 * x) + (16.0/116.0) : EndIf
  If y > 0.008856 : y = Pow(y, 1.0/3.0) : Else : y = (7.787 * y) + (16.0/116.0) : EndIf
  If z > 0.008856 : z = Pow(z, 1.0/3.0) : Else : z = (7.787 * z) + (16.0/116.0) : EndIf
  *L\f = (116.0 * y) - 16.0 : *a\f = 500.0 * (x - y) : *b2\f = 200.0 * (y - z)
EndProcedure

Procedure.f ColorEdge_Euclidean_Distance_RGB(r1, g1, b1, r2, g2, b2)
  Protected dr = r2 - r1, dg = g2 - g1, db = b2 - b1
  ProcedureReturn Sqr(dr * dr + dg * dg + db * db)
EndProcedure

Procedure.f ColorEdge_Euclidean_Distance_HSV(h1.f, s1.f, v1.f, h2.f, s2.f, v2.f)
  Protected.f dh = Abs(h2 - h1)
  If dh > 180.0 : dh = 360.0 - dh : EndIf
  dh / 180.0
  Protected.f ds = s2 - s1, dv = v2 - v1
  ProcedureReturn Sqr(dh * dh + ds * ds + dv * dv)
EndProcedure

Procedure.f ColorEdge_DeltaE_Lab(L1.f, a1.f, b1.f, L2.f, a2.f, b2.f)
  Protected.f dL = L2 - L1, da = a2 - a1, db = b2 - b1
  ProcedureReturn Sqr(dL * dL + da * da + db * db)
EndProcedure

Procedure ColorEdgeDetection_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    
    Protected sensitivity.f = \option[0]
    Protected colorSpace = \option[1]
    Protected toGray = \option[2]
    Protected inverse = \option[3]
    Protected method = \option[4]
    
    Clamp(sensitivity, 1, 100)
    sensitivity * 0.02
    
    Protected kRadius = 1
    Protected Dim r3(8)
    Protected Dim g3(8)
    Protected Dim b3(8)
    Protected Dim h3.f(8), Dim s3.f(8), Dim v3.f(8)
    Protected Dim L3.f(8), Dim a3.f(8), Dim b3Lab.f(8)
    
    Protected *srcPixel.Long, *dstPixel.Long
    Protected r, g, b, x, y, i, j, idx, v
    Protected.f distH, distV, distD1, distD2, gradientMagnitude, edgeStrength, currentDist, maxDist
    
    macro_calul_tread((ht - 2))
    
    Protected startPos = thread_start + 1
    Protected endPos   = thread_stop
    Clamp(startPos, 1, ht - 2) : Clamp(endPos, 1, ht - 2)
    
    If startPos > endPos : ProcedureReturn : EndIf
    
    For y = startPos To endPos
      For x = 1 To lg - 2
        idx = 0
        For j = -1 To 1
          For i = -1 To 1
            *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
            ColorEdge_ReadPixel(idx)
            idx + 1
          Next
        Next
        
        Select colorSpace
          Case 1 : For i = 0 To 8 : ColorEdge_RGB_To_HSV(r3(i), g3(i), b3(i), @h3(i), @s3(i), @v3(i)) : Next
          Case 2 : For i = 0 To 8 : ColorEdge_RGB_To_Lab(r3(i), g3(i), b3(i), @L3(i), @a3(i), @b3Lab(i)) : Next
        EndSelect
        
        If toGray
          Select method
            Case 0 ; Sobel
              Select colorSpace
                Case 0 ; RGB
                  distH = (ColorEdge_Euclidean_Distance_RGB(r3(0), g3(0), b3(0), r3(2), g3(2), b3(2)) + ColorEdge_Euclidean_Distance_RGB(r3(3), g3(3), b3(3), r3(5), g3(5), b3(5)) * 2.0 + ColorEdge_Euclidean_Distance_RGB(r3(6), g3(6), b3(6), r3(8), g3(8), b3(8)))
                  distV = (ColorEdge_Euclidean_Distance_RGB(r3(0), g3(0), b3(0), r3(6), g3(6), b3(6)) + ColorEdge_Euclidean_Distance_RGB(r3(1), g3(1), b3(1), r3(7), g3(7), b3(7)) * 2.0 + ColorEdge_Euclidean_Distance_RGB(r3(2), g3(2), b3(2), r3(8), g3(8), b3(8)))
                Case 1 ; HSV
                  distH = (ColorEdge_Euclidean_Distance_HSV(h3(0), s3(0), v3(0), h3(2), s3(2), v3(2)) + ColorEdge_Euclidean_Distance_HSV(h3(3), s3(3), v3(3), h3(5), s3(5), v3(5)) * 2.0 + ColorEdge_Euclidean_Distance_HSV(h3(6), s3(6), v3(6), h3(8), s3(8), v3(8)))
                  distV = (ColorEdge_Euclidean_Distance_HSV(h3(0), s3(0), v3(0), h3(6), s3(6), v3(6)) + ColorEdge_Euclidean_Distance_HSV(h3(1), s3(1), v3(1), h3(7), s3(7), v3(7)) * 2.0 + ColorEdge_Euclidean_Distance_HSV(h3(2), s3(2), v3(2), h3(8), s3(8), v3(8)))
                Case 2 ; Lab
                  distH = (ColorEdge_DeltaE_Lab(L3(0), a3(0), b3Lab(0), L3(2), a3(2), b3Lab(2)) + ColorEdge_DeltaE_Lab(L3(3), a3(3), b3Lab(3), L3(5), a3(5), b3Lab(5)) * 2.0 + ColorEdge_DeltaE_Lab(L3(6), a3(6), b3Lab(6), L3(8), a3(8), b3Lab(8)))
                  distV = (ColorEdge_DeltaE_Lab(L3(0), a3(0), b3Lab(0), L3(6), a3(6), b3Lab(6)) + ColorEdge_DeltaE_Lab(L3(1), a3(1), b3Lab(1), L3(7), a3(7), b3Lab(7)) * 2.0 + ColorEdge_DeltaE_Lab(L3(2), a3(2), b3Lab(2), L3(8), a3(8), b3Lab(8)))
              EndSelect
              gradientMagnitude = Sqr(distH * distH + distV * distV)
            Case 1 ; Max
              maxDist = 0
              For i = 0 To 8
                If i = 4 : Continue : EndIf
                Select colorSpace
                  Case 0 : currentDist = ColorEdge_Euclidean_Distance_RGB(r3(4), g3(4), b3(4), r3(i), g3(i), b3(i))
                  Case 1 : currentDist = ColorEdge_Euclidean_Distance_HSV(h3(4), s3(4), v3(4), h3(i), s3(i), v3(i))
                  Case 2 : currentDist = ColorEdge_DeltaE_Lab(L3(4), a3(4), b3Lab(4), L3(i), a3(i), b3Lab(i))
                EndSelect
                If currentDist > maxDist : maxDist = currentDist : EndIf
              Next
              gradientMagnitude = maxDist
            Case 2 ; Composé
              Select colorSpace
                Case 0 : distH = ColorEdge_Euclidean_Distance_RGB(r3(3), g3(3), b3(3), r3(5), g3(5), b3(5)) : distV = ColorEdge_Euclidean_Distance_RGB(r3(1), g3(1), b3(1), r3(7), g3(7), b3(7)) : distD1 = ColorEdge_Euclidean_Distance_RGB(r3(0), g3(0), b3(0), r3(8), g3(8), b3(8)) : distD2 = ColorEdge_Euclidean_Distance_RGB(r3(2), g3(2), b3(2), r3(6), g3(6), b3(6))
                Case 1 : distH = ColorEdge_Euclidean_Distance_HSV(h3(3), s3(3), v3(3), h3(5), s3(5), v3(5)) : distV = ColorEdge_Euclidean_Distance_HSV(h3(1), s3(1), v3(1), h3(7), s3(7), v3(7)) : distD1 = ColorEdge_Euclidean_Distance_HSV(h3(0), s3(0), v3(0), h3(8), s3(8), v3(8)) : distD2 = ColorEdge_Euclidean_Distance_HSV(h3(2), s3(2), v3(2), h3(6), s3(6), v3(6))
                Case 2 : distH = ColorEdge_DeltaE_Lab(L3(3), a3(3), b3Lab(3), L3(5), a3(5), b3Lab(5)) : distV = ColorEdge_DeltaE_Lab(L3(1), a3(1), b3Lab(1), L3(7), a3(7), b3Lab(7)) : distD1 = ColorEdge_DeltaE_Lab(L3(0), a3(0), b3Lab(0), L3(8), a3(8), b3Lab(8)) : distD2 = ColorEdge_DeltaE_Lab(L3(2), a3(2), b3Lab(2), L3(6), a3(6), b3Lab(6))
              EndSelect
              gradientMagnitude = Sqr(distH * distH + distV * distV + distD1 * distD1 + distD2 * distD2)
          EndSelect
          edgeStrength = gradientMagnitude * sensitivity * 10.0
          Clamp(edgeStrength, 0, 255)
          If inverse : edgeStrength = 255 - edgeStrength : EndIf
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(edgeStrength) * $010101))
        Else
          Select method
            Case 0, 2
              Select colorSpace
                Case 0
                  Protected.f rxH, gxH, bxH, rxV, gxV, bxV
                  v = (r3(2) + (r3(5) << 1) + r3(8)) - (r3(0) + (r3(3) << 1) + r3(6)) : rxH = v
                  v = (g3(2) + (g3(5) << 1) + g3(8)) - (g3(0) + (g3(3) << 1) + g3(6)) : gxH = v
                  v = (b3(2) + (b3(5) << 1) + b3(8)) - (b3(0) + (b3(3) << 1) + b3(6)) : bxH = v
                  v = (r3(6) + (r3(7) << 1) + r3(8)) - (r3(0) + (r3(1) << 1) + r3(2)) : rxV = v
                  v = (g3(6) + (g3(7) << 1) + g3(8)) - (g3(0) + (g3(1) << 1) + g3(2)) : gxV = v
                  v = (b3(6) + (b3(7) << 1) + b3(8)) - (b3(0) + (b3(1) << 1) + b3(2)) : bxV = v
                  r = Sqr(rxH * rxH + rxV * rxV) * sensitivity * 2.0
                  g = Sqr(gxH * gxH + gxV * gxV) * sensitivity * 2.0
                  b = Sqr(bxH * bxH + bxV * bxV) * sensitivity * 2.0
                Default
                  Select colorSpace
                    Case 1 : distH = ColorEdge_Euclidean_Distance_HSV(h3(3), s3(3), v3(3), h3(5), s3(5), v3(5)) : distV = ColorEdge_Euclidean_Distance_HSV(h3(1), s3(1), v3(1), h3(7), s3(7), v3(7))
                    Case 2 : distH = ColorEdge_DeltaE_Lab(L3(3), a3(3), b3Lab(3), L3(5), a3(5), b3Lab(5)) : distV = ColorEdge_DeltaE_Lab(L3(1), a3(1), b3Lab(1), L3(7), a3(7), b3Lab(7))
                  EndSelect
                  gradientMagnitude = Sqr(distH * distH + distV * distV) * sensitivity * 10.0
                  r = (r3(4) / 255.0) * gradientMagnitude : g = (g3(4) / 255.0) * gradientMagnitude : b = (b3(4) / 255.0) * gradientMagnitude
              EndSelect
            Case 1
              maxDist = 0
              For i = 0 To 8
                If i = 4 : Continue : EndIf
                Select colorSpace
                  Case 0 : currentDist = ColorEdge_Euclidean_Distance_RGB(r3(4), g3(4), b3(4), r3(i), g3(i), b3(i))
                  Case 1 : currentDist = ColorEdge_Euclidean_Distance_HSV(h3(4), s3(4), v3(4), h3(i), s3(i), v3(i))
                  Case 2 : currentDist = ColorEdge_DeltaE_Lab(L3(4), a3(4), b3Lab(4), L3(i), a3(i), b3Lab(i))
                EndSelect
                If currentDist > maxDist : maxDist = currentDist : EndIf
              Next
              gradientMagnitude = maxDist * sensitivity * 10.0
              r = (r3(4) / 255.0) * gradientMagnitude : g = (g3(4) / 255.0) * gradientMagnitude : b = (b3(4) / 255.0) * gradientMagnitude
          EndSelect
          Clamp(r, 0, 255) : Clamp(g, 0, 255) : Clamp(b, 0, 255)
          If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b))
        EndIf
      Next
    Next
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3())
    FreeArray(h3()) : FreeArray(s3()) : FreeArray(v3())
    FreeArray(L3()) : FreeArray(a3()) : FreeArray(b3Lab())
  EndWith
EndProcedure

Procedure ColorEdgeDetectionEx(*FilterCtx.FilterParams)
  Restore ColorEdgeDetection_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ColorEdgeDetection_MT())
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure ColorEdgeDetection(source, cible, mask, sensibilite, espace, nb, inverse, methode)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = sensibilite : \option[1] = espace : \option[2] = nb : \option[3] = inverse : \option[4] = methode
  EndWith
  ColorEdgeDetectionEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  ColorEdgeDetection_data:
  Data.s "ColorEdgeDetection"
  Data.s "Détection de contours basée sur les variations de couleur"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Specialized
  
  Data.s "Sensibilité"
  Data.i 1, 100, 40
  Data.s "Espace couleur (0=RGB/1=HSV/2=Lab)"
  Data.i 0, 2, 0
  Data.s "Noir et blanc"
  Data.i 0, 1, 0
  Data.s "Inversion"
  Data.i 0, 1, 0
  Data.s "Méthode (0=Sobel/1=Max/2=Composé)"
  Data.i 0, 2, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 88
; FirstLine = 59
; Folding = --
; EnableXP
; DPIAware