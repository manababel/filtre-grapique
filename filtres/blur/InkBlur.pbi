; ============================================================================
; MACRO : Application du rendu Encre (Densité, Courbe, Dispersion, Teinte)
; ============================================================================
Macro ProcessInkPixel(r_in, g_in, b_in, density, spread, edge_m, px_i, py_j, r_out, g_out, b_out)
  ; 1. Niveaux de gris du pixel flouté
  gray_val = (r_in * 299 + g_in * 587 + b_in * 114) / 1000.0
  norm_val = gray_val / 255.0
  
  ; 2. Simulation de la fibre du papier (bruit Haute Fréquence)
  If spread > 0
    ; Micro-bruit déterministe pour simuler le grain du papier
    paper_grain = (Mod(px_i * 12.9898 + py_j * 78.233, 1.0) - 0.5) * (spread * 0.004)
    norm_val + paper_grain
  EndIf
  
  ; 3. Seuil d'absorption de l'encre (Effet "Tout ou Rien" paramétrable)
  ; Densité pousse le seuil vers le sombre
  seuil_encre = 0.5 - (density - 50) * 0.006
  
  ; Courbe Sigmoïde très raide pour marquer les accumulations d'encre
  Protected k_steep.f = 10.0 + (density * 0.1)
  norm_val = 1.0 / (1.0 + Exp(-k_steep * (norm_val - seuil_encre)))
  
  ; 4. Re-pigmentation de la couleur originale
  ; Plus la zone est sombre, plus on applique la teinte "Encre" (sombre/saturée)
  ink_density = 1.0 - norm_val
  
  rf_val = r_in * (1.0 - ink_density * 0.85)
  gf_val = g_in * (1.0 - ink_density * 0.85)
  bf_val = b_in * (1.0 - ink_density * 0.85)
  
  ; Clamping final
  If rf_val < 0.0 : r_out = 0 : ElseIf rf_val > 255.0 : r_out = 255 : Else : r_out = Int(rf_val) : EndIf
  If gf_val < 0.0 : g_out = 0 : ElseIf gf_val > 255.0 : g_out = 255 : Else : g_out = Int(gf_val) : EndIf
  If bf_val < 0.0 : b_out = 0 : ElseIf bf_val > 255.0 : b_out = 255 : Else : b_out = Int(bf_val) : EndIf
EndMacro

; ============================================================================
; PASSE 1 : Flou Horizontal (*src -> *tmp)
; ============================================================================
Procedure InkBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected flow   = \option[1]
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
; PASSE 2 : Flou Vertical + Gradient + Effet Encre (*tmp -> *dst)
; ============================================================================
Procedure InkBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius  = \option[0]
    Protected flow    = \option[1]
    Protected density = \option[2]
    Protected spread  = \option[3]
    If radius < 1 : radius = 1 : EndIf
    
    Protected i, j, dy, py, kx, ky, sx, sy
    Protected a.l, r.l, g.l, b.l
    Protected sr.l, sg.l, sb.l ; Variables temporaires pour le Sobel
    Protected sumA.f, sumR.f, sumG.f, sumB.f, total_weight.f, w.f
    Protected finalR.l, finalG.l, finalB.l
    
    ; Variables locales requises pour la macro ProcessInkPixel
    Protected gx.f, gy.f, edge_mag.f, g_val.f
    Protected gray_val.f, norm_val.f, ink_c.f, dens_f.f, sprd_f.f
    Protected disp_val.f, ink_ratio.f, rf_val.f, gf_val.f, bf_val.f
    Protected.f paper_grain , seuil_encre , ink_density
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
        
        ; 2. Magnitude du Gradient Sobel (3x3 sur tampon, utilise sr, sg, sb pour préserver r, g, b)
        gx = 0.0 : gy = 0.0
        For ky = -1 To 1
          sy = j + ky
          If sy < 0 : sy = 0 : ElseIf sy >= ht : sy = ht - 1 : EndIf
          
          For kx = -1 To 1
            sx = i + kx
            If sx < 0 : sx = 0 : ElseIf sx >= lg : sx = lg - 1 : EndIf
            
            getargb(*tmp\l[sy * lg + sx], a, sr, sg, sb)
            g_val = (sr * 299 + sg * 587 + sb * 114) / 1000.0
            
            gx + g_val * kx
            gy + g_val * ky
          Next
        Next
        edge_mag = Sqr(gx * gx + gy * gy)
        
        ; 3. Application du rendu Encre
        ProcessInkPixel(r, g, b, density, spread, edge_mag, i, j, finalR, finalG, finalB)
        
        ; 4. Écriture Pixel
        *dst\l[j * lg + i] = (a << 24) | (finalR << 16) | (finalG << 8) | finalB
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; LANCEUR PRINCIPAL ET ENVELOPPE PUBLIQUE
; ============================================================================
Procedure InkBlurEx(*FilterCtx.FilterParams)
  Restore InkBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation du tampon temporaire \addr[2]
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@InkBlur_H_MT())
      Create_MultiThread_MT(@InkBlur_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure InkBlur(source, cible, mask, rayon, fluidite, densite, etalement)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = fluidite
    \option[2] = densite
    \option[3] = etalement
  EndWith
  InkBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  InkBlur_data:
  Data.s "InkBlur"
  Data.s "Effet encre fluide avec flou directionnel"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Rayon"
  Data.i 1, 30, 5
  Data.s "Fluidité"
  Data.i 0, 100, 60
  Data.s "Densité"
  Data.i 0, 100, 50
  Data.s "Étalement"
  Data.i 0, 100, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 232
; FirstLine = 180
; Folding = -
; EnableXP
; DPIAware