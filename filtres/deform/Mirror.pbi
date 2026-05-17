; ==============================================================================
; FILTRE MIRROR (SYMÉTRIE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Mirror_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected src_x.i, src_y.i
    Protected mirror_pos.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Configuration et Paramètres ---
    Protected axis_type.i     = \option[0] ; 0=vert, 1=horiz, 2=diag/, 3=diag\
    Protected axis_position.f = \option[1] / 100.0
    Protected keep_side.i     = \option[2] ; 0=gauche/haut, 1=droite/bas, 2=mixte
    Protected fade_amount.f   = \option[3] / 100.0

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i
    Protected distance_to_axis.f, fade_factor.f, max_distance.f
    Protected pixel_src.l, pixel_mirror.l
    Protected r1.i, g1.i, b1.i, a1.i
    Protected r2.i, g2.i, b2.i, a2.i
    Protected r.i, g.i, b.i, a.i

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        ; Sélection de la logique de symétrie
        Select axis_type
          Case 0 ; ===== Axe vertical =====
            mirror_pos = Int(axis_position * lg)
            src_y = y
            If keep_side = 0 : src_x = x : If x >= mirror_pos : src_x = 2 * mirror_pos - x : EndIf
            ElseIf keep_side = 1 : src_x = x : If x <= mirror_pos : src_x = 2 * mirror_pos - x : EndIf
            Else : src_x = x : distance_to_axis = Abs(x - mirror_pos) : max_distance = mirror_pos : EndIf

          Case 1 ; ===== Axe horizontal =====
            mirror_pos = Int(axis_position * ht)
            src_x = x
            If keep_side = 0 : src_y = y : If y >= mirror_pos : src_y = 2 * mirror_pos - y : EndIf
            ElseIf keep_side = 1 : src_y = y : If y <= mirror_pos : src_y = 2 * mirror_pos - y : EndIf
            Else : src_y = y : distance_to_axis = Abs(y - mirror_pos) : max_distance = mirror_pos : EndIf

          Case 2 ; ===== Diagonale / =====
            If keep_side = 0 : If y < x : src_x = x : src_y = y : Else : src_x = y : src_y = x : EndIf
            Else : If y > x : src_x = x : src_y = y : Else : src_x = y : src_y = x : EndIf : EndIf

          Case 3 ; ===== Diagonale \ =====
            If keep_side = 0 : If y < (ht - x) : src_x = x : src_y = y : Else : src_x = ht - y : src_y = lg - x : EndIf
            Else : If y > (ht - x) : src_x = x : src_y = y : Else : src_x = ht - y : src_y = lg - x : EndIf : EndIf
        EndSelect

        ; Échantillonnage et gestion du fondu (Mode Mixte)
        If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
          offset_src = (src_y * lg + src_x) * 4
          
          If keep_side = 2 And (axis_type = 0 Or axis_type = 1) And fade_amount > 0
            ; Logique de mélange pour effet de transparence à l'axe
            Protected mirror_coord.i
            If axis_type = 0 : mirror_coord = 2 * mirror_pos - x : Else : mirror_coord = 2 * mirror_pos - y : EndIf
            
            If mirror_coord >= 0 And ((axis_type=0 And mirror_coord < lg) Or (axis_type=1 And mirror_coord < ht))
              Protected offset_mirror.i
              If axis_type = 0 : offset_mirror = (y * lg + mirror_coord) * 4 : Else : offset_mirror = (mirror_coord * lg + x) * 4 : EndIf
              
              pixel_src = PeekL(*source + offset_src)
              pixel_mirror = PeekL(*source + offset_mirror)
              
              fade_factor = 1.0 - ((distance_to_axis / max_distance) * fade_amount)
              If fade_factor < 0 : fade_factor = 0 : ElseIf fade_factor > 1 : fade_factor = 1 : EndIf
              
              ; Mixage linéaire ARGB
              a1 = (pixel_src >> 24) & $FF : r1 = (pixel_src >> 16) & $FF : g1 = (pixel_src >> 8) & $FF : b1 = pixel_src & $FF
              a2 = (pixel_mirror >> 24) & $FF : r2 = (pixel_mirror >> 16) & $FF : g2 = (pixel_mirror >> 8) & $FF : b2 = pixel_mirror & $FF
              
              a = a1 * fade_factor + a2 * (1.0 - fade_factor)
              r = r1 * fade_factor + r2 * (1.0 - fade_factor)
              g = g1 * fade_factor + g2 * (1.0 - fade_factor)
              b = b1 * fade_factor + b2 * (1.0 - fade_factor)
              
              PokeL(*cible + offset_dst, (a << 24) | (r << 16) | (g << 8) | b)
            Else
              PokeL(*cible + offset_dst, PeekL(*source + offset_src))
            EndIf
          Else
            PokeL(*cible + offset_dst, PeekL(*source + offset_src))
          EndIf
        Else
          PokeL(*cible + offset_dst, $00000000)
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure MirrorEx(*FilterCtx.FilterParams)
  Restore Mirror_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Mirror_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Mirror(source, cible, mask, axis=0, pos=50, side=0, fade=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = axis ; 0-3
    \option[1] = pos  ; 0-100%
    \option[2] = side ; 0-2
    \option[3] = fade ; 0-100
  EndWith
  MirrorEx(FilterCtx)
EndProcedure

DataSection
  Mirror_Data:
  Data.s "Mirror"
  Data.s "Effet miroir avec symétrie axiale (Verticale, Horizontale ou Diagonale)"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Axe (0:V, 1:H, 2:/, 3:\)" : Data.i 0, 3, 0
  Data.s "Position axe (%)"         : Data.i 0, 100, 50
  Data.s "Côté (0:G/H, 1:D/B, 2:M)" : Data.i 0, 2, 0
  Data.s "Fondu (%)"                : Data.i 0, 100, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 118
; FirstLine = 90
; Folding = -
; EnableXP
; DPIAware