Procedure.f LABtoRGB_PivotXYZ(t.f)
  If t > 0.2068966 ; 6/29
    ProcedureReturn t * t * t
  Else
    ProcedureReturn (t - 16.0 / 116.0) / 7.787037
  EndIf
EndProcedure

Procedure LABtoRGB_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    ; Variables flottantes pour la précision des calculs
    Protected.f L, a, bb, X, Y, Z, rf, gf, bf, fx, fy, fz
    Protected.l i, alpha, r8, g8, b8, L_in, a_in, b_in
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Récupération des données LAB stockées en 8-bit
      ; On décompose le pixel (qui contient L, a, b au lieu de R, G, B)
      getargb(*src\pixel[i], alpha, L_in, a_in, b_in)
      
      ; 2. Dé-normalisation (8-bit -> Valeurs LAB réelles)
      L = L_in / 2.55          ; 0-255 -> 0-100
      a = a_in - 128           ; 0-255 -> -128 à 127
      bb = b_in - 128          ; 0-255 -> -128 à 127
      
      ; --- Application des options (si tu veux corriger le LAB avant retour) ---
      L = L + ((\option[0] - 127) / 2.55)
      a = a + (\option[1] - 127)
      bb = bb + (\option[2] - 127)
      
      ; 3. LAB → XYZ
      fy = (L + 16.0) / 116.0
      fx = fy + (a / 500.0)
      fz = fy - (bb / 200.0)
      
      ; Utilisation des références D65
      X = 0.95047 * LABtoRGB_PivotXYZ(fx)
      Y = 1.00000 * LABtoRGB_PivotXYZ(fy)
      Z = 1.08883 * LABtoRGB_PivotXYZ(fz)
      
      ; 4. XYZ → Linear RGB (Matrice inverse)
      rf =  3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z
      gf = -0.9692660 * X + 1.8760108 * Y + 0.0415560 * Z
      bf =  0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z
      
      ; 5. Linear RGB → sRGB (Correction Gamma inverse)
      If rf > 0.0031308 : rf = 1.055 * Pow(rf, 1.0/2.4) - 0.055 : Else : rf = 12.92 * rf : EndIf
      If gf > 0.0031308 : gf = 1.055 * Pow(gf, 1.0/2.4) - 0.055 : Else : gf = 12.92 * gf : EndIf
      If bf > 0.0031308 : bf = 1.055 * Pow(bf, 1.0/2.4) - 0.055 : Else : bf = 12.92 * bf : EndIf
      
      ; 6. Finalisation : Clipping et passage en 8-bit
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

Procedure LABtoRGBEx(*FilterCtx.FilterParams)
  Restore LABtoRGB_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@LABtoRGB_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure LABtoRGB(source , cible , mask , l , a , b)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = l
    \option[1] = a
    \option[2] = b
  EndWith
  LABtoRGBEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  LABtoRGB_data:
  Data.s "LAB -> RGB"
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
; CursorPosition = 87
; FirstLine = 51
; Folding = -
; EnableXP
; DPIAware