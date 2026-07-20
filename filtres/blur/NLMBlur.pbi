; ---------------------------------------------------
; (approx distance luminance + patch kernel)
; ARGB32, multithreaded
; ---------------------------------------------------

Procedure NLM_PrecomputePatchKernel(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected patchRadius = \option[1]
    Protected PS = 2 * patchRadius + 1
    Protected sigma.d = patchRadius / 2.0
    If sigma <= 0.0 : sigma = 0.5 : EndIf
    Protected twoSigma2.d = 2.0 * sigma * sigma
    Protected sum.d = 0.0
    Protected i, j, idx = 0
    Protected var.f
    Protected *kernel.FloatArray = \addr[2]
    If *kernel = 0 : ProcedureReturn : EndIf
    
    For j = -patchRadius To patchRadius
      For i = -patchRadius To patchRadius
        var = Exp(-(i*i + j*j) / twoSigma2)
        *kernel\f[idx] = var
        sum + var
        idx + 1
      Next
    Next
    
    If sum > 0.0
      Protected invSum.d = 1.0 / sum
      Protected maxIdx = PS * PS - 1
      For idx = 0 To maxIdx
        *kernel\f[idx] * invSum
      Next
    EndIf
  EndWith
EndProcedure

Procedure NLMBlur_Calcul_Lum(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected *lumaPtr.FloatArray = \addr[3]
    Protected *src32.Pixel32
    Protected.l x , y , pPos , rl , gl , bl
    For y = 0 To h - 1
      *src32 = \addr[0] + (y * w) * 4
      For x = 0 To w - 1
        getrgb(*src32\l , rl , gl , bl)
        *lumaPtr\f[pPos] = 0.299 * rl + 0.587 * gl + 0.114 * bl
        pPos + 1
        *src32 + 4
      Next
    Next
  EndWith
EndProcedure

Procedure NLMBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected searchRadius = \option[0]
    Protected patchRadius = \option[1]
    Protected hparam.d = \option[2]
    Protected *src32.Pixel32, *dst32.Pixel32

    ; Cast des pointeurs de mémoire en structures de type tableau pour éviter PeekF/PokeF
    Protected *kPtr.FloatArray = \addr[2]
    Protected *lumaPtr.FloatArray = \addr[3]
    
    Protected rl, gl, bl, y, x, lum.f
    Protected pPos = 0

    macro_calul_tread(h)

    Protected invHSq.d = 1.0 / (hparam * hparam)
    Protected w_minus_1 = w - 1, h_minus_1 = h - 1
    Protected patchDiameter = 2 * patchRadius + 1
    Protected idxKernel, ky, kx, px, py, qx, qy, sx, sy, spos
    Protected aC, rC, gC, bC
    Protected accumA.d, accumR.d, accumG.d, accumB.d, wsum.d
    Protected lumDiff.d, patchDist.d, weight.d
    Protected searchYMin, searchYMax, searchXMin, searchXMax
    Protected *srcSearch.Pixel32
    Protected.l a , r , g , b
    ; On extrait l'adresse de base pour éviter de la recalculer à chaque fois
    Protected *baseSrc = \addr[0]

    For y = thread_start To thread_stop - 1
      ; Optimisation du calcul des limites Y pour le patch complet (évite le IF interne)
      Protected minPy = Max_2(0, y - patchRadius)
      Protected maxPy = Min_2(h_minus_1, y + patchRadius)
      
      For x = 0 To w - 1
        pPos = y * w + x
        *src32 = *baseSrc + pPos * 4
        getargb(*src32 , aC , rC , gC , bC)
        
        accumA = 0.0 : accumR = 0.0 : accumG = 0.0 : accumB = 0.0 : wsum = 0.0
        
        searchYMin = Max_2(0, y - searchRadius)
        searchYMax = Min_2(h_minus_1, y + searchRadius)
        searchXMin = Max_2(0, x - searchRadius)
        searchXMax = Min_2(w_minus_1, x + searchRadius)
        
        For sy = searchYMin To searchYMax
          For sx = searchXMin To searchXMax
            
            patchDist = 0.0 
            idxKernel = 0
            
            ; BOUCLE CRITIQUE OPTIMISÉE : Moins de branches 'If'
            For ky = -patchRadius To patchRadius
              py = y + ky : qy = sy + ky
              
              ; Si on sort des limites verticales, on saute rapidement
              If py < 0 Or py > h_minus_1 Or qy < 0 Or qy > h_minus_1
                idxKernel + patchDiameter 
                Continue
              EndIf
              
              Protected py_w = py * w
              Protected qy_w = qy * w
              
              For kx = -patchRadius To patchRadius
                px = x + kx : qx = sx + kx
                
                If px < 0 Or px > w_minus_1 Or qx < 0 Or qx > w_minus_1
                  idxKernel + 1 
                  Continue
                EndIf
                
                lumDiff = *lumaPtr\f[py_w + px] - *lumaPtr\f[qy_w + qx]
                patchDist + *kPtr\f[idxKernel] * (lumDiff * lumDiff)
                idxKernel + 1
              Next
            Next
            
            weight = Exp(-patchDist * invHSq)
            spos = sy * w + sx
            *srcSearch = *baseSrc + spos * 4
            getargb(*srcSearch\l , a , r , g , b)
            ; Accumulation directe
            wsum + weight
            accumA + a * weight 
            accumR + r * weight
            accumG + g * weight 
            accumB + b * weight
          Next
        Next

        *dst32 = \addr[1] + pPos * 4
        If wsum <= 0.0
          *dst32\l = *src32\l
        Else
          Protected invWsum.d = 1.0 / wsum
          aC = Int(accumA * invWsum + 0.5) 
          rC = Int(accumR * invWsum + 0.5)
          gC = Int(accumG * invWsum + 0.5) 
          bC = Int(accumB * invWsum + 0.5)
          
          clamp_argb(aC, rC , gC , bC)
          
          *dst32\l = (aC << 24) | (rC << 16) | (gC << 8) | bC
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure NLMBlurEx(*FilterCtx.FilterParams)
  With *FilterCtx
    Restore NLMBlur_data
    Protected last_data = Filter_InitAndValidate()
    *FilterCtx\asm_dispo = 0
    If last_data < 0 : ProcedureReturn 0 : EndIf
    
    Protected PS = 2 * \option[1] + 1
    Protected kernelSize = PS * PS
    \addr[2] = 0 : \addr[3] = 0
    \addr[2] = AllocateMemory(kernelSize * 4)
    \addr[3] = AllocateMemory(\image_lg[0] * \image_ht[0] * 4)
    If *FilterCtx\addr[2] And *FilterCtx\addr[3]
      NLM_PrecomputePatchKernel(*FilterCtx)
      NLMBlur_Calcul_Lum(*FilterCtx)
      Create_MultiThread_MT(@NLMBlur_sp())
      mask_update(*FilterCtx, last_data)
    EndIf
    If \addr[2] : FreeMemory(\addr[2]) : EndIf
    If \addr[3] : FreeMemory(\addr[3]) : EndIf
  EndWith
EndProcedure

Procedure NLMBlur(source, cible, mask, searchRadius, patchRadius, hparam)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = searchRadius
    \option[1] = patchRadius
    \option[2] = hparam
  EndWith
  NLMBlurEx(FilterCtx)
EndProcedure

DataSection
  NLMBlur_data:
  Data.s "NLM Blur"
  Data.s "Flou basé sur la redondance des motifs (Non-Local Means)"
  Data.i #FilterType_Blur, #Blur_Adaptive
  Data.s "Search radius"
  Data.i 1, 7, 2
  Data.s "Patch radius"
  Data.i 1, 7, 3
  Data.s "Force"
  Data.i 1, 200, 12
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 213
; FirstLine = 161
; Folding = -
; EnableXP
; DPIAware