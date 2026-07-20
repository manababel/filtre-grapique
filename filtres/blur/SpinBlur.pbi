Procedure SpinBlur_MT_SSE4(*FilterCtx.FilterParams)
EndProcedure
Procedure SpinBlur_MT_AVX(*FilterCtx.FilterParams)
EndProcedure
Procedure SpinBlur_MT_AVX512(*FilterCtx.FilterParams)
EndProcedure

Macro SpinBlur_create_tab()
  For k = 0 To samples - 1
    If *FilterCtx\option[5] = 1
      t = (k - samples / 2.0) / (samples / 2.0)
      WeightTable(k) = Exp(-t * t * 2.0)
    Else
      WeightTable(k) = 1.0
    EndIf
  Next
EndMacro

Procedure SpinBlur_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.Pixelarray = \addr[0]
    Protected *cible.Pixelarray  = \addr[1]
    
    Protected i, j, k
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected samples = \option[0]      ; Nombre d'échantillons
    Protected angle_max.f = \option[1]  ; Angle maximum en degrés
    Protected cx.f, cy.f                ; Centre de rotation
    
    Protected count
    Protected dx.f, dy.f, dist.f, angle_step.f
    Protected nx.f, ny.f, rx.f, ry.f
    Protected cos_a.f, sin_a.f
    Protected cos_step.f, sin_step.f, cos_next.f
    Protected px, py
    Protected weight.f, total_weight.f
    Protected.f sample_weight
    Protected effective_angle.f
    Protected start_angle.f 
    Protected dy_sq.f
    Protected t.f
    
    ; Structure d'accumulation sur la pile (Tableau de 4 Floats)
    Protected Dim tab_sumRGBA.f(3)
    Protected sumRGBA = @tab_sumRGBA(0)
    
    Protected finalPixel.l
    Protected pixel.l
    
    Dim WeightTable.f(samples)
    SpinBlur_create_tab()
    
    macro_calul_tread(ht)
    
    ; Calcul du centre de rotation
    If \option[2] = -1
      cx = lg / 2.0 : cy = ht / 2.0
    Else
      cx = \option[2] : cy = \option[3]
    EndIf
    
    angle_max = angle_max * #PI / 180.0
    Protected max_dist_sq.f = (lg * lg + ht * ht) / 4.0
    Protected attenuation.f = \option[4] / 100.0
    
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    
    ; Traitement de chaque pixel
    For j = thread_start To thread_stop - 1
      dy = j - cy
      dy_sq = dy * dy
      
      For i = 0 To lg - 1
        dx = i - cx
        dist = Sqr(dx * dx + dy_sq)
        
        ; Application de l'atténuation basée sur la distance
        If attenuation > 0
          weight = 1.0 - (dist / Sqr(max_dist_sq * 4.0)) * attenuation
          If weight < 0.1 : weight = 0.1 : EndIf
        Else
          weight = 1.0
        EndIf
        
        effective_angle = angle_max * weight
        angle_step = effective_angle / (samples - 1)
        
        ; --- CALCUL TRIGONOMÉTRIQUE UNIQUE PAR PIXEL ---
        start_angle = -effective_angle / 2.0
        cos_a = Cos(start_angle)
        sin_a = Sin(start_angle)
        cos_step = Cos(angle_step)
        sin_step = Sin(angle_step)
        
        ; Réinitialisation de l'accumulateur
        tab_sumRGBA(0) = 0.0 : tab_sumRGBA(1) = 0.0 : tab_sumRGBA(2) = 0.0 : tab_sumRGBA(3) = 0.0
        
        count = 0
        total_weight = 0
        
        ; Échantillonnage le long de l'arc de rotation
        For k = 0 To samples - 1
          
          rx = dx * cos_a - dy * sin_a
          ry = dx * sin_a + dy * cos_a
          
          nx = cx + rx
          ny = cy + ry
          
          px = Int(nx + 0.5)
          py = Int(ny + 0.5)
          
          If px >= 0 And px < lg And py >= 0 And py < ht
            pixel = *source\l[py * lg + px]
            sample_weight = WeightTable(k)
            
            ; --- ZONE ASM SSE2 VECTORISÉE (64-BIT EXCLUSIF) ---
            !pxor xmm5, xmm5              ; xmm5 = [0 | 0 | 0 | 0]
            !movd xmm0, [p.v_pixel]       ; xmm0 = [ 0 | 0 | 0 | A.R.G.B ]
            !punpcklbw xmm0, xmm5         ; Converti en Word (16 bits)
            !punpcklwd xmm0, xmm5         ; Converti en DWord (32 bits entier)
            !cvtdq2ps xmm0, xmm0          ; Converti en Float Single [A | R | G | B]
            
            ; Application du poids du sample
            !movss xmm2, [p.v_sample_weight]
            !shufps xmm2, xmm2, 00000000b ; xmm2 = [W | W | W | W]
            !mulps xmm0, xmm2             ; xmm0 = [A*W | R*W | G*W | B*W]
            
            ; Accumulation via registre d'adresse 64 bits RAX
            !mov rax, [p.v_sumRGBA]       ; Récupère le pointeur 64-bit du tableau
            !movups xmm4, [rax]           ; Lit les 4 floats accumulés
            !addps xmm4, xmm0             ; Ajoute le pixel courant pondéré
            !movups [rax], xmm4           ; Réécrit les 4 floats en mémoire
            
            total_weight + sample_weight
            count + 1
          EndIf
          
          ; --- TRIGONOMÉTRIE SANS FONCTION ---
          cos_next = cos_a * cos_step - sin_a * sin_step
          sin_a    = sin_a * cos_step + cos_a * sin_step
          cos_a = cos_next
        Next
        
        If count > 0 And total_weight > 0
          ; --- DIVISION FINALE ET PACKING x64 ---
          !mov rax, [p.v_sumRGBA]       ; Pointeur vers la somme totale
          !movups xmm4, [rax]           ; Charge les 4 floats cumulés
          
          !movss xmm1, [p.v_total_weight]
          !shufps xmm1, xmm1, 00000000b   ; xmm1 = [TW | TW | TW | TW]
          !divps xmm4, xmm1                ; Division ARGB en une seule passe
          
          ; Conversion inverse Float -> Byte avec Saturation
          !cvttps2dq xmm4, xmm4            ; Float -> Int 32
          !packssdw xmm4, xmm4             ; Int 32 -> Int 16 avec saturation
          !packuswb xmm4, xmm4             ; Int 16 -> UInt 8 avec saturation
          
          !movd [p.v_finalPixel], xmm4     ; Enregistre le pixel final
          
          ; Application forcée de l'Alpha à 255 (Opaque)
          *cible\l[j * lg + i] = finalPixel | $FF000000
        Else
          ; Si aucun échantillon valide, copie conforme du pixel d'origine
          *cible\l[j * lg + i] = *source\l[j * lg + i]
        EndIf
        
      Next
    Next
    
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
  EndWith
