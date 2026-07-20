; ============================================================================
; ALGORITHME 3 : GPU-STYLE SHADER (Le plus rapide en pratique)
; Technique : Ã‰chantillonnage stochastique avec poids gaussien
; Gain : 10-20x plus rapide, qualitÃ© lÃ©gÃ¨rement infÃ©rieure
; ============================================================================


Procedure SpiralBlur_Stochastic_MT_SSE4(*FilterCtx.FilterParams)
EndProcedure
Procedure SpiralBlur_Stochastic_MT_AVX(*FilterCtx.FilterParams)
EndProcedure
Procedure SpiralBlur_Stochastic_MT_AVX512(*FilterCtx.FilterParams)
EndProcedure

Procedure SpiralBlur_Stochastic_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.PixelArray = \addr[0]
    Protected *cible.PixelArray  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected Radius = \option[0]
    Protected cx.f = (\option[1] * lg) / 100
    Protected cy.f = (\option[2] * ht) / 100
    Protected force.i = \option[3]
    Protected direction = ((\option[5] * 2) - 1)
    Protected MaxDist.f = (\option[4] * lg) / 100
    
    Protected samples 
    Min(samples , Radius , 16)
    Protected invSamples.f = 1.0 / samples
   
    Protected x, y, s
    
    ; Alignement de tableaux et structures SSE requis (16 octets)
    Protected.l ai, ri, gi, bi
    Protected.i lg_minus_1 = lg - 1
    Protected.i ht_minus_1 = ht - 1
    
    Protected Dim tab_acc.f(3)
    Protected acc = @tab_acc()
    
    macro_calul_tread(ht)
    
    ; Masque SSE constant pour la conversion de bytes vers longs/floats
    ; On va utiliser l'assembleur en ligne pour manipuler les registres XMM
    
    For y = thread_start To thread_stop - 1
      Protected yOffset.i = y * lg
      
      For x = 0 To lg - 1
        Protected dx.f = x - cx
        Protected dy.f = y - cy
        Protected dist.f = Sqr(dx * dx + dy * dy)
        
        If dist > MaxDist
          *cible\l[yOffset + x] = *source\l[yOffset + x]
          Continue 
        EndIf
        
        Protected baseAngle.f = ATan2(dx, dy)
        
        ; Variables d'accumulation SSE alignées en mémoire
        ; xmm0 accumulera les canaux [A, R, G, B] en Float
        ; xmm1 servira à charger le poids
        Protected.f totalWeight = 0.0
        
        !movups xmm0, [p.v_totalWeight] ; Initialise xmm0 à 0 (via totalWeight qui est à 0.0)
        !shufps xmm0, xmm0, 0           ; Mettre à zéro tout le registre [0.0, 0.0, 0.0, 0.0]
        tab_acc(0) = 0 : tab_acc(1) = 0: tab_acc(2) = 0: tab_acc(3) = 0
        For s = 0 To samples - 1
          Protected offset.f = (s - samples/2) * (Radius / (samples/2))
          Protected weight.f = Exp(-(offset*offset) / (2*Radius*Radius))
          
          Protected rotation.f = (force * dist * direction * s * invSamples) / 100.0
          Protected sampleAngle.f = baseAngle + Radian(rotation)
          Protected sampleDist.f = dist + offset
          
          Protected sx.i = cx + sampleDist * Cos(sampleAngle)
          Protected sy.i = cy + sampleDist * Sin(sampleAngle)
          
          If sx >= 0 And sx < lg_minus_1 And sy >= 0 And sy < ht_minus_1
            Protected pos.i = (sy * lg + sx)
            Protected pixel.l = *source\l[pos]
            
            ; --- DÉBUT CODE SSE2 ---
            ; Étape 1 : Charger le pixel 32 bits ARGB dans le registre xmm2
            !movd xmm2, [p.v_pixel]         ; xmm2 = [0, 0, 0, ARGB] (000000000000000000000000AARRGGBB)
            
            ; Étape 2 : Unpack des octets (8-bit) vers mots (16-bit) puis vers double mots (32-bit int)
            !pxor xmm3, xmm3                ; xmm3 = 0
            !punpcklbw xmm2, xmm3           ; Déballe bytes en mots -> xmm2 = [0A, 0R, 0G, 0B] (16-bit)
            !punpcklwd xmm2, xmm3           ; Déballe mots en dwords -> xmm2 = [A, R, G, B] en Int 32-bit
            
            ; Étape 3 : Conversion Int 32-bit vers Float 32-bit
            !cvtdq2ps xmm2, xmm2            ; xmm2 = [(float)A, (float)R, (float)G, (float)B]
            
            ; Étape 4 : Multiplier par le poids (weight) vectoriellement
            !movss xmm1, [p.v_weight]       ; xmm1 = [0, 0, 0, weight]
            !shufps xmm1, xmm1, 0           ; xmm1 = [weight, weight, weight, weight]
            !mulps xmm2, xmm1               ; xmm2 = [A*w, R*w, G*w, B*w]
            
            ; Étape 5 : Accumuler dans xmm0
            !mov rax,[p.v_acc]
            !movups xmm0 , [rax]
            !addps xmm0, xmm2               ; xmm0 += xmm2
            !mov rax,[p.v_acc]
            !movups [rax] , xmm0
            totalWeight + weight
          EndIf
        Next
        
        If totalWeight > 0.0
          Protected.f invTotalWeight = 1.0 / totalWeight
          !mov rax,[p.v_acc]
          !movups xmm0 , [rax]
          ; Étape 6 : Division finale par le totalWeight
          !movss xmm1, [p.v_invTotalWeight] ; xmm1 = [0, 0, 0, invTotalWeight]
          !shufps xmm1, xmm1, 0             ; xmm1 = [invTotalWeight, ..., invTotalWeight]
          !mulps xmm0, xmm1                 ; xmm0 = [A/tw, R/tw, G/tw, B/tw] en Float
          
          ; Étape 7 : Reconvertir les Floats en Entiers 32-bit avec troncature (ou arrondi)
          !cvttps2dq xmm0, xmm0             ; xmm0 = [(int)A, (int)R, (int)G, (int)B] 32-bit signés
          
          ; Étape 8 : Re-paqueter les 4 Ints 32-bit vers des octets 8-bit (Saturated)
          !packssdw xmm0, xmm0              ; 32-bit vers 16-bit
          !packuswb xmm0, xmm0              ; 16-bit vers 8-bit (unsigned avec saturation)
          
          ; Étape 9 : Extraire le pixel recomposé ARGB 32-bit et l'injecter dans la cible
          Protected outPixel.l
          !movd [p.v_outPixel], xmm0
          
          ; On préserve le canal Alpha d'origine si nécessaire, ou on applique direct
          *cible\l[yOffset + x] = outPixel
        Else
          *cible\l[yOffset + x] = *source\l[yOffset + x]
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure SpiralBlur_Stochastic_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.pixelarray = \addr[0]
    Protected *cible.Pixelarray  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected Radius = \option[0]
    Protected cx.f = (\option[1] * lg) / 100
    Protected cy.f = (\option[2] * ht) / 100
    Protected force.i = \option[3]
    Protected direction = ((\option[5] * 2) - 1)
    
    Protected.f dx , dy , dist
    Protected.f r , g, b
    Protected.l ai , ri , gi , bi
    Protected.f totalWeight
    Protected.f baseAngle
    Protected.f offset , weight , rotation , sampleAngle , sampleDist
    Protected.i sx , sy , pos , yOffset
    Protected MaxDist.f = (\option[4] * lg) / 100
    
    ; Nombre d'échantillons réduit (style Monte Carlo)
    Protected samples 
    Min(samples , Radius , 16)
    Protected invSamples.f = 1.0 / samples
    Protected x , y , s
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      yOffset.i = y * lg
      For x = 0 To lg - 1
        dx.f = x - cx
        dy.f = y - cy
        dist.f = Sqr(dx * dx + dy * dy)
        If dist > MaxDist
          *cible\l[yOffset + x] = *source\l[yOffset + x]
          Continue ; Passe directement au pixel 'x' suivant
        EndIf
        baseAngle.f = ATan2(dx, dy)
        r = 0 :g = 0: b = 0
        ai = 0 : ri = 0: gi = 0: bi = 0
        totalWeight.f = 0
        ; Échantillonnage avec distribution gaussienne (Uniquement à l'intérieur de MaxDist)
        For s = 0 To samples - 1
          offset.f = (s - samples/2) * (Radius / (samples/2))
          weight.f = Exp(-(offset*offset) / (2*Radius*Radius))
          rotation.f = (force * dist * direction * s * invSamples) / 100.0
          sampleAngle.f = baseAngle + Radian(rotation)
          sampleDist.f = dist + offset
          sx.i = cx + sampleDist * Cos(sampleAngle)
          sy.i = cy + sampleDist * Sin(sampleAngle)
          If sx >= 0 And sx < (lg - 1) And sy >= 0 And sy < (ht - 1)
            pos.i = (sy * lg + sx)
            getargb( *source\l[pos] , ai , ri , gi , bi)
            r + weight * ri 
            g + weight * gi 
            b + weight * bi 
            totalWeight + weight
          EndIf
        Next
        If totalWeight > 0
          *cible\l[yOffset + x] = (ai << 24) | (Int(r/totalWeight) << 16) |  (Int(g/totalWeight) << 8) | Int(b/totalWeight)
        Else
          *cible\l[yOffset + x] = *source\l[yOffset + x]
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure spiral_stochasticEx(*FilterCtx.FilterParams)
  
  Restore spiral_stochastic_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  *FilterCtx\asm_dispo = 1
  With *FilterCtx
    Protected i, angle.f
    Protected quality = \option[4]
    Protected inv_quality.f = 1.0 / quality
    Protected angleCount = 360 * quality
    ; Allocation optimisée avec mémoire alignée
    Dim cosTable.f(angleCount)
    Dim sinTable.f(angleCount) 
    ; Précalcul optimisé des tables trigonométriques
    For i = 0 To angleCount - 1
      angle = Radian(i * inv_quality)
      cosTable(i) = Cos(angle)
      sinTable(i) = Sin(angle)
    Next
    \addr[2] = @cosTable()
    \addr[3] = @sinTable()
    
    ;Create_MultiThread_MT(@SpiralBlur_Stochastic_MT())
    selet_and_start_programme(SpiralBlur_Stochastic_MT)
    mask_update(*FilterCtx.FilterParams , last_data)
    
    FreeArray(cosTable())
    FreeArray(sinTable())
  EndWith
EndProcedure

Procedure spiral_stochastic(source , cible , mask , rayon , posx , posy , force , ra , sens)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = posx
    \option[2] = posy
    \option[3] = force
    \option[4] = ra
    \option[5] = sens
  EndWith
  SpiralBlur_IIREx(FilterCtx.FilterParams)
EndProcedure

DataSection
  spiral_stochastic_data:
  Data.s "spiral_stochastic"
  Data.s "appliquer un filtre de flou en spirale"
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Rayon du filtre"       
  Data.i 1,99,50
  Data.s "Pos X"   
  Data.i 0,100,50
  Data.s "Pos Y"        
  Data.i 0,100,50
  Data.s "Force de rotation"  
  Data.i 0,100,10
  Data.s "Rayon actif"   
  Data.i 0,100,100
  Data.s "sens"  
  Data.i 0,1,0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 68
; FirstLine = 34
; Folding = --
; EnableXP
; DPIAware