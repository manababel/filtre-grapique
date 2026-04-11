Procedure OilPaintBlur_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected radius = *param\option[0]
  Protected intensityLevels = *param\option[1]  ; Niveaux d'intensité (quantification)
  
  If radius < 1 : radius = 1 : EndIf
  If intensityLevels < 2 : intensityLevels = 2 : EndIf
  If intensityLevels > 256 : intensityLevels = 256 : EndIf
  
  Protected x, y, dx, dy, px, py, index, value
  Protected r, g, b, a, intensity, intensityBin
  Protected i 
  ; Histogrammes pour chaque canal et bin d'intensité
  Dim histR(intensityLevels - 1)
  Dim histG(intensityLevels - 1)
  Dim histB(intensityLevels - 1)
  Dim histA(intensityLevels - 1)
  Dim histCount(intensityLevels - 1)
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      ; Réinitialiser les histogrammes
      For i = 0 To intensityLevels - 1
        histR(i) = 0
        histG(i) = 0
        histB(i) = 0
        histA(i) = 0
        histCount(i) = 0
      Next
      
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
          
          ; Calcul de l'intensité (luminance)
          intensity = (r * 77 + g * 150 + b * 29) >> 8
          
          ; Quantification de l'intensité
          intensityBin = (intensity * intensityLevels) / 256
          If intensityBin >= intensityLevels : intensityBin = intensityLevels - 1 : EndIf
          
          ; Accumulation dans l'histogramme
          histR(intensityBin) + r
          histG(intensityBin) + g
          histB(intensityBin) + b
          histA(intensityBin) + a
          histCount(intensityBin) + 1
        Next
      Next
      
      ; Trouver le bin le plus fréquent
      Protected maxCount = 0, maxBin = 0
      For i = 0 To intensityLevels - 1
        If histCount(i) > maxCount
          maxCount = histCount(i)
          maxBin = i
        EndIf
      Next
      
      ; Calculer la moyenne des pixels du bin dominant
      If maxCount > 0
        a = histA(maxBin) / maxCount
        r = histR(maxBin) / maxCount
        g = histG(maxBin) / maxCount
        b = histB(maxBin) / maxCount
      Else
        ; Fallback: pixel original
        index = (y * lg + x) << 2
        value = PeekL(*param\addr[0] + index)
        a = (value >> 24) & $FF
        r = (value >> 16) & $FF
        g = (value >> 8) & $FF
        b = value & $FF
      EndIf
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure OilPaintBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Artistic
    *param\name = "OilPaintBlur"
    *param\remarque = "Effet peinture à l'huile"
    *param\info[0] = "Rayon"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 15 : *param\info_data(0, 2) = 5
    *param\info[1] = "Niveaux d'intensité"
    *param\info_data(1, 0) = 2 : *param\info_data(1, 1) = 64 : *param\info_data(1, 2) = 20
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 15)
  Clamp(*param\option[1], 2, 64)
  
  filter_start(@OilPaintBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 11
; Folding = -
; EnableXP
; DPIAware