Macro BoxBlur_declare_variable_ASM(lenght , name , var1 , var2 , size)
  Protected.l lg = *param\lg               ; largeur de l'image
  Protected.l ht = *param\ht               ; hauteur de l'image
  Protected.l x = 0, y = 0                 ; coordonnées dans l'image
  macro_calul_tread(lenght)                ; calcule la portion d'image à traiter pour chaque thread
  Protected tt
  
  Protected.l name = *param\option[var1]
  Protected pz = *param\addr[var2]
  Protected var
  
  Protected *screen_scr = *param\addr[0]
  Protected *screen_dst = *param\addr[1]

  name = (name << 1) + 1
  Protected.l blur = 65536 / name
  !movd xmm2,[p.v_blur]
  !pshuflw xmm2, xmm2, 0
  Protected.l pixel_out, pixel_in
EndMacro

Procedure BoxBlur_X_ASM(*param.parametre) 
  push_reg(*param.parametre)
  BoxBlur_declare_variable_ASM(ht, optx, 0, 2, lg) 

  !mov r12d,[p.v_thread_start]
  !BoxBlur_X_Boucle_ASM:
    ; Calcul offset de base pour la ligne courante
    !mov r15d,[p.v_lg]
    !imul r15d,r12d
    !add r15d,[p.v_x]
    !shl r15d,2
    ; r9 = pointeur source
    !mov eax,r15d
    !add rax,[p.p_screen_scr]
    !mov r9,rax
    ; r10 = pointeur destination
    !mov eax,r15d
    !add rax,[p.p_screen_dst]
    !mov r10,rax
    ; r8 = tableau pz
    !mov r8,[p.v_pz]
    ; r11d = optx (constante pour la boucle)
    !mov r11d,[p.v_optx]
    ; === Calcul noyau initial ===
    !pxor xmm1,xmm1
    !xor ecx,ecx
    !BoxBlur_Calcul_noyau_rest_ASM:
      !mov eax,[r8 + rcx * 4]
      !movd xmm0,[r9 + rax * 4]
      !pmovzxbw xmm0,xmm0
      !paddw xmm1,xmm0
      !inc ecx
      !cmp ecx,r11d
    !jl BoxBlur_Calcul_noyau_rest_ASM
    ; === Stocker premier pixel ===
    !movq xmm3,xmm1
    !pmulhuw xmm3,xmm2
    !packuswb xmm3,xmm3
    !movd [r10],xmm3
    
    
    ; === Fenêtre glissante gauche ===
    !mov r14d,[p.v_lg]
    !dec r14d
    !xor ecx,ecx
    !BoxBlur_Calcul_differentiel_X_boucle_gauche_ASM:
      ; eax = index pixel ancien (à retirer)
      !mov eax,[r8 + rcx * 4]
      ; ebx = index pixel nouveau (à ajouter)
      !lea ebx,[ecx + r11d]
      !mov ebx,[r8 + rbx * 4]
      ; Charger ancien et nouveau pixel
      !movd xmm4,[r9 + rax * 4]
      !movd xmm5,[r9 + rbx * 4]
      !pmovzxbw xmm4,xmm4
      !pmovzxbw xmm5,xmm5
      ; Différentiel
      !psubw xmm1,xmm4
      !paddw xmm1,xmm5
      ; Conversion et stockage
      !movq xmm3,xmm1
      !pmulhuw xmm3,xmm2
      !packuswb xmm3,xmm3
      !inc ecx
      !movd [r10 + rcx * 4],xmm3
      !cmp ecx,[p.v_optx]
    !jb BoxBlur_Calcul_differentiel_X_boucle_gauche_ASM
      
    ; === Fenêtre glissante centre ===
    !mov r14d,[p.v_lg]
    !dec r14d
    !sub r14d,[p.v_optx]
    !mov eax,[r8 + rcx * 4]
    !lea ebx,[ecx + r11d]
    !mov ebx,[r8 + rbx * 4]
    !lea rsi, [r9 + rax*4] 
    !lea rdi, [r9 + rbx*4]
    !lea rdx, [r10 + rcx*4 + 4]
    
    ; Vérifier si on peut dérouler (nombre pair d'itérations)
    !mov r15d,r14d
    !sub r15d,ecx
    !test r15d,1
    !jnz BoxBlur_centre_impair
    
    !BoxBlur_Calcul_differentiel_X_boucle_centre_x2:
      ; === Pixel 1 ===
      !movd xmm4,[rsi]
      !movd xmm5,[rdi]
      !pmovzxbw xmm4,xmm4
      !pmovzxbw xmm5,xmm5
      !psubw xmm1,xmm4
      !paddw xmm1,xmm5
      !movq xmm3,xmm1
      !pmulhuw xmm3,xmm2
      !packuswb xmm3,xmm3
      !movd [rdx],xmm3
      
      ; === Pixel 2 ===
      !movd xmm4,[rsi+4]
      !movd xmm5,[rdi+4]
      !add rsi,8              ; <-- avance de 2 pixels
      !add rdi,8
      !pmovzxbw xmm4,xmm4
      !pmovzxbw xmm5,xmm5
      !psubw xmm1,xmm4
      !paddw xmm1,xmm5
      !movq xmm3,xmm1
      !pmulhuw xmm3,xmm2
      !packuswb xmm3,xmm3
      !movd [rdx+4],xmm3
      
      !add rdx,8
      !add ecx,2              ; <-- incrémente de 2
      !cmp ecx,r14d
    !jb BoxBlur_Calcul_differentiel_X_boucle_centre_x2
    !jmp BoxBlur_centre_fin
    
    !BoxBlur_centre_impair:
      ; Traiter le dernier pixel si nombre impair
      !movd xmm4,[rsi]
      !movd xmm5,[rdi]
      !pmovzxbw xmm4,xmm4
      !pmovzxbw xmm5,xmm5
      !psubw xmm1,xmm4
      !paddw xmm1,xmm5
      !movq xmm3,xmm1
      !pmulhuw xmm3,xmm2
      !packuswb xmm3,xmm3
      !movd [rdx],xmm3
      
    !BoxBlur_centre_fin:
    
    ; === Fenêtre glissante droite ===
    !mov r14d,[p.v_lg]
    !dec r14d
    ;!xor ecx,ecx
    !BoxBlur_Calcul_differentiel_X_boucle_droite_ASM:
      ; eax = index pixel ancien (à retirer)
      !mov eax,[r8 + rcx * 4]
      ; ebx = index pixel nouveau (à ajouter)
      !lea ebx,[ecx + r11d]
      !mov ebx,[r8 + rbx * 4]
      ; Charger ancien et nouveau pixel
      !movd xmm4,[r9 + rax * 4]
      !movd xmm5,[r9 + rbx * 4]
      !pmovzxbw xmm4,xmm4
      !pmovzxbw xmm5,xmm5
      ; Différentiel
      !psubw xmm1,xmm4
      !paddw xmm1,xmm5
      ; Conversion et stockage
      !movq xmm3,xmm1
      !pmulhuw xmm3,xmm2
      !packuswb xmm3,xmm3
      !inc ecx
      !movd [r10 + rcx * 4],xmm3
      !cmp ecx,r14d
    !jb BoxBlur_Calcul_differentiel_X_boucle_droite_ASM
      
    !inc r12d
    !cmp r12d,[p.v_thread_stop]
  !jb BoxBlur_X_Boucle_ASM
  pop_reg(*param.parametre)
EndProcedure

Macro BoxBlur_Y_ASM_SP1(var1,var2)
  !movdqa xmm4,xmm0
  !psrldq xmm4,var1
  !pmovzxbw xmm4,xmm4
  !paddw var2,xmm4
EndMacro

Macro BoxBlur_Y_ASM_SP2(var1,var2)
  !movdqa xmm3,var1
  !pmulhuw xmm3,xmm2
  !packuswb xmm3,xmm3
  !movd [rax + var2],xmm3
EndMacro

Macro BoxBlur_Y_ASM_SP3(var1,var2)
  !movdqa xmm4,xmm13
  !psrldq xmm4,var1
  !pmovzxbw xmm4,xmm4
  !psubw var2,xmm4
  !movdqa xmm5,xmm14
  !psrldq xmm5,var1
  !pmovzxbw xmm5,xmm5
  !paddw var2,xmm5
EndMacro

Macro BoxBlur_Y_ASM_SP4(var1,var2)
  !movdqa xmm3,var1
  !pmulhuw xmm3,xmm2
  !packuswb xmm3,xmm3
  !movd [rax + var2],xmm3
EndMacro

Procedure BoxBlur_Y_ASM(*param.parametre) 
  Push_Reg(*param)
  BoxBlur_declare_variable_ASM(lg, opty, 1, 3, ht)
  
  !mov r14d,[p.v_ht]
  !dec r14d
  !mov r12d,[p.v_thread_start]
  !and r12d,0xFFFFFFFC           ; Aligner sur 4
  
  ; Calculer limite SANS arrondir
  !mov r15d,[p.v_thread_stop]
  !sub r15d,3                    ; Limite pour groupes de 4
  
  !mov r11d,[p.v_lg]
  !shl r11d,2
  
  !BoxBlur_Y_Boucle_4x_ASM:
    !mov eax,r12d
    !shl eax,2
    !add rax,[p.p_screen_scr]
    !mov r9,rax
    
    ; === Accumulateurs pour 4 colonnes ===
    !pxor xmm1,xmm1
    !pxor xmm6,xmm6
    !pxor xmm11,xmm11
    !pxor xmm12,xmm12
    !xor ecx,ecx
    !mov r8,[p.v_pz]
    
    !BoxBlur_Y_noyau_4x:
      !mov eax,[r8 + rcx * 4]
      !imul eax,r11d
      !movdqu xmm0,[r9 + rax]
      
      !movdqa xmm4,xmm0
      !pmovzxbw xmm4,xmm4
      !paddw xmm1,xmm4
      
      BoxBlur_Y_ASM_SP1(4,xmm6)
      BoxBlur_Y_ASM_SP1(8,xmm11)
      BoxBlur_Y_ASM_SP1(12,xmm12)
      !inc ecx
      !cmp ecx,[p.v_opty]
    !jl BoxBlur_Y_noyau_4x
    
    !mov eax,r12d
    !shl eax,2
    !add rax,[p.p_screen_dst]
    !mov r10,rax
    
    BoxBlur_Y_ASM_SP2(xmm1,0)
    BoxBlur_Y_ASM_SP2(xmm6,4)
    BoxBlur_Y_ASM_SP2(xmm11,8)
    BoxBlur_Y_ASM_SP2(xmm12,12)
    
    !mov edx,[p.v_opty]
    !xor ecx,ecx
    
    !BoxBlur_Y_slide_4x:
      !mov eax,[r8 + rcx * 4]
      !imul eax,r11d
      !lea edi,[ecx + edx]
      !mov edi,[r8 + rdi * 4]
      !imul edi,r11d
      
      !movdqu xmm13,[r9 + rax]
      !movdqu xmm14,[r9 + rdi]
      
      !movdqa xmm4,xmm13
      !pmovzxbw xmm4,xmm4
      !psubw xmm1,xmm4
      !movdqa xmm5,xmm14
      !pmovzxbw xmm5,xmm5
      !paddw xmm1,xmm5
      
      BoxBlur_Y_ASM_SP3(4,xmm6)
      BoxBlur_Y_ASM_SP3(8,xmm11)
      BoxBlur_Y_ASM_SP3(12,xmm12)
      
      !inc ecx
      !mov eax,ecx
      !imul eax,r11d
      !add rax,r10
      
      BoxBlur_Y_ASM_SP4(xmm1,0)
      BoxBlur_Y_ASM_SP4(xmm6,4)
      BoxBlur_Y_ASM_SP4(xmm11,8)
      BoxBlur_Y_ASM_SP4(xmm12,12)
      
      !cmp ecx,r14d
    !jb BoxBlur_Y_slide_4x
    
    !add r12d,4
    !cmp r12d,r15d
  !jb BoxBlur_Y_Boucle_4x_ASM
  
  ; === Traiter colonnes restantes (0 à 3 colonnes) ===
  !mov r13d,[p.v_thread_stop]
  !cmp r12d,r13d
  !jge BoxBlur_Y_done
  
  !BoxBlur_Y_reste_ASM:
    !mov eax,r12d
    !shl eax,2
    !add rax,[p.p_screen_scr]
    !mov r9,rax
    
    ; Calcul noyau pour 1 colonne
    !pxor xmm1,xmm1
    !xor ecx,ecx
    !mov r8,[p.v_pz]
    
    !BoxBlur_Y_noyau_1x:
      !mov eax,[r8 + rcx * 4]
      !imul eax,r11d
      !movd xmm0,[r9 + rax]
      !pmovzxbw xmm0,xmm0
      !paddw xmm1,xmm0
      !inc ecx
      !cmp ecx,[p.v_opty]
    !jl BoxBlur_Y_noyau_1x
    
    ; Premier pixel
    !mov eax,r12d
    !shl eax,2
    !add rax,[p.p_screen_dst]
    !mov r10,rax
    !movdqa xmm3,xmm1
    !pmulhuw xmm3,xmm2
    !packuswb xmm3,xmm3
    !movd [rax],xmm3
    
    ; Fenêtre glissante
    !mov edx,[p.v_opty]
    !xor ecx,ecx
    
    !BoxBlur_Y_slide_1x:
      !mov eax,[r8 + rcx * 4]
      !imul eax,r11d
      !lea edi,[ecx + edx]
      !mov edi,[r8 + rdi * 4]
      !imul edi,r11d
      
      !movd xmm4,[r9 + rax]
      !movd xmm5,[r9 + rdi]
      !pmovzxbw xmm4,xmm4
      !pmovzxbw xmm5,xmm5
      !psubw xmm1,xmm4
      !paddw xmm1,xmm5
      
      !movdqa xmm3,xmm1
      !pmulhuw xmm3,xmm2
      !packuswb xmm3,xmm3
      
      !inc ecx
      !mov eax,ecx
      !imul eax,r11d
      !movd [r10 + rax],xmm3
      
      !cmp ecx,r14d
    !jb BoxBlur_Y_slide_1x
    
    !inc r12d
    !cmp r12d,r13d
  !jb BoxBlur_Y_reste_ASM
  
  !BoxBlur_Y_done:
  Pop_reg(*param)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 13
; Folding = --
; EnableXP
; DPIAware