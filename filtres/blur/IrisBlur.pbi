Procedure IrisBlur_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected centerX.f = *param\option[0] / 100.0  ; Centre X (0-100%)
  Protected centerY.f = *param\option[1] / 100.0  ; Centre Y (0-100%)
  Protected innerRadius.f = *param\option[2]       ; Rayon intérieur (net)
  Protected outerRadius.f = *param\option[3]       ; Rayon extérieur (flou)
  Protected maxBlurRadius = *param\option[4]       ; Rayon max du flou
  
  If innerRadius < 0 : innerRadius = 0 : EndIf
  If outerRadius <= innerRadius : outerRadius = innerRadius + 10 : EndIf
  If maxBlurRadius < 1 : maxBlurRadius = 1 : EndIf
  
  ; Centre en pixels
  Protected cx.f = lg * centerX
  Protected cy.f = ht * centerY
  
  Protected x, y, dx, dy, px, py, index, value
  Protected r, g, b, a
  Protected sumR.f, sumG.f, sumB.f, sumA.f, count
  Protected distance.f, blurAmount.f, effectiveRadius
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      ; Distance euclidienne au centre
      Protected distX.f = x - cx
      Protected distY.f = y - cy
      distance = Sqr(distX * distX + distY * distY)
      
      ; Calcul du facteur de flou
      If distance <= innerRadius
        blurAmount = 0.0  ; Zone nette
      ElseIf distance >= outerRadius
        blurAmount = 1.0  ; Flou maximum
      Else
        ; Transition linéaire
        blurAmount = (distance - innerRadius) / (outerRadius - innerRadius)
      EndIf
      
      ; Rayon de flou effectif
      effectiveRadius = Int(maxBlurRadius * blurAmount)
      
      If effectiveRadius <= 0
        ; Pas de flou, copie directe
        index = (y * lg + x) << 2
        PokeL(*param\addr[1] + index, PeekL(*param\addr[0] + index))
      Else
        ; Application du flou
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : count = 0
        
        For dy = -effectiveRadius To effectiveRadius
          py = y + dy
          If py < 0 Or py >= ht : Continue : EndIf
          
          For dx = -effectiveRadius To effectiveRadius
            px = x + dx
            If px < 0 Or px >= lg : Continue : EndIf
            
            ; Filtre circulaire
            If dx * dx + dy * dy > effectiveRadius * effectiveRadius : Continue : EndIf
            
            index = (py * lg + px) << 2
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
        Next
        
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
        
        PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      EndIf
    Next
  Next
EndProcedure

Procedure IrisBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Artistic
    *param\name = "IrisBlur"
    *param\remarque = "Flou circulaire graduel (effet iris)"
    *param\info[0] = "Centre X (%)"
    *param\info_data(0, 0) = 0 : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 50
    *param\info[1] = "Centre Y (%)"
    *param\info_data(1, 0) = 0 : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 50
    *param\info[2] = "Rayon net"
    *param\info_data(2, 0) = 0 : *param\info_data(2, 1) = 500 : *param\info_data(2, 2) = 100
    *param\info[3] = "Rayon flou"
    *param\info_data(3, 0) = 0 : *param\info_data(3, 1) = 1000 : *param\info_data(3, 2) = 300
    *param\info[4] = "Intensité flou"
    *param\info_data(4, 0) = 1 : *param\info_data(4, 1) = 30 : *param\info_data(4, 2) = 10
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 0, 100)
  Clamp(*param\option[1], 0, 100)
  Clamp(*param\option[2], 0, 500)
  Clamp(*param\option[3], 0, 1000)
  Clamp(*param\option[4], 1, 30)
  
  filter_start(@IrisBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 72
; FirstLine = 35
; Folding = -
; EnableXP
; DPIAware