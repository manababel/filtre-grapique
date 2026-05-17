Procedure WatercolorBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected sharpness = \option[1]  ; Netteté des bords (0-100)
    
    If radius < 1 : radius = 1 : EndIf
    
    Protected x, y, dx, dy, px, py, index, value
    Protected r, g, b, a
    Protected centerR, centerG, centerB, centerA
    Protected sumR.f, sumG.f, sumB.f, sumA.f, sumWeight.f
    Protected diff, weight.f
    
    ; Conversion du paramètre sharpness en facteur de poids
    Protected sharpFactor.f = 1.0 + (sharpness / 10.0)
    
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
            
            ; Calcul de la similarité de couleur
            diff = Abs(r - centerR) + Abs(g - centerG) + Abs(b - centerB)
            
            ; Poids basé sur la similarité (effet aquarelle)
            ; Les couleurs similaires se mélangent plus
            weight = Exp(-diff / (sharpFactor * 50.0))
            
            sumA + a * weight
            sumR + r * weight
            sumG + g * weight
            sumB + b * weight
            sumWeight + weight
          Next
        Next
        
        ; Normalisation
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
        
        ; Clamp d'origine conservé (opération locale sur variables)
        If a < 0 : a = 0 : ElseIf a > 255 : a = 255 : EndIf
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure WatercolorBlurEx(*FilterCtx.FilterParams)
  Restore WatercolorBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Application des Clamps d'origine sur les options
    If \option[0] < 1 : \option[0] = 1 : ElseIf \option[0] > 15 : \option[0] = 15 : EndIf
    If \option[1] < 0 : \option[1] = 0 : ElseIf \option[1] > 100 : \option[1] = 100 : EndIf
    
    Create_MultiThread_MT(@WatercolorBlur_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure WatercolorBlur(source, cible, mask, rayon, nettete)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = nettete
  EndWith
  WatercolorBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  WatercolorBlur_data:
  Data.s "WatercolorBlur"
  Data.s "Effet aquarelle avec diffusion des couleurs"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Rayon"
  Data.i 1, 15, 5
  Data.s "Netteté"
  Data.i 0, 100, 30
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 104
; FirstLine = 76
; Folding = -
; EnableXP
; DPIAware