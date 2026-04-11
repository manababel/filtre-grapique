Procedure.f PivotXYZ(t.f)
  If t > 0.008856
    ProcedureReturn Pow(t, 1.0 / 3.0)
  Else
    ProcedureReturn (7.787 * t) + (16.0 / 116.0)
  EndIf
EndProcedure

Procedure RGBtoXYZ(r.f, g.f, b.f, *X, *Y, *Z)
  r = r / 255.0
  g = g / 255.0
  b = b / 255.0

  If r > 0.04045
    r = Pow((r + 0.055) / 1.055, 2.4)
  Else
    r = r / 12.92
  EndIf

  If g > 0.04045
    g = Pow((g + 0.055) / 1.055, 2.4)
  Else
    g = g / 12.92
  EndIf

  If b > 0.04045
    b = Pow((b + 0.055) / 1.055, 2.4)
  Else
    b = b / 12.92
  EndIf

  *X = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
  *Y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
  *Z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b
EndProcedure

Procedure XYZtoLAB(X.f, Y.f, Z.f, *L, *a, *b)
  Protected Xn.f = 0.95047
  Protected Yn.f = 1.00000
  Protected Zn.f = 1.08883

  Protected fx.f = PivotXYZ(X / Xn)
  Protected fy.f = PivotXYZ(Y / Yn)
  Protected fz.f = PivotXYZ(Z / Zn)

  *L = (116 * fy) - 16
  *a = 500 * (fx - fy)
  *b = 200 * (fy - fz)
EndProcedure

Procedure LABtoXYZ(L.f, a.f, b.f, *X, *Y, *Z)
  Protected Yn.f = 1.0
  Protected Xn.f = 0.95047
  Protected Zn.f = 1.08883

  Protected fy.f = (L + 16) / 116.0
  Protected fx.f = a / 500.0 + fy
  Protected fz.f = fy - b / 200.0

  If Pow(fy, 3) > 0.008856
    *Y = Pow(fy, 3)
  Else
    *Y = (fy - 16.0 / 116.0) / 7.787
  EndIf

  If Pow(fx, 3) > 0.008856
    *X = Pow(fx, 3)
  Else
    *X = (fx - 16.0 / 116.0) / 7.787
  EndIf

  If Pow(fz, 3) > 0.008856
    *Z = Pow(fz, 3)
  Else
    *Z = (fz - 16.0 / 116.0) / 7.787
  EndIf

  *X = *X * Xn
  *Y = *Y * Yn
  *Z = *Z * Zn
EndProcedure

Procedure XYZtoRGB(X.f, Y.f, Z.f, *r, *g, *b)
  Protected R.f =  3.2406 * X - 1.5372 * Y - 0.4986 * Z
  Protected G.f = -0.9689 * X + 1.8758 * Y + 0.0415 * Z
  Protected B.f =  0.0557 * X - 0.2040 * Y + 1.0570 * Z

  If R <= 0.0031308
    R = 12.92 * R
  Else
    R = 1.055 * Pow(R, 1.0 / 2.4) - 0.055
  EndIf

  If G <= 0.0031308
    G = 12.92 * G
  Else
    G = 1.055 * Pow(G, 1.0 / 2.4) - 0.055
  EndIf

  If B <= 0.0031308
    B = 12.92 * B
  Else
    B = 1.055 * Pow(B, 1.0 / 2.4) - 0.055
  EndIf
  
  *r = r * 255
  *g = g * 255
  *b = b * 255
  clamp_rgb(*r , *g , *b)
EndProcedure

Procedure RGB_LAB_Modif_MT(*p.parametre)
  Protected *src = *p\source
  Protected *dst = *p\cible
  Protected lg = *p\lg
  Protected ht = *p\ht

  Protected adjustL.f = *p\option[0] / 127.5
  Protected adjustA.f = (*p\option[1] - 128) / 127.5
  Protected adjustB.f = (*p\option[2] - 128) / 127.5
  Protected grayscaleMode = *p\option[3]

  Protected i, color
  Protected alpha, r, g, b
  Protected r2.f, g2.f, b2.f
  Protected L.f, a.f, bb.f
  Protected X.f, Y.f, Z.f
  Protected total = lg * ht
  Protected start = (*p\thread_pos * total) / *p\thread_max
  Protected stop  = ((*p\thread_pos + 1) * total) / *p\thread_max - 1
  If stop > total - 1 : stop = total - 1 : EndIf

  For i = start To stop
    color = PeekL(*src + i * 4)
    getargb(color, alpha, r, g, b)

    RGBtoXYZ(r, g, b, @X, @Y, @Z)
    XYZtoLAB(X, Y, Z, @L, @a, @bb)

    L * adjustL
    a * adjustA
    bb * adjustB

    If grayscaleMode
      r2 = L * 255 / 100
      g2 = r2
      b2 = r2
    Else
      LABtoXYZ(L, a, bb, @X, @Y, @Z)
      XYZtoRGB(X, Y, Z, @r2, @g2, @b2)
    EndIf

    Clamp(r2, 0, 255)
    Clamp(g2, 0, 255)
    Clamp(b2, 0, 255)

    PokeL(*dst + i * 4, (alpha << 24) | (Int(r2) << 16) | (Int(g2) << 8) | Int(b2))
  Next
EndProcedure

Procedure RGB_LAB_Modif(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorSpace
    param\name = "RGB → LAB → modif → LAB → RGB"
    param\remarque = "Conversion complète avec ajustement des composantes LAB"
    param\info[0] = "L (luminosité)"
    param\info[1] = "a (chrominance)"
    param\info[2] = "b (chrominance)"
    param\info[3] = "Grayscale"
    param\info[4] = "Masque binaire"

    param\info_data(0,0) = 0 : param\info_data(0,1) = 255  : param\info_data(0,2) = 128
    param\info_data(1,0) = 0 : param\info_data(1,1) = 255  : param\info_data(1,2) = 128
    param\info_data(2,0) = 0 : param\info_data(2,1) = 255  : param\info_data(2,2) = 128
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1    : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 1    : param\info_data(4,2) = 0

    ProcedureReturn
  EndIf

  Protected *source = *param\source
  Protected *cible  = *param\cible
  Protected *mask   = *param\mask
  Protected i
  If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf

  Protected thread = CountCPUs(#PB_System_CPUs)
  Clamp(thread, 1, 128)
  Protected Dim tr(thread)

  MultiThread_MT(@RGB_LAB_Modif_MT())
  If *mask : *param\mask_type = *param\option[3] : MultiThread_MT(@_mask()) : EndIf

  FreeArray(tr())
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 162
; FirstLine = 126
; Folding = --
; EnableXP
; DPIAware