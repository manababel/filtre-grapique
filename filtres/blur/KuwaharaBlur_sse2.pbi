Procedure Kuwahara_Passe1_Worker_SSE2(*FilterCtx.FilterParams)  
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y
    Protected *adr0.Long = \addr[0]
    Protected *adr7.Long = \addr[7]
    Protected *adr6.Quad = \addr[6]
    
    ; 1. Calcul des bornes du thread
    macro_calul_tread(ht) 
    If thread_start < 0 : thread_start = 0 : EndIf 
    
    ; Variables de travail pour les adresses courantes dans les boucles
    Protected *curSrc
    Protected *curSatColor
    Protected *curSatSquare
    
    ; 2. Boucle des lignes (Y)
    For y = thread_start To thread_stop - 1
      
      ; Calcul des adresses de début de ligne
      *curSrc       = *adr0 + (y * lg * 4)
      *curSatColor  = *adr7 + (y * lg * 16) ; Chaque entrée SAT couleur fait 4 longs = 16 octets
      *curSatSquare = *adr6 + (y * lg * 8)  ; Chaque quad fait 8 octets
      
      ; -------------------------------------------------------------
      ; INITIALISATION DU PREMIER PIXEL (x = 0)
      ; -------------------------------------------------------------
      ! mov rsi, [p.p_curSrc]
      ! mov eax, dword [rsi]           ; eax = [ A | R | G | B ]
      ! and eax, 0x00FFFFFF            ; On force l'Alpha à 0 -> [ 0 | R | G | B ]
      ! movd xmm0, eax                 
      
      ; Éclatement en entiers 32-bit (dwords)
      ! pxor xmm1, xmm1
      ! punpcklbw xmm0, xmm1           
      ! punpcklwd xmm0, xmm1           ; xmm0 = [ dword3: 0 | dword2: R | dword1: G | dword0: B ]
      
      ; --- INVERSION DES CANAUX POUR CORRESPONDRE À LA MÉMOIRE ---
      ; On inverse tout : dword 0<->3 et dword 1<->2. Masque : 00 01 10 11 b (0x1B)
      ; xmm0 devient : [ dword3: B | dword2: G | dword1: R | dword0: 0 ]
      ; À l'écriture en mémoire (Little Endian), l'ordre physique sera : [0, R, G, B] -> Strictement identique au code PB !
      ! pshufd xmm0, xmm0, 00011011b
      
      ! movdqa xmm2, xmm0              ; Sauvegarde de la couleur pour le calcul du carré
      
      ; Écriture du premier élément SAT Couleur
      ! mov rdx, [p.p_curSatColor]
      ! movdqu [rdx], xmm0
      
      ; Calcul du carré pour x = 0 (R² + G² + B²)
      ! movdqa xmm4, xmm2
      ! pmuludq xmm4, xmm4             ; Multiplie dword 0 (0) et dword 2 (G) -> Donne G² en 64 bits dans xmm4
      
      ! pshufd xmm5, xmm2, 01010101b   ; Isole dword 1 (R)
      ! pmuludq xmm5, xmm5             ; R²
      ! paddq xmm4, xmm5               ; xmm4 = G² + R²
      
      ! pshufd xmm6, xmm2, 11111111b   ; Isole dword 3 (B)
      ! pmuludq xmm6, xmm6             ; B²
      ! paddq xmm4, xmm6               ; xmm4 = G² + R² + B²
      
      ; Écriture du premier élément SAT Carré
      ! mov rdi, [p.p_curSatSquare]
      ! movq [rdi], xmm4
      
      ; On avance les pointeurs
      *curSrc       + 4
      *curSatColor  + 16
      *curSatSquare + 8
      
      ; -------------------------------------------------------------
      ; 3. BOUCLE INTERNE OPTIMISÉE (x = 1 To lg - 1)
      ; -------------------------------------------------------------
      For x = 1 To lg - 1
        
        ; 1. SAT COULEURS
        ! mov rsi, [p.p_curSrc]
        ! mov eax, dword [rsi]
        ! and eax, 0x00FFFFFF          ; Alpha à 0
        ! movd xmm0, eax
        
        ! pxor xmm1, xmm1
        ! punpcklbw xmm0, xmm1         
        ! punpcklwd xmm0, xmm1         
        
        ! pshufd xmm0, xmm0, 00011011b ; Même inversion de structure [0, R, G, B]
        
        ! movdqa xmm2, xmm0            ; Sauvegarde du pixel courant pour le carré
        
        ; Charger la couleur du pixel à GAUCHE (déjà cumulée)
        ! mov rdx, [p.p_curSatColor]
        ! movdqu xmm3, [rdx - 16]      
        
        ! paddd xmm3, xmm0             ; Gauche + Source
        ! movdqu [rdx], xmm3           ; Sauvegarde
        
        ; 2. SAT CARRÉS (Courant + Gauche)
        ! movdqa xmm4, xmm2
        ! pmuludq xmm4, xmm4           ; G²
        
        ! pshufd xmm5, xmm2, 01010101b 
        ! pmuludq xmm5, xmm5           ; R²
        ! paddq xmm4, xmm5             
        
        ! pshufd xmm6, xmm2, 11111111b 
        ! pmuludq xmm6, xmm6           ; B²
        ! paddq xmm4, xmm6             ; xmm4 = Carré du pixel courant (R² + G² + B²)
        
        ; Charger le carré du pixel à GAUCHE (déjà cumulé)
        ! mov rdi, [p.p_curSatSquare]
        ! movq xmm7, [rdi - 8]         
        
        ! paddq xmm7, xmm4             ; Gauche + Source (Carrés)
        ! movq [rdi], xmm7             ; Sauvegarde
        
        *curSrc       + 4
        *curSatColor  + 16
        *curSatSquare + 8
      Next
    Next
  EndWith
