Macro ErosionBlur_sp1()
  value = PeekL(*param\addr[0] + index)
  
  ; Extraction rapide ARGB
  a_temp = (value >> 24) & $FF
  r_temp = (value >> 16) & $FF
  g_temp = (value >> 8) & $FF
  b_temp = value & $FF
  
  ; Mettre à jour le minimum pour chaque canal
  If a_temp < minA : minA = a_temp : EndIf
  If r_temp < minR : minR = r_temp : EndIf
  If g_temp < minG : minG = g_temp : EndIf
  If b_temp < minB : minB = b_temp : EndIf
EndMacro

Procedure ErosionBlur_sp(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected kernelSize = *param\option[0]
  
  If kernelSize < 1 : kernelSize = 1 : EndIf
  
  Protected radius = kernelSize
  Protected x, y, dx, dy, px, py, index
  Protected value, r.l, g.l, b.l, a.l
  Protected a_temp, r_temp, g_temp, b_temp
  Protected minA, minR, minG, minB
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      ; Initialiser le minimum à la valeur maximale possible
      minA = 255 : minR = 255 : minG = 255 : minB = 255
      
      ; Parcourir le voisinage
      For dy = -radius To radius
        py = y + dy
        If py < 0 Or py >= ht : Continue : EndIf
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          
          index = (py * lg + px) << 2
          ErosionBlur_sp1()
        Next
      Next
      
      ; Appliquer la valeur minimale comme résultat (érosion)
      a = minA
      r = minR
      g = minG
      b = minB
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure ErosionBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Morphological
    *param\name = "ErosionBlur"
    *param\remarque = "Flou basé sur l'érosion morphologique (assombrit l'image)"
    *param\info[0] = "Rayon"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 20 : *param\info_data(0, 2) = 3
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 20)
  
  filter_start(@ErosionBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 75
; FirstLine = 6
; Folding = -
; EnableXP
; DPIAware