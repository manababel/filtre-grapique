Procedure UnsharpMask_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected radius = *param\option[0]
  Protected amount.f = *param\option[1] / 100.0  ; Force (0-500%)
  Protected threshold = *param\option[2]          ; Seuil de détection des contours
  
  If radius < 1 : radius = 1 : EndIf
  
  Protected x, y, dx, dy, px, py, index, value
  Protected r, g, b, a
  Protected blurR, blurG, blurB
  Protected origR, origG, origB, origA
  Protected sumR, sumG, sumB, count
  Protected diff, sharpR, sharpG, sharpB
  
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
      
      ; Calcul du flou local
      sumR = 0 : sumG = 0 : sumB = 0 : count = 0
      
      For dy = -radius To radius
        py = y + dy
        If py < 0 Or py >= ht : Continue : EndIf
        
        For dx = -radius To radius
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
      
      ; Calcul de la différence (masque flou)
      diff = Abs(origR - blurR) + Abs(origG - blurG) + Abs(origB - blurB)
      
      ; Application du seuil
      If diff >= threshold
        ; Accentuation = original + amount * (original - flou)
        sharpR = origR + amount * (origR - blurR)
        sharpG = origG + amount * (origG - blurG)
        sharpB = origB + amount * (origB - blurB)
        
        Clamp(sharpR, 0, 255)
        Clamp(sharpG, 0, 255)
        Clamp(sharpB, 0, 255)
        
        r = sharpR
        g = sharpG
        b = sharpB
      Else
        ; Pas assez de contraste, garder l'original
        r = origR
        g = origG
        b = origB
      EndIf
      
      a = origA
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure UnsharpMask(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Specialized
    *param\name = "UnsharpMask"
    *param\remarque = "Masque flou (accentuation)"
    *param\info[0] = "Rayon"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 20 : *param\info_data(0, 2) = 3
    *param\info[1] = "Force (%)"
    *param\info_data(1, 0) = 0 : *param\info_data(1, 1) = 500 : *param\info_data(1, 2) = 100
    *param\info[2] = "Seuil"
    *param\info_data(2, 0) = 0 : *param\info_data(2, 1) = 100 : *param\info_data(2, 2) = 5
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 20)
  Clamp(*param\option[1], 0, 500)
  Clamp(*param\option[2], 0, 100)
  
  filter_start(@UnsharpMask_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 89
; FirstLine = 40
; Folding = -
; EnableXP
; DPIAware