Procedure DirectionalBoxBlur_MT_SSE4(*FilterCtx.FilterParams)
EndProcedure
Procedure DirectionalBoxBlur_MT_AVX(*FilterCtx.FilterParams)
EndProcedure
Procedure DirectionalBoxBlur_MT_AVX512(*FilterCtx.FilterParams)
EndProcedure

Procedure DirectionalBoxBlur_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.pixelarray = \addr[0]
    Protected *output.pixelarray = \addr[1]
    Protected width   = \image_lg[0]
    Protected height  = \image_ht[0]
    Protected angle.f  = \option[0] * #PI / 180.0
    Protected radius   = \option[1]
    
    Protected dx.f = Cos(angle)
    Protected dy.f = Sin(angle)
    
    Protected.l x, y, i
    Protected widthMinus1.f = width - 1
    Protected heightMinus1.f = height - 1
    
    macro_calul_tread(height)
    
    ; Sécurisation de l'environnement via tes macros personnalisées
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    
    ; --- Pré-chargement des constantes SSE ---
    !movss xmm8, [p.v_widthMinus1]
    !shufps xmm8, xmm8, 0         ; xmm8 = [width-1, width-1, width-1, width-1]
    !movss xmm9, [p.v_heightMinus1]
    !shufps xmm9, xmm9, 0         ; xmm9 = [height-1, height-1, height-1, height-1]
    !xorps xmm10, xmm10           ; xmm10 = [0.0, 0.0, 0.0, 0.0] (Borne basse)
    !pxor xmm7, xmm7              ; xmm7 = [0, 0, 0, 0]
    
    ; Constante float 1.0
    Protected.f fOne = 1.0
    !movss xmm12, [p.v_fOne]
    !shufps xmm12, xmm12, 0       ; xmm12 = [1.0, 1.0, 1.0, 1.0]
    
    !mov r8, [p.v_width]            ; r8 = Largeur de l'image
    !mov rsi, [p.p_source]          ; rsi = Pointeur source stable
    
    For y = thread_start To thread_stop - 1
      For x = 0 To width - 1
        
        ; Calcul de l'adresse mémoire exacte du pixel de destination
        Protected pixel_idx = *output + ((y * width + x) << 2)
        
        !pxor xmm5, xmm5 
        !xorps xmm11, xmm11 
        
        ; --- Pré-calcul hors de la boucle i ---
        !cvtsi2ss xmm13, [p.v_x]    ; xmm13 = (float) x
        !cvtsi2ss xmm14, [p.v_y]    ; xmm14 = (float) y
        !movss xmm15, [p.v_dx]      ; xmm15 = dx
        
        For i = -radius To radius
          
          ; --- Remplacement ASM complet de sx et sy ---
          !cvtsi2ss xmm1, [p.v_i]   ; xmm1 = (float) i
          !movss xmm0, xmm1       ; xmm0 = i
          
          !mulss xmm0, xmm15      ; xmm0 = i * dx
          !addss xmm0, xmm13      ; xmm0 = x + (i * dx) -> xmm0 = sx
          
          !mulss xmm1, [p.v_dy]     ; xmm1 = i * dy
          !addss xmm1, xmm14      ; xmm1 = y + (i * dy) -> xmm1 = sy
          
          ; --- Test des limites vectoriel CORRIGÉ ---
          ; Rappel : cmpless A, B  =>  A = (A <= B) ? $FFFFFFFF : 0
          
          ; Vérification X : sx >= 0 (0 <= sx) et sx <= widthMinus1
          !movss xmm2, xmm10
          !cmpless xmm2, xmm0     ; xmm2 = (0.0 <= sx) ? $FFFFFFFF : 0
          !movss xmm6, xmm0
          !cmpless xmm6, xmm8     ; xmm6 = (sx <= width-1) ? $FFFFFFFF : 0
          !andps xmm2, xmm6       ; xmm2 = Valide en X
          
          ; Vérification Y : sy >= 0 (0 <= sy) et sy <= heightMinus1
          !movss xmm3, xmm10
          !cmpless xmm3, xmm1     ; xmm3 = (0.0 <= sy) ? $FFFFFFFF : 0
          !movss xmm6, xmm1
          !cmpless xmm6, xmm9     ; xmm6 = (sy <= height-1) ? $FFFFFFFF : 0
          !andps xmm3, xmm6       ; xmm3 = Valide en Y
          
          !andps xmm2, xmm3       ; Masque final (X et Y valides)
          
          !movd eax, xmm2
          !test eax, eax
          !jz .l_skip_pixel_add   ; Si le pixel est hors-bornes, on saute !
          
          ; --- Lecture et accumulation du pixel ---
          !cvttss2si eax, xmm0    
          !cvttss2si ecx, xmm1    
          
          !movsxd rax, eax
          !movsxd rcx, ecx
          !imul rcx, r8
          !add rax, rcx           ; rax = offset (sy * width + sx)
          
          !movd xmm4, [rsi + rax * 4] 
          
          !punpcklbw xmm4, xmm7
          !punpcklwd xmm4, xmm7   
          
          !paddd xmm5, xmm4       
          !addss xmm11, xmm12
          
          !.l_skip_pixel_add:
        Next
        
        ; --- TRAITEMENT DU COMPTEUR ---
        !comiss xmm11, xmm10
        !jbe .l_boxblur_zero_pixel
        
        !movss xmm6, [p.v_fOne]
        !divss xmm6, xmm11        
        !shufps xmm6, xmm6, 0     
        
        !cvtdq2ps xmm5, xmm5      
        !mulps xmm5, xmm6         
        !cvttps2dq xmm5, xmm5     
        
        ; --- SATURATION (CLAMP 0-255) ET EXTRACTION VECTORIELLE ---
        !packssdw xmm5, xmm5     
        !packuswb xmm5, xmm5     
        
        !movd eax, xmm5
        !and eax, $00FFFFFF       ; Nettoyage canal Alpha
        !jmp .l_boxblur_write
        
        !.l_boxblur_zero_pixel:
        !xor eax, eax             ; Couleur noire si aucun pixel valide
        
        !.l_boxblur_write:
        !mov rdx, [p.v_pixel_idx]
        !mov [rdx], eax           ; Écriture finale sans crash
        
      Next
    Next
    
    ; Restauration de l'environnement
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
  EndWith
