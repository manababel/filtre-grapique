; ---------------------------------------------------
; Gaussian Pyramid Blur - Version optimisée
; Flou multi-résolution avec passes séparables X/Y
; ---------------------------------------------------

Procedure CreateGaussianKernel_pyramid(Array Kernel.f(1), radius)
  Protected size = radius * 2 + 1
  Protected sum.f = 0.0
  Protected sigma.f = radius / 3.0
  If sigma < 0.5 : sigma = 0.5 : EndIf
  sigma = 2.0 * sigma * sigma
  Protected i, x

  For i = 0 To size - 1
    x = i - radius
    Kernel(i) = Exp(-(x * x) / sigma)
    sum + Kernel(i)
  Next

  If sum > 0.0
    For i = 0 To size - 1
      Kernel(i) / sum
    Next
  EndIf
EndProcedure

; ---------------------------------------------------
; Gaussian Pyramid Blur
; ---------------------------------------------------

Procedure GaussianBlur_X(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \option[7], ht = \option[8], radius = \option[0]
    If radius < 1 : radius = 1 : EndIf
    
    Protected size = radius * 2 + 1
    Dim kernel.f(size - 1)
    CreateGaussianKernel_pyramid(kernel(), radius)
    
    Protected a, r, g, b, x, y, dx, px, index, c
    Dim lineA.f(lg - 1) : Dim lineR.f(lg - 1) : Dim lineG.f(lg - 1) : Dim lineB.f(lg - 1)
    
    macro_calul_tread(ht)

    For y = thread_start To thread_stop - 1
      ; --- TA LOGIQUE EXACTE RESTAURÉE ---
      For x = 0 To lg - 1
        index = (y * lg + x) << 2
        c = PeekL(\addr[0] + index)
        r = (c >> 24) & $FF
        g = (c >> 16) & $FF
        b = (c >> 8) & $FF
        a = c & $FF
        lineA(x) = r
        lineR(x) = g
        lineG(x) = b
        lineB(x) = a
      Next

      For x = 0 To lg - 1
        Protected sumA.f = 0.0, sumR.f = 0.0, sumG.f = 0.0, sumB.f = 0.0
        For dx = -radius To radius
          px = x + dx
          If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf ; Ton Clamp(px...)
          Protected kernelVal.f = kernel(dx + radius)
          sumA + lineA(px) * kernelVal
          sumR + lineR(px) * kernelVal
          sumG + lineG(px) * kernelVal
          sumB + lineB(px) * kernelVal
        Next
        
        a = Int(sumA + 0.5) : r = Int(sumR + 0.5) : g = Int(sumG + 0.5) : b = Int(sumB + 0.5)
        
        ; Clamping manuel (équivalent à ta logique)
        If a > 255 : a = 255 : ElseIf a < 0 : a = 0 : EndIf
        If r > 255 : r = 255 : ElseIf r < 0 : r = 0 : EndIf
        If g > 255 : g = 255 : ElseIf g < 0 : g = 0 : EndIf
        If b > 255 : b = 255 : ElseIf b < 0 : b = 0 : EndIf
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure GaussianBlur_Y(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \option[7], ht = \option[8], radius = \option[0]
    If radius < 1 : radius = 1 : EndIf
    
    Protected size = radius * 2 + 1
    Dim kernel.f(size - 1)
    CreateGaussianKernel_pyramid(kernel(), radius)
    
    Protected a, r, g, b, x, y, dy, py, index, c
    Dim colA.f(ht - 1) : Dim colR.f(ht - 1) : Dim colG.f(ht - 1) : Dim colB.f(ht - 1)
    
    macro_calul_tread(lg)

    For x = thread_start To thread_stop - 1
      ; --- TA LOGIQUE EXACTE RESTAURÉE ---
      For y = 0 To ht - 1
        index = (y * lg + x) << 2
        c = PeekL(\addr[0] + index)
        r = (c >> 24) & $FF
        g = (c >> 16) & $FF
        b = (c >> 8) & $FF
        a = c & $FF
        colA(y) = r
        colR(y) = g
        colG(y) = b
        colB(y) = a
      Next

      For y = 0 To ht - 1
        Protected sumA.f = 0.0, sumR.f = 0.0, sumG.f = 0.0, sumB.f = 0.0
        For dy = -radius To radius
          py = y + dy
          If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf ; Ton Clamp(py...)
          Protected kernelVal.f = kernel(dy + radius)
          sumA + colA(py) * kernelVal
          sumR + colR(py) * kernelVal
          sumG + colG(py) * kernelVal
          sumB + colB(py) * kernelVal
        Next
        
        a = Int(sumA + 0.5) : r = Int(sumR + 0.5) : g = Int(sumG + 0.5) : b = Int(sumB + 0.5)
        
        If a > 255 : a = 255 : ElseIf a < 0 : a = 0 : EndIf
        If r > 255 : r = 255 : ElseIf r < 0 : r = 0 : EndIf
        If g > 255 : g = 255 : ElseIf g < 0 : g = 0 : EndIf
        If b > 255 : b = 255 : ElseIf b < 0 : b = 0 : EndIf
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

;==========================
; Upscale avec interpolation bilinéaire
;==========================
Procedure Pyramid_Upscale(*src, srcW, srcH, *dst, dstW, dstH)
  Protected x, y, sx, sy
  Protected c
  
  For y = 0 To dstH - 1
    sy = y >> 1
    If sy >= srcH : sy = srcH - 1 : EndIf
    
    For x = 0 To dstW - 1
      sx = x >> 1
      If sx >= srcW : sx = srcW - 1 : EndIf
      
      c = PeekL(*src + ((sy * srcW + sx) << 2))
      PokeL(*dst + ((y * dstW + x) << 2), c)
    Next
  Next
EndProcedure

;==========================
; Downscale avec moyenne 2x2
;==========================
Procedure Pyramid_Downscale(*src, srcW, srcH, *dst, dstW, dstH)
  Protected x, y, sx, sy
  Protected c1, c2, c3, c4
  Protected a, r, g, b
  
  For y = 0 To dstH - 1
    sy = y << 1
    For x = 0 To dstW - 1
      sx = x << 1
      
      ; Lecture des 4 pixels sources
      c1 = PeekL(*src + ((sy * srcW + sx) << 2))
      c2 = PeekL(*src + ((sy * srcW + sx + 1) << 2))
      c3 = PeekL(*src + (((sy + 1) * srcW + sx) << 2))
      c4 = PeekL(*src + (((sy + 1) * srcW + sx + 1) << 2))
      
      ; Moyenne des 4 pixels (préserve la luminosité)
      a = (((c1 >> 24) & $FF) + ((c2 >> 24) & $FF) + ((c3 >> 24) & $FF) + ((c4 >> 24) & $FF)) >> 2
      r = (((c1 >> 16) & $FF) + ((c2 >> 16) & $FF) + ((c3 >> 16) & $FF) + ((c4 >> 16) & $FF)) >> 2
      g = (((c1 >> 8) & $FF) + ((c2 >> 8) & $FF) + ((c3 >> 8) & $FF) + ((c4 >> 8) & $FF)) >> 2
      b = ((c1 & $FF) + (c2 & $FF) + (c3 & $FF) + (c4 & $FF)) >> 2
      
      PokeL(*dst + ((y * dstW + x) << 2), (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure GaussianPyramidBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected *buf1 = AllocateMemory(lg * ht * 4)
    Protected *buf2 = AllocateMemory(lg * ht * 4)
    If Not *buf1 Or Not *buf2 : Goto cleanup : EndIf

    CopyMemory(\addr[0], *buf1, lg * ht * 4)

    ; 1. Flou original
    \addr[0] = *buf1 : \addr[1] = *buf2 : \option[7] = lg : \option[8] = ht
    Create_MultiThread_MT(@GaussianBlur_X(), 1)
    \addr[0] = *buf2 : \addr[1] = *buf1 : Create_MultiThread_MT(@GaussianBlur_Y(), 1)

    ; 2. Downscale x2
    Protected lg2 = lg >> 1, ht2 = ht >> 1
    If lg2 < 2 : lg2 = 2 : EndIf : If ht2 < 2 : ht2 = 2 : EndIf
    Pyramid_Downscale(*buf1, lg, ht, *buf2, lg2, ht2)

    ; 3. Flou réduit
    \addr[0] = *buf2 : \addr[1] = *buf1 : \option[7] = lg2 : \option[8] = ht2
    Create_MultiThread_MT(@GaussianBlur_X(), 1)
    \addr[0] = *buf1 : \addr[1] = *buf2 : Create_MultiThread_MT(@GaussianBlur_Y(), 1)

    ; 4. Upscale x2
    Pyramid_Upscale(*buf2, lg2, ht2, *buf1, lg, ht)

    ; 5. Flou final (vers l'adresse cible originale)
    \addr[0] = *buf1 : \addr[1] = \addr[1] : \option[7] = lg : \option[8] = ht
    Create_MultiThread_MT(@GaussianBlur_X(), 1)
    \addr[0] = \addr[1] : \addr[1] = \addr[1] : Create_MultiThread_MT(@GaussianBlur_Y(), 1)

    cleanup:
    If *buf1 : FreeMemory(*buf1) : EndIf
    If *buf2 : FreeMemory(*buf2) : EndIf
  EndWith
EndProcedure


Procedure GaussianPyramidBlurEx(*FilterCtx.FilterParams)
  Restore GaussianPyramidBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  GaussianPyramidBlur_sp(*FilterCtx)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure GaussianPyramidBlur(source, cible, mask, radius)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
  EndWith
  GaussianPyramidBlurEx(FilterCtx)
EndProcedure

DataSection
  GaussianPyramidBlur_data:
  Data.s "Gaussian Pyramid Blur (probleme)"
  Data.s "Flou gaussien multi-résolution"
  Data.i #FilterType_Blur, #Blur_MultiScale
  Data.s "Rayon"
  Data.i 1, 5, 2
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 249
; FirstLine = 204
; Folding = --
; EnableXP
; DPIAware