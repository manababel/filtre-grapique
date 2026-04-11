;==========================
; Création du noyau gaussien
;==========================
Procedure CreateGaussianKernel_pyramid(Array Kernel.f(1), radius)
  Protected size = radius * 2 + 1
  Protected sum.f = 0.0
  Protected sigma.f = radius / 3.0  ; Ajusté pour une meilleure distribution
  If sigma < 0.5 : sigma = 0.5 : EndIf
  sigma = 2.0 * sigma * sigma
  Protected i, x

  For i = 0 To size - 1
    x = i - radius
    kernel(i) = Exp(-(x * x) / sigma)
    sum + kernel(i)
  Next

  ; Normalisation pour conserver la luminosité
  If sum > 0.0
    For i = 0 To size - 1
      kernel(i) / sum
    Next
  EndIf
EndProcedure

;==========================
; Flou Gaussien Séparable X
;==========================
Procedure GaussianBlur_X(*param.parametre)
  Protected lg = *param\option[7]
  Protected ht = *param\option[8]
  Protected radius = *param\option[0]
  
  If radius < 1 : radius = 1 : EndIf
  Protected size = radius * 2 + 1
  Dim kernel.f(size - 1)
  CreateGaussianKernel_pyramid(kernel(), radius)
  
  Protected a, r, g, b
  Protected x, y, dx, px, index
  Dim lineA.f(lg - 1)
  Dim lineR.f(lg - 1)
  Dim lineG.f(lg - 1)
  Dim lineB.f(lg - 1)
  
  macro_calul_tread(ht)

  For y = thread_start To thread_stop - 1
    ; Remplir les buffers de ligne
    For x = 0 To lg - 1
      index = (y * lg + x) << 2
      Protected c = PeekL(*param\addr[0] + index)
      r = (c >> 24) & $FF
      g = (c >> 16) & $FF
      b = (c >> 8) & $FF
      a = c & $FF
      lineA(x) = r
      lineR(x) = g
      lineG(x) = b
      lineB(x) = a
    Next

    ; Application du flou horizontal
    For x = 0 To lg - 1
      Protected sumA.f = 0.0
      Protected sumR.f = 0.0
      Protected sumG.f = 0.0
      Protected sumB.f = 0.0
      
      For dx = -radius To radius
        px = x + dx
        Clamp(px, 0, lg - 1)
        Protected kernelVal.f = kernel(dx + radius)
        sumA + lineA(px) * kernelVal
        sumR + lineR(px) * kernelVal
        sumG + lineG(px) * kernelVal
        sumB + lineB(px) * kernelVal
      Next
      
      ; Clamp et conversion
      Clamp(sumA, 0.0, 255.0)
      Clamp(sumR, 0.0, 255.0)
      Clamp(sumG, 0.0, 255.0)
      Clamp(sumB, 0.0, 255.0)
      
      a = Int(sumA + 0.5)
      r = Int(sumR + 0.5)
      g = Int(sumG + 0.5)
      b = Int(sumB + 0.5)
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

;==========================
; Flou Gaussien Séparable Y
;==========================
Procedure GaussianBlur_Y(*param.parametre)
  Protected radius = *param\option[0]
  Protected lg = *param\option[7]
  Protected ht = *param\option[8]
  
  If radius < 1 : radius = 1 : EndIf
  Protected size = radius * 2 + 1
  Dim kernel.f(size - 1)
  CreateGaussianKernel_pyramid(kernel(), radius)
  
  Protected a, r, g, b
  Protected x, y, dy, py, index
  Dim colA.f(ht - 1)
  Dim colR.f(ht - 1)
  Dim colG.f(ht - 1)
  Dim colB.f(ht - 1)
  
  macro_calul_tread(lg)

  For x = thread_start To thread_stop - 1
    ; Remplir les buffers de colonne
    For y = 0 To ht - 1
      index = (y * lg + x) << 2
      Protected c = PeekL(*param\addr[0] + index)
      r = (c >> 24) & $FF
      g = (c >> 16) & $FF
      b = (c >> 8) & $FF
      a = c & $FF
      colA(y) = r
      colR(y) = g
      colG(y) = b
      colB(y) = a
    Next

    ; Application du flou vertical
    For y = 0 To ht - 1
      Protected sumA.f = 0.0
      Protected sumR.f = 0.0
      Protected sumG.f = 0.0
      Protected sumB.f = 0.0
      
      For dy = -radius To radius
        py = y + dy
        Clamp(py, 0, ht - 1)
        Protected kernelVal.f = kernel(dy + radius)
        sumA + colA(py) * kernelVal
        sumR + colR(py) * kernelVal
        sumG + colG(py) * kernelVal
        sumB + colB(py) * kernelVal
      Next
      
      ; Clamp et conversion
      Clamp(sumA, 0.0, 255.0)
      Clamp(sumR, 0.0, 255.0)
      Clamp(sumG, 0.0, 255.0)
      Clamp(sumB, 0.0, 255.0)
      
      a = Int(sumA + 0.5)
      r = Int(sumR + 0.5)
      g = Int(sumG + 0.5)
      b = Int(sumB + 0.5)
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

