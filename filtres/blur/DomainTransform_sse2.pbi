; ---------------------------------------------------
; Domain Transform - Version Sécurisée Intégrale
; ---------------------------------------------------

Procedure DomainTransform_Image_IntToFloat_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *adr0.PixelArray = \addr[0]
    Protected *adr13.FloatArray = \addr[3] ; Remplace adr3, 4 et 5
    Protected total = \image_lg[0] * \image_ht[1]
    macro_calul_tread(total) ; Définit thread_start et thread_stop
    !mov rsi, [p.p_adr0]     ; Source (Pixels 32-bits BGRA / RGBA)
    !mov rdi, [p.p_adr13]    ; Destination unique (4 floats par pixel = 16 octets)
    !mov r8,  [p.v_thread_start] 
    !mov r10, [p.v_thread_stop]
    !pxor xmm7, xmm7         ; xmm7 = [0, 0, 0, 0] (Masque de zéros pour l'unpck)
    !mov r9 , r8
    !shl r9 , 4
    !.DomainTransform_Image_IntToFloat_MT_SSE2_loop_pixel:
      !movd xmm0, [rsi + r8 * 4]     ; xmm0 = [ 0, 0, 0, 0 | 0, 0, 0, 0 | 0, 0, 0, 0 | A, R, G, B ]
      !punpcklbw xmm0, xmm7 
      !punpcklwd xmm0, xmm7         ; xmm0 = [ A_int32 | R_int32 | G_int32 | B_int32 ]
      !cvtdq2ps xmm0, xmm0          ; xmm0 = [ A.f | R.f | G.f | B.f ]
      !movups [rdi + r9], xmm0       ; Écrit d'un coup A ,R, G et B  (votre "trou") en mémoire
      !add r9 , 16
      !inc r8
      !cmp r8, r10
    !jb .DomainTransform_Image_IntToFloat_MT_SSE2_loop_pixel
  EndWith
EndProcedure

; --- Calcul Dx ---

Procedure DomainTransform_ComputeDx_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *adr6.FloatArray = \addr[5]     ; Destination (Format plat 1 float/pixel)
    Protected *adr13.FloatArray = \addr[3]   ; Source unifiée (R, G, B, Trou)
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, pos
    Protected.f factor = 1.0 / \option[1] 
    Protected lgMinus1 = lg - 1
    macro_calul_tread(ht) ; Définit thread_start et thread_stop
    Protected thread_start_local = thread_start
    Protected thread_stop_local = thread_stop
    ; Préparation des constantes pour le SSE
    Protected.f one = 1.0
    Protected.i sign_mask = $7FFFFFFF
    ; Chargement des constantes dans les registres SSE
    !movss xmm4, [p.v_factor]
    !shufps xmm4, xmm4, 0          ; xmm4 = [factor, factor, factor, factor]
    !movss xmm5, [p.v_one]
    !shufps xmm5, xmm5, 0          ; xmm5 = [1.0, 1.0, 1.0, 1.0]
    !movd xmm6, [p.v_sign_mask]
    !shufps xmm6, xmm6, 0          ; xmm6 = masque pour Abs() [0x7FFFFFFF x 4]
    For y = thread_start_local To thread_stop_local - 1
      pos = y * lg
      Protected *pSrc  = *adr13 + (pos * 16) 
      Protected *pDest = *adr6 + (pos * 4)   ; Destination plate (4 octets par pixel)
      !mov rcx, [p.v_lgMinus1]     ; Compteur de la boucle X
      !cmp rcx, 0
      !jle l_skip_line_DomainTransform_ComputeDx_MT_SSE2 ; Sécurité si la largeur est <= 1
      !mov rsi, [p.p_pSrc]         ; rsi pointe sur le pixel courant dans *adr13
      !mov rdi, [p.p_pDest]        ; rdi pointe sur la destination dans *adr6
      !l_loop_x_DomainTransform_ComputeDx_MT_SSE2:
        !movups xmm0, [rsi]        ; xmm0 = [ Trou  |  R  |  G  |  B  ] (Pixel Courant)
        !movups xmm1, [rsi + 16]   ; xmm1 = [ Trou' |  R' |  G' |  B' ] (Pixel Suivant, +16 octets)
        !subps xmm0, xmm1          ; xmm0 = [ dTrou | db  | dg  | dr  ]
        !andps xmm0, xmm6          ; xmm0 = [ Abs(dTrou) | Abs(dr) | Abs(dg) | Abs(db) ]
        !movaps xmm1, xmm0
        !shufps xmm1, xmm1, $01    ; xmm1 = [ ?, ?, ?, Abs(dg) ]
        !addss xmm0, xmm1          ; xmm0[élément 0] = Abs(dr) + Abs(dg)
        !movaps xmm2, xmm0
        !shufps xmm2, xmm2, $02    ; xmm2 = [ ?, ?, ?, Abs(db) ]
        !addss xmm0, xmm2          ; xmm0[élément 0] = Abs(dr) + Abs(dg) + Abs(db) = diff
        !mulss xmm0, xmm4          ; xmm0 = factor * diff
        !addss xmm0, xmm5          ; xmm0 = 1.0 + (factor * diff)
        !movss [rdi], xmm0
        !add rsi, 16               ; Prochain pixel source (saut de 16 octets / 4 floats)
        !add rdi, 4                ; Prochain pixel destination (saut de 4 octets / 1 float)
        !dec rcx
      !jnz l_loop_x_DomainTransform_ComputeDx_MT_SSE2
      !l_skip_line_DomainTransform_ComputeDx_MT_SSE2:
      !mov rdi, [p.p_pDest]
      !mov rsi, [p.v_lgMinus1]
      !movss xmm0, [p.v_one]
      !movss [rdi + rsi * 4], xmm0
    Next
  EndWith
EndProcedure
    
; --- Calcul Dy ---
Procedure DomainTransform_ComputeDy_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *adr7.FloatArray = \addr[6]     ; Destination (Format plat 1 float/pixel)
    Protected *adr13.FloatArray = \addr[3]   ; Source unifiée (R, G, B, Trou)
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, pos
    Protected.f factor = 1.0 / \option[1]
    Protected htMinus1 = ht - 1
    macro_calul_tread(ht) ; Définit thread_start et thread_stop   
    Protected thread_start_local = thread_start
    Protected thread_stop_local = thread_stop
    Protected.f one = 1.0
    Protected.i sign_mask = $7FFFFFFF
    Protected line_stride = lg * 16
    !movss xmm4, [p.v_factor]
    !shufps xmm4, xmm4, 0          ; xmm4 = [factor, factor, factor, factor]
    !movss xmm5, [p.v_one]
    !shufps xmm5, xmm5, 0          ; xmm5 = [1.0, 1.0, 1.0, 1.0]
    !movd xmm6, [p.v_sign_mask]
    !shufps xmm6, xmm6, 0          ; xmm6 = masque pour Abs()
    !mov r8, [p.v_line_stride]     ; r8 = pas d'une ligne dans le buffer source (*16)
    For y = thread_start_local To thread_stop_local - 1
      pos = y * lg
      Protected *pSrc  = *adr13 + (pos * 16) ; Source entrelacée (16 octets par pixel)
      Protected *pDest = *adr7 + (pos * 4)   ; Destination plate (4 octets par pixel)
      !mov rcx, [p.v_lg]           ; Compteur X
      !cmp rcx, 0
      !jle .skip_line_y_DomainTransform_ComputeDy_MT_SSE2
      !mov rsi, [p.p_pSrc]         ; rsi pointe sur le pixel courant dans *adr13
      !mov rax, [p.p_pDest]        ; rax pointe sur la destination dans *adr7
      !mov r9, [p.v_y]
      !cmp r9, [p.v_htMinus1]
      !je .loop_x_last_line_DomainTransform_ComputeDy_MT_SSE2
      !.loop_x_y_DomainTransform_ComputeDy_MT_SSE2:
        !movups xmm0, [rsi]        ; xmm0 = [ Trou  |  B  |  G  |  R  ] (Pixel Courant)
        !movups xmm1, [rsi + r8]   ; xmm1 = [ Trou' | B'  | G'  | R'  ] (Pixel du dessous)
        !subps xmm0, xmm1          ; xmm0 = [ dTrou | db  | dg  | dr  ]
        !andps xmm0, xmm6          ; xmm0 = [ Abs(dTrou) | Abs(db) | Abs(dg) | Abs(dr) ]
        !movaps xmm1, xmm0
        !shufps xmm1, xmm1, $01    ; xmm1 = [ ?, ?, ?, Abs(dg) ]
        !addss xmm0, xmm1          ; xmm0[0] = Abs(dr) + Abs(dg)
        !movaps xmm2, xmm0
        !shufps xmm2, xmm2, $02    ; xmm2 = [ ?, ?, ?, Abs(db) ]
        !addss xmm0, xmm2          ; xmm0[0] = Abs(dr) + Abs(dg) + Abs(db) = diff
        !mulss xmm0, xmm4
        !addss xmm0, xmm5
        !movss [rax], xmm0
        !add rsi, 16               ; Pixel suivant dans la source (+16 octets)
        !add rax, 4                ; Pixel suivant dans la destination (+4 octets)
        !dec rcx
      !jnz .loop_x_y_DomainTransform_ComputeDy_MT_SSE2
      !jmp .skip_line_y_DomainTransform_ComputeDy_MT_SSE2
      !.loop_x_last_line_DomainTransform_ComputeDy_MT_SSE2:
        !movss [rax], xmm5         ; Écrit 1.0
        !add rax, 4
        !dec rcx
      !jnz .loop_x_last_line_DomainTransform_ComputeDy_MT_SSE2
      !.skip_line_y_DomainTransform_ComputeDy_MT_SSE2:
    Next
  EndWith
EndProcedure

; --- Filtre Horizontal Indexé (Zéro risque de plantage) ---
Procedure DomainTransform_FilterH_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, pos
    Protected.f sigma = \option[0]
    Protected.f exp_factor = -1.0 / (1.41421356 * sigma)
    Protected.f alpha, dist, invAlpha
    Protected *adr13.FloatArray = \addr[3] ; Source unifiée
    Protected *adr14.FloatArray = \addr[4] ; Destination unifiée
    Protected *adr6.FloatArray  = \addr[5]  ; Distances Dx
    macro_calul_tread(ht) ; Définit thread_start et thread_stop
    Protected lgMinus1 = lg - 1
    
    Protected *pDest.FloatArray
    Protected *pDistDx.FloatArray
    Protected *pFirstSrc.FloatArray 
    Protected *pSrcX.FloatArray 
    Protected *pDestX.FloatArray 
    Protected *pDistDxX.FloatArray 
      
    For y = thread_start To thread_stop - 1
      pos = y * lg
      
      *pDest.FloatArray = *adr14 + (pos * 16)
      *pDistDx.FloatArray = *adr6 + (pos * 4)
      
      ; =======================================================================
      ; 1. PASSE GAUCHE -> DROITE
      ; =======================================================================
      ; On copie le premier pixel de la source (adr13) vers la destination (adr14)
      *pFirstSrc  = *adr13 + (pos * 16)
      !mov rsi, [p.p_pFirstSrc]
      !mov rdi, [p.p_pDest]
      !movups xmm0, [rsi]
      !movups [rdi], xmm0             ; Premier pixel copié
      ; On se positionne sur le DEUXIÈME pixel (x = 1) pour commencer le filtrage
      *pSrcX    = *adr13 + ((pos + 1) * 16)
      *pDestX   = *adr14 + ((pos + 1) * 16)
      *pDistDxX = *pDistDx
      For x = 1 To lg - 1
        dist = *pDistDxX\f[0]
        alpha = Exp(dist * exp_factor)
        invAlpha = 1.0 - alpha
        *pDistDxX + 4               ; Avance le pointeur de distance (+1 float)
        !mov rsi, [p.p_pSrcX]       ; Charger l'adresse du pixel source courant
        !mov rdi, [p.p_pDestX]      ; Charger l'adresse du pixel destination courant
        !movss xmm4, [p.v_alpha]
        !shufps xmm4, xmm4, 0       ; xmm4 = [alpha, alpha, alpha, alpha]
        !movss xmm5, [p.v_invAlpha]
        !shufps xmm5, xmm5, 0       ; xmm5 = [invAlpha, invAlpha, invAlpha, invAlpha]
        !movups xmm0, [rdi - 16]    ; xmm0 = prev (le pixel de GAUCHE déjà écrit dans adr14)
        !movups xmm1, [rsi]         ; xmm1 = src (le pixel COURANT de la source adr13)
        !mulps xmm0, xmm4           ; alpha * prev
        !mulps xmm1, xmm5           ; invAlpha * src
        !addps xmm0, xmm1           ; xmm0 = (alpha * prev) + (invAlpha * src)
        !movups [rdi], xmm0         ; Écrit le résultat dans la destination (adr14)
        *pSrcX + 16                 ; Avance le pointeur source
        *pDestX + 16                ; Avance le pointeur destination
      Next
      
      ; =======================================================================
      ; 2. PASSE DROITE -> GAUCHE
      ; =======================================================================
        *pDest = *adr14 + (((y * lg) + (lg - 2)) * 16)
        *pDistDx = *adr6 + (((y * lg) + (lg - 2)) * 4)
        For x = lgMinus1 - 1 To 0 Step -1
          dist = *pDistDx\f[0]
          alpha = Exp(dist * exp_factor)
          invAlpha = 1.0 - alpha
          *pDistDx - 4                 ; Recule la distance de façon stable en PureBasic
          !mov rdi, [p.p_pDest]        ; On recharge rdi à chaque tour pour être ultra-sûr
          !movss xmm4, [p.v_alpha]
          !shufps xmm4, xmm4, 0
          !movss xmm5, [p.v_invAlpha]
          !shufps xmm5, xmm5, 0
          !movups xmm0, [rdi + 16]    ; Charge le pixel de DROITE depuis la RAM
          !movups xmm1, [rdi]         ; Charge le pixel COURANT depuis la RAM
          !mulps xmm0, xmm4           ; alpha * VoisinDroite
          !mulps xmm1, xmm5           ; invAlpha * Courant
          !addps xmm0, xmm1           ; Somme
          !movups [rdi], xmm0         ; Écrit le résultat in-place
          *pDest - 16                 ; On fait reculer le pointeur PureBasic pour le prochain tour
        Next
    Next
  EndWith
EndProcedure

; --- Filtre Vertical Indexé (Zéro risque de plantage) ---
Procedure DomainTransform_FilterV_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, pos
    Protected.f sigma = \option[0]
    Protected.f exp_factor = -1.0 / (1.41421356 * sigma)
    Protected.f alpha, dist, invAlpha
    Protected *adr14.FloatArray = \addr[4] ; Buffer Image (Lecture/Écriture In-place)
    Protected *adr7.FloatArray  = \addr[6]  ; Distances Dy
    macro_calul_tread(lg)                   ; Définit thread_start et thread_stop (par colonne)
    Protected htMinus1 = ht - 1
    Protected src_stride  = lg * 16         ; Saut d'une ligne pour les pixels (16 octets)
    Protected dist_stride = lg * 4          ; Saut d'une ligne pour les distances (4 octets)
    
    For x = thread_start To thread_stop - 1
      
      ; =======================================================================
      ; 1. PASSE HAUT -> BAS (Utilise la relecture [rdi - src_stride])
      ; =======================================================================
        Protected *pDestY.FloatArray   = *adr14 + (ht * 16) ; Variable de travail pour la boucle
        Protected *pDistDyY.FloatArray = *adr7  + (x * 4)   ; Pointeur distance (commence en haut de la colonne)
        *pDestY  = *adr14 + (((1 * lg) + x) * 16)
        For y = 1 To htMinus1
          dist = *pDistDyY\f[0]
          alpha = Exp(dist * exp_factor)
          invAlpha = 1.0 - alpha
          *pDistDyY + dist_stride     ; Avance d'une ligne pour la distance suivante
          !mov rdi, [p.p_pDestY]      ; Recharge l'adresse du pixel courant (Ligne y)
          !mov r8,  [p.v_src_stride]  ; Sécurité : on recharge le stride à chaque tour
          !movss xmm4, [p.v_alpha]
          !shufps xmm4, xmm4, 0
          !movss xmm5, [p.v_invAlpha]
          !shufps xmm5, xmm5, 0
          !mov rdx, [p.p_pDestY]     ; rdx = pixel courant (Ligne Y)
          !sub rdx, [p.v_src_stride] ; rdx = rdx - stride (on recule d'une ligne)
          !movups xmm0, [rdx]        ; xmm0 = Pixel du DESSUS (Ligne Y-1)
          !movups xmm1, [rdi]         ; Pixel COURANT
          !mulps xmm0, xmm4           ; alpha * dessus
          !mulps xmm1, xmm5           ; invAlpha * courant
          !addps xmm0, xmm1
          !movups [rdi], xmm0         ; Écrit le résultat
          *pDestY + src_stride        ; Avance le pointeur de pixel d'une ligne
        Next
      ; =======================================================================
      ; 2. PASSE BAS -> HAUT (Utilise la relecture [rdi + src_stride])
      ; =======================================================================
        Protected *pDestBack.FloatArray = *adr14 + (((ht - 2) * lg + x) * 16)
        Protected *pDistBack.FloatArray = *adr7  + (((ht - 2) * lg + x) * 4)
        For y = htMinus1 - 1 To 0 Step -1
          dist = *pDistBack\f[0]
          alpha = Exp(dist * exp_factor)
          invAlpha = 1.0 - alpha
          *pDistBack - dist_stride     ; Recule d'une ligne pour la distance
          !mov rdi, [p.p_pDestBack]    ; Recharge l'adresse du pixel courant
          !mov r8,  [p.v_src_stride]   ; Sécurité absolue du registre de stride
          !movss xmm4, [p.v_alpha]
          !shufps xmm4, xmm4, 0
          !movss xmm5, [p.v_invAlpha]
          !shufps xmm5, xmm5, 0
          !movups xmm0, [rdi + r8]    ; Pixel du DESSOUS (déjà filtré)
          !movups xmm1, [rdi]         ; Pixel COURANT
          !mulps xmm0, xmm4           ; alpha * dessous
          !mulps xmm1, xmm5           ; invAlpha * courant
          !addps xmm0, xmm1
          !movups [rdi], xmm0         ; Écrit le résultat in-place
          *pDestBack - src_stride     ; Recule le pointeur de pixel d'une ligne
        Next
    Next
  EndWith
EndProcedure



; --- Écriture finale ---
Procedure DomainTransform_WriteBack_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[1]
    
    Protected *adr0.PixelArray = \addr[0]     ; Image d'origine (pour récupérer l'Alpha)
    Protected *adr1.PixelArray = \addr[1]     ; Image de sortie finale (32-bits ARGB/RGBA)
    Protected *adr14.FloatArray = \addr[4]   ; Vos données filtrées finales (4 floats/pixel)
    
    macro_calul_tread(total) ; Définit thread_start et thread_stop
  EndWith
  
  !mov rsi, [p.p_adr14]     ; Source : Données filtrées Floats
  !mov rdx, [p.p_adr0]      ; Source 2 : Pixels d'origine (Alpha)
  !mov rdi, [p.p_adr1]      ; Destination : Pixels de sortie finaux
  !mov r8,  [p.v_thread_start]
  !.DomainTransform_WriteBack_MT_SSE2_loop:
    !mov r9, r8
    !shl r9, 4                   ; r9 = r8 * 16
    !movups xmm0, [rsi + r9]     ; xmm0 = [ Trou | B.f | G.f | R.f ]
    !cvtps2dq xmm0, xmm0         ; xmm0 = [ Trou_int | B_int | G_int | R_int ]
    !packssdw xmm0, xmm0         ; Convertit les entiers 32 bits en entiers 16 bits signés (saturés)
    !packuswb xmm0, xmm0         ; Convertit les entiers 16 bits en 8 bits non-signés (saturés à 0-255 !)
    !movd eax, xmm0              ; eax = [ Trou | B | G | R ] (au format 32-bits standard de votre machine)
    !mov ecx, [rdx + r8 * 4]     ; ecx = Pixel original complet [ A | B_orig | G_orig | R_orig ]
    !and ecx, $FF000000          ; On efface R, G, B pour ne garder que l'Alpha (Bits de poids fort)
    !and eax, $00FFFFFF          ; On nettoie le "Trou" du pixel généré par précaution
    !or  eax, ecx                ; Fusion magique par masquage : Alpha_orig + R,G,B_filtrés
    !mov [rdi + r8 * 4], eax
    !inc r8
    !cmp r8, [p.v_thread_stop]
  !jb .DomainTransform_WriteBack_MT_SSE2_loop
  
EndProcedure






; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 3
; Folding = --
; EnableXP
; DPIAware