; ==============================================================================
; FILTRE CROSSHATCHING ARTISTIC EFFECT - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure crosshatching_MT(*p.FilterParams)
  With *p
    ; --- Dimensions de l'image ---
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    
    ; --- Coordonnées ---
    Protected x, y, dx, dy
    Protected i, j
    
    ; --- Composantes ARGB ---
    Protected a, r, g, b
    Protected rC, gC, bC
    Protected valR, valG, valB
    
    ; --- Luminance et analyse ---
    Protected luminance.f, avgLum.f
    Protected localLum.f, sumLum.f
    Protected minLum.f, maxLum.f
    
    ; --- Détection de contours ---
    Protected sobelX.f, sobelY.f
    Protected edgeMagnitude.f
    Protected edgeStrength.f
    
    ; --- Matrices Sobel ---
    Dim kernelX.f(2, 2)
    kernelX(0, 0) = -1 : kernelX(1, 0) = 0 : kernelX(2, 0) = 1
    kernelX(0, 1) = -2 : kernelX(1, 1) = 0 : kernelX(2, 1) = 2
    kernelX(0, 2) = -1 : kernelX(1, 2) = 0 : kernelX(2, 2) = 1
    
    Dim kernelY.f(2, 2)
    kernelY(0, 0) = -1 : kernelY(1, 0) = -2 : kernelY(2, 0) = -1
    kernelY(0, 1) =  0 : kernelY(1, 1) =  0 : kernelY(2, 1) =  0
    kernelY(0, 2) =  1 : kernelY(1, 2) =  2 : kernelY(2, 2) =  1
    
    ; --- Hachures ---
    Protected hatchValue.f
    Protected hatch0.f, hatch45.f, hatch90.f, hatch135.f
    Protected finalHatch.f
    Protected hatchIntensity.f
    
    ; --- Angles et directions ---
    Protected angle.f
    Protected distance.f
    Protected pattern.f
    
    ; --- Couleur ---
    Protected hue.f, sat.f, val.f
    Protected colorBlend.f
    
    ; --- Pointeurs mémoire ---
    Protected *src.Pixel32
    Protected *dst.Pixel32
    
    ; ============================================================================
    ; LECTURE DES PARAMÈTRES
    ; ============================================================================
    
    Protected strength.f = \option[0] * 0.01
    Protected hatchDensity.f = \option[1] * 0.1
    Protected lineThickness.f = \option[2] * 0.1
    Protected numDirections = \option[3]
    Protected hatchContrast.f = \option[4] * 0.01
    Protected colorPreserve.f = \option[5] * 0.01
    Protected edgeBoost.f = \option[6] * 0.01
    
    If strength <= 0.0 : strength = 0.01 : EndIf
    If hatchDensity < 0.1 : hatchDensity = 0.1 : EndIf
    If numDirections < 1 : numDirections = 1 : EndIf
    If numDirections > 4 : numDirections = 4 : EndIf
    
    ; ============================================================================
    ; CONFIGURATION MULTITHREADING
    ; ============================================================================
    
    Protected startY = (\thread_pos * h) / \thread_max
    Protected endY   = ((\thread_pos + 1) * h) / \thread_max
    
    Protected margin = 2
    If startY < margin : startY = margin : EndIf
    If endY > h - margin : endY = h - margin : EndIf
    
    ; Fréquences des motifs
    Protected freq0.f = hatchDensity * 2.0
    Protected freq45.f = hatchDensity * 1.414
    Protected freq90.f = hatchDensity * 2.0
    Protected freq135.f = hatchDensity * 1.414
    
    ; ============================================================================
    ; TRAITEMENT PRINCIPAL
    ; ============================================================================
    
    For y = startY To endY - 1
      For x = margin To w - margin - 1
        
        *src = \addr[0] + ((y * w + x) << 2)
        GetARGB(*src\l, a, rC, gC, bC)
        luminance = rC * 0.299 + gC * 0.587 + bC * 0.114
        
        sumLum = 0.0 : minLum = 255.0 : maxLum = 0.0
        Protected count = 0
        
        For dy = -2 To 2
          For dx = -2 To 2
            *src = \addr[0] + (((y + dy) * w + (x + dx)) << 2)
            GetARGB(*src\l, a, valR, valG, valB)
            localLum = valR * 0.299 + valG * 0.587 + valB * 0.114
            sumLum + localLum
            If localLum < minLum : minLum = localLum : EndIf
            If localLum > maxLum : maxLum = localLum : EndIf
            count + 1
          Next
        Next
        
        avgLum = sumLum / count
        
        sobelX = 0.0 : sobelY = 0.0
        For dy = -1 To 1
          For dx = -1 To 1
            *src = \addr[0] + (((y + dy) * w + (x + dx)) << 2)
            GetARGB(*src\l, a, valR, valG, valB)
            localLum = valR * 0.299 + valG * 0.587 + valB * 0.114
            sobelX + localLum * kernelX(dx + 1, dy + 1)
            sobelY + localLum * kernelY(dx + 1, dy + 1)
          Next
        Next
        
        edgeMagnitude = Sqr(sobelX * sobelX + sobelY * sobelY)
        edgeStrength = edgeMagnitude / 1000.0
        If edgeStrength > 1.0 : edgeStrength = 1.0 : EndIf
        
        Protected normLum.f = luminance / 255.0
        Protected darkness.f = 1.0 - normLum
        
        hatch0 = 0.0
        If numDirections >= 1
          pattern = Sin(y * #PI / freq0) * 0.5 + 0.5
          If pattern < lineThickness * 0.1 : hatch0 = 1.0 : EndIf
        EndIf
        
        hatch90 = 0.0
        If numDirections >= 2
          pattern = Sin(x * #PI / freq90) * 0.5 + 0.5
          If pattern < lineThickness * 0.1
            If darkness > 0.5 : hatch90 = 1.0 : EndIf
          EndIf
        EndIf
        
        hatch45 = 0.0
        If numDirections >= 3
          distance = (x + y) / Sqr(2.0)
          pattern = Sin(distance * #PI / freq45) * 0.5 + 0.5
          If pattern < lineThickness * 0.1
            If darkness > 0.66 : hatch45 = 1.0 : EndIf
          EndIf
        EndIf
        
        hatch135 = 0.0
        If numDirections >= 4
          distance = (x - y) / Sqr(2.0)
          pattern = Sin(distance * #PI / freq135) * 0.5 + 0.5
          If pattern < lineThickness * 0.1
            If darkness > 0.8 : hatch135 = 1.0 : EndIf
          EndIf
        EndIf
        
        finalHatch = hatch0
        If hatch90 > finalHatch : finalHatch = hatch90 : EndIf
        If hatch45 > finalHatch : finalHatch = hatch45 : EndIf
        If hatch135 > finalHatch : finalHatch = hatch135 : EndIf
        
        finalHatch = Pow(finalHatch, 1.0 / hatchContrast)
        hatchIntensity = darkness * finalHatch
        
        If edgeBoost > 0.0
          hatchIntensity = hatchIntensity + edgeStrength * edgeBoost * 0.3
          If hatchIntensity > 1.0 : hatchIntensity = 1.0 : EndIf
        EndIf
        
        Protected baseValue.f = 255.0 * (1.0 - hatchIntensity)
        Protected finalValue.f = baseValue * 0.7 + luminance * 0.3
        
        Protected newR.f, newG.f, newB.f
        If colorPreserve > 0.0 And luminance > 1.0
          Protected ratio.f = finalValue / luminance
          newR = rC * ratio
          newG = gC * ratio
          newB = bC * ratio
          newR = finalValue + (newR - finalValue) * colorPreserve
          newG = finalValue + (newG - finalValue) * colorPreserve
          newB = finalValue + (newB - finalValue) * colorPreserve
        Else
          newR = finalValue : newG = finalValue : newB = finalValue
        EndIf
        
        r = Int(rC + (newR - rC) * strength)
        g = Int(gC + (newG - gC) * strength)
        b = Int(bC + (newB - bC) * strength)
        
        If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
        
        *dst = \addr[1] + ((y * w + x) << 2)
        *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure crosshatchingEx(*FilterCtx.FilterParams)
  Restore crosshatching_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@crosshatching_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure crosshatching(source, cible, mask, strength=100, density=30, thick=15, dir=3, contrast=100, color=0, edges=80)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = strength
    \option[1] = density
    \option[2] = thick
    \option[3] = dir
    \option[4] = contrast
    \option[5] = color
    \option[6] = edges
  EndWith
  crosshatchingEx(FilterCtx)
EndProcedure

DataSection
  crosshatching_Data:
  Data.s "Crosshatching (marche pas)"
  Data.s "Effet de hachures croisées type dessin au crayon ou à l'encre"
  Data.i #FilterType_Artistic, #Artistic_Other
  Data.s "Intensité" : Data.i 1, 100, 100
  Data.s "Densité hachures" : Data.i 1, 100, 30
  Data.s "Épaisseur traits" : Data.i 1, 50, 15
  Data.s "Directions (1-4)" : Data.i 1, 4, 3
  Data.s "Contraste hachures" : Data.i 0, 200, 100
  Data.s "Couleur" : Data.i 0, 100, 0
  Data.s "Contours" : Data.i 0, 200, 80
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 244
; FirstLine = 204
; Folding = -
; EnableXP
; DPIAware