;==========================
; Flou Séparable complet
;==========================
Procedure GaussianBlur_Separable(*param.parametre)
  Protected lg = *param\option[7]
  Protected ht = *param\option[8]
  
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected *tmp = AllocateMemory(lg * ht * 4)
  If Not *tmp : ProcedureReturn : EndIf

  ; Pass X
  *param\addr[0] = *src
  *param\addr[1] = *tmp
  MultiThread_MT(@GaussianBlur_X(), 4)

  ; Pass Y
  *param\addr[0] = *tmp
  *param\addr[1] = *dst
  MultiThread_MT(@GaussianBlur_Y(), 4)

  FreeMemory(*tmp)
  *param\addr[0] = *src
  *param\addr[1] = *dst
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

Procedure GaussianPyramidBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_MultiScale
    *param\name = "Gaussian Pyramid Blur"
    *param\remarque = "Gaussian blur multi-résolution"
    *param\info[0] = "Rayon"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 5 : *param\info_data(0, 2) = 2
    *param\info[1] = "Masque"
    *param\info_data(1, 0) = 0 : *param\info_data(1, 1) = 2 : *param\info_data(1, 2) = 0
    ProcedureReturn
  EndIf

  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf

  Protected lg = *param\lg
  Protected ht = *param\ht
  Clamp(*param\option[0], 1, 5)

  ; Validation des dimensions
  If lg < 4 Or ht < 4 : ProcedureReturn : EndIf

  ; Buffers temporaires
  Protected *buf1 = AllocateMemory(lg * ht * 4)
  Protected *buf2 = AllocateMemory(lg * ht * 4)
  If Not *buf1 Or Not *buf2
    If *buf1 : FreeMemory(*buf1) : EndIf
    If *buf2 : FreeMemory(*buf2) : EndIf
    ProcedureReturn
  EndIf

  CopyMemory(*param\source, *buf1, lg * ht * 4)

  ; ===== Étape 1 : flou image originale =====
  *param\addr[0] = *buf1
  *param\addr[1] = *buf2
  *param\option[7] = lg
  *param\option[8] = ht
  GaussianBlur_Separable(*param)

  ; ===== Étape 2 : downscale x2 avec moyenne =====
  Protected lg2 = lg >> 1
  Protected ht2 = ht >> 1
  If lg2 < 2 : lg2 = 2 : EndIf
  If ht2 < 2 : ht2 = 2 : EndIf
  
  Pyramid_Downscale(*buf2, lg, ht, *buf1, lg2, ht2)

  ; ===== Étape 3 : flou image réduite =====
  *param\addr[0] = *buf1
  *param\addr[1] = *buf2
  *param\option[7] = lg2
  *param\option[8] = ht2
  GaussianBlur_Separable(*param)

  ; ===== Étape 4 : upscale x2 =====
  Pyramid_Upscale(*buf2, lg2, ht2, *buf1, lg, ht)

  ; ===== Étape 5 : flou final =====
  *param\addr[0] = *buf1
  *param\addr[1] = *param\cible
  *param\option[7] = lg
  *param\option[8] = ht
  GaussianBlur_Separable(*param)

  ; ===== Masque éventuel =====
  If *param\mask And *param\option[1]
    *param\mask_type = *param\option[1] - 1
    MultiThread_MT(@_mask())
  EndIf

  FreeMemory(*buf1)
  FreeMemory(*buf2)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 125
; FirstLine = 106
; Folding = --
; EnableXP
; DPIAware