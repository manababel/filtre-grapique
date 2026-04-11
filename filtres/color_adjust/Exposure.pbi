; ────────────────────────────────────────────────────────────────
; Procédure thread : Correction d'exposition d'une image ARGB 32 bits
;
; Applique une courbe d’exposition simulée (de type photographique)
; basée sur une fonction exponentielle décroissante.
;
; \option[0] = facteur d’exposition (1–255), plus la valeur est grande,
;              plus l'image est lumineuse.
;
; Caractéristiques :
; - Utilisation d'une table LUT (lookup table) pour performance
; - Compatible multithread
; - Respecte le masque alpha (si alpha < 128, le pixel est ignoré)
; ────────────────────────────────────────────────────────────────
Procedure Exposure_MT(*p.parametre)
  Protected i, a, r, g, b, alpha, var
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  ; Clamping et normalisation du facteur d’exposition
  Protected exposure.f = *p\option[0]
  Clamp(exposure, 1, 255)
  exposure * 0.1
  ; Génération de la LUT pour la transformation d'exposition
  Protected Dim tab.a(255)
  For i = 0 To 255
    Protected val.f = 255 * (1.0 - Exp(-i * exposure / 255.0))
    If val > 255 : val = 255 : EndIf
    tab(i) = Int(val)
  Next
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  ; Traitement des pixels dans la plage assignée au thread
  For i = startPos To endPos - 1
    *srcPixel = *p\source + (i << 2)
    *dstPixel = *p\cible + (i << 2)
    var = *srcPixel\l
    getargb(var, a, r, g, b)
    r = tab(r)
    g = tab(g)
    b = tab(b)
    Clamp_RGB(r, g, b)

    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
  FreeArray(tab())
EndProcedure

Procedure Exposure(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorAdjustment
    param\name = "Exposure"
    param\remarque = "Correction d’exposition (type photo)"
    param\info[0] = "Exposition"
    param\info[1] = "Masque"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 255 : param\info_data(0,2) = 15
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2 : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf

  filter_start(@Exposure_MT(), 3, 1)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 38
; FirstLine = 2
; Folding = -
; EnableXP
; DPIAware