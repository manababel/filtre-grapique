; ---------------------------------------------------
; SmartBlur - Version optimisée
; Flou intelligent préservant les contours
; ---------------------------------------------------

Procedure SmartBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected threshold = \option[1]  ; Seuil de différence
    
    If radius < 1 : radius = 1 : EndIf
    If threshold < 0 : threshold = 0 : EndIf
    
    Protected x, y, dx, dy, px, py, index, value
    Protected r, g, b, a
    Protected centerR, centerG, centerB, centerA
    Protected sumR, sumG, sumB, sumA, count
    Protected diffR, diffG, diffB, diff
    
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
        
        sumR = 0 : sumG = 0 : sumB = 0 : sumA = 0 : count = 0
        
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
            
            ; Calcul de la différence avec le pixel central
            diffR = Abs(r - centerR)
            diffG = Abs(g - centerG)
            diffB = Abs(b - centerB)
            diff = (diffR + diffG + diffB) / 3
            
            ; N'inclure que si la différence est sous le seuil
            If diff <= threshold
              sumA + a
              sumR + r
              sumG + g
              sumB + b
              count + 1
            EndIf
          Next
        Next
        
        ; Calculer la moyenne ou garder l'original
        If count > 0
          a = sumA / count
          r = sumR / count
          g = sumG / count
          b = sumB / count
        Else
          a = centerA
          r = centerR
          g = centerG
          b = centerB
        EndIf
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure SmartBlurEx(*FilterCtx.FilterParams)
  Restore SmartBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@SmartBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure SmartBlur(source, cible, mask, radius, threshold, mask_type)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = threshold
    \option[2] = mask_type
  EndWith
  SmartBlurEx(FilterCtx)
EndProcedure

DataSection
  SmartBlur_data:
  Data.s "SmartBlur"
  Data.s "Flou intelligent préservant les contours"
  Data.i #FilterType_Blur, #Blur_EdgeAware
  Data.s "Rayon"
  Data.i 1, 20, 3    ; Rayon
  Data.s "Seuil"
  Data.i 0, 100, 30  ; Seuil
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 97
; FirstLine = 68
; Folding = -
; EnableXP
; DPIAware