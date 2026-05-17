; =================================================================
; FILTRE : RGB vers YCbCr (Norme BT.601)
; Description : Convertit l'espace RGB en Luminance (Y) et 
;               Chrominance Bleu/Rouge (Cb, Cr).
; =================================================================

Procedure RGBtoYCbCr_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    ; Variables de calcul
    Protected.f r, g, b, y, cb, cr
    Protected.l i, alpha, r_in, g_in, b_in
    Protected.l y8, cb8, cr8
    
    ; Définition de la zone de travail du thread
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Extraction des composantes ARGB
      getargb(*src\pixel[i], alpha, r_in, g_in, b_in)
      
      ; 2. Conversion en flottants
      r = r_in
      g = g_in
      b = b_in
      
      ; 3. Formules de calcul YCbCr (BT.601 numérique)
      ; Y  = 16  + 0.257R + 0.504G + 0.098B
      ; Cb = 128 - 0.148R - 0.291G + 0.439B
      ; Cr = 128 + 0.439R - 0.368G - 0.071B
      y  = 16.0  + (0.256788 * r) + (0.504129 * g) + (0.097906 * b)
      cb = 128.0 - (0.148223 * r) - (0.290993 * g) + (0.439216 * b)
      cr = 128.0 + (0.439216 * r) - (0.367788 * g) - (0.071427 * b)
      
      ; 4. Application des offsets (Options du filtre)
      ; \option[0..2] sont centrés sur 127 pour ne rien modifier par défaut
      y  + (\option[0] - 127)
      cb + (\option[1] - 127)
      cr + (\option[2] - 127)
      
      ; 5. Conversion en entiers 8 bits avec protection (Clamp)
      y8  = Int(y)  : If y8 < 0  : y8 = 0  : ElseIf y8 > 255 : y8 = 255 : EndIf
      cb8 = Int(cb) : If cb8 < 0 : cb8 = 0 : ElseIf cb8 > 255 : cb8 = 255 : EndIf
      cr8 = Int(cr) : If cr8 < 0 : cr8 = 0 : ElseIf cr8 > 255 : cr8 = 255 : EndIf
      
      ; 6. Stockage dans le buffer de destination
      ; Le canal Rouge reçoit Y, Vert reçoit Cb, Bleu reçoit Cr
      *dst\pixel[i] = (alpha << 24) | (y8 << 16) | (cb8 << 8) | cr8
    Next
  EndWith
EndProcedure

Procedure RGBtoYCbCrEx(*FilterCtx.FilterParams)
  Restore RGBtoYCbCr_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@RGBtoYCbCr_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure RGBtoYCbCr(source, cible, mask, y_adj, cb_adj, cr_adj)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = y_adj ; Luminance
    \option[1] = cb_adj ; Chroma Bleu
    \option[2] = cr_adj ; Chroma Rouge
  EndWith
  RGBtoYCbCrEx(FilterCtx.FilterParams)
EndProcedure

; ─── Données du Filtre ───
DataSection
  RGBtoYCbCr_data:
  Data.s "RGB -> YCbCr"
  Data.s "Conversion Espace Couleur Vidéo Numérique"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Y (Luminosité)"            
  Data.i 0, 255, 127
  Data.s "Cb (Bleu-Jaune)"            
  Data.i 0, 255, 127
  Data.s "Cr (Rouge-Vert)"    
  Data.i 0, 255, 127
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 62
; FirstLine = 33
; Folding = -
; EnableXP
; DPIAware