; ==============================================================================
; FRACTALIUS - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Fractalius_MT(*p.FilterParams)
  With *p
    ; --- Dimensions et Plage ---
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected startY = (\thread_pos * h) / \thread_max
    Protected endY   = ((\thread_pos + 1) * h) / \thread_max
    
    ; Protection bordures pour noyau 3x3
    If startY < 1 : startY = 1 : EndIf
    If endY > h - 1 : endY = h - 1 : EndIf
    
    ; --- Paramètres (0.0 à 1.0 ou +) ---
    Protected intensity.f      = \option[0] * 0.01
    Protected edgeStrength.f   = \option[1] * 0.01
    Protected glowAmount.f     = \option[2] * 0.02 ; Facteur 2 intégré
    Protected detailBoost.f    = \option[3] * 0.01
    Protected saturation.f     = \option[4] * 0.01
    Protected edgeThreshold.f  = \option[5] * 0.01
    
    ; Variables de calcul
    Protected x, y, dx, dy, pix, offset
    Protected rC, gC, bC, r, g, b
    Protected valR, valG, valB
    Protected sobelX.f, sobelY.f, edgeIntensity.f, luminance.f
    Protected sumR, sumG, sumB, count
    Protected finalR.f, finalG.f, finalB.f, lum.f
    
    ; Matrice Sobel intégrée (KernelX / KernelY)
    ; X: -1 0 1 | Y: -1 -2 -1
    ;    -2 0 2 |     0  0  0
    ;    -1 0 1 |     1  2  1

    For y = startY To endY - 1
      For x = 1 To w - 2
        
        ; 1. Lecture Pixel Central
        offset = (y * w + x) << 2
        pix = PeekL(\addr[0] + offset)
        rC = (pix >> 16) & $FF
        gC = (pix >> 8) & $FF
        bC = pix & $FF
        
        sobelX = 0.0 : sobelY = 0.0
        sumR = 0 : sumG = 0 : sumB = 0 : count = 0
        
        ; 2. Sobel + Moyenne Locale (Kernel 3x3)
        For dy = -1 To 1
          Protected lineOffset = (y + dy) * w
          For dx = -1 To 1
            pix = PeekL(\addr[0] + ((lineOffset + (x + dx)) << 2))
            valR = (pix >> 16) & $FF
            valG = (pix >> 8) & $FF
            valB = pix & $FF
            
            luminance = valR * 0.299 + valG * 0.587 + valB * 0.114
            
            ; Kernel X
            Protected kx = 0
            If dx = -1 : kx = -1 : ElseIf dx = 1 : kx = 1 : EndIf
            If dy = 0 : kx * 2 : EndIf
            sobelX + luminance * kx
            
            ; Kernel Y
            Protected ky = 0
            If dy = -1 : ky = -1 : ElseIf dy = 1 : ky = 1 : EndIf
            If dx = 0 : ky * 2 : EndIf
            sobelY + luminance * ky
            
            sumR + valR : sumG + valG : sumB + valB : count + 1
          Next
        Next
        
        ; 3. Force du contour
        edgeIntensity = Sqr(sobelX * sobelX + sobelY * sobelY) / 1000.0
        If edgeIntensity > 1.0 : edgeIntensity = 1.0 : EndIf
        
        If edgeIntensity < edgeThreshold
          edgeIntensity = 0.0
        Else
          edgeIntensity = (edgeIntensity - edgeThreshold) / (1.0 - edgeThreshold)
        EndIf
        
        ; 4. Composition (Contours + Glow + Détails)
        Protected avgR.f = sumR / count
        Protected avgG.f = sumG / count
        Protected avgB.f = sumB / count
        
        finalR = rC + (255 - rC) * edgeIntensity * edgeStrength + (avgR * edgeIntensity * glowAmount)
        finalG = gC + (255 - gC) * edgeIntensity * edgeStrength + (avgG * edgeIntensity * glowAmount)
        finalB = bC + (255 - bC) * edgeIntensity * edgeStrength + (avgB * edgeIntensity * glowAmount)
        
        ; HDR / Détails
        finalR + (finalR - avgR) * (edgeIntensity * detailBoost)
        finalG + (finalG - avgG) * (edgeIntensity * detailBoost)
        finalB + (finalB - avgB) * (edgeIntensity * detailBoost)
        
        ; 5. Saturation
        lum = finalR * 0.299 + finalG * 0.587 + finalB * 0.114
        finalR = lum + (finalR - lum) * saturation
        finalG = lum + (finalG - lum) * saturation
        finalB = lum + (finalB - lum) * saturation
        
        ; 6. Mix avec original & Clamping
        r = rC + (finalR - rC) * intensity
        g = gC + (finalG - gC) * intensity
        b = bC + (finalB - bC) * intensity
        
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        
        PokeL(\addr[1] + offset, $FF000000 | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure FractaliusEx(*FilterCtx.FilterParams)
  Restore Fractalius_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Fractalius_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Fractalius(source, cible, mask, intensity=70, edge=80, glow=40, detail=100, sat=120, thresh=20)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensity
    \option[1] = edge
    \option[2] = glow
    \option[3] = detail
    \option[4] = sat
    \option[5] = thresh
  EndWith
  FractaliusEx(FilterCtx)
EndProcedure

DataSection
  Fractalius_Data:
  Data.s "Fractalius (marche pas)"
  Data.s "Effet fractal artistique avec contours lumineux et renforcement HDR."
  Data.i #FilterType_Artistic, #Artistic_Other
  Data.s "Intensité"       : Data.i 1, 100, 70
  Data.s "Force contours"  : Data.i 1, 100, 80
  Data.s "Lumière (Glow)"  : Data.i 0, 100, 40
  Data.s "Détails"         : Data.i 0, 200, 100
  Data.s "Saturation"      : Data.i 0, 200, 120
  Data.s "Seuil contours"  : Data.i 1, 100, 20
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 150
; FirstLine = 109
; Folding = -
; EnableXP
; DPIAware