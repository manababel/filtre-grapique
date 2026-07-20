Macro Blur_IIR_get_rgb_32_sse2(var)
  !movd xmm#var, [r10 + rcx * 4]
  !pxor xmm0, xmm0
  !punpcklbw xmm#var, xmm0         
  !punpcklwd xmm#var, xmm0         
  !cvtdq2ps xmm#var, xmm#var
EndMacro

Macro Blur_IIR_sp1_32_sse2()
Blur_IIR_get_rgb_32_sse2(6)
  !movups xmm7, xmm1
  !mulps xmm1, xmm2            
  !mulps xmm6, xmm3            
  !addps xmm1, xmm6            
  !movups xmm6, xmm1            
  !cvtps2dq xmm6, xmm6
  !packssdw xmm6, xmm6         
  !packuswb xmm6, xmm6         
  !movd dword [r10 + rcx * 4], xmm6
EndMacro

Macro Blur_IIR_blurH_SSE2()
  !mov r10, [p.p_dst32]           ; r10 = p_dst32
  !mov r8, [p.v_thread_start]     ; r8 = y (compteur de ligne)
  !_Blur_IIR_loop_y_h:
    !cmp r8, [p.v_thread_stop]
    !jge _Blur_IIR_end_y_h                 
    ; --- Calcul de mem = y * w ---
    !mov rax, r8                  
    !imul rax, [p.v_w]            
    !mov r11, rax                 ; r11 = mem
    !mov rcx, rax                 ; rcx = pos = mem
    ; 1. Initialisation Aller (Gauche -> Droite)
    Blur_IIR_get_rgb_32_sse2(1)
    !mov r9, 1                    ; r9 = x = 1
    !_Blur_IIR_loop_x_right:
      !cmp r9, [p.v_w]
      !jge _Blur_IIR_end_x_right           
      ; rcx (pos) = r11 (mem) + r9 (x)
      !mov rcx, r11
      !add rcx, r9
      Blur_IIR_sp1_32_sse2()
      !inc r9                     
      !jmp _Blur_IIR_loop_x_right
    !_Blur_IIR_end_x_right:
    ; 2. Initialisation Retour (Droite -> Gauche)
    ; rcx (pos) = r11 (mem) + w - 1
    !mov rcx, r11
    !add rcx, [p.v_w]
    !dec rcx
    Blur_IIR_get_rgb_32_sse2(1)
    ; r9 = w - 2
    !mov r9, [p.v_w]
    !sub r9, 2
    !_Blur_IIR_loop_x_left:
      !cmp r9, 0
      !jl _Blur_IIR_end_x_left             
      ; rcx (pos) = r11 (mem) + r9 (x)
      !mov rcx, r11
      !add rcx, r9
      Blur_IIR_sp1_32_sse2()
      !dec r9                     
      !jmp _Blur_IIR_loop_x_left
    !_Blur_IIR_end_x_left:
    !inc r8                       ; y++
    !jmp _Blur_IIR_loop_y_h
  !_Blur_IIR_end_y_h:
EndMacro

Macro Blur_IIR_blurV_SSE2()
  !mov r10, [p.p_dst32]           ; r10 = p_dst32
  !mov r8, [p.v_thread_start]     ; r8 = x (compteur de colonne)
  !_Blur_IIR_loop_x_v:
    !cmp r8, [p.v_thread_stop]
    !jge _Blur_IIR_end_x_v                 
    ; --- Initialisation Aller (Haut -> Bas) ---
    !mov rcx, r8                  ; rcx = pos = x
    Blur_IIR_get_rgb_32_sse2(1)
    !mov r9, 1                    ; r9 = y = 1
    !_Blur_IIR_loop_y_down:
      !cmp r9, [p.v_h]
      !jge _Blur_IIR_end_y_down            
      ; rcx (pos) = y * w + x
      !mov rcx, r9
      !imul rcx, [p.v_w]
      !add rcx, r8
      Blur_IIR_sp1_32_sse2()
      !inc r9                     ; y++
      !jmp _Blur_IIR_loop_y_down
    !_Blur_IIR_end_y_down:
    ; --- Initialisation Retour (Bas -> Haut) ---
    ; rcx (pos) = (h - 1) * w + x
    !mov rcx, [p.v_h]
    !dec rcx
    !imul rcx, [p.v_w]
    !add rcx, r8  
    Blur_IIR_get_rgb_32_sse2(1)
    ; r9 = h - 2
    !mov r9, [p.v_h]
    !sub r9, 2
    !_Blur_IIR_loop_y_up:
      !cmp r9, 0
      !jl _Blur_IIR_end_y_up               
      ; rcx (pos) = y * w + x
      !mov rcx, r9
      !imul rcx, [p.v_w]
      !add rcx, r8
      Blur_IIR_sp1_32_sse2()
      !dec r9                     ; y--
      !jmp _Blur_IIR_loop_y_up
    !_Blur_IIR_end_y_up:
    !inc r8                       ; x++
    !jmp _Blur_IIR_loop_x_v
  !_Blur_IIR_end_x_v:
EndMacro


Procedure Blur_IIR_sp1_sse2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *dst32 = \addr[1]
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected.f alpha, inv_alpha
    macro_calul_tread(h)
    alpha = Exp(-2.3 / (\option[0] + 1.0))
    inv_alpha = 1.0 - alpha
    
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    !movss xmm2, [p.v_alpha]       
    !shufps xmm2, xmm2, 0          
    !movss xmm3, [p.v_inv_alpha]   
    !shufps xmm3, xmm3, 0          
    Blur_IIR_blurH_sse2()
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
  EndWith
EndProcedure

Procedure Blur_IIR_sp2_sse2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *dst32 = \addr[1]
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected.f alpha, inv_alpha
    macro_calul_tread(w)
    alpha = Exp(-2.3 / (\option[1] + 1.0))
    inv_alpha = 1.0 - alpha
    
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    !movss xmm2, [p.v_alpha]       
    !shufps xmm2, xmm2, 0          
    !movss xmm3, [p.v_inv_alpha]   
    !shufps xmm3, xmm3, 0          
    Blur_IIR_blurV_sse2()
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
  EndWith
EndProcedure
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 150
; FirstLine = 111
; Folding = --
; EnableXP
; DPIAware