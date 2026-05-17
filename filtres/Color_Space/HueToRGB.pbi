Procedure HueToRGB_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    Protected.f h, f, p, q, t, rf, gf, bf
    Protected.l i, alpha, r8, g8, b8, h_in, sector
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Récupération de la teinte (on suppose qu'elle est stockée sur le canal Rouge ou les trois)
      getargb(*src\pixel[i], alpha, h_in, r8, g8) ; On récupère h_in depuis le canal R
      
      ; 2. Dé-normalisation (0-255 -> 0-360°)
      h = (h_in * 360.0) / 255.0
      
      ; --- Application de l'offset optionnel ---
      h = h + (\option[0] - 127) * 2
      While h < 0 : h + 360 : Wend
      While h >= 360 : h - 360 : Wend
      
      ; 3. Algorithme de conversion Hue vers RGB (avec S=1 et V=1)
      ; On divise le cercle en 6 secteurs de 60 degrés
      sector = Int(h / 60.0) % 6
      f = (h / 60.0) - sector
      
      ; Ici p=0 (1-S), q=(1-S*f), t=(1-S*(1-f)) car S=1 et V=1
      p = 0.0
      q = 1.0 - f
      t = f
      
      Select sector
        Case 0 : rf = 1.0 : gf = t   : bf = p
        Case 1 : rf = q   : gf = 1.0 : bf = p
        Case 2 : rf = p   : gf = 1.0 : bf = t
        Case 3 : rf = p   : gf = q   : bf = 1.0
        Case 4 : rf = t   : gf = p   : bf = 1.0
        Case 5 : rf = 1.0 : gf = p   : bf = q
      EndSelect
      
      ; 4. Mapping vers 8-bit (0-255)
      r8 = Int(rf * 255)
      g8 = Int(gf * 255)
      b8 = Int(bf * 255)
      
      ; Sécurité Clamp
      If r8 < 0 : r8 = 0 : ElseIf r8 > 255 : r8 = 255 : EndIf
      If g8 < 0 : g8 = 0 : ElseIf g8 > 255 : g8 = 255 : EndIf
      If b8 < 0 : b8 = 0 : ElseIf b8 > 255 : b8 = 255 : EndIf
      
      *dst\pixel[i] = (alpha << 24) | (r8 << 16) | (g8 << 8) | b8
    Next
  EndWith
EndProcedure

Procedure HueToRGBEx(*FilterCtx.FilterParams)
  Restore HueToRGB_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@HueToRGB_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure HueToRGB(source, cible, mask, hue_offset)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = hue_offset
  EndWith
  HueToRGBEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  HueToRGB_data:
  Data.s "Hue -> RGB"
  Data.s "Génération de couleurs vives à partir de la teinte"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Décalage Teinte"            
  Data.i 0,255,127
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; Folding = -
; EnableXP
; DPIAware