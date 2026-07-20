Structure RGBCoeff
  b.f
  g.f
  r.f
  a.f
EndStructure


  
Procedure HeatDiffusionAnisoBlur_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.PixelArray = \addr[0]
    Protected *cible.PixelArray  = \addr[1]
    Protected *lookupTable.FloatArray = \addr[3]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected lambda.f = 0.2
    
    If \option[2] > 0 : lambda = \option[2] * 0.01 : EndIf
    
    Protected x, y
    Protected lgMinus1 = lg - 1
    Protected htMinus1 = ht - 1
    
    Protected stride = lg << 2
    Protected *srcPtr, *dstPtr
    Protected *srcN, *srcS, *srcW, *srcE
    
    macro_calul_tread(ht)
    
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    For y = thread_start To thread_stop - 1
      Protected line_offset = y * lg
      
      *srcPtr = *source + (line_offset << 2)
      *dstPtr = *cible + (line_offset << 2)
      
      If y > 0        : *srcN = *srcPtr - stride : Else : *srcN = *srcPtr : EndIf
      If y < htMinus1 : *srcS = *srcPtr + stride : Else : *srcS = *srcPtr : EndIf
      
      For x = 0 To lgMinus1
        If x > 0        : *srcW = *srcPtr - 4 : Else : *srcW = *srcPtr : EndIf
        If x < lgMinus1 : *srcE = *srcPtr + 4 : Else : *srcE = *srcPtr : EndIf
        
        ; Variables de stockage temporaire des deltas 
        Protected.l dNr, dNg, dNb, dSr, dSg, dSb, dWr, dWg, dWb, dEr, dEg, dEb
        
        ; ----------------------------------------------------
        ; BLOC SSE2 x64 : CHARGEMENT ET CALCUL DES DELTAS
        ; ----------------------------------------------------
        !pxor xmm0, xmm0
        
        ; [Pixel Centre] -> xmm1 (Utilisation stricte de RAX)
        !mov rax, [p.p_srcPtr]
        !movd xmm1, [rax]
        !punpcklbw xmm1, xmm0
        !punpcklwd xmm1, xmm0
        !cvtdq2ps xmm1, xmm1
        
        ; [Voisin Nord] -> xmm2
        !mov rax, [p.p_srcN]
        !movd xmm2, [rax]
        !punpcklbw xmm2, xmm0
        !punpcklwd xmm2, xmm0
        !cvtdq2ps xmm2, xmm2
        
        ; [Voisin Sud] -> xmm3
        !mov rax, [p.p_srcS]
        !movd xmm3, [rax]
        !punpcklbw xmm3, xmm0
        !punpcklwd xmm3, xmm0
        !cvtdq2ps xmm3, xmm3
        
        ; [Voisin Ouest] -> xmm4
        !mov rax, [p.p_srcW]
        !movd xmm4, [rax]
        !punpcklbw xmm4, xmm0
        !punpcklwd xmm4, xmm0
        !cvtdq2ps xmm4, xmm4
        
        ; [Voisin Est] -> xmm5
        !mov rax, [p.p_srcE]
        !movd xmm5, [rax]
        !punpcklbw xmm5, xmm0
        !punpcklwd xmm5, xmm0
        !cvtdq2ps xmm5, xmm5
        
        ; Soustractions (Voisin - Centre)
        !subps xmm2, xmm1 
        !subps xmm3, xmm1 
        !subps xmm4, xmm1 
        !subps xmm5, xmm1 
        
        ; Extraction sécurisée des deltas vers l'espace entier local (Truncate)
        !cvttps2dq xmm6, xmm2
        !movd [p.v_dNb], xmm6
        !psrldq xmm6, 4
        !movd [p.v_dNg], xmm6
        !psrldq xmm6, 4
        !movd [p.v_dNr], xmm6
        
        !cvttps2dq xmm6, xmm3
        !movd [p.v_dSb], xmm6
        !psrldq xmm6, 4
        !movd [p.v_dSg], xmm6
        !psrldq xmm6, 4
        !movd [p.v_dSr], xmm6
        
        !cvttps2dq xmm6, xmm4
        !movd [p.v_dWb], xmm6
        !psrldq xmm6, 4
        !movd [p.v_dWg], xmm6
        !psrldq xmm6, 4
        !movd [p.v_dWr], xmm6
        
        !cvttps2dq xmm6, xmm5
        !movd [p.v_dEb], xmm6
        !psrldq xmm6, 4
        !movd [p.v_dEg], xmm6
        !psrldq xmm6, 4
        !movd [p.v_dEr], xmm6
        
        ; Traitement Absolu sans saut d'instructions CPU
        If dNr < 0 : dNr = -dNr : EndIf : If dNg < 0 : dNg = -dNg : EndIf : If dNb < 0 : dNb = -dNb : EndIf
        If dSr < 0 : dSr = -dSr : EndIf : If dSg < 0 : dSg = -dSg : EndIf : If dSb < 0 : dSb = -dSb : EndIf
        If dWr < 0 : dWr = -dWr : EndIf : If dWg < 0 : dWg = -dWg : EndIf : If dWb < 0 : dWb = -dWb : EndIf
        If dEr < 0 : dEr = -dEr : EndIf : If dEg < 0 : dEg = -dEg : EndIf : If dEb < 0 : dEb = -dEb : EndIf
        
        ; ----------------------------------------------------
        ; INTERROGATION LOOKUP TABLE ET RECONSTRUCTION DES COEFFICIENTS
        ; ----------------------------------------------------
        Protected.f cNr, cNg, cNb, cSr, cSg, cSb, cWr, cWg, cWb, cEr, cEg, cEb
        cNb = *lookupTable\f[dNb] : cNg = *lookupTable\f[dNg] : cNr = *lookupTable\f[dNr]
        cSb = *lookupTable\f[dSb] : cSg = *lookupTable\f[dSg] : cSr = *lookupTable\f[dSr]
        cWb = *lookupTable\f[dWb] : cWg = *lookupTable\f[dWg] : cWr = *lookupTable\f[dWr]
        cEb = *lookupTable\f[dEb] : cEg = *lookupTable\f[dEg] : cEr = *lookupTable\f[dEr]
        
        ; Injection et Alignement à la volée dans les registres SSE
        !movss xmm6, [p.v_cNb]
        !movss xmm0, [p.v_cNg]
        !unpcklps xmm6, xmm0
        !movss xmm0, [p.v_cNr]
        !movss xmm7, [l_float_one]
        !unpcklps xmm0, xmm7
        !movlhps xmm6, xmm0    
        !mulps xmm2, xmm6      ; Delta N * Coeff N
        
        !movss xmm6, [p.v_cSb]
        !movss xmm0, [p.v_cSg]
        !unpcklps xmm6, xmm0
        !movss xmm0, [p.v_cSr]
        !movss xmm7, [l_float_one]
        !unpcklps xmm0, xmm7
        !movlhps xmm6, xmm0    
        !mulps xmm3, xmm6      ; Delta S * Coeff S
        
        !movss xmm6, [p.v_cWb]
        !movss xmm0, [p.v_cWg]
        !unpcklps xmm6, xmm0
        !movss xmm0, [p.v_cWr]
        !movss xmm7, [l_float_one]
        !unpcklps xmm0, xmm7
        !movlhps xmm6, xmm0    
        !mulps xmm4, xmm6      ; Delta W * Coeff W
        
        !movss xmm6, [p.v_cEb]
        !movss xmm0, [p.v_cEg]
        !unpcklps xmm6, xmm0
        !movss xmm0, [p.v_cEr]
        !movss xmm7, [l_float_one]
        !unpcklps xmm0, xmm7
        !movlhps xmm6, xmm0    
        !mulps xmm5, xmm6      ; Delta E * Coeff E
        
        ; ----------------------------------------------------
        ; INTÉGRATION FLUX + LAMBDA
        ; ----------------------------------------------------
        !movss xmm6, [p.v_lambda]
        !shufps xmm6, xmm6, 0
        
        !addps xmm2, xmm3
        !addps xmm4, xmm5
        !addps xmm2, xmm4
        !mulps xmm2, xmm6      
        !addps xmm1, xmm2      
        
        ; Conversion finale Float -> Byte
        !cvtps2dq xmm1, xmm1
        !pxor xmm0, xmm0
        !packssdw xmm1, xmm0
        !packuswb xmm1, xmm0
        
        ; Écriture 64-bits native du pixel calculé
        !mov rax, [p.p_dstPtr]
        !movd [rax], xmm1
        
        ; Application du masque Alpha à 255 direct en mémoire 64 bits sans index pos
        Protected *alphaFixer.Long = *dstPtr
        *alphaFixer\l = *alphaFixer\l | $FF000000
        
        ; Incrémentation simultanée de tous les pointeurs glissants (mémoire contiguë)
        *srcPtr + 4 : *dstPtr + 4
        *srcN + 4   : *srcS + 4   : *srcW + 4   : *srcE + 4
      Next
    Next
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
  EndWith
  ProcedureReturn
  
