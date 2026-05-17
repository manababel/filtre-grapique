; ==============================================================================
; FILTRE KALEIDOSCOPE - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Kaleidoscope_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0]
    Protected *dst = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected numSlices = \option[0]
    If numSlices < 1 : numSlices = 1 : EndIf

    Protected rotationDeg.f = \option[1] - 360
    Protected zoom.f = \option[2] / 100.0
    If zoom <= 0.01 : zoom = 0.01 : EndIf

    Protected angleOffset.f = Radian(rotationDeg)
    Protected angleStep.f = 2 * #PI / numSlices

    Protected cx = lg / 2
    Protected cy = ht / 2

    ; --- Configuration Multithreading (macro_calcul_thread) ---
    macro_calul_tread(ht)
    Protected startY = (\thread_pos * ht) / \thread_max
    Protected stopY  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected x, y, dx.f, dy.f, angle.f, dist.f, srcAngle.f
    Protected sx.f, sy.f, sxi, syi
    Protected offsetSrc, offsetDst

    ; --- Traitement principal ---
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
  EndWith
EndProcedure

Procedure KaleidoscopeEx(*FilterCtx.FilterParams)
  Restore Kaleidoscope_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Kaleidoscope_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Kaleidoscope(source, cible, mask, numSlices=6, rotation=360, zoom=100)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = numSlices
    \option[1] = rotation
    \option[2] = zoom
  EndWith
  KaleidoscopeEx(FilterCtx)
EndProcedure

DataSection
  Kaleidoscope_Data:
  Data.s "Kaleidoscope"
  Data.s "Effet kaléidoscopique avec rotation et zoom"
  Data.i #FilterType_TexturePattern, #Artistic_Other
  Data.s "Nb secteurs" : Data.i 1, 24, 6
  Data.s "Rotation"    : Data.i 0, 720, 360
  Data.s "Zoom"        : Data.i 10, 500, 100
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 24
; Folding = -
; EnableXP
; DPIAware