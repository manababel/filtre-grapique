; ----------------------------------------------------------------------------------
; Procédure thread pour l'ajustement du balance des couleurs RGB sur une image ARGB 32 bits.
;
; Cette procédure applique un facteur multiplicateur sur les canaux rouge, vert, et bleu
; (option[0], option[1], option[2] respectivement) en tenant compte d'un masque alpha
; optionnel qui peut moduler l'effet de manière progressive ou dure.
;
; Paramètres (via *p.parametre) :
; - option[0] : facteur rouge (0..255)
; - option[1] : facteur vert (0..255)
; - option[2] : facteur bleu  (0..255)
Procedure Balance_MT(*p.parametre)
  Protected i, pixel.l, a.l, r.l, g.l, b.l
  Protected factorR = *p\option[0]
  Protected factorG = *p\option[1]
  Protected factorB = *p\option[2]
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32 = *p\source
  Protected *dstPixel.Pixel32 = *p\cible
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\source + (i << 2)
    *dstPixel = *p\cible + (i << 2)
    pixel = *srcPixel\l
    GetARGB(pixel, a, r, g, b)
    r = (factorR * r) >> 8
    g = (factorG * g) >> 8
    b = (factorB * b) >> 8
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure principale pour appliquer un effet de balance RGB sur image ARGB 32 bits
Procedure Balance(*param.parametre)
  ; Mode d'information (description de l'effet)
  If param\info_active
    param\typ = #FilterType_ColorAdjustment
    param\name = "Balance"
    param\remarque = ""
    param\info[0] = "Rouge (0-255)"
    param\info[1] = "Vert (0-255)"
    param\info[2] = "Bleu (0-255)"
    param\info[3] = "Masque"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 512 : param\info_data(0,2) = 255
    param\info_data(1,0) = 1 : param\info_data(1,1) = 512 : param\info_data(1,2) = 255
    param\info_data(2,0) = 1 : param\info_data(2,1) = 512 : param\info_data(2,2) = 255
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2  : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Balance_MT(), 3, 1)

EndProcedure



; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 45
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger