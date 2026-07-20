

Macro GuidedFilterColor_ComputeIntegral_sp0_SSE2()
; On charge les pointeeurs et dimensions dans des registres
  !mov rsi, [p.p_source1]   ; rsi = *source1
  !mov rdi, [p.p_source2]   ; rdi = *source2
  !movsxd r8, [p.v_lg]      ; r8  = lg (64-bit)
  !movsxd r9, [p.v_ht]      ; r9  = ht (64-bit)
  
  ; --- 1. Le Pixel (0,0) ---
  !mov eax, [rsi]
  !and eax, 0xFF
  !cvtsi2ss xmm0, eax       
  !movss [rdi], xmm0        
  
  ; --- 2. La Première Ligne (y = 0, x > 0) ---
  !mov rcx, 1               ; rcx = x = 1
  !GuidedFilterColor_ComputeIntegral_sp0_SSE2_loop_line1_#MacroExpandedCount:
  !cmp rcx, r8
  !jge GuidedFilterColor_ComputeIntegral_sp0_SSE2_end_line1_#MacroExpandedCount
    !mov eax, [rsi + rcx*4] 
    !and eax, 0xFF
    !cvtsi2ss xmm0, eax     
    !movss xmm1, [rdi + rcx*4 - 4] 
    !addss xmm0, xmm1       
    !movss [rdi + rcx*4], xmm0
    !inc rcx
    !jmp GuidedFilterColor_ComputeIntegral_sp0_SSE2_loop_line1_#MacroExpandedCount
  !GuidedFilterColor_ComputeIntegral_sp0_SSE2_end_line1_#MacroExpandedCount:

  ; --- 3. La Première Colonne (x = 0, y > 0) ---
  !mov rbx, r8              ; rbx = pos1 = lg
  !mov rcx, 1               ; rcx = y = 1
  !GuidedFilterColor_ComputeIntegral_sp0_SSE2_loop_col1_#MacroExpandedCount:
  !cmp rcx, r9
  !jge GuidedFilterColor_ComputeIntegral_sp0_SSE2_end_col1_#MacroExpandedCount
    !mov eax, [rsi + rbx*4] 
    !and eax, 0xFF
    !cvtsi2ss xmm0, eax
    
    !mov rdx, rbx           
    !sub rdx, r8
    !movss xmm1, [rdi + rdx*4] 
    
    !addss xmm0, xmm1
    !movss [rdi + rbx*4], xmm0
    
    !add rbx, r8            
    !inc rcx                
    !jmp GuidedFilterColor_ComputeIntegral_sp0_SSE2_loop_col1_#MacroExpandedCount
  !GuidedFilterColor_ComputeIntegral_sp0_SSE2_end_col1_#MacroExpandedCount:

  ; --- 4. Le Cœur de l'image (x > 0, y > 0) ---
  !mov rbx, r8              ; rbx = pos1 = lg
  !mov rcx, 1               ; rcx = y = 1
  !GuidedFilterColor_ComputeIntegral_sp0_SSE2_loop_y_#MacroExpandedCount:
  !cmp rcx, r9
  !jge GuidedFilterColor_ComputeIntegral_sp0_SSE2_end_y_#MacroExpandedCount
    !mov rdx, 1             ; rdx = x = 1
    !GuidedFilterColor_ComputeIntegral_sp0_SSE2_loop_x_#MacroExpandedCount:
    !cmp rdx, r8
    !jge GuidedFilterColor_ComputeIntegral_sp0_SSE2_end_x_#MacroExpandedCount
      !mov r10, rbx         
      !add r10, rdx
      
      ; var
      !mov eax, [rsi + r10*4]
      !and eax, 0xFF
      !cvtsi2ss xmm0, eax   
      
      ; top (pos2 - lg)
      !mov r11, r10
      !sub r11, r8
      !movss xmm1, [rdi + r11*4]
      !addss xmm0, xmm1     
      
      ; left (pos2 - 1)
      !movss xmm2, [rdi + r10*4 - 4]
      !addss xmm0, xmm2     
      
      ; tf (pos2 - lg - 1)
      !dec r11
      !movss xmm3, [rdi + r11*4]
      !subss xmm0, xmm3     
      
      ; Sauvegarde
      !movss [rdi + r10*4], xmm0
      
      !inc rdx              
      !jmp GuidedFilterColor_ComputeIntegral_sp0_SSE2_loop_x_#MacroExpandedCount
    !GuidedFilterColor_ComputeIntegral_sp0_SSE2_end_x_#MacroExpandedCount:
    !add rbx, r8            
    !inc rcx                
    !jmp GuidedFilterColor_ComputeIntegral_sp0_SSE2_loop_y_#MacroExpandedCount
  !GuidedFilterColor_ComputeIntegral_sp0_SSE2_end_y_#MacroExpandedCount:
