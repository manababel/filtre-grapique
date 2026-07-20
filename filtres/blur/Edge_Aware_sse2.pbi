

Macro Edge_Aware_RecursiveFilter_H_sp0_01_sse2()

; --- PRÉPARATION (Hors de la boucle) ---
! mov rdx, [p.p_ptrR]       ; Pointeur R
! mov rsi, [p.p_ptrG]       ; Pointeur G
! mov rdi, [p.p_ptrB]       ; Pointeur B
! mov r8,  [p.p_plut]       ; Pointeur de la LUT (chargé UNE seule fois !)
! movss xmm7, [p.v_StepLUT] ; Constante StepLUT

! mov rbx, 1

; --- CHARGEMENT INITIAL (Pixel x-1 pour la toute première itération) ---
; Comme la boucle commence à rbx = 1, le pixel "adjacent" initial est à l'index 0
! movss xmm3, [rdx] 
! movss xmm4, [rsi] 
! movss xmm5, [rdi] 
! unpcklps xmm3, xmm4                 
! movlhps  xmm3, xmm5       ; xmm3 = [ 0.0 | b(0) | g(0) | r(0) ]

! Edge_Aware_RecursiveFilter_H_sp0_01_sse2_jp0:

    ; 1. Charger UNIQUEMENT le pixel actuel (xmm3 contient DÉJÀ le pixel précédent !)
    ! movss xmm0, [rdx + rbx * 4] ; r0
    ! movss xmm1, [rsi + rbx * 4] ; g0
    ! movss xmm2, [rdi + rbx * 4] ; b0
    ! unpcklps xmm0, xmm1                 
    ! movlhps  xmm0, xmm2         ; xmm0 = [ 0.0 | b0 | g0 | r0 ]
    
    ; --- [ CALCUL MATHÉMATIQUE ] ---
    ! movdqa xmm1, xmm0
    ! subps xmm1, xmm3
    ! mulps xmm1, xmm1            ; xmm1 = [ 0.0 | (b0-b1)² | (g0-g1)² | (r0-r1)² ]
    
    ; Somme horizontale SSE2 optimisée (r² + g² + b²)
    ! movdqa xmm2, xmm1
    ! psrlq  xmm2, 32             ; Décale de 32 bits (g² passe en position basse)
    ! addss  xmm1, xmm2           ; xmm1 (low) = r² + g²
    ! movdqa xmm2, xmm1
    ! movhlps xmm2, xmm1          ; Déplace la partie haute (b²) vers le bas
    ! addss  xmm1, xmm2           ; xmm1 (low) = r² + g² + b²
    
    ! mulss xmm1, xmm7            ; xmm1 * StepLUT
    ! cvttss2si rax, xmm1         ; rax = lut_idx (directement en 64-bits)
    
    ; Accès direct à la LUT sans intermédiaire mémoire
    ! movss xmm4, [r8 + rax * 4]  ; Magie de l'indexation x64 : Base (r8) + Index (rax) * Échelle (4)
    ! shufps xmm4, xmm4, 0        ; xmm4 = [ weight | weight | weight | weight ]
    
    ; Interpolation : xmm0 = xmm0 + (xmm3 - xmm0) * weight
    ! subps xmm3, xmm0
    ! mulps xmm3, xmm4
    ! addps xmm0, xmm3            ; xmm0 contient maintenant le pixel filtré !
    
    ; 3. Sauvegarde des résultats
    ! movss [rdx + rbx * 4], xmm0
    ! psrldq xmm0, 4
    ! movss [rsi + rbx * 4], xmm0
    ! psrldq xmm0, 4
    ! movss [rdi + rbx * 4], xmm0
    
    ; --- LE RECYCLAGE (La clé de la vitesse) ---
    ; Le pixel actuel qu'on vient de calculer (et qui est dans xmm0, mais altéré par psrldq) 
    ; doit redevenir le "pixel précédent" (xmm3) du prochain tour. On le recharge à la source.
    ! movss xmm3, [rdx + rbx * 4]
    ! movss xmm4, [rsi + rbx * 4]
    ! movss xmm5, [rdi + rbx * 4]
    ! unpcklps xmm3, xmm4
    ! movlhps  xmm3, xmm5
    
! inc rbx
! cmp rbx, [p.v_wMinus1]
! jbe Edge_Aware_RecursiveFilter_H_sp0_01_sse2_jp0

EndMacro

Macro Edge_Aware_RecursiveFilter_H_sp0_02_sse2()

