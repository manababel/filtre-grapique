Procedure RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4(*FilterCtx.FilterParams)
  Protected radius = *FilterCtx\option[0]
  Protected w = *FilterCtx\image_lg[0]
  Protected h = *FilterCtx\image_ht[0]
  Protected w_minus_1 = w - 1
  Protected *src.pixelarray = *FilterCtx\addr[0]
  Protected *dst.pixelarray = *FilterCtx\addr[5]
  
  macro_calul_tread(h)
  
  Protected max_c = (radius * 2) + 1
  Dim invTable.u(max_c)
  Protected i
  For i = 1 To max_c : invTable(i) = ($FFFF + (i / 2)) / i : Next
  Protected.i p_invTable = @invTable()
  
  ; --- REGISTRES x64 ---
  ; r12 = y, r13 = thread_stop, r14 = w, r15 = radius, rbp = w_minus_1
  ; rdi = base_src, rsi = base_dst, rbx = p_invTable
  
  !mov [rsp - 8], rbp              ; Sauvegarde de RBP (requis par PureBasic)
  !mov r12, [p.v_thread_start]
  !mov r13, [p.v_thread_stop]
  !mov r14, [p.v_w]
  !mov r15, [p.v_radius]
  !mov rbp, [p.v_w_minus_1]
  !mov rdi, [p.p_src]
  !mov rsi, [p.p_dst]
  !mov rbx, [p.v_p_invTable]
  
  !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_loop_y:
    !cmp r12, r13
    !jge .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_end_y
    
    ; Calcul de l'adresse de début de la ligne actuelle (y * w * 4)
    !mov rdx, r12
    !imul rdx, r14
    !shl rdx, 2
    !mov r9, rdi
    !add r9, rdx                   ; r9 = *current_src_row
    !mov r10, rsi
    !add r10, rdx                  ; r10 = *current_dst_row
    
    !xor r11, r11                  ; r11 = x = 0
    
    !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_loop_x:
      !cmp r11, r14
      !jge .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_end_x
      
      !pxor xmm0, xmm0
      !xor rcx, rcx                ; rcx = c = 0
      
      !mov rdx, r15
      !neg rdx                     ; rdx = i = -radius
      
      !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_loop_i:
        !cmp rdx, r15
        !jg .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_end_i
        
        ; px = x + i
        !mov rax, r11
        !add rax, rdx
        
        ; Clamping branchless
        !xor r8, r8
        !cmp rax, 0
        !cmovl rax, r8
        !cmp rax, rbp
        !cmovg rax, rbp            ; rax = px clapped
        
        ; offset direct dans la ligne courante : px * 4
        !shl rax, 2
        
        !pmovzxbd xmm1, dword [r9 + rax]
        !packusdw xmm1, xmm1
        !paddw xmm0, xmm1
        
        !inc rcx
        !inc rdx
        !jmp .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_loop_i
      !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_end_i:
      
      ; Division & Écriture
      !movzx eax, word [rbx + rcx * 2]
      !movd xmm2, eax
      !pshuflw xmm2, xmm2, 0
      
      !pmulhuw xmm0, xmm2
      !packuswb xmm0, xmm0
      
      ; x * 4 pour la destination
      !mov rax, r11
      !shl rax, 2
      !movd [r10 + rax], xmm0
      
      !inc r11
      !jmp .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_loop_x
    !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_end_x:
    
    !inc r12
    !jmp .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_loop_y
  !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4_end_y:
  
  !mov rbp, [rsp - 8]              ; Restauration de RBP
EndProcedure

