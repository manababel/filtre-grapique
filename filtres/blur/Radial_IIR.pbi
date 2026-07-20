Procedure RadialBlur_IIR_MT_SSE4(*FilterCtx.FilterParams)
EndProcedure
Procedure RadialBlur_IIR_MT_AVX(*FilterCtx.FilterParams)
EndProcedure
Procedure RadialBlur_IIR_MT_AVX512(*FilterCtx.FilterParams)
EndProcedure

Procedure RadialBlur_IIR_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected cx = (\option[1] * lg) / 100
    Protected cy = (\option[2] * ht) / 100
    Protected pos, i, j
    Protected cosA.f, sinA.f
    Protected maxRadius
    Protected px.f, py.f
    Protected ipx.l, ipy.l
    Protected Alpha.f, inv_Alpha.f
    Protected quality = \option[3]
    Protected *scr.Pixel32
    Protected *dst.Pixel32
    
    Alpha = Exp(-2.3 / (\option[0] + 1))
    inv_Alpha = 1.0 - alpha
    maxRadius = Sqr(lg * lg + ht * ht)
    Protected tt = 360 * quality
    
    Protected *cosTable.Floatarray = \addr[2]
    Protected *sinTable.Floatarray = \addr[3]
    Protected *source = \addr[0]
    Protected *output = \addr[1]
    
    macro_calul_tread(tt)
    
    Protected firstPixel.l
    
    ; --- Pré-chargement des constantes SSE ---
    !movss xmm6, [p.v_Alpha]
    !shufps xmm6, xmm6, 0         ; xmm6 = [Alpha, Alpha, Alpha, Alpha]
    !movss xmm7, [p.v_inv_Alpha]
    !shufps xmm7, xmm7, 0         ; xmm7 = [inv_Alpha, inv_Alpha, inv_Alpha, inv_Alpha]
    !pxor xmm4, xmm4              ; xmm4 = [0, 0, 0, 0] pour déballage
    
    ; --- Génération dynamique des masques RGB et Alpha sans DataSection ---
    !mov eax, $00FFFFFF
    !movd xmm8, eax               ; xmm8 = Masque RGB [$00FFFFFF, 0, 0, 0]
    !mov eax, $FF000000
    !movd xmm9, eax               ; xmm9 = Masque Alpha [$FF000000, 0, 0, 0]
    
    ; On fixe rsi et rdi avant les boucles
    !mov rsi, [p.p_source]        
    !mov rdi, [p.p_output]        
    
    For i = thread_start To thread_stop
      
      cosA = *cosTable\f[i]
      sinA = *sinTable\f[i]
      
      !pxor xmm5, xmm5              ; Réinitialisation de l'accumulateur flou
      firstPixel = #True
      
      For j = 0 To maxRadius
        px = cx + (j * cosA)
        py = cy + (j * sinA)
        
        If px < 0.0 Or py < 0.0 Or px >= lg Or py >= ht
          Continue
        EndIf
        
        ipx = Int(px)
        ipy = Int(py)
        
        If ipx < 0 Or ipy < 0 Or ipx >= lg Or ipy >= ht
          Continue
        EndIf
        
        pos = (ipy * lg + ipx) << 2
        
        ; --- BLOC SSE2 OPTIMISÉ ---
        !mov rax, [p.v_pos]
        !movd xmm0, [rsi + rax]       ; xmm0 = [0, 0, 0, pixel_source]
        
        !movaps xmm1, xmm0            ; xmm1 = Sauvegarde pour l'Alpha d'origine
        
        ; Déballage du pixel en flottants
        !punpcklbw xmm0, xmm4         
        !punpcklwd xmm0, xmm4         
        !cvtdq2ps xmm0, xmm0          ; xmm0 = [?, r1, g1, b1] en float
        
        If firstPixel
          !movaps xmm5, xmm0          ; L'accumulateur prend le premier pixel
          firstPixel = #False
        Else
          !mulps xmm5, xmm6           ; Alpha * accum
          !mulps xmm0, xmm7           ; inv_Alpha * pixel_courant
          !addps xmm5, xmm0           ; accum mis à jour
        EndIf
        
        ; Saturation matérielle automatique [0-255]
        !movaps xmm0, xmm5
        !cvttps2dq xmm0, xmm0         
        !packssdw xmm0, xmm0          
        !packuswb xmm0, xmm0          ; xmm0 = [0, 0, 0, new_RGB]
        
        ; Fusion de l'Alpha d'origine et du RGB calculé via nos masques registres
        !pand xmm0, xmm8              ; xmm0 & $00FFFFFF (Garde uniquement le RGB calculé)
        !pand xmm1, xmm9              ; xmm1 & $FF000000 (Garde uniquement l'Alpha d'origine)
        !por xmm0, xmm1               ; Fusion (RGB | Alpha)
        
        ; Écriture directe en RAM
        !movd [rdi + rax], xmm0
        ; --- FIN DU BLOC SSE2 ---
        
      Next
    Next
  EndWith
