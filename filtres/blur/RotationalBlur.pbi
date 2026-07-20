Procedure RotationalBlur_MT_SSE4(*FilterCtx.FilterParams)
EndProcedure
Procedure RotationalBlur_MT_AVX(*FilterCtx.FilterParams)
EndProcedure
Procedure RotationalBlur_MT_AVX512(*FilterCtx.FilterParams)
EndProcedure


Procedure RotationalBlur_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.pixelarray = \addr[0]
    Protected *cible.pixelarray  = \addr[1]
    Protected lg.l = \image_lg[0]
    Protected ht.l = \image_ht[0]
    Protected centerX.f = \option[0] / 100.0
    Protected centerY.f = \option[1] / 100.0
    Protected angle.f = \option[2] * #PI / 180.0
    Protected samples = \option[3]
    
    If samples < 2 : samples = 2 : EndIf
    If samples > 50 : samples = 50 : EndIf
    
    ; --- TABLE DE MULTIPLICATION POUR LE SHIFT ---
    Protected Dim InverseTable.l(51)
    Protected t_idx
    For t_idx = 1 To 50
      InverseTable(t_idx) = Round((65536.0 / t_idx), #PB_Round_Nearest)
    Next t_idx
    Protected *pTable = @InverseTable()
    
    Protected cx.f = lg * centerX
    Protected cy.f = ht * centerY
    
    Protected.l x, y, i, count
    Protected.f dx, dy, t, rotAngle, cosA, sinA, rx, ry, sx, sy
    Protected.l lg_minus_1 = lg - 1
    Protected.l ht_minus_1 = ht - 1
    Protected.l isx, isy
    macro_calul_tread(ht)
    
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        count = 0
        
        ; Accumulateur 16-bits (Mots) mis à zéro
        !pxor xmm4, xmm4
        
        dx = x - cx
        dy = y - cy
        
        For i = 0 To samples - 1
          t = i / (samples - 1.0)
          rotAngle = -angle * 0.5 + angle * t
          
          cosA = Cos(rotAngle)
          sinA = Sin(rotAngle)
          
          rx = dx * cosA - dy * sinA
          ry = dx * sinA + dy * cosA
          
          sx = cx + rx
          sy = cy + ry
          
          isx = sx
          isy = sy
          
          ; Vérification des limites (strictement identique au PB)
          If isx < 0 Or isx >= lg Or isy < 0 Or isy >= ht
            Continue
          EndIf
          
          count + 1
          
          ; --- Lecture Source ---
          !mov eax, [p.v_isy]
          !imul ecx, [p.v_lg]        
          !add eax, [p.v_isx]
          !shl eax , 2
          !add rax, [p.p_source]     
          !movd xmm0, [rax] 
          
          !pxor xmm1, xmm1
          !punpcklbw xmm0, xmm1       ; xmm0 = [0A, 0R, 0G, 0B]
          !paddw xmm4, xmm0           ; Cumul dans xmm4
        Next
        
        If count > 0
          ; --- Préparation du Facteur 32-bits ---
          !mov eax, [p.v_count]
          !shl eax , 2
          !add rax, [p.p_pTable]
          !mov eax, [rax]   ; eax = Facteur (65536 / count)
          !movd xmm1, eax
          !pshuflw xmm1, xmm1, 0
          
          !pmulhw xmm4, xmm1 
          !packuswb xmm4, xmm4
          
          ; --- Écriture Cible ---
          !mov eax, [p.v_y]
          !imul eax , [p.v_lg]
          !add eax, [p.v_x]
          !shl eax , 2
          !add rax, [p.p_cible]
          !movd [rax], xmm4  ; Écrit le pixel ARGB parfait
        EndIf
        
      Next
    Next
    
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
    
  EndWith
EndProcedure

Procedure RotationalBlur_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.pixelarray = \addr[0]
    Protected *cible.pixelarray  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected centerX.f = \option[0] / 100.0  ; Centre X (0-100%)
    Protected centerY.f = \option[1] / 100.0  ; Centre Y (0-100%)
    Protected angle.f = \option[2] * #PI / 180.0  ; Angle en radians
    Protected samples = \option[3]
    
    If samples < 2 : samples = 2 : EndIf
    If samples > 50 : samples = 50 : EndIf
    
    ; Centre en pixels
    Protected cx.f = lg * centerX
    Protected cy.f = ht * centerY
    
    Protected x, y, i
    Protected sumR.f, sumG.f, sumB.f, sumA.f, count
    Protected sx.f, sy.f, rotAngle.f
    Protected index, value
    Protected r, g, b, a
    Protected dx.f, dy.f, cosA.f, sinA.f
    Protected rx.f, ry.f
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : count = 0
        
        ; Position relative au centre
        dx = x - cx
        dy = y - cy
        
        ; Échantillonnage le long de l'arc de rotation
        For i = 0 To samples - 1
          Protected t.f = i / (samples - 1.0)  ; 0.0 à 1.0
          rotAngle = -angle * 0.5 + angle * t  ; De -angle/2 à +angle/2
                                               ; Rotation du vecteur
          cosA = Cos(rotAngle)
          sinA = Sin(rotAngle) 
          rx = dx * cosA - dy * sinA
          ry = dx * sinA + dy * cosA
          ; Position échantillonnée
          sx = cx + rx
          sy = cy + ry
          ; Vérification des limites
          If sx < 0 Or sx >= lg Or sy < 0 Or sy >= ht : Continue : EndIf
          getargb(*source\l[(Int(sy) * lg + Int(sx))] , a , r , g , b)
          sumA + a
          sumR + r
          sumG + g
          sumB + b
          count + 1
        Next
        ; Moyenne
        If count > 0
          a = sumA / count
          r = sumR / count
          g = sumG / count
          b = sumB / count
          clamp_argb(a,r,g,b)
          *cible\l[(Int(y) * lg + Int(x))] = (a << 24) | (r << 16) | (g << 8) | b
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure RotationalBlurEx(*FilterCtx.FilterParams)
  Restore RotationalBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  selet_and_start_programme(RotationalBlur_MT)
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure RotationalBlur(source , cible , mask , cx , cy , angle , echantillons)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = cx
    \option[1] = cy
    \option[2] = angle
    \option[3] = echantillons
  EndWith
  RotationalBlurEx(FilterCtx.FilterParams)
EndProcedure


DataSection
  RotationalBlur_data:
  Data.s "RotationalBlur"
  Data.s "Flou de rotation autour d'un point"
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Centre X (%)"       
  Data.i 0,100,50
  Data.s "Centre Y (%)"   
  Data.i 0,100,50
  Data.s "Angle (°)"        
  Data.i 0,360,30
  Data.s "Échantillons"  
  Data.i 2,50,15
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 204
; Folding = --
; EnableXP
; DPIAware