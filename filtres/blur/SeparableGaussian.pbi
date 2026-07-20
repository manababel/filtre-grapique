; ; --- Utilitaires de noyau ---

; Version pour la version PureBasic (Virgule fixe, retourne des Longs)
Procedure CreateGaussianKernel_Sep(Array kernel.l(1), radius.l, sigma.f)
  If sigma <= 0.0 : sigma = radius / 3.0 : EndIf
  Protected radius_opt = Int(sigma * 3.0 + 0.5)
  If radius_opt < radius : radius = radius_opt : EndIf
  If radius < 1 : radius = 1 : EndIf
  Protected size = radius * 2 + 1
  Dim kernel(size - 1)
  Protected sigma2.f = 2.0 * sigma * sigma
  Dim temp_kernel.f(size - 1)
  Protected sum.f = 0.0
  Protected i, x
  For i = 0 To size - 1
    x = i - radius
    temp_kernel(i) = Exp(-(x * x) / sigma2)
    sum + temp_kernel(i)
  Next
  If sum > 0.0
    For i = 0 To size - 1
      kernel(i) = Int((temp_kernel(i) / sum) * 65536.0 + 0.5)
    Next
  EndIf
EndProcedure

; Nouvelle procédure pour la version SSE2 (Retourne des Floats normalisés)
Procedure CreateGaussianKernel_Sep_Float(Array kernel.f(1), radius.l, sigma.f)
  If sigma <= 0.0 : sigma = radius / 3.0 : EndIf
  Protected radius_opt = Int(sigma * 3.0 + 0.5)
  If radius_opt < radius : radius = radius_opt : EndIf
  If radius < 1 : radius = 1 : EndIf
  Protected size = radius * 2 + 1
  Dim kernel(size - 1)
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

Macro SeparableGaussian_init()
  Protected *source.pixelarray = *FilterCtx\addr[0]
  Protected *cible.pixelarray  = *FilterCtx\addr[1]
  Protected lg = *FilterCtx\image_lg[0]
  Protected ht = *FilterCtx\image_ht[0]
  Protected sigma.f = *FilterCtx\option[1] / 10.0
  Protected radius = CalcEffectiveRadius(*FilterCtx\option[0], sigma)
  Protected size = radius * 2 + 1
  Protected x, y, px , py , pz, i, value
  Protected sumA, sumR, sumG, sumB 
  Protected k
EndMacro

Procedure SeparableGaussian_X_MT_SSE2(*FilterCtx.FilterParams)
  SeparableGaussian_init()
  With *FilterCtx
   Dim kernel.f(size - 1) 
    CreateGaussianKernel_Sep_Float(kernel(), radius, sigma)
    Protected *pKernel.FloatArray = @kernel()
    Protected pixelIn.l, pixelOut.l , posOffset
    Protected k_val.f
    macro_calul_tread(ht)
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    For y = thread_start To thread_stop - 1
      posOffset = y * lg
      For x = 0 To lg - 1
        !pxor xmm0, xmm0
        For i = -radius To radius
          px = x + i
          clamp(px , 0 , (lg-1))
          pixelIn = *source\l[posOffset + px]
          k_val = *pKernel\f[i + radius]
          !pxor xmm3, xmm3
          !movd xmm1, [p.v_pixelIn]     ; xmm1 = [ 0 | 0 | 0 | A R G B ]
          !punpcklbw xmm1, xmm3         ; xmm1 = [ 0 A | 0 R | 0 G | 0 B ] (en mots/words)
          !punpcklwd xmm1, xmm3         ; xmm1 = [ A | R | G | B ] (en entiers/dwords)
          !cvtdq2ps xmm1, xmm1          ; Convertir les 4 canaux en float
          !movss xmm2, [p.v_k_val]      ; Charger le coef du kernel dans le float bas de xmm2
          !shufps xmm2, xmm2, $00       ; CORRECTION : Dupliquer le coef sur les 4 canaux [ K | K | K | K ]
          !mulps xmm1, xmm2             ; [ A*K | R*K | G*K | B*K ]
          !addps xmm0, xmm1             ; Accumuler dans xmm0
        Next
        !cvtps2dq xmm0, xmm0            ; Float -> int
        !packssdw xmm0, xmm0            ; Int -> word (avec saturation)
        !packuswb xmm0, xmm0            ; Word -> byte non-signé (saturation 0-255)
        !movd [p.v_pixelOut], xmm0      ; Extraire le pixel ARGB final
        *cible\l[posOffset + x] = pixelOut
      Next
    Next
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
  EndWith
EndProcedure

Procedure SeparableGaussian_Y_MT_SSE2(*FilterCtx.FilterParams)
  SeparableGaussian_init()
  With *FilterCtx
   Dim kernel.f(size - 1) 
    CreateGaussianKernel_Sep_Float(kernel(), radius, sigma)
    Protected *pKernel.FloatArray = @kernel()
    Protected pixelIn.l, pixelOut.l
    Protected k_val.f
    macro_calul_tread(lg)
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    For x = thread_start To thread_stop - 1
      For y = 0 To ht - 1
        !pxor xmm0, xmm0                
        For i = -radius To radius
          py = y + i
          clamp(py , 0 , (ht - 1))
          pixelIn = *source\l[py * lg + x]
          k_val = *pKernel\f[i + radius]
          !pxor xmm3, xmm3
          !movd xmm1, [p.v_pixelIn]
          !punpcklbw xmm1, xmm3
          !punpcklwd xmm1, xmm3
          !cvtdq2ps xmm1, xmm1
          !movss xmm2, [p.v_k_val]
          !shufps xmm2, xmm2, $00       ; CORRECTION
          !mulps xmm1, xmm2
          !addps xmm0, xmm1
        Next
        !cvtps2dq xmm0, xmm0
        !packssdw xmm0, xmm0
        !packuswb xmm0, xmm0
        !movd [p.v_pixelOut], xmm0
        *cible\l[y * lg + x] = pixelOut
      Next
    Next
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
  EndWith
