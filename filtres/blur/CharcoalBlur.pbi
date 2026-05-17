Procedure CharcoalBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected i, j, k, x, y
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]        ; Rayon du flou
    Protected intensity = \option[1]     ; Intensité de l'effet (0-100)
    Protected grain = \option[2]         ; Grain du charbon (0-100)
    Protected contrast = \option[3]      ; Contraste (0-100)
    
    Protected a.l, r.l, g.l, b.l
    Protected sumA.l, sumR.l, sumG.l, sumB.l
    Protected count, px, py
    Protected diameter = radius * 2 + 1
    Protected weight.f, total_weight.f
    Protected dx, dy, dist.f
    
    ; Variables pour l'effet charbon
    Protected gray.l, inverted.l
    Protected edge.f, noise.f
    Protected final_value.l
    
    macro_calul_tread(ht)
    
    ; Traitement de chaque pixel
    For j = thread_start To thread_stop - 1
      For i = 0 To lg - 1
        
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
        total_weight = 0
        
        ; Parcours de la fenêtre de flou avec détection de contours
        For y = -radius To radius
          py = j + y
          If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
          
          For x = -radius To radius
            px = i + x
            If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
            
            ; Calcul de la distance pour pondération
            dx = x
            dy = y
            dist = Sqr(dx * dx + dy * dy)
            
            ; Pondération gaussienne
            weight = Exp(-(dist * dist) / (2.0 * radius * radius / 3.0))
            
            *srcPixel = \addr[0] + ((py * lg + px) << 2)
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
          *srcPixel = \addr[0] + ((j * lg + i) << 2)
          getargb(*srcPixel\l, a, r, g, b)
        EndIf
        
        ; === Détection de contours (Sobel simplifié) ===
        Protected gx.f = 0, gy.f = 0
        Protected kernel_x, kernel_y
        
        For y = -1 To 1
          py = j + y
          If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
          
          For x = -1 To 1
            px = i + x
            If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
            
            *srcPixel = \addr[0] + ((py * lg + px) << 2)
            getargb(*srcPixel\l, a, r, g, b)
            
            ; Conversion en niveaux de gris
            gray = (r * 299 + g * 587 + b * 114) / 1000
            
            ; Noyaux de Sobel
            kernel_x = x
            kernel_y = y
            
            gx + gray * kernel_x
            gy + gray * kernel_y
          Next
        Next
        
        ; Magnitude du gradient
        edge = Sqr(gx * gx + gy * gy)
        edge / 255.0 ; Normalisation
        If edge > 1.0 : edge = 1.0 : EndIf
        
        ; === Effet Charbon ===
        
        ; Conversion en niveaux de gris du pixel actuel
        gray = (r * 299 + g * 587 + b * 114) / 1000
        
        ; Inversion des valeurs (charbon = zones sombres sur fond clair)
        inverted = 255 - gray
        
        ; Application de l'intensité et des contours
        Protected base_charcoal.f = inverted / 255.0
        Protected edge_effect.f = edge * intensity / 100.0
        
        ; Combinaison : contours forts + base inversée
        final_value = (base_charcoal * 0.3 + edge_effect * 0.7) * 255
        
        ; Ajout de grain (texture charbon)
        If grain > 0
          ; Pseudo-random noise basé sur position
          noise = Mod((i * 127 + j * 311) , 100) / 100.0
          noise = (noise - 0.5) * grain / 100.0 * 50
          final_value + noise
        EndIf
        
        ; Application du contraste
        If contrast <> 50
          Protected contrast_factor.f = (contrast / 50.0)
          final_value = 128 + (final_value - 128) * contrast_factor
        EndIf
        
        ; Clamping
        If final_value < 0 : final_value = 0 : EndIf
        If final_value > 255 : final_value = 255 : EndIf
        
        ; Résultat monochrome (noir/blanc)
        r = final_value
        g = final_value
        b = final_value
        
        ; Écriture du résultat
        *dstPixel = \addr[1] + ((j * lg + i) << 2)
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure CharcoalBlurEx(*FilterCtx.FilterParams)
  Restore CharcoalBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@CharcoalBlur_MT())
  
  mask_update(*FilterCtx , last_data)
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
  Data.s "Réservé"
  Data.i 0, 100, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 168
; FirstLine = 137
; Folding = -
; EnableXP
; DPIAware