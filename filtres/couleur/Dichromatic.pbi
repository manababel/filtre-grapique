

Procedure Dichromatic_MT(*p.parametre)
  Protected i, a, r, g, b
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected threshold = (*p\option[0] / 100.0) * 255
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected totalPixels = lg * ht
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  *srcPixel = *p\addr[0] + (startPos << 2)
  *dstPixel = *p\addr[1] + (startPos << 2)
  For i = startPos To endPos - 1
    getargb(*srcPixel\l , a, r , g , b)
    Protected grey = ((r * 1225 + g * 2405 + b * 466) >> 12)
    *dstPixel\l = Bool(grey >= threshold) * $FFFFFF | (a << 24)
    ;If grey < threshold
      ;*dstPixel\l = a << 24  ; Noir avec alpha
    ;Else
      ;*dstPixel\l = (a << 24) | $FFFFFF  ; Blanc avec alpha
    ;EndIf
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

; Procédure d'appel du filtre
Procedure Dichromatic(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Dichromatic"
    param\remarque = ""
    param\info[0] = "Intensité"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 25 : param\info_data(0,1) = 75 : param\info_data(0,2) = 50
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf

  filter_start(@Dichromatic_MT(), 1, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 24
; Folding = -
; EnableXP
; DPIAware