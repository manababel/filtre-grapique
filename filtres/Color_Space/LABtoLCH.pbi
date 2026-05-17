; =================================================================
; FILTRE : LAB vers LCH
; Description : Convertit les coordonnées rectangulaires LAB 
;               en coordonnées polaires LCH (Cylindrique).
; =================================================================

Procedure LABtoLCH_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    ; Variables de calcul
    Protected.f l_lab, a_lab, b_lab, c_lch, h_lch
    Protected.l i, alpha, l_in, a_in, b_in
    Protected.l l8, c8, h8
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Extraction des composantes LAB depuis les canaux R, G, B
      getargb(*src\pixel[i], alpha, l_in, a_in, b_in)
      
      ; 2. Remise à l'échelle réelle du LAB
      ; L: 0 à 100 | a et b: env -128 à +128
      l_lab = (l_in / 255.0) * 100.0
      a_lab = a_in - 128.0
      b_lab = b_in - 128.0
      
      ; 3. Calcul de la Chroma (C) - Distance euclidienne depuis le centre
      ; C = sqrt(a² + b²)
      c_lch = Sqr(a_lab * a_lab + b_lab * b_lab)
      
      ; 4. Calcul de la Teinte (H) - Angle en degrés
      ; H = atan2(b, a)
      h_lch = Degree(ATan2(b_lab, a_lab))
      
      ; Normalisation de l'angle entre 0 et 360°
      If h_lch < 0 : h_lch + 360.0 : EndIf
      
      ; 5. Application des options (Ajustements)
      l_lab + (\option[0] - 127)
      c_lch + (\option[1] - 127)
      h_lch + (\option[2] - 127) * 2 ; Multiplié par 2 pour couvrir plus d'angle
      
      ; Sécurités
      If l_lab < 0 : l_lab = 0 : ElseIf l_lab > 100 : l_lab = 100 : EndIf
      If c_lch < 0 : c_lch = 0 : EndIf 
      While h_lch < 0 : h_lch + 360 : Wend
      While h_lch >= 360 : h_lch - 360 : Wend
      
      ; 6. Mapping vers 8-bit pour le buffer
      ; L (0-100) -> 0-255
      ; C (0-132 env) -> 0-255 (on utilise un facteur de sécurité)
      ; H (0-360) -> 0-255
      l8 = Int((l_lab / 100.0) * 255.0)
      c8 = Int(c_lch * 1.5) ; Mise à l'échelle pour remplir le canal
      h8 = Int((h_lch / 360.0) * 255.0)
      
      ; Clamp final
      If l8 > 255 : l8 = 255 : EndIf
      If c8 > 255 : c8 = 255 : EndIf
      If h8 > 255 : h8 = 255 : EndIf
      
      *dst\pixel[i] = (alpha << 24) | (l8 << 16) | (c8 << 8) | h8
    Next
  EndWith
EndProcedure

Procedure LABtoLCHEx(*FilterCtx.FilterParams)
  Restore LABtoLCH_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@LABtoLCH_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure LABtoLCH(source, cible, mask, l_adj, c_adj, h_adj)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = l_adj
    \option[1] = c_adj
    \option[2] = h_adj
  EndWith
  LABtoLCHEx(FilterCtx.FilterParams)
EndProcedure

; ─── Données du Filtre ───
DataSection
  LABtoLCH_data:
  Data.s "LAB -> LCH"
  Data.s "Conversion vers coordonnées polaires perceptuelles"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Luminance (L)"            
  Data.i 0, 255, 127
  Data.s "Chroma (Saturation)"            
  Data.i 0, 255, 127
  Data.s "Teinte (Angle H)"    
  Data.i 0, 255, 127
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 68
; FirstLine = 42
; Folding = -
; EnableXP
; DPIAware