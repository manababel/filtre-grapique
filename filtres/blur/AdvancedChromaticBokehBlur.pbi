Macro AdvancedChromaticBlur_sp1(v1, v2, channel)
  px = v1
  py = v2
  Clamp(px, 0, lg - 1)
  Clamp(py, 0, ht - 1)
  index = (py * lg + px) * 4
  value = PeekL(*param\addr[0] + index)
  
  ; Extraction optimisée des composantes
  a_temp = (value >> 24) & 255
  r_temp = (value >> 16) & 255
  g_temp = (value >> 8) & 255
  b_temp = value & 255
  
  Select channel
    Case 0 
      sumR + r_temp
      countR + 1
    Case 1 
      sumG + g_temp
      countG + 1
    Case 2 
      sumB + b_temp
      countB + 1
  EndSelect
  sumA + a_temp
EndMacro

Procedure AdvancedChromaticBokehBlur_sp(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]
  Protected sides = *param\option[1]
  Protected chroma = *param\option[2]
  
  ; Validation des paramètres
  If radius < 1 : radius = 1 : EndIf
  If sides < 3 : sides = 3 : EndIf
  If chroma < 0 : chroma = 0 : EndIf
  
  Protected x, y, i
  Protected.f angle
  Protected px, py
  Protected value, r.l, g.l, b.l, a.l
  Protected sumR, sumG, sumB, sumA
  Protected countR, countG, countB
  Protected dxR, dyR, dxG, dyG, dxB, dyB
  Protected index
  Protected a_temp, r_temp, g_temp, b_temp
  Protected chromaRange = chroma * 2
  Protected angleStep.f = 2.0 * #PI / sides
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      sumR = 0 : sumG = 0 : sumB = 0 : sumA = 0
      countR = 0 : countG = 0 : countB = 0
      
      ; Parcourir les sommets du polygone pour chaque canal
      For i = 0 To sides - 1
        angle = angleStep * i
        
        ; Décalage chromatique aléatoire pour chaque canal
        dxR = Round(radius * Cos(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
        dyR = Round(radius * Sin(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
        dxG = Round(radius * Cos(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
        dyG = Round(radius * Sin(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
        dxB = Round(radius * Cos(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
        dyB = Round(radius * Sin(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
        
        AdvancedChromaticBlur_sp1(x + dxR, y + dyR, 0)
        AdvancedChromaticBlur_sp1(x + dxG, y + dyG, 1)
        AdvancedChromaticBlur_sp1(x + dxB, y + dyB, 2)
      Next
      
      ; Calcul de la moyenne des pixels échantillonnés par canal
      If countR > 0
        r = sumR / countR
      Else
        r = (PeekL(*param\addr[0] + (y * lg + x) * 4) >> 16) & 255
      EndIf
      
      If countG > 0
        g = sumG / countG
      Else
        g = (PeekL(*param\addr[0] + (y * lg + x) * 4) >> 8) & 255
      EndIf
      
      If countB > 0
        b = sumB / countB
      Else
        b = PeekL(*param\addr[0] + (y * lg + x) * 4) & 255
      EndIf
      
      ; Alpha basé sur le nombre total d'échantillons
      If countR > 0 Or countG > 0 Or countB > 0
        a = sumA / (countR + countG + countB)
      Else
        a = (PeekL(*param\addr[0] + (y * lg + x) * 4) >> 24) & 255
      EndIf
      
      ; Écriture du pixel résultant
      PokeL(*param\addr[1] + (y * lg + x) * 4, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure AdvancedChromaticBokehBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Optical
    *param\name = "AdvancedChromaticBokehBlur"
    *param\remarque = "Flou cinématographique polygonal avec aberration chromatique"
    *param\info[0] = "Rayon"
    *param\info[1] = "Nombre de côtés du polygone"
    *param\info[2] = "Décalage chromatique"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 5 : *param\info_data(0, 2) = 1
    *param\info_data(1, 0) = 3 : *param\info_data(1, 1) = 12 : *param\info_data(1, 2) = 1
    *param\info_data(2, 0) = 0 : *param\info_data(2, 1) = 5 : *param\info_data(2, 2) = 1
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 5)
  Clamp(*param\option[1], 3, 12)
  Clamp(*param\option[2], 0, 5)
  
  filter_start(@AdvancedChromaticBokehBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 128
; FirstLine = 59
; Folding = -
; EnableXP
; DPIAware