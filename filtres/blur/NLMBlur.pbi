; ---------------------------------------------------
; NLM Blur optimisé (approx distance luminance + patch kernel)
; ARGB32, multithreaded
; ---------------------------------------------------

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

  If sum > 0.0
    Protected invSum.d = 1.0 / sum
    For idx = 0 To PS*PS - 1
      PokeF(*kernel_d + idx * 4, PeekF(*kernel_d + idx * 4) * invSum)
    Next
  EndIf
EndProcedure

Procedure NLMBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0], h = \image_ht[0]
    Protected searchRadius = \option[0], patchRadius = \option[1], hparam.d = \option[2]
    Protected *src32.Pixel32, *dst32.Pixel32
    Protected PS = 2 * patchRadius + 1, kernelSize = PS * PS
    Protected *kernel_d = AllocateMemory(kernelSize * 4)
    If *kernel_d = 0 : ProcedureReturn : EndIf
    NLM_PrecomputePatchKernel(patchRadius, *kernel_d)

    Protected *luma = AllocateMemory(w * h * 4)
    If *luma = 0 : FreeMemory(*kernel_d) : ProcedureReturn : EndIf
    
    Protected rl, gl, bl, y, x, lum.f
    For y = 0 To h - 1
      For x = 0 To w - 1
        *src32 = \addr[0] + (y*w + x) * 4
        getrgb(*src32\l, rl, gl, bl)
        lum = 0.299 * rl + 0.587 * gl + 0.114 * bl
        PokeF(*luma + (y*w + x) * 4, lum)
      Next
    Next

    macro_calul_tread(h)

    Protected invHSq.d = 1.0 / (hparam * hparam)
    Protected w_minus_1 = w - 1, h_minus_1 = h - 1
    Protected patchDiameter = 2 * patchRadius + 1
    Protected idxKernel, ky, kx, px, py, qx, qy, sx, sy, spos, pPos
    Protected aC, rC, gC, bC, aN, rN, gN, bN
    Protected accumA.d, accumR.d, accumG.d, accumB.d, wsum.d
    Protected lumDiff.d, patchDist.d, weight.d, kernelWeight.f, lumaP.f, lumaQ.f
    Protected searchYMin, searchYMax, searchXMin, searchXMax

    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        pPos = y * w + x
        *src32 = \addr[0] + pPos * 4
        aC = (*src32\l >> 24) & $FF : rC = (*src32\l >> 16) & $FF
        gC = (*src32\l >>  8) & $FF : bC =  *src32\l & $FF
        accumA = 0.0 : accumR = 0.0 : accumG = 0.0 : accumB = 0.0 : wsum = 0.0
        searchYMin = Max_2(0, y - searchRadius) : searchYMax = Min_2(h_minus_1, y + searchRadius)
        searchXMin = Max_2(0, x - searchRadius) : searchXMax = Min_2(w_minus_1, x + searchRadius)
        
        For sy = searchYMin To searchYMax
          For sx = searchXMin To searchXMax
            patchDist = 0.0 : idxKernel = 0
            For ky = -patchRadius To patchRadius
              py = y + ky : qy = sy + ky
              If py < 0 Or py > h_minus_1 Or qy < 0 Or qy > h_minus_1
                idxKernel + patchDiameter : Continue
              EndIf
              For kx = -patchRadius To patchRadius
                px = x + kx : qx = sx + kx
                If px < 0 Or px > w_minus_1 Or qx < 0 Or qx > w_minus_1
                  idxKernel + 1 : Continue
                EndIf
                lumaP = PeekF(*luma + (py*w + px) * 4)
                lumaQ = PeekF(*luma + (qy*w + qx) * 4)
                lumDiff = lumaP - lumaQ
                kernelWeight = PeekF(*kernel_d + idxKernel * 4)
                patchDist + kernelWeight * (lumDiff * lumDiff)
                idxKernel + 1
              Next
            Next
            weight = Exp(-patchDist * invHSq)
            spos = sy * w + sx
            *src32 = \addr[0] + spos * 4
            aN = (*src32\l >> 24) & $FF : rN = (*src32\l >> 16) & $FF
            gN = (*src32\l >>  8) & $FF : bN =  *src32\l & $FF
            accumA + aN * weight : accumR + rN * weight
            accumG + gN * weight : accumB + bN * weight
            wsum + weight
          Next
        Next

        *dst32 = \addr[1] + pPos * 4
        If wsum <= 0.0
          *dst32\l = PeekL(\addr[0] + pPos * 4)
        Else
          Protected invWsum.d = 1.0 / wsum
          aC = Int(accumA * invWsum + 0.5) : rC = Int(accumR * invWsum + 0.5)
          gC = Int(accumG * invWsum + 0.5) : bC = Int(accumB * invWsum + 0.5)
          If aC < 0 : aC = 0 : ElseIf aC > 255 : aC = 255 : EndIf
          If rC < 0 : rC = 0 : ElseIf rC > 255 : rC = 255 : EndIf
          If gC < 0 : gC = 0 : ElseIf gC > 255 : gC = 255 : EndIf
          If bC < 0 : bC = 0 : ElseIf bC > 255 : bC = 255 : EndIf
          *dst32\l = (aC << 24) | (rC << 16) | (gC << 8) | bC
        EndIf
      Next
    Next
    FreeMemory(*kernel_d) : FreeMemory(*luma)
  EndWith
EndProcedure

Procedure NLMBlurEx(*FilterCtx.FilterParams)
  Restore NLMBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@NLMBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure NLMBlur(source, cible, mask, searchRadius, patchRadius, hparam, mask_type)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = searchRadius : \option[1] = patchRadius
    \option[2] = hparam       : \option[3] = mask_type
  EndWith
  NLMBlurEx(FilterCtx)
EndProcedure

DataSection
  NLMBlur_data:
  Data.s "NLM Blur"
  Data.s "Flou basé sur la redondance des motifs (Non-Local Means)"
  Data.i #FilterType_Blur, #Blur_Adaptive
  Data.s "Search radius"
  Data.i 1, 30, 10
  Data.s "Patch radius"
  Data.i 1, 7, 3
  Data.s "Force (h)"
  Data.i 1, 200, 12
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 136
; FirstLine = 106
; Folding = -
; EnableXP
; DPIAware