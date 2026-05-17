Procedure OilPaintBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected intensityLevels = \option[1]  ; Niveaux d'intensité (quantification)
    
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
            value = PeekL(\addr[0] + index)
            
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
          value = PeekL(\addr[0] + index)
          a = (value >> 24) & $FF
          r = (value >> 16) & $FF
          g = (value >> 8) & $FF
          b = value & $FF
        EndIf
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure OilPaintBlurEx(*FilterCtx.FilterParams)
  Restore OilPaintBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Application des Clamps d'origine
    If \option[0] < 1 : \option[0] = 1 : ElseIf \option[0] > 15 : \option[0] = 15 : EndIf
    If \option[1] < 2 : \option[1] = 2 : ElseIf \option[1] > 64 : \option[1] = 64 : EndIf
    
    Create_MultiThread_MT(@OilPaintBlur_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure OilPaintBlur(source, cible, mask, rayon, intensite)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = intensite
  EndWith
  OilPaintBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  OilPaintBlur_data:
  Data.s "OilPaintBlur"
  Data.s "Effet peinture à l'huile"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Rayon"
  Data.i 1, 15, 5
  Data.s "Niveaux d'intensité"
  Data.i 2, 64, 20
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 114
; FirstLine = 86
; Folding = -
; EnableXP
; DPIAware