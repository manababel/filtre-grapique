
Procedure WLSBlur_Init_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *adr0.pixelarray  = \addr[0]
    Protected *adr2.floatarray  = \addr[2]
    Protected *adr5.floatarray  = \addr[5]
    Protected *adr6.floatarray  = \addr[6]
    Protected *adr7.floatarray  = \addr[7]
    Protected *adr8.floatarray  = \addr[8]
    Protected *adr9.floatarray  = \addr[9]
    Protected *adr10.floatarray = \addr[10]
    
    Protected total = \image_lg[0] * \image_ht[0]
    
    macro_calul_tread(total) ; Définit thread_start et thread_stop
    
    Protected i = thread_start
    Protected stop = thread_stop
    
    ; Si le thread n'a rien à traiter, on sort
    If i >= stop : ProcedureReturn : EndIf
    
    ; --- Préparation des constantes de luminance pour SSE ---
    Protected Coeff_R.f = 0.299
    Protected Coeff_G.f = 0.587
    Protected Coeff_B.f = 0.114
    
    push_reg(*FilterCtx)
    ; On charge les constantes dans les registres SSE
    !movss xmm10, [p.v_Coeff_R]
    !movss xmm11, [p.v_Coeff_G]
    !movss xmm12, [p.v_Coeff_B]
    
    ; --- Chargement des adresses des pointeurs dans les registres standards ---
    
    !mov rcx, [p.p_adr0]
    !mov rdx, [p.p_adr2]
    !mov r8,  [p.p_adr5]
    !mov r9,  [p.p_adr6]
    !mov r10, [p.p_adr7]
    !mov r11, [p.p_adr8]
    !mov r12, [p.p_adr9]
    !mov r13, [p.p_adr10]
    
    !mov rax, [p.v_i]    ; rax = index de boucle (i)
    !mov rbx, [p.v_stop] ; rbx = limite (thread_stop)
    
    !WLSBlur_Init_MT_SSE2_loop:
      ; 1. Lecture du pixel 32-bit (Format standard PB: $AARRGGBB ou $BBGGRRAA selon l'OS)
      ; On assume ici le format standard de pixel 32 bits : Rouge, Vert, Bleu.
      ; Si vos canaux sont inversés, il suffit d'intervertir r8/r9/r10 dans le stockage.
      
      !movzx edi, byte [rcx + rax * 4]       ; edi = Bleu (par exemple)
      !movzx esi, byte [rcx + rax * 4 + 1]   ; esi = Vert
      !movzx ebp, byte [rcx + rax * 4 + 2]   ; ebp = Rouge
      
      ; 2. Conversion immédiate des entiers en Flottants (via SSE)
      !cvtsi2ss xmm0, ebp ; xmm0 = (float) r
      !cvtsi2ss xmm1, esi ; xmm1 = (float) g
      !cvtsi2ss xmm2, edi ; xmm2 = (float) b
      
      ; 3. Écritures simultanées dans le bloc 5,6,7 ET 8,9,10 (Plus besoin de CopyMemory !)
      !movss [r8  + rax * 4], xmm0 ; adr5[i] = r
      !movss [r11 + rax * 4], xmm0 ; adr8[i] = r
      
      !movss [r9  + rax * 4], xmm1 ; adr6[i] = g
      !movss [r12 + rax * 4], xmm1 ; adr9[i] = g
      
      !movss [r10 + rax * 4], xmm2 ; adr7[i] = b
      !movss [r13 + rax * 4], xmm2 ; adr10[i] = b
      
      ; 4. Calcul de la Luminance en parallèle : (r*0.299) + (g*0.587) + (b*0.114)
      !mulss xmm0, xmm10 ; xmm0 = r * 0.299
      !mulss xmm1, xmm11 ; xmm1 = g * 0.587
      !mulss xmm2, xmm12 ; xmm2 = b * 0.114
      
      !addss xmm0, xmm1  ; xmm0 = (r*0.299) + (g*0.587)
      !addss xmm0, xmm2  ; xmm0 = luminance complète
      
      ; 5. Stockage de la luminance dans adr2
      !movss [rdx + rax * 4], xmm0
      
      ; 6. Incrémentation de la boucle
      !inc rax
      !cmp rax, rbx
    !jl WLSBlur_Init_MT_SSE2_loop
    pop_reg(*FilterCtx)
  EndWith
EndProcedure

Procedure WLSBlur_ComputeWeights_MT_sse2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.floatarray = \addr[2]
    Protected *cible1.floatarray = \addr[3]
    Protected *cible2.floatarray = \addr[4]
    Protected *lut.floatarray    = \addr[14]
    
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected lgMinus1 = lg - 1
    Protected htMinus1 = ht - 1
   
    macro_calul_tread(ht)
    
    Protected end_y = thread_stop - 1
    Protected handle_last_line = #False
    If end_y >= htMinus1
      end_y = htMinus1 - 1
      handle_last_line = #True
    EndIf
    
    ; --- Préparation des constantes pour l'ASM ---
    Protected Coeff10.f = 10.0
    Protected MaxIdx.i = 2550
    Protected SignMask.i = $7FFFFFFF ; Masque pour faire Abs() sur les floats
    
    ; Chargement des constantes SSE
    !movss xmm8, [p.v_Coeff10]
    !movd xmm9, [p.v_SignMask]
    
    ; Chargement des pointeurs de base
    !mov r8, [p.p_source]
    !mov r9, [p.p_cible1]
    !mov r10, [p.p_cible2]
    !mov r11, [p.p_lut]
    !mov r14, [p.v_lg]
    
    Protected y, x, idx, line_limit, last_line_limit
    Protected *r12_line_down
    
    ; 1. BOUCLE PRINCIPALE (Lignes de thread_start à end_y)
    For y = thread_start To end_y
      idx = y * lg
      line_limit = idx + lgMinus1 - 1
      
      ; --- CALCUL DU POINTEUR DE LA LIGNE INFÉRIEURE ---
      ; On calcule l'adresse absolue en PureBasic pour simplifier l'ASM juste après
      *r12_line_down = *source + (idx + lg) * 4
      
      ; Chargement des compteurs de boucle et du pointeur de ligne inférieure
      !mov rbx, [p.v_idx]
      !mov r15, [p.v_line_limit]
      !mov r12, [p.p_r12_line_down]
      
      !align 16
      !WLSBlur_ComputeWeights_MT_sse2_loop:
        ; --- CHARGEMENT DES PIXELS ---
        !movss xmm0, [r8 + rbx * 4]         ; xmm0 = L_here
        !movss xmm1, [r8 + rbx * 4 + 4]     ; xmm1 = L_right
        !movss xmm2, [r12]                  ; xmm2 = L_down (via r12 directement)
        
        ; --- CALCUL GRADIENT X ---
        !subss xmm1, xmm0                   ; xmm1 = L_right - L_here
        !andps xmm1, xmm9                   ; xmm1 = Abs(grad_x)
        !mulss xmm1, xmm8                   ; xmm1 = grad_x * 10.0
        !cvttss2si rcx, xmm1                ; rcx = Int(grad_x * 10.0)
        
        ; --- CALCUL GRADIENT Y ---
        !subss xmm2, xmm0                   ; xmm2 = L_down - L_here
        !andps xmm2, xmm9                   ; xmm2 = Abs(grad_y)
        !mulss xmm2, xmm8                   ; xmm2 = grad_y * 10.0
        !cvttss2si rdx, xmm2                ; rdx = Int(grad_y * 10.0)
        
        ; --- SÉCURITÉ ANTI-DÉBORDEMENT LUT (Clamp à 2550) ---
        !mov rax, [p.v_MaxIdx]
        !cmp rcx, rax
        !cmovg rcx, rax                      ; si rcx > 2550 alors rcx = 2550
        !cmp rdx, rax
        !cmovg rdx, rax                      ; si rdx > 2550 alors rdx = 2550
        
        ; --- LECTURE LUT ET ÉCRITURE CIBLE ---
        !movss xmm3, [r11 + rcx * 4]        ; xmm3 = *lut\f[idx_lut_x]
        !movss xmm4, [r11 + rdx * 4]        ; xmm4 = *lut\f[idx_lut_y]
        
        !movss [r9 + rbx * 4], xmm3         ; *cible1\f[idx] = wx
        !movss [r10 + rbx * 4], xmm4        ; *cible2\f[idx] = wy
        
        ; --- AVANCEMENT ---
        !add r12, 4                         ; On avance le pointeur de la ligne du dessous
        !inc rbx
        !cmp rbx, r15
        !jle WLSBlur_ComputeWeights_MT_sse2_loop
        
      ; Gérer le pixel de bord (lgMinus1) pour la ligne courante
      *cible1\f[idx + lgMinus1] = 0
    Next y
    
    ; 2. TRAITEMENT DE LA DERNIÈRE LIGNE (Si ce thread a la fin de l'image)
    If handle_last_line
      idx = htMinus1 * lg
      last_line_limit = idx + lgMinus1 - 1
      
      !mov rbx, [p.v_idx]
      !mov r15, [p.v_last_line_limit]
      
      !align 16
      !WLSBlur_ComputeWeights_MT_sse2_last_line_loop:
        !movss xmm0, [r8 + rbx * 4]         ; L_here
        !movss xmm1, [r8 + rbx * 4 + 4]     ; L_right
        
        !subss xmm1, xmm0
        !andps xmm1, xmm9
        !mulss xmm1, xmm8
        !cvttss2si rcx, xmm1
        
        !mov rax, [p.v_MaxIdx]
        !cmp rcx, rax
        !cmovg rcx, rax
        
        !movss xmm3, [r11 + rcx * 4]
        !movss [r9 + rbx * 4], xmm3         ; *cible1\f[idx] = wx
        !xorps xmm4, xmm4
        !movss [r10 + rbx * 4], xmm4        ; *cible2\f[idx] = 0.0 (wy)
        
        !inc rbx
        !cmp rbx, r15
        !jle WLSBlur_ComputeWeights_MT_sse2_last_line_loop
        
      *cible1\f[idx + lgMinus1] = 0
    EndIf
    
  EndWith
EndProcedure

Procedure WLSBlur_Jacobi_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected lambda.f = \option[0]
    Protected channel = \option[5]
    Protected lgMinus1 = lg - 1
    Protected htMinus1 = ht - 1

    macro_calul_tread(ht) 
        
    Protected *input.FloatArray   = \addr[5 + channel]
    Protected *current.FloatArray = \addr[8 + channel]
    Protected *next.FloatArray    = \addr[11 + channel]
    Protected *wx.FloatArray      = \addr[3]
    Protected *wy.FloatArray      = \addr[4]
    
    Protected y, x, idx
    Protected One.f = 1.0
    
    ; --- Préparation des registres constants ---
    !movss xmm10, [p.v_lambda]
    !shufps xmm10, xmm10, 0        ; Copie lambda sur tous les slots au cas où, mais scalaire suffit ici
    !movss xmm11, [p.v_One]       ; Constante 1.0 pour diag
    
    ; Chargement des pointeurs dans les registres
    !mov r8,  [p.p_input]
    !mov r9,  [p.p_current]
    !mov r10, [p.p_next]
    !mov r11, [p.p_wx]
    !mov r12, [p.p_wy]
    !mov r14, [p.v_lg]
    
    For y = thread_start To thread_stop - 1
      idx = y * lg
      
      ; --- 1. PREMIER PIXEL DE LA LIGNE (x = 0) ---
      ; On le traite manuellement pour éviter les "If x > 0"
      x = 0
      Protected val.f = *input\f[idx]
      Protected sum.f = val
      Protected diag.f = 1.0
      
      ; Droite
      Protected wx_here.f = *wx\f[idx]
      sum  + lambda * wx_here * *current\f[idx + 1]
      diag + lambda * wx_here
      ; Haut
      If y > 0
        Protected wy_up.f = *wy\f[idx - lg]
        sum  + lambda * wy_up * *current\f[idx - lg]
        diag + lambda * wy_up
      EndIf
      ; Bas
      If y < htMinus1
        Protected wy_here.f = *wy\f[idx]
        sum  + lambda * wy_here * *current\f[idx + lg]
        diag + lambda * wy_here
      EndIf
      *next\f[idx] = sum / diag
      
      ; --- 2. COEUR DE LA LIGNE EN ASM (x = 1 À lg - 2) ---
      ; ZÉRO BRANCHEMENT 'IF' POUR X, RAPIDITÉ ABSOLUE
      If lg > 2
        Protected start_x = idx + 1
        Protected end_x   = idx + lgMinus1 - 1
        
        !mov rbx, [p.v_start_x]    ; rbx = Index courant en pixels
        !mov r15, [p.v_end_x]      ; r15 = Borne de fin
        !mov rax, [p.v_y]          ; On charge y pour les verifs haut/bas
        
        !align 16
        !wls_jacobi_inner_loop:
          ; Chargement du pixel central
          !movss xmm0, [r8 + rbx * 4]   ; xmm0 = val (sum)
          !movss xmm1, xmm11            ; xmm1 = 1.0 (diag)
          
          ; --- GAUCHE (wx_left & left) ---
          !movss xmm2, [r11 + rbx * 4 - 4] ; xmm2 = wx_left
          !mulss xmm2, xmm10               ; xmm2 = lambda * wx_left
          !movss xmm3, [r9 + rbx * 4 - 4]  ; xmm3 = left
          !mulss xmm3, xmm2                ; xmm3 = lambda * wx_left * left
          !addss xmm0, xmm3                ; sum  += xmm3
          !addss xmm1, xmm2                ; diag += lambda * wx_left
          
          ; --- DROITE (wx_here & right) ---
          !movss xmm2, [r11 + rbx * 4]     ; xmm2 = wx_here
          !mulss xmm2, xmm10               ; xmm2 = lambda * wx_here
          !movss xmm3, [r9 + rbx * 4 + 4]  ; xmm3 = right
          !mulss xmm3, xmm2                ; xmm3 = lambda * wx_here * right
          !addss xmm0, xmm3                ; sum  += xmm3
          !addss xmm1, xmm2                ; diag += lambda * wx_here
          
          ; --- HAUT (wy_up & up) ---
          !cmp rax, 0
          !jle wls_jacobi_skip_up
          !mov rdx, rbx
          !sub rdx, r14                    ; rdx = idx - lg
          !movss xmm2, [r12 + rdx * 4]     ; xmm2 = wy_up
          !mulss xmm2, xmm10               ; xmm2 = lambda * wy_up
          !movss xmm3, [r9 + rdx * 4]      ; xmm3 = up
          !mulss xmm3, xmm2                ; xmm3 = lambda * wy_up * up
          !addss xmm0, xmm3
          !addss xmm1, xmm2
          !wls_jacobi_skip_up:
          
          ; --- BAS (wy_here & down) ---
          !mov rcx, [p.v_htMinus1]
          !cmp rax, rcx
          !jge wls_jacobi_skip_down
          !mov rdx, rbx
          !add rdx, r14                    ; rdx = idx + lg
          !movss xmm2, [r12 + rbx * 4]     ; xmm2 = wy_here
          !mulss xmm2, xmm10               ; xmm2 = lambda * wy_here
          !movss xmm3, [r9 + rdx * 4]      ; xmm3 = down
          !mulss xmm3, xmm2                ; xmm3 = lambda * wy_here * down
          !addss xmm0, xmm3
          !addss xmm1, xmm2
          !wls_jacobi_skip_down:
          
          ; --- DIVISION ET STOCKAGE (*next = sum / diag) ---
          !divss xmm0, xmm1                ; xmm0 = sum / diag
          !movss [r10 + rbx * 4], xmm0     ; Stockage dans *next
          
          !inc rbx
          !cmp rbx, r15
          !jle wls_jacobi_inner_loop
      EndIf
      
      ; --- 3. DERNIER PIXEL DE LA LIGNE (x = lgMinus1) ---
      ; Idem, traité en dehors de la boucle principale pour supprimer le "If x < lgMinus1"
      idx = y * lg + lgMinus1
      val = *input\f[idx]
      sum = val
      diag = 1.0
      
      ; Gauche
      Protected wx_left.f = *wx\f[idx - 1]
      sum  + lambda * wx_left * *current\f[idx - 1]
      diag + lambda * wx_left
      ; Haut
      If y > 0
        wy_up = *wy\f[idx - lg]
        sum  + lambda * wy_up * *current\f[idx - lg]
        diag + lambda * wy_up
      EndIf
      ; Bas
      If y < htMinus1
        wy_here = *wy\f[idx]
        sum  + lambda * wy_here * *current\f[idx + lg]
        diag + lambda * wy_here
      EndIf
      *next\f[idx] = sum / diag
      
    Next y
  EndWith
EndProcedure

Procedure WLSBlur_Copy_MT_sse2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected total = lg * ht
    Protected channel = \option[5]
    Protected dif
    Protected *src = (\addr[11 + channel])
    Protected *dst = (\addr[8 + channel] )
    
    macro_calul_tread(total)
    
    dif = (thread_stop - thread_start)
    CopyMemory(*src + thread_start * 4 , *dst + thread_start * 4, dif * 4)

  EndWith
EndProcedure


Procedure WLSBlur_WriteBack_MT_sse2(*FilterCtx.FilterParams)
With *FilterCtx
    Protected *adr0.pixelarray  = \addr[0]
    Protected *adr1.pixelarray  = \addr[1]
    Protected *adr8.floatarray  = \addr[8]
    Protected *adr9.floatarray  = \addr[9]
    Protected *adr10.floatarray = \addr[10]
    Protected total = \image_lg[0] * \image_ht[0]
    Protected AlphaMask.i = $FF000000
    
    macro_calul_tread(total)
    
    Protected idx = thread_start
    Protected stop = thread_stop
    
    If idx >= stop : ProcedureReturn : EndIf
    
    ; Chargement des pointeurs dans les registres x64
    !mov r8,  [p.p_adr0]  ; Image source (pour l'Alpha)
    !mov r9,  [p.p_adr1]  ; Image destination
    !mov r10, [p.p_adr8]  ; Canal Rouge (floats)
    !mov r11, [p.p_adr9]  ; Canal Vert (floats)
    !mov r12, [p.p_adr10] ; Canal Bleu (floats)
    
    !mov rcx, [p.v_idx]   ; Compteur de boucle
    !mov rdx, [p.v_stop]  ; Limite de fin
    
    ; Masque pour isoler le canal Alpha ($FF000000)
    
    !mov r14, [p.v_AlphaMask]
    
    !align 16
    !wls_writeback_loop:
      ; --- 1. CHARGEMENT ET ARRONDI DES CANAUX (SCALAIRE SSE) ---
      ; On charge la valeur float et on la convertit en entier 32-bit avec arrondi le plus proche
      !cvtss2si eax, [r10 + rcx * 4]  ; eax = Int(Rouge + 0.5)
      !cvtss2si ebx, [r11 + rcx * 4]  ; ebx = Int(Vert + 0.5)
      !cvtss2si esi, [r12 + rcx * 4]  ; esi = Int(Bleu + 0.5)
      
      ; --- 2. CLAMP ULTRA-RAPIDE (SANS SAUT CPU) ---
      ; Écrêtage à 0 (si < 0, max met à 0)
      !xor edi, edi
      !cmp eax, edi
      !cmovl eax, edi
      !cmp ebx, edi
      !cmovl ebx, edi
      !cmp esi, edi
      !cmovl esi, edi
      
      ; Écrêtage à 255 (si > 255, min met à 255)
      !mov edi, 255
      !cmp eax, edi
      !cmovg eax, edi
      !cmp ebx, edi
      !cmovg ebx, edi
      !cmp esi, edi
      !cmovg esi, edi
      
      ; --- 3. RECOMPOSITION DU PIXEL ---
      ; Extraction de l'Alpha d'origine
      !mov ebp, [r8 + rcx * 4]        ; ebp = Pixel complet d'origine
      !and ebp, r14d                  ; ebp = OOOOOOOO (Garde uniquement Alpha)
      
      ; Décalages binaires pour assembler ARGB ($AARRGGBB)
      !shl eax, 16                    ; Place le Rouge sur son octet
      !shl ebx, 8                     ; Place le Vert sur son octet
      ; Le Bleu (esi) reste sur le premier octet
      
      ; Fusion par OU logique
      !or ebp, eax
      !or ebp, ebx
      !or ebp, esi
      
      ; Écriture dans la destination
      !mov [r9 + rcx * 4], ebp
      
      ; --- 4. AVANCEMENT DE LA BOUCLE ---
      !inc rcx
      !cmp rcx, rdx
      !jl wls_writeback_loop

  EndWith
EndProcedure


; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 457
; FirstLine = 424
; Folding = -
; EnableXP
; DPIAware