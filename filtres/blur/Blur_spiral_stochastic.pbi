; ============================================================================
; ALGORITHME 3 : GPU-STYLE SHADER (Le plus rapide en pratique)
; Technique : Ã‰chantillonnage stochastique avec poids gaussien
; Gain : 10-20x plus rapide, qualitÃ© lÃ©gÃ¨rement infÃ©rieure
; ============================================================================

Procedure SpiralBlur_Stochastic_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected Radius = *param\option[0]
  Protected cx.f = (*param\option[1] * lg) / 100
  Protected cy.f = (*param\option[2] * ht) / 100
  Protected force.i = *param\option[3]
  Protected direction = ((*param\option[6] * 2) - 1)
  
  ; Nombre d'Ã©chantillons rÃ©duit (style Monte Carlo)
  Protected samples 
  Min(samples , Radius , 16) ; Seulement 16 Ã©chantillons au lieu de centaines!
  Protected invSamples.f = 1.0 / samples
  
  Protected *src.Pixel32 = *param\addr[0]
  Protected *dst.Pixel32 = *param\addr[1]
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
EndProcedure

Procedure spiral_stochastic(*param.parametre)
  
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Directional
    *param\name = "spiral_stochastic"
    *param\remarque = "appliquer un filtre de flou en spirale (optimisé)"
    *param\info[0] = "Rayon du filtre"          
    *param\info[1] = "Pos X"           
    *param\info[2] = "Pos Y"          
    *param\info[3] = "Force de rotation"   
    *param\info[4] = "Qualité" 
    *param\info[5] = "Rayon actif"   
    *param\info[6] = "sens"   
    *param\info[7] = "Masque binaire"    
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 99 : *param\info_data(0,2) = 50
    *param\info_data(1,0) = 0 : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 50
    *param\info_data(2,0) = 0 : *param\info_data(2,1) = 100 : *param\info_data(2,2) = 50
    *param\info_data(3,0) = 0 : *param\info_data(3,1) = 100 : *param\info_data(3,2) = 10
    *param\info_data(4,0) = 16 : *param\info_data(4,1) = 64 : *param\info_data(4,2) = 32
    *param\info_data(5,0) = 0 : *param\info_data(5,1) = 100 : *param\info_data(5,2) = 100
    *param\info_data(6,0) = 0 : *param\info_data(6,1) = 1 : *param\info_data(6,2) = 0
    *param\info_data(7,0) = 0 : *param\info_data(7,1) = 2 : *param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  
  Filter_BufferPrepare(*param.parametre)
  
  Protected i, angle.f
  Protected quality = *param\option[4]
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
  
  *param\addr[2] = @cosTable()
  *param\addr[3] = @sinTable()
  
  MultiThread_MT(@SpiralBlur_IIR_MT())
  
  macro_Filter_BufferFinalize(7)
  
  FreeArray(cosTable())
  FreeArray(sinTable())
  
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 82
; FirstLine = 62
; Folding = -
; EnableXP
; DPIAware