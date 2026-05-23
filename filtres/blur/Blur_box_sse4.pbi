

Macro BoxBlur_SSE4_X_calcul_noyau() 
    !pxor xmm0, xmm0
    !xor rcx, rcx                ; i = 0
    !BoxBlur_sse4_Calcul_noyau_l_x_kernel:
      !mov r9d  , [rdx + rcx * 4]; r9 = index pourla gestion des bords
      !movd xmm1, [rsi + r9  * 4]; Charger pixel ARGB
      !pmovzxbd xmm1, xmm1       ; 4x8bit -> 4x32bit
      !paddd xmm0, xmm1          ; add + pixel
      !inc rcx
      !cmp ecx, r8d
    !jb BoxBlur_sse4_Calcul_noyau_l_x_kernel
EndMacro

Macro BoxBlur_SSE4_X_write_pixel()
  !movdqa xmm4, xmm0         ; Copie de l'accumulateur
  !pmulld xmm4, xmm3         ; Multiplication 32-bit (SSE4.1)
  !psrld xmm4, 16            ; Division par 65536 (Shift Right)
  !packusdw xmm4, xmm4       ; Saturation 32->16
  !packuswb xmm4, xmm4       ; Saturation 16->8
EndMacro

Macro BoxBlur_SSE4_X_sub_pixel()
  !mov r9d  , [rdx + rbx * 4]
  !movd xmm1, [rsi + r9  * 4]
  !pmovzxbd xmm1, xmm1
  !psubd xmm0, xmm1
EndMacro

Macro BoxBlur_SSE4_X_add_pixel()
  !mov r10, rbx
  !add r10, r8               
  !mov r9d  , [rdx + r10 * 4]
  !movd xmm1, [rsi + r9  * 4]
  !pmovzxbd xmm1, xmm1
  !paddd xmm0, xmm1
EndMacro

Procedure BoxBlur_SSE4_X(*FilterCtx.FilterParams) 
  With *FilterCtx
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]
    Protected *source = \addr[0]
    Protected *cible = \addr[1]
    Protected index = \addr[2]
    Protected optx = \option[0]
    optx = (optx << 1) + 1
    Protected.l Blur = 65536 / optx 
  EndWith
  macro_calul_tread(ht)                ; calcule la portion d'image à traiter pour chaque thread
  
  push_reg(FilterCtx.FilterParams)
  Push_Reg_XMM(FilterCtx.FilterParams)

  !mov rdx, [p.v_index]           ; rdx = Table d'indices (addr[2])
  !mov r8d, [p.v_optx]         ; r8d = Taille de la fenêtre (kernel)
  !movd xmm3, [p.v_Blur]
  !PSHUFD xmm3, xmm3, 0          ; xmm3 = [Blur, Blur, Blur, Blur]
  
  !mov r12d, [p.v_thread_start]
  !BoxBlur_SSE4_X_Y_Loop:
    ; Calcul de l'adresse de ligne : *nsrc = *scr + (y * lg * 4)
    !mov eax, [p.v_lg]
    !imul eax, r12d
    !shl rax, 2
    !mov rsi, [p.p_source]
    !add rsi, rax                ; rsi = pointeur ligne source
    !mov rdi, [p.p_cible]
    !add rdi, rax                ; rdi = pointeur ligne destination
    
    BoxBlur_SSE4_X_calcul_noyau() 
    BoxBlur_SSE4_X_write_pixel()
    !movd [rdi], xmm4; nouveau pixel

    !xor rbx, rbx 
    !BoxBlur_SSE4_X_l_x_sliding_00:
      BoxBlur_SSE4_X_sub_pixel()
      BoxBlur_SSE4_X_add_pixel()
      BoxBlur_SSE4_X_write_pixel()
      !movd [rdi + rbx * 4], xmm4; nouveau pixel
       !inc rbx
      !cmp ebx, [p.v_lg]
    !jb BoxBlur_SSE4_X_l_x_sliding_00
      
    !inc r12d
    !cmp r12d, [p.v_thread_stop]
  !jb BoxBlur_SSE4_X_Y_Loop
  
  pop_reg_xmm(FilterCtx.FilterParams)
  pop_reg(FilterCtx.FilterParams)
EndProcedure


;--


