Procedure RGB_YIQ_Modif_MT(*p.parametre)
  Protected *src = *p\source
  Protected *dst = *p\cible
  Protected lg = *p\lg
  Protected ht = *p\ht

  Protected adjustY.f = *p\option[0] / 127.5
  Protected adjustI.f = *p\option[1] / 127.5
  Protected adjustQ.f = *p\option[2] / 127.5
  Protected grayscaleMode = *p\option[3]

  Protected i, color
  Protected a, r, g, b
  Protected r2, g2, b2
  Protected y.f, i_.f, q.f
  Protected total = lg * ht
  Protected start = (*p\thread_pos * total) / *p\thread_max
  Protected stop  = ((*p\thread_pos + 1) * total) / *p\thread_max - 1
  If stop > total - 1 : stop = total - 1 : EndIf

  For i = start To stop
    color = PeekL(*src + i * 4)
    getargb(color, a, r, g, b)

    ; --- RGB → YIQ ---
    y = 0.299 * r + 0.587 * g + 0.114 * b
    i_ = 0.596 * r - 0.274 * g - 0.322 * b
    q = 0.211 * r - 0.523 * g + 0.312 * b

    ; --- Ajustements ---
    y * adjustY
    i_ * adjustI
    q * adjustQ

    If grayscaleMode
      r2 = y
      g2 = y
      b2 = y
    Else
      ; --- YIQ → RGB ---
      r2 = y + 0.956 * i_ + 0.621 * q
      g2 = y - 0.272 * i_ - 0.647 * q
      b2 = y - 1.106 * i_ + 1.703 * q
    EndIf

    Clamp(r2, 0, 255)
    Clamp(g2, 0, 255)
    Clamp(b2, 0, 255)

    PokeL(*dst + i * 4, (a << 24) | (r2 << 16) | (g2 << 8) | b2)
  Next
EndProcedure

Procedure RGB_YIQ_Modif(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorSpace
    param\name = "RGB → YIQ → modif → YIQ → RGB"
    param\remarque = "Conversion complète avec ajustement des composantes YIQ"
    param\info[0] = "Y (luminance)"
    param\info[1] = "I (chrominance)"
    param\info[2] = "Q (chrominance)"
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

  MultiThread_MT(@RGB_YIQ_Modif_MT())
  If *mask : *param\mask_type = *param\option[4] : MultiThread_MT(@_mask()) : EndIf

  FreeArray(tr())
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 55
; FirstLine = 19
; Folding = -
; EnableXP
; DPIAware