Procedure.f HSLtoRGB_HueToRGB(p.f, q.f, t.f)
  If t < 0 : t + 1.0 : EndIf
  If t > 1 : t - 1.0 : EndIf
  If t < 1.0/6.0 : ProcedureReturn p + (q - p) * 6.0 * t : EndIf
  If t < 1.0/2.0 : ProcedureReturn q : EndIf
  If t < 2.0/3.0 : ProcedureReturn p + (q - p) * (2.0/3.0 - t) * 6.0 : EndIf
  ProcedureReturn p
EndProcedure

Procedure HSLtoRGB_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    Protected.f h, s, l, q, p, rf, gf, bf
    Protected.l i, alpha, r8, g8, b8, h_in, s_in, l_in
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Récupération des données HSL
      getargb(*src\pixel[i], alpha, h_in, s_in, l_in)
      
      ; 2. Dé-normalisation
      h = (h_in * 360.0) / 255.0 ; 0-360°
      s = s_in / 255.0           ; 0-1
      l = l_in / 255.0           ; 0-1
      
      ; --- Application des options ---
      h = h + (\option[0] - 127) * 2
      While h < 0 : h + 360 : Wend
      While h >= 360 : h - 360 : Wend
      
      s = s + ((\option[1] - 127) / 127.0)
      If s < 0 : s = 0 : ElseIf s > 1 : s = 1 : EndIf
      
      l = l + ((\option[2] - 127) / 127.0)
      If l < 0 : l = 0 : ElseIf l > 1 : l = 1 : EndIf
      
      ; 3. Algorithme de conversion HSL vers RGB
      If s = 0
        rf = l : gf = l : bf = l ; Gris
      Else
        If l < 0.5
          q = l * (1.0 + s)
        Else
          q = l + s - l * s
        EndIf
        p = 2.0 * l - q
        
        ; Conversion de la teinte en composantes RGB
        rf = HSLtoRGB_HueToRGB(p, q, (h / 360.0) + 1.0/3.0)
        gf = HSLtoRGB_HueToRGB(p, q, (h / 360.0))
        bf = HSLtoRGB_HueToRGB(p, q, (h / 360.0) - 1.0/3.0)
      EndIf
      
      ; 4. Mapping final vers 8-bit
      r8 = Int(rf * 255)
      g8 = Int(gf * 255)
      b8 = Int(bf * 255)
      
      ; Clamp
      If r8 < 0 : r8 = 0 : ElseIf r8 > 255 : r8 = 255 : EndIf
      If g8 < 0 : g8 = 0 : ElseIf g8 > 255 : g8 = 255 : EndIf
      If b8 < 0 : b8 = 0 : ElseIf b8 > 255 : b8 = 255 : EndIf
      
      *dst\pixel[i] = (alpha << 24) | (r8 << 16) | (g8 << 8) | b8
    Next
  EndWith
EndProcedure

Procedure HSLtoRGBEx(*FilterCtx.FilterParams)
  Restore HSLtoRGB_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@HSLtoRGB_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure HSLtoRGB(source, cible, mask, h, s, l)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = h
    \option[1] = s
    \option[2] = l
  EndWith
  HSLtoRGBEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  HSLtoRGB_data:
  Data.s "HSL -> RGB"
  Data.s "Conversion HSL vers RGB avec réglages"
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