

Macro BoxBlur_SSE2_X_calcul_noyau() 
  !pxor xmm0, xmm0              ; Accumulateur (sera en float)
  !xor rcx, rcx                 ; i = 0
  !BoxBlur_SSE2_Calcul_noyau_l_x_kernel:
    !mov r9d  , [rdx + rcx * 4] ; Index
    !movd xmm1, [rsi + r9  * 4] ; Charger pixel ARGB
    !punpcklbw xmm1, xmm5   
    !punpcklwd xmm1, xmm5
    !cvtdq2ps xmm1, xmm1        ; Conversion 4x32bit Int -> 4x32bit Float
    !addps xmm0, xmm1           ; Addition flottante (Vectorisée)
    ;!paddd xmm0,xmm1
    !inc rcx
    !cmp ecx, r8d
  !jb BoxBlur_SSE2_Calcul_noyau_l_x_kernel
EndMacro

Macro BoxBlur_SSE2_X_write_pixel()
  !movaps xmm4, xmm0          ; Copie de l'accumulateur (Float)
  ;!cvtdq2ps xmm4, xmm0
  !mulps xmm4, xmm3           ; xmm3 contient [fBlur, fBlur, fBlur, fBlur]
  !cvtps2dq xmm4, xmm4        ; Conversion Float -> Int 32-bit (arrondi au plus proche)
  !packusdw xmm4, xmm4        ; Saturation 32 -> 16 bits (unsigned)
  !packuswb xmm4, xmm4        ; Saturation 16 -> 8 bits (unsigned)
EndMacro

Macro BoxBlur_SSE2_X_sub_pixel()
  !mov r11, rbx
  !dec r11                    ; r11 = rbx - 1 (le pixel qui sort de la fenêtre)
  !mov r9d, [rdx + r11 * 4]   
  !movd xmm1, [rsi + r9 * 4]
  !punpcklbw xmm1, xmm5       
  !punpcklwd xmm1, xmm5
  !cvtdq2ps xmm1, xmm1
  !subps xmm0, xmm1
  ;!psubd xmm0,xmm1
EndMacro

Macro BoxBlur_SSE2_X_add_pixel()
  !mov r10, rbx
  !add r10, r8
  !dec r10                    ; r10 = rbx + iOptx - 1 (le nouveau pixel qui entre)
  !mov r9d, [rdx + r10 * 4]   
  !movd xmm1, [rsi + r9 * 4]
  !punpcklbw xmm1, xmm5       
  !punpcklwd xmm1, xmm5
  !cvtdq2ps xmm1, xmm1
  !addps xmm0, xmm1
  ;!paddd xmm0,xmm1
EndMacro

Procedure BoxBlur_SSE2_X(*FilterCtx.FilterParams)  
  
  With *FilterCtx
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]
    Protected *source = \addr[0]
    Protected *cible = \addr[1]
    Protected *index = \addr[2]
    Protected.l iOptx = (\option[0] * 2) + 1
    Protected.f fBlur = 1.0 / iOptx 
  EndWith
  
  macro_calul_tread(ht) 
  push_reg(FilterCtx.FilterParams)
  Push_Reg_XMM(FilterCtx.FilterParams)

  !mov rdx, [p.p_index]        ; rdx = Table d'indices
  !mov r8d, [p.v_iOptx]        ; r8d = Taille du noyau (ENTIER)
  !movss xmm3, [p.v_fBlur]     ; xmm3 = [0, 0, 0, Blur]
  !shufps xmm3, xmm3, 0        ; xmm3 = [Blur, Blur, Blur, Blur]
  !pxor xmm5, xmm5
  
  !mov r12d, [p.v_thread_start]
  !BoxBlur_SSE2_X_Y_Loop:
    !mov eax, [p.v_lg]
    !imul eax, r12d
    !shl rax, 2
    !mov rsi, [p.p_source]
    !add rsi, rax                
    !mov rdi, [p.p_cible]
    !add rdi, rax                
    BoxBlur_SSE2_X_calcul_noyau() 
    BoxBlur_SSE2_X_write_pixel()
    !movd [rdi], xmm4
    !mov rbx, 1                  ; On commence à l'index 1
    !BoxBlur_SSE2_X_l_x_sliding_00:
      !cmp ebx, [p.v_lg]
      !jae BoxBlur_SSE2_X_NextLine
      BoxBlur_SSE2_X_sub_pixel()
      BoxBlur_SSE2_X_add_pixel()
      BoxBlur_SSE2_X_write_pixel()
      !movd [rdi + rbx * 4], xmm4
      !inc rbx
      !jmp BoxBlur_SSE2_X_l_x_sliding_00
    !BoxBlur_SSE2_X_NextLine:
    !inc r12d
    !cmp r12d, [p.v_thread_stop]
  !jb BoxBlur_SSE2_X_Y_Loop
  pop_reg_xmm(FilterCtx.FilterParams)
  pop_reg(FilterCtx.FilterParams)
