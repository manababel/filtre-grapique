; =============================================================================
; FILTRE ARTISTIQUE "WATERCOLOR" POUR IMAGE ARGB 32 BITS
; =============================================================================

; -----------------------------------------------------------------------------
; PROCÉDURE THREAD : watercolor_MT
; -----------------------------------------------------------------------------
Procedure watercolor_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    ; --- Dimensions de l'image ---
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected x, y, i, j
    
    ; --- Composantes ARGB ---
    Protected a, r, g, b
    Protected rC, gC, bC, rN, gN, bN
    
    ; --- Accumulation pour moyennage ---
    Protected sumR.f, sumG.f, sumB.f
    Protected count.f
    
    ; --- Variation et texture ---
    Protected noise.f, variation.f, edge.f
    
    ; --- Saturation ---
    Protected hue.f, sat.f, val.f
    Protected minRGB.f, maxRGB.f, delta.f
    
    ; --- Pointeurs mémoire ---
    Protected *src.Pixel32, *dst.Pixel32

    ; --- Paramètres (Mutation vers \option[]) ---
    Protected diffusion.f      = \option[0] * 0.01
    Protected radius           = \option[1]
    If radius < 1 : radius = 1 : EndIf
    If radius > 10 : radius = 10 : EndIf
    
    Protected grainStrength.f  = \option[2] * 0.01
    Protected colorVariation.f = \option[3] * 0.01
    Protected edgePreserve.f   = \option[4] * 0.01
    Protected satBoost.f       = \option[5] * 0.01
    
    ; --- Calcul des segments de thread ---
    Protected border = radius + 1
    Protected totalRows = (h - border) - border
    macro_calul_tread(totalRows)
    Protected startY = thread_start + border
    Protected endY   = thread_stop + border

    For y = startY To endY - 1
      For x = border To w - border - 1
        
        ; 1. Lecture du centre
        *src = \addr[0] + ((y * w + x) << 2)
        GetARGB(*src\l, a, rC, gC, bC)
        
        ; 2. Détection de contour
        Protected grayC.f = rC * 0.299 + gC * 0.587 + bC * 0.114
        Protected edgeSum.f = 0.0
        Protected edgeCount = 0
        
        For i = -1 To 1 Step 2
          For j = -1 To 1 Step 2
            GetARGB(PeekL(\addr[0] + (((y + i) * w + (x + j)) << 2)), a, rN, gN, bN)
            Protected grayN.f = rN * 0.299 + gN * 0.587 + bN * 0.114
            edgeSum + Abs(grayC - grayN)
            edgeCount + 1
          Next
        Next
        edge = edgeSum / (edgeCount * 255.0)
        
        ; 3. Diffusion Aquarelle
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : count = 0.0
        Protected adaptiveRadius.f = radius * (1.0 - edge * edgePreserve)
        If adaptiveRadius < 1.0 : adaptiveRadius = 1.0 : EndIf
        
        Protected iRadius = Int(adaptiveRadius)
        For i = -iRadius To iRadius
          For j = -iRadius To iRadius
            Protected dist.f = Sqr(i * i + j * j)
            If dist <= adaptiveRadius
              Protected weight.f = 1.0 / (1.0 + dist * dist * 0.5)
              GetARGB(PeekL(\addr[0] + (((y + i) * w + (x + j)) << 2)), a, rN, gN, bN)
              sumR + rN * weight
              sumG + gN * weight
              sumB + bN * weight
              count + weight
            EndIf
          Next
        Next
        
        Protected avgR.f = sumR / count
        Protected avgG.f = sumG / count
        Protected avgB.f = sumB / count
        Protected blendDiffusion.f = diffusion * (1.0 - edge * edgePreserve * 0.7)
        
        r = Int(rC * (1.0 - blendDiffusion) + avgR * blendDiffusion)
        g = Int(gC * (1.0 - blendDiffusion) + avgG * blendDiffusion)
        b = Int(bC * (1.0 - blendDiffusion) + avgB * blendDiffusion)
        
        ; 4. Variation de couleur
        If colorVariation > 0.01
          Protected seed = (x * 12345 + y * 67890) & $7FFFFFFF
          Protected noiseValInt = (seed % 1000) - 500
          variation = (noiseValInt * 1.0 / 500.0) * colorVariation * 30.0
          r + Int(variation)
          g + Int(variation * 0.8)
          b + Int(variation * 1.2)
        EndIf
        
        ; 5. Boost Saturation
        If satBoost > 1.01
          minRGB = r : If g < minRGB : minRGB = g : EndIf : If b < minRGB : minRGB = b : EndIf
          maxRGB = r : If g > maxRGB : maxRGB = g : EndIf : If b > maxRGB : maxRGB = b : EndIf
          delta = maxRGB - minRGB
          val = maxRGB / 255.0
          If maxRGB > 0.0001 : sat = delta / maxRGB : Else : sat = 0.0 : EndIf
          
          If delta > 0.0001
            If maxRGB = r
              Protected h_temp.f = (g - b) / delta
              While h_temp >= 6.0 : h_temp - 6.0 : Wend
              While h_temp < 0.0 : h_temp + 6.0 : Wend
              hue = 60.0 * h_temp
            ElseIf maxRGB = g
              hue = 60.0 * (((b - r) / delta) + 2.0)
            Else
              hue = 60.0 * (((r - g) / delta) + 4.0)
            EndIf
            If hue < 0 : hue + 360.0 : EndIf
          Else
            hue = 0.0
          EndIf
          
          sat * satBoost
          If sat > 1.0 : sat = 1.0 : EndIf
          
          Protected c.f = val * sat
          Protected h_div_60.f = hue / 60.0
          Protected h_mod_2.f = h_div_60 - Int(h_div_60 / 2.0) * 2.0
          Protected x2.f = c * (1.0 - Abs(h_mod_2 - 1.0))
          Protected m.f = val - c
          Protected r1.f, g1.f, b1.f
          Protected h_sector = Int(hue / 60.0)
          If h_sector >= 6 : h_sector = 5 : EndIf : If h_sector < 0 : h_sector = 0 : EndIf
          
          Select h_sector
            Case 0 : r1 = c : g1 = x2 : b1 = 0
            Case 1 : r1 = x2 : g1 = c : b1 = 0
            Case 2 : r1 = 0 : g1 = c : b1 = x2
            Case 3 : r1 = 0 : g1 = x2 : b1 = c
            Case 4 : r1 = x2 : g1 = 0 : b1 = c
            Case 5 : r1 = c : g1 = 0 : b1 = x2
          EndSelect
          r = Int((r1 + m) * 255.0)
          g = Int((g1 + m) * 255.0)
          b = Int((b1 + m) * 255.0)
        EndIf
        
        ; 6. Grain Papier
        If grainStrength > 0.01
          Protected seed2 = ((x * 54321 + y * 98765) * 3) & $7FFFFFFF
          Protected grain2Int = (seed2 % 1000) - 500
          Protected grainEffect.f = (grain2Int * 1.0 / 500.0) * grainStrength * 40.0
          Protected brightness.f = (r + g + b) / (3.0 * 255.0)
          grainEffect * (0.5 + brightness * 0.5)
          r + Int(grainEffect) : g + Int(grainEffect) : b + Int(grainEffect)
        EndIf
        
        ; 7. Effet Eau (Éclaircissement)
        Protected luminosity.f = (r + g + b) / (3.0 * 255.0)
        If luminosity > 0.6
          Protected lightenFactor.f = (luminosity - 0.6) * 0.3
          r = Int(r + (255 - r) * lightenFactor)
          g = Int(g + (255 - g) * lightenFactor)
          b = Int(b + (255 - b) * lightenFactor)
        EndIf
        
        ; 8. Assombrissement contours
        If edge > 0.3
          Protected darkenEdge.f = (edge - 0.3) * 0.4
          r = Int(r * (1.0 - darkenEdge))
          g = Int(g * (1.0 - darkenEdge))
          b = Int(b * (1.0 - darkenEdge))
        EndIf
        
        ; 9. Clamping
        If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
        
        *dst = \addr[1] + ((y * w + x) << 2)
        *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

