Procedure RotationalBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
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

Procedure RotationalBlurEx(*FilterCtx.FilterParams)
  Restore RotationalBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@RotationalBlur_sp())
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
; CursorPosition = 2
; Folding = -
; EnableXP
; DPIAware