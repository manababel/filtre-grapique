Procedure TwistBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    ; Mise à jour des noms de variables pour correspondre à la nouvelle structure
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected centerX.f = \option[0] / 100.0  ; Centre X (0-100%)
    Protected centerY.f = \option[1] / 100.0  ; Centre Y (0-100%)
    Protected maxAngle.f = \option[2] * #PI / 180.0  ; Angle max en radians
    Protected radius.f = \option[3]             ; Rayon d'effet
    Protected samples = \option[4]
    
    If samples < 2 : samples = 2 : EndIf
    If samples > 50 : samples = 50 : EndIf
    If radius < 1 : radius = 1 : EndIf
    
    ; Centre en pixels
    Protected cx.f = lg * centerX
    Protected cy.f = ht * centerY
    
    Protected x, y, i
    Protected sumR.f, sumG.f, sumB.f, sumA.f, count
    Protected sx.f, sy.f, rotAngle.f
    Protected index, value
    Protected r, g, b, a
    Protected dx.f, dy.f, distance.f, cosA.f, sinA.f
    Protected rx.f, ry.f, angleAmount.f
    
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
          Protected t.f = i / (samples - 1.0)  ; 0.0 à 1.0
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
          If sx < 0 Or sx >= lg Or sy < 0 Or sy >= ht : Continue : EndIf
          
          index = (Int(sy) * lg + Int(sx)) << 2
          value = PeekL(\addr[0] + index)
          
          a = ((value >> 24) & $FF)
          r = ((value >> 16) & $FF)
          g = ((value >> 8) & $FF)
          b = (value & $FF)
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
        Else
          index = (y * lg + x) << 2
          value = PeekL(\addr[0] + index)
          a = (value >> 24) & $FF
          r = (value >> 16) & $FF
          g = (value >> 8) & $FF
          b = value & $FF
        EndIf
        
        Clamp(a, 0, 255)
        Clamp(r, 0, 255)
        Clamp(g, 0, 255)
        Clamp(b, 0, 255)
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure TwistBlurEx(*FilterCtx.FilterParams)
  Restore TwistBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@TwistBlur_sp())
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
; CursorPosition = 113
; FirstLine = 94
; Folding = -
; EnableXP
; DPIAware