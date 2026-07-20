; Sub-macro inline pour la conversion de teinte HSL
Macro HueToRGB_Calc(var, p, q, t_in)
  MacroExpandedCount_t.f = t_in
  If MacroExpandedCount_t < 0.0 : MacroExpandedCount_t + 1.0 : EndIf
  If MacroExpandedCount_t > 1.0 : MacroExpandedCount_t - 1.0 : EndIf
  
  If MacroExpandedCount_t < 0.1666667
    var = p + (q - p) * 6.0 * MacroExpandedCount_t
  ElseIf MacroExpandedCount_t < 0.5
    var = q
  ElseIf MacroExpandedCount_t < 0.6666667
    var = p + (q - p) * (0.6666667 - MacroExpandedCount_t) * 6.0
  Else
    var = p
  EndIf
EndMacro

; Traitement Pixel par Pixel optimisé
Macro ProcessPastelPixel(r_in, g_in, b_in, lightness, saturation, smoothness, contrast, r_out, g_out, b_out)
  rf = r_in / 255.0
  gf = g_in / 255.0
  bf = b_in / 255.0
  
  ; Calcul des min/max
  max_rgb = rf
  If gf > max_rgb : max_rgb = gf : EndIf
  If bf > max_rgb : max_rgb = bf : EndIf
  
  min_rgb = rf
  If gf < min_rgb : min_rgb = gf : EndIf
  If bf < min_rgb : min_rgb = bf : EndIf
  
  l = (max_rgb + min_rgb) * 0.5
  delta = max_rgb - min_rgb
  
  If delta > 0.0001
    If l > 0.5
      s = delta / (2.0 - max_rgb - min_rgb)
    Else
      s = delta / (max_rgb + min_rgb)
    EndIf
    
    If rf = max_rgb
      h = (gf - bf) / delta
      If gf < bf : h + 6.0 : EndIf
    ElseIf gf = max_rgb
      h = 2.0 + (bf - rf) / delta
    Else
      h = 4.0 + (rf - gf) / delta
    EndIf
    h * 60.0
  Else
    h = 0.0
    s = 0.0
  EndIf
  
  ; --- Ajustements effet Pastel ---
  l + (1.0 - l) * lightness * 0.005
  If l > 1.0 : l = 1.0 : EndIf
  
  s * saturation * 0.01
  If s > 1.0 : s = 1.0 : ElseIf s < 0.0 : s = 0.0 : EndIf
  
  If smoothness > 0
    l + (0.7 - l) * smoothness * 0.01
  EndIf
  
  ; Contraste optionnel
  If contrast <> 0
    l = 0.5 + (l - 0.5) * ((100.0 + contrast) / 100.0)
    If l < 0.0 : l = 0.0 : ElseIf l > 1.0 : l = 1.0 : EndIf
  EndIf
  
  ; --- Conversion HSL -> RGB ---
  If s <= 0.0001
    resR = l * 255.0
    resG = l * 255.0
    resB = l * 255.0
  Else
    If l < 0.5
      q = l * (1.0 + s)
    Else
      q = l + s - l * s
    EndIf
    p = 2.0 * l - q
    
    ht1 = h / 360.0
    
    HueToRGB_Calc(resR, p, q, ht1 + 0.3333333)
    HueToRGB_Calc(resG, p, q, ht1)
    HueToRGB_Calc(resB, p, q, ht1 - 0.3333333)
    
    resR * 255.0
    resG * 255.0
    resB * 255.0
  EndIf
  
  ; Clamping
  If resR < 0.0 : resR = 0.0 : ElseIf resR > 255.0 : resR = 255.0 : EndIf
  If resG < 0.0 : resG = 0.0 : ElseIf resG > 255.0 : resG = 255.0 : EndIf
  If resB < 0.0 : resB = 0.0 : ElseIf resB > 255.0 : resB = 255.0 : EndIf
  
  r_out = Int(resR)
  g_out = Int(resG)
  b_out = Int(resB)
EndMacro

