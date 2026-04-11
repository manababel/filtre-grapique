Macro ChromaticBlur_sp1(dxR, dyR, dxG, dyG, dxB, dyB)
  ; Canal Rouge
  px = x + dxR
  py = y + dyR
  If px < 0 : px = 0 : ElseIf px > lg_minus_1 : px = lg_minus_1 : EndIf
  If py < 0 : py = 0 : ElseIf py > ht_minus_1 : py = ht_minus_1 : EndIf
  index = (py * lg + px) << 2
  value = PeekL(*param\addr[0] + index)
  r_temp = (value >> 16) & 255
  sumR + r_temp
  
  ; Canal Vert
  px = x + dxG
  py = y + dyG
  If px < 0 : px = 0 : ElseIf px > lg_minus_1 : px = lg_minus_1 : EndIf
  If py < 0 : py = 0 : ElseIf py > ht_minus_1 : py = ht_minus_1 : EndIf
  index = (py * lg + px) << 2
  value = PeekL(*param\addr[0] + index)
  g_temp = (value >> 8) & 255
  sumG + g_temp
  
  ; Canal Bleu
  px = x + dxB
  py = y + dyB
  If px < 0 : px = 0 : ElseIf px > lg_minus_1 : px = lg_minus_1 : EndIf
  If py < 0 : py = 0 : ElseIf py > ht_minus_1 : py = ht_minus_1 : EndIf
  index = (py * lg + px) << 2
  value = PeekL(*param\addr[0] + index)
  b_temp = value & 255
  sumB + b_temp
  
  ; Canal Alpha (même position que le pixel central)
  index = (y * lg + x) << 2
  value = PeekL(*param\addr[0] + index)
  a_temp = (value >> 24) & 255
  sumA + a_temp
  
  count + 1
EndMacro


Procedure ChromaticBokehBlur_sp(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]
  Protected chroma = *param\option[1]  ; décalage chromatique maximal
  
  If radius < 1 : radius = 1 : EndIf
  If chroma < 0 : chroma = 0 : EndIf
  
  Protected x, y, i
  Protected dxR, dyR, dxG, dyG, dxB, dyB
  Protected value, r, g, b, a
  Protected sumR, sumG, sumB, sumA, count
  Protected px, py, index
  Protected a_temp, r_temp, g_temp, b_temp
  Protected lg_minus_1 = lg - 1
  Protected ht_minus_1 = ht - 1
  Protected chromaRange = chroma * 2 + 1
  Protected samples = radius * radius
  Protected thread_pos = *param\thread_pos
  
  ; Initialisation du générateur aléatoire pour ce thread
  RandomSeed((thread_pos + 1) * 9876)
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      sumR = 0 : sumG = 0 : sumB = 0 : sumA = 0 : count = 0
      
      ; Parcourir un voisinage avec aberration chromatique
      For i = 1 To samples
        ; Décalage pseudo-aléatoire pour chaque canal (simule l'aberration chromatique)
        dxR = Random(chromaRange) - chroma
        dyR = Random(chromaRange) - chroma
        dxG = Random(chromaRange) - chroma
        dyG = Random(chromaRange) - chroma
        dxB = Random(chromaRange) - chroma
        dyB = Random(chromaRange) - chroma
        
        ChromaticBlur_sp1(dxR, dyR, dxG, dyG, dxB, dyB)
      Next
      
      ; Moyenne
      If count > 0
        r = sumR / count
        g = sumG / count
        b = sumB / count
        a = sumA / count
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


Procedure ChromaticBokehBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Optical
    *param\name = "Chromatic Aberration Blur"
    *param\remarque = "Flou simulant l'aberration chromatique des objectifs (franges colorées)"
    *param\info[0] = "Rayon"
    *param\info[1] = "Décalage chromatique"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 1  : *param\info_data(0, 1) = 50 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0  : *param\info_data(1, 1) = 10 : *param\info_data(1, 2) = 2
    *param\info_data(2, 0) = 0  : *param\info_data(2, 1) = 2  : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Validation des paramètres
  If *param\option[0] < 1 : *param\option[0] = 1 : EndIf
  If *param\option[0] > 50 : *param\option[0] = 50 : EndIf
  If *param\option[1] < 0 : *param\option[1] = 0 : EndIf
  If *param\option[1] > 10 : *param\option[1] = 10 : EndIf
  
  Filter_BufferPrepare(*param)
  MultiThread_MT(@ChromaticBokehBlur_sp())
  macro_Filter_BufferFinalize(2)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 112
; FirstLine = 67
; Folding = -
; EnableXP
; DPIAware