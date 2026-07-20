; ============================================================================
; PASSE 1 : Horizontale (*src -> *tmp)
; ============================================================================
Procedure WatercolorBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected sharpness = \option[1]
    
    If radius < 1 : radius = 1 : EndIf
    
    Protected x, y, dx, px, value
    Protected r, g, b, a, centerR, centerG, centerB, centerA
    Protected diff, y_offset.i
    Protected sumR.f, sumG.f, sumB.f, sumA.f, sumWeight.f, weight.f
    
    Protected sharpFactor.f = 1.0 + (sharpness / 10.0)
    Protected invSharp.f = 1.0 / (sharpFactor * 50.0)
    
    ; Pré-calcul d'une Look-Up Table (LUT) pour la fonction Exp()
    ; La différence 'diff' maximale entre 2 couleurs RGB est 255 * 3 = 765
    Protected Dim ExpLUT.f(765)
    For diff = 0 To 765
      ExpLUT(diff) = Exp(-diff * invSharp)
    Next
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      y_offset = y * lg
      For x = 0 To lg - 1
        value = *src\l[y_offset + x]
        centerA = (value >> 24) & $FF
        centerR = (value >> 16) & $FF
        centerG = (value >> 8) & $FF
        centerB = value & $FF
        
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : sumWeight = 0.0
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          
          value = *src\l[y_offset + px]
          a = (value >> 24) & $FF
          r = (value >> 16) & $FF
          g = (value >> 8) & $FF
          b = value & $FF
          
          diff = Abs(r - centerR) + Abs(g - centerG) + Abs(b - centerB)
          weight = ExpLUT(diff) ; Lecture rapide dans la table
          
          sumA + a * weight
          sumR + r * weight
          sumG + g * weight
          sumB + b * weight
          sumWeight + weight
        Next
        
        If sumWeight > 0.0
          a = sumA / sumWeight
          r = sumR / sumWeight
          g = sumG / sumWeight
          b = sumB / sumWeight
        Else
          a = centerA : r = centerR : g = centerG : b = centerB
        EndIf
        
        *tmp\l[y_offset + x] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PASSE 2 : Verticale (*tmp -> *dst)
; ============================================================================
Procedure WatercolorBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected sharpness = \option[1]
    
    If radius < 1 : radius = 1 : EndIf
    
    Protected x, y, dy, py, value
    Protected r, g, b, a, centerR, centerG, centerB, centerA
    Protected diff
    Protected sumR.f, sumG.f, sumB.f, sumA.f, sumWeight.f, weight.f
    
    Protected sharpFactor.f = 1.0 + (sharpness / 10.0)
    Protected invSharp.f = 1.0 / (sharpFactor * 50.0)
    
    Protected Dim ExpLUT.f(765)
    For diff = 0 To 765
      ExpLUT(diff) = Exp(-diff * invSharp)
    Next
    
    Protected *tmp.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        value = *tmp\l[y * lg + x]
        centerA = (value >> 24) & $FF
        centerR = (value >> 16) & $FF
        centerG = (value >> 8) & $FF
        centerB = value & $FF
        
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : sumWeight = 0.0
        
        For dy = -radius To radius
          py = y + dy
          If py < 0 Or py >= ht : Continue : EndIf
          
          value = *tmp\l[py * lg + x]
          a = (value >> 24) & $FF
          r = (value >> 16) & $FF
          g = (value >> 8) & $FF
          b = value & $FF
          
          diff = Abs(r - centerR) + Abs(g - centerG) + Abs(b - centerB)
          weight = ExpLUT(diff)
          
          sumA + a * weight
          sumR + r * weight
          sumG + g * weight
          sumB + b * weight
          sumWeight + weight
        Next
        
        If sumWeight > 0.0
          a = sumA / sumWeight
          r = sumR / sumWeight
          g = sumG / sumWeight
          b = sumB / sumWeight
        Else
          a = centerA : r = centerR : g = centerG : b = centerB
        EndIf
        
        *dst\l[y * lg + x] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; LANCEUR
; ============================================================================
Procedure WatercolorBlurEx(*FilterCtx.FilterParams)
  Restore WatercolorBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    If \option[0] < 1 : \option[0] = 1 : ElseIf \option[0] > 15 : \option[0] = 15 : EndIf
    If \option[1] < 0 : \option[1] = 0 : ElseIf \option[1] > 100 : \option[1] = 100 : EndIf
    
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@WatercolorBlur_H_MT())
      Create_MultiThread_MT(@WatercolorBlur_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
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
; CursorPosition = 176
; FirstLine = 121
; Folding = -
; EnableXP
; DPIAware