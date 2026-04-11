Macro ErodeDilate_sp1()
  value = PeekL(*param\addr[0] + index)
  
  ; Extraction rapide ARGB
  a_temp = (value >> 24) & $FF
  r_temp = (value >> 16) & $FF
  g_temp = (value >> 8) & $FF
  b_temp = value & $FF
  
  ; Mettre à jour min/max pour chaque canal
  If a_temp < minA : minA = a_temp : EndIf
  If a_temp > maxA : maxA = a_temp : EndIf
  If r_temp < minR : minR = r_temp : EndIf
  If r_temp > maxR : maxR = r_temp : EndIf
  If g_temp < minG : minG = g_temp : EndIf
  If g_temp > maxG : maxG = g_temp : EndIf
  If b_temp < minB : minB = b_temp : EndIf
  If b_temp > maxB : maxB = b_temp : EndIf
EndMacro

Procedure MorphOpenCloseBlur_sp(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected kernelSize = *param\option[0]
  
  If kernelSize < 1 : kernelSize = 1 : EndIf
  
  Protected radius = kernelSize
  Protected x, y, dx, dy, px, py, index
  Protected value, r.l, g.l, b.l, a.l
  Protected a_temp, r_temp, g_temp, b_temp
  
  Protected minA, maxA, minR, maxR, minG, maxG, minB, maxB
  Protected openA, openR, openG, openB
  Protected closeA, closeR, closeG, closeB
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      
      ; ==== Phase 1 : Érosion (pour Opening) ====
      minA = 255 : minR = 255 : minG = 255 : minB = 255
      maxA = 0   : maxR = 0   : maxG = 0   : maxB = 0
      
      For dy = -radius To radius
        py = y + dy
        If py < 0 Or py >= ht : Continue : EndIf
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          
          index = (py * lg + px) << 2
          ErodeDilate_sp1()
        Next
      Next
      
      ; Résultat de l'érosion = minimum
      openA = minA
      openR = minR
      openG = minG
      openB = minB
      
      ; ==== Phase 2 : Dilatation (pour Closing) ====
      minA = 255 : minR = 255 : minG = 255 : minB = 255
      maxA = 0   : maxR = 0   : maxG = 0   : maxB = 0
      
      For dy = -radius To radius
        py = y + dy
        If py < 0 Or py >= ht : Continue : EndIf
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          
          index = (py * lg + px) << 2
          ErodeDilate_sp1()
        Next
      Next
      
      ; Résultat de la dilatation = maximum
      closeA = maxA
      closeR = maxR
      closeG = maxG
      closeB = maxB
      
      ; ==== Résultat final : moyenne Opening + Closing ====
      ; Cette moyenne préserve la luminosité
      a = (openA + closeA) >> 1
      r = (openR + closeR) >> 1
      g = (openG + closeG) >> 1
      b = (openB + closeB) >> 1
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure MorphOpenCloseBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Morphological
    *param\name = "MorphOpenCloseBlur"
    *param\remarque = "Flou morphologique par moyenne Opening + Closing"
    *param\info[0] = "Rayon"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 20 : *param\info_data(0, 2) = 3
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 20)
  
  filter_start(@MorphOpenCloseBlur_sp(), 1)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 113
; FirstLine = 44
; Folding = -
; EnableXP
; DPIAware