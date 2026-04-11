; ---------------------------------------------------
; NLM Blur optimisé (approx distance luminance + précomputed patch kernel)
; ARGB32, multithreaded
; ---------------------------------------------------

; --- Précompute gaussian patch kernel (weights) into arrays (centered)
Procedure NLM_PrecomputePatchKernel(patchRadius, *kernel_d)
  Protected PS = 2 * patchRadius + 1
  Protected sigma.d = patchRadius / 2.0
  If sigma <= 0.0 : sigma = 0.5 : EndIf
  Protected twoSigma2.d = 2.0 * sigma * sigma
  Protected sum.d = 0.0
  Protected i, j, idx = 0
  Protected var.f

  For j = -patchRadius To patchRadius
    For i = -patchRadius To patchRadius
      var = Exp(-(i*i + j*j) / twoSigma2)
      PokeF(*kernel_d + idx * 4, var)
      sum + var
      idx + 1
    Next
  Next

  ; Normalize
  If sum > 0.0
    Protected invSum.d = 1.0 / sum
    For idx = 0 To PS*PS - 1
      var = PeekF(*kernel_d + idx * 4) * invSum
      PokeF(*kernel_d + idx * 4, var)
    Next
  EndIf
EndProcedure


; --- NLM thread worker optimisé
Procedure NLMBlur_MT(*param.parametre)
  Protected w = *param\lg
  Protected h = *param\ht
  Protected searchRadius = *param\option[0]
  Protected patchRadius  = *param\option[1]
  Protected hparam.d     = *param\option[2]

  Protected *src32.Pixel32
  Protected *dst32.Pixel32

  ; --- Précompute kernel
  Protected PS = 2 * patchRadius + 1
  Protected kernelSize = PS * PS
  Protected *kernel_d = AllocateMemory(kernelSize * 4)
  If *kernel_d = 0 : ProcedureReturn : EndIf
  NLM_PrecomputePatchKernel(patchRadius, *kernel_d)

  ; --- Précompute luminance
  Protected *luma = AllocateMemory(w * h * 4)
  If *luma = 0
    FreeMemory(*kernel_d)
    ProcedureReturn
  EndIf
  
  Protected rl, gl, bl
  Protected y, x, lum.f
  
  For y = 0 To h - 1
    For x = 0 To w - 1
      *src32 = *param\addr[0] + (y*w + x) * 4
      getrgb(*src32\l, rl, gl, bl)
      lum = 0.299 * rl + 0.587 * gl + 0.114 * bl
      PokeF(*luma + (y*w + x) * 4, lum)
    Next
  Next

  ; --- Multi-thread split
  macro_calul_tread(h)

  ; --- Constantes précalculées
  Protected invHSq.d = 1.0 / (hparam * hparam)
  Protected w_minus_1 = w - 1
  Protected h_minus_1 = h - 1
  Protected patchDiameter = 2 * patchRadius + 1

  ; --- Variables locales
  Protected idxKernel, ky, kx, px, py, qx, qy
  Protected sx, sy, spos, pPos
  Protected aC, rC, gC, bC, aN, rN, gN, bN
  Protected accumA.d, accumR.d, accumG.d, accumB.d, wsum.d
  Protected lumDiff.d, patchDist.d, weight.d
  Protected kernelWeight.f
  Protected lumaP.f, lumaQ.f
  Protected searchYMin, searchYMax, searchXMin, searchXMax

  ; --- Boucle principale
  For y = thread_start To thread_stop - 1
    For x = 0 To w - 1
      pPos = y * w + x
      *src32 = *param\addr[0] + pPos * 4
      aC = (*src32\l >> 24) & $FF
      rC = (*src32\l >> 16) & $FF
      gC = (*src32\l >>  8) & $FF
      bC =  *src32\l & $FF

      accumA = 0.0 : accumR = 0.0 : accumG = 0.0 : accumB = 0.0 : wsum = 0.0

      ; --- Fenêtre de recherche
      searchYMin = Max_2(0, y - searchRadius)
      searchYMax = Min_2(h_minus_1, y + searchRadius)
      searchXMin = Max_2(0, x - searchRadius)
      searchXMax = Min_2(w_minus_1, x + searchRadius)
      
      For sy = searchYMin To searchYMax
        For sx = searchXMin To searchXMax

          patchDist = 0.0
          idxKernel = 0
          
          For ky = -patchRadius To patchRadius
            py = y + ky
            qy = sy + ky
            
            ; Vérification des limites Y
            If py < 0 Or py > h_minus_1 Or qy < 0 Or qy > h_minus_1
              idxKernel + patchDiameter
              Continue
            EndIf

            For kx = -patchRadius To patchRadius
              px = x + kx
              qx = sx + kx
              
              ; Vérification des limites X
              If px < 0 Or px > w_minus_1 Or qx < 0 Or qx > w_minus_1
                idxKernel + 1
                Continue
              EndIf

              ; Calcul distance luminance
              lumaP = PeekF(*luma + (py*w + px) * 4)
              lumaQ = PeekF(*luma + (qy*w + qx) * 4)
              lumDiff = lumaP - lumaQ
              kernelWeight = PeekF(*kernel_d + idxKernel * 4)
              patchDist + kernelWeight * (lumDiff * lumDiff)
              idxKernel + 1
            Next
          Next

          ; Calcul du poids
          weight = Exp(-patchDist * invHSq)

          ; Accumulation des couleurs
          spos = sy * w + sx
          *src32 = *param\addr[0] + spos * 4
          aN = (*src32\l >> 24) & $FF
          rN = (*src32\l >> 16) & $FF
          gN = (*src32\l >>  8) & $FF
          bN =  *src32\l & $FF

          accumA + aN * weight
          accumR + rN * weight
          accumG + gN * weight
          accumB + bN * weight
          wsum + weight
        Next
      Next

      ; Écriture du résultat
      *dst32 = *param\addr[1] + pPos * 4
      
      If wsum <= 0.0
        *src32 = *param\addr[0] + pPos * 4
        *dst32\l = *src32\l
      Else
        Protected invWsum.d = 1.0 / wsum
        aC = Int(accumA * invWsum + 0.5)
        rC = Int(accumR * invWsum + 0.5)
        gC = Int(accumG * invWsum + 0.5)
        bC = Int(accumB * invWsum + 0.5)

        ; Clamping
        If aC < 0   : aC = 0   : ElseIf aC > 255 : aC = 255 : EndIf
        If rC < 0   : rC = 0   : ElseIf rC > 255 : rC = 255 : EndIf
        If gC < 0   : gC = 0   : ElseIf gC > 255 : gC = 255 : EndIf
        If bC < 0   : bC = 0   : ElseIf bC > 255 : bC = 255 : EndIf

        *dst32\l = (aC << 24) | (rC << 16) | (gC << 8) | bC
      EndIf
    Next
  Next

  ; --- Libération des buffers
  FreeMemory(*kernel_d)
  FreeMemory(*luma)
EndProcedure


; --- Entrée principale
Procedure NLMBlur(*param.parametre)
  If *param\info_active
    *param\typ      = #FilterType_Blur
    *param\subtype  = #Blur_Adaptive
    *param\name     = "NLM Blur"
    *param\remarque = "Flou basé sur la redondance des motifs"
    *param\info[0]  = "Search radius"
    *param\info[1]  = "Patch radius"
    *param\info[2]  = "h (filter strength)"
    *param\info[3]  = "Mask"
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 30  : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 1   : *param\info_data(1, 1) = 7   : *param\info_data(1, 2) = 3
    *param\info_data(2, 0) = 1   : *param\info_data(2, 1) = 200 : *param\info_data(2, 2) = 12
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 2   : *param\info_data(3, 2) = 0
    ProcedureReturn
  EndIf

  If Filter_BufferPrepare(*param) <> 0
    MultiThread_MT(@NLMBlur_MT())
    macro_Filter_BufferFinalize(3)
  EndIf
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 216
; FirstLine = 147
; Folding = -
; EnableXP
; DPIAware