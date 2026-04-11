Procedure TwistBlur_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected centerX.f = *param\option[0] / 100.0  ; Centre X (0-100%)
  Protected centerY.f = *param\option[1] / 100.0  ; Centre Y (0-100%)
  Protected maxAngle.f = *param\option[2] * #PI / 180.0  ; Angle max en radians
  Protected radius.f = *param\option[3]            ; Rayon d'effet
  Protected samples = *param\option[4]
  
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
        value = PeekL(*param\addr[0] + index)
        
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
        value = PeekL(*param\addr[0] + index)
        a = (value >> 24) & $FF
        r = (value >> 16) & $FF
        g = (value >> 8) & $FF
        b = value & $FF
      EndIf
      
      Clamp(a, 0, 255)
      Clamp(r, 0, 255)
      Clamp(g, 0, 255)
      Clamp(b, 0, 255)
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure TwistBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Directional
    *param\name = "TwistBlur"
    *param\remarque = "Flou de torsion (twist) avec rayon d'effet"
    *param\info[0] = "Centre X (%)"
    *param\info_data(0, 0) = 0 : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 50
    *param\info[1] = "Centre Y (%)"
    *param\info_data(1, 0) = 0 : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 50
    *param\info[2] = "Angle max (°)"
    *param\info_data(2, 0) = 0 : *param\info_data(2, 1) = 360 : *param\info_data(2, 2) = 90
    *param\info[3] = "Rayon d'effet"
    *param\info_data(3, 0) = 1 : *param\info_data(3, 1) = 1000 : *param\info_data(3, 2) = 200
    *param\info[4] = "Échantillons"
    *param\info_data(4, 0) = 2 : *param\info_data(4, 1) = 50 : *param\info_data(4, 2) = 15
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 0, 100)
  Clamp(*param\option[1], 0, 100)
  Clamp(*param\option[2], 0, 360)
  Clamp(*param\option[3], 1, 1000)
  Clamp(*param\option[4], 2, 50)
  
  filter_start(@TwistBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 64
; FirstLine = 45
; Folding = -
; EnableXP
; DPIAware