EndProcedure

Procedure SpinBlur_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.Pixelarray = \addr[0]
    Protected *cible.Pixelarray  = \addr[1]
    
    Protected i, j, k
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected samples = \option[0]      ; Nombre d'échantillons
    Protected angle_max.f = \option[1]  ; Angle maximum en degrés
    Protected cx.f, cy.f                ; Centre de rotation
    
    Protected a.l, r.l, g.l, b.l
    Protected sumA.f, sumR.f, sumG.f, sumB.f 
    Protected count
    Protected dx.f, dy.f, dist.f, angle_step.f
    Protected nx.f, ny.f, rx.f, ry.f
    Protected cos_a.f, sin_a.f
    Protected cos_step.f, sin_step.f, cos_next.f
    Protected px, py
    Protected weight.f, total_weight.f
    Protected sample_weight.f
    Protected t.f
    Protected effective_angle.f
    Protected start_angle.f 
    Protected dy_sq.f
    
    Dim WeightTable.f(samples)
    SpinBlur_create_tab()
    
    macro_calul_tread(ht)
    
    ; Calcul du centre de rotation
    If \option[2] = -1
      cx = lg / 2.0 : cy = ht / 2.0
    Else
      cx = \option[2] : cy = \option[3]
    EndIf
    
    angle_max = angle_max * #PI / 180.0
    Protected max_dist_sq.f = (lg * lg + ht * ht) / 4.0 ; Pré-calcul de la distance max au carré
    Protected attenuation.f = \option[4] / 100.0
    
    ; Traitement de chaque pixel
    For j = thread_start To thread_stop - 1
      dy = j - cy
      dy_sq.f = dy * dy ; Sorti de la boucle i
      For i = 0 To lg - 1
        dx = i - cx
        dist = Sqr(dx * dx + dy_sq)
        ; Application de l'atténuation basée sur la distance
        If attenuation > 0
          weight = 1.0 - (dist / Sqr(max_dist_sq * 4.0)) * attenuation
          If weight < 0.1 : weight = 0.1 : EndIf
        Else
          weight = 1.0
        EndIf
        effective_angle.f = angle_max * weight
        angle_step = effective_angle / (samples - 1)
        ; --- OPTIMISATION TRIGONOMÉTRIQUE ---
        ; 1. On calcule le Cos/Sin de l'angle de départ
        start_angle.f = -effective_angle / 2.0
        cos_a = Cos(start_angle)
        sin_a = Sin(start_angle)
        ; 2. On calcule le Cos/Sin du "pas" (Incrément constant)
        cos_step = Cos(angle_step)
        sin_step = Sin(angle_step)
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
        count = 0
        total_weight = 0
        ; Échantillonnage le long de l'arc de rotation
        For k = 0 To samples - 1
          rx = dx * cos_a - dy * sin_a
          ry = dx * sin_a + dy * cos_a
          nx = cx + rx
          ny = cy + ry
          px = Int(nx + 0.5)
          py = Int(ny + 0.5)
          If px >= 0 And px < lg And py >= 0 And py < ht
            sample_weight = WeightTable(k)
            getargb(*source\l[py * lg + px] , a , r , g , b)
            sumA + a * sample_weight
            sumR + r * sample_weight
            sumG + g * sample_weight
            sumB + b * sample_weight
            total_weight + sample_weight
            count + 1
          EndIf
          ; --- INCULCATION DE L'ANGLE SUIVANT (Trigo sans fonction) ---
          cos_next = cos_a * cos_step - sin_a * sin_step
          sin_a = sin_a * cos_step + cos_a * sin_step
          cos_a = cos_next
        Next
        If count > 0 And total_weight > 0
          a = sumA / total_weight
          r = sumR / total_weight
          g = sumG / total_weight
          b = sumB / total_weight
          *cible\l[j * lg + i] = (a << 24) | (r << 16) | (g << 8) | b
        Else
          *cible\l[j * lg + i] = *source\l[j * lg + i]
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure SpinBlurEx(*FilterCtx.FilterParams)
  Restore SpinBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  ;Create_MultiThread_MT(@SpinBlur_MT())
  selet_and_start_programme(SpinBlur_MT)
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure SpinBlur(source, cible, mask, samples, angle, cx, cy, attenuation, ponderation)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = samples
    \option[1] = angle
    \option[2] = cx
    \option[3] = cy
    \option[4] = attenuation
    \option[5] = ponderation
  EndWith
  SpinBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  SpinBlur_data:
  Data.s "SpinBlur"
  Data.s "Flou de rotation circulaire"
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Qualité (Samples)"
  Data.i 5, 100, 20
  Data.s "Angle (°)"
  Data.i 1, 360, 45
  Data.s "Centre X (-1=auto)"
  Data.i -1, 9999, -1
  Data.s "Centre Y (-1=auto)"
  Data.i -1, 9999, -1
  Data.s "Atténuation (%)"
  Data.i 0, 100, 100
  Data.s "Pondération (0:Unif, 1:Gauss)"
  Data.i 0, 1, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 142
; FirstLine = 180
; Folding = --
; EnableXP
; DPIAware