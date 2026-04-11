Macro DilationBlur_sp1()
  value = PeekL(*param\addr[0] + index)
  a_temp = (value >> 24) & $FF
  r_temp = (value >> 16) & $FF
  g_temp = (value >> 8) & $FF
  b_temp = value & $FF
  If a_temp > maxA : maxA = a_temp : EndIf
  If r_temp > maxR : maxR = r_temp : EndIf
  If g_temp > maxG : maxG = g_temp : EndIf
  If b_temp > maxB : maxB = b_temp : EndIf
EndMacro

Procedure DilationBlur_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected radius = *param\option[0]
  If radius < 1 : radius = 1 : EndIf
  
  Protected x, y, dx, dy, px, py, index, value
  Protected r.l, g.l, b.l, a.l
  Protected a_temp, r_temp, g_temp, b_temp
  Protected maxA, maxR, maxG, maxB
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      maxA = 0 : maxR = 0 : maxG = 0 : maxB = 0
      
      For dy = -radius To radius
        py = y + dy
        If py < 0 Or py >= ht : Continue : EndIf
        For dx = -radius To radius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          index = (py * lg + px) << 2
          DilationBlur_sp1()
        Next
      Next
      
      a = maxA : r = maxR : g = maxG : b = maxB
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure DilationBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Morphological
    *param\name = "DilationBlur"
    *param\remarque = "Dilatation morphologique (éclaircit l'image)"
    *param\info[0] = "Rayon"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 20 : *param\info_data(0, 2) = 3
    ProcedureReturn
  EndIf
  Clamp(*param\option[0], 1, 20)
  filter_start(@DilationBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 45
; Folding = -
; EnableXP
; DPIAware