EndProcedure

; --- Version PureBasic (Virgule fixe) ---

Procedure SeparableGaussian_X_MT_PB(*FilterCtx.FilterParams)
  SeparableGaussian_init()
  Dim kernel.l(size - 1) 
  CreateGaussianKernel_Sep(kernel(), radius, sigma)
  With *FilterCtx
    Protected posOffset
    macro_calul_tread(ht)
    For y = thread_start To thread_stop - 1
      posOffset = y * lg 
      For x = 0 To lg - 1
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
        For i = -radius To radius
          pz = x + i
          clamp(pz , 0 , (lg - 1))
          k = kernel(i + radius)
          value = *source\l[posOffset + pz]
          sumA + ((value >> 24) & $FF) * k
          sumR + ((value >> 16) & $FF) * k
          sumG + ((value >> 8)  & $FF) * k
          sumB + (value         & $FF) * k
        Next 
        *cible\l[posOffset + x] = (((sumA + 32768) >> 16) << 24) |
                                  (((sumR + 32768) >> 16) << 16) |
                                  (((sumG + 32768) >> 16) << 8)  |
                                  ((sumB + 32768) >> 16)
      Next 
    Next 
  EndWith
  FreeArray(kernel()) 
EndProcedure

Procedure SeparableGaussian_Y_MT_PB(*FilterCtx.FilterParams)
  SeparableGaussian_init()
  Dim kernel.l(size - 1) 
  CreateGaussianKernel_Sep(kernel(), radius, sigma)
  With *FilterCtx
    macro_calul_tread(lg)
    For x = thread_start To thread_stop - 1
      For y = 0 To ht - 1
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
        For i = -radius To radius
          pz = y + i
          clamp(pz , 0 , (ht-1))
          k = kernel(i + radius)
          value = *source\l[pz * lg + x]
          sumA + ((value >> 24) & $FF) * k
          sumR + ((value >> 16) & $FF) * k
          sumG + ((value >> 8)  & $FF) * k
          sumB + (value         & $FF) * k
        Next 
        *cible\l[y * lg + x] = (((sumA + 32768) >> 16) << 24) |
                               (((sumR + 32768) >> 16) << 16) |
                               (((sumG + 32768) >> 16) << 8)  |
                               ((sumB + 32768) >> 16)
      Next 
    Next 
  EndWith
  FreeArray(kernel())
EndProcedure


Macro SeparableGaussian_sp(var)
  *FilterCtx\addr[0] = *original_src
  *FilterCtx\addr[1] = *tmp
  Create_MultiThread_MT(@SeparableGaussian_X_MT_#var())
  *FilterCtx\addr[0] = *tmp
  *FilterCtx\addr[1] = *original_dst
  Create_MultiThread_MT(@SeparableGaussian_Y_MT_#var())
EndMacro

Procedure SeparableGaussianEx(*FilterCtx.FilterParams)
  Restore SeparableGaussian_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    If \option[0] < 1 : \option[0] = 1 : EndIf
    If \option[1] = 0 : \option[1] = \option[0] * 10 / 3 : EndIf
    
    Protected sigma_real.f = \option[1] / 10.0
    Protected radius_max = Int(sigma_real * 3.0 + 0.5)
    If radius_max > 50 : radius_max = 50 : EndIf
    If \option[0] > radius_max : \option[0] = radius_max : EndIf
    
    Protected *original_src = \addr[0]
    Protected *original_dst = \addr[1]
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected *tmp = AllocateMemory(lg * ht * 4)
    If Not *tmp : ProcedureReturn : EndIf
    
    CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
      SeparableGaussian_sp(PB)
    CompilerElse
      
      CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
        Select \Asm ; CORRIGÉ : Utilisation directe de \Asm (car dans le bloc With)
          Case 1   : SeparableGaussian_sp(SSE2)
          Default  : SeparableGaussian_sp(PB)
        EndSelect
        
      CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
        
        Select \Asm
          Case 100
          Default  : SeparableGaussian_sp(PB)
        EndSelect
        
      CompilerEndIf
      
    CompilerEndIf
    
    FreeMemory(*tmp)
    \addr[0] = *original_src
    \addr[1] = *original_dst 
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure SeparableGaussian(source, cible, mask, rayon, sigma_x10)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = sigma_x10
  EndWith
  SeparableGaussianEx(FilterCtx.FilterParams)
EndProcedure


DataSection
  SeparableGaussian_data:
  Data.s "SeparableGaussian"
  Data.s "Flou gaussien haute performance (Sépare les axes X et Y)"
  Data.i #FilterType_Blur
  Data.i #Blur_Gaussian
  
  Data.s "Rayon (px)"
  Data.i 1, 50, 5
  Data.s "Sigma x10 (0=auto)"
  Data.i 0, 100, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 151
; FirstLine = 105
; Folding = ---
; EnableXP
; DPIAware