EndProcedure

Procedure DirectionalBoxBlur_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    ; Utilisation de structures .pixelarray pour un accès direct
    Protected *source.pixelarray = \addr[0]
    Protected *output.pixelarray = \addr[1]
    Protected width   = \image_lg[0]
    Protected height = \image_ht[0]
    Protected angle.f  = \option[0] * #PI / 180.0
    Protected radius   = \option[1]
    
    ; Précalcul des valeurs constantes
    Protected dx.f = Cos(angle)
    Protected dy.f = Sin(angle)
    Protected invCount.f
    
    Protected x, y, i
    Protected sx.f, sy.f
    Protected rSum, gSum, bSum  ; Entiers pour l'accumulation
    Protected r, g, b, count
    Protected col, r1, g1, b1, posOffset
    
    macro_calul_tread(height)
    For y = thread_start To thread_stop -1
      For x = 0 To width - 1
        rSum = 0 : gSum = 0 : bSum = 0 : count = 0
        For i = -radius To radius
          sx = x + i * dx
          sy = y + i * dy
          ; Vérification des limites en une seule condition
          If sx >= 0 And sx < width And sy >= 0 And sy < height
            ; Calcul de la position dans le tableau (PureBasic gère le * 4 en interne avec \l)
            posOffset = (Int(sy) * width + Int(sx))
            ; Remplacement de PeekL par l'accès direct via pointeur
            getrgb(*source\l[posOffset], r1, g1, b1)
            rSum + r1 : gSum + g1 : bSum + b1
            count + 1
          EndIf
        Next
        If count > 0
          invCount = 1.0 / count
          r = rSum * invCount
          g = gSum * invCount
          b = bSum * invCount
        Else
          r = 0 : g = 0 : b = 0
        EndIf
        ; Remplacement de PokeL par l'écriture directe via pointeur
        *output\l[y * width + x] = (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure DirectionalBoxBlurEx(*FilterCtx.FilterParams)
  Restore DirectionalBoxBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[0] << 2  ; Bit shift au lieu de * 4
     \addr[2] = AllocateMemory(total)
    If Not \addr[2] : ProcedureReturn : EndIf
    CopyMemory(\image[0], \addr[2], total)
    \addr[0] = \addr[2]
    \addr[1] = \image[1]
    Protected i, passes = \option[2]
    For i = 1 To passes
      selet_and_start_programme(DirectionalBoxBlur_MT)
      If i < passes
        CopyMemory(\addr[1], \addr[0], total)
      EndIf
    Next
    mask_update(*FilterCtx.FilterParams , last_data)
    FreeMemory(\addr[2])
  EndWith
EndProcedure

Procedure DirectionalBoxBlur(source , cible , mask , angle , radius , ndp)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = angle
    \option[1] = radius
    \option[2] = ndp
  EndWith
  DirectionalBoxBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  DirectionalBoxBlur_data:
  Data.s "DirectionalBlur"
  Data.s ""
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Angle (°)"       
  Data.i 1,360,0
  Data.s "Radius"   
  Data.i 1,32,8
  Data.s "Nombre de passes"        
  Data.i 1,3,1
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 206
; FirstLine = 196
; Folding = --
; EnableXP
; DPIAware