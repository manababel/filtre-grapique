; =================================================================
; FILTRE : LCH vers LAB
; Description : Convertit les coordonnées polaires LCH 
;               en coordonnées rectangulaires LAB.
; =================================================================

Procedure LCHtoLAB_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    ; Variables de calcul
    Protected.f l_lch, c_lch, h_lch, a_lab, b_lab
    Protected.l i, alpha, l_in, c_in, h_in
    Protected.l l8, a8, b8
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Extraction des composantes LCH depuis les canaux R, G, B
      getargb(*src\pixel[i], alpha, l_in, c_in, h_in)
      
      ; 2. Remise à l'échelle réelle (Inverse du mapping précédent)
      l_lch = (l_in / 255.0) * 100.0
      c_lch = c_in / 1.5           ; On annule le facteur de sécurité de 1.5
      h_lch = (h_in / 255.0) * 360.0
      
      ; 3. Application des options (Ajustements)
      l_lch + (\option[0] - 127)
      c_lch + (\option[1] - 127)
      h_lch + (\option[2] - 127) * 2
      
      ; Sécurités et normalisation de la teinte
      If l_lch < 0 : l_lch = 0 : ElseIf l_lch > 100 : l_lch = 100 : EndIf
      If c_lch < 0 : c_lch = 0 : EndIf
      While h_lch < 0 : h_lch + 360 : Wend
      While h_lch >= 360 : h_lch - 360 : Wend
      
      ; 4. Transformation de Polaire vers Rectangulaire
      ; a = C * cos(H_rad)
      ; b = C * sin(H_rad)
      a_lab = c_lch * Cos(Radian(h_lch))
      b_lab = c_lch * Sin(Radian(h_lch))
      
      ; 5. Mapping vers 8-bit pour le buffer LAB (0-255)
      ; L (0-100) -> 0-255
      ; a et b sont centrés sur 128
      l8 = Int((l_lch / 100.0) * 255.0)
      a8 = Int(a_lab + 128.0)
      b8 = Int(b_lab + 128.0)
      
      ; Clamp final
      If l8 < 0 : l8 = 0 : ElseIf l8 > 255 : l8 = 255 : EndIf
      If a8 < 0 : a8 = 0 : ElseIf a8 > 255 : a8 = 255 : EndIf
      If b8 < 0 : b8 = 0 : ElseIf b8 > 255 : b8 = 255 : EndIf
      
      *dst\pixel[i] = (alpha << 24) | (l8 << 16) | (a8 << 8) | b8
    Next
  EndWith
EndProcedure

Procedure LCHtoLABEx(*FilterCtx.FilterParams)
  Restore LCHtoLAB_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@LCHtoLAB_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure LCHtoLAB(source, cible, mask, l_adj, c_adj, h_adj)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = l_adj
    \option[1] = c_adj
    \option[2] = h_adj
  EndWith
  LCHtoLABEx(FilterCtx.FilterParams)
EndProcedure

; ─── Données du Filtre ───
DataSection
  LCHtoLAB_data:
  Data.s "LCH -> LAB"
  Data.s "Retour aux coordonnées rectangulaires perceptuelles"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Luminance (L)"            
  Data.i 0, 255, 127
  Data.s "Chroma (C)"            
  Data.i 0, 255, 127
  Data.s "Teinte (H)"    
  Data.i 0, 255, 127
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 69
; FirstLine = 33
; Folding = -
; EnableXP
; DPIAware