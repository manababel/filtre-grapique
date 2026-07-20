; ============================================================================
; MACRO : Calcul de l'effet Charbon (Sobel + Grain + Contraste)
; Syntaxiquement valide pour PureBasic (sans typage dans les arguments)
; ============================================================================
Macro ProcessCharcoalPixel(gray_center, gx_val, gy_val, intensity, grain, contrast, px_x, py_y, out_val)
  ; 1. Magnitude du gradient Sobel
  edge_val = Sqr(gx_val * gx_val + gy_val * gy_val) / 255.0
  If edge_val > 1.0 : edge_val = 1.0 : EndIf
  
  ; 2. Inversion (charbon = sombre sur clair)
  inv_gray = 255.0 - gray_center
  
  ; 3. Mélange contours / base
  base_charcoal = inv_gray / 255.0
  edge_effect   = edge_val * intensity * 0.01
  f_val         = (base_charcoal * 0.3 + edge_effect * 0.7) * 255.0
  
  ; 4. Texture / Grain
  If grain > 0
    noise_val = Mod((px_x * 127 + py_y * 311), 100) * 0.01
    noise_val = (noise_val - 0.5) * grain * 0.5
    f_val + noise_val
  EndIf
  
  ; 5. Contraste (point pivot = 128)
  If contrast <> 50
    f_val = 128.0 + (f_val - 128.0) * (contrast * 0.02)
  EndIf
  
  ; 6. Clamping
  If f_val < 0.0
    out_val = 0
  ElseIf f_val > 255.0
    out_val = 255
  Else
    out_val = Int(f_val)
  EndIf
EndMacro

; ============================================================================
; PASSE 1 : Flou Gaussien Horizontal (*src -> *tmp)
; ============================================================================
Procedure CharcoalBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    If radius < 1 : radius = 1 : EndIf
    
    Protected i, j, dx, px, y_offset.i
    Protected a.l, r.l, g.l, b.l
    Protected sumA.f, sumR.f, sumG.f, sumB.f, total_weight.f, w.f
    
    ; LUT Gaussienne 1D
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
; PASSE 2 : Flou Gaussien Vertical + Effet Charbon (*tmp -> *dst)
; ============================================================================
Procedure CharcoalBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius    = \option[0]
    Protected intensity = \option[1]
    Protected grain     = \option[2]
    Protected contrast  = \option[3]
    If radius < 1 : radius = 1 : EndIf
    
    Protected i, j, dy, py, kx, ky, sx, sy
    Protected a.l, r.l, g.l, b.l
    Protected sumA.f, sumR.f, sumG.f, sumB.f, total_weight.f, w.f
    
    ; Variables locales pour la macro ProcessCharcoalPixel
    Protected gray_c.f, gx.f, gy.f, g_val.f
    Protected edge_val.f, inv_gray.f, base_charcoal.f, edge_effect.f
    Protected f_val.f, noise_val.f, final_val.l
    
    ; LUT Gaussienne 1D
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
        ; 1. Flou Vertical
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
        
        ; Niveau de gris du pixel central
        gray_c = (r * 299 + g * 587 + b * 114) / 1000.0
        
        ; 2. Calcul des gradients de Sobel (fenêtre 3x3 sur le tampon temporaire)
        gx = 0.0 : gy = 0.0
        For ky = -1 To 1
          sy = j + ky
          If sy < 0 : sy = 0 : ElseIf sy >= ht : sy = ht - 1 : EndIf
          
          For kx = -1 To 1
            sx = i + kx
            If sx < 0 : sx = 0 : ElseIf sx >= lg : sx = lg - 1 : EndIf
            
            getargb(*tmp\l[sy * lg + sx], a, r, g, b)
            g_val = (r * 299 + g * 587 + b * 114) / 1000.0
            
            gx + g_val * kx
            gy + g_val * ky
          Next
        Next
        
        ; 3. Application du rendu Charbon
        ProcessCharcoalPixel(gray_c, gx, gy, intensity, grain, contrast, i, j, final_val)
        
        ; 4. Écriture de la couleur monochrome résultante
        *dst\l[j * lg + i] = (a << 24) | (final_val << 16) | (final_val << 8) | final_val
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; LANCEUR PRINCIPAL ET ENVELOPPE PUBLIC
; ============================================================================
Procedure CharcoalBlurEx(*FilterCtx.FilterParams)
  Restore CharcoalBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation du tampon temporaire \addr[2]
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@CharcoalBlur_H_MT())
      Create_MultiThread_MT(@CharcoalBlur_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure


Procedure CharcoalBlur(source, cible, mask, rayon, intensite, grain, contraste)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = intensite
    \option[2] = grain
    \option[3] = contraste
  EndWith
  CharcoalBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  CharcoalBlur_data:
  Data.s "CharcoalBlur"
  Data.s "Effet dessin au charbon avec détection de contours"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Rayon"
  Data.i 1, 20, 3
  Data.s "Intensité"
  Data.i 0, 100, 70
  Data.s "Grain"
  Data.i 0, 100, 30
  Data.s "Contraste"
  Data.i 0, 100, 50
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 235
; FirstLine = 108
; Folding = -
; EnableXP
; DPIAware