Procedure RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4(*FilterCtx.FilterParams)
  Protected radius = *FilterCtx\option[0]
  Protected w = *FilterCtx\image_lg[0]
  Protected h = *FilterCtx\image_ht[0]
  Protected h_minus_1 = h - 1
  Protected *src.pixelarray = *FilterCtx\addr[5]
  Protected *dst.pixelarray = *FilterCtx\addr[4]
  
  macro_calul_tread(w)
  
  Protected max_c = (radius * 2) + 1
  Dim invTable.u(max_c)
  Protected i
  For i = 1 To max_c : invTable(i) = ($FFFF + (i / 2)) / i : Next
  Protected.i p_invTable = @invTable()
  
  ; --- REGISTRES x64 ---
  ; r12 = x, r13 = thread_stop, r14 = h, r15 = radius, rbp = h_minus_1
  ; rdi = base_src, rsi = base_dst, rbx = p_invTable, r9 = stride (w * 4)
  
  !mov [rsp - 8], rbp              ; Sauvegarde de RBP (requis par PureBasic)
  !mov r12, [p.v_thread_start]
  !mov r13, [p.v_thread_stop]
  !mov r14, [p.v_h]
  !mov r15, [p.v_radius]
  !mov rbp, [p.v_h_minus_1]
  !mov rdi, [p.p_src]
  !mov rsi, [p.p_dst]
  !mov rbx, [p.v_p_invTable]
  
  ; On calcule le pitch d'une ligne (w * 4) pour se déplacer verticalement
  !mov r9, [p.v_w]
  !shl r9, 2                       ; r9 = octets par ligne (stride)
  
  !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_loop_x:
    !cmp r12, r13
    !jge .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_end_x
    
    !xor r11, r11                  ; r11 = y = 0
    
    !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_loop_y:
      !cmp r11, r14
      !jge .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_end_y
      
      !pxor xmm0, xmm0
      !xor rcx, rcx                ; rcx = c = 0 (accumulateur)
      
      !mov rdx, r15
      !neg rdx                     ; rdx = i = -radius
      
      !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_loop_i:
        !cmp rdx, r15
        !jg .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_end_i
        
        ; py = y + i
        !mov rax, r11
        !add rax, rdx
        
        ; Clamping vertical branchless (évaluation sans rupture de pipeline)
        !xor r8, r8
        !cmp rax, 0
        !cmovl rax, r8
        !cmp rax, rbp
        !cmovg rax, rbp            ; rax = py clamped
        
        ; offset source = py * stride + x * 4
        !imul rax, r9
        !mov r8, r12
        !shl r8, 2
        !add rax, r8               ; rax = offset total
        
        ; SSE4.1: Déballage direct du pixel mémoire 8-bit ARGB vers 32-bit dword
        !pmovzxbd xmm1, dword [rdi + rax]
        !packusdw xmm1, xmm1       ; Compression propre en 16-bit
        !paddw xmm0, xmm1          ; Somme
        
        !inc rcx
        !inc rdx
        !jmp .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_loop_i
      !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_end_i:
      
      ; offset destination = y * stride + x * 4
      !mov r8, r11
      !imul r8, r9
      !mov rax, r12
      !shl rax, 2
      !add r8, rax                 ; r8 = offset destination
      
      ; Division par multiplication de l'inverse (Virgule fixe)
      !movzx eax, word [rbx + rcx * 2]
      !movd xmm2, eax
      !pshuflw xmm2, xmm2, 0
      
      !pmulhuw xmm0, xmm2
      !packuswb xmm0, xmm0
      
      ; Écriture directe du pixel lissé
      !movd [rsi + r8], xmm0
      
      !inc r11
      !jmp .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_loop_y
    !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_end_y:
    
    !inc r12
    !jmp .l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_loop_x
  !.l_RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4_end_x:
  
  !mov rbp, [rsp - 8]              ; Restauration de RBP
EndProcedure

