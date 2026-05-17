; ---------------------------------------------------
; Frosted Glass Blur - Version optimisée
; Véritable effet verre dépoli : distorsion + flou local
; ---------------------------------------------------

; --- Hash rapide pseudo-aléatoire pour la distorsion
Macro FGB_random_offset(x, y, radius, seed, dx, dy)
  n = (x * 73856093) ! (y * 19349663) ! (seed * 83492791)
  n = n ! (n >> 13)
  n = n * 1274126177
  
  hi = (n >> 16) & $FFFF
  lo = n & $FFFF
  
  dx = hi - Int(hi / modv) * modv - radius
  dy = lo - Int(lo / modv) * modv - radius
EndMacro

; --- Worker Thread
Procedure FrostedGlassBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0], h = \image_ht[0]
    Protected radius = \option[0]
    Protected seed   = \option[1]
    Protected blurRadius = \option[2]
    
    Protected modv = 2 * radius + 1
    Protected w_minus_1 = w - 1, h_minus_1 = h - 1
    
    macro_calul_tread(h)
    
    Protected x, y, pos, n, hi, lo, dx, dy, cx, cy
    Protected bx, by, sx, sy, sumA, sumR, sumG, sumB, count
    Protected value, *src32.Pixel32
    
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        
        ; 1. Décalage aléatoire (distorsion du verre)
        If modv > 0
          FGB_random_offset(x, y, radius, seed, dx, dy)
          cx = x + dx : cy = y + dy
          If cx < 0 : cx = 0 : ElseIf cx > w_minus_1 : cx = w_minus_1 : EndIf
          If cy < 0 : cy = 0 : ElseIf cy > h_minus_1 : cy = h_minus_1 : EndIf
        Else
          cx = x : cy = y
        EndIf
        
        ; 2. Moyennage local (flou dépoli)
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0 : count = 0
        
        For by = -blurRadius To blurRadius
          sy = cy + by
          If sy < 0 : sy = 0 : ElseIf sy > h_minus_1 : sy = h_minus_1 : EndIf
          
          For bx = -blurRadius To blurRadius
            sx = cx + bx
            If sx < 0 : sx = 0 : ElseIf sx > w_minus_1 : sx = w_minus_1 : EndIf
            
            value = PeekL(\addr[0] + ((sy * w + sx) << 2))
            sumA + ((value >> 24) & $FF)
            sumR + ((value >> 16) & $FF)
            sumG + ((value >> 8) & $FF)
            sumB + (value & $FF)
            count + 1
          Next
        Next
        
        ; Calcul de la moyenne et écriture
        If count > 0
          value = ((sumA / count) << 24) | ((sumR / count) << 16) | ((sumG / count) << 8) | (sumB / count)
        Else
          value = PeekL(\addr[0] + ((y * w + x) << 2))
        EndIf
        
        PokeL(\addr[1] + ((y * w + x) << 2), value)
      Next
    Next
  EndWith
EndProcedure

; --- Procédure Ex
Procedure FrostedGlassBlurEx(*FilterCtx.FilterParams)
  Restore FrostedGlassBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  ; Bornage spécifique
  If *FilterCtx\option[0] < 0 : *FilterCtx\option[0] = 0 : EndIf
  If *FilterCtx\option[2] < 0 : *FilterCtx\option[2] = 0 : EndIf
  
  Create_MultiThread_MT(@FrostedGlassBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

; --- Appel simplifié
Procedure FrostedGlassBlur(source, cible, mask, radius, seed, blurRadius)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius : \option[1] = seed : \option[2] = blurRadius
  EndWith
  FrostedGlassBlurEx(FilterCtx)
EndProcedure

DataSection
  FrostedGlassBlur_data:
  Data.s "Frosted Glass Blur"
  Data.s "Effet verre dépoli combinant distorsion aléatoire et flou local"
  Data.i #FilterType_Blur, #Blur_Stochastic
  Data.s "Distorsion (px)"
  Data.i 0, 50, 10
  Data.s "Graine (Seed)"
  Data.i 0, 9999, 1234
  Data.s "Rayon flou"
  Data.i 0, 5, 2
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 97
; FirstLine = 66
; Folding = -
; EnableXP
; DPIAware