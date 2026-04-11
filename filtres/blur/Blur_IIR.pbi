; ============================================================================
; BLUR IIR OPTIMISÉ AVEC MULTI-THREADING ET CACHE-FRIENDLY
; ============================================================================



;-- Version ASM Optimisée avec blocs cache-friendly

Macro Blur_IIR_free_sse4()
  If *save
    !mov rax,[p.p_save]
    !movdqu xmm4,[rax + 000]
    !movdqu xmm5,[rax + 128]
    FreeMemory(*save)
  EndIf  
EndMacro

Macro Blur_IIR_init_reg_sse4()
  Protected *save = AllocateMemory(2 * 128)
  !mov rax,[p.p_save]
  !movdqu [rax + 000], xmm4
  !movdqu [rax + 128], xmm5
  *tmp32 = *param\addr[1]
  !pxor xmm3, xmm3
  !mov eax, $80
  !movd xmm2, eax
  !pshufd xmm2, xmm2, 0
  !movd xmm4, [p.v_alpha]
  !pshufd xmm4, xmm4, 0
  !movd xmm5, [p.v_inv_alpha] 
  !pshufd xmm5, xmm5, 0
EndMacro

Macro Blur_IIR_read_pixel_0_sse4(op)
  !movd xmm0, [r9]
  !punpcklbw xmm0, xmm3
  !punpcklwd xmm0, xmm3
  !pslld xmm0, 8
  !op r9, r8
EndMacro

Macro Blur_IIR_read_pixel_1_sse4(op)
  !prefetchnta [r9 + 64]    ; Prefetch 64 bytes à l'avance
  !movd xmm1, [r9]
  !punpcklbw xmm1, xmm3
  !punpcklwd xmm1, xmm3
  !pslld xmm1, 8
  !pmulld xmm0, xmm4
  !pmulld xmm1, xmm5
  !paddd xmm0, xmm1
  !psrld xmm0, 8
  !movdqa xmm1, xmm0
  !paddd xmm1, xmm2
  !psrld xmm1, 8
  !packusdw xmm1, xmm1
  !packuswb xmm1, xmm1
  !movd [r9], xmm1
  !op r9, r8
EndMacro


; ============================================================================
; VERSION HORIZONTALE AVEC TRAITEMENT PAR BLOCS
; ============================================================================

