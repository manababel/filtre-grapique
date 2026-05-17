Procedure HSVtoRGB_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    Protected.f h, s, v, f, p, q, t, rf, gf, bf
    Protected.l i, alpha, r8, g8, b8, h_in, s_in, v_in, sector
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Récupération des données HSV (H=R, S=G, V=B)
      getargb(*src\pixel[i], alpha, h_in, s_in, v_in)
      
      ; 2. Dé-normalisation
      h = (h_in * 360.0) / 255.0 ; 0-255 -> 0-360°
      s = s_in / 255.0           ; 0-255 -> 0-1
      v = v_in / 255.0           ; 0-255 -> 0-1
      
      ; --- Application des options ---
      h = h + (\option[0] - 127) * 2
      While h < 0 : h + 360 : Wend
      While h >= 360 : h - 360 : Wend
      
      s = s + ((\option[1] - 127) / 127.0)
      If s < 0 : s = 0 : ElseIf s > 1 : s = 1 : EndIf
      
      v = v + ((\option[2] - 127) / 127.0)
      If v < 0 : v = 0 : ElseIf v > 1 : v = 1 : EndIf
      
      ; 3. Algorithme de conversion HSV vers RGB
      If s = 0
        ; Si la saturation est à 0, c'est un niveau de gris
        rf = v : gf = v : bf = v
      Else
        sector = Int(h / 60.0) % 6
        f = (h / 60.0) - sector
        p = v * (1.0 - s)
        q = v * (1.0 - (s * f))
        t = v * (1.0 - (s * (1.0 - f)))
        
        Select sector
          Case 0 : rf = v : gf = t : bf = p
          Case 1 : rf = q : gf = v : bf = p
          Case 2 : rf = p : gf = v : bf = t
          Case 3 : rf = p : gf = q : bf = v
          Case 4 : rf = t : gf = p : bf = v
          Case 5 : rf = v : gf = p : bf = q
        EndSelect
      EndIf
      
      ; 4. Mapping final vers 8-bit
      r8 = Int(rf * 255)
      g8 = Int(gf * 255)
      b8 = Int(bf * 255)
      
      ; Clamp de sécurité
      If r8 < 0 : r8 = 0 : ElseIf r8 > 255 : r8 = 255 : EndIf
      If g8 < 0 : g8 = 0 : ElseIf g8 > 255 : g8 = 255 : EndIf
      If b8 < 0 : b8 = 0 : ElseIf b8 > 255 : b8 = 255 : EndIf
      
      *dst\pixel[i] = (alpha << 24) | (r8 << 16) | (g8 << 8) | b8
    Next
  EndWith
EndProcedure

Procedure HSVtoRGBEx(*FilterCtx.FilterParams)
  Restore HSVtoRGB_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@HSVtoRGB_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure HSVtoRGB(source , cible , mask , h , s , v)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = h
    \option[1] = s
    \option[2] = v
  EndWith
  HSVtoRGBEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  HSVtoRGB_data:
  Data.s "HSV -> RGB"
  Data.s "Conversion HSV vers RGB avec réglages"
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