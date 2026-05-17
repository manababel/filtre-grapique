Procedure.f RGBtoLAB_PivotXYZ(t.f)
  If t > 0.008856451 ; (6/29)^3
    ProcedureReturn Pow(t, 1.0 / 3.0)
  Else
    ProcedureReturn (7.787037 * t) + (16.0 / 116.0) ; 7.787... = (1/3)*(29/6)^2
  EndIf
EndProcedure

Procedure RGBtoLAB_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    ; Utilisation de flottants pour les composantes
    Protected.f rf, gf, bf, X, Y, Z, fx, fy, fz, L, a, bb
    Protected.l i, alpha, r, g, b, L8, a8, b8
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      getargb(*src\pixel[i], alpha, r, g, b)
      
      ; 1. RGB [0-255] → Linear RGB [0-1]
      rf = r / 255.0 : gf = g / 255.0 : bf = b / 255.0
      
      If rf > 0.04045 : rf = Pow((rf + 0.055) / 1.055, 2.4) : Else : rf = rf / 12.92 : EndIf
      If gf > 0.04045 : gf = Pow((gf + 0.055) / 1.055, 2.4) : Else : gf = gf / 12.92 : EndIf
      If bf > 0.04045 : bf = Pow((bf + 0.055) / 1.055, 2.4) : Else : bf = bf / 12.92 : EndIf
      
      ; 2. Linear RGB → XYZ (D65 Illuminant)
      X = 0.4124564 * rf + 0.3575761 * gf + 0.1804375 * bf
      Y = 0.2126729 * rf + 0.7151522 * gf + 0.0721750 * bf
      Z = 0.0193339 * rf + 0.1191920 * gf + 0.9503041 * bf
      
      ; 3. XYZ → LAB
      ; Références D65 : Xn=0.95047, Yn=1.0, Zn=1.08883
      fx = RGBtoLAB_PivotXYZ(X / 0.95047)
      fy = RGBtoLAB_PivotXYZ(Y / 1.0)
      fz = RGBtoLAB_PivotXYZ(Z / 1.08883)
      
      L = (116.0 * fy) - 16.0
      a = 500.0 * (fx - fy)
      bb = 200.0 * (fy - fz)
      
; On ajuste L (0-100), a (-128 à 127) et b (-128 à 127)
      
      ; Ajustement de L : on décale la luminosité
      ; (option[0] - 127) donne une plage d'environ -127 à +128
      ; On divise par 2.55 pour rester dans l'échelle 0-100 du LAB
      L = L + ((\option[0] - 127) / 2.55)
      
      ; Ajustement de a et b
      a = a + (\option[1] - 127)
      bb = bb + (\option[2] - 127)
      
      ; --- Mapping final ---
       L8 = Int(L * 2.55) ; Conversion 0-100 vers 0-255
       a8 = Int(a + 128)
       b8 = Int(bb + 128)
      
      ; On s'assure de ne pas sortir des limites 0-255
      If L8 < 0 : L8 = 0 : ElseIf L8 > 255 : L8 = 255 : EndIf
      If a8 < 0 : a8 = 0 : ElseIf a8 > 255 : a8 = 255 : EndIf
      If b8 < 0 : b8 = 0 : ElseIf b8 > 255 : b8 = 255 : EndIf
      
      *dst\pixel[i] = (alpha << 24) | (L8 << 16) | (a8 << 8) | b8 
    Next
  EndWith
EndProcedure

Procedure RGBtoLABEx(*FilterCtx.FilterParams)
  Restore RGBtoLAB_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@RGBtoLAB_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure RGBToLAB(source , cible , mask , y , u , v)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = y
    \option[1] = u
    \option[2] = v
  EndWith
  RGBtoLABEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RGBtoLAB_data:
  Data.s "RGB → LAB"
  Data.s "Conversion RGB vers LAB multithreadée"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "L (luminosité)"           
  Data.i 0,255,127
  Data.s "a (chrominance)"           
  Data.i 0,255,127
  Data.s "b (chrominance)"   
  Data.i 0,255,127
  Data.s "XXX"
EndDataSection

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 57
; FirstLine = 12
; Folding = -
; EnableXP
; DPIAware