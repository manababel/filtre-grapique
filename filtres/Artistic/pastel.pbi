Procedure pastel_MT(*p.FilterParams)
  With *p
    ; --- Dimensions de l'image ---
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    
    ; --- Coordonnées ---
    Protected x, y, i, j
    
    ; --- Composantes ARGB ---
    Protected a, r, g, b
    Protected rC, gC, bC
    Protected rN, gN, bN
    
    ; --- Moyennage et diffusion ---
    Protected sumR.f, sumG.f, sumB.f
    Protected count.f
    
    ; --- Texture et grain ---
    Protected noise.f
    Protected paperNoise.f
    Protected chalkNoise.f
    
    ; --- Saturation et luminosité ---
    Protected hue.f, sat.f, val.f
    Protected minRGB.f, maxRGB.f, delta.f
    
    ; --- Pointeurs mémoire ---
    Protected *src.Pixel32
    Protected *dst.Pixel32
    
    ; ============================================================================
    ; LECTURE DES PARAMÈTRES
    ; ============================================================================
    Protected softness.f = \option[0] * 0.01
    Protected paperGrain.f = \option[1] * 0.01
    Protected desaturation.f = \option[2] * 0.01
    Protected lighten.f = \option[3] * 0.01
    
    Protected grainSize = \option[4]
    If grainSize < 1 : grainSize = 1 : EndIf
    If grainSize > 8 : grainSize = 8 : EndIf
    
    Protected paperType = \option[5]
    
    ; ============================================================================
    ; CONFIGURATION MULTITHREADING
    ; ============================================================================
    Protected startY = (\thread_pos * h) / \thread_max
    Protected endY   = ((\thread_pos + 1) * h) / \thread_max
    
    Protected border = grainSize + 2
    If startY < border : startY = border : EndIf
    If endY > h - border : endY = h - border : EndIf
    
    ; ============================================================================
    ; TRAITEMENT PRINCIPAL
    ; ============================================================================
    For y = startY To endY - 1
      For x = border To w - border - 1
        
        *src = \addr[0] + ((y * w + x) << 2)
        GetARGB(*src\l, a, rC, gC, bC)
        
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : count = 0.0
        
        Protected radius = 2 + Int(softness * 3.0)
        
        For i = -radius To radius
          For j = -radius To radius
            Protected dist.f = Sqr(i*i + j*j)
            
            If dist <= radius
              Protected weight.f = 1.0 / (1.0 + dist * dist * 0.2)
              
              *src = \addr[0] + (((y + i) * w + (x + j)) << 2)
              GetARGB(*src\l, a, rN, gN, bN)
              
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
        
        r = Int(rC * (1.0 - softness) + avgR * softness)
        g = Int(gC * (1.0 - softness) + avgG * softness)
        b = Int(bC * (1.0 - softness) + avgB * softness)
        
        If desaturation > 0.01
          minRGB = r
          If g < minRGB : minRGB = g : EndIf
          If b < minRGB : minRGB = b : EndIf
          
          maxRGB = r
          If g > maxRGB : maxRGB = g : EndIf
          If b > maxRGB : maxRGB = b : EndIf
          
          delta = maxRGB - minRGB
          val = maxRGB / 255.0
          
          If maxRGB > 0.0001
            sat = delta / maxRGB
          Else
            sat = 0.0
          EndIf
          
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
          
          sat * (1.0 - desaturation * 0.7)
          If sat < 0.0 : sat = 0.0 : EndIf
          
          Protected c.f = val * sat
          Protected h_div_60.f = hue / 60.0
          Protected h_mod_2.f = h_div_60 - Int(h_div_60 / 2.0) * 2.0
          Protected x2.f = c * (1.0 - Abs(h_mod_2 - 1.0))
          Protected m.f = val - c
          
          Protected r1.f, g1.f, b1.f
          Protected h_sector = Int(hue / 60.0)
          If h_sector >= 6 : h_sector = 5 : EndIf
          If h_sector < 0 : h_sector = 0 : EndIf
          
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
        
        If lighten > 0.01
          Protected lightenAmount.f = lighten * 0.5
          r = Int(r + (255 - r) * lightenAmount)
          g = Int(g + (255 - g) * lightenAmount)
          b = Int(b + (255 - b) * lightenAmount)
        EndIf
        
        If paperGrain > 0.01
          Protected seed1 = ((x / grainSize) * 12345 + (y / grainSize) * 67890) & $7FFFFFFF
          Protected noiseValue1 = (seed1 % 1000) - 500
          paperNoise = noiseValue1 / 500.0
          
          Protected seed2 = ((x / (grainSize * 2)) * 23456 + (y / (grainSize * 2)) * 78901) & $7FFFFFFF
          Protected noiseValue2 = (seed2 % 1000) - 500
          Protected paperNoise2.f = noiseValue2 / 500.0
          
          paperNoise = paperNoise * 0.6 + paperNoise2 * 0.4
          
          Select paperType
            Case 0
              paperNoise * 0.5
            Case 1
              paperNoise * 1.0
            Case 2
              paperNoise * 1.5
            Case 3
              Protected seed3 = (x * 34567 + y * 89012) & $7FFFFFFF
              Protected noiseValue3 = (seed3 % 1000) - 500
              Protected velvetNoise.f = noiseValue3 / 500.0
              paperNoise = paperNoise * 0.3 + velvetNoise * 0.7
              paperNoise * 0.7
          EndSelect
          
          Protected paperEffect.f = paperNoise * paperGrain * 35.0
          
          r + Int(paperEffect)
          g + Int(paperEffect)
          b + Int(paperEffect)
        EndIf
        
        Protected seed4 = (x * 45678 + y * 23456) & $7FFFFFFF
        Protected noiseValue4 = (seed4 % 1000) - 500
        chalkNoise = noiseValue4 / 500.0
        
        Protected brightness.f = (r + g + b) / (3.0 * 255.0)
        Protected chalkVariation.f = chalkNoise * 0.15 * (1.0 - brightness * 0.5) * 20.0
        
        r + Int(chalkVariation)
        g + Int(chalkVariation * 0.9)
        b + Int(chalkVariation * 1.1)
        
        Protected layerSeed = ((x / 5) * 56789 + (y / 5) * 12345) & $7FFFFFFF
        Protected layerValue = (layerSeed % 1000) - 500
        Protected layerEffect.f = layerValue / 5000.0
        
        If brightness > 0.6
          Protected overlay.f = layerEffect * 8.0
          r + Int(overlay)
          g + Int(overlay)
          b + Int(overlay)
        EndIf
        
        Protected smoothR.f = 0.0, smoothG.f = 0.0, smoothB.f = 0.0
        Protected smoothCount.f = 0.0
        
        For i = -1 To 1
          For j = -1 To 1
            If i <> 0 Or j <> 0
              *src = \addr[0] + (((y + i) * w + (x + j)) << 2)
              GetARGB(*src\l, a, rN, gN, bN)
              
              smoothR + rN
              smoothG + gN
              smoothB + bN
              smoothCount + 1.0
            EndIf
          Next
        Next
        
        smoothR / smoothCount
        smoothG / smoothCount
        smoothB / smoothCount
        
        Protected smoothBlend.f = 0.15 * softness
        r = Int(r * (1.0 - smoothBlend) + smoothR * smoothBlend)
        g = Int(g * (1.0 - smoothBlend) + smoothG * smoothBlend)
        b = Int(b * (1.0 - smoothBlend) + smoothB * smoothBlend)
        
        If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
        
        *dst = \addr[1] + ((y * w + x) << 2)
        *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
        
      Next
    Next
  EndWith
EndProcedure

Procedure pastelEx(*FilterCtx.FilterParams)
  Restore pastel_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  With *FilterCtx
    Create_MultiThread_MT(@pastel_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure pastel(source, cible, mask, softness=50, grain=60, desat=40, lighten=30, size=3, type=1)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = softness
    \option[1] = grain
    \option[2] = desat
    \option[3] = lighten
    \option[4] = size
    \option[5] = type
  EndWith
  pastelEx(FilterCtx)
EndProcedure

DataSection
  pastel_Data:
  Data.s "Pastel"
  Data.s "Simule un dessin au pastel avec texture poudreuse et couleurs douces"
  Data.i #FilterType_Artistic, #Artistic_Material
  Data.s "Douceur"       : Data.i 0, 100, 50
  Data.s "Grain papier"  : Data.i 0, 100, 60
  Data.s "Désaturation"  : Data.i 0, 100, 40
  Data.s "Éclaircissement" : Data.i 0, 100, 30
  Data.s "Taille grain"  : Data.i 1, 8, 3
  Data.s "Type papier (0=Fin/1=Moyen/2=Rugueux/3=Velours)" : Data.i 0, 3, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 294
; FirstLine = 243
; Folding = -
; EnableXP
; DPIAware