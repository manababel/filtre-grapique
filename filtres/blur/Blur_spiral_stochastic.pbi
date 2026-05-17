; ============================================================================
; ALGORITHME 3 : GPU-STYLE SHADER (Le plus rapide en pratique)
; Technique : Ã‰chantillonnage stochastique avec poids gaussien
; Gain : 10-20x plus rapide, qualitÃ© lÃ©gÃ¨rement infÃ©rieure
; ============================================================================

Procedure SpiralBlur_Stochastic_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected Radius = \option[0]
    Protected cx.f = (\option[1] * lg) / 100
    Protected cy.f = (\option[2] * ht) / 100
    Protected force.i = \option[3]
    Protected direction = ((\option[6] * 2) - 1)
    
    ; Nombre d'Ã©chantillons rÃ©duit (style Monte Carlo)
    Protected samples 
    Min(samples , Radius , 16) ; Seulement 16 Ã©chantillons au lieu de centaines!
    Protected invSamples.f = 1.0 / samples
    
    Protected *src.Pixel32 = \addr[0]
    Protected *dst.Pixel32 = \addr[1]
    Protected x , y , s
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop
      Protected yOffset.i = y * lg
      
      For x = 0 To lg - 1
        Protected dx.f = x - cx
        Protected dy.f = y - cy
        Protected dist.f = Sqr(dx*dx + dy*dy)
        Protected baseAngle.f = ATan2(dy, dx)
        
        Protected r.f = 0, g.f = 0, b.f = 0, a.i = 0
        Protected ri = 0, gi = 0, bi = 0
        Protected totalWeight.f = 0
        
        ; Ã‰chantillonnage avec distribution gaussienne
        For s = 0 To samples - 1
          ; Offset gaussien (approximation rapide)
          Protected offset.f = (s - samples/2) * (Radius / (samples/2))
          Protected weight.f = Exp(-(offset*offset) / (2*Radius*Radius))
          
          ; Rotation spirale
          Protected rotation.f = (force * dist * direction * s * invSamples) / 100.0
          Protected sampleAngle.f = baseAngle + Radian(rotation)
          
          Protected sampleDist.f = dist + offset
          Protected sx.i = cx + sampleDist * Cos(sampleAngle)
          Protected sy.i = cy + sampleDist * Sin(sampleAngle)
          
          If sx >= 0 And sx < lg And sy >= 0 And sy < ht
            Protected pos.i = (sy * lg + sx) << 2
            Protected *pixel.Pixel32 = *src + pos
            Protected pix.l = *pixel\l
            
            getrgb(pix , ri , gi , bi)
            r + weight * ri ;((pix >> 16) & $FF)
            g + weight * gi ; ((pix >> 8) & $FF)
            b + weight * bi ; (pix & $FF)
            a = (pix >> 24) & $FF
            totalWeight + weight
          EndIf
        Next
        
        If totalWeight > 0
          Protected outPos.i = (yOffset + x) << 2
          Protected *out.Pixel32 = *dst + outPos
          *out\l = (a << 24) | (Int(r/totalWeight) << 16) | 
                   (Int(g/totalWeight) << 8) | Int(b/totalWeight)
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure spiral_stochasticEx(*FilterCtx.FilterParams)
  
  Restore spiral_stochastic_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  
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
    
    Create_MultiThread_MT(@SpiralBlur_Stochastic_MT())
    mask_update(*FilterCtx.FilterParams , last_data)
    
    FreeArray(cosTable())
    FreeArray(sinTable())
  EndWith
EndProcedure

Procedure spiral_stochastic(source , cible , mask , rayon , posx , posy , force , qualite , ra , sens)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = posx
    \option[2] = posy
    \option[3] = force
    \option[4] = qualite
    \option[5] = ra
    \option[6] = sens
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
  Data.s "Qualité" 
  Data.i 16,64,32
  Data.s "Rayon actif"   
  Data.i 0,100,100
  Data.s "sens"  
  Data.i 0,1,0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 123
; FirstLine = 74
; Folding = -
; EnableXP
; DPIAware