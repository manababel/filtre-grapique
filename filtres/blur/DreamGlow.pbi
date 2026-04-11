Procedure DreamGlow_MT(*param.parametre)
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected i, j, k, x, y
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]        ; Rayon du glow
  Protected intensity = *param\option[1]     ; Intensité de la lueur (0-100)
  Protected softness = *param\option[2]      ; Douceur de l'effet (0-100)
  Protected bloom = *param\option[3]         ; Effet bloom sur zones lumineuses (0-100)
  
  Protected a.l, r.l, g.l, b.l
  Protected sumA.l, sumR.l, sumG.l, sumB.l
  Protected count, px, py
  Protected diameter = radius * 2 + 1
  Protected weight.f, total_weight.f
  Protected dx, dy, dist.f
  
  ; Variables pour l'effet glow
  Protected orig_r.l, orig_g.l, orig_b.l
  Protected glow_r.f, glow_g.f, glow_b.f
  Protected luminance.f, bloom_factor.f
  Protected softness_factor.f, intensity_factor.f
  
  macro_calul_tread(ht)
  
  ; Traitement de chaque pixel
  For j = thread_start To thread_stop - 1
    For i = 0 To lg - 1
      
      ; Récupération du pixel original
      *srcPixel = *param\addr[0] + ((j * lg + i) << 2)
      getargb(*srcPixel\l, a, orig_r, orig_g, orig_b)
      
      ; === Premier passage : Flou pour créer le glow ===
      sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
      total_weight = 0
      
      For y = -radius To radius
        py = j + y
        If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
        
        For x = -radius To radius
          px = i + x
          If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
          
          dx = x
          dy = y
          dist = Sqr(dx * dx + dy * dy)
          
          ; Pondération gaussienne étendue pour effet glow
          weight = Exp(-(dist * dist) / (2.0 * radius * radius / 2.0))
          
          *srcPixel = *param\addr[0] + ((py * lg + px) << 2)
          getargb(*srcPixel\l, a, r, g, b)
          
          ; Calcul de la luminance pour bloom sélectif
          luminance = (r * 299 + g * 587 + b * 114) / 255000.0
          
          ; Amplification des zones lumineuses (bloom)
          If bloom > 0 And luminance > 0.6
            bloom_factor = 1.0 + (luminance - 0.6) * 2.5 * bloom / 100.0
            r = r * bloom_factor
            g = g * bloom_factor
            b = b * bloom_factor
            
            ; Clamping
            If r > 255 : r = 255 : EndIf
            If g > 255 : g = 255 : EndIf
            If b > 255 : b = 255 : EndIf
          EndIf
          
          sumA + a * weight
          sumR + r * weight
          sumG + g * weight
          sumB + b * weight
          total_weight + weight
        Next
      Next
      
      ; Moyenne pondérée du glow
      If total_weight > 0
        glow_r = sumR / total_weight
        glow_g = sumG / total_weight
        glow_b = sumB / total_weight
      Else
        glow_r = orig_r
        glow_g = orig_g
        glow_b = orig_b
      EndIf
      
      ; === Application de l'effet Dream Glow ===
      
      intensity_factor = intensity / 100.0
      softness_factor = softness / 100.0
      
      ; Mix entre image originale et glow
      ; Softness contrôle la préservation des détails
      Protected detail_preservation.f = 1.0 - softness_factor * 0.7
      Protected glow_blend.f = intensity_factor * (0.5 + softness_factor * 0.5)
      
      r = orig_r * detail_preservation + glow_r * glow_blend
      g = orig_g * detail_preservation + glow_g * glow_blend
      b = orig_b * detail_preservation + glow_b * glow_blend
      
      ; === Effet "Dream" : légère désaturation et éclaircissement ===
      
      ; Calcul de la luminance actuelle
      luminance = (r * 299 + g * 587 + b * 114) / 255000.0
      
      ; Désaturation douce (effet rêve éthéré)
      Protected desaturation.f = softness_factor * 0.3
      Protected gray_value.f = r * 0.299 + g * 0.587 + b * 0.114
      
      r = r * (1.0 - desaturation) + gray_value * desaturation
      g = g * (1.0 - desaturation) + gray_value * desaturation
      b = b * (1.0 - desaturation) + gray_value * desaturation
      
      ; Légère surexposition pour effet onirique
      Protected dream_lift.f = softness_factor * 0.2
      r = r + (255 - r) * dream_lift
      g = g + (255 - g) * dream_lift
      b = b + (255 - b) * dream_lift
      
      ; === Effet de halo sur les zones lumineuses ===
      If intensity > 50 And luminance > 0.5
        Protected halo_boost.f = (luminance - 0.5) * intensity_factor * 0.3
        r = r + (255 - r) * halo_boost
        g = g + (255 - g) * halo_boost
        b = b + (255 - b) * halo_boost
      EndIf
      
      ; === Adoucissement des couleurs (tons pastels) ===
      If softness > 30
        Protected pastel_factor.f = (softness - 30) / 70.0 * 0.25
        Protected white_blend.f = 255 * pastel_factor
        
        r = r * (1.0 - pastel_factor) + white_blend
        g = g * (1.0 - pastel_factor) + white_blend
        b = b * (1.0 - pastel_factor) + white_blend
      EndIf
      
      ; Clamping final
      If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
      
      ; Écriture du résultat
      *dstPixel = *param\addr[1] + ((j * lg + i) << 2)
      *dstPixel\l = (a << 24) | (Int(r) << 16) | (Int(g) << 8) | Int(b)
    Next
  Next
EndProcedure

Procedure DreamGlow(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Artistic
    *param\name = "Dream Glow"
    *param\remarque = "Effet lumineux onirique avec halos doux"
    *param\info[0] = "Rayon"          ; Rayon du glow
    *param\info[1] = "Intensité"      ; Intensité de la lueur
    *param\info[2] = "Douceur"        ; Douceur/effet rêve
    *param\info[3] = "Bloom"          ; Surbrillance zones lumineuses
    *param\info[4] = "Réservé"        ; Réservé pour usage futur
    
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 40   : *param\info_data(0, 2) = 12
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 100  : *param\info_data(1, 2) = 60
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 100  : *param\info_data(2, 2) = 70
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 100  : *param\info_data(3, 2) = 40
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 100  : *param\info_data(4, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Validation des paramètres
  clamp(*param\option[0], 1, 40)      ; Rayon
  clamp(*param\option[1], 0, 100)     ; Intensité
  clamp(*param\option[2], 0, 100)     ; Douceur
  clamp(*param\option[3], 0, 100)     ; Bloom
  clamp(*param\option[4], 0, 100)     ; Réservé
  
  ; Préparation des buffers
  Filter_BufferPrepare(*param.parametre)
  
  ; Application du filtre multi-thread
  MultiThread_MT(@DreamGlow_MT(), 2)
  
  ; Finalisation
  macro_Filter_BufferFinalize(4)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 154
; FirstLine = 120
; Folding = -
; EnableXP
; DPIAware