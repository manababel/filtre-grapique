; ===== Motion Blur orienté (multithread) =====
Procedure MotionBlur_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected w = *param\lg
  Protected h = *param\ht
  Protected radius = *param\option[0]
  Protected angle.f = *param\option[1] * #PI / 180.0
  
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected yStart = (thread_pos * h) / thread_max
  Protected yEnd = ((thread_pos + 1) * h) / thread_max - 1
  
  If yStart > yEnd : ProcedureReturn : EndIf
  
  ; Précalcul des constantes
  Protected dx.f = Cos(angle)
  Protected dy.f = Sin(angle)
  Protected size = (radius << 1) + 1  ; Bit shift au lieu de * 2
  Protected coeff.f = 1.0 / size
  
  Protected x, y, k
  Protected xi.f, yi.f
  Protected xiClamped, yiClamped
  Protected r, g, b  ; Entiers pour l'accumulation
  Protected r1, g1, b1
  Protected col
  Protected wMinus1 = w - 1
  Protected hMinus1 = h - 1
  Protected posOffset
  
  ; Précalcul des positions relatives
  Protected xStep.f, yStep.f
  
  For y = yStart To yEnd
    For x = 0 To w - 1
      r = 0 : g = 0 : b = 0
      
      ; Position de départ
      xi = x - dx * radius
      yi = y - dy * radius
      
      For k = 0 To size - 1
        ; Clamping optimisé
        If xi < 0
          xiClamped = 0
        ElseIf xi >= w
          xiClamped = wMinus1
        Else
          xiClamped = Int(xi)
        EndIf
        
        If yi < 0
          yiClamped = 0
        ElseIf yi >= h
          yiClamped = hMinus1
        Else
          yiClamped = Int(yi)
        EndIf
        
        posOffset = (yiClamped * w + xiClamped) << 2
        col = PeekL(*src + posOffset)
        getrgb(col, r1, g1, b1)
        
        r + r1
        g + g1
        b + b1
        
        ; Incrémenter les positions
        xi + dx
        yi + dy
      Next
      
      ; Moyenne finale
      r = r * coeff
      g = g * coeff
      b = b * coeff
      
      posOffset = (y * w + x) << 2
      PokeL(*dst + posOffset, (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

; ===== Procédure principale Motion Blur orienté =====
Procedure MotionBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Directional
    *param\name = "MotionBlur"
    *param\remarque = ""
    *param\info[0] = "Rayon"
    *param\info[1] = "Angle"
    *param\info[2] = "Masque"
    *param\info_data(0,0) = 1   : *param\info_data(0,1) = 100 : *param\info_data(0,2) = 10
    *param\info_data(1,0) = 0   : *param\info_data(1,1) = 360 : *param\info_data(1,2) = 0
    *param\info_data(2,0) = 0   : *param\info_data(2,1) = 2   : *param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  
  Filter_BufferPrepare(*param.parametre)
  MultiThread_MT(@MotionBlur_MT())
  macro_Filter_BufferFinalize(2)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 104
; FirstLine = 35
; Folding = -
; EnableXP
; DPIAware