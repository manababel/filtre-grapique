Macro CatEyeBlur_sp1(dx, dy)
  px = x + dx
  py = y + dy
  
  If px < 0
    px = 0
  ElseIf px > lg_minus_1
    px = lg_minus_1
  EndIf
  
  If py < 0
    py = 0
  ElseIf py > ht_minus_1
    py = ht_minus_1
  EndIf
  
  index = (py * lg + px) << 2
  value = PeekL(*param\addr[0] + index)
  getargb(value, a, r, g, b)
  sumA + a
  sumR + r
  sumG + g
  sumB + b
  count + 1
EndMacro


Procedure CatEyeBokehBlur_sp(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]
  Protected elong = *param\option[1]  ; facteur d'allongement
  
  If radius < 1 : radius = 1 : EndIf
  If elong < 1 : elong = 1 : EndIf
  
  Protected x, y, dx, dy
  Protected px, py
  Protected value, r, g, b, a
  Protected sumA, sumR, sumG, sumB, count
  Protected nx.d, ny.d, dist.d
  Protected index
  Protected lg_minus_1 = lg - 1
  Protected ht_minus_1 = ht - 1
  Protected radiusSq = radius * radius
  Protected elongSq = elong * elong
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0 : count = 0
      
      ; Parcourir un voisinage elliptique pour simuler l'effet Cat-Eye
      For dy = -radius To radius
        ny = dy
        
        For dx = -radius To radius
          ; Transformation elliptique : allongement horizontal
          nx = dx * elong
          
          ; Test de distance elliptique optimisé
          dist = nx * nx + ny * ny
          
          If dist <= radiusSq * elongSq
            CatEyeBlur_sp1(Round(nx, #PB_Round_Nearest), Round(ny, #PB_Round_Nearest))
          EndIf
        Next
      Next
      
      ; Moyenne des pixels échantillonnés
      If count > 0
        a = sumA / count
        r = sumR / count
        g = sumG / count
        b = sumB / count
      Else
        ; Copie du pixel source si aucun échantillon
        index = (y * lg + x) << 2
        value = PeekL(*param\addr[0] + index)
        a = (value >> 24) & 255
        r = (value >> 16) & 255
        g = (value >> 8) & 255
        b = value & 255
      EndIf
      
      ; Clamping pour sécurité
      If a < 0 : a = 0 : ElseIf a > 255 : a = 255 : EndIf
      If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
      
      PokeL(*param\addr[1] + (y * lg + x) * 4, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure


Procedure CatEyeBokehBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Optical
    *param\name = "Cat Eye Bokeh Blur"
    *param\remarque = "Flou bokeh elliptique simulant un œil de chat (effet d'objectif anamorphique)"
    *param\info[0] = "Rayon"
    *param\info[1] = "Allongement"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 1  : *param\info_data(0, 1) = 50 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 1  : *param\info_data(1, 1) = 5  : *param\info_data(1, 2) = 2
    *param\info_data(2, 0) = 0  : *param\info_data(2, 1) = 2  : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Validation des paramètres
  If *param\option[0] < 1 : *param\option[0] = 1 : EndIf
  If *param\option[0] > 50 : *param\option[0] = 50 : EndIf
  If *param\option[1] < 1 : *param\option[1] = 1 : EndIf
  If *param\option[1] > 5 : *param\option[1] = 5 : EndIf
  
  Filter_BufferPrepare(*param)
  MultiThread_MT(@CatEyeBokehBlur_sp())
  macro_Filter_BufferFinalize(2)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 122
; FirstLine = 53
; Folding = -
; EnableXP
; DPIAware