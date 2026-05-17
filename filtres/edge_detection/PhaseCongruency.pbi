; ============================================================================
; Filtre Phase Congruency - Détection de contours invariante au contraste
; ============================================================================

Procedure PhaseCongruency_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    
    ; Paramètres indexés
    Protected nscales = \option[0]
    Protected norient = \option[1]
    Protected minWaveLength.f = \option[2]
    Protected mult.f = \option[3]
    Protected toGray = \option[4]
    
    Protected sigmaOnf.f = 0.55
    Protected k.f = 2.0
    Protected cutOff.f = 0.5
    
    If nscales < 2 : nscales = 2 : EndIf
    If nscales > 6 : nscales = 6 : EndIf
    If norient < 4 : norient = 4 : EndIf
    If norient > 8 : norient = 8 : EndIf
    
    Dim sumAn_L(lg * ht)
    Dim sumAn_H(lg * ht)
    Dim maxAn(lg * ht)
    Dim Energy(lg * ht)
    
    Protected x, y, s, o, idx
    Protected wavelength.f
    Protected orientation.f
    Protected *srcPixel.Long
    Protected r, g, b, gray, a
    Protected realResp.d, imagResp.d, amplitude.d
    Protected sumE.d, sumO.d, sumAmp.d, An.d
    Protected PC.d, energy.d
    Protected magnitude
    
    macro_calul_tread((ht - 1))
    
    For s = 0 To nscales - 1
      wavelength = minWaveLength * Pow(mult, s)
      For o = 0 To norient - 1
        orientation = o * #PI / norient
        For y = thread_start To thread_stop
          For x = 0 To lg - 1
            idx = y * lg + x
            
            *srcPixel = \addr[0] + idx * 4
            GetRGB(PeekL(*srcPixel), r, g, b)
            
            If toGray
              gray = (r * 77 + g * 150 + b * 29) >> 8
            Else
              gray = (r + g + b) / 3
            EndIf
            
            realResp = 0
            imagResp = 0
            
            If x > 0 And x < lg - 1 And y > 0 And y < ht - 1
              Protected dx.f, dy.f
              
              ; Gradient selon X - Conservation de la structure d'origine
              *srcPixel = \addr[0] + (y * lg + (x + 1)) * 4
              GetRGB(PeekL(*srcPixel), r, g, b)
              dx = (r + g + b) / 3
              
              *srcPixel = \addr[0] + (y * lg + (x - 1)) * 4
              GetRGB(PeekL(*srcPixel), r, g, b)
              dx - (r + g + b) / 3
              
              ; Gradient selon Y - Conservation de la structure d'origine
              *srcPixel = \addr[0] + ((y + 1) * lg + x) * 4
              GetRGB(PeekL(*srcPixel), r, g, b)
              dy = (r + g + b) / 3
              
              *srcPixel = \addr[0] + ((y - 1) * lg + x) * 4
              GetRGB(PeekL(*srcPixel), r, g, b)
              dy - (r + g + b) / 3
              
              realResp = dx * Cos(orientation) + dy * Sin(orientation)
              imagResp = -dx * Sin(orientation) + dy * Cos(orientation)
              
              realResp * Exp(-((wavelength - 8.0) * (wavelength - 8.0)) / 50.0)
              imagResp * Exp(-((wavelength - 8.0) * (wavelength - 8.0)) / 50.0)
            EndIf
            
            amplitude = Sqr(realResp * realResp + imagResp * imagResp)
            sumAn_L(idx) + realResp
            sumAn_H(idx) + imagResp
            Energy(idx) + amplitude
            If amplitude > maxAn(idx) : maxAn(idx) = amplitude : EndIf
          Next
        Next
      Next
    Next
    
    For y = thread_start To thread_stop
      For x = 0 To lg - 1
        idx = y * lg + x
        sumE = sumAn_L(idx)
        sumO = sumAn_H(idx)
        sumAmp = Energy(idx)
        energy = Sqr(sumE * sumE + sumO * sumO)
        An = maxAn(idx) * k
        
        If sumAmp > 0.0001
          PC = (energy - An) / sumAmp
          If PC < 0 : PC = 0 : EndIf
          If PC > 1 : PC = 1 : EndIf
        Else
          PC = 0
        EndIf
        
        If PC < cutOff : PC = 0 : EndIf
        magnitude = PC * 255
        Clamp(magnitude, 0, 255)
        
        Protected *dstPixel.Long = \addr[1] + idx * 4
        If toGray
          PokeL(*dstPixel, $FF000000 | (magnitude * $010101))
        Else
          *srcPixel = \addr[0] + idx * 4
          GetRGB(PeekL(*srcPixel), r, g, b)
          a = (PeekL(*srcPixel) >> 24) & $FF
          r = (r * magnitude) / 255
          g = (g * magnitude) / 255
          b = (b * magnitude) / 255
          Clamp_RGB(r, g, b)
          PokeL(*dstPixel, (a << 24) | (r << 16) | (g << 8) | b)
        EndIf
      Next
    Next
    
    FreeArray(sumAn_L())
    FreeArray(sumAn_H())
    FreeArray(maxAn())
    FreeArray(Energy())
  EndWith
EndProcedure

Procedure PhaseCongruencyEx(*FilterCtx.FilterParams)
  Restore PhaseCongruency_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

    Create_MultiThread_MT(@PhaseCongruency_MT())
    mask_update(*FilterCtx.FilterParams, last_data)

EndProcedure

Procedure PhaseCongruency(source, cible, mask, nscales, norient, minWaveLength, mult, toGray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = nscales
    \option[1] = norient
    \option[2] = minWaveLength
    \option[3] = mult
    \option[4] = toGray
  EndWith
  PhaseCongruencyEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  PhaseCongruency_data:
  Data.s "PhaseCongruency"
  Data.s "Détection de contours invariante au contraste (Kovesi)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Advanced
  
  Data.s "Nombre d'échelles"
  Data.i 2, 6, 4
  Data.s "Nombre d'orientations"
  Data.i 4, 8, 6
  Data.s "Longueur d'onde minimale"
  Data.i 3, 20, 6
  Data.s "Multiplicateur d'échelle"
  Data.i 15, 30, 21
  Data.s "Noir et blanc"
  Data.i 0, 1, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 40
; Folding = -
; EnableXP
; DPIAware