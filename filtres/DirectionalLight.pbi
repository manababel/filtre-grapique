Procedure DirectionalLight(*param.parametre)
  Protected *source = *param\source
  Protected *cible  = *param\cible
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected dx.f = *param\option[0]  ; direction x
  Protected dy.f = *param\option[1]  ; direction y
  Protected intensity.f = *param\option[2]
  
  Clamp(intensity, 1, 100)
  intensity = intensity *0.01
  
  Protected i, x, y, var, r, g, b
  Protected nx.f, ny.f, dot.f, factor.f
  
  ; normalisation direction lumière
  Protected len.f = Sqr(dx*dx + dy*dy)
  If len = 0
    dx = 0
    dy = 1
  Else
    dx / len
    dy / len
  EndIf
  
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      i = y * lg + x
      var = PeekL(*source + (i << 2))
      RGBReturn(var, r, g, b)
      
      ; normal de la surface simple : vers haut (0,1)
      nx = 0
      ny = 1
      
      dot = dx*nx + dy*ny
      factor = intensity * dot
      If factor < 0 : factor = 0 : EndIf
      
      r = r * factor
      g = g * factor
      b = b * factor
      
      clamp_rgb(r,g,b)
      PokeL(*cible + (i << 2), (r << 16) + (g << 8) + b)
    Next
  Next
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 13
; Folding = -
; EnableXP
; DPIAware