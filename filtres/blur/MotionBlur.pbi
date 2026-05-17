; ===== Motion Blur orienté (multithread) =====
Procedure MotionBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0]
    Protected *dst = \addr[1]
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected radius = \option[0]
    Protected angle.f = \option[1] * #PI / 180.0
    
    Protected thread_pos = \thread_pos
    Protected thread_max = \thread_max
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
    
    For y = yStart To yEnd
      For x = 0 To w - 1
        r = 0 : g = 0 : b = 0
        ; Position de départ
        xi = x - dx * radius
        yi = y - dy * radius
        For k = 0 To size - 1
          ; Clamping optimisé
          If xi < 0 : xiClamped = 0 : ElseIf xi >= w : xiClamped = wMinus1 : Else : xiClamped = Int(xi) : EndIf
          If yi < 0 : yiClamped = 0 : ElseIf yi >= h : yiClamped = hMinus1 : Else : yiClamped = Int(yi) : EndIf
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
  EndWith
EndProcedure

; ===== Procédure principale Motion Blur orienté =====
Procedure MotionBlurEx(*FilterCtx.FilterParams)
  Restore MotionBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  ;Filter_BufferPrepare(FilterCtx.FilterParams)
  create_MultiThread_MT(@MotionBlur_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
  
EndProcedure

Procedure MotionBlur(source , cible , mask , rayon , angle)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = angle
  EndWith
  MotionBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  MotionBlur_data:
  Data.s "MotionBlurEx"
  Data.s ""
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Rayon"       
  Data.i 1,100,10
  Data.s "Angle"   
  Data.i 0,360,0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 31
; FirstLine = 21
; Folding = -
; EnableXP
; DPIAware