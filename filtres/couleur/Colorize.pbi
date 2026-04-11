; ────────────────────────────────────────────────────────────────
; Procédure thread pour coloriser une image ARGB 32 bits
;
; L'option[0] contrôle l'intensité de la colorisation (0–512),
; où 128 correspond à une intensité neutre (équilibre entre couleur et gris).
;
; La colorisation est un mélange entre la couleur originale et la moyenne
; des canaux (niveau de gris), modulé par l'intensité.
; ────────────────────────────────────────────────────────────────
Procedure Colorize_MT(*p.parametre)
  Protected i, a, r, g, b, gray
  Protected intensity = *p\option[0]  ; 0-512
  Protected var.l
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  
  *srcPixel = *p\addr[0] + (startPos << 2)
  *dstPixel = *p\addr[1] + (startPos << 2)
  
  For i = startPos To endPos - 1
    var = *srcPixel\l
    getargb(var, a, r, g, b)
    
    ; Calcul du niveau de gris (poids luminance standard)
    gray = (r * 54 + g * 183 + b * 18) >> 8
    
    ; Mélange : result = (color * intensity + gray * (128 - intensity)) / 128
    ; Optimisé sans division flottante
    r = (r * intensity + gray * (128 - intensity)) >> 7  ; division par 128 = shift 7
    g = (g * intensity + gray * (128 - intensity)) >> 7
    b = (b * intensity + gray * (128 - intensity)) >> 7
    
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

; ────────────────────────────────────────────────────────────────
Procedure Colorize(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Colorize"
    param\remarque = "Ajuste l'intensité des couleurs vs niveaux de gris"
    param\info[0] = "Intensité"
    param\info[1] = "Masque"
    param\info_data(0,0) = 0   : param\info_data(0,1) = 512 : param\info_data(0,2) = 128
    param\info_data(1,0) = 0   : param\info_data(1,1) = 2   : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Colorize_MT(), 1, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 57
; Folding = -
; EnableXP
; DPIAware