EndMacro

Procedure GuidedFilterColor_ComputeIntegral_SSE2(*FilterCtx.FilterParams)
  Protected x, y, pos1 , pos2 , var
  Protected top.f, left.f, tf.f
  Protected lg = *FilterCtx\image_lg[0]
  Protected ht = *FilterCtx\image_ht[0]
  If lg <= 0 Or ht <= 0 : ProcedureReturn : EndIf
  Protected *source1.pixelArray
  Protected *source2.FloatArray
  *source1.pixelArray = *FilterCtx\addr[3]
  *source2.FloatArray = *FilterCtx\addr[6]
  GuidedFilterColor_ComputeIntegral_sp0_SSE2()
  *source1.pixelArray = *FilterCtx\addr[4]
  *source2.FloatArray = *FilterCtx\addr[7]
  GuidedFilterColor_ComputeIntegral_sp0_SSE2()
  *source1.pixelArray = *FilterCtx\addr[5]
  *source2.FloatArray = *FilterCtx\addr[8]
  GuidedFilterColor_ComputeIntegral_sp0_SSE2()
EndProcedure

;--

Procedure GuidedFilterColor_SP2_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected tt = lg * ht
    macro_calul_tread(tt)
    Protected *I_R.pixelarray  = \addr[3]
    Protected *I_G.pixelarray  = \addr[4]
    Protected *I_B.pixelarray  = \addr[5]
    Protected *tmpR.floatarray = \addr[12]
    Protected *tmpG.floatarray = \addr[13]
    Protected *tmpB.floatarray = \addr[14]
    Protected thread_start_64.q = thread_start
    Protected thread_stop_64.q  = thread_stop
  EndWith
  
  !mov rsi, [p.p_I_R]            ; rsi = *I_R
  !mov rdi, [p.p_I_G]            ; rdi = *I_G
  !mov rbp, [p.p_I_B]            ; rbp = *I_B
  
  !mov rbx, [p.p_tmpR]          ; rbx = *tmpR
  !mov r12, [p.p_tmpG]          ; r12 = *tmpG
  !mov r13, [p.p_tmpB]          ; r13 = *tmpB
  
  !mov rcx, [p.v_thread_start_64] ; rcx = i = thread_start
  !mov rdx, [p.v_thread_stop_64]  ; rdx = thread_stop
  
  ; =====================================================================
  ; BOUCLE PIXEL PAR PIXEL (SCALAIRE SSE2)
  ; =====================================================================
  !GuidedFilterColor_Scalar:
      !cmp rcx, rdx
      !jge GuidedFilterColor_End
      ; --- Chargement des canaux (8 bits) dans des registres valides ---
      !movzx eax, byte [rsi + rcx*4]  ; eax = R (0x000000RR)
      !movzx r8d, byte [rdi + rcx*4]  ; r8d = G (0x000000GG)
      !movzx r9d, byte [rbp + rcx*4]  ; r9d = B (0x000000BB)
      ; --- Construction du registre vectoriel (Entiers 32 bits) ---
      !pxor xmm1, xmm1
      !pinsrw xmm1, r9d, 0            ; xmm1 = [ 0 | 0 | 0 | B ] (en Dwords 32 bits)
      !pinsrw xmm1, r8d, 2            ; xmm1 = [ 0 | 0 | G | B ]
      !pinsrw xmm1, eax, 4            ; xmm1 = [ 0 | R | G | B ]
      !cvtdq2ps xmm1, xmm1            ; xmm1 = [ 0.0 | R.0 | G.0 | B.0 ]
      ; --- Calcul du carré (var * var) ---
      !movaps xmm0, xmm1              ; xmm0 = copie des floats originaux [ 0 | R | G | B ]
      !mulps xmm1, xmm1               ; xmm1 = carrés [ 0 | R*R | G*G | B*B ]
      
      !movss [r13 + rcx*4], xmm1      ; movss extrait le float du bas (index 0 -> B*B)
      !psrldq xmm1, 4
      !movss [r12 + rcx*4], xmm1      ; Sauvegarde G*G
      !psrldq xmm1, 4
      !movss [rbx + rcx*4], xmm1      ; Sauvegarde R*R
      !inc rcx                        ; i++ (Pixel suivant)
      !jmp GuidedFilterColor_Scalar
  
  !GuidedFilterColor_End:
