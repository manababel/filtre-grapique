Procedure RGBtoYUV_MT(*FilterCtx.FilterParams)
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
      getargb(*src\pixel[i] , a , r , g , b)
      ; Conversion RGB → YUV
      Y = (0.299 * R + 0.587 * G + 0.114 * B) * adjustY
      U = (-0.14713 * R - 0.28886 * G + 0.436 * B) * adjustU
      V = (0.615 * R - 0.51499 * G - 0.10001 * B) * adjustV
      R2 = Y + 1.13983 * V
      G2 = Y - 0.39465 * U - 0.58060 * V
      B2 = Y + 2.03211 * U
      Clamp_rgb(R2, g2 , b2)
      *dst\pixel[i] = (a<<24) | (r2<<16) | (g2<<8) | b2
    Next
  EndWith
EndProcedure

Procedure RGB_To_YUVEx(*FilterCtx.FilterParams)

  Restore RGB_To_YUV_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@RGBtoYUV_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
  
EndProcedure

Procedure RGB_To_YUV(source , cible , mask , y , u , v)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = y
    \option[1] = u
    \option[2] = v
  EndWith
  RGB_To_YUVEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RGB_To_YUV_data:
  Data.s "RGB To YUV"
  Data.s ""
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Y-Luminance"           
  Data.i 0,255,127
  Data.s "U-Chrominance bleue"           
  Data.i 0,255,127
  Data.s "V-Chrominance rouge"   
  Data.i 0,255,127
  Data.s "XXX"
EndDataSection

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 33
; Folding = -
; EnableXP
; DPIAware