EndProcedure

Procedure Kuwahara_Passe2_Worker_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y
    Protected.i lg4 = lg << 2
    Protected *adr7.Long = \addr[7] ; Table SAT Couleur (16 octets par élément)
    Protected *adr6.Quad = \addr[6] ; Table SAT Carré (8 octets par élément)
    
    ; 1. Calcul des bornes de colonnes pour ce thread
    macro_calul_tread(lg) 
    If thread_start < 0 : thread_start = 0 : EndIf 
    
    ; Variables de travail pour les pointeurs mouvants dans les boucles
    Protected *curSatColor, *dessusSatColor
    Protected *curSatSquare, *dessusSatSquare
    
    ; 2. On parcourt ligne par ligne (Y)
    For y = 1 To ht - 1
      
      ; Calcul des adresses de départ pour la ligne Y actuelle et la ligne Y-1 (dessus)
      ; On se positionne directement à la colonne "thread_start"
      *curSatColor    = *adr7 + ((y * lg + thread_start) * 16)
      *dessusSatColor = *curSatColor - (lg * 16)
      
      *curSatSquare    = *adr6 + ((y * lg + thread_start) * 8)
      *dessusSatSquare = *curSatSquare - (lg * 8)
      
      ; -------------------------------------------------------------
      ; 3. BOUCLE INTERNE SUR LES COLONNES ATTRIBUÉES (X)
      ; -------------------------------------------------------------
      For x = thread_start To thread_stop - 1 
        
        ; --- 1. SAT COULEURS (4 x longs dwords en parallèle) ---
        ! mov rsi, [p.p_dessusSatColor]
        ! mov rdi, [p.p_curSatColor]
        
        ! movdqu xmm0, [rsi]           ; xmm0 = [ dessus_B | dessus_G | dessus_R | 0 ]
        ! movdqu xmm1, [rdi]           ; xmm1 = [ actuel_B | actuel_G | actuel_R | 0 ]
        
        ! paddd xmm1, xmm0             ; Additionne les 4 canaux 32 bits d'un coup
        ! movdqu [rdi], xmm1           ; Sauvegarde le résultat dans le pixel actuel
        
        ; --- 2. SAT CARRÉS (1 x quad 64 bits) ---
        ! mov rsi, [p.p_dessusSatSquare]
        ! mov rdi, [p.p_curSatSquare]
        
        ! movq xmm2, [rsi]             ; xmm2 = carré du dessus (64 bits)
        ! movq xmm3, [rdi]             ; xmm3 = carré actuel (64 bits)
        
        ! paddq xmm3, xmm2             ; Additionne en mode 64 bits non signé
        ! movq [rdi], xmm3             ; Sauvegarde le résultat
        
        ; --- 3. PROGRESSION HORIZONTALE DES POINTEURS ---
        *curSatColor    + 16
        *dessusSatColor + 16
        *curSatSquare   + 8
        *dessusSatSquare + 8
      Next 
    Next 
  EndWith
EndProcedure



