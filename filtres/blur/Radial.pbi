Procedure RadialBlur_MT_SSE4(*FilterCtx.FilterParams)
EndProcedure
Procedure RadialBlur_MT_AVX(*FilterCtx.FilterParams)
EndProcedure
Procedure RadialBlur_MT_AVX512(*FilterCtx.FilterParams)
EndProcedure

Procedure RadialBlur_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected Radius = \option[0]
    If Radius < 1 : Radius = 1 : EndIf
    Protected cx = (\option[1] * lg) / 100
    Protected cy = (\option[2] * ht) / 100
    Protected rmax = (\option[3] * Sqr(lg*lg+ht*ht) )/ 100
    If rmax < 1 : rmax = 1 : EndIf
    
    Protected.f rmax2 = rmax * rmax
    Protected.f samp = 1.0 / (Radius + 1)
    
    Protected *source = \addr[0]
    Protected *output = \addr[1]
    
    Protected.l x, y, i
    Protected.f lgMinus1 = lg - 1
    Protected.f htMinus1 = ht - 1
    
    macro_calul_tread(ht)
    
    ; Sécurisation de l'environnement
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    
    ; --- Pré-chargement des constantes SSE ---
    !movss xmm8, [p.v_lgMinus1]
    !shufps xmm8, xmm8, 0         ; xmm8 = [lg-1, lg-1, lg-1, lg-1]
    !movss xmm9, [p.v_htMinus1]
    !shufps xmm9, xmm9, 0         ; xmm9 = [ht-1, ht-1, ht-1, ht-1]
    !xorps xmm10, xmm10           ; xmm10 = [0.0, 0.0, 0.0, 0.0] (Borne basse)
    !pxor xmm7, xmm7              ; xmm7 = [0, 0, 0, 0] (Zéro entier pour déballage)
    
    Protected.f fOne = 1.0
    !movss xmm12, [p.v_fOne]
    !shufps xmm12, xmm12, 0       ; xmm12 = [1.0, 1.0, 1.0, 1.0]
    
    !mov r8, [p.v_lg]             ; r8 = Largeur (pour calculs d'index)
    !mov rsi, [p.p_source]        ; rsi = Pointeur image source
    !mov rdi, [p.p_output]        ; rdi = Pointeur image destination
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        
        ; Offset mémoire du pixel actuel
        Protected pixelOffset = (y * lg + x) << 2
        
        ; 1. Calcul de la distance au centre
        Protected.f dx = x - cx
        Protected.f dy = y - cy
        
        !movss xmm0, [p.v_dx]
        !mulss xmm0, xmm0         ; dx * dx
        !movss xmm1, [p.v_dy]
        !mulss xmm1, xmm1         ; dy * dy
        !addss xmm0, xmm1         ; xmm0 = dist = dx*dx + dy*dy
        
        !movss xmm1, [p.v_rmax2]
        !comiss xmm0, xmm1
        !jbe .l_radial_process     ; Si dist <= rmax2, on applique le flou
        
        ; --- CAS : dist > rmax2 (Copie brute du pixel source) ---
        !mov rdx, [p.v_pixelOffset]
        !mov eax, [rsi + rdx]
        !mov [rdi + rdx], eax
        Continue
        
        !.l_radial_process:
        ; 2. Calcul de la force d'atténuation du flou : force = (rmax2 - dist) / rmax2
        !movss xmm2, [p.v_rmax2]
        !subss xmm2, xmm0         ; rmax2 - dist
        !divss xmm2, [p.v_rmax2]  ; xmm2 = force
        
        ; Sécurité force < 0 -> force = 0
        !maxss xmm2, xmm10        ; xmm2 = force (clampée basse à 0.0)
        !shufps xmm2, xmm2, 0     ; xmm2 = [force, force, force, force]
        
        ; Calcul des pas de déplacement (dxStep, dyStep)
        Protected.f dxStep = (cx - x) * samp
        Protected.f dyStep = (cy - y) * samp
        
        ; Registres accumulateurs pour la boucle de rayon
        !pxor xmm5, xmm5          ; xmm5 = Accumulateur RGB flou [0, R, G, B]
        
        ; Initialisation des coordonnées de lancer (fx, fy) dans les registres
        !cvtsi2ss xmm13, [p.v_x]  ; xmm13 = fx = (float)x
        !cvtsi2ss xmm14, [p.v_y]  ; xmm14 = fy = (float)y
        
        ; 3. BOUCLE DE RAYON (Accumulation des échantillons)
        For i = 0 To Radius
          
          ; Test des limites : 0.0 <= fx <= lg-1 et 0.0 <= fy <= ht-1
          !movss xmm0, xmm10
          !cmpless xmm0, xmm13    ; 0.0 <= fx
          !movss xmm6, xmm13
          !cmpless xmm6, xmm8     ; fx <= lg-1
          !andps xmm0, xmm6
          
          !movss xmm1, xmm10
          !cmpless xmm1, xmm14    ; 0.0 <= fy
          !movss xmm6, xmm14
          !cmpless xmm6, xmm9     ; fy <= ht-1
          !andps xmm1, xmm6
          
          !andps xmm0, xmm1       ; Masque final dans xmm0
          !movd eax, xmm0
          !test eax, eax
          !jz .l_skip_radial_sample
          
          ; Coordonnées entières de lecture (sx, sy)
          !cvttss2si eax, xmm13   ; eax = Int(fx)
          !cvttss2si ecx, xmm14   ; ecx = Int(fy)
          
          !movsxd rax, eax
          !movsxd rcx, ecx
          !imul rcx, r8
          !add rax, rcx           ; rax = sy * lg + sx
          
          
          ; Lecture du pixel échantillonné
          !movd xmm4, [rsi + rax * 4]
          !punpcklbw xmm4, xmm7
          !punpcklwd xmm4, xmm7   ; xmm4 = [0, R, G, B] (Entiers 32-bit)
          !paddd xmm5, xmm4       ; Accumulation
          
          !.l_skip_radial_sample:
          ; Avancement du rayon : fx += dxStep, fy += dyStep
          !addss xmm13, [p.v_dxStep]
          !addss xmm14, [p.v_dyStep]
        Next
        
        ; 4. CALCUL DE LA MOYENNE DU FLOU : r = r * samp
        !movss xmm0, [p.v_samp]
        !shufps xmm0, xmm0, 0     ; xmm0 = [samp, samp, samp, samp]
        !cvtdq2ps xmm5, xmm5      ; Conversion de l'accumulateur en float
        !mulps xmm5, xmm0         ; xmm5 = Pixel Flouté Moyen [A, R, G, B] (Flottants)
        
        ; 5. INTERPOLATION FINALE (LERP) AVEC LE PIXEL D'ORIGINE
        !mov rdx, [p.v_pixelOffset]
        !movd xmm3, [rsi + rdx]   ; xmm3 = Pixel Original Brut
        
        ; Sauvegarde sécurisée du canal Alpha d'origine
        !movd eax, xmm3
        !and eax, $FF000000       ; eax = [A, 0, 0, 0]
        
        ; Déballage du pixel d'origine en flottants
        !punpcklbw xmm3, xmm7
        !punpcklwd xmm3, xmm7   
        !cvtdq2ps xmm3, xmm3      ; xmm3 = Pixel Original (Flottants)
        
        ; Formule mathématique : Original + force * (Flou - Original)
        !subps xmm5, xmm3         ; xmm5 = (Flou - Original)
        !mulps xmm5, xmm2         ; xmm5 = force * (Flou - Original)
        !addps xmm5, xmm3         ; xmm5 = Original + force * (Flou - Original)
        
        ; 6. SATURATION ET RECONSTITUTION 32-BIT
        !cvttps2dq xmm5, xmm5     ; Re-conversion en entiers
        !packssdw xmm5, xmm5     
        !packuswb xmm5, xmm5      ; Clamping matériel strict entre 0 et 255
        
        !movd ecx, xmm5           ; ecx = [ ?, R, G, B ]
        !and ecx, $00FFFFFF       ; Nettoyage du canal Alpha calculé
        !or eax, ecx              ; Fusion de l'Alpha d'origine (eax) avec le RGB (ecx)
        
        ; Écriture finale dans l'image de destination
        !mov [rdi + rdx], eax
        
      Next
    Next
    
    ; Restauration de l'environnement
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
  EndWith
EndProcedure

Procedure RadialBlur_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
  Protected lg = \image_lg[0]
  Protected ht = \image_ht[0]
  Protected Radius = \option[0]
  If Radius < 1 : Radius = 1 : EndIf
  Protected cx = (\option[1] * lg) / 100
  Protected cy = (\option[2] * ht) / 100
  Protected rmax = (\option[3] * Sqr(lg*lg+ht*ht) )/ 100
  If rmax < 1 : rmax = 1 : EndIf
  Protected rmax2.f = rmax * rmax
  Protected samp.f = 1 / (Radius + 1)
  Protected *scr1.Pixel32
  Protected *dst.Pixel32


  Protected x, y, i, sx, sy
  Protected dx, dy, fx.f, fy.f
  Protected r1, g1, b1, r.f, g.f , b.f , a
  Protected dist.f, force.f

    macro_calul_tread(ht)
    For y = thread_start To thread_stop -1
    Protected rowOffset = y * lg * 4
    dy = y - cy
    For x = 0 To lg - 1
      dx = x - cx
      dist = dx*dx + dy*dy
      Protected pixelOffset = rowOffset + x * 4
      If dist > rmax2
        *scr1 = \addr[0] + pixelOffset
        *dst = \addr[1] + pixelOffset
        *dst\l = *scr1\l
        Continue
      EndIf
      force = (rmax2 - dist) / rmax2
      If force < 0 : force = 0 : EndIf
      Protected dxStep.f = ((cx - x) * samp)
      Protected dyStep.f = ((cy - y) * samp)
      fx = x
      fy = y
      r = 0
      g = 0
      b = 0
      For i = 0 To Radius
        sx = fx
        sy = fy
        If sx >= 0 And sx < lg And sy >= 0 And sy < ht
          *scr1 = \addr[0] + (sy * lg + sx) * 4
          getrgb(*scr1\l, r1, g1, b1)
          r = r + r1
          g = g + g1
          b = b + b1
        EndIf
        fx + dxStep
        fy + dyStep
      Next
      r = r * samp
      g = g * samp
      b = b * samp
      *scr1 = \addr[0] + pixelOffset
      getargb(*scr1\l , a , r1, g1, b1)
      r1 = r * force + r1 * (1 - force)
      g1 = g * force + g1 * (1 - force)
      b1 = b * force + b1 * (1 - force)
      clamp_rgb(r1, g1, b1)
      *dst = \addr[1] + pixelOffset
      *dst\l = (a << 24) | (r1 << 16) | (g1 << 8) | b1
    Next
  Next
EndWith
EndProcedure


Procedure RadialBlurEx( *FilterCtx.FilterParams )
  Restore RadialBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf 
  selet_and_start_programme(RadialBlur_MT)
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure RadialBlur(source , cible , mask , echantillonnage , posx , posy , rmax)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = echantillonnage
    \option[1] = posx
    \option[2] = posy
    \option[3] = rmax
  EndWith
  RadialBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RadialBlur_data:
  Data.s "RadialBlur"
  Data.s ""
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "échantillonnage"         
  Data.i 1,50,25
  Data.s "Pos X"         
  Data.i 0,100,50
  Data.s "Pos Y"         
  Data.i 0,100,50
  Data.s "Rayon Max"         
  Data.i 0,100,50
  Data.s "XXX"
EndDataSection

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 263
; FirstLine = 237
; Folding = --
; EnableXP
; DPIAware
; DisableDebugger