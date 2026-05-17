; ---------------------------------------------------
; Defocus Blur - Version optimisée
; Simulation de défocalisation par échantillonnage circulaire uniforme
; ---------------------------------------------------

Procedure DefocusBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected samples = \option[1]
    Protected x, y, i, sx, sy, index, value
    Protected sumR.f, sumG.f, sumB.f, sumA.f
    Protected a, r, g, b
    Protected angle.f, dist.f
    Protected lg_minus_1 = lg - 1, ht_minus_1 = ht - 1
    
    ; Initialisation du générateur aléatoire par thread pour la distribution
    RandomSeed((\thread_pos + 1) * 54321)
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg_minus_1
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0
        
        ; Échantillonnage circulaire (Vogel's disk ou distribution uniforme)
        For i = 0 To samples - 1
          angle = (2.0 * #PI * i) / samples
          ; Sqr(Random) pour assurer une distribution uniforme sur la surface du disque
          dist = radius * Sqr(Random(10000) / 10000.0)
          
          sx = x + Cos(angle) * dist
          sy = y + Sin(angle) * dist
          
          ; Clamping des coordonnées
          If sx < 0 : sx = 0 : ElseIf sx > lg_minus_1 : sx = lg_minus_1 : EndIf
          If sy < 0 : sy = 0 : ElseIf sy > ht_minus_1 : sy = ht_minus_1 : EndIf
          
          index = (sy * lg + sx) << 2
          value = PeekL(\addr[0] + index)
          
        a = ((value >> 24) & $FF)
        r = ((value >> 16) & $FF)
        g = ((value >> 8) & $FF)
        b = (value & $FF)
        sumA + a
        sumR + r
        sumG + g
        sumB + b
        Next
        
        ; Calcul de la moyenne et clamping final
        a = sumA / samples + 0.5
        r = sumR / samples + 0.5
        g = sumG / samples + 0.5
        b = sumB / samples + 0.5
        
        If a > 255 : a = 255 : EndIf
        If r > 255 : r = 255 : EndIf
        If g > 255 : g = 255 : EndIf
        If b > 255 : b = 255 : EndIf
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure DefocusBlurEx(*FilterCtx.FilterParams)
  Restore DefocusBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Bornage des options
    If \option[0] < 1 : \option[0] = 1 : EndIf
    If \option[1] < 4 : \option[1] = 4 : EndIf
  EndWith
  
  Create_MultiThread_MT(@DefocusBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure DefocusBlur(source, cible, mask, radius, samples)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius : \option[1] = samples
  EndWith
  DefocusBlurEx(FilterCtx)
EndProcedure

DataSection
  DefocusBlur_data:
  Data.s "Defocus Blur"
  Data.s "Flou de défocalisation circulaire via échantillonnage stochastique"
  Data.i #FilterType_Blur, #Blur_Specialized
  Data.s "Rayon"
  Data.i 1, 50, 10
  Data.s "Qualité (Samples)"
  Data.i 4, 128, 16
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 48
; FirstLine = 22
; Folding = -
; EnableXP
; DPIAware