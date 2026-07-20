Procedure SpiralBlur_Separable_MT_SSE4(*FilterCtx.FilterParams)
EndProcedure
Procedure SpiralBlur_Separable_MT_AVX(*FilterCtx.FilterParams)
EndProcedure
Procedure SpiralBlur_Separable_MT_AVX512(*FilterCtx.FilterParams)
EndProcedure

Procedure SpiralBlur_Separable_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.PixelArray = \addr[0]
    Protected *cible.PixelArray  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected Radius = \option[0]
    Protected cx.f = (\option[1] * lg) / 100
    Protected cy.f = (\option[2] * ht) / 100
    Protected force.i = \option[3] - 360
    Protected x, y , k
    Protected kernelSize.i, sampleDist.f
    Protected.l al, rl, gl, bl
    Protected.f af, rf, gf, bf
    Protected.i sx , sy
    Protected.f dx , dy, dist
    Protected.f angle , newAngle , samples
    
    Protected Dim tab_acc.f(3)
    Protected acc = @tab_acc()
    ; Récupération des limites du Thread fournies par ton macro_calul_tread
    macro_calul_tread(ht) 
    
    kernelSize = Radius
    If kernelSize < 1 : kernelSize = 1 : EndIf
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        
        ; Coordonnées polaires locales
        dx.f = x - cx
        dy.f = y - cy
        dist.f = Sqr(dx * dx + dy * dy)
        
        ; Éviter le pixel central exact (division par zéro / NaN)
        If dist < 0.1 : dist = 0.1 : EndIf
        
        angle.f = ATan2(dx, dy) ; Vérifie l'ordre x/y selon ta version de PB
        
        ; Rotation dérivée de la distance
        newAngle.f = angle + (force * dist / 10000.0)
        
        samples.f = 0
        
        af = 0 : rf = 0 : gf = 0 : bf = 0
        tab_acc(0) = 0 : tab_acc(1) = 0: tab_acc(2) = 0: tab_acc(3) = 0
        
        ; Échantillonnage le long du rayon modifié par la spirale
        For k = -kernelSize To kernelSize
          sampleDist = dist + k
          
          ; On s'assure de rester dans des distances positives
          If sampleDist < 0 : Continue : EndIf 
          
          sx.i = cx + sampleDist * Cos(newAngle)
          sy.i = cy + sampleDist * Sin(newAngle)

          ; Bornes incluses correctement (< lg et < ht)
          If sx >= 0 And sx < lg And sy >= 0 And sy < ht
            
            ; --- Lecture Source ---
            !mov eax, [p.v_sy]
            !imul eax, [p.v_lg]        
            !add eax, [p.v_sx]
            !mov rcx, [p.p_source]     
            !movd xmm0, [rcx + rax * 4] 
            
            !pxor xmm1, xmm1
            !punpcklbw xmm0, xmm1       ; xmm0 = [0A, 0R, 0G, 0B]
            !punpcklwd xmm0, xmm1       ; xmm0 = [0A, 0R, 0G, 0B]
            !cvtdq2ps xmm0, xmm0
            
            !mov rax,[p.v_acc]
            !addps xmm0 , [rax]
            !movups [rax] , xmm0
            samples + 1
          EndIf
        Next
        
        ; Application au buffer de destination
        If samples > 0
          !movss xmm1, [p.v_samples]        ; xmm1 = [0, 0, 0, samples]
          !shufps xmm1, xmm1, 0             ; xmm1 = [samples, samples , samples , samples]
          !mov rax,[p.v_acc]
          !movups xmm0 , [rax] 
          !divps xmm0 , xmm1
          !cvttps2dq xmm0, xmm0 
          !packssdw xmm0, xmm0              ; 32-bit vers 16-bit
          !packuswb xmm0, xmm0              ; 16-bit vers 8-bit (unsigned avec saturation)
          
          !mov eax, [p.v_y]
          !imul eax, [p.v_lg]        
          !add eax, [p.v_x]
          !mov rcx, [p.p_cible]     
          !movd [rcx + rax * 4] , xmm0

        Else
          ; Sécurité : si aucun sample, on garde le pixel d'origine
          If Not \option[4]
            *cible\l[(y * lg + x)] = *source\l[(y * lg + x)]
          Else
            *cible\l[(y * lg + x)] = 0
          EndIf
        EndIf
      Next
    Next
    
  EndWith
