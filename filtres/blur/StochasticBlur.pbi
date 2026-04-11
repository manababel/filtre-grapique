Macro StochasticBlur_sp1(sx, sy)
  px = x + sx
  py = y + sy
  
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
EndMacro


Procedure StochasticBlur_sp(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]
  Protected samples = *param\option[1]
  
  If radius < 1 : radius = 1 : EndIf
  If samples < 1 : samples = 5 : EndIf
  
  Protected x, y, sx, sy, i, index
  Protected value, r, g, b, a
  Protected sumA, sumR, sumG, sumB
  Protected px, py
  Protected lg_minus_1 = lg - 1
  Protected ht_minus_1 = ht - 1
  Protected diameter = radius * 2 + 1
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
      
      ; Générer des échantillons stochastiques uniformes
      For i = 1 To samples
        ; Échantillonnage pseudo-aléatoire dans le voisinage
        sx = Mod((i * 37), diameter) - radius
        sy = Mod((i * 59), diameter) - radius
        StochasticBlur_sp1(sx, sy)
      Next
      
      ; Moyenne des échantillons
      a = sumA / samples
      r = sumR / samples
      g = sumG / samples
      b = sumB / samples
      
      ; Clamping pour sécurité
      If a < 0 : a = 0 : ElseIf a > 255 : a = 255 : EndIf
      If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
      
      PokeL(*param\addr[1] + (y * lg + x) * 4, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure


Procedure StochasticBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Stochastic
    *param\name = "Stochastic Sampling Blur"
    *param\remarque = "Flou basé sur échantillonnage stochastique uniforme"
    *param\info[0] = "Rayon"
    *param\info[1] = "Échantillons"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 1  : *param\info_data(0, 1) = 50  : *param\info_data(0, 2) = 5
    *param\info_data(1, 0) = 5  : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 20
    *param\info_data(2, 0) = 0  : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Validation des paramètres
  If *param\option[0] < 1 : *param\option[0] = 1 : EndIf
  If *param\option[0] > 50 : *param\option[0] = 50 : EndIf
  If *param\option[1] < 5 : *param\option[1] = 5 : EndIf
  If *param\option[1] > 100 : *param\option[1] = 100 : EndIf
  
  Filter_BufferPrepare(*param)
  MultiThread_MT(@StochasticBlur_sp())
  macro_Filter_BufferFinalize(2)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 99
; FirstLine = 30
; Folding = -
; EnableXP
; DPIAware