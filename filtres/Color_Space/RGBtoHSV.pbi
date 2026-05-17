Procedure RGBtoHSV_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    Protected.f rf, gf, bf, min, max, delta, h, s, v
    Protected.l i, alpha, r, g, b, h8, s8, v8
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      getargb(*src\pixel[i], alpha, r, g, b)
      
      ; 1. Normalisation RGB [0-1]
      rf = r / 255.0
      gf = g / 255.0
      bf = b / 255.0
      
      ; 2. Trouver Min et Max
      max = rf
      If gf > max : max = gf : EndIf
      If bf > max : max = bf : EndIf
      
      min = rf
      If gf < min : min = gf : EndIf
      If bf < min : min = bf : EndIf
      
      delta = max - min
      
      ; --- Calcul de la Valeur (V) ---
      v = max
      
      ; --- Calcul de la Saturation (S) ---
      If max > 0
        s = delta / max
      Else
        s = 0
      EndIf
      
      ; --- Calcul de la Teinte (H) ---
      If delta = 0
        h = 0 ; Gris (pas de teinte)
      Else
        If max = rf
          h = (gf - bf) / delta
        ElseIf max = gf
          h = 2.0 + (bf - rf) / delta
        Else
          h = 4.0 + (rf - gf) / delta
        EndIf
        
        h * 60.0 ; Conversion en degrés
        If h < 0 : h + 360.0 : EndIf
      EndIf
      
      ; --- Modification via les options ---
      ; On ajuste H, S, V avant le stockage
      h = h + (\option[0] - 127) * 2 ; Ajustement Teinte (+/- 254°)
      If h < 0 : h + 360 : ElseIf h > 360 : h - 360 : EndIf
      
      s = s + ((\option[1] - 127) / 127.0) ; Ajustement Saturation
      If s < 0 : s = 0 : ElseIf s > 1 : s = 1 : EndIf
      
      v = v + ((\option[2] - 127) / 127.0) ; Ajustement Valeur
      If v < 0 : v = 0 : ElseIf v > 1 : v = 1 : EndIf
      
      ; --- Mapping vers 8-bit (0-255) ---
      h8 = Int(h * 255 / 360) ; On ramène 0-360 vers 0-255
      s8 = Int(s * 255)
      v8 = Int(v * 255)
      
      ; Clamp final par précaution
      If h8 < 0 : h8 = 0 : ElseIf h8 > 255 : h8 = 255 : EndIf
      If s8 < 0 : s8 = 0 : ElseIf s8 > 255 : s8 = 255 : EndIf
      If v8 < 0 : v8 = 0 : ElseIf v8 > 255 : v8 = 255 : EndIf
      
      *dst\pixel[i] = (alpha << 24) | (h8 << 16) | (s8 << 8) | v8
    Next
  EndWith
EndProcedure

Procedure RGBtoHSVEx(*FilterCtx.FilterParams)
  Restore RGBtoHSV_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@RGBtoHSV_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure RGBtoHSV(source , cible , mask , h , s , v)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = h
    \option[1] = s
    \option[2] = v
  EndWith
  RGBtoHSVEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RGBtoHSV_data:
  Data.s "RGB -> HSV"
  Data.s "Conversion RGB vers HSV avec réglages"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "H (Teinte)"            
  Data.i 0,255,127
  Data.s "S (Saturation)"            
  Data.i 0,255,127
  Data.s "V (Valeur)"    
  Data.i 0,255,127
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; Folding = -
; EnableXP
; DPIAware