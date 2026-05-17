; ---------------------------------------------------
; SurfaceBlur - Version optimisée
; Flou de surface préservant les contours
; ---------------------------------------------------

Procedure SurfaceBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected threshold = \option[1]  ; Seuil de différence
    
    If radius < 1 : radius = 1 : EndIf
    If threshold < 1 : threshold = 1 : EndIf
    
    Protected x, y, dx, dy, px, py, index, value
    Protected r, g, b, a
    Protected centerR, centerG, centerB, centerA
    Protected sumR.f, sumG.f, sumB.f, sumA.f, sumWeight.f
    Protected diffR, diffG, diffB
    Protected weight.f
    Protected thresholdSq.f = threshold * threshold
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        ; Pixel central
        index = (y * lg + x) << 2
        value = PeekL(\addr[0] + index)
        centerA = (value >> 24) & $FF
        centerR = (value >> 16) & $FF
        centerG = (value >> 8) & $FF
        centerB = value & $FF
        
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : sumWeight = 0.0
        
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
            
            ; Calcul de la différence de couleur
            diffR = r - centerR
            diffG = g - centerG
            diffB = b - centerB
            
            ; Distance euclidienne au carré
            Protected distSq.f = diffR * diffR + diffG * diffG + diffB * diffB
            
            ; Calcul du poids (fonction gaussienne de la différence)
            weight = Exp(-distSq / (2.0 * thresholdSq))
            
            sumA + a * weight
            sumR + r * weight
            sumG + g * weight
            sumB + b * weight
            sumWeight + weight
          Next
        Next
        
        ; Normalisation par la somme des poids
        If sumWeight > 0.0
          a = sumA / sumWeight
          r = sumR / sumWeight
          g = sumG / sumWeight
          b = sumB / sumWeight
        Else
          a = centerA
          r = centerR
          g = centerG
          b = centerB
        EndIf
        
        ; Clamping des valeurs
        If a < 0 : a = 0 : ElseIf a > 255 : a = 255 : EndIf
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure SurfaceBlurEx(*FilterCtx.FilterParams)
  Restore SurfaceBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@SurfaceBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure SurfaceBlur(source, cible, mask, radius, threshold, mask_type)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = threshold
    \option[2] = mask_type
  EndWith
  SurfaceBlurEx(FilterCtx)
EndProcedure

DataSection
  SurfaceBlur_data:
  Data.s "SurfaceBlur"
  Data.s "Flou de surface préservant les contours"
  Data.i #FilterType_Blur, #Blur_EdgeAware
  Data.s "Rayon"
  Data.i 1, 20, 5    ; Rayon
  Data.s "Seuil"
  Data.i 1, 100, 30  ; Seuil
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 107
; FirstLine = 78
; Folding = -
; EnableXP
; DPIAware