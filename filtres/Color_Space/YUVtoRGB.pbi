Procedure YUVtoRGB_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    Protected adjustY.f = \option[0] / 127.5
    Protected adjustU.f = \option[1] / 127.5
    Protected adjustV.f = \option[2] / 127.5
    Protected.l a , r ,g , b, r2 , g2 , b2 , i
    Protected.f y , u , v
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    For i = thread_start To thread_stop - 1
      getargb(*src\pixel[i], a, r, g, b)
      ; Ici on suppose que R=Y, G=U, B=V dans l'image source (stockage YUV dans RGB)
      y = r * adjustY
      u = (g - 128) * adjustU
      v = (b - 128) * adjustV 
      ; Conversion YUV → RGB (BT.601)
      r2 = y + 1.402 * v
      g2 = y - 0.344136 * u - 0.714136 * v
      b2 = y + 1.772 * u
      Clamp_rgb(r2, g2 , b2)
      *dst\pixel[i] = (a << 24) | (Int(r2) << 16) | (Int(g2) << 8) | Int(b2)
    Next
  EndWith
EndProcedure

Procedure YUVtoRGBEx(*FilterCtx.FilterParams)
  Restore YUVtoRGB_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@YUVtoRGB_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure YUVtoRGB(source , cible , mask , y , u , v )
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = y
    \option[1] = u
    \option[2] = v
  EndWith
  YUVtoRGBEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  YUVtoRGB_data:
  Data.s "YUV to RGB"
  Data.s ""
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Y"   
  Data.i 0,255,127
  Data.s "U"       
  Data.i 0,255,127
  Data.s "V" 
  Data.i 0,255,127
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 31
; Folding = -
; EnableXP
; DPIAware