EndProcedure

Procedure SpiralBlur_Separable_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected Radius = \option[0]
    Protected cx.f = (\option[1] * lg) / 100
    Protected cy.f = (\option[2] * ht) / 100
    Protected force.i = \option[3] - 360
    Protected *src.PixelArray = \addr[0]
    Protected *dst.PixelArray = \addr[1]
    Protected x, y
    Protected kernelSize.i, sampleDist.f
    Protected.l al, rl, gl, bl
    Protected.f af, rf, gf, bf
    
    ; Récupération des limites du Thread fournies par ton macro_calul_tread
    macro_calul_tread(ht) 
    
    kernelSize = Radius
    If kernelSize < 1 : kernelSize = 1 : EndIf
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        
        ; Coordonnées polaires locales
        Protected dx.f = x - cx
        Protected dy.f = y - cy
        Protected dist.f = Sqr(dx * dx + dy * dy)
        
        ; Éviter le pixel central exact (division par zéro / NaN)
        If dist < 0.1 : dist = 0.1 : EndIf
        
        Protected angle.f = ATan2(dx, dy) ; Vérifie l'ordre x/y selon ta version de PB
        
        ; Rotation dérivée de la distance
        Protected newAngle.f = angle + (force * dist / 10000.0)
        
        Protected samples.f = 0
        Protected k
        
        af = 0 : rf = 0 : gf = 0 : bf = 0
        
        ; Échantillonnage le long du rayon modifié par la spirale
        For k = -kernelSize To kernelSize
          sampleDist = dist + k
          
          ; On s'assure de rester dans des distances positives
          If sampleDist < 0 : Continue : EndIf 
          
          Protected sx.i = cx + sampleDist * Cos(newAngle)
          Protected sy.i = cy + sampleDist * Sin(newAngle)
          
          ; Bornes incluses correctement (< lg et < ht)
          If sx >= 0 And sx < lg And sy >= 0 And sy < ht
            getargb(*src\l[sy * lg + sx] , al, rl, gl, bl)
            af + al
            rf + rl
            gf + gl
            bf + bl
            samples + 1
          EndIf
        Next
        
        ; Application au buffer de destination
        If samples > 0
          al = af / samples
          rl = rf / samples
          gl = gf / samples
          bl = bf / samples
          *dst\l[(y * lg + x)] = (al << 24) | (rl << 16) | (gl << 8) | bl
        Else
          ; Sécurité : si aucun sample, on garde le pixel d'origine
          If Not \option[4]
            *dst\l[(y * lg + x)] = *src\l[(y * lg + x)]
          Else
            *dst\l[(y * lg + x)] = 0
          EndIf
        EndIf
      Next
    Next
    
  EndWith
EndProcedure

Procedure spiral_SeparableEx(*FilterCtx.FilterParams)
  Restore spiral_Separable_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  selet_and_start_programme(SpiralBlur_Separable_MT)
  mask_update(*FilterCtx.FilterParams, last_data)
EndProcedure

Procedure spiral_Separable(source, cible, mask, rayon, posx, posy, force , fond = 0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = posx
    \option[2] = posy
    \option[3] = force
    \option[4] = fond
  EndWith
  spiral_SeparableEx(FilterCtx.FilterParams)
EndProcedure

; --- Métadonnées (inchangées, elles sont déjà correctes) ---
DataSection
  spiral_Separable_data:
  Data.s "spiral_Separable"
  Data.s "appliquer un filtre de flou en spirale"
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Rayon du filtre"       
  Data.i 1,99,5
  Data.s "Pos X"   
  Data.i 0,100,50
  Data.s "Pos Y"        
  Data.i 0,100,50
  Data.s "Force de rotation"  
  Data.i 0,720,360
  Data.s "fond noir"  
  Data.i 0,1,0
  Data.s "XXX"  
EndDataSection

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 26
; FirstLine = 7
; Folding = --
; EnableXP
; DPIAware