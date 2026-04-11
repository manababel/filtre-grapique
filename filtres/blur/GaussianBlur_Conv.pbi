Procedure GaussianBlur_Conv_H_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected w = *param\lg
  Protected h = *param\ht
  Protected radius = *param\option[0]
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected yStart = (thread_pos * h) / thread_max
  Protected yEnd = ((thread_pos + 1) * h) / thread_max - 1
  
  Protected x, y, k, i, pos, posOffset
  Protected r.f, g.f, b.f
  Protected r1, g1, b1
  Protected col
  Protected *kernel = *param\addr[2]
  Protected half = radius
  Protected wMinus1 = w - 1
  Protected kernelSize = SizeOf(Float)
  Protected var.f
  
  For y = yStart To yEnd
    posOffset = y * w << 2  ; Précalcul de y * w * 4
    For x = 0 To w - 1
      r = 0 : g = 0 : b = 0
      
      For k = -half To half
        ; Clamping optimisé
        i = x + k
        If i < 0
          i = 0
        ElseIf i > wMinus1
          i = wMinus1
        EndIf
        
        pos = posOffset + (i << 2)
        col = PeekL(*src + pos)
        getrgb(col, r1, g1, b1)
        
        var = PeekF(*kernel + (k + half) * kernelSize)
        r + r1 * var
        g + g1 * var
        b + b1 * var
      Next
      
      pos = posOffset + (x << 2)
      PokeL(*dst + pos, RGB(Int(r), Int(g), Int(b)))
    Next
  Next
EndProcedure

Procedure GaussianBlur_Conv_V_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected w = *param\lg
  Protected h = *param\ht
  Protected radius = *param\option[0]
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected yStart = (thread_pos * h) / thread_max
  Protected yEnd = ((thread_pos + 1) * h) / thread_max - 1
  
  Protected x, y, k, i, pos, xOffset
  Protected r.f, g.f, b.f
  Protected r1, g1, b1
  Protected col
  Protected *kernel = *param\addr[2]
  Protected half = radius
  Protected hMinus1 = h - 1
  Protected kernelSize = SizeOf(Float)
  Protected wShift2 = w << 2  ; w * 4 précalculé
  Protected var.f
  
  For y = yStart To yEnd
    For x = 0 To w - 1
      r = 0 : g = 0 : b = 0
      xOffset = x << 2  ; Précalcul de x * 4
      
      For k = -half To half
        ; Clamping optimisé
        i = y + k
        If i < 0
          i = 0
        ElseIf i > hMinus1
          i = hMinus1
        EndIf
        
        pos = i * wShift2 + xOffset
        col = PeekL(*src + pos)
        getrgb(col, r1, g1, b1)
        
        var = PeekF(*kernel + (k + half) * kernelSize)
        r + r1 * var
        g + g1 * var
        b + b1 * var
      Next
      
      pos = y * wShift2 + xOffset
      PokeL(*dst + pos, RGB(Int(r), Int(g), Int(b)))
    Next
  Next
EndProcedure

Procedure GaussianBlur_Conv(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Gaussian
    *param\name = "GaussianBlur_Conv"
    *param\remarque = "Gaussian Blur (convolution, séparable)"
    *param\info[0] = "Rayon"
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 50 : *param\info_data(0,2) = 5
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected total = *param\lg * *param\ht << 2  ; Bit shift
  Protected *tempo = AllocateMemory(total)
  If Not *tempo : ProcedureReturn : EndIf
  
  ; Générer le noyau
  Protected radius = *param\option[0]
  If radius < 1 : radius = 1 : EndIf
  
  Protected sigma.f = radius * 0.5  ; Division optimisée
  Protected size = (radius << 1) + 1  ; Bit shift
  Protected *kernel = AllocateMemory(size * SizeOf(Float))
  
  If Not *kernel
    FreeMemory(*tempo)
    ProcedureReturn
  EndIf
  
  Protected i, x
  Protected var.f, sum.f = 0.0
  Protected invTwoSigmaSq.f = 1.0 / (2.0 * sigma * sigma)  ; Précalcul
  Protected kernelOffset
  
  ; Calcul du noyau avec précalcul
  For i = 0 To size - 1
    x = i - radius
    var = Exp(-x * x * invTwoSigmaSq)
    kernelOffset = i * SizeOf(Float)
    PokeF(*kernel + kernelOffset, var)
    sum + var
  Next
  
  ; Normalisation
  Protected invSum.f = 1.0 / sum
  For i = 0 To size - 1
    kernelOffset = i * SizeOf(Float)
    var = PeekF(*kernel + kernelOffset)
    PokeF(*kernel + kernelOffset, var * invSum)
  Next
  
  ; === Passe horizontale ===
  *param\addr[0] = *param\source
  *param\addr[1] = *tempo
  *param\addr[2] = *kernel
  MultiThread_MT(@GaussianBlur_Conv_H_MT())
  
  ; === Passe verticale ===
  *param\addr[0] = *tempo
  *param\addr[1] = *param\cible
  MultiThread_MT(@GaussianBlur_Conv_V_MT())
  
  ; Nettoyage
  FreeMemory(*tempo)
  FreeMemory(*kernel)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 169
; FirstLine = 100
; Folding = -
; EnableXP
; DPIAware