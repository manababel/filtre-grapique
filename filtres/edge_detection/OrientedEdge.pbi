Procedure OrientedEdge_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected mul.f = \option[0]
    Protected angle.f = \option[1]
    Protected tolerance.f = \option[2]
    Protected toGray = \option[3]
    Protected inverse = \option[4]
    Protected showDirection = \option[5]
    Protected suppressNonMax = \option[6]
    
    clamp(mul, 0, 100)
    mul = mul * 0.1
    
    ; Normaliser l'angle entre 0 et 360
    While angle < 0.0
      angle + 360.0
    Wend
    While angle >= 360.0
      angle - 360.0
    Wend
    
    clamp(tolerance, 0, 180)
    
    ; Convertir l'angle cible en radians
    Protected target_angle_rad.f = (angle * #PI) / 180.0
    Protected tolerance_rad.f = (tolerance * #PI) / 180.0

    Protected a, r, g, b
    Protected r1, g1, b1, r2, g2, b2, r3, g3, b3, r4, g4, b4
    Protected r5, g5, b5, r6, g6, b6, r7, g7, b7, r8, g8, b8
    Protected gx.f, gy.f, mag.f, edge_angle.f, angle_diff.f
    Protected valR.f, valG.f, valB.f
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected x, y
    Protected pitch = lg * 4

    macro_calul_tread((ht - 2))
    
    Protected startPos = thread_start + 1
    Protected endPos   = thread_stop + 1
    
    If startPos < 1 : startPos = 1 : EndIf
    If endPos > ht - 2 : endPos = ht - 2 : EndIf
    
    ; Buffer temporaire pour stocker les magnitudes
    Protected Dim mag_buffer.f(lg, 3)
    Protected Dim angle_buffer.f(lg, 3)
    
    For y = startPos To endPos
      Protected *srcLinePrev = *source + (y - 1) * pitch
      Protected *srcLine = *source + y * pitch
      Protected *srcLineNext = *source + (y + 1) * pitch
      Protected *dstLine = *cible + y * pitch
      
      For x = 1 To lg - 2
        Protected offset = x * 4
        
        ; Lecture des 8 pixels voisins
        *srcPixel = *srcLinePrev + offset - 4
        getargb(*srcPixel\l, a, r1, g1, b1)
        *srcPixel = *srcLinePrev + offset
        getrgb(*srcPixel\l, r2, g2, b2)
        *srcPixel = *srcLinePrev + offset + 4
        getrgb(*srcPixel\l, r3, g3, b3)
        
        *srcPixel = *srcLine + offset - 4
        getrgb(*srcPixel\l, r4, g4, b4)
        *srcPixel = *srcLine + offset + 4
        getrgb(*srcPixel\l, r6, g6, b6)
        
        *srcPixel = *srcLineNext + offset - 4
        getrgb(*srcPixel\l, r7, g7, b7)
        *srcPixel = *srcLineNext + offset
        getrgb(*srcPixel\l, r8, g8, b8)
        *srcPixel = *srcLineNext + offset + 4
        getrgb(*srcPixel\l, r5, g5, b5) 
        
        ; Opérateur Sobel
        Protected gxR.f = (-r1 - (2*r4) - r7 + r3 + (2*r6) + r5)
        Protected gxG.f = (-g1 - (2*g4) - g7 + g3 + (2*g6) + g5)
        Protected gxB.f = (-b1 - (2*b4) - b7 + b3 + (2*b6) + b5)
        
        Protected gyR.f = (-r1 - (2*r2) - r3 + r7 + (2*r8) + r5)
        Protected gyG.f = (-g1 - (2*g2) - g3 + g7 + (2*g8) + g5)
        Protected gyB.f = (-b1 - (2*b2) - b3 + b7 + (2*b8) + b5)
        
        Protected magR.f = Sqr((gxR * gxR) + (gyR * gyR))
        Protected magG.f = Sqr((gxG * gxG) + (gyG * gyG))
        Protected magB.f = Sqr((gxB * gxB) + (gyB * gyB))
        
        mag = (magR + magG + magB) / 3.0
        gx = (gxR + gxG + gxB) / 3.0
        gy = (gyR + gyG + gyB) / 3.0
        
        edge_angle = ATan2(gy, gx)
        angle_diff = Abs(edge_angle - target_angle_rad)
        
        If angle_diff > #PI
          angle_diff = (2.0 * #PI) - angle_diff
        EndIf
        
        mag_buffer(x, 0) = mag
        angle_buffer(x, 0) = edge_angle
        
        If angle_diff <= tolerance_rad
          Protected response.f = 1.0 - (angle_diff / tolerance_rad)
          
          If showDirection
            Protected hue.f = ((edge_angle * 180.0) / #PI + 180.0)
            While hue < 0.0 : hue + 360.0 : Wend
            While hue >= 360.0 : hue - 360.0 : Wend
            
            Protected sat.f = response
            Protected val.f = mag / 255.0
            If val > 1.0 : val = 1.0 : EndIf
            
            Protected c.f = val * sat
            Protected x_hsv.f = c * (1.0 - Abs(Mod(hue / 60.0, 2.0) - 1.0))
            Protected m.f = val - c
            Protected sector = Int(hue / 60.0)
            
            Select sector
              Case 0 : valR = c : valG = x_hsv : valB = 0.0
              Case 1 : valR = x_hsv : valG = c : valB = 0.0
              Case 2 : valR = 0.0 : valG = c : valB = x_hsv
              Case 3 : valR = 0.0 : valG = x_hsv : valB = c
              Case 4 : valR = x_hsv : valG = 0.0 : valB = c
              Default: valR = c : valG = 0.0 : valB = x_hsv
            EndSelect
            
            valR = (valR + m) * 255.0
            valG = (valG + m) * 255.0
            valB = (valB + m) * 255.0
          Else
            valR = magR * response * mul
            valG = magG * response * mul
            valB = magB * response * mul
          EndIf
        Else
          valR = 0.0
          valG = 0.0
          valB = 0.0
        EndIf
        
        If suppressNonMax And x > 1 And y > startPos
          Protected cos_angle.f = Cos(angle_buffer(x, 0))
          Protected sin_angle.f = Sin(angle_buffer(x, 0))
          Protected mag_prev.f, mag_next.f
          
          If Abs(cos_angle) > Abs(sin_angle)
            mag_prev = mag_buffer(x - 1, 0)
            mag_next = mag_buffer(x + 1, 0)
          Else
            mag_prev = mag_buffer(x, 1)
            mag_next = mag
          EndIf
          
          If mag_buffer(x, 0) < mag_prev Or mag_buffer(x, 0) < mag_next
            valR = 0.0
            valG = 0.0
            valB = 0.0
          EndIf
        EndIf
        
        r = Int(valR)
        g = Int(valG)
        b = Int(valB)
        
        clamp_rgb(r, g, b)
        
        If toGray
          r = ((r * 77) + (g * 150) + (b * 29)) >> 8
          g = r
          b = r
        EndIf

        If inverse
          r = 255 - r
          g = 255 - g
          b = 255 - b
        EndIf

        *dstPixel = *dstLine + offset
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
      
      For x = 0 To lg - 1
        mag_buffer(x, 1) = mag_buffer(x, 0)
        angle_buffer(x, 1) = angle_buffer(x, 0)
      Next
    Next
  EndWith
EndProcedure

Procedure OrientedEdgeEx(*FilterCtx.FilterParams)
  Restore OrientedEdge_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@OrientedEdge_MT())
  
  mask_update(*FilterCtx , last_data)
EndProcedure

Procedure OrientedEdge(source , cible , mask , multiply , angle , tolerance , nb , inversion , direction , suppression)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = angle
    \option[2] = tolerance
    \option[3] = nb
    \option[4] = inversion
    \option[5] = direction
    \option[6] = suppression
  EndWith
  OrientedEdgeEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  OrientedEdge_data:
  Data.s "OrientedEdge"
  Data.s "Détection de contours dans une direction spécifique"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Specialized
  
  Data.s "multiply"
  Data.i 0, 100, 10
  Data.s "angle (0-360°)"
  Data.i 0, 360, 0
  Data.s "tolerance (0-180°)"
  Data.i 0, 180, 45
  Data.s "Noir et blanc"
  Data.i 0, 1, 0
  Data.s "inversion"
  Data.i 0, 1, 0
  Data.s "afficher direction (HSV)"
  Data.i 0, 1, 0
  Data.s "suppression non-maximum"
  Data.i 0, 1, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 41
; FirstLine = 30
; Folding = -
; EnableXP
; DPIAware