; ============================================================================
; PASSE 1 : Flou Gaussien Horizontal (*src -> *tmp)
; ============================================================================
Procedure PastelBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    If radius < 1 : radius = 1 : EndIf
    
    Protected i, j, dx, px, y_offset.i
    Protected a.l, r.l, g.l, b.l
    Protected sumA.f, sumR.f, sumG.f, sumB.f, total_weight.f, w.f
    
    ; Tableau statique local au thread pour éviter les réallocations dynamiques
    Protected Dim GaussLUT.f(radius * 2 + 1)
    Protected sigmaSq2.f = (2.0 * radius * radius) / 3.0
    For dx = -radius To radius
      GaussLUT(dx + radius) = Exp(-(dx * dx) / sigmaSq2)
    Next
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    
    macro_calul_tread(ht)
    
    For j = thread_start To thread_stop - 1
      y_offset = j * lg
      For i = 0 To lg - 1
        sumA = 0.0 : sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : total_weight = 0.0
        
        For dx = -radius To radius
          px = i + dx
          If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
          
          w = GaussLUT(dx + radius)
          getargb(*src\l[y_offset + px], a, r, g, b)
          
          sumA + a * w
          sumR + r * w
          sumG + g * w
          sumB + b * w
          total_weight + w
        Next
        
        a = sumA / total_weight
        r = sumR / total_weight
        g = sumG / total_weight
        b = sumB / total_weight
        
        *tmp\l[y_offset + i] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PASSE 2 : Flou Gaussien Vertical + Traitement Pastel (*tmp -> *dst)
; ============================================================================
Procedure PastelBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius     = \option[0]
    Protected lightness  = \option[1]
    Protected saturation = \option[2]
    Protected smoothness = \option[3]
    Protected contrast   = \option[4]
    If radius < 1 : radius = 1 : EndIf
    
    Protected i, j, dy, py
    Protected a.l, r.l, g.l, b.l
    Protected sumA.f, sumR.f, sumG.f, sumB.f, total_weight.f, w.f
    Protected finalR.l, finalG.l, finalB.l
    
    ; Variables requises pour la macro ProcessPastelPixel
    Protected rf.f, gf.f, bf.f, max_rgb.f, min_rgb.f, delta.f
    Protected l.f, h.f, s.f, p.f, q.f, ht1.f
    Protected resR.f, resG.f, resB.f, MacroExpandedCount_t.f
    
    Protected Dim GaussLUT.f(radius * 2 + 1)
    Protected sigmaSq2.f = (2.0 * radius * radius) / 3.0
    For dy = -radius To radius
      GaussLUT(dy + radius) = Exp(-(dy * dy) / sigmaSq2)
    Next
    
    Protected *tmp.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(ht)
    
    For j = thread_start To thread_stop - 1
      For i = 0 To lg - 1
        sumA = 0.0 : sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : total_weight = 0.0
        
        For dy = -radius To radius
          py = j + dy
          If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
          
          w = GaussLUT(dy + radius)
          getargb(*tmp\l[py * lg + i], a, r, g, b)
          
          sumA + a * w
          sumR + r * w
          sumG + g * w
          sumB + b * w
          total_weight + w
        Next
        
        a = sumA / total_weight
        r = sumR / total_weight
        g = sumG / total_weight
        b = sumB / total_weight
        
        ; Appel simple de la macro (sans typage ni pointeurs)
        ProcessPastelPixel(r, g, b, lightness, saturation, smoothness, contrast, finalR, finalG, finalB)
        
        *dst\l[j * lg + i] = (a << 24) | (finalR << 16) | (finalG << 8) | finalB
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; LANCEUR PRINCIPAL
; ============================================================================
Procedure PastelBlurEx(*FilterCtx.FilterParams)
  Restore PastelBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation du tampon temporaire \addr[2]
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@PastelBlur_H_MT())
      Create_MultiThread_MT(@PastelBlur_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure PastelBlur(source, cible, mask, rayon, luminosite, saturation, douceur, contraste)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = luminosite
    \option[2] = saturation
    \option[3] = douceur
    \option[4] = contraste
  EndWith
  PastelBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  PastelBlur_data:
  Data.s "PastelBlur"
  Data.s "Flou doux avec effet pastel artistique"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Rayon"
  Data.i 1, 50, 8
  Data.s "Luminosité"
  Data.i 0, 100, 40
  Data.s "Saturation"
  Data.i 0, 200, 70
  Data.s "Douceur"
  Data.i 0, 100, 50
  Data.s "Contraste"
  Data.i 0, 100, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 226
; FirstLine = 171
; Folding = --
; EnableXP
; DPIAware