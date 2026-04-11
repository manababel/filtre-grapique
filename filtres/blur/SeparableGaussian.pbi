Procedure CreateGaussianKernel_Sep(Array kernel.f(1), radius.l, sigma.f)
  If sigma <= 0.0 : sigma = radius / 3.0 : EndIf
  
  ; Tronquer radius AVANT de calculer size et Dim
  Protected radius_opt = Int(sigma * 3.0 + 0.5)
  If radius_opt < radius : radius = radius_opt : EndIf
  If radius < 1 : radius = 1 : EndIf
  
  Protected size = radius * 2 + 1   ; ← size calculé APRÈS
  Dim kernel(size - 1)               ; ← allocation correcte
  
  Protected sigma2.f = 2.0 * sigma * sigma
  Protected sum.f = 0.0
  Protected i, x
  
  For i = 0 To size - 1
    x = i - radius
    kernel(i) = Exp(-(x * x) / sigma2)
    sum + kernel(i)
  Next
  
  If sum > 0.0
    For i = 0 To size - 1
      kernel(i) / sum
    Next
  EndIf
EndProcedure

Procedure.i CalcEffectiveRadius(radius.l, sigma.f)
  If sigma <= 0.0 : sigma = radius / 3.0 : EndIf
  Protected r = Int(sigma * 3.0 + 0.5)
  If r < radius : radius = r : EndIf
  If radius < 1 : radius = 1 : EndIf
  ProcedureReturn radius
EndProcedure

Procedure SeparableGaussian_X(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected sigma.f = *param\option[1] / 10.0
  Protected radius = CalcEffectiveRadius(*param\option[0], sigma)  ; ← radius réel
  
  Protected size = radius * 2 + 1   ; ← maintenant correct
  Dim kernel.f(size - 1)
  CreateGaussianKernel_Sep(kernel(), radius, sigma)
  
  Protected x, y, dx, px, index
  Protected sumA.f, sumR.f, sumG.f, sumB.f  ; ← sorti des boucles
  Protected k.f                              ; ← sorti des boucles
  Protected.i value, a, r, g, b
  Protected Dim lineA.f(lg - 1)
  Protected Dim lineR.f(lg - 1)
  Protected Dim lineG.f(lg - 1)
  Protected Dim lineB.f(lg - 1)
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      index = (y * lg + x) << 2
      value = PeekL(*param\addr[0] + index)
      a = (value >> 24) & $FF
      r = (value >> 16) & $FF
      g = (value >> 8)  & $FF
      b =  value        & $FF
      lineA(x) = a
      lineR(x) = r
      lineG(x) = g
      lineB(x) = b
    Next
    
    For x = 0 To lg - 1
      sumA = 0.0 : sumR = 0.0 : sumG = 0.0 : sumB = 0.0
      
      For dx = -radius To radius
        px = x + dx
        Clamp(px, 0, lg - 1)
        k = kernel(dx + radius)        ; ← simple affectation
        sumA + lineA(px) * k
        sumR + lineR(px) * k
        sumG + lineG(px) * k
        sumB + lineB(px) * k
      Next
      
      Clamp(sumA, 0.0, 255.0)
      Clamp(sumR, 0.0, 255.0)
      Clamp(sumG, 0.0, 255.0)
      Clamp(sumB, 0.0, 255.0)
      
      PokeL(*param\addr[1] + ((y * lg + x) << 2), (Int(sumA + 0.5) << 24) | (Int(sumR + 0.5) << 16) | (Int(sumG + 0.5) << 8) | Int(sumB + 0.5))
    Next                               ; ↑ parenthèses corrigées
  Next
EndProcedure

Procedure SeparableGaussian_Y(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected sigma.f = *param\option[1] / 10.0
  Protected radius = CalcEffectiveRadius(*param\option[0], sigma)  ; ← radius réel
  
  Protected size = radius * 2 + 1   ; ← maintenant correct
  Dim kernel.f(size - 1)
  CreateGaussianKernel_Sep(kernel(), radius, sigma)
  
  Protected x, y, dy, py, index
  Protected sumA.f, sumR.f, sumG.f, sumB.f  ; ← sorti des boucles
  Protected k.f                              ; ← sorti des boucles
  Protected.i value, a, r, g, b
  Protected Dim colA.f(ht - 1)
  Protected Dim colR.f(ht - 1)
  Protected Dim colG.f(ht - 1)
  Protected Dim colB.f(ht - 1)
  
  macro_calul_tread(lg)
  
  For x = thread_start To thread_stop - 1
    For y = 0 To ht - 1
      index = (y * lg + x) << 2
      value = PeekL(*param\addr[0] + index)
      a = (value >> 24) & $FF
      r = (value >> 16) & $FF
      g = (value >> 8)  & $FF
      b =  value        & $FF
      colA(y) = a
      colR(y) = r
      colG(y) = g
      colB(y) = b
    Next
    
    For y = 0 To ht - 1
      sumA = 0.0 : sumR = 0.0 : sumG = 0.0 : sumB = 0.0
      
      For dy = -radius To radius
        py = y + dy
        Clamp(py, 0, ht - 1)
        k = kernel(dy + radius)        ; ← simple affectation
        sumA + colA(py) * k
        sumR + colR(py) * k
        sumG + colG(py) * k
        sumB + colB(py) * k
      Next
      
      Clamp(sumA, 0.0, 255.0)
      Clamp(sumR, 0.0, 255.0)
      Clamp(sumG, 0.0, 255.0)
      Clamp(sumB, 0.0, 255.0)
      
      PokeL(*param\addr[1] + ((y * lg + x) << 2), (Int(sumA + 0.5) << 24) | (Int(sumR + 0.5) << 16) | (Int(sumG + 0.5) << 8) | Int(sumB + 0.5))
    Next                               ; ↑ parenthèses corrigées
  Next
EndProcedure

Procedure SeparableGaussian_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected *tmp = AllocateMemory(lg * ht * 4)
  If Not *tmp : ProcedureReturn : EndIf
  
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  
  ; Pass X
  *param\addr[0] = *src
  *param\addr[1] = *tmp
  MultiThread_MT(@SeparableGaussian_X(), 4)
  
  ; Pass Y
  *param\addr[0] = *tmp
  *param\addr[1] = *dst
  MultiThread_MT(@SeparableGaussian_Y(), 4)
  
  FreeMemory(*tmp)
  *param\addr[0] = *src
  *param\addr[1] = *dst
EndProcedure

Procedure SeparableGaussian(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Gaussian
    *param\name = "SeparableGaussian"
    *param\remarque = "Flou gaussien optimisé séparable"
    *param\info[0] = "Rayon"
    *param\info[1] = "Sigma x10"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 50  : *param\info_data(0, 2) = 5
    *param\info_data(1, 0) = 1 : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0 : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 50)
  If *param\option[1] = 0 : *param\option[1] = *param\option[0] * 10 / 3 : EndIf
  
  Protected sigma_real.f = *param\option[1] / 10.0
  Protected radius_max = Int(sigma_real * 3.0 + 0.5)
  Clamp(radius_max, 1, 50)
  If *param\option[0] > radius_max
    *param\option[0] = radius_max
  EndIf
  
  
  filter_start(@SeparableGaussian_sp(), 2 , 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 102
; FirstLine = 75
; Folding = --
; EnableXP
; DPIAware