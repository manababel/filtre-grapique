; =================================================================
; FILTRE : XYZ vers RGB
; Description : Convertit l'espace de référence CIE 1931 XYZ 
;               vers l'espace sRGB (Illuminant D65).
; =================================================================

Procedure XYZtoRGB_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    ; Variables de calcul
    Protected.f X, Y, Z, rf, gf, bf
    Protected.l i, alpha, x_in, y_in, z_in
    Protected.l r8, g8, b8
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Extraction des composantes XYZ depuis les canaux R, G, B
      getargb(*src\pixel[i], alpha, x_in, y_in, z_in)
      
      ; 2. Normalisation [0.0 - 1.0] et application des options
      X = (x_in / 255.0) + ((\option[0] - 127) / 127.0)
      Y = (y_in / 255.0) + ((\option[1] - 127) / 127.0)
      Z = (z_in / 255.0) + ((\option[2] - 127) / 127.0)
      
      ; 3. Transformation Matricielle Inverse (XYZ vers Linear RGB)
      rf =  3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z
      gf = -0.9692660 * X + 1.8760108 * Y + 0.0415560 * Z
      bf =  0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z
      
      ; 4. Correction Gamma sRGB (Linéaire vers Non-Linéaire)
      ; On repasse les couleurs dans l'espace perceptuel de l'écran
      If rf > 0.0031308 : rf = 1.055 * Pow(rf, 1/2.4) - 0.055 : Else : rf = 12.92 * rf : EndIf
      If gf > 0.0031308 : gf = 1.055 * Pow(gf, 1/2.4) - 0.055 : Else : gf = 12.92 * gf : EndIf
      If bf > 0.0031308 : bf = 1.055 * Pow(bf, 1/2.4) - 0.055 : Else : bf = 12.92 * bf : EndIf
      
      ; 5. Conversion en entiers 8 bits avec Clamp
      r8 = Int(rf * 255) : If r8 < 0 : r8 = 0 : ElseIf r8 > 255 : r8 = 255 : EndIf
      g8 = Int(gf * 255) : If g8 < 0 : g8 = 0 : ElseIf g8 > 255 : g8 = 255 : EndIf
      b8 = Int(bf * 255) : If b8 < 0 : b8 = 0 : ElseIf b8 > 255 : b8 = 255 : EndIf
      
      ; 6. Stockage final
      *dst\pixel[i] = (alpha << 24) | (r8 << 16) | (g8 << 8) | b8
    Next
  EndWith
EndProcedure

Procedure XYZtoRGBEx(*FilterCtx.FilterParams)
  Restore XYZtoRGB_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@XYZtoRGB_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure XYZtoRGB(source, cible, mask, x_adj, y_adj, z_adj)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = x_adj
    \option[1] = y_adj
    \option[2] = z_adj
  EndWith
  XYZtoRGBEx(FilterCtx.FilterParams)
EndProcedure

; ─── Données du Filtre ───
DataSection
  XYZtoRGB_data:
  Data.s "XYZ -> RGB"
  Data.s "Décodage CIE 1931 vers affichage sRGB"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Correction X"            
  Data.i 0, 255, 127
  Data.s "Correction Y"            
  Data.i 0, 255, 127
  Data.s "Correction Z"    
  Data.i 0, 255, 127
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 57
; FirstLine = 30
; Folding = -
; EnableXP
; DPIAware