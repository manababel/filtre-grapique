; ============================================================================
; MACRO : Rendu Dream Glow (Melange, Bloom, Desaturation, Surexposition, Pastel)
; Validite syntaxique PureBasic (arguments sans type)
; ============================================================================
Macro ProcessDreamGlow(origR, origG, origB, glowR, glowG, glowB, intensity, softness, r_out, g_out, b_out)
  intensity_factor = intensity * 0.01
  softness_factor  = softness * 0.01
  
  ; 1. Mix entre image originale et glow
  detail_preservation = 1.0 - softness_factor * 0.7
  glow_blend          = intensity_factor * (0.5 + softness_factor * 0.5)
  
  rf_val = origR * detail_preservation + glowR * glow_blend
  gf_val = origG * detail_preservation + glowG * glow_blend
  bf_val = origB * detail_preservation + glowB * glow_blend
  
  ; 2. Effet "Dream" : Desaturation douce
  luminance_val = (rf_val * 299.0 + gf_val * 587.0 + bf_val * 114.0) / 255000.0
  desat_val     = softness_factor * 0.3
  gray_val      = rf_val * 0.299 + gf_val * 0.587 + bf_val * 0.114
  
  rf_val = rf_val * (1.0 - desat_val) + gray_val * desat_val
  gf_val = gf_val * (1.0 - desat_val) + gray_val * desat_val
  bf_val = bf_val * (1.0 - desat_val) + gray_val * desat_val
  
  ; 3. Legere surexposition (Dream Lift)
  dream_lift = softness_factor * 0.2
  rf_val + (255.0 - rf_val) * dream_lift
  gf_val + (255.0 - gf_val) * dream_lift
  bf_val + (255.0 - bf_val) * dream_lift
  
  ; 4. Effet de halo sur les zones lumineuses
  If intensity > 50 And luminance_val > 0.5
    halo_boost = (luminance_val - 0.5) * intensity_factor * 0.3
    rf_val + (255.0 - rf_val) * halo_boost
    gf_val + (255.0 - gf_val) * halo_boost
    bf_val + (255.0 - bf_val) * halo_boost
  EndIf
  
  ; 5. Adoucissement des couleurs (Tons pastels)
  If softness > 30
    pastel_factor = (softness - 30) / 70.0 * 0.25
    white_blend   = 255.0 * pastel_factor
    
    rf_val = rf_val * (1.0 - pastel_factor) + white_blend
    gf_val = gf_val * (1.0 - pastel_factor) + white_blend
    bf_val = bf_val * (1.0 - pastel_factor) + white_blend
  EndIf
  
  ; Clamping final
  If rf_val < 0.0 : r_out = 0 : ElseIf rf_val > 255.0 : r_out = 255 : Else : r_out = Int(rf_val) : EndIf
  If gf_val < 0.0 : g_out = 0 : ElseIf gf_val > 255.0 : g_out = 255 : Else : g_out = Int(gf_val) : EndIf
  If bf_val < 0.0 : b_out = 0 : ElseIf bf_val > 255.0 : b_out = 255 : Else : b_out = Int(bf_val) : EndIf
EndMacro

; ============================================================================
; PASSE 1 : Flou Horizontal + Bloom (*src -> *tmp)
; ============================================================================
Procedure DreamGlow_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected bloom  = \option[3]
    If radius < 1 : radius = 1 : EndIf
    
    Protected i, j, dx, px, y_offset.i
    Protected a.l, r.l, g.l, b.l
    Protected sumA.f, sumR.f, sumG.f, sumB.f, total_weight.f, w.f
    Protected luminance.f, bloom_factor.f
    
    ; LUT Gaussienne 1D
    Protected Dim GaussLUT.f(radius * 2 + 1)
    Protected sigmaSq2.f = (2.0 * radius * radius) / 2.0
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
          
          ; Amplification Bloom sur les zones très lumineuses
          If bloom > 0
            luminance = (r * 299 + g * 587 + b * 114) / 255000.0
            If luminance > 0.6
              bloom_factor = 1.0 + (luminance - 0.6) * 2.5 * bloom * 0.01
              r = Int(r * bloom_factor)
              g = Int(g * bloom_factor)
              b = Int(b * bloom_factor)
              If r > 255 : r = 255 : EndIf
              If g > 255 : g = 255 : EndIf
              If b > 255 : b = 255 : EndIf
            EndIf
          EndIf
          
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
; PASSE 2 : Flou Vertical + Traitement Dream Glow (*tmp -> *dst)
; ============================================================================
Procedure DreamGlow_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius    = \option[0]
    Protected intensity = \option[1]
    Protected softness  = \option[2]
    If radius < 1 : radius = 1 : EndIf
    
    Protected i, j, dy, py, y_offset.i
    Protected a.l, r.l, g.l, b.l
    Protected origA.l, origR.l, origG.l, origB.l
    Protected sumA.f, sumR.f, sumG.f, sumB.f, total_weight.f, w.f
    Protected finalR.l, finalG.l, finalB.l
    
    ; Variables locales requises pour la macro ProcessDreamGlow
    Protected intensity_factor.f, softness_factor.f, detail_preservation.f, glow_blend.f
    Protected rf_val.f, gf_val.f, bf_val.f, luminance_val.f, desat_val.f, gray_val.f
    Protected dream_lift.f, halo_boost.f, pastel_factor.f, white_blend.f
    
    ; LUT Gaussienne 1D
    Protected Dim GaussLUT.f(radius * 2 + 1)
    Protected sigmaSq2.f = (2.0 * radius * radius) / 2.0
    For dy = -radius To radius
      GaussLUT(dy + radius) = Exp(-(dy * dy) / sigmaSq2)
    Next
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(ht)
    
    For j = thread_start To thread_stop - 1
      y_offset = j * lg
      For i = 0 To lg - 1
        ; 1. Recupération du pixel original
        getargb(*src\l[y_offset + i], origA, origR, origG, origB)
        
        ; 2. Flou Vertical
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
        
        ; 3. Application de la macro Dream Glow
        ProcessDreamGlow(origR, origG, origB, r, g, b, intensity, softness, finalR, finalG, finalB)
        
        ; 4. Ecriture Pixel dans l'image destination
        *dst\l[y_offset + i] = (origA << 24) | (finalR << 16) | (finalG << 8) | finalB
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; LANCEUR PRINCIPAL ET ENVELOPPE PUBLIQUE
; ============================================================================
Procedure DreamGlowEx(*FilterCtx.FilterParams)
  Restore DreamGlow_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  With *FilterCtx
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation du tampon temporaire \addr[2]
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@DreamGlow_H_MT())
      Create_MultiThread_MT(@DreamGlow_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure DreamGlow(source, cible, mask, rayon, intensite, douceur, bloom)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = intensite
    \option[2] = douceur
    \option[3] = bloom
  EndWith
  DreamGlowEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  DreamGlow_data:
  Data.s "DreamGlow"
  Data.s "Effet lumineux onirique avec halos doux"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Rayon"
  Data.i 1, 40, 12
  Data.s "Intensité"
  Data.i 0, 100, 60
  Data.s "Douceur"
  Data.i 0, 100, 70
  Data.s "Bloom"
  Data.i 0, 100, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 250
; FirstLine = 198
; Folding = -
; EnableXP
; DPIAware