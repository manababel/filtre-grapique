Procedure MotionBlur_MT_SSE4(*FilterCtx.FilterParams)
EndProcedure
Procedure MotionBlur_MT_AVX(*FilterCtx.FilterParams)
EndProcedure
Procedure MotionBlur_MT_AVX512(*FilterCtx.FilterParams)
EndProcedure


Procedure MotionBlur_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.pixelarray = \addr[0]
    Protected *dst.pixelarray = \addr[1]
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected radius = \option[0]
    Protected angle.f = \option[1] * #PI / 180.0
    Protected dx.f = Cos(angle)
    Protected dy.f = Sin(angle)
    Protected size = (radius << 1) + 1
    Protected coeff.f = 1.0 / size
    Protected x, y, k
    Protected wMinus1.f = w - 1
    Protected hMinus1.f = h - 1
    Protected.f xi , yi
    Protected.l final_r, final_g, final_b
    ; Masque SSE pour isoler les octets RGB individuels après déballage
    Protected.q mask_low = $00FF00FF00FF00FF
    
    macro_calul_tread(h) 
    
    ; --- Pré-chargement des constantes SSE (X64 global) ---
    !movss xmm8, [p.v_wMinus1]
    !shufps xmm8, xmm8, 0         ; xmm8 = [wMinus1, wMinus1, wMinus1, wMinus1]
    !movss xmm9, [p.v_hMinus1]
    !shufps xmm9, xmm9, 0         ; xmm9 = [hMinus1, hMinus1, hMinus1, hMinus1]
    !xorps xmm10, xmm10           ; xmm10 = [0.0, 0.0, 0.0, 0.0] (Pour le Max/Clamping des coordonnées)
    !pxor xmm7, xmm7              ; xmm7 = [0, 0, 0, 0] EN ENTIERS (Pour le déballage RGB)
    !movq xmm11, [p.v_mask_low]
    !punpcklqdq xmm11, xmm11      ; xmm11 = $000000FF000000FF000000FF000000FF
    Protected width_rb = w
    !mov r8, [p.v_width_rb]       ; r8 = Largeur de l'image
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        xi = x - dx * radius
        yi = y - dy * radius
        ; Initialisation de l'accumulateur RGB à 0 (4 entiers 32-bit : [0, R, G, B])
        !pxor xmm5, xmm5 
        For k = 0 To size - 1
          ; 1. Clamping des coordonnées (xi, yi)
          !movss xmm0, [p.v_xi]
          !movss xmm1, [p.v_yi]
          !maxss xmm0, xmm10
          !minss xmm0, xmm8             ; xmm0 = xiClamped (float)
          !maxss xmm1, xmm10
          !minss xmm1, xmm9             ; xmm1 = yiClamped (float)
          ; 2. Conversion en entiers 32-bit
          !cvttss2si eax, xmm0          ; eax = (int)xiClamped
          !cvttss2si ecx, xmm1          ; ecx = (int)yiClamped
          ; 3. Calcul de l'adresse du pixel source
          !movsxd rax, eax
          !movsxd rcx, ecx
          !imul rcx, r8
          !add rax, rcx
          !mov rsi, [p.p_src]
          !movd xmm2, [rsi + rax * 4]   ; xmm2 = [ 0, 0, 0, ARGB ]
          ; 4. Déballage des canaux corrigé (On utilise xmm7 au lieu de xmm10)
          !punpcklbw xmm2, xmm7        ; xmm2 = [ 0:A, 0:R, 0:G, 0:B ] (8-bit -> 16-bit)
          !pand xmm2, xmm11             ; Nettoyage via le masque
          !punpcklwd xmm2, xmm7        ; xmm2 = [ 32-bit A, 32-bit R, 32-bit G, 32-bit B ]
          ; 5. Accumulation parallèle dans xmm5
          !paddd xmm5, xmm2 
          xi + dx
          yi + dy
        Next
        ; Convertir les accumulations entières en flottants
        !cvtdq2ps xmm5, xmm5            ; xmm5 = [ (float)A, (float)R, (float)G, (float)B ]
        ; Multiplier par le coefficient de moyenne
        !movss xmm6, [p.v_coeff]
        !shufps xmm6, xmm6, 0           ; xmm6 = [coeff, coeff, coeff, coeff]
        !mulps xmm5, xmm6               ; xmm5 = [A*coeff, R*coeff, G*coeff, B*coeff]
        ; Reconvertir en entiers 32-bit
        !cvttps2dq xmm5, xmm5           ; xmm5 = [ (int)A, (int)R, (int)G, (int)B ]
        ; Extraction des canaux finalisés
        !movd [p.v_final_b], xmm5
        !psrldq xmm5, 4
        !movd [p.v_final_g], xmm5
        !psrldq xmm5, 4
        !movd [p.v_final_r], xmm5
        ; Bornage de sécurité (0 - 255)
        If final_r > 255 : final_r = 255 : EndIf
        If final_g > 255 : final_g = 255 : EndIf
        If final_b > 255 : final_b = 255 : EndIf
        ; Reconstruction du pixel final
        *dst\l[y * w + x] = (final_r << 16) | (final_g << 8) | final_b
      Next
    Next
  EndWith
EndProcedure

Procedure MotionBlur_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.pixelarray = \addr[0]
    Protected *dst.pixelarray = \addr[1]
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected radius = \option[0]
    Protected angle.f = \option[1] * #PI / 180.0
    Protected dx.f = Cos(angle)
    Protected dy.f = Sin(angle)
    Protected size = (radius << 1) + 1  ; Bit shift au lieu de * 2
    Protected coeff.f = 1.0 / size
    Protected x, y, k
    Protected xi.f, yi.f
    Protected xiClamped, yiClamped
    Protected r, g, b  ; Entiers pour l'accumulation
    Protected r1, g1, b1
    Protected wMinus1 = w - 1
    Protected hMinus1 = h - 1
    Protected posOffset
    macro_calul_tread(h) 
    For y = thread_start To thread_stop -1
      For x = 0 To w - 1
        r = 0 : g = 0 : b = 0
        xi = x - dx * radius
        yi = y - dy * radius
        For k = 0 To size - 1
          If xi < 0 : xiClamped = 0 : ElseIf xi >= w : xiClamped = wMinus1 : Else : xiClamped = Int(xi) : EndIf
          If yi < 0 : yiClamped = 0 : ElseIf yi >= h : yiClamped = hMinus1 : Else : yiClamped = Int(yi) : EndIf
          posOffset = (yiClamped * w + xiClamped)
          getrgb(*src\l[posOffset], r1, g1, b1)
          r + r1
          g + g1
          b + b1
          xi + dx
          yi + dy
        Next
        r = r * coeff
        g = g * coeff
        b = b * coeff
        *dst\l[y * w + x] = (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

; ===== Procédure principale Motion Blur orienté =====
Procedure MotionBlurEx(*FilterCtx.FilterParams)
  Restore MotionBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  selet_and_start_programme(MotionBlur_MT)
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure MotionBlur(source , cible , mask , rayon , angle)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = angle
  EndWith
  MotionBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  MotionBlur_data:
  Data.s "MotionBlur"
  Data.s ""
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Rayon"       
  Data.i 1,100,10
  Data.s "Angle"   
  Data.i 0,360,0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 151
; FirstLine = 124
; Folding = --
; EnableXP
; DPIAware