Procedure RGBtoHue_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    Protected.f rf, gf, bf, min, max, delta, h
    Protected.l i, alpha, r, g, b, h8
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      getargb(*src\pixel[i], alpha, r, g, b)
      
      ; 1. Normalisation [0-1]
      rf = r / 255.0
      gf = g / 255.0
      bf = b / 255.0
      
      ; 2. Calcul du delta (Max - Min)
      max = rf : If gf > max : max = gf : EndIf : If bf > max : max = bf : EndIf
      min = rf : If gf < min : min = gf : EndIf : If bf < min : min = bf : EndIf
      delta = max - min
      
      ; 3. Calcul de la Teinte (Hue)
      If delta = 0
        h = 0 ; Échelle de gris = pas de teinte
      Else
        If max = rf
          h = (gf - bf) / delta
        ElseIf max = gf
          h = 2.0 + (bf - rf) / delta
        Else
          h = 4.0 + (rf - gf) / delta
        EndIf
        
        h * 60.0 ; Passage en degrés (0-360)
        If h < 0 : h + 360.0 : EndIf
      EndIf
      
      ; 4. Option : Décalage de la teinte
      h = h + (\option[0] - 127) * 2
      While h < 0 : h + 360 : Wend
      While h >= 360 : h - 360 : Wend
      
      ; 5. Conversion en 8-bit (0-255)
      h8 = Int(h * 255 / 360)
      
      ; On remplit les 3 canaux avec la valeur de la teinte 
      ; pour obtenir une carte des teintes en niveaux de gris
      *dst\pixel[i] = (alpha << 24) | (h8 << 16) | (h8 << 8) | h8
    Next
  EndWith
EndProcedure

Procedure RGBtoHueEx(*FilterCtx.FilterParams)
  Restore RGBtoHue_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@RGBtoHue_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure RGBtoHue(source, cible, mask, hue_offset)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = hue_offset
  EndWith
  RGBtoHueEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RGBtoHue_data:
  Data.s "RGB -> Hue"
  Data.s "Extraction de la teinte uniquement (Niveaux de gris)"
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