Procedure PastelBlur_MT(*param.parametre)
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected i, j, k, x, y
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]       ; Rayon du flou
  Protected lightness = *param\option[1]    ; Éclaircissement (0-100)
  Protected saturation = *param\option[2]   ; Saturation (0-200, 100=normal)
  Protected smoothness = *param\option[3]   ; Douceur (0-100)
  
  Protected a.l, r.l, g.l, b.l
  Protected sumA.l, sumR.l, sumG.l, sumB.l
  Protected count, px, py
  Protected diameter = radius * 2 + 1
  Protected weight.f, total_weight.f
  Protected dx, dy, dist.f
  
  ; Pour la conversion HSL
  Protected h.f, s.f, l.f
  Protected min_rgb.f, max_rgb.f, delta.f
  Protected rf.f, gf.f, bf.f
  
  macro_calul_tread(ht)
  
  ; Traitement de chaque pixel
  For j = thread_start To thread_stop - 1
    For i = 0 To lg - 1
      
      sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
      total_weight = 0
      
      ; Parcours de la fenêtre de flou
      For y = -radius To radius
        py = j + y
        If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
        
        For x = -radius To radius
          px = i + x
          If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
          
          ; Calcul de la distance pour pondération gaussienne
          dx = x
          dy = y
          dist = Sqr(dx * dx + dy * dy)
          
          ; Pondération gaussienne
          weight = Exp(-(dist * dist) / (2.0 * radius * radius / 3.0))
          
          *srcPixel = *param\addr[0] + ((py * lg + px) << 2)
          getargb(*srcPixel\l, a, r, g, b)
          
          sumA + a * weight
          sumR + r * weight
          sumG + g * weight
          sumB + b * weight
          total_weight + weight
        Next
      Next
      
      ; Moyenne pondérée
      If total_weight > 0
        a = sumA / total_weight
        r = sumR / total_weight
        g = sumG / total_weight
        b = sumB / total_weight
      Else
        *srcPixel = *param\addr[0] + ((j * lg + i) << 2)
        getargb(*srcPixel\l, a, r, g, b)
      EndIf
      
      ; === Effet Pastel : Conversion RGB -> HSL -> RGB ===
      
      ; Normalisation RGB (0-255 -> 0.0-1.0)
      rf = r / 255.0
      gf = g / 255.0
      bf = b / 255.0
      
      ; Calcul HSL
      max_rgb = rf
      If gf > max_rgb : max_rgb = gf : EndIf
      If bf > max_rgb : max_rgb = bf : EndIf
      
      min_rgb = rf
      If gf < min_rgb : min_rgb = gf : EndIf
      If bf < min_rgb : min_rgb = bf : EndIf
      
      l = (max_rgb + min_rgb) / 2.0
      
      If max_rgb = min_rgb
        ; Gris (pas de saturation)
        h = 0
        s = 0
      Else
        delta = max_rgb - min_rgb
        
        ; Calcul de la saturation
        If l > 0.5
          s = delta / (2.0 - max_rgb - min_rgb)
        Else
          s = delta / (max_rgb + min_rgb)
        EndIf
        
        ; Calcul de la teinte
        If rf = max_rgb
          h = (gf - bf) / delta
          If gf < bf : h + 6.0 : EndIf
        ElseIf gf = max_rgb
          h = 2.0 + (bf - rf) / delta
        Else
          h = 4.0 + (rf - gf) / delta
        EndIf
        h * 60.0
      EndIf
      
      ; === Application de l'effet Pastel ===
      
      ; Augmentation de la luminosité (éclaircissement)
      l + (1.0 - l) * lightness / 200.0
      If l > 1.0 : l = 1.0 : EndIf
      
      ; Ajustement de la saturation
      s * saturation / 100.0
      If s > 1.0 : s = 1.0 : EndIf
      If s < 0 : s = 0 : EndIf
      
      ; Adoucissement (rapprochement vers des tons moyens)
      If smoothness > 0
        Protected target_l.f = 0.7  ; Luminosité cible pour l'effet pastel
        l + (target_l - l) * smoothness / 100.0
      EndIf
      
      ; === Conversion HSL -> RGB ===
      
      If s = 0
        ; Gris
        r = l * 255.0
        g = l * 255.0
        b = l * 255.0
      Else
        Protected q.f, p.f
        
        If l < 0.5
          q = l * (1.0 + s)
        Else
          q = l + s - l * s
        EndIf
        p = 2.0 * l - q
        
        ; Fonction de conversion de teinte
        Macro PastelBlur_HueToRGB(var,p, q, t)
          If t < 0 : t + 1.0 : EndIf
          If t > 1 : t - 1.0 : EndIf
          If t < 1.0 / 6.0
            p + (q - p) * 6.0 * t
          ElseIf t < 0.5
            var = q
          ElseIf t < 2.0 / 3.0
            var = p + (q - p) * (2.0 / 3.0 - t) * 6.0
          Else
            var = p
          EndIf
        EndMacro
        
        Protected ht1.f = h / 360.0
        PastelBlur_HueToRGB(rf, p, q, ht1 + 1.0 / 3.0)
        PastelBlur_HueToRGB(gf , p, q, ht1)
        PastelBlur_HueToRGB(bf , p, q, ht1 - 1.0 / 3.0)
        
        r = rf * 255.0
        g = gf * 255.0
        b = bf * 255.0
      EndIf
      
      ; Clamping final
      If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
      
      ; Écriture du résultat
      *dstPixel = *param\addr[1] + ((j * lg + i) << 2)
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    Next
  Next
EndProcedure

Procedure PastelBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Artistic
    *param\name = "Pastel Blur"
    *param\remarque = "Flou doux avec effet pastel artistique"
    *param\info[0] = "Rayon"          ; Rayon du flou
    *param\info[1] = "Luminosité"     ; Éclaircissement (effet pastel)
    *param\info[2] = "Saturation"     ; Saturation des couleurs
    *param\info[3] = "Douceur"        ; Douceur de l'effet
    *param\info[4] = "Contraste"      ; Réservé pour usage futur
    
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 50   : *param\info_data(0, 2) = 8
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 100  : *param\info_data(1, 2) = 40
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 200  : *param\info_data(2, 2) = 70
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 100  : *param\info_data(3, 2) = 50
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 100  : *param\info_data(4, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Validation des paramètres
  clamp(*param\option[0], 1, 50)      ; Rayon
  clamp(*param\option[1], 0, 100)     ; Luminosité
  clamp(*param\option[2], 0, 200)     ; Saturation
  clamp(*param\option[3], 0, 100)     ; Douceur
  clamp(*param\option[4], 0, 100)     ; Contraste (réservé)
  
  ; Préparation des buffers
  Filter_BufferPrepare(*param.parametre)
  
  ; Application du filtre multi-thread
  MultiThread_MT(@PastelBlur_MT(), 2)
  
  ; Finalisation
  macro_Filter_BufferFinalize(4)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 167
; FirstLine = 152
; Folding = -
; EnableXP
; DPIAware