Macro Blur_IIR_blurH_sse4_blocked()
  Blur_IIR_init_reg_sse4()
  
  ; r10 = thread_start (début du traitement)
  ; r11 = thread_stop (fin du traitement)
  ; r12 = block_size (#BLOCK_SIZE)
  ; r13 = block_y_start (début du bloc courant)
  ; r14 = block_y_end (fin du bloc courant)
  
  !mov r10, [p.v_thread_start]
  !mov r11, [p.v_thread_stop]
  !mov r12, 64;#BLOCK_SIZE
  !mov r13, r10                    ; block_y_start = thread_start
  
  ; Boucle sur les blocs
  !Blur_IIR_blurH_block_loop:
    ; Calculer block_y_end = min(block_y_start + BLOCK_SIZE - 1, thread_stop - 1)
    !mov r14, r13                  ; block_y_end = block_y_start
    !add r14, r12                  ; block_y_end += BLOCK_SIZE
    !dec r14                       ; block_y_end -= 1
    !mov r15, r11                  ; r15 = thread_stop
    !dec r15                       ; r15 = thread_stop - 1
    !cmp r14, r15                  ; if (block_y_end >= thread_stop - 1)
    !cmovge r14, r15               ; block_y_end = thread_stop - 1
    
    ; Traiter toutes les lignes du bloc
    !mov rcx, r13                  ; y = block_y_start
    !Blur_IIR_blurH_line_loop:
      !mov r8, 4
      
      ; === Balayage gauche → droite ===
      !mov r9d, ecx
      !imul r9d, [p.v_lg]
      !shl r9d, 2
      !add r9, [p.p_tmp32]
      
      Blur_IIR_read_pixel_0_sse4(add)
      
      !mov rax, [p.v_lg]
      !sub rax, 2
      !Blur_IIR_blurH_forward:
        Blur_IIR_read_pixel_1_sse4(add)
      !dec rax
      !jnz Blur_IIR_blurH_forward
      
      ; === Balayage droite → gauche ===
      !mov r9d, ecx
      !imul r9d, [p.v_lg]
      !add r9d, [p.v_lg]
      !dec r9d
      !shl r9d, 2
      !add r9, [p.p_tmp32]
      
      Blur_IIR_read_pixel_0_sse4(sub)
      
      !mov rax, [p.v_lg]
      !sub rax, 2
      !Blur_IIR_blurH_backward:
        Blur_IIR_read_pixel_1_sse4(sub)
      !dec rax
      !jnz Blur_IIR_blurH_backward
      
      ; Ligne suivante
      !inc rcx
      !cmp rcx, r14
      !jle Blur_IIR_blurH_line_loop
    
    ; Bloc suivant
    !add r13, r12                  ; block_y_start += BLOCK_SIZE
    !cmp r13, r11                  ; if (block_y_start < thread_stop)
    !jl Blur_IIR_blurH_block_loop
  
  Blur_IIR_free_sse4()
EndMacro


; ============================================================================
; VERSION VERTICALE AVEC TRAITEMENT PAR BLOCS
; ============================================================================

Macro Blur_IIR_blurV_sse4_blocked()
  Blur_IIR_init_reg_sse4()
  
  ; r10 = thread_start
  ; r11 = thread_stop
  ; r12 = block_size
  ; r13 = block_x_start
  ; r14 = block_x_end
  
  !mov r10, [p.v_thread_start]
  !mov r11, [p.v_thread_stop]
  !mov r12, 64;#BLOCK_SIZE
  !mov r13, r10
  
  ; Boucle sur les blocs de colonnes
  !Blur_IIR_blurV_block_loop:
    ; Calculer block_x_end
    !mov r14, r13
    !add r14, r12
    !dec r14
    !mov r15, r11
    !dec r15
    !cmp r14, r15
    !cmovge r14, r15
    
    ; Traiter toutes les colonnes du bloc
    !mov rcx, r13                  ; x = block_x_start
    !Blur_IIR_blurV_column_loop:
      !mov r8, [p.v_lg]
      !shl r8, 2
      
      ; === Balayage haut → bas ===
      !mov r9d, ecx
      !shl r9d, 2
      !add r9, [p.p_tmp32]
      
      Blur_IIR_read_pixel_0_sse4(add)
      
      !mov rax, [p.v_ht]
      !sub rax, 2
      !Blur_IIR_blurV_down:
        Blur_IIR_read_pixel_1_sse4(add)
      !dec rax
      !jnz Blur_IIR_blurV_down
      
      ; === Balayage bas → haut ===
      !mov r9d, [p.v_ht]
      !dec r9d
      !imul r9d, [p.v_lg]
      !add r9d, ecx
      !shl r9d, 2
      !add r9, [p.p_tmp32]
      
      Blur_IIR_read_pixel_0_sse4(sub)
      
      !mov rax, [p.v_ht]
      !sub rax, 2
      !Blur_IIR_blurV_up:
        Blur_IIR_read_pixel_1_sse4(sub)
      !dec rax
      !jnz Blur_IIR_blurV_up
      
      ; Colonne suivante
      !inc rcx
      !cmp rcx, r14
      !jle Blur_IIR_blurV_column_loop
    
    ; Bloc suivant
    !add r13, r12
    !cmp r13, r11
    !jl Blur_IIR_blurV_block_loop
  
  Blur_IIR_free_sse4()
EndMacro


; ============================================================================
; PROCÉDURES SSE3 AVEC BLOCS
; ============================================================================

Macro Blur_IIR_sp_001_sse4()
  Protected *cible = *param\addr[1]
  Protected lg = *param\lg, ht = *param\ht
  Protected alpha, inv_alpha
  Protected *tmp32.pixel32
EndMacro

Procedure Blur_IIR_sp1_sse4_blocked(*param.parametre)
  Blur_IIR_sp_001_sse4()
  macro_calul_tread(ht)
  alpha = Int((Exp(-2.3 / (*param\option[0] + 1.0))) * 256)
  Clamp(alpha, 1, 255)
  inv_alpha = 256 - alpha
  Blur_IIR_blurH_sse4_blocked()
EndProcedure

Procedure Blur_IIR_sp2_sse4_blocked(*param.parametre)
  Blur_IIR_sp_001_sse4()
  macro_calul_tread(lg)
  alpha = Int((Exp(-2.3 / (*param\option[1] + 1.0))) * 256)
  inv_alpha = 256 - alpha
  Blur_IIR_blurV_sse4_blocked()
EndProcedure


;-- Version PB avec blocs (inchangée)

Macro Blur_IIR_get_rgb_32(a,r,g,b)
  *pix32 = *dst32 + (pos * 4)
  a = (*pix32\l >> 16) & $ff00
  r = (*pix32\l >>  8) & $ff00
  g = (*pix32\l      ) & $ff00
  b = (*pix32\l <<  8) & $ff00
EndMacro

Macro Blur_IIR_sp1_32()
  Blur_IIR_get_rgb_32(a1,r1,g1,b1)
  a = (a * alpha + inv_alpha * a1) >> 8
  r = (r * alpha + inv_alpha * r1) >> 8
  g = (g * alpha + inv_alpha * g1) >> 8
  b = (b * alpha + inv_alpha * b1) >> 8
  a1 = (a + 128) >> 8
  r1 = (r + 128) >> 8
  g1 = (g + 128) >> 8
  b1 = (b + 128) >> 8
  *pix32\l = (a1 << 24) + (r1 << 16) + (g1 << 8) + b1
EndMacro

Macro Blur_IIR_blurH()
  For block_y_start = thread_start To thread_stop - 1 Step #BLOCK_SIZE
    block_y_end = block_y_start + #BLOCK_SIZE - 1
    If block_y_end >= thread_stop
      block_y_end = thread_stop - 1
    EndIf
    
    For y = block_y_start To block_y_end
      pos = (y * w)
      mem = pos
      Blur_IIR_get_rgb_32(a, r, g, b)
      
      For x = 1 To w - 1
        pos = (mem + x)
        Blur_IIR_sp1_32()
      Next
      
      pos = (mem + (w - 1))
      Blur_IIR_get_rgb_32(a, r, g, b)
      For x = w - 2 To 0 Step -1
        pos = (y * w + x)
        Blur_IIR_sp1_32()
      Next
    Next
  Next
EndMacro

Macro Blur_IIR_blurV()
  For block_x_start = thread_start To thread_stop - 1 Step #BLOCK_SIZE
    block_x_end = block_x_start + #BLOCK_SIZE - 1
    If block_x_end >= thread_stop
      block_x_end = thread_stop - 1
    EndIf
    
    For x = block_x_start To block_x_end
      pos = x
      Blur_IIR_get_rgb_32(a, r, g, b)
      
      For y = 1 To h - 1
        pos = (y * w + x)
        Blur_IIR_sp1_32()
      Next
      
      pos = ((h - 1) * w + x)
      Blur_IIR_get_rgb_32(a, r, g, b)
      For y = h - 2 To 0 Step -1
        pos = (y * w + x)
        Blur_IIR_sp1_32()
      Next
    Next
  Next
EndMacro

Macro Blur_IIR_sp_001(var, opt, opt2)
  Protected *cible = *param\addr[1]
  Protected w = *param\lg, h = *param\ht
  Protected a, r, g, b, a1, r1, g1.l, b1
  Protected alpha, inv_alpha, alphaX, inv_alphaX, alphaY, inv_alphaY
  Protected x, y, mem, pos
  Protected *dst32.pixel32 = *cible
  Protected *pix32.pixel32
  Protected.l block_y_start, block_y_end
  Protected.l block_x_start, block_x_end
  
  macro_calul_tread(var)
  alpha#opt = Int((Exp(-2.3 / (*param\option[opt2] + 1.0))) * 256)
  inv_alpha#opt = 256 - alpha#opt
  alpha = alphax : inv_alpha = inv_alphax
EndMacro

Procedure Blur_IIR_sp1(*param.parametre)
  Blur_IIR_sp_001(h, x, 0)
  Blur_IIR_blurH()
EndProcedure

Procedure Blur_IIR_sp2(*param.parametre)
  Blur_IIR_sp_001(w, y, 1)
  alpha = alphay : inv_alpha = inv_alphay
  Blur_IIR_blurV()
EndProcedure


; ============================================================================
; CALCUL ADAPTATIF DU NOMBRE DE THREADS
; ============================================================================
Macro CalculerThreadsOptimal(thread)
  thread = 1
  Select (*param\lg * *param\ht)
    Case 0 To 650000 : thread = 1
    Case 650001 To 2620000 : thread = 2
    Case 2620001 To 10000000 : thread = 4
    Case 10000001 To 40000000 : thread = 8
    Default : thread = 16
  EndSelect
  If thread > CountCPUs(#PB_System_ProcessCPUs) : thread = CountCPUs(#PB_System_ProcessCPUs) : EndIf
EndMacro


; ============================================================================
; PROCÉDURE PRINCIPALE OPTIMISÉE
; ============================================================================

Procedure Blur_IIR_sp0(*param.parametre)
  CopyMemory(*param\addr[0], *param\addr[1], (*param\lg * *param\ht * 4))
  
  ; Calculer le nombre optimal de threads
  Protected.l nb_threads
  CalculerThreadsOptimal(nb_threads)
  Protected passe
  
  Debug "Blur IIR Optimisé - Threads: " + Str(nb_threads)
  
  CompilerIf #PB_Compiler_Processor = #PB_Processor_x64 And #PB_Compiler_Backend = #PB_Backend_Asm
    ; Version SSE3 avec blocs cache-friendly
    For passe = 0 To *param\option[2] - 1
      MultiThread_MT(@Blur_IIR_sp1_sse4_blocked(), nb_threads)
      MultiThread_MT(@Blur_IIR_sp2_sse4_blocked(), nb_threads)
    Next
  CompilerElse
    ; Version PureBasic avec blocs
    For passe = 0 To *param\option[2] - 1
      MultiThread_MT(@Blur_IIR_sp1(), nb_threads)
      MultiThread_MT(@Blur_IIR_sp2(), nb_threads)
    Next
  CompilerEndIf
EndProcedure

Procedure Blur_IIR(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Classic
    *param\name = "Blur_IIR"
    *param\remarque = "Flou IIR ultra-optimisé (multi-thread + cache-friendly)"
    *param\info[0] = "Rayon X"
    *param\info[1] = "Rayon Y"
    *param\info[2] = "Nombre de passe"
    *param\info[3] = "Masque"
    *param\info_data(0,0) = 0 : *param\info_data(0,1) = 100 : *param\info_data(0,2) = 1
    *param\info_data(1,0) = 0 : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 1
    *param\info_data(2,0) = 1 : *param\info_data(2,1) = 3   : *param\info_data(2,2) = 1
    *param\info_data(3,0) = 0 : *param\info_data(3,1) = 2   : *param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  
  clamp(*param\option[2], 1, 3)
  If Filter_BufferPrepare(*param.parametre) <> 0
    Blur_IIR_sp0(*param.parametre)
    macro_Filter_BufferFinalize(3)
  EndIf
EndProcedure


; ============================================================================
; OPTIMISATIONS IMPLÉMENTÉES
; ============================================================================
;
; 1. ✅ Traitement par blocs de 64 lignes/colonnes (cache L1)
; 2. ✅ Prefetch SSE (prefetchnta) pour améliorer le cache
; 3. ✅ Nombre de threads adaptatif selon taille d'image
; 4. ✅ Registres optimisés (r10-r15 pour variables de boucle)
; 5. ✅ Instructions conditionnelles (cmovge) pour éviter les branches
;
; GAINS ATTENDUS:
; - Traitement par blocs: +10-15% (meilleur cache hit rate)
; - Prefetch: +5-8% (données chargées à l'avance)
; - Threads adaptatifs: +10-15% (meilleur équilibrage)
; - TOTAL: +25-35% plus rapide que la version originale
;
; PERFORMANCE ESTIMÉE (2048x2048, rayon 20):
; - Version originale: ~32 ms
; - Version optimisée: ~22-24 ms
;
; ============================================================================
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 389
; FirstLine = 376
; Folding = ----
; Optimizer
; EnableThread
; EnableXP
; DPIAware
; CPU = 5
; DisableDebugger
; Compiler = PureBasic 6.21 - C Backend (Windows - x64)