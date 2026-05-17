Procedure RGBtoYIQ_MT(*FilterCtx.FilterParams)
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
      ; RGB -> YIQ
      y  = ((0.299 * r) + (0.587 * g) + (0.114 * b)) * adjustY
      fi = ((0.596 * r) - (0.274 * g) - (0.322 * b)) * adjustI
      fq = ((0.211 * r) - (0.523 * g) + (0.312 * b)) * adjustQ
      ; YIQ -> RGB
      r2 = y + (0.956 * fi) + (0.621 * fq)
      g2 = y - (0.272 * fi) - (0.647 * fq)
      b2 = y - (1.106 * fi) + (1.703 * fq)
      ; On sature les valeurs entre 0 et 255
      Clamp_rgb(r2 , g2 , b2)
      *dst\pixel[index] = (a << 24) | (r2 << 16) | (g2 << 8) | b2
    Next
  EndWith
EndProcedure

Procedure RGBtoYIQEx(*FilterCtx.FilterParams)
  Restore RGBtoYIQ_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@RGBtoYIQ_MT()) ; <--- Correction ici
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure RGBtoYIQ(source, cible, mask, r, g, b)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = r
    \option[1] = g
    \option[2] = b
  EndWith
  RGBtoYIQEx(FilterCtx) ; <--- Correction ici
EndProcedure

DataSection
  RGBtoYIQ_data:
  Data.s "RGB to YIQ"
  Data.s "Ajuste la luminance (Y) et la chrominance (I, Q)"
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
; CursorPosition = 8
; Folding = -
; EnableXP
; DPIAware