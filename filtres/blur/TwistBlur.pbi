Procedure TwistBlur_MT_SSE4(*FilterCtx.FilterParams)
EndProcedure
Procedure TwistBlur_MT_AVX(*FilterCtx.FilterParams)
EndProcedure
Procedure TwistBlur_MT_AVX512(*FilterCtx.FilterParams)
EndProcedure

Procedure TwistBlur_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.PixelArray = \addr[0]
    Protected *cible.PixelArray  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected centerX.f = \option[0] / 100.0  ; Centre X (0-100%)
    Protected centerY.f = \option[1] / 100.0  ; Centre Y (0-100%)
    Protected maxAngle.f = \option[2] * #PI / 180.0  ; Angle max en radians
    Protected radius.f = \option[3]                  ; Rayon d'effet
    Protected samples = \option[4]
    
    ; Déclarations locales obligatoires en début de procédure
    Protected t.f
    Protected x, y, i
    Protected count.f
    Protected sx.l, sy.l, rotAngle.f
    Protected index, value
    Protected r, g, b, a
    Protected dx.f, dy.f, distance.f, cosA.f, sinA.f
    Protected rx.f, ry.f, angleAmount.f
    
    clamp(samples , 2 , 50)
    If radius < 1 : radius = 1 : EndIf
    
    ; Centre en pixels
    Protected cx.f = lg * centerX
    Protected cy.f = ht * centerY
    
    Protected Dim tab_acc.f(3)
    Protected acc = @tab_acc()
    Protected pixel.l
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        tab_acc(0) = 0 : tab_acc(1) = 0: tab_acc(2) = 0: tab_acc(3) = 0
        count = 0
        ; Position relative au centre
        dx = x - cx
        dy = y - cy
        distance = Sqr(dx * dx + dy * dy)
        
        ; Calcul de l'angle de torsion (dépend de la distance)
        If distance <= radius
          ; Torsion maximale au centre, décroît avec la distance
          angleAmount = 1.0 - (distance / radius)
        Else
          angleAmount = 0.0
        EndIf
        
        ; Échantillonnage le long de l'arc de torsion
        For i = 0 To samples - 1
          t = i / (samples - 1.0)  ; 0.0 à 1.0 (Déclaration déplacée en haut)
          rotAngle = maxAngle * angleAmount * (t - 0.5) * 2.0  ; De -angle à +angle
          
          ; Rotation du vecteur
          cosA = Cos(rotAngle)
          sinA = Sin(rotAngle)
          
          rx = dx * cosA - dy * sinA
          ry = dx * sinA + dy * cosA
          
          ; Position échantillonnée
          sx = cx + rx
          sy = cy + ry
          
          ; Vérification des limites
          If sx >= 0 And sx < lg And sy >= 0 And sy < ht
            
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
            count + 1
          EndIf
        Next
        
        ; Moyenne
        If count > 0
          !movss xmm1, [p.v_count]        ; xmm1 = [0, 0, 0, count]
          !shufps xmm1, xmm1, 0             ; xmm1 = [count, count , count , count]
          !mov rax,[p.v_acc]
          !movups xmm0 , [rax] 
          !divps xmm0 , xmm1
          !cvttps2dq xmm0, xmm0 
          !packssdw xmm0, xmm0              ; 32-bit vers 16-bit
          !packuswb xmm0, xmm0              ; 16-bit vers 8-bit (unsigned avec saturation)
          
          !movd [p.v_pixel] , xmm0
        Else
          ; CORRECTION : Utiliser x et y (le pixel actuel) pour éviter le crash hors-limites
          pixel = *source\l[y * lg + x]
        EndIf
        
        *cible\l[(y * lg + x)] =  pixel
      Next
    Next
  EndWith
EndProcedure

Procedure TwistBlur_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.PixelArray = \addr[0]
    Protected *cible.PixelArray  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected centerX.f = \option[0] / 100.0  ; Centre X (0-100%)
    Protected centerY.f = \option[1] / 100.0  ; Centre Y (0-100%)
    Protected maxAngle.f = \option[2] * #PI / 180.0  ; Angle max en radians
    Protected radius.f = \option[3]                  ; Rayon d'effet
    Protected samples = \option[4]
    
    ; Déclarations locales obligatoires en début de procédure
    Protected t.f
    Protected x, y, i
    Protected sumR.f, sumG.f, sumB.f, sumA.f, count
    Protected sx.l, sy.l, rotAngle.f
    Protected index, value
    Protected r, g, b, a
    Protected dx.f, dy.f, distance.f, cosA.f, sinA.f
    Protected rx.f, ry.f, angleAmount.f
    
    clamp(samples , 2 , 50)
    If radius < 1 : radius = 1 : EndIf
    
    ; Centre en pixels
    Protected cx.f = lg * centerX
    Protected cy.f = ht * centerY
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : count = 0
        
        ; Position relative au centre
        dx = x - cx
        dy = y - cy
        distance = Sqr(dx * dx + dy * dy)
        
        ; Calcul de l'angle de torsion (dépend de la distance)
        If distance <= radius
          ; Torsion maximale au centre, décroît avec la distance
          angleAmount = 1.0 - (distance / radius)
        Else
          angleAmount = 0.0
        EndIf
        
        ; Échantillonnage le long de l'arc de torsion
        For i = 0 To samples - 1
          t = i / (samples - 1.0)  ; 0.0 à 1.0 (Déclaration déplacée en haut)
          rotAngle = maxAngle * angleAmount * (t - 0.5) * 2.0  ; De -angle à +angle
          
          ; Rotation du vecteur
          cosA = Cos(rotAngle)
          sinA = Sin(rotAngle)
          
          rx = dx * cosA - dy * sinA
          ry = dx * sinA + dy * cosA
          
          ; Position échantillonnée
          sx = cx + rx
          sy = cy + ry
          
          ; Vérification des limites
          If sx >= 0 And sx < lg And sy >= 0 And sy < ht
            getargb(*source\l[sy * lg + sx] , a , r , g , b)
            sumA + a
            sumR + r
            sumG + g
            sumB + b
            count + 1
          EndIf
        Next
        
        ; Moyenne
        If count > 0
          a = sumA / count
          r = sumR / count
          g = sumG / count
          b = sumB / count
        Else
          ; CORRECTION : Utiliser x et y (le pixel actuel) pour éviter le crash hors-limites
          getargb(*source\l[y * lg + x] , a , r , g , b)
        EndIf
        
        clamp_argb(a , r , g , b)
        *cible\l[(y * lg + x)] =  (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure TwistBlurEx(*FilterCtx.FilterParams)
  Restore TwistBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  selet_and_start_programme(TwistBlur_MT)
  mask_update(*FilterCtx.FilterParams, last_data)
EndProcedure

Procedure TwistBlur(source, cible, mask, cx, cy, angle, rayon, echantillons)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = cx
    \option[1] = cy
    \option[2] = angle
    \option[3] = rayon
    \option[4] = echantillons
  EndWith
  TwistBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  TwistBlur_data:
  Data.s "TwistBlur"
  Data.s "Flou de torsion (twist) avec rayon d'effet"
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Centre X (%)"        
  Data.i 0, 100, 50
  Data.s "Centre Y (%)"   
  Data.i 0, 100, 50
  Data.s "Angle max (°)"         
  Data.i 0, 360, 90
  Data.s "Rayon d'effet"  
  Data.i 1, 1000, 200
  Data.s "Échantillons"  
  Data.i 2, 50, 15
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 45
; FirstLine = 30
; Folding = --
; EnableXP
; DPIAware