Macro BoxBlur_SSE4_Y_Extract_And_Add(target_reg, imm_index, op)
  !pshufd xmm1, xmm0, imm_index
  !pmovzxbd xmm1, xmm1 ; 4x8 bits (= pixel 32 bits a(8)r(8)g(8)b(8) ) => 4x32 bits (= pixel 128 bits a(32)r(32)g(32)b(32) )
  !op target_reg, xmm1
EndMacro

; --- Accumulation du noyau initial ---
Macro BoxBlur_SSE4_Y_calcul_noyau()
  !pxor xmm10, xmm10
  !pxor xmm11, xmm11
  !pxor xmm12, xmm12
  !pxor xmm13, xmm13
  !xor rcx, rcx
  !BoxBlur_SSE4_Y_calcul_noyau#MacroExpandedCount:
    !mov r9d, [rdx + rcx * 4]
    !imul r9d, r11d
    !movdqu xmm0, [rsi + r9]
    
    !pmovzxbd xmm1, xmm0
    !paddd xmm10, xmm1
    BoxBlur_SSE4_Y_Extract_And_Add(xmm11, 1, paddd)
    BoxBlur_SSE4_Y_Extract_And_Add(xmm12, 2, paddd)
    BoxBlur_SSE4_Y_Extract_And_Add(xmm13, 3, paddd)
    
    !inc rcx
    !cmp ecx, r8d
  !jb BoxBlur_SSE4_Y_calcul_noyau#MacroExpandedCount
EndMacro

Macro BoxBlur_SSE4_Y_write_pixel(reg_in)
  !movdqa xmm4, reg_in
  !pmulld xmm4, xmm3
  !psrld xmm4, 16
  !packusdw xmm4, xmm4
  !packuswb xmm4, xmm4
EndMacro

; --- Update des accumulateurs (Sub/Add) ---
; On passe l'offset r9/r10 en paramètre pour plus de clarté
Macro BoxBlur_SSE4_Y_sub_pixel()
  !movdqu xmm0, [rsi + r9]
  !pmovzxbd xmm1, xmm0
  !psubd xmm10, xmm1
  BoxBlur_SSE4_Y_Extract_And_Add(xmm11, 1, psubd)
  BoxBlur_SSE4_Y_Extract_And_Add(xmm12, 2, psubd)
  BoxBlur_SSE4_Y_Extract_And_Add(xmm13, 3, psubd)
EndMacro

Macro BoxBlur_SSE4_Y_add_pixel()
  !movdqu xmm0, [rsi + r9]
  !pmovzxbd xmm1, xmm0
  !paddd xmm10, xmm1
  BoxBlur_SSE4_Y_Extract_And_Add(xmm11, 1, paddd)
  BoxBlur_SSE4_Y_Extract_And_Add(xmm12, 2, paddd)
  BoxBlur_SSE4_Y_Extract_And_Add(xmm13, 3, paddd)
EndMacro

Procedure BoxBlur_SSE4_Y(*FilterCtx.FilterParams)  
  With *FilterCtx
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]
    Protected *source = \addr[0]
    Protected *cible = \addr[1]
    Protected index = \addr[3]      ; Table d'indices verticaux
    Protected opty = \option[1]
    opty = (opty << 1) + 1
    Protected.l Blur = 65536 / opty
    Protected.l stride = lg << 2 ; lg * 4
  EndWith

