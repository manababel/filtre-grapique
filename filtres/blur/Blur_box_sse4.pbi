

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

Macro BoxBlur_SSE4_Y_calcul_noyau() 
    !pxor xmm0, xmm0
    !xor rcx, rcx
    !BoxBlur_SSE4_Y_l_y_kernel_init:
      !mov r9d, [rdx + rcx * 4]
      !imul r9d, r11d            ; y_index * stride
      !movd xmm1, [rsi + r9]
      !pmovzxbd xmm1, xmm1
      !paddd xmm0, xmm1
      !inc rcx
      !cmp ecx, r8d
    !jb BoxBlur_SSE4_Y_l_y_kernel_init
  EndMacro
  
Macro BoxBlur_SSE4_Y_sub_pixel()
  !mov r9d, [rdx + rbx * 4]   ; Index de ligne (y)
  !imul r9d, r11d             ; Offset = y * stride
  !movd xmm1, [rsi + r9]      ; Lecture verticale
  !pmovzxbd xmm1, xmm1
  !psubd xmm0, xmm1
EndMacro

Macro BoxBlur_SSE4_Y_add_pixel()
  !mov r10d, ebx
  !add r10d, r8d              ; y + kernel_size
  !mov r9d, [rdx + r10 * 4]
  !imul r9d, r11d             ; Offset = (y+k) * stride
  !movd xmm1, [rsi + r9]
  !pmovzxbd xmm1, xmm1
  !paddd xmm0, xmm1
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

  macro_calul_tread(lg)          ; On découpe par colonnes (X)
  push_reg(FilterCtx.FilterParams)
  Push_Reg_XMM(FilterCtx.FilterParams)

  !mov rdx, [p.v_index]             ; rdx = Table d'indices Y
  !mov r8d, [p.v_opty]           ; r8d = Taille du kernel
  !mov r11d, [p.v_stride]        ; r11 = Saut de ligne
  
  ; Préparation du multiplicateur (Entier fixe 16.16)
  !movd xmm3, [p.v_Blur]
  !PSHUFD xmm3, xmm3, 0          ; xmm3 = [Blur, Blur, Blur, Blur]
  
  !mov r12d, [p.v_thread_start]  ; On itère sur les colonnes (X)
  !BoxBlur_SSE4_Y_Loop_X:
    ; Positionnement sur la colonne actuelle
    !mov rax, r12
    !shl rax, 2                  ; x * 4
    !mov rsi, [p.p_source]
    !add rsi, rax                ; rsi pointe sur le premier pixel de la colonne
    !mov rdi, [p.p_cible]
    !add rdi, rax                ; rdi pointe sur la destination
    
    BoxBlur_SSE4_Y_calcul_noyau() 

    !xor rbx, rbx                ; rbx = y = 0
    !BoxBlur_SSE4_X_l_y_sliding_00:
      BoxBlur_SSE4_X_write_pixel() ; Réutilisation de la macro X (le calcul est le même)
      !mov rax, rbx
      !imul eax, r11d            ; y * stride
      !movd [rdi + rax], xmm4    ; Écriture dans la colonne
      BoxBlur_SSE4_Y_sub_pixel()
      BoxBlur_SSE4_Y_add_pixel()
      !inc rbx
      !cmp ebx, [p.v_ht]
    !jb BoxBlur_SSE4_X_l_y_sliding_00

    !inc r12d
    !cmp r12d, [p.v_thread_stop]
  !jb BoxBlur_SSE4_Y_Loop_X
  
  pop_reg_xmm(FilterCtx.FilterParams)
  pop_reg(FilterCtx.FilterParams)
EndProcedure
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 106
; Folding = --
; EnableXP
; DPIAware