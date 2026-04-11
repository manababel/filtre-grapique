;--- Filtre de désaturation sélective par teinte (Hue)
; Convertit en niveaux de gris les pixels dont la teinte correspond à hueTarget ± tolerance
Procedure Color_hue_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected maxVal, minVal, delta, hue, deltaHue
  
  Protected hueTarget = *param\option[0]  ; 0-255
  Protected tolerance = *param\option[1]  ; 0-255
  
  Protected i, a, r, g, b, var
  Protected totalPixels = lg * ht
  Protected startPos = (*param\thread_pos * totalPixels) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * totalPixels) / *param\thread_max
  
  Protected *srcPixel.Pixel32 = *source + (startPos << 2)
  Protected *dstPixel.Pixel32 = *cible + (startPos << 2)
  
  For i = startPos To endPos - 1
    var = *srcPixel\l
    getargb(var, a, r, g, b)
    
    ; Calcul HSV/HSL - détermination de la teinte
    max3(maxVal, r, g, b)
    min3(minVal, r, g, b)
    delta = maxVal - minVal
    
    If delta <> 0  ; Pixel coloré (pas gris neutre)
      ; Calcul de la teinte (0-255)
      Select maxVal
        Case r : hue = 0   + 43 * (g - b) / delta
        Case g : hue = 85  + 43 * (b - r) / delta
        Case b : hue = 171 + 43 * (r - g) / delta
      EndSelect
      
      ; Normalisation dans [0, 255]
      While hue < 0   : hue + 256 : Wend
      While hue >= 256 : hue - 256 : Wend
      
      ; Distance circulaire entre hue et hueTarget
      deltaHue = Abs(hue - hueTarget)
      If deltaHue > 128
        deltaHue = 256 - deltaHue
      EndIf
      
      ; Si la teinte correspond, convertir en niveaux de gris
      If deltaHue <= tolerance
        Protected gray = (r * 54 + g * 183 + b * 18) >> 8
        var = (a << 24) | (gray * $010101)  ; Préserve alpha
      EndIf
    EndIf
    
    *dstPixel\l = var
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

;--- Procédure principale
Procedure Color_hue(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Color_hue"
    param\remarque = "Désature une plage de teintes spécifique"
    param\info[0] = "Teinte cible"
    param\info[1] = "Tolérance"
    param\info[2] = "Masque"
    param\info_data(0,0) = 0   : param\info_data(0,1) = 255 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0   : param\info_data(1,1) = 128 : param\info_data(1,2) = 20
    param\info_data(2,0) = 0   : param\info_data(2,1) = 2   : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Color_hue_MT(), 1, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 64
; FirstLine = 7
; Folding = -
; EnableXP
; DPIAware