; --- PRÉPARATION (Hors de la boucle) ---
! mov rdx, [p.p_ptrR]       ; Pointeur R
! mov si,  [p.p_ptrG]       ; Pointeur G (Note : rsi si conflit, PureBasic accepte rsi)
! mov rsi, [p.p_ptrG]
! mov rdi, [p.p_ptrB]
! mov r8,  [p.p_plut]       ; Pointeur de la LUT
! movss xmm7, [p.v_StepLUT] ; Constante StepLUT

; --- INITIALISATION DE L'INDEX ---
; On commence à x = wMinus1 - 1
! mov rbx, [p.v_wMinus1]
! dec rbx

; --- CHARGEMENT INITIAL (Pixel "précédent", qui est ici à DROITE, donc à l'index wMinus1) ---
! mov rax, [p.v_wMinus1]
! movss xmm3, [rdx + rax * 4] 
! movss xmm4, [rsi + rax * 4] 
! movss xmm5, [rdi + rax * 4] 
! unpcklps xmm3, xmm4                 
! movlhps  xmm3, xmm5       ; xmm3 = [ 0.0 | b(droite) | g(droite) | r(droite) ]

! Edge_Aware_RecursiveFilter_H_RL_sse2_jp0:

    ; 1. Charger le pixel actuel (à l'index rbx)
    ! movss xmm0, [rdx + rbx * 4] ; r0
    ! movss xmm1, [rsi + rbx * 4] ; g0
    ! movss xmm2, [rdi + rbx * 4] ; b0
    ! unpcklps xmm0, xmm1                 
    ! movlhps  xmm0, xmm2         ; xmm0 = [ 0.0 | b0 | g0 | r0 ]
    
    ; --- [ CALCUL MATHÉMATIQUE ] ---
    ! movdqa xmm1, xmm0
    ! subps xmm1, xmm3
    ! mulps xmm1, xmm1            ; xmm1 = [ 0.0 | (b0-b1)² | (g0-g1)² | (r0-r1)² ]
    
    ; Somme horizontale
    ! movdqa xmm2, xmm1
    ! psrlq  xmm2, 32             
    ! addss  xmm1, xmm2           
    ! movdqa xmm2, xmm1
    ! movhlps xmm2, xmm1          
    ! addss  xmm1, xmm2           ; xmm1 (low) = r² + g² + b²
    
    ! mulss xmm1, xmm7            ; xmm1 * StepLUT
    ! cvttss2si rax, xmm1         ; rax = lut_idx
    
    ; Accès LUT et expansion du poids
    ! movss xmm4, [r8 + rax * 4]  
    ! shufps xmm4, xmm4, 0        
    
    ; Interpolation
    ! subps xmm3, xmm0
    ! mulps xmm3, xmm4
    ! addps xmm0, xmm3            
    
    ; 3. Sauvegarde du pixel actuel modifié
    ! movss [rdx + rbx * 4], xmm0
    ! psrldq xmm0, 4
    ! movss [rsi + rbx * 4], xmm0
    ! psrldq xmm0, 4
    ! movss [rdi + rbx * 4], xmm0
    
    ; --- LE RECYCLAGE ---
    ; Ce pixel modifié devient le pixel "adjacent de droite" pour la prochaine itération à gauche
    ! movss xmm3, [rdx + rbx * 4]
    ! movss xmm4, [rsi + rbx * 4]
    ! movss xmm5, [rdi + rbx * 4]
    ! unpcklps xmm3, xmm4
    ! movlhps  xmm3, xmm5
    
; --- BOUCLE DÉCRÉMENTALE ---
! dec rbx
! cmp rbx, 0
! jge Edge_Aware_RecursiveFilter_H_RL_sse2_jp0 ; saute tant que rbx >= 0 (jge = Jump if Greater or Equal)

EndMacro


Procedure Edge_Aware_RecursiveFilter_H_MT_sse2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected wMinus1 = w - 1
    Protected x, y, idx, lineOffset, srcOffset
    Protected r0.f, g0.f, b0.f, r1.f, g1.f, b1.f
    Protected diff_carre.f, weight.f
    
    macro_calul_tread(h)
    
    Protected *bufR.FloatArray = \addr[3]
    Protected *bufG.FloatArray = \addr[4]
    Protected *bufB.FloatArray = \addr[5]
    Protected *Lut.FloatArray  = \addr[6] ; Récupération de la LUT
    Protected StepLUT.f        = \option[7]
    
    Protected Dim tempR.f(w)
    Protected Dim tempG.f(w)
    Protected Dim tempB.f(w)
    Protected *ptrR = @tempR()
    Protected *ptrG = @tempG()
    Protected *ptrB = @tempB()
    Protected *plut = *Lut
    Protected lineByteSize = w << 2
    Protected lut_idx

    For y = thread_start To thread_stop - 1
      lineOffset = y * w
      srcOffset = lineOffset << 2
      
      ; Charger la ligne avec CopyMemory (Optimisé au lieu de la boucle For)
      CopyMemory(*bufR + srcOffset, @tempR(0), lineByteSize)
      CopyMemory(*bufG + srcOffset, @tempG(0), lineByteSize)
      CopyMemory(*bufB + srcOffset, @tempB(0), lineByteSize)
      
      ; Gauche -> Droite
      Edge_Aware_RecursiveFilter_H_sp0_01_sse2()
      
      ; Droite -> Gauche
      Edge_Aware_RecursiveFilter_H_sp0_02_sse2()
      
      ; Sauvegarder la ligne avec CopyMemory
      CopyMemory(@tempR(0), *bufR + srcOffset, lineByteSize)
      CopyMemory(@tempG(0), *bufG + srcOffset, lineByteSize)
      CopyMemory(@tempB(0), *bufB + srcOffset, lineByteSize)
    Next
  EndWith
EndProcedure

Macro Edge_Aware_RecursiveFilter_V_sp0_sse2(op)
  ; 1. Charger la valeur de l'index 'y' de la boucle dans rax
  ! mov rax, [p.v_y]
  
  ; 2. Charger les adresses des pointeurs de la colonne courante
  ! mov rdx, [p.p_ptrR]
  ! mov rsi, [p.p_ptrG]
  ! mov rdi, [p.p_ptrB]
  
  ; 3. Charger le pixel actuel (r0, g0, b0) via l'index y (dans rax)
  ! movss xmm0, [rdx + rax * 4] ; r0
  ! movss xmm1, [rsi + rax * 4] ; g0
  ! movss xmm2, [rdi + rax * 4] ; b0
  ! unpcklps xmm0, xmm1                 
  ! movlhps  xmm0, xmm2                 ; xmm0 = [ 0.0 | b0 | g0 | r0 ]
  
  ; 4. Charger le pixel adjacent (r1, g1, b1) en appliquant TON op (inc ou dec) sur r8
  ! mov r8, rax
  ! op r8                        ; inc r8 (Haut -> Bas) OU dec r8 (Bas -> Haut)
  
  ! movss xmm3, [rdx + r8 * 4] ; r1
  ! movss xmm4, [rsi + r8 * 4] ; g1
  ! movss xmm5, [rdi + r8 * 4] ; b1
  ! unpcklps xmm3, xmm4                 
  ! movlhps  xmm3, xmm5                 ; xmm3 = [ 0.0 | b1 | g1 | r1 ]
  
  ; 5. Calcul de la différence et élévation au carré
  ! movdqa xmm1, xmm0
  ! subps xmm1, xmm3                    ; xmm1 = [ 0 | b0-b1 | g0-g1 | r0-r1 ]
  ! mulps xmm1, xmm1                    ; xmm1 = [ 0 | (b0-b1)² | (g0-g1)² | (r0-r1)² ]
  
  ; 6. Somme horizontale rapide (diff_carre)
  ! movdqa xmm2, xmm1
  ! shufps xmm2, xmm2, $4E              
  ! addps xmm1, xmm2                    
  ! movdqa xmm2, xmm1
  ! shufps xmm2, xmm2, $11              
  ! addss xmm1, xmm2                    ; xmm1 (Dword 0) = diff_carre
  
  ; 7. Calcul de l'index de la LUT
  ! mulss xmm1, [p.v_StepLUT]           ; xmm1 = diff_carre * StepLUT
  ! cvttss2si eax, xmm1                 ; Convertit le float tronqué dans EAX
  ! mov [p.v_lut_idx], eax              ; Stocke dans la variable locale
  
  ; 8. Récupération du poids (weight) depuis la LUT en PureBasic
  weight = *Lut\f[lut_idx]
  ! movss xmm4, [p.v_weight]
  ! shufps xmm4, xmm4, 0                 ; xmm4 = [ weight | weight | weight | weight ]
  
  ; 9. Interpolation linéaire : r0 + weight * (r1 - r0)
  ! subps xmm3, xmm0                    ; xmm3 = [ 0 | b1-b0 | g1-g0 | r1-r0 ]
  ! mulps xmm3, xmm4                    
  ! addps xmm0, xmm3                    ; xmm0 = [ 0 | b_new | g_new | r_new ]
  
  ; 10. Sauvegarde des résultats (On recharge rax et les pointeurs)
  ! mov rax, [p.v_y]
  ! mov rdx, [p.p_ptrR]
  ! mov rsi, [p.p_ptrG]
  ! mov rdi, [p.p_ptrB]
  
  ! movss [rdx + rax * 4], xmm0
  ! psrldq xmm0, 4
  ! movss [rsi + rax * 4], xmm0
  ! psrldq xmm0, 4
  ! movss [rdi + rax * 4], xmm0

EndMacro

Macro Edge_Aware_RecursiveFilter_V_TopToBottom_sse2()
; --- PRÉPARATION ---
! mov rdx, [p.p_ptrR]       
! mov rsi, [p.p_ptrG]       
! mov rdi, [p.p_ptrB]       
! mov r8,  [p.p_plut]       
! movss xmm7, [p.v_StepLUT] 

! mov rbx, 1                ; Compteur Y (Ligne 1 à hMinus1)

; --- CHARGEMENT INITIAL (Ligne 0) ---
! movss xmm3, [rdx] 
! movss xmm4, [rsi] 
! movss xmm5, [rdi] 
! unpcklps xmm3, xmm4                 
! movlhps  xmm3, xmm5       

! Edge_Aware_RecursiveFilter_V_CTB_sse2_jp0:

    ; Puisque les données sont contiguës, l'offset en octets est rbx * 4 !
    ! mov rax, rbx
    ! shl rax, 2            ; rax = y * 4
    
    ; 1. Charger le pixel actuel
    ! movss xmm0, [rdx + rax]   
    ! movss xmm1, [rsi + rax]   
    ! movss xmm2, [rdi + rax]   
    ! unpcklps xmm0, xmm1                 
    ! movlhps  xmm0, xmm2       
    
    ; --- CALCUL MATHÉMATIQUE ---
    ! movdqa xmm1, xmm0
    ! subps xmm1, xmm3
    ! mulps xmm1, xmm1          
    
    ; Somme horizontale
    ! movdqa xmm2, xmm1
    ! shufps xmm2, xmm1, $4E              
    ! addps  xmm1, xmm2
    ! movdqa xmm2, xmm1
    ! shufps xmm2, xmm1, $11
    ! addss  xmm1, xmm2          
    
    ! mulss xmm1, xmm7            
    
    ; Index LUT
    ! xor r10, r10
    ! cvttss2si r10, xmm1   
    
    ; Accès LUT
    ! movss xmm4, [r8 + r10 * 4]  
    ! shufps xmm4, xmm4, 0        
    
    ; Interpolation
    ! subps xmm3, xmm0
    ! mulps xmm3, xmm4
    ! addps xmm0, xmm3            
    
    ; 3. Sauvegarde
    ! movss [rdx + rax], xmm0
    ! psrldq xmm0, 4
    ! movss [rsi + rax], xmm0
    ! psrldq xmm0, 4
    ! movss [rdi + rax], xmm0
    
    ; --- RECYCLAGE ---
    ! movss xmm3, [rdx + rax]
    ! movss xmm4, [rsi + rax]
    ! movss xmm5, [rdi + rax]
    ! unpcklps xmm3, xmm4
    ! movlhps  xmm3, xmm5
    
! inc rbx
! cmp rbx, [p.v_hMinus1]
! jbe Edge_Aware_RecursiveFilter_V_CTB_sse2_jp0
EndMacro

Macro Edge_Aware_RecursiveFilter_V_BottomToTop_sse2()
; --- PRÉPARATION ---
! mov rdx, [p.p_ptrR]       
! mov rsi, [p.p_ptrG]       
! mov rdi, [p.p_ptrB]       
! mov r8,  [p.p_plut]       
! movss xmm7, [p.v_StepLUT] 

; --- INITIALISATION INDEX ---
! mov rbx, [p.v_hMinus1]
! dec rbx                   ; rbx = hMinus1 - 1

; --- CHARGEMENT INITIAL (Ligne hMinus1, tout au bout du tableau temp) ---
! mov rax, [p.v_hMinus1]
! shl rax, 2                ; Offset final = hMinus1 * 4
! movss xmm3, [rdx + rax] 
! movss xmm4, [rsi + rax] 
! movss xmm5, [rdi + rax] 
! unpcklps xmm3, xmm4                 
! movlhps  xmm3, xmm5       

! Edge_Aware_RecursiveFilter_V_CBT_sse2_jp0:

    ! mov rax, rbx
    ! shl rax, 2            ; rax = y * 4

    ; 1. Charger le pixel actuel
    ! movss xmm0, [rdx + rax] 
    ! movss xmm1, [rsi + rax] 
    ! movss xmm2, [rdi + rax] 
    ! unpcklps xmm0, xmm1                 
    ! movlhps  xmm0, xmm2         
    
    ; --- CALCUL MATHÉMATIQUE ---
    ! movdqa xmm1, xmm0
    ! subps xmm1, xmm3
    ! mulps xmm1, xmm1            
    
    ; Somme horizontale
    ! movdqa xmm2, xmm1
    ! shufps xmm2, xmm1, $4E              
    ! addps  xmm1, xmm2
    ! movdqa xmm2, xmm1
    ! shufps xmm2, xmm1, $11
    ! addss  xmm1, xmm2           
    
    ! mulss xmm1, xmm7            
    
    ; Index LUT
    ! xor r10, r10
    ! cvttss2si r10, xmm1   
    
    ; Accès LUT
    ! movss xmm4, [r8 + r10 * 4]  
    ! shufps xmm4, xmm4, 0        
    
    ; Interpolation
    ! subps xmm3, xmm0
    ! mulps xmm3, xmm4
    ! addps xmm0, xmm3            
    
    ; 3. Sauvegarde
    ! movss [rdx + rax], xmm0
    ! psrldq xmm0, 4
    ! movss [rsi + rax], xmm0
    ! psrldq xmm0, 4
    ! movss [rdi + rax], xmm0
    
    ; --- RECYCLAGE ---
    ! movss xmm3, [rdx + rax]
    ! movss xmm4, [rsi + rax]
    ! movss xmm5, [rdi + rax]
    ! unpcklps xmm3, xmm4
    ! movlhps  xmm3, xmm5
    
; --- BOUCLE DÉCRÉMENTALE ---
! dec rbx
! cmp rbx, 0
! jge Edge_Aware_RecursiveFilter_V_CBT_sse2_jp0
EndMacro

Procedure Edge_Aware_RecursiveFilter_V_MT_sse2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected hMinus1 = h - 1
    Protected x, y, idx
    Protected r0.f, g0.f, b0.f, r1.f, g1.f, b1.f
    Protected diff_carre.f, weight.f
    
    macro_calul_tread(w)
    
    ; Accès direct aux buffers de flottants (Pas de Peek/Poke)
    Protected *bufR.FloatArray = \addr[3]
    Protected *bufG.FloatArray = \addr[4]
    Protected *bufB.FloatArray = \addr[5]
    Protected *Lut.FloatArray  = \addr[6] ; Récupération de la table pré-calculée
    Protected StepLUT.f        = \option[7] ; Facteur d'échelle de la LUT
    
    ; Tableaux locaux sur la pile pour stocker la colonne courante de manière contiguë
    Protected Dim tempR.f(h)
    Protected Dim tempG.f(h)
    Protected Dim tempB.f(h)
    Protected *ptrR = @tempR()
    Protected *ptrG = @tempG()
    Protected *ptrB = @tempB()
    Protected *plut = *Lut
    Protected lut_idx

    For x = thread_start To thread_stop - 1
      
      ; 1. Charger la colonne (Sauts de lignes de taille 'w')
      For y = 0 To hMinus1
        idx = y * w + x
        tempR(y) = *bufR\f[idx]
        tempG(y) = *bufG\f[idx]
        tempB(y) = *bufB\f[idx]
      Next
      
      ; 2. Filtrage : Haut -> Bas
      Edge_Aware_RecursiveFilter_V_TopToBottom_sse2()
      
      ; 3. Filtrage : Bas -> Haut
      Edge_Aware_RecursiveFilter_V_BottomToTop_sse2()
      ; 4. Sauvegarder la colonne modifiée dans les buffers globaux
      For y = 0 To hMinus1
        idx = y * w + x
        *bufR\f[idx] = tempR(y)
        *bufG\f[idx] = tempG(y)
        *bufB\f[idx] = tempB(y)
      Next
    Next
  EndWith
EndProcedure
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 475
; FirstLine = 438
; Folding = --
; EnableXP
; DPIAware