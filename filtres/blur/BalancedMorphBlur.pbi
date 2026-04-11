Procedure BalancedMorphBlur_sp(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected kernelSize = *param\option[0]
  
  If kernelSize < 1 : kernelSize = 1 : EndIf
  
  Protected radius = kernelSize
  Protected x, y, dx, dy, px, py, index, value
  Protected a_temp, r_temp, g_temp, b_temp
  Protected minA, minR, minG, minB
  Protected maxA, maxR, maxG, maxB
  Protected r.l, g.l, b.l, a.l
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      ; Initialiser min et max
      minA = 255 : minR = 255 : minG = 255 : minB = 255
      maxA = 0   : maxR = 0   : maxG = 0   : maxB = 0
      
      ; Parcourir le voisinage une seule fois
      For dy = -radius To radius
        py = y + dy
        If py < 0 Or py >= ht : Continue : EndIf
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          
          index = (py * lg + px) << 2
          value = PeekL(*param\addr[0] + index)
          
          a_temp = (value >> 24) & $FF
          r_temp = (value >> 16) & $FF
          g_temp = (value >> 8) & $FF
          b_temp = value & $FF
          
          ; Min pour érosion
          If a_temp < minA : minA = a_temp : EndIf
          If r_temp < minR : minR = r_temp : EndIf
          If g_temp < minG : minG = g_temp : EndIf
          If b_temp < minB : minB = b_temp : EndIf
          
          ; Max pour dilatation
          If a_temp > maxA : maxA = a_temp : EndIf
          If r_temp > maxR : maxR = r_temp : EndIf
          If g_temp > maxG : maxG = g_temp : EndIf
          If b_temp > maxB : maxB = b_temp : EndIf
        Next
      Next
      
      ; Moyenne érosion + dilatation = préserve la luminosité
      a = (minA + maxA) >> 1
      r = (minR + maxR) >> 1
      g = (minG + maxG) >> 1
      b = (minB + maxB) >> 1
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure BalancedMorphBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Morphological
    *param\name = "BalancedMorphBlur"
    *param\remarque = "Flou morphologique équilibré (moyenne érosion+dilatation)"
    *param\info[0] = "Rayon"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 20 : *param\info_data(0, 2) = 3
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 20)
  
  filter_start(@BalancedMorphBlur_sp(), 1)
EndProcedure