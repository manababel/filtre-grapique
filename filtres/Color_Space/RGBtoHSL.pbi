Procedure RGBtoHSL_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    Protected.f rf, gf, bf, min, max, delta, h, s, l
    Protected.l i, alpha, r, g, b, h8, s8, l8
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      getargb(*src\pixel[i], alpha, r, g, b)
      
      ; 1. Normalisation RGB [0-1]
      rf = r / 255.0
      gf = g / 255.0
      bf = b / 255.0
      
      ; 2. Trouver Min et Max
      max = rf : If gf > max : max = gf : EndIf : If bf > max : max = bf : EndIf
      min = rf : If gf < min : min = gf : EndIf : If bf < min : min = bf : EndIf
      
      delta = max - min
      
      ; --- Calcul de la Luminosité (L) ---
      l = (max + min) / 2.0
      
      ; --- Calcul de la Teinte (H) ---
      If delta = 0
        h = 0 ; Gris
      Else
        If max = rf
          h = (gf - bf) / delta
        ElseIf max = gf
          h = 2.0 + (bf - rf) / delta
        Else
          h = 4.0 + (rf - gf) / delta
        EndIf
        
        h * 60.0
        If h < 0 : h + 360.0 : EndIf
      EndIf
      
      ; --- Calcul de la Saturation (S) ---
      If delta = 0
        s = 0
      Else
        ; La formule S diffère du HSV
        s = delta / (1.0 - Abs(2.0 * l - 1.0))
      EndIf
      
      ; --- Modification via les options ---
      ; Teinte
      h = h + (\option[0] - 127) * 2
      While h < 0 : h + 360 : Wend
      While h >= 360 : h - 360 : Wend
      
      ; Saturation
      s = s + ((\option[1] - 127) / 127.0)
      If s < 0 : s = 0 : ElseIf s > 1 : s = 1 : EndIf
      
      ; Luminosité
      l = l + ((\option[2] - 127) / 127.0)
      If l < 0 : l = 0 : ElseIf l > 1 : l = 1 : EndIf
      
      ; --- Mapping vers 8-bit (0-255) ---
      h8 = Int(h * 255 / 360)
      s8 = Int(s * 255)
      l8 = Int(l * 255)
      
      ; Clamp
      If h8 < 0 : h8 = 0 : ElseIf h8 > 255 : h8 = 255 : EndIf
      If s8 < 0 : s8 = 0 : ElseIf s8 > 255 : s8 = 255 : EndIf
      If l8 < 0 : l8 = 0 : ElseIf l8 > 255 : l8 = 255 : EndIf
      
      *dst\pixel[i] = (alpha << 24) | (h8 << 16) | (s8 << 8) | l8
    Next
  EndWith
EndProcedure

Procedure RGBtoHSLEx(*FilterCtx.FilterParams)
  Restore RGBtoHSL_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@RGBtoHSL_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure RGBtoHSL(source, cible, mask, h, s, l)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = h
    \option[1] = s
    \option[2] = l
  EndWith
  RGBtoHSLEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RGBtoHSL_data:
  Data.s "RGB -> HSL"
  Data.s "Conversion RGB vers HSL (Teinte, Saturation, Luminosité)"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "H (Teinte)"            
  Data.i 0,255,127
  Data.s "S (Saturation)"            
  Data.i 0,255,127
  Data.s "L (Luminosité)"    
  Data.i 0,255,127
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; Folding = -
; EnableXP
; DPIAware