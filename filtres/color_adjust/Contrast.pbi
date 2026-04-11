
Procedure Contrast_MT(*p.parametre)
  Protected i, a, r, g, b, contrast, alpha, var
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected *mask = *p\mask
  ; Conversion du facteur utilisateur (0-255) en facteur de contraste (base 256)
  contrast = (( *p\option[0] - 128 ) * 256 ) / 128 + 256
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\source + (i << 2)
    *dstPixel = *p\cible + (i << 2)
    var = *srcPixel\l
    GetARGB(var, a, r, g, b)
    ; Appliquer le contraste autour de 128
    r = (((r - 128) * contrast) >> 8) + 128
    g = (((g - 128) * contrast) >> 8) + 128
    b = (((b - 128) * contrast) >> 8) + 128
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

Procedure Contrast(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorAdjustment
    param\name = "Contrast"
    param\remarque = ""
    param\info[0] = "Contraste"
    param\info[1] = "Masque"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 512 : param\info_data(0,2) = 255
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Contrast_MT(), 3, 1)
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 24
; Folding = -
; EnableXP
; DPIAware