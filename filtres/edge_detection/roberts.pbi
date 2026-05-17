; Conversion HSV → RGB pour le mode orientation
Procedure Roberts_RGBFromHSV(*r.Integer, *g.Integer, *b.Integer, h.f, s.f, v.f)
  Protected c.f = v * s
  Protected x.f = c * (1.0 - Abs(Mod(h / 60.0, 2.0) - 1.0))
  Protected m.f = v - c
  Protected r1.f, g1.f, b1.f
  Protected sector = h / 60.0
  
  Select Int(sector)
    Case 0 : r1 = c : g1 = x : b1 = 0.0
    Case 1 : r1 = x : g1 = c : b1 = 0.0
    Case 2 : r1 = 0.0 : g1 = c : b1 = x
    Case 3 : r1 = 0.0 : g1 = x : b1 = c
    Case 4 : r1 = x : g1 = 0.0 : b1 = c
    Default: r1 = c : g1 = 0.0 : b1 = x
  EndSelect
  
  *r\i = Int((r1 + m) * 255.0)
  *g\i = Int((g1 + m) * 255.0)
  *b\i = Int((b1 + m) * 255.0)
EndProcedure

Procedure Roberts_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.05
    Protected math = \option[1]       ; 0: SQR, 1: ABS
    Protected toGray = \option[2]     ; Boolean
    Protected inverse = \option[3]    ; Boolean
    Protected seuillage = \option[4]  ; 0-255
    Protected orientation = \option[5]; Boolean
    Protected angle_add.f = \option[6]
    
    Protected x, y, pitch = lg << 2
    Protected a, r, g, b
    Protected r1, g1, b1, r2, g2, b2, r3, g3, b3, r4, g4, b4
    Protected gxR, gxG, gxB, gyR, gyG, gyB
    Protected valR.f, valG.f, valB.f, gx, gy, mag.f, angle.f
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    
    macro_calul_tread(ht)
    
    ; On s'arrête à ht-1 et lg-1 car Roberts utilise un voisinage 2x2 (x+1, y+1)
    For y = thread_start To thread_stop - 1
      If y >= ht - 1 : Break : EndIf
      
      Protected *srcLine = \addr[0] + (y * pitch)
      Protected *srcLineNext = *srcLine + pitch
      Protected *dstLine = \addr[1] + (y * pitch)
      
      For x = 0 To lg - 2
        Protected offset = x << 2
        
        ; Pixel (x, y)
        *srcPixel = *srcLine + offset
        getargb(*srcPixel\l, a, r1, g1, b1)
        ; Pixel (x+1, y)
        *srcPixel = *srcLine + offset + 4
        getrgb(*srcPixel\l, r2, g2, b2)
        ; Pixel (x, y+1)
        *srcPixel = *srcLineNext + offset
        getrgb(*srcPixel\l, r3, g3, b3)
        ; Pixel (x+1, y+1)
        *srcPixel = *srcLineNext + offset + 4
        getrgb(*srcPixel\l, r4, g4, b4)

        ; Gx = P(x,y) - P(x+1, y+1)
        gxR = r1 - r4 : gxG = g1 - g4 : gxB = b1 - b4
        ; Gy = P(x+1, y) - P(x, y+1)
        gyR = r2 - r3 : gyG = g2 - g3 : gyB = b2 - b3
        
        If orientation
          gx = gxR + gxG + gxB
          gy = gyR + gyG + gyB
          mag = Sqr(gx * gx + gy * gy) * mul
          angle = ATan2(gx, gy) * 180.0 / #PI + angle_add
          
          ; Wrap angle
          While angle < 0.0 : angle + 360.0 : Wend
          While angle >= 360.0 : angle - 360.0 : Wend
          
          If mag > 255.0 : mag = 255.0 : EndIf
          Roberts_RGBFromHSV(@r, @g, @b, angle, 1.0, mag / 255.0)
        Else
          If math ; Mode ABS
            valR = Abs(gxR) + Abs(gyR)
            valG = Abs(gxG) + Abs(gyG)
            valB = Abs(gxB) + Abs(gyB)
          Else   ; Mode SQR
            valR = Sqr(gxR * gxR + gyR * gyR) 
            valG = Sqr(gxG * gxG + gyG * gyG) 
            valB = Sqr(gxB * gxB + gyB * gyB) 
          EndIf
          
          r = Int(valR * mul)
          g = Int(valG * mul)
          b = Int(valB * mul)
        EndIf
        
        ; Clamping et Seuillage
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        
        If seuillage > 0
          If r > seuillage : r = 255 : Else : r = 0 : EndIf
          If g > seuillage : g = 255 : Else : g = 0 : EndIf
          If b > seuillage : b = 255 : Else : b = 0 : EndIf
        EndIf
        
        If toGray
          r = (r * 77 + g * 150 + b * 29) >> 8
          g = r : b = r
        EndIf

        If inverse
          r = 255 - r : g = 255 - g : b = 255 - b
        EndIf

        *dstPixel = *dstLine + offset
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure RobertsEx(*FilterCtx.FilterParams)
  Restore Roberts_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@Roberts_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure Roberts(source, cible, mask, multiply=10, math=0, gray=0, inverse=0, seuil=0, orient=0, angle=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = math
    \option[2] = gray
    \option[3] = inverse
    \option[4] = seuil
    \option[5] = orient
    \option[6] = angle
  EndWith
  RobertsEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Roberts_data:
  Data.s "Roberts"
  Data.s "Détection de contours par l'opérateur de Roberts (gradient 2x2)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
  
  Data.s "Multiplicateur"
  Data.i 0, 100, 10
  Data.s "Math (0:SQR, 1:ABS)"
  Data.i 0, 1, 0
  Data.s "Niveaux de gris"
  Data.i 0, 1, 0
  Data.s "Inverser"
  Data.i 0, 1, 0
  Data.s "Seuillage (0=Off)"
  Data.i 0, 255, 0
  Data.s "Orientation (HSV)"
  Data.i 0, 1, 0
  Data.s "Angle d'ajustement"
  Data.i 0, 360, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 138
; FirstLine = 125
; Folding = -
; EnableXP
; DPIAware