Procedure KuwaharaBlur_sp_sse2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected radius = \option[0]
    Protected sharpness.f = \option[1] / 100.0
    Protected inv_sharpness.f = 1.0 - sharpness
    
    Protected x, y, minIndex, pos_pixel
    Protected.l a1, r1, g1, b1
    Protected r.f, g.f, b.f, minVar.f, currentVar.f
    Protected w_minus_1 = w - 1, h_minus_1 = h - 1
    
    Protected *adr0.pixelarray = \addr[0]
    Protected *adr1.pixelarray = \addr[1]
    Protected *adr7.pixelarray = \addr[7] ; SAT Couleurs
    Protected *adr6.quadarray  = \addr[6] ; SAT Carrés
    
    Protected x0, y0, x1, y1
    Protected invC.f, sum_l.l
    
    ; On revient à des variables simples (beaucoup plus rapides que les tableaux Dim)
    Protected q_C0.f, q_C1.f, q_C2.f, q_C3.f
    Protected q_S0.q, q_S1.q, q_S2.q, q_S3.q
    
    macro_calul_tread(h)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        
        ! mov rsi, [p.p_adr7]
        
        ; =====================================================================
        ; QUADRANT 0
        ; =====================================================================
        x0 = x - radius : If x0 < 0 : x0 = 0 : EndIf
        y0 = y - radius : If y0 < 0 : y0 = 0 : EndIf
        q_C0 = (x - x0 + 1) * (y - y0 + 1)
        
        pos_pixel = (y * w + x)
        q_S0 = *adr6\q[pos_pixel]
        ! mov rax, [p.v_pos_pixel]
        ! shl rax, 4
        ! movdqu xmm0, [rsi + rax]
        
        ! pxor xmm1, xmm1
        ! pxor xmm2, xmm2
        ! pxor xmm3, xmm3
        
        If y0 > 0
          pos_pixel = ((y0 - 1) * w + x) : q_S0 - *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm1, [rsi + rax]
        EndIf
        If x0 > 0
          pos_pixel = (y * w + (x0 - 1)) : q_S0 - *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm2, [rsi + rax]
        EndIf
        If x0 > 0 And y0 > 0
          pos_pixel = ((y0 - 1) * w + (x0 - 1)) : q_S0 + *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm3, [rsi + rax]
        EndIf
        
        ! psubd xmm0, xmm1
        ! psubd xmm0, xmm2
        ! paddd xmm0, xmm3 ; xmm0 contient [0, R, G, B] du Q0
        
        ! movdqa xmm4, xmm0
        ! pshufd xmm5, xmm4, 01001110b
        ! paddd xmm4, xmm5
        ! movdqa xmm5, xmm4
        ! pshufd xmm5, xmm5, 11111111b
        ! paddd xmm4, xmm5
        ! movd [p.v_sum_l], xmm4
        
        minVar = q_S0 / q_C0 - (sum_l / q_C0) * (sum_l / q_C0)
        minIndex = 0
        
        ; =====================================================================
        ; QUADRANT 1
        ; =====================================================================
        x0 = x : y0 = y - radius : If y0 < 0 : y0 = 0 : EndIf
        x1 = x + radius : If x1 > w_minus_1 : x1 = w_minus_1 : EndIf
        q_C1 = (x1 - x0 + 1) * (y - y0 + 1)
        
        pos_pixel = (y * w + x1)
        q_S1 = *adr6\q[pos_pixel]
        ! mov rax, [p.v_pos_pixel]
        ! shl rax, 4
        ! movdqu xmm8, [rsi + rax]
        
        ! pxor xmm1, xmm1
        ! pxor xmm2, xmm2
        ! pxor xmm3, xmm3
        
        If y0 > 0
          pos_pixel = ((y0 - 1) * w + x1) : q_S1 - *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm1, [rsi + rax]
        EndIf
        If x0 > 0
          pos_pixel = (y * w + (x0 - 1)) : q_S1 - *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm2, [rsi + rax]
        EndIf
        If x0 > 0 And y0 > 0
          pos_pixel = ((y0 - 1) * w + (x0 - 1)) : q_S1 + *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm3, [rsi + rax]
        EndIf
        
        ! psubd xmm8, xmm1
        ! psubd xmm8, xmm2
        ! paddd xmm8, xmm3 ; xmm8 contient [0, R, G, B] du Q1
        
        ! movdqa xmm4, xmm8
        ! pshufd xmm5, xmm4, 01001110b
        ! paddd xmm4, xmm5
        ! movdqa xmm5, xmm4
        ! pshufd xmm5, xmm5, 11111111b
        ! paddd xmm4, xmm5
        ! movd [p.v_sum_l], xmm4
        
        currentVar = q_S1 / q_C1 - (sum_l / q_C1) * (sum_l / q_C1)
        If currentVar < minVar : minVar = currentVar : minIndex = 1 : EndIf
        
        ; =====================================================================
        ; QUADRANT 2
        ; =====================================================================
        x0 = x - radius : If x0 < 0 : x0 = 0 : EndIf
        y0 = y : y1 = y + radius : If y1 > h_minus_1 : y1 = h_minus_1 : EndIf
        q_C2 = (x - x0 + 1) * (y1 - y0 + 1)
        
        pos_pixel = (y1 * w + x)
        q_S2 = *adr6\q[pos_pixel]
        ! mov rax, [p.v_pos_pixel]
        ! shl rax, 4
        ! movdqu xmm9, [rsi + rax]
        
        ! pxor xmm1, xmm1
        ! pxor xmm2, xmm2
        ! pxor xmm3, xmm3
        
        If y0 > 0
          pos_pixel = ((y0 - 1) * w + x) : q_S2 - *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm1, [rsi + rax]
        EndIf
        If x0 > 0
          pos_pixel = (y1 * w + (x0 - 1)) : q_S2 - *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm2, [rsi + rax]
        EndIf
        If x0 > 0 And y0 > 0
          pos_pixel = ((y0 - 1) * w + (x0 - 1)) : q_S2 + *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm3, [rsi + rax]
        EndIf
        
        ! psubd xmm9, xmm1
        ! psubd xmm9, xmm2
        ! paddd xmm9, xmm3 ; xmm9 contient [0, R, G, B] du Q2
        
        ! movdqa xmm4, xmm9
        ! pshufd xmm5, xmm4, 01001110b
        ! paddd xmm4, xmm5
        ! movdqa xmm5, xmm4
        ! pshufd xmm5, xmm5, 11111111b
        ! paddd xmm4, xmm5
        ! movd [p.v_sum_l], xmm4
        
        currentVar = q_S2 / q_C2 - (sum_l / q_C2) * (sum_l / q_C2)
        If currentVar < minVar : minVar = currentVar : minIndex = 2 : EndIf
        
        ; =====================================================================
        ; QUADRANT 3
        ; =====================================================================
        x0 = x : y0 = y
        x1 = x + radius : If x1 > w_minus_1 : x1 = w_minus_1 : EndIf
        y1 = y + radius : If y1 > h_minus_1 : y1 = h_minus_1 : EndIf
        q_C3 = (x1 - x0 + 1) * (y1 - y0 + 1)
        
        pos_pixel = (y1 * w + x1)
        q_S3 = *adr6\q[pos_pixel]
        ! mov rax, [p.v_pos_pixel]
        ! shl rax, 4
        ! movdqu xmm10, [rsi + rax]
        
        ! pxor xmm1, xmm1
        ! pxor xmm2, xmm2
        ! pxor xmm3, xmm3
        
        If y0 > 0
          pos_pixel = ((y0 - 1) * w + x1) : q_S3 - *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm1, [rsi + rax]
        EndIf
        If x0 > 0
          pos_pixel = (y1 * w + (x0 - 1)) : q_S3 - *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm2, [rsi + rax]
        EndIf
        If x0 > 0 And y0 > 0
          pos_pixel = ((y0 - 1) * w + (x0 - 1)) : q_S3 + *adr6\q[pos_pixel]
          ! mov rax, [p.v_pos_pixel]
          ! shl rax, 4
          ! movdqu xmm3, [rsi + rax]
        EndIf
        
        ! psubd xmm10, xmm1
        ! psubd xmm10, xmm2
        ! paddd xmm10, xmm3 ; xmm10 contient [0, R, G, B] du Q3
        
        ! movdqa xmm4, xmm10
        ! pshufd xmm5, xmm4, 01001110b
        ! paddd xmm4, xmm5
        ! movdqa xmm5, xmm4
        ! pshufd xmm5, xmm5, 11111111b
        ! paddd xmm4, xmm5
        ! movd [p.v_sum_l], xmm4
        
        currentVar = q_S3 / q_C3 - (sum_l / q_C3) * (sum_l / q_C3)
        If currentVar < minVar : minVar = currentVar : minIndex = 3 : EndIf
        
        ; =====================================================================
        ; SELECTION UNIQUE DU GAGNANT
        ; =====================================================================
        Select minIndex
          Case 0 : invC = 1.0 / q_C0 : ! movdqa xmm0, xmm0
          Case 1 : invC = 1.0 / q_C1 : ! movdqa xmm0, xmm8
          Case 2 : invC = 1.0 / q_C2 : ! movdqa xmm0, xmm9
          Case 3 : invC = 1.0 / q_C3 : ! movdqa xmm0, xmm10
        EndSelect
        
        ; On extrait les canaux uniquement du gagnant, à la toute fin !
        ! pshufd xmm1, xmm0, 01010101b
        ! movd [p.v_sum_l], xmm1
        r = sum_l
        
        ! pshufd xmm1, xmm0, 10101010b
        ! movd [p.v_sum_l], xmm1
        g = sum_l
        
        ! pshufd xmm1, xmm0, 11111111b
        ! movd [p.v_sum_l], xmm1
        b = sum_l
        
        
        ; =====================================================================
        ; APPLICATION DU BLUR FINALE EN ASM SSE
        ; =====================================================================
        ; Inversion de xmm0 pour passer de BGRA à ARGB au format Float (votre correction)
        ! cvtdq2ps xmm0, xmm0
        ! shufps xmm0, xmm0, 00011011b
        
        ; 1. Charger le pixel d'origine (BGRA) et l'éclater en 4 flottants 32-bits
        ! mov rax, [p.v_pos_pixel]
        ! mov rdx, [p.p_adr0]
        ! movd xmm1, [rdx + rax * 4]    ; xmm1 = [A1, R1, G1, B1] (en mémoire)
        ! pxor xmm5, xmm5
        ! punpcklbw xmm1, xmm5          ; Élargit les octets en Words (16-bits)
        ! punpcklwd xmm1, xmm5          ; Élargit en DWords (32-bits entiers)
        ! cvtdq2ps xmm1, xmm1           ; Convertit en Single Float: xmm1 = [A1, R1, G1, B1]
        
        ; 2. Préparer les facteurs multiplicateurs
        ! movss xmm2, [p.v_invC]
        ! shufps xmm2, xmm2, 00000000b  
        
        ! movss xmm3, [p.v_sharpness]
        ! shufps xmm3, xmm3, 00000000b  
        
        ! movss xmm4, [p.v_inv_sharpness]
        ! shufps xmm4, xmm4, 00000000b  
        
        ; 3. Calculer la moyenne du quadrant choisi
        ! mulps xmm0, xmm2              ; xmm0 = Moyenne calculée
        
        ; 4. Formule de mixage vectorielle
        ! mulps xmm0, xmm3              ; xmm0 = Moyenne * sharpness
        ! mulps xmm1, xmm4              ; xmm1 = PixelOrigine * inv_sharpness
        ! addps xmm0, xmm1              ; xmm0 = Résultat final combiné
        
        ; 5. AJOUT DU CLAMPING (Évite les bugs de pixels qui flashent)
        ;! maxps xmm0, xmm5              ; Force le minimum à 0.0 (xmm5 vaut 0)
        ;! mov rcx, $437f0000437f0000    ; Constante float 255.0
        ;! movq xmm2, rcx
        ;! punpckldq xmm2, xmm2          ; xmm2 = [255.0, 255.0, 255.0, 255.0]
        ;! minps xmm0, xmm2              ; Force le maximum à 255.0
        
        ; 6. Reconvertir en entiers 32-bits et empaqueter
        ! cvtps2dq xmm0, xmm0           
        ! packssdw xmm0, xmm5
        ! packuswb xmm0, xmm5
        
        ; 7. AJOUT DE LA RESTAURATION DE L'ALPHA D'ORIGINE
        ! movd r8d, xmm0                ; r8d = le pixel calculé
        ! mov ecx, [rdx + rax * 4]      ; ecx = recharge le pixel d'origine depuis *adr0
        ! and ecx, $FF000000            ; Isole le canal Alpha d'origine
        ! and r8d, $00FFFFFF            ; Nettoie l'Alpha calculé (qui a été massacré par les maths)
        ! or ecx, r8d                   ; Fusionne l'Alpha d'origine avec ton RGB parfait
        
        ; 9. Écriture directe dans le buffer de destination
        ! mov rdx, [p.p_adr1]
        ! mov [rdx + rax * 4], ecx      ; On écrit ECX au lieu de xmm0 pour injecter le pixel corrigé
        
        
      Next 
    Next 
  EndWith
EndProcedure

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 218
; FirstLine = 227
; Folding = -
; EnableXP
; DPIAware