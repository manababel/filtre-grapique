Procedure ZoomBlur_MT_SSE4(*FilterCtx.FilterParams)
EndProcedure
Procedure ZoomBlur_MT_AVX(*FilterCtx.FilterParams)
EndProcedure
Procedure ZoomBlur_MT_AVX512(*FilterCtx.FilterParams)
EndProcedure

Procedure ZoomBlur_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected.l lg = \image_lg[0], ht = \image_ht[0]
    Protected strength.f = \option[0] / 100.0  ; Force du zoom (0-100)
    Protected samples = \option[1]              ; Nombre d'échantillons
    Protected centerX.f = \option[2] / 100.0   ; Position X du centre (0-100)
    Protected centerY.f = \option[3] / 100.0   ; Position Y du centre (0-100)
    
    If samples < 2 : samples = 2 : EndIf
    If samples > 50 : samples = 50 : EndIf
    
    ; Calcul du centre en pixels
    Protected cx.f = lg * centerX
    Protected cy.f = ht * centerY
    
    Protected.l x, y, i
    Protected sx.l, sy.l, index
    Protected.f dx, dy, t, scale
    Protected.l invSamples
    Protected *src = \addr[0]
    Protected *dst = \addr[1]
    Protected lg_minus_1 = lg - 1
    Protected ht_minus_1 = ht - 1
    
    invSamples = Round((65536.0 / samples), #PB_Round_Nearest) ;1.0 / samples
    
    macro_calul_tread(ht)
    
    !mov eax, [p.v_invSamples]
    !movd xmm2, eax
    !pshuflw xmm2, xmm2, 0 
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        dx = x - cx
        dy = y - cy
        !pxor xmm4, xmm4 
        For i = 0 To samples - 1
          scale = 1.0 - (i / (samples - 1.0)) * strength
          sx = Round(cx + dx * scale, #PB_Round_Nearest)
          sy = Round(cy + dy * scale, #PB_Round_Nearest)
          clamp(sx , 0 , lg_minus_1)
          clamp(sy , 0 , ht_minus_1)
          !mov eax , [p.v_lg]
          !imul eax , [p.v_sy]
          !add eax , [p.v_sx]
          !mov rcx , [p.p_src]
          !movd xmm0 , [rcx + rax * 4]            ; xmm0 = [0, 0, 0, 0 | A, R, G, B] (8-bits)          
          !pxor xmm1, xmm1              ; xmm1 = 0
          !punpcklbw xmm0, xmm1         ; xmm0 = [0, A, 0, R | 0, G, 0, B] (16-bits)
          !paddw xmm4, xmm0             
        Next
        !pmulhw xmm4, xmm2            ; xmm4 contient maintenant les moyennes directes !
        !packuswb xmm4, xmm4          ; 16-bits -> 8-bits (Clamp 0-255 intégré)
        !mov eax , [p.v_lg]
        !imul eax, [p.v_y]
        !add eax , [p.v_x]
        !mov rcx, [p.p_dst]
        !movd [rcx + rax * 4], xmm4             ; Écriture ARGB directe
      Next
    Next
  EndWith
EndProcedure

Procedure ZoomBlur_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected strength.f = \option[0] / 100.0  ; Force du zoom (0-100)
    Protected samples = \option[1]             ; Nombre d'échantillons
    Protected centerX.f = \option[2] / 100.0   ; Position X du centre (0-100)
    Protected centerY.f = \option[3] / 100.0   ; Position Y du centre (0-100)
    
    If samples < 2 : samples = 2 : EndIf
    If samples > 50 : samples = 50 : EndIf
    
    ; Calcul du centre en pixels
    Protected cx.f = lg * centerX
    Protected cy.f = ht * centerY
    
    Protected x, y, i
    Protected sumR.f, sumG.f, sumB.f, sumA.f
    Protected sx, sy, index, value
    Protected r, g, b, a
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0
        
        ; Vecteur du centre vers le pixel
        Protected dx.f = x - cx
        Protected dy.f = y - cy
        
        ; Échantillonnage le long du rayon
        For i = 0 To samples - 1
          Protected t.f = i / (samples - 1.0)  ; 0.0 à 1.0
          Protected scale.f = 1.0 - t * strength
          
          ; Position échantillonnée
          sx = cx + dx * scale
          sy = cy + dy * scale
          
          ; Clamp
          If sx < 0 : sx = 0 : EndIf
          If sx >= lg : sx = lg - 1 : EndIf
          If sy < 0 : sy = 0 : EndIf
          If sy >= ht : sy = ht - 1 : EndIf
          
          index = (sy * lg + sx) << 2
          value = PeekL(\addr[0] + index)
          
          a = ((value >> 24) & $FF)
          r =  ((value >> 16) & $FF)
          g =  ((value >> 8) & $FF)
          b =  (value & $FF)
          sumA + a
          sumR + r
          sumG + g
          sumB + b
        Next
        
        ; Moyenne
        a = sumA / samples
        r = sumR / samples
        g = sumG / samples
        b = sumB / samples
        
        Clamp(a, 0, 255)
        Clamp(r, 0, 255)
        Clamp(g, 0, 255)
        Clamp(b, 0, 255)
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure ZoomBlurEx(*FilterCtx.FilterParams)
  Restore ZoomBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  *FilterCtx\asm_dispo = 1
  selet_and_start_programme(ZoomBlur_MT)
  mask_update(*FilterCtx.FilterParams , last_data)
  
EndProcedure

Procedure ZoomBlur(source , cible , mask , Force , echantillons , cx , cy )
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = Force
    \option[1] = echantillons
    \option[2] = cx
    \option[3] = cy
  EndWith
  ZoomBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  ZoomBlur_data:
  Data.s "ZoomBlur"
  Data.s "Flou de zoom radial depuis un point central"
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Force"       
  Data.i 1,100,20
  Data.s "Échantillons"   
  Data.i 0,50,10
  Data.s "Centre X (%)"        
  Data.i 0,100,50
  Data.s "Centre Y (%)"  
  Data.i 0,100,50
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; Folding = --
; EnableXP
; DPIAware