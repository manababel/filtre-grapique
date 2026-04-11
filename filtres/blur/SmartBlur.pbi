Procedure SmartBlur_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected radius = *param\option[0]
  Protected threshold = *param\option[1]  ; Seuil de différence
  
  If radius < 1 : radius = 1 : EndIf
  If threshold < 0 : threshold = 0 : EndIf
  
  Protected x, y, dx, dy, px, py, index, value
  Protected r, g, b, a
  Protected centerR, centerG, centerB, centerA
  Protected sumR, sumG, sumB, sumA, count
  Protected diffR, diffG, diffB, diff
  
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
      
      sumR = 0 : sumG = 0 : sumB = 0 : sumA = 0 : count = 0
      
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
          
          ; Calcul de la différence avec le pixel central
          diffR = Abs(r - centerR)
          diffG = Abs(g - centerG)
          diffB = Abs(b - centerB)
          diff = (diffR + diffG + diffB) / 3
          
          ; N'inclure que si la différence est sous le seuil
          If diff <= threshold
            sumA + a
            sumR + r
            sumG + g
            sumB + b
            count + 1
          EndIf
        Next
      Next
      
      ; Calculer la moyenne ou garder l'original
      If count > 0
        a = sumA / count
        r = sumR / count
        g = sumG / count
        b = sumB / count
      Else
        a = centerA
        r = centerR
        g = centerG
        b = centerB
      EndIf
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure SmartBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_EdgeAware
    *param\name = "SmartBlur"
    *param\remarque = "Flou intelligent préservant les contours"
    *param\info[0] = "Rayon"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 20 : *param\info_data(0, 2) = 3
    *param\info[1] = "Seuil"
    *param\info_data(1, 0) = 0 : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 30
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 20)
  Clamp(*param\option[1], 0, 100)
  
  filter_start(@SmartBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 80
; FirstLine = 28
; Folding = -
; EnableXP
; DPIAware