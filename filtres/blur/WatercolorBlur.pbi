Procedure WatercolorBlur_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected radius = *param\option[0]
  Protected sharpness = *param\option[1]  ; Netteté des bords (0-100)
  
  If radius < 1 : radius = 1 : EndIf
  
  Protected x, y, dx, dy, px, py, index, value
  Protected r, g, b, a
  Protected centerR, centerG, centerB, centerA
  Protected sumR.f, sumG.f, sumB.f, sumA.f, sumWeight.f
  Protected diff, weight.f
  
  ; Conversion du paramètre sharpness en facteur de poids
  Protected sharpFactor.f = 1.0 + (sharpness / 10.0)
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      ; Pixel central
      index = (y * lg + x) << 2
      value = PeekL(*param\addr[0] + index)
      centerA = (value >> 24) & $FF
      centerR = (value >> 16) & $FF
      centerG = (value >> 8) & $FF
      centerB = value & $FF
      
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : sumWeight = 0.0
      
      ; Parcourir le voisinage
      For dy = -radius To radius
        py = y + dy
        If py < 0 Or py >= ht : Continue : EndIf
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          
          index = (py * lg + px) << 2
          value = PeekL(*param\addr[0] + index)
          
          a = (value >> 24) & $FF
          r = (value >> 16) & $FF
          g = (value >> 8) & $FF
          b = value & $FF
          
          ; Calcul de la similarité de couleur
          diff = Abs(r - centerR) + Abs(g - centerG) + Abs(b - centerB)
          
          ; Poids basé sur la similarité (effet aquarelle)
          ; Les couleurs similaires se mélangent plus
          weight = Exp(-diff / (sharpFactor * 50.0))
          
          sumA + a * weight
          sumR + r * weight
          sumG + g * weight
          sumB + b * weight
          sumWeight + weight
        Next
      Next
      
      ; Normalisation
      If sumWeight > 0.0
        a = sumA / sumWeight
        r = sumR / sumWeight
        g = sumG / sumWeight
        b = sumB / sumWeight
      Else
        a = centerA
        r = centerR
        g = centerG
        b = centerB
      EndIf
      
      Clamp(a, 0, 255)
      Clamp(r, 0, 255)
      Clamp(g, 0, 255)
      Clamp(b, 0, 255)
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure WatercolorBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Artistic
    *param\name = "WatercolorBlur"
    *param\remarque = "Effet aquarelle avec diffusion des couleurs"
    *param\info[0] = "Rayon"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 15 : *param\info_data(0, 2) = 5
    *param\info[1] = "Netteté"
    *param\info_data(1, 0) = 0 : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 30
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 15)
  Clamp(*param\option[1], 0, 100)
  
  filter_start(@WatercolorBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 85
; FirstLine = 33
; Folding = -
; EnableXP
; DPIAware