Procedure RollingGuidance_Worker_SSE4(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected radius = \option[0]
    Protected sigmaColor = \option[1]
    Protected dim_size = (radius * 2) + 1
    
    Protected w_minus_1 = w - 1
    Protected h_minus_1 = h - 1
    
    Protected *src   = \addr[0]
    Protected *dst   = \addr[1]
    Protected *guide = \addr[2]
    
    Protected *buf1.floatarray = \addr[7] 
    Protected *buf2.floatarray = \addr[6] 
    
    Protected dy
    
    macro_calul_tread(h)
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    
    ; --- INITIALISATION DES REGISTRES ---
    !mov r12, [p.v_thread_start]
    !mov r13, [p.v_thread_stop]
    !mov r15, [p.v_w]
    !mov rbp, [p.v_w_minus_1]
    !mov rbx, [p.p_guide]
    
    ; Chargement des buffers dans des registres pour éviter les accès RAM redondants
    !mov rsi, [p.p_buf1]
    !mov rdi, [p.p_buf2]
    
    ; --- BOUCLE PRINCIPALE Y ---
    !_lbl_RollingGuidance_Worker_SSE4_loop_y:
      !cmp r12, r13
      !jge _lbl_RollingGuidance_Worker_SSE4_end_y
      
      ; offsetLine = y * w * 4
      !mov rax, r12
      !imul rax, r15
      !shl rax, 2
      
      ; currentGuide = *guide + offsetLine
      !mov r10, rbx
      !add r10, rax                  
      
      !xor r14, r14                  ; r14 = x = 0
      
      ; --- BOUCLE INTERNE X ---
      !_lbl_RollingGuidance_Worker_SSE4_loop_x:
        !cmp r14, r15
        !jge _lbl_RollingGuidance_Worker_SSE4_end_x
        
        ; --- ACCÈS PIXEL GUIDE ---
        !mov rdx, r14
        !shl rdx, 2
        !add rdx, r10                 
        
        ; pmovzxbd charge l'octet [B, G, R, A] (mémoire vers registre xmm)
        ; xmm6 sera [ B0, G0, R0, A0 ] en Float
        !pmovzxbd xmm6, dword [rdx]   
        !cvtdq2ps xmm6, xmm6          
        
        !pxor xmm0, xmm0              ; xmm0 = Somme pondérée [B | G | R | A] accumulée en Float
        !pxor xmm4, xmm4              ; xmm4 = Somme des poids (sumW, scalaire)
        
        ; Initialisation sécurisée de dy
        !mov eax, [p.v_radius]
        !neg eax
        !mov [p.v_dy], eax            ; dy = -radius
        
        ; --- BOUCLE DY ---
        !_lbl_RollingGuidance_Worker_SSE4_loop_dy:
          !mov eax, [p.v_dy]
          !cmp eax, [p.v_radius]
          !jg _lbl_RollingGuidance_Worker_SSE4_end_dy
          
          ; py = y + dy
          !mov rax, r12
          !movsxd rdx, dword [p.v_dy]
          !add rax, rdx
          
          ; Clamping vertical py (0 -> h_minus_1)
          !xor rdx, rdx                
          !mov r8, [p.v_h_minus_1]
          !cmp rax, 0
          !cmovl rax, rdx
          !cmp rax, r8
          !cmovg rax, r8
          
          ; Base de la ligne source (*srcLine = *src + py * w * 4)
          !imul rax, r15
          !shl rax, 2
          !add rax, [p.p_src]        
          
          ; ly = dy + radius
          !movsxd r8, dword [p.v_dy]
          !add r8, [p.v_radius]      
          
          ; idx_space_base = ly * dim_size
          !imul r8, [p.v_dim_size]   
          
          ; On prépare la boucle dx
          !mov r9d, [p.v_radius]
          !neg r9                    ; r9 = dx = -radius
          
          ; --- BOUCLE DX ---
          !_lbl_RollingGuidance_Worker_SSE4_loop_dx:
            !mov ecx, [p.v_radius]
            !cmp r9d, ecx
            !jg _lbl_RollingGuidance_Worker_SSE4_end_dx
            
            ; px = x + dx
            !mov rcx, r14
            !add rcx, r9
            
            ; Clamping horizontal px (0 -> w_minus_1)
            !xor rdx, rdx            
            !cmp rcx, 0
            !cmovl rcx, rdx
            !cmp rcx, rbp
            !cmovg rcx, rbp          
            
            ; *pixelSrc = *srcLine + (px * 4)
            !mov rdx, rcx
            !shl rdx, 2
            !add rdx, rax            
            
            ; --- LECTURE PIXEL SOURCE & CONVERSION ---
            ; xmm1 = [ B, G, R, A ]
            !pmovzxbd xmm1, dword [rdx]   
            !cvtdq2ps xmm1, xmm1          
            
            ; Delta couleur : xmm5 = xmm1 - xmm6 -> [ dB, dG, dR, dA ]
            !movaps xmm5, xmm1
            !subps xmm5, xmm6
            
            ; dColor = (r0-r)^2 + (g0-g)^2 + (b0-b)^2
            ; Le masque 0x71 (binaire 0111 0001) dit à dpps :
            ; Multiplier et additionner uniquement les indices 0, 1, 2 (B, G, R) et stocker le résultat dans l'élément 0 de xmm5
            !dpps xmm5, xmm5, 0x71
            
            ; Extraction sécurisée de dColor (64-bits propre pour r11)
            !xor r11, r11
            !cvttss2si r11, xmm5          
            
            ; Sécurité d'index
            !test r11, r11
            !jns _lbl_RollingGuidance_ok
            !xor r11, r11
            !_lbl_RollingGuidance_ok:
            
            ; lx = dx + radius
            !mov rdx, r9
            !add rdx, [p.v_radius]       
            
            ; idx_space = idx_space_base + lx
            !add rdx, r8                 
            
            ; --- CALCUL DU POIDS TOTAL (wTot) ---
            !movss xmm3, [rsi + r11 * 4]  ; xmm3 = *buf1\f[dColor]
            !mulss xmm3, [rdi + rdx * 4]  ; xmm3 = wTot = *buf1 * *buf2
            
            ; Accumuler sumW (scalaire, bas de xmm4)
            !addss xmm4, xmm3             
            
            ; Dupliquer wTot sur tout xmm3 pour multiplier [B, G, R, A] d'un coup
            !shufps xmm3, xmm3, 0         
            
            ; xmm1 = [ B*wTot, G*wTot, R*wTot, A*wTot ]
            !mulps xmm1, xmm3             
            
            ; Accumuler dans sumR, sumG, sumB, sumA (xmm0)
            !addps xmm0, xmm1             
            
            !inc r9                       ; dx++
            !jmp _lbl_RollingGuidance_Worker_SSE4_loop_dx
          !_lbl_RollingGuidance_Worker_SSE4_end_dx:
          
          !inc dword [p.v_dy]
          !jmp _lbl_RollingGuidance_Worker_SSE4_loop_dy
        !_lbl_RollingGuidance_Worker_SSE4_end_dy:
        
        ; --- DIVISION ET CALCUL DU PIXEL FINAL ---
        !pxor xmm2, xmm2
        !ucomiss xmm4, xmm2              
        !jbe _lbl_RollingGuidance_Worker_SSE4_jp1
        
        ; Copier sumW sur les 4 canaux de xmm4 pour faire la division globale
        !shufps xmm4, xmm4, 0            
        !divps xmm0, xmm4                ; xmm0 = [ B/sumW, G/sumW, R/sumW, A/sumW ]
        
        ; Arrondi à l'entier le plus proche (+0.5)
        !roundps xmm0, xmm0, 0            
        !cvtps2dq xmm0, xmm0             ; xmm0 = [ (int)B, (int)G, (int)R, (int)A ]
        
        ; Compression des 4 canaux d'un coup vers 8 bits non signés
        !packssdw xmm0, xmm0            
        !packuswb xmm0, xmm0             ; xmm0 = [ B, G, R, A, B, G, R, A, ... ] en octets
        
        ; Écriture directe du pixel condensé (32 bits / 4 octets)
        !mov rdx, [p.p_dst]
        !mov rax, r12
        !imul rax, r15
        !shl rax, 2
        !add rdx, rax                    
        !movd [rdx + r14 * 4], xmm0      
        !jmp _lbl_RollingGuidance_Worker_SSE4_jp2
        
        !_lbl_RollingGuidance_Worker_SSE4_jp1:
        !mov rdx, [p.p_dst]
        !mov rax, r12
        !imul rax, r15
        !shl rax, 2
        !add rdx, rax
        !mov dword [rdx + r14 * 4], 0    
        
        !_lbl_RollingGuidance_Worker_SSE4_jp2:
        
        ; Recharger r10 avec l'adresse du guide de la ligne courante
        !mov rax, r12
        !imul rax, r15
        !shl rax, 2
        !mov r10, rbx
        !add r10, rax

        ;If Key_Escape_Press = 1 
          ;!jmp _lbl_RollingGuidance_Worker_SSE4_escape
        ;EndIf
        
        !inc r14                         ; x++
        !jmp _lbl_RollingGuidance_Worker_SSE4_loop_x
      !_lbl_RollingGuidance_Worker_SSE4_end_x:
      
      !inc r12                         ; y++
      !jmp _lbl_RollingGuidance_Worker_SSE4_loop_y
    !_lbl_RollingGuidance_Worker_SSE4_end_y:
    
    !_lbl_RollingGuidance_Worker_SSE4_escape:
    
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
  EndWith
EndProcedure
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 444
; FirstLine = 407
; Folding = -
; EnableXP
; DPIAware