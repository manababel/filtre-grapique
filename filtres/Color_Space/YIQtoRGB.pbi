Procedure YIQtoRGB_MT(*FilterCtx.FilterParams)
  Protected.l a, r, g, b, r2, g2, b2, index
  Protected.f y, fi, fq, adjustY, adjustI, adjustQ
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    adjustY = \option[0] / 127.5
    adjustI = \option[1] / 127.5
    adjustQ = \option[2] / 127.5
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    For index = thread_start To thread_stop - 1
      getargb(*src\pixel[index], a, r, g, b)
      y  = r * adjustY
      fi = g * adjustI
      fq = b * adjustQ
      ; Conversion Inverse : YIQ -> RGB
      r2 = y + (0.956 * fi) + (0.621 * fq)
      g2 = y - (0.272 * fi) - (0.647 * fq)
      b2 = y - (1.106 * fi) + (1.703 * fq)
      ; Saturation des valeurs
      Clamp_rgb(r2 , g2 , b2)
      *dst\pixel[index] = (a << 24) | (r2 << 16) | (g2 << 8) | b2
    Next
  EndWith
EndProcedure

Procedure YIQtoRGBEx(*FilterCtx.FilterParams)
  Restore YIQtoRGB_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@YIQtoRGB_MT())
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure YIQtoRGB(source, cible, mask, y_adj, i_adj, q_adj)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  
  With FilterCtx
    \option[0] = y_adj
    \option[1] = i_adj
    \option[2] = q_adj
  EndWith
  
  YIQtoRGBEx(FilterCtx)
EndProcedure

DataSection
  YIQtoRGB_data:
  Data.s "YIQ to RGB"
  Data.s "Inverse la conversion YIQ vers RGB avec ajustements"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Y"
  Data.i 0, 255, 127
  Data.s "I"
  Data.i 0, 255, 127
  Data.s "Q"
  Data.i 0, 255, 127
  Data.s "XXX"
EndDataSection

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 5
; Folding = -
; EnableXP
; DPIAware