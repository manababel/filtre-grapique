; ────────────────────────────────────────────────────────────────
; Procédure thread pour correction gamma d'une image ARGB 32 bits
;
; Gamma est fourni en option[0] × 100 (ex: 220 = gamma 2.2)
; La LUT est calculée une fois par thread (à optimiser globalement si possible)
; Le masque alpha est pris en compte (pixels ignorés si alpha < 128)
; ────────────────────────────────────────────────────────────────
Procedure Gamma_MT(*p.parametre)
  Protected i, var, a, r, g, b, alpha
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected totalPixels = lg * ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max

  For i = startPos To endPos - 1
    *srcPixel = *p\source + (i << 2)
    *dstPixel = *p\cible + (i << 2)
    getargb(*srcPixel\l , a , r ,g , b)
    r = PeekA(*p\addr[2] + r)
    g = PeekA(*p\addr[2] + g)
    b = PeekA(*p\addr[2] + b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

; Procédure principale Gamma avec gestion multithread et masque alpha
Procedure Gamma(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorAdjustment
    param\name = "Gamma"
    param\remarque = ""
    param\info[0] = "Gamma"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 255 : param\info_data(0,2) = 127
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  

  *param\addr[2] = AllocateMemory(256)
  Protected div.f , var , i
  Protected gamma_raw.f = 255 - *param\option[0]
  clamp(gamma_raw, 0, 255)
  Protected gamma_f.f = gamma_raw / 100
  ; Génération LUT gamma (partagée pour R/G/B)
  For i = 0 To 255
    div = i
    var = Pow(div / 255.0, gamma_f) * 255.0
    Clamp(var, 0, 255)
    PokeA(*param\addr[2] + i , var)
  Next

  filter_start(@Gamma_MT(), 1, 1)
  FreeMemory(*param\addr[2])

EndProcedure



; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 55
; FirstLine = 1
; Folding = -
; EnableXP
; DPIAware