; -----------------------------------------------------------------------------
; PROCÉDURE D'APPEL : watercolorEx
; -----------------------------------------------------------------------------
Procedure watercolorEx(*FilterCtx.FilterParams)
  Restore watercolor_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@watercolor_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; -----------------------------------------------------------------------------
; INTERFACE SIMPLIFIÉE
; -----------------------------------------------------------------------------
Procedure watercolor(source, cible, mask, diffusion=60, radius=4, grain=40, variation=30, edgePreserve=50, satBoost=130)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = diffusion
    \option[1] = radius
    \option[2] = grain
    \option[3] = variation
    \option[4] = edgePreserve
    \option[5] = satBoost
  EndWith
  watercolorEx(FilterCtx)
EndProcedure

; -----------------------------------------------------------------------------
; DONNÉES DU FILTRE
; -----------------------------------------------------------------------------
DataSection
  watercolor_Data:
  Data.s "Aquarelle / Watercolor (marche pas)"
  Data.s "Simule un effet de peinture à l'eau avec diffusion, texture et saturation"
  Data.i #FilterType_Artistic
  Data.i #Artistic_Material
  
  Data.s "Diffusion"
  Data.i 1, 100, 60
  
  Data.s "Rayon diffusion"
  Data.i 1, 10 + 0, 4 ; Note: +0 pour forcer expression si besoin, ici simple
  
  Data.s "Grain papier"
  Data.i 0, 100, 40
  
  Data.s "Variation couleur"
  Data.i 0, 100, 30
  
  Data.s "Préserver contours"
  Data.i 0, 100, 50
  
  Data.s "Saturation (100=normal)"
  Data.i 50, 200, 130
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 236
; FirstLine = 209
; Folding = -
; EnableXP
; DPIAware