EndProcedure

Procedure RadialBlur_IIR_MT_PB(*FilterCtx.FilterParams)
  With FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected cx = (\option[1] * lg) / 100
    Protected cy = (\option[2] * ht) / 100
    Protected pos , i , j
    Protected cosA.f , sinA.f
    Protected maxRadius
    Protected a , r.f , g.f , b.f
    Protected r1 ,g1 ,b1
    Protected firstPixel = #True
    Protected px , py
    Protected Alpha.f , inv_Alpha.f
    Protected quality = \option[3]
    Protected *scr.Pixel32
    Protected *dst.Pixel32
    Alpha = Exp(-2.3 / (\option[0] + 1))
    inv_Alpha = 1 - alpha
    maxRadius = Sqr(lg * lg + ht * ht)
    Protected tt = 360 * quality
    
    macro_calul_tread(tt)
    ;For i = 0 To (360 * quality) - 1
    For i = thread_start To thread_stop
      cosA = PeekF(\addr[2] + i <<2)
      sinA = PeekF(\addr[3] + i <<2)
      ; Variables pour flou IIR
      r = 0 : g = 0 : b = 0
      firstPixel = #True
      For j = 0 To maxRadius
        ; Position en cartésien
        px = cx + (j * cosA)
        py = cy + (j * sinA)
        If px < 0 Or py < 0 Or px >= lg Or py >= ht : Continue : EndIf
        ; Lecture pixel depuis buffer source (nearest neighbor)
        pos = ((py) * lg + (px)) << 2
        *scr = \addr[0] + pos
        getargb(*scr\l , a , r1 , g1 , b1)
        If firstPixel
          r = r1  : g = g1  : b = b1 
          firstPixel = #False
        Else
          ; Application du flou IIR exponentiel
          r = (Alpha * r + inv_Alpha * r1)
          g = (Alpha * g + inv_Alpha * g1)
          b = (Alpha * b + inv_Alpha * b1)
        EndIf
        ; Écriture dans image temporaire
        r1 = r
        g1 = g
        b1 = b
        clamp_rgb(r1,g1,b1)
        *dst = \addr[1] + pos
        *dst\l = (a << 24) | (r1 << 16) | (g1 << 8) | b1
      Next
    Next
  EndWith
EndProcedure

Procedure RadialBlur_IIREx( *FilterCtx.FilterParams )
  ; Mode interface : renseigner les informations sur les options si demandé
  Restore RadialBlur_IIR_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With FilterCtx
    Protected i , angle.f
    Protected quality = \option[3]
    Protected inv_quality.f = 1/quality
    Protected Dim rc.f(360 * quality)
    Protected Dim rs.f(360 * quality)
    For i = 0 To (360 * quality) - 1
      angle = Radian(i * inv_quality) 
      rc(i) = Cos(angle)
      rs(i) = Sin(angle)
    Next
    \addr[2] = @rc()
    \addr[3] = @rs()
    
  EndWith
  
  selet_and_start_programme(RadialBlur_IIR_MT)
  mask_update(*FilterCtx.FilterParams , last_data)
  
  FreeArray(rc())
  FreeArray(rs())
EndProcedure

Procedure RadialBlur_IIR(source , cible , mask , Rayon , posx , posy , qualite)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = Rayon
    \option[1] = posx
    \option[2] = posy
    \option[3] = qualite
  EndWith
  RadialBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RadialBlur_IIR_data:
  Data.s "RadialBlur_IIR"
  Data.s "version sse2 plus lente que la version pb"
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Rayon"         
  Data.i 1,50,25
  Data.s "Pos X"         
  Data.i 0,100,50
  Data.s "Pos Y"         
  Data.i 0,100,50
  Data.s "qualité"         
  Data.i 0,128,32
  Data.s "XXX"
EndDataSection

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 103
; FirstLine = 69
; Folding = --
; EnableXP
; DPIAware