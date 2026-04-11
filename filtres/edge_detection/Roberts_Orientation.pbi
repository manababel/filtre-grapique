; Conversion HSV → RGB (simple)
Procedure RGBFromHSV(*r.Integer, *g.Integer, *b.Integer, h.f, s.f, v.f)
  Protected c.f = v * s
  Protected x.f = c * (1 - Abs(Mod(h / 60.0, 2) - 1))
  Protected m.f = v - c
  Protected r1.f, g1.f, b1.f
  
  Select Int(h / 60)
    Case 0 : r1 = c : g1 = x : b1 = 0
    Case 1 : r1 = x : g1 = c : b1 = 0
    Case 2 : r1 = 0 : g1 = c : b1 = x
    Case 3 : r1 = 0 : g1 = x : b1 = c
    Case 4 : r1 = x : g1 = 0 : b1 = c
    Default: r1 = c : g1 = 0 : b1 = x
  EndSelect
  
  *r\i = (r1 + m) * 255
  *g\i = (g1 + m) * 255
  *b\i = (b1 + m) * 255
EndProcedure


Procedure Roberts_Orientation_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected mul.f = *param\option[0]
  clamp(mul, 0, 100)
  mul = mul * 0.05
  
  Protected a, r, g, b
  Protected r1,g1,b1, r2,g2,b2, r3,g3,b3, r4,g4,b4
  Protected gx, gy, mag, angle
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected x, y
  
  Protected startPos = (*param\thread_pos * (ht-1)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht-1)) / *param\thread_max
  
  For y = startPos To endPos - 1
    For x = 0 To lg - 2
      ; Lire pixels
      *srcPixel = (*source + (y * lg + x) * 4)
      getargb(*srcPixel\l, a, r1,g1,b1)
      
      *srcPixel = (*source + (y * lg + x + 1) * 4)
      getrgb(*srcPixel\l, r2,g2,b2)
      
      *srcPixel = (*source + ((y+1) * lg + x) * 4)
      getrgb(*srcPixel\l, r3,g3,b3)
      
      *srcPixel = (*source + ((y+1) * lg + x + 1) * 4)
      getrgb(*srcPixel\l, r4,g4,b4)
      
      ; Gradient Roberts (sur luminance simplifiée)
      gx = (r1 - r4) + (g1 - g4) + (b1 - b4)
      gy = (r2 - r3) + (g2 - g3) + (b2 - b3)
      
      ; Magnitude et orientation
      mag   = Sqr(gx*gx + gy*gy) * mul
      angle = ATan2(gy, gx) * 180 / #PI   ; angle en degrés -180..180
      If angle < 0 : angle + 360 : EndIf  ; normalisation 0..360
      
      ; Conversion HSV → RGB
      RGBFromHSV(@r, @g, @b, angle, 1.0, mag/255.0)
      
      clamp_rgb(r, g, b)
      
      *dstPixel = (*cible + (y * lg + x) * 4)
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    Next
  Next
EndProcedure

Procedure Roberts_Orientation(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    *param\subtype = #EdgeDetect_Gradient
    param\name = "Roberts_Orientation"
    param\remarque = "Détection 2 directions"
    param\info[0] = "multiply"
    param\info[1] = "math (ABS ou SQR)"
    param\info[2] = "Noir et blanc"
    param\info[3] = "inversion"
    param\info[4] = "seuillage : 0 = off"
    param\info[5] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 10
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1 : param\info_data(1,2) = 0
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1   : param\info_data(2,2) = 0
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255   : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Roberts_Orientation_MT() , 5)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 79
; FirstLine = 30
; Folding = -
; EnableXP
; DPIAware