; ────────────────────────────────────────────────────────────────
; Procédure thread pour l'effet d'éclaircissement par loi quadratique
;
; Cette méthode applique un éclaircissement non-linéaire selon une fonction
; racine carrée inversée : plus un pixel est sombre, plus il est éclairci.
;
; \option[0] contrôle l'intensité (1–255). Plus il est grand, plus l'effet est fort.
; ────────────────────────────────────────────────────────────────
Procedure SquareLaw_MT(*p.parametre)
  Protected i, a, r, g, b, var
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  
  ; Récupération de la LUT précalculée
  Protected *lut = *p\addr[2]
  
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  
  *srcPixel = *p\addr[0] + (startPos << 2)
  *dstPixel = *p\addr[1] + (startPos << 2)
  
  ; Traitement pixel par pixel
  For i = startPos To endPos - 1
    var = *srcPixel\l
    getargb(var, a, r, g, b)
    
    ; Application de la LUT
    r = PeekA(*lut + r)
    g = PeekA(*lut + g)
    b = PeekA(*lut + b)
    
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

Procedure SquareLaw_Lightening(*param.parametre)
  If *param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Square Law Lightening"
    param\remarque = "Éclaircissement progressif par loi quadratique"
    *param\info[0] = "Intensité"
    *param\info[1] = "Masque"
    param\info_data(0,0) = 1   : param\info_data(0,1) = 255 : param\info_data(0,2) = 127
    param\info_data(1,0) = 0   : param\info_data(1,1) = 2   : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  
  ; Clamp de l'intensité
  Protected intensity = *param\option[0]
  Clamp(intensity, 1, 255)
  
  ; Calcul de la valeur carrée (puissance max)
  Protected sqrval = intensity * intensity
  
  ; Allocation et génération de la LUT quadratique inversée
  *param\addr[2] = AllocateMemory(256)
  
  Protected i, inv, val
  For i = 0 To 255
    inv = 255 - i
    val = sqrval - inv * inv
    If val < 0 : val = 0 : EndIf
    PokeA(*param\addr[2] + i, Int(Sqr(val)))
  Next
  
  filter_start(@SquareLaw_MT(), 1, 1)
  
  ; Libération de la mémoire
  FreeMemory(*param\addr[2])
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 67
; FirstLine = 3
; Folding = -
; EnableXP
; DPIAware