Protected.l ht_minus_1 = ht - 1
  
  macro_calul_tread(lg)
  Protected.l limit_x4 = thread_start + ((thread_stop - thread_start) / 4) * 4
  
  push_reg(FilterCtx.FilterParams)
  Push_Reg_XMM(FilterCtx.FilterParams)

  !mov rdx, [p.v_index]    ; Table Y
  !mov r8d, [p.v_opty]     ; Kernel size
  !mov r11d, [p.v_stride]  ; Stride
  !movd xmm3, [p.v_Blur]
  !pshufd xmm3, xmm3, 0

  !mov r12d, [p.v_thread_start]
  !BoxBlur_SSE4_Y_Loop_X:
    ; Calcul RSI / RDI initial
    !mov rax, r12
    !shl rax, 2
    !mov rsi, [p.p_source]
    !add rsi, rax
    !mov rdi, [p.p_cible]
    !add rdi, rax
    
    BoxBlur_SSE4_Y_calcul_noyau()
    
    !xor rbx, rbx       ; y = 0
    !xor r14, r14       ; r14 = offset_actuel (y * stride)
    
    !BoxBlur_SSE4_Y_Sliding_Loop:
      ; --- Rendu et Écriture ---
      ; On peut un peu "piper" les écritures pour éviter les stalls
      BoxBlur_SSE4_Y_write_pixel(xmm10)
      !movd [rdi + r14], xmm4
      BoxBlur_SSE4_Y_write_pixel(xmm11)
      !movd [rdi + r14 + 4], xmm4
      BoxBlur_SSE4_Y_write_pixel(xmm12)
      !movd [rdi + r14 + 8], xmm4
      BoxBlur_SSE4_Y_write_pixel(xmm13)
      !movd [rdi + r14 + 12], xmm4
      
      ; --- SUB PIXEL ---
      !mov r9d, [rdx + rbx * 4]
      !imul r9d, r11d
      BoxBlur_SSE4_Y_sub_pixel()
      
      ; --- ADD PIXEL ---
      !mov r10d, ebx
      !add r10d, r8d
      !mov r9d, [rdx + r10 * 4]
      !imul r9d, r11d
      BoxBlur_SSE4_Y_add_pixel()
      
      !add r14, r11        ; offset += stride (Remplace imul !)
      !inc rbx
      !cmp ebx, [p.v_ht]
    !jb BoxBlur_SSE4_Y_Sliding_Loop

    !add r12d, 4
    !cmp r12d, [p.v_limit_x4]
  !jb BoxBlur_SSE4_Y_Loop_X
  
; ==========================================================
  ; BOUCLE DE NETTOYAGE si la largeur de l'image n'est pas un muliple de 4
  ; ==========================================================
  !BoxBlur_SSE4_Y_Cleanup_Loop:
  !cmp r12d, [p.v_thread_stop]
  !jae BoxBlur_SSE4_Y_End          ; Terminé !

  !BoxBlur_SSE4_Y_Loop_X1:
    !mov rax, r12
    !shl rax, 2
    !mov rsi, [p.p_source]
    !add rsi, rax
    !mov rdi, [p.p_cible]
    !add rdi, rax
    
    ; Calcul du noyau pour UNE SEULE colonne (xmm10)
    !pxor xmm10, xmm10
    !xor rcx, rcx
    !BoxBlur_SSE4_Y_Loop_X1_sp1:
      !mov r9d, [rdx + rcx * 4]
      !imul r9d, r11d
      !movd xmm1, [rsi + r9]
      !pmovzxbd xmm1, xmm1
      !paddd xmm10, xmm1
      !inc rcx
      !cmp ecx, r8d
    !jb BoxBlur_SSE4_Y_Loop_X1_sp1

    !xor rbx, rbx
    !xor r14, r14
    !BoxBlur_SSE4_Y_Loop_X1_sp2:
      BoxBlur_SSE4_Y_write_pixel(xmm10)
      !movd [rdi + r14], xmm4
      
      ; Update SUB (xmm10 uniquement)
      !mov r9d, [rdx + rbx * 4]
      !imul r9d, r11d
      !movd xmm1, [rsi + r9]
      !pmovzxbd xmm1, xmm1
      !psubd xmm10, xmm1
      
      ; Update ADD (xmm10 uniquement)
      !mov r10d, ebx
      !add r10d, r8d
      !mov r9d, [rdx + r10 * 4]
      !imul r9d, r11d
      !movd xmm1, [rsi + r9]
      !pmovzxbd xmm1, xmm1
      !paddd xmm10, xmm1
      
      !add r14, r11
      !inc rbx
      !cmp ebx, [p.v_ht]
    !jb BoxBlur_SSE4_Y_Loop_X1_sp2

    !inc r12d
    !cmp r12d, [p.v_thread_stop]
  !jb BoxBlur_SSE4_Y_Loop_X1

  !BoxBlur_SSE4_Y_End:
  
  pop_reg_xmm(FilterCtx.FilterParams)
  pop_reg(FilterCtx.FilterParams)
EndProcedure

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 272
; FirstLine = 238
; Folding = --
; EnableXP
; DPIAware