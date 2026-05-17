Procedure TiltShift_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected focusPos.f = \option[0] / 100.0    ; Position focus (0-100%)
    Protected focusWidth.f = \option[1] / 100.0   ; Largeur zone nette (0-100%)
    Protected blurRadius = \option[2]               ; Rayon du flou
    Protected angle.f = \option[3] * #PI / 180.0  ; Angle en radians
    
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
          PokeL(\addr[1] + index, PeekL(\addr[0] + index))
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
          Next
          
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
          
          PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure TiltShiftEx(*FilterCtx.FilterParams)
  Restore TiltShift_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Application des Clamps d'origine
    If \option[0] < 0 : \option[0] = 0 : ElseIf \option[0] > 100 : \option[0] = 100 : EndIf
    If \option[1] < 0 : \option[1] = 0 : ElseIf \option[1] > 100 : \option[1] = 100 : EndIf
    If \option[2] < 1 : \option[2] = 1 : ElseIf \option[2] > 20 : \option[2] = 20 : EndIf
    If \option[3] < 0 : \option[3] = 0 : ElseIf \option[3] > 360 : \option[3] = 360 : EndIf
    
    Create_MultiThread_MT(@TiltShift_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure TiltShift(source, cible, mask, pos_focus, largeur_focus, rayon, angle)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = pos_focus
    \option[1] = largeur_focus
    \option[2] = rayon
    \option[3] = angle
  EndWith
  TiltShiftEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  TiltShift_data:
  Data.s "TiltShift"
  Data.s "Effet miniature / Tilt-Shift"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Position focus (%)"
  Data.i 0, 100, 50
  Data.s "Largeur focus (%)"
  Data.i 0, 100, 20
  Data.s "Rayon flou"
  Data.i 1, 20, 5
  Data.s "Angle (°)"
  Data.i 0, 360, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 115
; FirstLine = 93
; Folding = -
; EnableXP
; DPIAware