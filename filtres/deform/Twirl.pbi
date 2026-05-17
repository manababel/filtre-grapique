; ==============================================================================
; FILTRE TWIRL (TOURBILLON) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Twirl_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected dx.f, dy.f, r.f
    Protected normalized_r.f, rotation_factor.f, rotation_angle.f
    Protected current_angle.f, new_angle.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs des constantes de l'effet ---
    Protected cx.f = (\option[1] / 100.0) * lg
    Protected cy.f = (\option[2] / 100.0) * ht

    ; Rayon d'effet basé sur la diagonale
    Protected diagonale.f = Sqr(lg * lg + ht * ht)
    Protected rayon.f = (diagonale * \option[3] / 100.0) + 1.0
    Protected inv_rayon.f = 1.0 / rayon 

    ; Angle max en radians (1000 = neutre, plage ±180°)
    Protected angle_max.f = (\option[0] - 1000.0) * #PI / 180.0

    ; Courbe d'atténuation (falloff)
    Protected attenuation.f = \option[4] / 100.0
    Protected falloff_power.f = 1.0 + attenuation * 3.0 

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        dx = x - cx
        dy = y - cy
        r = Sqr(dx * dx + dy * dy)

        If r <= rayon
          ; Normalisation (0 centre -> 1 bord)
          normalized_r = r * inv_rayon

          ; Facteur de torsion avec courbe de puissance
          rotation_factor = 1.0 - Pow(normalized_r, falloff_power)
          rotation_angle = angle_max * rotation_factor

          ; Passage en polaire -> Rotation -> Retour en cartésien
          current_angle = ATan2(dy, dx)
          new_angle = current_angle + rotation_angle

          src_x = cx + r * Cos(new_angle)
          src_y = cy + r * Sin(new_angle)
        Else
          ; Hors rayon : pas de déformation
          src_x = x
          src_y = y
        EndIf

        src_x_int = Int(src_x)
        src_y_int = Int(src_y)

        ; Échantillonnage avec protection des bords
        If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
          offset_src = (src_y_int * lg + src_x_int) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $00000000) ; Transparent
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure TwirlEx(*FilterCtx.FilterParams)
  Restore Twirl_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Twirl_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Twirl(source, cible, mask, angle=1000, posX=50, posY=50, radius=50, falloff=50)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = angle    ; Rotation max (0-2000)
    \option[1] = posX     ; Centre X (%)
    \option[2] = posY     ; Centre Y (%)
    \option[3] = radius   ; Rayon (%)
    \option[4] = falloff  ; Atténuation (0-100)
  EndWith
  TwirlEx(FilterCtx)
EndProcedure

DataSection
  Twirl_Data:
  Data.s "Twirl"
  Data.s "Rotation progressive du centre vers les bords avec atténuation"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Angle Max (±180°)" : Data.i 0, 2000, 1000
  Data.s "Position X (%)"    : Data.i 0, 100, 50
  Data.s "Position Y (%)"    : Data.i 0, 100, 50
  Data.s "Rayon (%)"         : Data.i 0, 100, 50
  Data.s "Atténuation (%)"   : Data.i 0, 100, 50
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 97
; FirstLine = 71
; Folding = -
; EnableXP
; DPIAware