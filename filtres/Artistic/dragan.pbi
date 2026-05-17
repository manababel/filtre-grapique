;==============================================================================
; DRAGAN EFFECT
;==============================================================================

Procedure dragan_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    ; --- Dimensions ---
    Protected w = \image_lg[0]
    Protected h = \image_ht[0] ; Correction appliquée index 0
    
    ; --- Paramètres (Conversion float) ---
    Protected intensity.f       = \option[0] * 0.01
    Protected contrast.f        = \option[1] * 0.01
    Protected clarityAmount.f   = \option[2] * 0.01
    Protected desaturation.f    = \option[3] * 0.01
    Protected skinProtection.f  = \option[4] * 0.01
    Protected grainIntensity.f  = \option[5] * 0.01
    Protected vignetteStr.f     = \option[6] * 0.01
    
    If intensity <= 0.0 : intensity = 0.01 : EndIf
    
    ; --- Variables Vignettage ---
    Protected centerX.f = w * 0.5
    Protected centerY.f = h * 0.5
    Protected maxDist.f = Sqr(centerX * centerX + centerY * centerY)
    
    ; --- Variables de calcul ---
    Protected x, y, dx, dy, r, g, b, a
    Protected rC, gC, bC, valR, valG, valB
    Protected luminance.f, newLum.f, localLum.f, sumLum.f, avgLum.f
    Protected deltaLum.f, clarity.f, skinTone.f, grain.f
    Protected *src.Pixel32, *dst.Pixel32
    
    ; --- Multithreading ---
    macro_calul_tread(h)
    Protected startY = thread_start
    Protected endY   = thread_stop - 1
    
    ; Protection bordures (kernel 3x3)
    If startY < 1 : startY = 1 : EndIf
    If endY > h - 2 : endY = h - 2 : EndIf

    For y = startY To endY
      For x = 1 To w - 2
        
        ; 1. Lecture Pixel Central
        *src = \addr[0] + ((y * w + x) << 2)
        getargb(*src\l, a, rC, gC, bC)
        luminance = rC * 0.299 + gC * 0.587 + bC * 0.114
        
        ; 2. Clarté (Micro-contraste local 3x3)
        sumLum = 0.0
        For dy = -1 To 1
          For dx = -1 To 1
            *src = \addr[0] + (((y + dy) * w + (x + dx)) << 2)
            getargb(*src\l, a, valR, valG, valB)
            sumLum + (valR * 0.299 + valG * 0.587 + valB * 0.114)
          Next
        Next
        avgLum = sumLum / 9.0
        clarity = (luminance - avgLum) * clarityAmount
        
        ; 3. Courbe de Contraste en S (Sigmoïde)
        newLum = luminance + clarity
        Protected normLum.f = newLum / 255.0
        If normLum < 0.0 : normLum = 0.0 : ElseIf normLum > 1.0 : normLum = 1.0 : EndIf
        
        Protected curved.f
        If contrast > 1.0
          Protected k.f = (contrast - 1.0) * 10.0
          curved = 1.0 / (1.0 + Exp(-k * (normLum - 0.5)))
        Else
          curved = normLum * contrast + 0.5 * (1.0 - contrast)
        EndIf
        newLum = curved * 255.0
        
        ; 4. Détection Tons Chair (HSV simplifié)
        Protected maxC.f = rC : If gC > maxC : maxC = gC : EndIf : If bC > maxC : maxC = bC : EndIf
        Protected minC.f = rC : If gC < minC : minC = gC : EndIf : If bC < minC : minC = bC : EndIf
        Protected delta.f = maxC - minC
        Protected hue.f = 0, sat.f = 0
        
        If maxC > 0.0 : sat = delta / maxC : EndIf
        If delta > 0.0
          If maxC = rC
            hue = 60.0 * ((gC - bC) / delta)
          ElseIf maxC = gC
            hue = 60.0 * (2.0 + (bC - rC) / delta)
          Else
            hue = 60.0 * (4.0 + (rC - gC) / delta)
          EndIf
          If hue < 0.0 : hue + 360.0 : EndIf
        EndIf
        
        skinTone = 0.0
        If (hue >= 0.0 And hue <= 50.0) And (sat >= 0.2 And sat <= 0.6) And (luminance > 80.0)
          skinTone = ((1.0 - (hue / 50.0)) + (1.0 - Abs(sat - 0.4) / 0.4)) * 0.5
          If skinTone > 1.0 : skinTone = 1.0 : EndIf
        EndIf
        
        ; 5. Désaturation Sélective
        Protected desatFactor.f = desaturation * (1.0 - skinTone * skinProtection)
        Protected ratio.f = 1.0
        If luminance > 0.1 : ratio = newLum / luminance : EndIf
        
        Protected nR.f = rC * ratio
        Protected nG.f = gC * ratio
        Protected nB.f = bC * ratio
        
        nR = newLum + (nR - newLum) * (1.0 - desatFactor)
        nG = newLum + (nG - newLum) * (1.0 - desatFactor)
        nB = newLum + (nB - newLum) * (1.0 - desatFactor)
        


        ; 6. Grain Argentique
        If grainIntensity > 0.0
          Protected seed.l = (x * 12345 + y * 67890) & $7FFFFFFF
          seed = (seed * 1103515245 + 12345) & $7FFFFFFF
          
          ; On décompose pour être sûr de la validité en PureBasic
          Protected modVal.l = seed % 1000
          Protected grainV.f = (modVal - 500) / 500.0
          
          Protected grainMask.f = 1.0 - Abs((newLum / 255.0) - 0.5) * 2.0
          grain = grainV * grainIntensity * grainMask * 15.0
          nR + grain : nG + grain : nB + grain
        EndIf

        
        ; 7. Vignettage
        If vignetteStr > 0.0
          Protected dist.f = Sqr(Pow(x - centerX, 2) + Pow(y - centerY, 2))
          Protected vignette.f = 1.0 - Pow(dist / maxDist, 2.0) * vignetteStr
          If vignette < 0.0 : vignette = 0.0 : EndIf
          nR * vignette : nG * vignette : nB * vignette
        EndIf
        
        ; 8. Mix Final & Clamping
        r = Int(rC + (nR - rC) * intensity)
        g = Int(gC + (nG - gC) * intensity)
        b = Int(bC + (nB - bC) * intensity)
        
        clamp_rgb(r, g, b)
        *dst = \addr[1] + ((y * w + x) << 2)
        *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure draganEx(*FilterCtx.FilterParams)
  Restore Dragan_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@dragan_MT())
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure dragan(source, cible, mask, intensity, contrast, clarity, desat, skin_prot, grain, vignette)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensity : \option[1] = contrast : \option[2] = clarity : \option[3] = desat
    \option[4] = skin_prot : \option[5] = grain : \option[6] = vignette
  EndWith
  draganEx(FilterCtx)
EndProcedure

DataSection
  Dragan_Data:
  Data.s "Dragan Effect"
  Data.s "Effet dramatique avec contraste extrême et désaturation sélective"
  Data.i #FilterType_Artistic
  Data.i #Artistic_Light
  
  Data.s "Intensité" : Data.i 1, 100, 80
  Data.s "Contraste" : Data.i 50, 200, 150
  Data.s "Clarté" : Data.i 0, 200, 120
  Data.s "Désaturation" : Data.i 0, 100, 60
  Data.s "Protection peau" : Data.i 0, 100, 70
  Data.s "Grain" : Data.i 0, 100, 30
  Data.s "Vignettage" : Data.i 0, 100, 40
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 113
; FirstLine = 86
; Folding = -
; EnableXP
; DPIAware