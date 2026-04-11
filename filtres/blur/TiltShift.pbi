Procedure TiltShift_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected focusPos.f = *param\option[0] / 100.0    ; Position focus (0-100%)
  Protected focusWidth.f = *param\option[1] / 100.0   ; Largeur zone nette (0-100%)
  Protected blurRadius = *param\option[2]             ; Rayon du flou
  Protected angle.f = *param\option[3] * #PI / 180.0  ; Angle en radians
  
  If blurRadius < 1 : blurRadius = 1 : EndIf
  
  Protected x, y, dx, dy, px, py, index, value
  Protected r, g, b, a
  Protected sumR.f, sumG.f, sumB.f, sumA.f, count
  Protected distance.f, blurAmount.f
  
  ; Précalcul pour rotation
  Protected cosA.f = Cos(angle)
  Protected sinA.f = Sin(angle)
  Protected centerY.f = ht * 0.5
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      ; Calcul de la distance à l'axe de focus
      Protected yRel.f = (y - centerY) / ht
      Protected xRel.f = (x - lg * 0.5) / lg
      
      ; Rotation
      Protected yRot.f = yRel * cosA - xRel * sinA
      
      ; Distance normalisée à la ligne de focus
      distance = Abs(yRot - (focusPos - 0.5))
      
      ; Calcul du facteur de flou
      If distance < focusWidth * 0.5
        blurAmount = 0.0  ; Zone nette
      Else
        blurAmount = (distance - focusWidth * 0.5) / (0.5 - focusWidth * 0.5)
        If blurAmount > 1.0 : blurAmount = 1.0 : EndIf
      EndIf
      
      ; Rayon de flou effectif
      Protected effectiveRadius = Int(blurRadius * blurAmount)
      
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

Procedure TiltShift(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Artistic
    *param\name = "TiltShift"
    *param\remarque = "Effet miniature / Tilt-Shift"
    *param\info[0] = "Position focus (%)"
    *param\info_data(0, 0) = 0 : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 50
    *param\info[1] = "Largeur focus (%)"
    *param\info_data(1, 0) = 0 : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 20
    *param\info[2] = "Rayon flou"
    *param\info_data(2, 0) = 1 : *param\info_data(2, 1) = 20 : *param\info_data(2, 2) = 5
    *param\info[3] = "Angle (°)"
    *param\info_data(3, 0) = 0 : *param\info_data(3, 1) = 360 : *param\info_data(3, 2) = 0
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 0, 100)
  Clamp(*param\option[1], 0, 100)
  Clamp(*param\option[2], 1, 20)
  Clamp(*param\option[3], 0, 360)
  
  filter_start(@TiltShift_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 70
; FirstLine = 45
; Folding = -
; EnableXP
; DPIAware