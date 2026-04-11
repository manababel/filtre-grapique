Procedure RGB_YUV_Modif_MT(*p.parametre)
  Protected *src = *p\source
  Protected *dst = *p\cible
  Protected lg = *p\lg
  Protected ht = *p\ht

  Protected adjustY.f = *p\option[0] / 127.5
  Protected adjustU.f = *p\option[1] / 127.5
  Protected adjustV.f = *p\option[2] / 127.5
  Protected grayscaleMode = *p\option[3]

  Protected i, color
  Protected a, r, g, b
  Protected r2.f, g2.f, b2.f
  Protected y.f, u.f, v.f
  Protected total = lg * ht
  Protected start = (*p\thread_pos * total) / *p\thread_max
  Protected stop  = ((*p\thread_pos + 1) * total) / *p\thread_max - 1
  If stop > total - 1 : stop = total - 1 : EndIf

  For i = start To stop
    color = PeekL(*src + i * 4)
    getargb(color, a, r, g, b)

    ; --- RGB → YUV ---
    y = 0.299 * r + 0.587 * g + 0.114 * b
    u = -0.14713 * r - 0.28886 * g + 0.436 * b
    v = 0.615 * r - 0.51499 * g - 0.10001 * b

    ; --- Ajustements ---
    y * adjustY
    u * adjustU
    v * adjustV

    If grayscaleMode
      r2 = y
      g2 = y
      b2 = y
    Else
      ; --- YUV → RGB ---
      r2 = y + 1.13983 * v
      g2 = y - 0.39465 * u - 0.58060 * v
      b2 = y + 2.03211 * u
    EndIf

    Clamp(r2, 0, 255)
    Clamp(g2, 0, 255)
    Clamp(b2, 0, 255)

    PokeL(*dst + i * 4, (a << 24) | (Int(r2) << 16) | (Int(g2) << 8) | Int(b2))
  Next
EndProcedure

Procedure RGB_YUV_Modif(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorSpace
    param\name = "RGB → YUV → modif → YUV → RGB"
    param\remarque = "Conversion complète avec ajustement des composantes YUV"
    param\info[0] = "Y"
    param\info[1] = "U"
    param\info[2] = "V"
    param\info[3] = "Grayscale"
    param\info[4] = "Masque binaire"

    param\info_data(0,0) = 0   : param\info_data(0,1) = 255 : param\info_data(0,2) = 128
    param\info_data(1,0) = 0   : param\info_data(1,1) = 255 : param\info_data(1,2) = 128
    param\info_data(2,0) = 0   : param\info_data(2,1) = 255 : param\info_data(2,2) = 128
    param\info_data(3,0) = 0   : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0   : param\info_data(4,1) = 1   : param\info_data(4,2) = 0

    ProcedureReturn
  EndIf

  Protected *source = *param\source
  Protected *cible  = *param\cible
  Protected *mask   = *param\mask
  Protected i
  If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf

  Protected thread = CountCPUs(#PB_System_CPUs)
  Clamp(thread, 1, 128)
  Protected Dim tr(thread)

  MultiThread_MT(@RGB_YUV_Modif_MT())
  If *mask : *param\mask_type = *param\option[3] : MultiThread_MT(@_mask()) : EndIf

  FreeArray(tr())
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 55
; FirstLine = 19
; Folding = -
; EnableXP
; DPIAware