EndProcedure

;--

Procedure GuidedFilterColor_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]
    Protected eps.f = \option[1]
    
    Protected x, y, pos, lgMinus1 = lg - 1
    Protected x0, y0, x1, y1
    Protected.f currentArea, invArea, un.f = 1.0, zero.f = 0.0
    
    Protected *cible.pixelarray = \addr[1]
    Protected *sourceIR   = \addr[3]
    Protected *sourceIG   = \addr[4]
    Protected *sourceIB   = \addr[5]
    Protected *sourceINTR  = \addr[6]
    Protected *sourceINTG  = \addr[7]
    Protected *sourceINTB  = \addr[8]
    Protected *sourceINTRR = \addr[9]
    Protected *sourceINTGG = \addr[10]
    Protected *sourceINTBB = \addr[11]
    
    ; Variables temporaires pour l'ASM
    Protected.q offset_A, offset_B, offset_C, offset_D
    Protected.l rc, gc, bc
    
    macro_calul_tread(ht)

    For y = thread_start To thread_stop - 1
      y0 = y - radius : If y0 < 0 : y0 = 0 : EndIf
      y1 = y + radius : If y1 >= ht : y1 = ht - 1 : EndIf
      
      Protected y0_lg_minus = (y0 - 1) * lg
      Protected y1_lg = y1 * lg
      Protected y_lg = y * lg
      
      For x = 0 To lgMinus1
        x0 = x - radius : If x0 < 0 : x0 = 0 : EndIf
        x1 = x + radius : If x1 >= lg : x1 = lg - 1 : EndIf
        
        currentArea = (x1 - x0 + 1) * (y1 - y0 + 1)
        invArea = 1.0 / currentArea
        
        ; --- PRE-CALCUL DES OFFSETS MEMOIRE ---
        offset_A = (y0_lg_minus + (x0 - 1)) * 4
        offset_B = (y1_lg + (x0 - 1)) * 4
        offset_C = (y0_lg_minus + x1) * 4
        offset_D = (y1_lg + x1) * 4
        pos = (y_lg + x)
        
        !mov r8, [p.v_offset_D]
        !mov r9, [p.v_offset_B]
        !mov r10, [p.v_offset_C]
        !mov r11, [p.v_offset_A]
        
        !movss xmm6, [p.v_eps]
        !movss xmm7, [p.v_invArea]
        !movss xmm5, [p.v_zero]
        
        ; =====================================================================
        ; CANAL ROUGE (rc)
        ; =====================================================================
        !mov rdx, [p.p_sourceINTR]
        !movss xmm0, [rdx + r8] ; D
        
        !cmp dword [p.v_x0], 0
        !jle .skip_x0_R
        !subss xmm0, [rdx + r9] ; D - B
        !cmp dword [p.v_y0], 0
        !jle .skip_y0_R
        !subss xmm0, [rdx + r10] ; D - B - C
        !addss xmm0, [rdx + r11] ; D - B - C + A
        !jmp .calc_meanI_R
        !.skip_x0_R:
        !cmp dword [p.v_y0], 0
        !jle .calc_meanI_R
        !subss xmm0, [rdx + r10] ; D - C
        !.skip_y0_R:             ; <-- Ajouté suite au message précédent
        !.calc_meanI_R:
        !mulss xmm0, xmm7        ; xmm0 = meanI
        
        ; --- Image intégrale 2 (meanII) ---
        !mov rdx, [p.p_sourceINTRR]
        !movss xmm1, [rdx + r8] ; D
        !cmp dword [p.v_x0], 0
        !jle .skip_x0_RR
        !subss xmm1, [rdx + r9] ; D - B
        !cmp dword [p.v_y0], 0
        !jle .skip_y0_RR
        !subss xmm1, [rdx + r10] ; D - B - C
        !addss xmm1, [rdx + r11] ; D - B - C + A
        !jmp .calc_meanII_R
        !.skip_x0_RR:
        !cmp dword [p.v_y0], 0
        !jle .calc_meanII_R
        !subss xmm1, [rdx + r10] ; D - C
        !.skip_y0_RR:
        !.calc_meanII_R:
        !mulss xmm1, xmm7        ; xmm1 = meanII
        
        ; --- Filtre et calcul final R ---
        !movss xmm2, xmm0
        !mulss xmm2, xmm2        ; meanI * meanI
        !subss xmm1, xmm2        ; varI = meanII - meanI*meanI
        !maxss xmm1, xmm5        ; If varI < 0 : varI = 0
        
        !movss xmm2, xmm1
        !addss xmm2, xmm6        ; varI + eps
        !divss xmm1, xmm2        ; xmm1 = a = varI / (varI + eps)
        
        !movss xmm2, xmm1
        !mulss xmm2, xmm0        ; a * meanI
        !subss xmm0, xmm2        ; xmm0 = b = meanI - a*meanI
        
        !mov rdx, [p.p_sourceIR]
        !mov r14, [p.v_pos]      ; <-- Modifié rsi en r14 pour ne pas corrompre rsi
        !movzx eax, byte [rdx + r14*4] ; nval
        !cvtsi2ss xmm3, eax
        
        !mulss xmm1, xmm3        ; a * nval
        !addss xmm1, xmm0        ; var = a * nval + b
        !cvttss2si eax, xmm1     ; Convertit le float final vers entier
        !mov [p.v_rc], eax
        
        ; =====================================================================
        ; CANAL VERT (gc)
        ; =====================================================================
        !mov rdx, [p.p_sourceINTG]
        !movss xmm0, [rdx + r8]
        !cmp dword [p.v_x0], 0
        !jle .skip_x0_G
        !subss xmm0, [rdx + r9]
        !cmp dword [p.v_y0], 0
        !jle .skip_y0_G
        !subss xmm0, [rdx + r10]
        !addss xmm0, [rdx + r11]
        !jmp .calc_meanI_G
        !.skip_x0_G:
        !cmp dword [p.v_y0], 0
        !jle .calc_meanI_G
        !subss xmm0, [rdx + r10]
        !.skip_y0_G:             ; <-- Corrigé (ajout des ':')
        !.calc_meanI_G:
        !mulss xmm0, xmm7
        
        ; --- Image intégrale 2 (meanII) ---
        !mov rdx, [p.p_sourceINTGG]
        !movss xmm1, [rdx + r8]
        !cmp dword [p.v_x0], 0
        !jle .skip_x0_GG
        !subss xmm1, [rdx + r9]
        !cmp dword [p.v_y0], 0
        !jle .skip_y0_GG
        !subss xmm1, [rdx + r10]
        !addss xmm1, [rdx + r11]
        !jmp .calc_meanII_G
        !.skip_x0_GG:
        !cmp dword [p.v_y0], 0
        !jle .calc_meanII_G
        !subss xmm1, [rdx + r10]
        !.skip_y0_GG:            ; <-- Corrigé (ajout des ':')
        !.calc_meanII_G:
        !mulss xmm1, xmm7
        
        ; --- Filtre et calcul final G ---
        !movss xmm2, xmm0
        !mulss xmm2, xmm2
        !subss xmm1, xmm2
        !maxss xmm1, xmm5
        !movss xmm2, xmm1
        !addss xmm2, xmm6
        !divss xmm1, xmm2
        !movss xmm2, xmm1
        !mulss xmm2, xmm0
        !subss xmm0, xmm2
        !mov rdx, [p.p_sourceIG]
        !movzx eax, byte [rdx + r14*4]
        !cvtsi2ss xmm3, eax
        !mulss xmm1, xmm3
        !addss xmm1, xmm0
        !cvttss2si eax, xmm1
        !mov [p.v_gc], eax
        
        ; =====================================================================
        ; CANAL BLEU (bc)
        ; =====================================================================
        !mov rdx, [p.p_sourceINTB]
        !movss xmm0, [rdx + r8]
        !cmp dword [p.v_x0], 0
        !jle .skip_x0_B
        !subss xmm0, [rdx + r9]
        !cmp dword [p.v_y0], 0
        !jle .skip_y0_B
        !subss xmm0, [rdx + r10]
        !addss xmm0, [rdx + r11]
        !jmp .calc_meanI_B
        !.skip_x0_B:
        !cmp dword [p.v_y0], 0
        !jle .calc_meanI_B
        !subss xmm0, [rdx + r10]
        !.skip_y0_B:             ; <-- Ajouté (étiquette manquante)
        !.calc_meanI_B:
        !mulss xmm0, xmm7
        
        ; --- Image intégrale 2 (meanII) ---
        !mov rdx, [p.p_sourceINTBB]
        !movss xmm1, [rdx + r8]
        !cmp dword [p.v_x0], 0
        !jle .skip_x0_BB
        !subss xmm1, [rdx + r9]
        !cmp dword [p.v_y0], 0
        !jle .skip_y0_BB
        !subss xmm1, [rdx + r10]
        !addss xmm1, [rdx + r11]
        !jmp .calc_meanII_B
        !.skip_x0_BB:
        !cmp dword [p.v_y0], 0
        !jle .calc_meanII_B
        !subss xmm1, [rdx + r10]
        !.skip_y0_BB:            ; <-- Ajouté (étiquette manquante)
        !.calc_meanII_B:
        !mulss xmm1, xmm7
        
        ; --- Filtre et calcul final B ---
        !movss xmm2, xmm0
        !mulss xmm2, xmm2
        !subss xmm1, xmm2
        !maxss xmm1, xmm5
        !movss xmm2, xmm1
        !addss xmm2, xmm6
        !divss xmm1, xmm2
        !movss xmm2, xmm1
        !mulss xmm2, xmm0
        !subss xmm0, xmm2
        !mov rdx, [p.p_sourceIB]
        !movzx eax, byte [rdx + r14*4]
        !cvtsi2ss xmm3, eax
        !mulss xmm1, xmm3
        !addss xmm1, xmm0
        !cvttss2si eax, xmm1
        !mov [p.v_bc], eax

        ; --- CLAMP RGB ET RECONSTRUCTION PIXEL ---
        clamp_rgb(rc , gc , bc)        
        *cible\l[pos] = (rc << 16) | (gc << 8) | bc
      Next
    Next
  EndWith
EndProcedure
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 177
; FirstLine = 374
; Folding = -
; EnableXP
; DPIAware