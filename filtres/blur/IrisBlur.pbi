Procedure IrisBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected centerX.f = \option[0] / 100.0  ; Centre X (0-100%)
    Protected centerY.f = \option[1] / 100.0  ; Centre Y (0-100%)
    Protected innerRadius.f = \option[2]       ; Rayon intérieur (net)
    Protected outerRadius.f = \option[3]       ; Rayon extérieur (flou)
    Protected maxBlurRadius = \option[4]       ; Rayon max du flou
    
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
              
              ; Filtre circulaire
              If dx * dx + dy * dy > effectiveRadius * effectiveRadius : Continue : EndIf
              
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

Procedure IrisBlurEx(*FilterCtx.FilterParams)
  Restore IrisBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Application des Clamps d'origine
    If \option[0] < 0 : \option[0] = 0 : ElseIf \option[0] > 100 : \option[0] = 100 : EndIf
    If \option[1] < 0 : \option[1] = 0 : ElseIf \option[1] > 100 : \option[1] = 100 : EndIf
    If \option[2] < 0 : \option[2] = 0 : ElseIf \option[2] > 500 : \option[2] = 500 : EndIf
    If \option[3] < 0 : \option[3] = 0 : ElseIf \option[3] > 1000 : \option[3] = 1000 : EndIf
    If \option[4] < 1 : \option[4] = 1 : ElseIf \option[4] > 30 : \option[4] = 30 : EndIf
    
    Create_MultiThread_MT(@IrisBlur_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure IrisBlur(source, cible, mask, centreX, centreY, rayon_net, rayon_flou, intensite)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = centreX
    \option[1] = centreY
    \option[2] = rayon_net
    \option[3] = rayon_flou
    \option[4] = intensite
  EndWith
  IrisBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  IrisBlur_data:
  Data.s "IrisBlur"
  Data.s "Flou circulaire graduel (effet iris)"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Centre X (%)"
  Data.i 0, 100, 50
  Data.s "Centre Y (%)"
  Data.i 0, 100, 50
  Data.s "Rayon net"
  Data.i 0, 500, 100
  Data.s "Rayon flou"
  Data.i 0, 1000, 300
  Data.s "Intensité flou"
  Data.i 1, 30, 10
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 118
; FirstLine = 99
; Folding = -
; EnableXP
; DPIAware