; ==============================================================================
; FILTRE ZIGZAG (DENTS DE SCIE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Zigzag_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected offset_x.f, offset_y.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Configuration et Précalculs ---
    Protected amplitude.f = \option[0]
    Protected zigzag_count.i = \option[1]
    If zigzag_count < 1 : zigzag_count = 1 : EndIf
    
    Protected direction.i = \option[2] ; 0:H, 1:V, 2:Diag/, 3:Diag\
    Protected shape.i     = \option[3] ; 0:Scie, 1:Triangle, 2:Créneaux
    Protected smoothing.f = (\option[4] / 100.0)

    ; --- Configuration Multithreading ---
    Protected startY.i = ((\thread_pos * ht) / \thread_max)
    Protected stopY.i  = (((\thread_pos + 1) * ht) / \thread_max - 1)
    If stopY > (ht - 1) : stopY = (ht - 1) : EndIf

    Protected offset_dst.i, offset_src.i
    Protected position.f, segment_size.f
    Protected normalized_pos.f, zigzag_value.f
    Protected progress.f, smooth_factor.f
    Protected diag_scale.f = 0.7071

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = (y * lg * 4)

      For x = 0 To (lg - 1)
        offset_x = 0
        offset_y = 0

        Select direction
          Case 0 : position = x : segment_size = (lg / zigzag_count)
          Case 1 : position = y : segment_size = (ht / zigzag_count)
          Case 2 : position = (x + y) : segment_size = ((lg + ht) / zigzag_count)
          Case 3 : position = (x - y + ht) : segment_size = ((lg + ht) / zigzag_count)
        EndSelect

        normalized_pos = (position / segment_size)
        progress = (normalized_pos - Int(normalized_pos))

        Select shape
          Case 0 : zigzag_value = progress
          Case 1 : If progress < 0.5 : zigzag_value = (progress * 2.0)
                   Else : zigzag_value = (2.0 - (progress * 2.0)) : EndIf
          Case 2 : If progress < 0.5 : zigzag_value = 0.0 : Else : zigzag_value = 1.0 : EndIf
        EndSelect

        If smoothing > 0
          smooth_factor = Sin((zigzag_value * #PI))
          zigzag_value = (zigzag_value * (1.0 - smoothing) + (smooth_factor * smoothing))
        EndIf

        zigzag_value = (zigzag_value * 2.0 - 1.0)
        
        Select direction
          Case 0 : offset_y = (amplitude * zigzag_value)
          Case 1 : offset_x = (amplitude * zigzag_value)
          Case 2 : offset_x = (amplitude * zigzag_value * diag_scale)
                   offset_y = (-amplitude * zigzag_value * diag_scale)
          Case 3 : offset_x = (amplitude * zigzag_value * diag_scale)
                   offset_y = (amplitude * zigzag_value * diag_scale)
        EndSelect

        src_x = (x + offset_x)
        src_y = (y + offset_y)
        src_x_int = Int(src_x)
        src_y_int = Int(src_y)

        If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
          offset_src = ((src_y_int * lg + src_x_int) * 4)
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $00000000)
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure ZigzagEx(*FilterCtx.FilterParams)
  Restore Zigzag_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Zigzag_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Zigzag(source, cible, mask, amp=20, count=10, dir=0, shape=0, smooth=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = amp
    \option[1] = count
    \option[2] = dir
    \option[3] = shape
    \option[4] = smooth
  EndWith
  ZigzagEx(FilterCtx)
EndProcedure

DataSection
  Zigzag_Data:
  Data.s "Zigzag (Dents de scie)"
  Data.s "Déformation en zigzag avec formes géométriques et lissage configurable"
  Data.i #FilterType_Deformation, 0
  Data.s "Amplitude (pixels)"
  Data.i 0, 100, 20
  Data.s "Nombre de zigzags"
  Data.i 1, 100, 10
  Data.s "Direction (0=horiz, 1=vert, 2=diag/, 3=diag\)"
  Data.i 0, 3, 0
  Data.s "Forme (0=scie, 1=triangle, 2=créneaux)"
  Data.i 0, 2, 0
  Data.s "Lissage (0=vif, 100=arrondi)"
  Data.i 0, 100, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 127
; FirstLine = 84
; Folding = -
; EnableXP
; DPIAware