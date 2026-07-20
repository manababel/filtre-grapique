; ---------------------------------------------------
; Gaussian Pyramid Blur - Version optimisée
; Flou multi-résolution avec passes séparables X/Y
; ---------------------------------------------------

Procedure CreateGaussianKernel_pyramid(Array Kernel.f(1), radius)
  Protected size = radius * 2 + 1
  Protected sum.f = 0.0
  Protected sigma.f = radius / 3.0
  Protected i, x
  If sigma < 0.5 : sigma = 0.5 : EndIf
  sigma = 2.0 * sigma * sigma
  
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
    Protected lg = \option[7]
    Protected ht = \option[8]
    Protected radius = \option[0]
    If radius < 1 : radius = 1 : EndIf
    Protected size = radius * 2 + 1
    Protected a, r, g, b, x, y, dx, px
    Protected.f sumA.f , sumR.f , sumG.f , sumB.f 
    Protected kernelVal.f
    
    Protected *src.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[3]
    
    Dim kernel.f(size - 1)
    Dim lineA.f(lg - 1)
    Dim lineR.f(lg - 1)
    Dim lineG.f(lg - 1)
    Dim lineB.f(lg - 1)
    CreateGaussianKernel_pyramid(kernel(), radius)
    
    macro_calul_tread(ht)

    For y = thread_start To thread_stop - 1
      ; --- TA LOGIQUE EXACTE RESTAURÉE ---
      For x = 0 To lg - 1
        getargb(*src\l[y * lg + x] , a , r , g , b)
        lineA(x) = a
        lineR(x) = r
        lineG(x) = g
        lineB(x) = b
      Next

      For x = 0 To lg - 1
        sumA.f = 0.0: sumR.f = 0.0: sumG.f = 0.0: sumB.f = 0.0
        For dx = -radius To radius
          px = x + dx
          clamp(px , 0 , (lg - 1))
          kernelVal = kernel(dx + radius)
          sumA + lineA(px) * kernelVal
          sumR + lineR(px) * kernelVal
          sumG + lineG(px) * kernelVal
          sumB + lineB(px) * kernelVal
        Next
        a = Int(sumA + 0.5) : r = Int(sumR + 0.5) : g = Int(sumG + 0.5) : b = Int(sumB + 0.5)
        clamp_argb(a , r , g , b)
        *dst\l[y * lg + x] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure GaussianBlur_Y(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \option[7]
    Protected ht = \option[8]
    Protected radius = \option[0]
    If radius < 1 : radius = 1 : EndIf
    Protected a, r, g, b, x, y, dy, py
    Protected.f sumA.f , sumR.f , sumG.f , sumB.f 
    Protected kernelVal.f
    
    Protected size = radius * 2 + 1
    Dim kernel.f(size - 1)
    Dim colA.f(ht - 1)
    Dim colR.f(ht - 1)
    Dim colG.f(ht - 1)
    Dim colB.f(ht - 1)
    CreateGaussianKernel_pyramid(kernel(), radius)

    Protected *src.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[3]
    
    macro_calul_tread(lg)

    For x = thread_start To thread_stop - 1
      ; --- TA LOGIQUE EXACTE RESTAURÉE ---
      For y = 0 To ht - 1
        getargb(*src\l[y * lg + x] , a , r , g , b)
        colA(y) = a
        colR(y) = r
        colG(y) = g
        colB(y) = b
      Next

      For y = 0 To ht - 1
        sumA = 0.0: sumR = 0.0: sumG = 0.0: sumB = 0.0
        For dy = -radius To radius
          py = y + dy
          clamp(py , 0 , (ht - 1))
          kernelVal = kernel(dy + radius)
          sumA + colA(py) * kernelVal
          sumR + colR(py) * kernelVal
          sumG + colG(py) * kernelVal
          sumB + colB(py) * kernelVal
        Next
        
        a = Int(sumA + 0.5) : r = Int(sumR + 0.5) : g = Int(sumG + 0.5) : b = Int(sumB + 0.5)
        clamp_argb(a , r , g , b)
        *dst\l[y * lg + x] = (a << 24) | (r << 16) | (g << 8) | b
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
  Protected *nsrc.pixelarray = *src
  Protected *ndst.pixelarray = *dst
  
  For y = 0 To dstH - 1
    sy = y >> 1
    If sy >= srcH : sy = srcH - 1 : EndIf
    For x = 0 To dstW - 1
      sx = x >> 1
      If sx >= srcW : sx = srcW - 1 : EndIf
      *ndst\l[y * dstW + x] = *nsrc\l[sy * srcW + sx]
    Next
  Next
EndProcedure

;==========================
; Downscale avec moyenne 2x2
;==========================
Procedure Pyramid_Downscale(*src, srcW, srcH, *dst, dstW, dstH)
  Protected x, y, sx, sy
  Protected c1, c2, c3, c4
  Protected.l a, r, g, b
  Protected.l a0 , r0 , g0 , b0
  Protected.l a1 , r1 , g1 , b1
  Protected.l a2 , r2 , g2 , b2
  Protected.l a3 , r3 , g3 , b3
  
  Protected *nsrc.pixelarray = *src
  Protected *ndst.pixelarray = *dst
  
  For y = 0 To dstH - 1
    sy = y << 1
    For x = 0 To dstW - 1
      sx = x << 1
      getargb(*nsrc\l[sy * srcW + sx] , a0 , r0 , g0 , b0)
      getargb(*nsrc\l[sy * srcW + sx + 1] , a1 , r1 , g1 , b1)
      getargb(*nsrc\l[(sy + 1) * srcW + sx] , a2 , r2 , g2 , b2)
      getargb(*nsrc\l[(sy + 1) * srcW + sx + 1] , a3 , r3 , g3 , b3)
      a = (a0 + a1 + a2 + a3) >> 2
      r = (r0 + r1 + r2 + r3) >> 2
      g = (g0 + g1 + g2 + g3) >> 2
      b = (b0 + b1 + b2 + b3) >> 2  
      *ndst\l[y * dstW + x] = (a << 24) | (r << 16) | (g << 8) | b
    Next
  Next
EndProcedure

Procedure GaussianPyramidBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected *buf1 = AllocateMemory(lg * ht * 4)
    Protected *buf2 = AllocateMemory(lg * ht * 4)
    If *buf1 <> 0 And *buf2 <> 0
      CopyMemory(\addr[0], *buf1, lg * ht * 4)
      
      ; 1. Flou original
      \addr[2] = *buf1
      \addr[3] = *buf2
      \option[7] = lg
      \option[8] = ht
      Create_MultiThread_MT(@GaussianBlur_X())
      \addr[2] = *buf2
      \addr[3] = *buf1
      Create_MultiThread_MT(@GaussianBlur_Y())
      
      ; 2. Downscale x2
      Protected lg2 = lg >> 1
      Protected ht2 = ht >> 1
      If lg2 < 2 : lg2 = 2 : EndIf
      If ht2 < 2 : ht2 = 2 : EndIf
      Pyramid_Downscale(*buf1, lg, ht, *buf2, lg2, ht2)
      
      ; 3. Flou réduit
      \addr[2] = *buf2
      \addr[3] = *buf1
      \option[7] = lg2
      \option[8] = ht2
      Create_MultiThread_MT(@GaussianBlur_X())
      \addr[2] = *buf1
      \addr[3] = *buf2
      Create_MultiThread_MT(@GaussianBlur_Y())
      
      ; 4. Upscale x2
      Pyramid_Upscale(*buf2, lg2, ht2, *buf1, lg, ht)
      
      ; 5. Flou final (vers l'adresse cible originale)
      \addr[2] = *buf1
      \addr[3] = *buf2
      \option[7] = lg
      \option[8] = ht
      Create_MultiThread_MT(@GaussianBlur_X())
      \addr[2] = *buf2
      \addr[3] = \addr[1]
      Create_MultiThread_MT(@GaussianBlur_Y())
      
    EndIf
    If *buf1 : FreeMemory(*buf1) : EndIf
    If *buf2 : FreeMemory(*buf2) : EndIf
  EndWith
  
EndProcedure


Procedure GaussianPyramidBlurEx(*FilterCtx.FilterParams)
  Restore GaussianPyramidBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  GaussianPyramidBlur_sp(*FilterCtx)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure GaussianPyramidBlur(source, cible, mask, radius)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
  EndWith
  GaussianPyramidBlurEx(FilterCtx)
EndProcedure

DataSection
  GaussianPyramidBlur_data:
  Data.s "Gaussian Pyramid Blur"
  Data.s "Flou gaussien multi-résolution"
  Data.i #FilterType_Blur, #Blur_MultiScale
  Data.s "Rayon"
  Data.i 1, 15, 2
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 234
; FirstLine = 176
; Folding = --
; EnableXP
; DPIAware