Procedure DefocusBlur_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected radius = *param\option[0]
  Protected samples = *param\option[1]  ; Nombre d'échantillons circulaires
  
  If radius < 1 : radius = 1 : EndIf
  If samples < 4 : samples = 4 : EndIf
  If samples > 64 : samples = 64 : EndIf
  
  Protected x, y, i
  Protected sumR.f, sumG.f, sumB.f, sumA.f
  Protected sx, sy, index, value
  Protected r, g, b, a
  Protected angle.f, dist.f
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0
      
      ; Échantillonnage circulaire (simulation défocalisation)
      For i = 0 To samples - 1
        angle = (2.0 * #PI * i) / samples
        dist = radius * Sqr(Random(1000) / 1000.0)  ; Distribution uniforme dans le disque
        
        sx = x + Cos(angle) * dist
        sy = y + Sin(angle) * dist
        
        ; Clamp
        If sx < 0 : sx = 0 : EndIf
        If sx >= lg : sx = lg - 1 : EndIf
        If sy < 0 : sy = 0 : EndIf
        If sy >= ht : sy = ht - 1 : EndIf
        
        index = (sy * lg + sx) << 2
        value = PeekL(*param\addr[0] + index)
        
        a = ((value >> 24) & $FF)
        r = ((value >> 16) & $FF)
        g = ((value >> 8) & $FF)
        b = (value & $FF)
        sumA + a
        sumR + r
        sumG + g
        sumB + b
      Next
      
      ; Moyenne
      a = sumA / samples
      r = sumR / samples
      g = sumG / samples
      b = sumB / samples
      
      Clamp(a, 0, 255)
      Clamp(r, 0, 255)
      Clamp(g, 0, 255)
      Clamp(b, 0, 255)
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure DefocusBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Specialized
    *param\name = "DefocusBlur"
    *param\remarque = "Défocalisation circulaire simulée"
    *param\info[0] = "Rayon"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 30 : *param\info_data(0, 2) = 10
    *param\info[1] = "Échantillons"
    *param\info_data(1, 0) = 4 : *param\info_data(1, 1) = 64 : *param\info_data(1, 2) = 16
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 30)
  Clamp(*param\option[1], 4, 64)
  
  filter_start(@DefocusBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 45
; Folding = -
; EnableXP
; DPIAware