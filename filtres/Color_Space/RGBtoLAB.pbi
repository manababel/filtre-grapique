  Procedure.f RGBtoLAB_PivotXYZ(t.f)
    If t > 0.008856
      ProcedureReturn Pow(t, 1.0 / 3.0)
    Else
      ProcedureReturn (7.787 * t) + (16.0 / 116.0)
    EndIf
  EndProcedure

Procedure RGBtoLAB_MT(*p.parametre)
  Protected *src = *p\source
  Protected *dst = *p\cible
  Protected lg = *p\lg
  Protected ht = *p\ht
  
  Protected op1 = *p\option[0]
  Protected i, color
  Protected alpha, r, g, b
  Protected L.f, a.f, bb.f

  Protected total = lg * ht
  Protected start = (*p\thread_pos * total) / *p\thread_max
  Protected stop  = ((*p\thread_pos + 1) * total) / *p\thread_max - 1
  If stop > total - 1 : stop = total - 1 : EndIf

  For i = start To stop
    color = PeekL(*src + i * 4)
    ; Extraction des canaux ARGB
    getargb(color , alpha,r,g,b)

    ; RGB → XYZ
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

    Protected X.f = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
    Protected Y.f = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
    Protected Z.f = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b

    ; XYZ → LAB
    Protected Xn.f = 0.95047
    Protected Yn.f = 1.00000
    Protected Zn.f = 1.08883

    Protected fx.f = RGBtoLAB_PivotXYZ(X / Xn)
    Protected fy.f = RGBtoLAB_PivotXYZ(Y / Yn)
    Protected fz.f = RGBtoLAB_PivotXYZ(Z / Zn)

    L = (116 * fy) - 16
    a = 500 * (fx - fy)
    bb = 200 * (fy - fz)
    ; --- modification ---
    Debug l
    L = L + op1
    a = a - *p\option[1]
    bb = bb - *p\option[2]
    
    Protected L8 = Int(L * 255 / 100)
    Protected a8 = Int(a + 128)
    Protected b8 = Int(bb + 128)
    clamp_rgb(l8,a8,b8)
    
    PokeL(*dst + i * 4 + 0, (alpha << 24) | (l8 << 16) | (a8 << 8) | b8 )

  Next
EndProcedure

Procedure RGBtoLAB(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorSpace
    param\name = "RGB → LAB"
    param\remarque = "Conversion RGB vers LAB multithreadée"
    param\info[0] = "L (luminosité)"
    param\info[1] = "a (chrominance)"
    param\info[2] = "b (chrominance)"
    param\info[3] = "Masque binaire"
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

  MultiThread_MT(@RGBtoLAB_MT())
  If *mask : *param\mask_type = *param\option[3] : MultiThread_MT(@_mask()) : EndIf
  
  FreeArray(tr())
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 86
; FirstLine = 48
; Folding = -
; EnableXP
; DPIAware