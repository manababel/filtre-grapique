Procedure.f teinte_HUEtoRGB(p.f, q.f, t.f)
  While t < 0 : t + 360 : Wend
  While t >= 360 : t - 360 : Wend
  
  If t < 60
    ProcedureReturn p + (q - p) * t / 60
  ElseIf t < 180
    ProcedureReturn q
  ElseIf t < 240
    ProcedureReturn p + (q - p) * (240 - t) / 60
  Else
    ProcedureReturn p
  EndIf
EndProcedure

Procedure teinte_MT(*p.parametre)
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected totalPixels = lg * ht
  Protected mode = *p\option[1]
  Protected hueShift = *p\option[0]  ; 0-360 degrés
  
  ; Précalculs pour mode YUV (arithmétique fixe point)
  Protected angle.f = (#PI * hueShift) / 180
  Protected cs = Cos(angle) * 256
  Protected sn = Sin(angle) * 256
  
  Protected j, var, a, r, g, b
  Protected ry, by, y, ryy, byy, gyy
  Protected I.f, Q.f, yf.f, I2.f, Q2.f
  Protected rf.f, gf.f, bf.f, h.f, s.f, l.f
  Protected maxVal.f, minVal.f, delta.f, p.f
  
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected start = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected stop  = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  
  *srcPixel = *source + (start << 2)
  *dstPixel = *cible + (start << 2)
  
  For j = start To stop - 1
    var = *srcPixel\l
    getargb(var, a, r, g, b)
    
    Select mode
      Case 0  ; ---- YUV (optimisé entier)
        ; Conversion RGB → YUV
        y   = (30 * r + 59 * g + 11 * b) / 100
        ry  = (70 * r - 59 * g - 11 * b) / 100
        by  = (-30 * r - 59 * g + 89 * b) / 100
        
        ; Rotation de la teinte (plan UV)
        ryy = (sn * by + cs * ry) / 256
        byy = (cs * by - sn * ry) / 256
        gyy = (-51 * ryy - 19 * byy) / 100
        
        ; Conversion YUV → RGB
        r = y + ryy
        g = y + gyy
        b = y + byy
        
      Case 1  ; ---- YIQ (précision flottante)
        ; Conversion RGB → YIQ
        I = 0.596 * r - 0.274 * g - 0.322 * b
        Q = 0.211 * r - 0.523 * g + 0.312 * b
        yf = 0.299 * r + 0.587 * g + 0.114 * b
        
        ; Rotation de la teinte (plan IQ)
        I2 = I * Cos(angle) - Q * Sin(angle)
        Q2 = I * Sin(angle) + Q * Cos(angle)
        
        ; Conversion YIQ → RGB
        r = yf + 0.956 * I2 + 0.621 * Q2
        g = yf - 0.272 * I2 - 0.647 * Q2
        b = yf - 1.106 * I2 + 1.703 * Q2
        
      Case 2  ; ---- HSL (rotation pure de teinte)
        ; Normalisation RGB → [0, 1]
        rf = r / 255.0
        gf = g / 255.0
        bf = b / 255.0
        
        ; Calcul min/max
        max3(maxVal, rf, gf, bf)
        min3(minVal, rf, gf, bf)
        
        ; Lightness
        l = (maxVal + minVal) / 2.0
        delta = maxVal - minVal
        
        If delta = 0.0
          ; Gris neutre - pas de changement
          rf = l : gf = l : bf = l
        Else
          ; Calcul de la saturation
          If l < 0.5
            s = delta / (maxVal + minVal)
          Else
            s = delta / (2.0 - maxVal - minVal)
          EndIf
          
          ; Calcul de la teinte (0-360°)
          Select maxVal
            Case rf
              h = (gf - bf) / delta
              If gf < bf : h + 6.0 : EndIf
            Case gf
              h = (bf - rf) / delta + 2.0
            Case bf
              h = (rf - gf) / delta + 4.0
          EndSelect
          h * 60.0
          
          ; Application du décalage de teinte
          h + hueShift
          While h >= 360 : h - 360 : Wend
          While h < 0 : h + 360 : Wend
          
          ; Calcul de p et q pour conversion HSL → RGB
          If l < 0.5
            q = l * (1 + s)
          Else
            q = l + s - (l * s)
          EndIf
          p = 2 * l - q
          
          ; Conversion HSL → RGB
          rf = teinte_HUEtoRGB(p, q, h + 120)
          gf = teinte_HUEtoRGB(p, q, h)
          bf = teinte_HUEtoRGB(p, q, h - 120)
        EndIf
        
        ; Conversion [0, 1] → [0, 255]
        r = rf * 255
        g = gf * 255
        b = bf * 255
    EndSelect
    
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

Procedure teinte(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "teinte"
    param\remarque = "Rotation de la teinte dans différents espaces colorimétriques"
    param\info[0] = "Angle (degrés)"
    param\info[1] = "Espace couleur"
    param\info[2] = "Masque"
    param\info_data(0,0) = 0   : param\info_data(0,1) = 360 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0   : param\info_data(1,1) = 2   : param\info_data(1,2) = 0
    param\info_data(2,0) = 0   : param\info_data(2,1) = 2   : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@teinte_MT(), 1, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 33
; Folding = -
; EnableXP
; DPIAware