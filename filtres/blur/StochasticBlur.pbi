; ---------------------------------------------------
; Stochastic Sampling Blur - Version optimisée
; Flou basé sur échantillonnage stochastique uniforme
; ---------------------------------------------------

Macro StochasticBlur_sp1(sx, sy)
  px = x + sx
  py = y + sy
  
  If px < 0 : px = 0 : ElseIf px > lg_minus_1 : px = lg_minus_1 : EndIf
  If py < 0 : py = 0 : ElseIf py > ht_minus_1 : py = ht_minus_1 : EndIf
  
  index = (py * lg + px) << 2
  value = PeekL(*FilterCtx\addr[0] + index)
  
  sumA + ((value >> 24) & $FF)
  sumR + ((value >> 16) & $FF)
  sumG + ((value >> 8) & $FF)
  sumB + (value & $FF)
EndMacro

Procedure StochasticBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0], samples = \option[1]
    Protected x, y, sx, sy, i, index, value, r, g, b, a
    Protected sumA, sumR, sumG, sumB, px, py
    Protected lg_minus_1 = lg - 1, ht_minus_1 = ht - 1
    Protected diameter = radius * 2 + 1
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
        
        ; Échantillonnage pseudo-aléatoire (déterministe via Mod)
        For i = 1 To samples
          sx = Mod((i * 37), diameter) - radius
          sy = Mod((i * 59), diameter) - radius
          StochasticBlur_sp1(sx, sy)
        Next
        
        a = sumA / samples : r = sumR / samples
        g = sumG / samples : b = sumB / samples
        
        If a < 0 : a = 0 : ElseIf a > 255 : a = 255 : EndIf
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        
        PokeL(\addr[1] + (y * lg + x) * 4, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure StochasticBlurEx(*FilterCtx.FilterParams)
  Restore StochasticBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  ; Bornage des options
  If *FilterCtx\option[0] < 1 : *FilterCtx\option[0] = 1 : EndIf
  If *FilterCtx\option[1] < 5 : *FilterCtx\option[1] = 5 : EndIf
  
  Create_MultiThread_MT(@StochasticBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure StochasticBlur(source, cible, mask, radius, samples, mask_type)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius : \option[1] = samples : \option[2] = mask_type
  EndWith
  StochasticBlurEx(FilterCtx)
EndProcedure

DataSection
  StochasticBlur_data:
  Data.s "StochasticBlur"
  Data.s "Flou basé sur échantillonnage stochastique uniforme"
  Data.i #FilterType_Blur, #Blur_Stochastic
  Data.s "Rayon"
  Data.i 1, 50, 5
  Data.s "Échantillons"
  Data.i 5, 100, 20
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 13
; FirstLine = 2
; Folding = -
; EnableXP
; DPIAware