EndProcedure

;--

Macro BoxBlur_SSE2_Y_calcul_noyau() 
  !pxor xmm0, xmm0              ; Accumulateur (float)
  !pxor xmm5, xmm5
  !xor rcx, rcx
  !BoxBlur_SSE2_Y_l_y_kernel_init:
    !mov r9d, [rdx + rcx * 4]
    !imul r9d, r11d             ; y_index * stride
    !movd xmm1, [rsi + r9]      ; Charge 4 octets (BGRA)
    !punpcklbw xmm1, xmm5   
    !punpcklwd xmm1, xmm5     
    !cvtdq2ps xmm1, xmm1        ; Entiers -> Floats
    !addps xmm0, xmm1           ; Accumulation en float
    !inc rcx
    !cmp ecx, r8d
  !jb BoxBlur_SSE2_Y_l_y_kernel_init
EndMacro

Macro BoxBlur_SSE2_Y_sub_pixel()
  !pxor xmm5, xmm5
  !mov r9d, [rdx + rbx * 4]    
  !imul r9d, r11d             
  !movd xmm1, [rsi + r9]      
  !punpcklbw xmm1, xmm5    
  !punpcklwd xmm1, xmm5 
  !cvtdq2ps xmm1, xmm1        ; Conversion float
  !subps xmm0, xmm1           ; Soustraction float
EndMacro

Macro BoxBlur_SSE2_Y_add_pixel()
  !pxor xmm5, xmm5
  !mov r10d, ebx
  !add r10d, r8d              
  !mov r9d, [rdx + r10 * 4]
  !imul r9d, r11d             
  !movd xmm1, [rsi + r9]
  !punpcklbw xmm1, xmm5   
  !punpcklwd xmm1, xmm5
  !cvtdq2ps xmm1, xmm1        ; Conversion float
  !addps xmm0, xmm1           ; Addition float
EndMacro


Procedure BoxBlur_SSE2_Y(*FilterCtx.FilterParams)  
  With *FilterCtx
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]
    Protected *source = \addr[0]
    Protected *cible = \addr[1]
    Protected index = \addr[3]
    Protected.l iOpty = (\option[1] * 2) + 1 
    Protected.f fBlur = 1.0 / iOpty
    Protected.l stride = lg << 2
  EndWith

  macro_calul_tread(lg)  
  push_reg(FilterCtx.FilterParams)
  Push_Reg_XMM(FilterCtx.FilterParams)

  !mov rdx, [p.v_index]      
  !mov r8d, [p.v_iOpty]       ; Utilisation de iOpty pour r8d
  !mov r11d, [p.v_stride]    
  !movss xmm3, [p.v_fBlur]     
  !shufps xmm3, xmm3, 0        
  !pxor xmm5, xmm5
  
  !mov r12d, [p.v_thread_start] 
  !BoxBlur_SSE2_Y_Loop_X:         
    !mov rax, r12
    !shl rax, 2                
    !mov rsi, [p.p_source]
    !add rsi, rax              
    !mov rdi, [p.p_cible]
    !add rdi, rax              
    BoxBlur_SSE2_Y_calcul_noyau() 
    !xor rbx, rbx              
    !BoxBlur_SSE2_Y_sliding:
      BoxBlur_SSE2_X_write_pixel() 
      !mov rax, rbx
      !imul eax, r11d          
      !movd [rdi + rax], xmm4  
      BoxBlur_SSE2_Y_sub_pixel()
      BoxBlur_SSE2_Y_add_pixel()
      !inc rbx
      !cmp ebx, [p.v_ht]
    !jb BoxBlur_SSE2_Y_sliding
    !inc r12d
    !cmp r12d, [p.v_thread_stop]
  !jb BoxBlur_SSE2_Y_Loop_X
  
  pop_reg_xmm(FilterCtx.FilterParams)
  pop_reg(FilterCtx.FilterParams)
EndProcedure

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 59
; Folding = --
; EnableXP
; DPIAware