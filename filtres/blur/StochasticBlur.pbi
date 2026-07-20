; ---------------------------------------------------
; Stochastic Sampling Blur - Version optimisée
; Flou basé sur échantillonnage stochastique uniforme
; ---------------------------------------------------



Procedure StochasticBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.pixelarray = \addr[0]
    Protected *cible.pixelarray  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]
    Protected samples = \option[1]
    
    Protected x, y, sx, sy, i, index, value, r, g, b, a
    Protected sumA, sumR, sumG, sumB, px, py
    Protected lg_minus_1 = lg - 1
    Protected ht_minus_1 = ht - 1
    Protected diameter = radius * 2 + 1
    
    If samples < 1 : samples = 1 : EndIf
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
        
        ; Échantillonnage pseudo-aléatoire (déterministe via Mod)
        For i = 1 To samples
          sx = ((i * 37)% diameter) - radius
          sy = ((i * 59)% diameter) - radius
          px = x + sx
          py = y + sy
          
          clamp(px , 0 , lg_minus_1)
          clamp(py , 0 , ht_minus_1)
          
          getargb(*source\l[py * lg + px] , a , r , g , b)
          sumA + a
          sumR + r
          sumG + g
          SumB + b
        Next
        
        a = sumA / samples
        r = sumR / samples
        g = sumG / samples
        b = sumB / samples
        
        clamp_argb(a , r , g , b)
        
        *cible\l[(y * lg + x)] =  (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure StochasticBlurEx(*FilterCtx.FilterParams)
  Restore StochasticBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  ; Bornage des options
  If *FilterCtx\option[0] < 1 : *FilterCtx\option[0] = 1 : EndIf
  If *FilterCtx\option[1] < 5 : *FilterCtx\option[1] = 5 : EndIf
  
  Create_MultiThread_MT(@StochasticBlur_sp())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure StochasticBlur(source, cible, mask, radius, samples)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = samples 
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
; CursorPosition = 63
; FirstLine = 37
; Folding = -
; EnableXP
; DPIAware