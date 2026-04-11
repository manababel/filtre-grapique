Procedure SharpenBlur_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected blurRadius = *param\option[0]
  Protected sharpenAmount.f = *param\option[1] / 100.0  ; Force netteté
  Protected blendRatio.f = *param\option[2] / 100.0     ; Mélange flou/net
  
  If blurRadius < 1 : blurRadius = 1 : EndIf
  
  Protected x, y, dx, dy, px, py, index, value
  Protected r, g, b, a
  Protected blurR, blurG, blurB
  Protected origR, origG, origB, origA
  Protected sumR, sumG, sumB, count
  Protected sharpR, sharpG, sharpB
  Protected finalR, finalG, finalB
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      ; Pixel original
      index = (y * lg + x) << 2
      value = PeekL(*param\addr[0] + index)
      origA = (value >> 24) & $FF
      origR = (value >> 16) & $FF
      origG = (value >> 8) & $FF
      origB = value & $FF
      
      ; Calcul du flou
      sumR = 0 : sumG = 0 : sumB = 0 : count = 0
      
      For dy = -blurRadius To blurRadius
        py = y + dy
        If py < 0 Or py >= ht : Continue : EndIf
        
        For dx = -blurRadius To blurRadius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          
          index = (py * lg + px) << 2
          value = PeekL(*param\addr[0] + index)
          
          sumR + ((value >> 16) & $FF)
          sumG + ((value >> 8) & $FF)
          sumB + (value & $FF)
          count + 1
        Next
      Next
      
      If count > 0
        blurR = sumR / count
        blurG = sumG / count
        blurB = sumB / count
      Else
        blurR = origR
        blurG = origG
        blurB = origB
      EndIf
      
      ; Netteté accentuée
      sharpR = origR + sharpenAmount * (origR - blurR)
      sharpG = origG + sharpenAmount * (origG - blurG)
      sharpB = origB + sharpenAmount * (origB - blurB)
      
      Clamp(sharpR, 0, 255)
      Clamp(sharpG, 0, 255)
      Clamp(sharpB, 0, 255)
      
      ; Mélange entre flou et netteté
      finalR = blurR * blendRatio + sharpR * (1.0 - blendRatio)
      finalG = blurG * blendRatio + sharpG * (1.0 - blendRatio)
      finalB = blurB * blendRatio + sharpB * (1.0 - blendRatio)
      
      Clamp(finalR, 0, 255)
      Clamp(finalG, 0, 255)
      Clamp(finalB, 0, 255)
      
      r = finalR
      g = finalG
      b = finalB
      a = origA
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure SharpenBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Specialized
    *param\name = "SharpenBlur"
    *param\remarque = "Combinaison flou et netteté avec dosage"
    *param\info[0] = "Rayon flou"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 20 : *param\info_data(0, 2) = 5
    *param\info[1] = "Force netteté (%)"
    *param\info_data(1, 0) = 0 : *param\info_data(1, 1) = 300 : *param\info_data(1, 2) = 150
    *param\info[2] = "Ratio flou (%)"
    *param\info_data(2, 0) = 0 : *param\info_data(2, 1) = 100 : *param\info_data(2, 2) = 30
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 20)
  Clamp(*param\option[1], 0, 300)
  Clamp(*param\option[2], 0, 100)
  
  filter_start(@SharpenBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 87
; FirstLine = 38
; Folding = -
; EnableXP
; DPIAware