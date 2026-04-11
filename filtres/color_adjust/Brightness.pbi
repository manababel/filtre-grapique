
; ────────────────────────────────────────────────────────────────
; Procédure thread pour ajuster la luminosité RGB d'une image
Procedure Brightness_MT(*p.parametre)
  Protected i, a, r, g, b
  Protected totalPixels = *p\lg * *p\ht
  Protected sr = *p\option[0] - 255
  Protected sg = *p\option[1] - 255
  Protected sb = *p\option[2] - 255
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\source + (i << 2)
    *dstPixel = *p\cible + (i << 2)
    GetARGB(*srcPixel\l, a, r, g, b)
    r + sr
    g + sg
    b + sb
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

; ────────────────────────────────────────────────────────────────
; Procédure principale Brightness avec gestion du masque
Procedure Brightness(*param.parametre)
  ; Si l’appel est pour l’aide/info, retourne les descriptions
  If param\info_active
    param\typ = #FilterType_ColorAdjustment
    param\name = "Brightness"
    param\remarque = ""
    param\info[0] = "ajustement Rouge"
    param\info[1] = "ajustement Vert"
    param\info[2] = "ajustement Bleu"
    param\info[3] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 512 : param\info_data(0,2) = 255
    param\info_data(1,0) = 1 : param\info_data(1,1) = 512 : param\info_data(1,2) = 255
    param\info_data(2,0) = 1 : param\info_data(2,1) = 512 : param\info_data(2,2) = 255
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1  : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Balance_MT(), 3, 1)
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; Folding = -
; EnableAsm
; EnableThread
; EnableXP