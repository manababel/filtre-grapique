; =================================================================
; FILTRE : RGB vers XYZ
; Description : Convertit l'espace sRGB vers l'espace de référence 
;               CIE 1931 XYZ (Illuminant D65).
; =================================================================

Procedure RGBtoXYZ_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    ; Variables de calcul
    Protected.f rf, gf, bf, X, Y, Z
    Protected.l i, alpha, r, g, b
    Protected.l x8, y8, z8
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Extraction des composantes RGB
      getargb(*src\pixel[i], alpha, r, g, b)
      
      ; 2. Normalisation [0.0 - 1.0]
      rf = r / 255.0
      gf = g / 255.0
      bf = b / 255.0
      
      ; 3. Passage en Linear RGB (Décorrélation du Gamma sRGB)
      If rf > 0.04045 : rf = Pow((rf + 0.055) / 1.055, 2.4) : Else : rf = rf / 12.92 : EndIf
      If gf > 0.04045 : gf = Pow((gf + 0.055) / 1.055, 2.4) : Else : gf = gf / 12.92 : EndIf
      If bf > 0.04045 : bf = Pow((bf + 0.055) / 1.055, 2.4) : Else : bf = bf / 12.92 : EndIf
      
      ; 4. Transformation Matricielle (Vers D65 XYZ)
      X = 0.4124564 * rf + 0.3575761 * gf + 0.1804375 * bf
      Y = 0.2126729 * rf + 0.7151522 * gf + 0.0721750 * bf
      Z = 0.0193339 * rf + 0.1191920 * gf + 0.9503041 * bf
      
      ; 5. Application des options (Ajustements directs sur les axes X, Y, Z)
      X = X + ((\option[0] - 127) / 127.0)
      Y = Y + ((\option[1] - 127) / 127.0)
      Z = Z + ((\option[2] - 127) / 127.0)
      
      ; 6. Mapping vers 8-bit pour stockage/visualisation
      ; Note : Les valeurs XYZ peuvent légèrement dépasser 1.0
      x8 = Int(X * 255) : If x8 < 0 : x8 = 0 : ElseIf x8 > 255 : x8 = 255 : EndIf
      y8 = Int(Y * 255) : If y8 < 0 : y8 = 0 : ElseIf y8 > 255 : y8 = 255 : EndIf
      z8 = Int(Z * 255) : If z8 < 0 : z8 = 0 : ElseIf z8 > 255 : z8 = 255 : EndIf
      
      *dst\pixel[i] = (alpha << 24) | (x8 << 16) | (y8 << 8) | z8
    Next
  EndWith
EndProcedure

Procedure RGBtoXYZEx(*FilterCtx.FilterParams)
  Restore RGBtoXYZ_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@RGBtoXYZ_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure RGBtoXYZ(source, cible, mask, x_adj, y_adj, z_adj)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = x_adj
    \option[1] = y_adj
    \option[2] = z_adj
  EndWith
  RGBtoXYZEx(FilterCtx.FilterParams)
EndProcedure

; ─── Données du Filtre ───
DataSection
  RGBtoXYZ_data:
  Data.s "RGB -> XYZ"
  Data.s "Espace de référence CIE 1931 (D65)"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Axe X (Mixte)"            
  Data.i 0, 255, 127
  Data.s "Axe Y (Luminance)"            
  Data.i 0, 255, 127
  Data.s "Axe Z (Bleu)"    
  Data.i 0, 255, 127
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 6
; Folding = -
; EnableXP
; DPIAware