EnableASM
  !align 16
  !l_float_one: dd 1.0
DisableASM
EndProcedure

Macro HeatDiffusionAnisoBlur_sp1(var, Nvar, Svar, Wvar, Evar)
  ; Remplacement de Abs() par une soustraction absolue rapide
   diff_N = Nvar - var : If diff_N < 0 : diff_N = -diff_N : EndIf
   diff_S = Svar - var : If diff_S < 0 : diff_S = -diff_S : EndIf
   diff_W = Wvar - var : If diff_W < 0 : diff_W = -diff_W : EndIf
   diff_E = Evar - var : If diff_E < 0 : diff_E = -diff_E : EndIf
  
  ; Accès direct via pointeur structuré sans PeekF
  cN = *lookupTable\f[diff_N]
  cS = *lookupTable\f[diff_S]
  cW = *lookupTable\f[diff_W]
  cE = *lookupTable\f[diff_E]
  
  var + lambda * (cN * (Nvar - var) + cS * (Svar - var) + cW * (Wvar - var) + cE * (Evar - var))
EndMacro

Procedure HeatDiffusionAnisoBlur_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.PixelArray32 = \addr[0]
    Protected *cible.PixelArray32  = \addr[1]
    Protected *lookupTable.FloatArray = \addr[3]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected lambda.f = 0.2
    Protected k.f = 10.0
    If \option[1] > 0 : k = \option[1] : EndIf
    If \option[2] > 0 : lambda = \option[2] * 0.01 : EndIf
    Protected diff_N , diff_S , diff_W , diff_E
    Protected x, y, r, g, b, pos
    Protected Nr, Ng, Nb, Sr, Sg, Sb, Wr, Wg, Wb, Er, Eg, Eb
    Protected cN.f, cS.f, cW.f, cE.f
    Protected lgMinus1 = lg - 1
    Protected htMinus1 = ht - 1
    macro_calul_tread(ht)
    For y = thread_start To thread_stop - 1
      Protected line_offset = y * lg
      For x = 0 To lgMinus1
        pos = line_offset + x
        getrgb(*source\pixel[pos] , r , g , b)
        If y > 0        : getrgb(*source\pixel[pos - lg] , Nr , Ng , Nb) : Else : Nr = r : Ng = g : Nb = b : EndIf
        If y < htMinus1 : getrgb(*source\pixel[pos + lg] , Sr , Sg , Sb) : Else : Sr = r : Sg = g : Sb = b : EndIf
        If x > 0        : getrgb(*source\pixel[pos - 1]  , Wr , Wg , Wb) : Else : Wr = r : Wg = g : Wb = b : EndIf
        If x < lgMinus1 : getrgb(*source\pixel[pos + 1]  , Er , Eg , Eb) : Else : Er = r : Eg = g : Eb = b : EndIf
        HeatDiffusionAnisoBlur_sp1(r, Nr, Sr, Wr, Er)
        HeatDiffusionAnisoBlur_sp1(g, Ng, Sg, Wg, Eg)
        HeatDiffusionAnisoBlur_sp1(b, Nb, Sb, Wb, Eb)
        clamp_rgb(r, g, b)
        *cible\pixel[pos] = $FF000000 | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Macro HeatDiffusionBlurEx_sp(var)
    For i = 1 To iterations
      *FilterCtx\addr[0] = *buf_src
      *FilterCtx\addr[1] = *buf_dst
      Create_MultiThread_MT(@HeatDiffusionAnisoBlur_MT_#var())
      Swap *buf_src, *buf_dst
    Next
EndMacro

Procedure HeatDiffusionBlurEx(*FilterCtx.FilterParams)
  Restore HeatDiffusionBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[0] << 2
    Protected *tempo = AllocateMemory(total)
    If Not *tempo : ProcedureReturn 0 : EndIf
    
    \addr[3] = AllocateMemory(256 << 2)
    If Not \addr[3] : FreeMemory(*tempo) : ProcedureReturn 0 : EndIf
    
    ; Utilisation du pointeur structuré ici aussi
    Protected *lookupTable.FloatArray = \addr[3]
    Protected i
    Protected var.f
    Protected invK.f = 1.0 / \option[1]
    Protected invKSq.f = invK * invK
    
    ; Remplissage direct sans PokeF
    For i = 0 To 255
      var = Exp(-i * i * invKSq)
      *lookupTable\f[i] = var
    Next
    
    CopyMemory(\addr[0], *tempo, total)
    Protected *buf_src = *tempo
    Protected *buf_dst = \addr[1]
    
    Protected iterations = \option[0]
    
    CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
      HeatDiffusionBlurEx_sp(PB)
    CompilerElse
      CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
        Select *FilterCtx\Asm ; Correction de la variable manquante '*'
          Case 1 : HeatDiffusionBlurEx_sp(SSE2)
          Default : HeatDiffusionBlurEx_sp(PB)
        EndSelect
      CompilerElse
        Select *FilterCtx\Asm
          Default : HeatDiffusionBlurEx_sp(PB)
        EndSelect
      CompilerEndIf
    CompilerEndIf
    
    If *buf_src <> \addr[1]
      CopyMemory(*buf_src, \addr[1], total)
    EndIf
    
    FreeMemory(*tempo)
    FreeMemory(\addr[3])
    \addr[3] = 0
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure HeatDiffusionBlur(source, cible, mask, iterations, contraste, lambda_percent)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = iterations
    \option[1] = contraste
    \option[2] = lambda_percent
  EndWith
  HeatDiffusionBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  HeatDiffusionBlur_data:
  Data.s "HeatDiffusionAnisotropic"
  Data.s "Flou anisotrope (Perona-Malik)"
  Data.i #FilterType_Blur
  Data.i #Blur_Gaussian
  Data.s "Itérations"
  Data.i 1, 50, 50
  Data.s "Contraste K"
  Data.i 1, 100, 20
  Data.s "Lambda (%)"
  Data.i 1, 25, 25
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 207
; FirstLine = 168
; Folding = --
; EnableXP
; DPIAware
; DisableDebugger