Procedure SoftShadow(*param.parametre)
  Protected *source = *param\source
  Protected *cible  = *param\cible
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected offsetX = *param\option[0]
  Protected offsetY = *param\option[1]
  Protected shadowIntensity = *param\option[2]

  offsetX = offsetX - 10
  offsetY = offsetY - 10
  Clamp(offsetX, -10, 10)
  Clamp(offsetY, -10, 10)
  Clamp(shadowIntensity, 0, 255)

  Protected i, x, y, var, r, g, b, sr, sg, sb
  Protected sx, sy, si , oy , ox
  Protected factor.f = 1.0 - shadowIntensity / 255.0
  Protected intensity.f = shadowIntensity / 255.0

  ; Variables pour la moyenne floue
  Protected blurR.l, blurG.l, blurB.l
  Protected count.l

  For y = 0 To ht - 1
    For x = 0 To lg - 1
      i = y * lg + x
      var = PeekL(*source + (i << 2))
      RGBReturn(var, r, g, b)

      ; Calculer la moyenne floue autour du pixel décalé
      blurR = 0
      blurG = 0
      blurB = 0
      count = 0

      For oy = -1 To 1
        For ox = -1 To 1
          sx = x + offsetX + ox
          sy = y + offsetY + oy
          If (sx >= 0) And (sx < lg-1) And (sy >= 0) And (sy < ht-1)
            si = sy * lg + sx
            var = PeekL(*source + (si << 2))
            RGBReturn(var, sr, sg, sb)
            blurR + sr
            blurG + sg
            blurB + sb
            count + 1
          EndIf
        Next
      Next

      ; Moyenne
      If count <> 0
      sr = blurR / count
      sg = blurG / count
      sb = blurB / count
    EndIf
    
      ; Mélange
      r = Int(r * factor + sr * intensity * 0.5)
      g = Int(g * factor + sg * intensity * 0.5)
      b = Int(b * factor + sb * intensity * 0.5)

      Clamp_RGB(r, g, b)
      PokeL(*cible + (i << 2), (r << 16) + (g << 8) + b)
    Next
  Next
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 43
; FirstLine = 5
; Folding = -
; EnableXP
; DPIAware