; ---------------------------------------------------
; Monte Carlo Blur - Version optimisée
; Flou basé sur échantillonnage aléatoire Monte Carlo
; ---------------------------------------------------

Procedure MonteCarloBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0], samples = \option[1]
    Protected.l x, y, sx, sy, i, value, r, g, b, a
    Protected sumA, sumR, sumG, sumB, px, py
    Protected lg_minus_1 = lg - 1, ht_minus_1 = ht - 1
    Protected diameter = radius * 2 + 1
    
    Protected *src.pixelarray = \addr[0]
    Protected *dst.pixelarray = \addr[1]
    macro_calul_tread(ht)
    
    ; Initialisation du générateur aléatoire pour ce thread spécifique
    RandomSeed(thread_start + 12345)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
        
        ; Échantillonnage Monte Carlo (Aléatoire pur)
        For i = 1 To samples
          sx = Random(diameter) - radius
          sy = Random(diameter) - radius
          px = x + sx
          py = y + sy
          clamp(px , 0 , lg_minus_1)
          clamp(py , 0 , ht_minus_1)
          getargb(*src\l[py * lg + px] , a , r , g , b)
          sumA + a : sumR + r : sumG + g : sumB + b
        Next
        
        ; Calcul de la moyenne
        a = sumA / samples
        r = sumR / samples
        g = sumG / samples
        b = sumB / samples
        
        ; Clamping rapide
        clamp_argb(a , r , g , b)
        
        *dst\l[y * lg + x] = (a << 24) | (r << 16) | (g << 8) | b

      Next
    Next
  EndWith
EndProcedure

Procedure MonteCarloBlurEx(*FilterCtx.FilterParams)
  Restore MonteCarloBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  ; Bornage des options
  If *FilterCtx\option[0] < 1 : *FilterCtx\option[0] = 1 : EndIf
  If *FilterCtx\option[1] < 5 : *FilterCtx\option[1] = 5 : EndIf
  
  Create_MultiThread_MT(@MonteCarloBlur_sp())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure MonteCarloBlur(source, cible, mask, radius, samples)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = samples
  EndWith
  MonteCarloBlurEx(FilterCtx)
EndProcedure

DataSection
  MonteCarloBlur_data:
  Data.s "Monte Carlo Blur"
  Data.s "Flou granuleux basé sur un échantillonnage Monte Carlo"
  Data.i #FilterType_Blur, #Blur_Stochastic
  Data.s "Rayon"
  Data.i 1, 50, 5
  Data.s "Échantillons"
  Data.i 5, 100, 20
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 56
; FirstLine = 30
; Folding = -
; EnableXP
; DPIAware