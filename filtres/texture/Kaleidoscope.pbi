Procedure Kaleidoscope_MT(*p.parametre)
  Protected *src = *p\addr[0]
  Protected *dst = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected numSlices = *p\option[0]
  If numSlices < 1 : numSlices = 1 : EndIf

  Protected rotationDeg.f = *p\option[1] - 360
  Protected zoom.f = *p\option[2] / 100.0
  If zoom <= 0.01 : zoom = 0.01 : EndIf

  Protected angleOffset.f = Radian(rotationDeg)
  Protected angleStep.f = 2 * #PI / numSlices

  Protected cx = lg / 2
  Protected cy = ht / 2

  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  Protected x, y, dx.f, dy.f, angle.f, dist.f, srcAngle.f
  Protected sx.f, sy.f, sxi, syi
  Protected offsetSrc, offsetDst

  For y = startY To stopY
    dy = y - cy
    For x = 0 To lg - 1
      dx = x - cx
      
      angle = ATan2(dy, dx) + angleOffset
      dist  = Sqr(dx*dx + dy*dy) * zoom

      ; ramener angle dans [0, 2PI]
      While angle < 0 : angle + 2 * #PI : Wend
      While angle >= 2 * #PI : angle - 2 * #PI : Wend

      ; Miroir tous les secteurs impairs
      srcAngle = Mod(angle, angleStep)
      If Mod(Int(angle / angleStep), 2) = 1
        srcAngle = angleStep - srcAngle
      EndIf

      sx = cx + Cos(srcAngle) * dist
      sy = cy + Sin(srcAngle) * dist

      Clamp(sx, 0, lg - 1)
      Clamp(sy, 0, ht - 1)

      sxi = Int(sx)
      syi = Int(sy)

      offsetSrc = (syi * lg + sxi) * 4
      offsetDst = (y * lg + x) * 4

      PokeL(*dst + offsetDst, PeekL(*src + offsetSrc))
    Next
  Next
EndProcedure

Procedure Kaleidoscope(*param.parametre)
  If param\info_active
    param\typ = #FilterType_TexturePattern
    param\name = "Kaleidoscope"
    param\remarque = "Effet kaléidoscopique avec rotation et zoom"
    param\info[0] = "Nb secteurs"
    param\info[1] = "Rotation"
    param\info[2] = "Zoom"
    param\info[3] = "Masque binaire"
    param\info_data(0,0) = 1  : param\info_data(0,1) = 24  : param\info_data(0,2) = 6
    param\info_data(1,0) = 0 : param\info_data(1,1) = 720 : param\info_data(1,2) = 360
    param\info_data(2,0) = 10 : param\info_data(2,1) = 500 : param\info_data(2,2) = 100
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2 : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf

  filter_start(@Kaleidoscope_MT(), 3, 1)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 2
; Folding = -
; EnableXP
; DPIAware