

; --- ECRITURE DES 2 PIXELS ---
Macro BoxBlur_AVX2_X_write_pixel()
  !vpmulld ymm4, ymm0, ymm3      ; Somme * Blur (pour les 2 pixels)
  !vpsrld ymm4, ymm4, 16        ; Shift >> 16
  !vpackusdw ymm4, ymm4, ymm4   ; 32b -> 16b (Saturé)
  !vpermq ymm4, ymm4, 0x08      ; Réordonner les lanes pour vpackuswb
  !vpackuswb ymm4, ymm4, ymm4   ; 16b -> 8b (Saturé)
  ; Le résultat (2 pixels ARGB) est maintenant dans les 64 bits de poids faible de xmm4
EndMacro

Macro BoxBlur_AVX2_X_sub_pixels()
  ; Sortie : Pixel i (pour P1) et Pixel i+1 (pour P2)
  !mov r9d, [rdx + rbx * 4]      ; Index base
  !vmovq xmm1, [rsi + r9 * 4]    ; Charge 2 pixels ARGB consécutifs
  !vpmovzxbd ymm1, xmm1          ; [Px_i+1 | Px_i] étendus en 32 bits
  !vpsubd ymm0, ymm0, ymm1
EndMacro

Macro BoxBlur_AVX2_X_add_pixels()
  ; Entrée : Pixel i+r8 (pour P1) et Pixel i+r8+1 (pour P2)
  !mov r10, rbx
  !add r10, r8
  !mov r9d, [rdx + r10 * 4]
  !vmovq xmm1, [rsi + r9 * 4]    ; Charge 2 pixels entrants
  !vpmovzxbd ymm1, xmm1
  !vpaddd ymm0, ymm0, ymm1
EndMacro

; --- ACCUMULATION INITIALE ---
Macro BoxBlur_AVX2_X_calcul_noyau()
  !vpxor ymm0, ymm0, ymm0
  !xor rcx, rcx
  !BoxBlur_avx2_Calcul_noyau_loop:
    ; --- Somme pour Pixel 1 ---
    !mov r9d, [rdx + rcx * 4]
    !vmovd xmm1, [rsi + r9 * 4]
    !vpmovzxbd ymm1, xmm1       ; Étendre 1px ARGB -> 4x32b (bas du YMM)
    !vpaddd ymm0, ymm0, ymm1    ; Accumuler dans les deux lanes (temporairement)
    !inc rcx
    !cmp ecx, r8d
  !jb BoxBlur_avx2_Calcul_noyau_loop

  ; Maintenant ymm0 (low) = Somme P1. 
  ; Copions cela en haut pour P2 et ajustons la fenêtre glissante d'un cran.
  !vinserti128 ymm0, ymm0, xmm0, 1 ; Duplique la somme P1 dans la partie haute

  ; Ajustement spécifique pour le Pixel 2 (Fenêtre décalée de +1)
  ; Soustraire le premier pixel de P1, ajouter le pixel suivant après le noyau de P1
  !mov r9d, [rdx]               ; Index sortant pour P2 (index 0)
  !vmovd xmm1, [rsi + r9 * 4]
  !vpmovzxbd ymm1, xmm1
  !vpsubd xmm2, xmm0, xmm1      ; On travaille sur XMM (partie haute via vinsert après)
  
  !mov r9d, [rdx + rcx * 4]      ; Index entrant pour P2 (index r8d)
  !vmovd xmm1, [rsi + r9 * 4]
  !vpmovzxbd ymm1, xmm1
  !vpaddd xmm2, xmm2, xmm1
  
  !vinserti128 ymm0, ymm0, xmm2, 1 ; ymm0 est maintenant [Somme_P2 | Somme_P1]
EndMacro
  
  Procedure BoxBlur_AVX2_X(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]
    Protected *source = \addr[0]
    Protected *cible = \addr[1]
    Protected index = \addr[2]
    Protected optx = \option[0]
    optx = (optx << 1) + 1
    Protected.l Blur = 65536 / optx 
    
    Protected lg2 = lg - 4
  EndWith
  

  macro_calul_tread(ht)                ; calcule la portion d'image à traiter pour chaque thread
  push_reg(FilterCtx.FilterParams)
  Push_Reg_YMM(FilterCtx.FilterParams)
  
  !mov rdx, [p.v_index]           ; rdx = Table d'indices (addr[2])
  !mov r8d, [p.v_optx]         ; r8d = Taille de la fenêtre (kernel)
  !vmovd xmm3, [p.v_Blur]
  !vpbroadcastd ymm3, xmm3        ; Diffuse Blur sur les 8 slots de 32 bits
  
  !mov r12d, [p.v_thread_start]
  !BoxBlur_AVX2_X_Y_Loop:
    !mov eax, [p.v_lg]
    !imul eax, r12d
    !shl rax, 2
    !mov rsi, [p.p_source]
    !add rsi, rax                ; rsi = pointeur ligne source
    !mov rdi, [p.p_cible]
    !add rdi, rax                ; rdi = pointeur ligne destination

    BoxBlur_AVX2_X_calcul_noyau() 
    BoxBlur_AVX2_X_write_pixel()
    !vmovq [rdi], xmm4            ; Pixel 1 (bas du registre)

    !xor rbx, rbx 
    !BoxBlur_AVX2_X_l_x_sliding:
      
      BoxBlur_AVX2_X_sub_pixels()
      BoxBlur_AVX2_X_add_pixels()
      BoxBlur_AVX2_X_write_pixel()
      !vmovq [rdi + rbx * 4], xmm4  ; Ecriture décalée
      !add rbx, 2
      !cmp ebx, [p.v_lg2]
    !jb BoxBlur_AVX2_X_l_x_sliding
      
    !inc r12d
    !cmp r12d, [p.v_thread_stop]
  !jb BoxBlur_AVX2_X_Y_Loop
  
  pop_reg_ymm(FilterCtx.FilterParams)
  pop_reg(FilterCtx.FilterParams)
EndProcedure

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 102
; FirstLine = 65
; Folding = -
; EnableXP
; DPIAware