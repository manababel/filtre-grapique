Procedure color_effect_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected opt = *param\option[0]
  
  Clamp(opt, 0, 3)
  
  Protected i, var, a, r, g, b, r2, g2, b2, rgb
  Protected totalPixels = lg * ht
  Protected startPos = (*param\thread_pos * totalPixels) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * totalPixels) / *param\thread_max
  
  Protected *srcPixel.Pixel32 = *source + (startPos << 2)
  Protected *dstPixel.Pixel32 = *cible + (startPos << 2)
  
  For i = startPos To endPos - 1
    var = *srcPixel\l
    getargb(var, a, r, g, b)
    
    ; Calcul des moyennes de canaux
    r2 = (g + b) >> 1
    g2 = (r + b) >> 1
    b2 = (r + g) >> 1
    
    ; Permutations de canaux selon l'option
    Select opt
      Case 0 : rgb = (b2 << 16) | (g2 << 8) | r2  ; BGR (cyan-like)
      Case 1 : rgb = (r2 << 16) | (g2 << 8) | b2  ; RGB (magenta-like)
      Case 2 : rgb = (g2 << 16) | (b2 << 8) | r2  ; GBR (yellow-like)
      Case 3 : rgb = (b2 << 16) | (r2 << 8) | g2  ; BRG (custom)
    EndSelect
    
    *dstPixel\l = (a << 24) | rgb
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

Procedure color_effect(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "color_effect"
    param\remarque = "Mélange créatif des canaux de couleur"
    param\info[0] = "Mode"
    param\info[1] = "Masque"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 3 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2 : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@color_effect_MT(), 1, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 43
; Folding = -
; EnableXP
; DPIAware