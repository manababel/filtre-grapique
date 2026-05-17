; ==============================================================================
; FILTRE SPIRALIZE (SPIRALE / VORTEX) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Spiralize_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected dx.f, dy.f, r.f
    Protected a.f, new_a.f, rotation_angle.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs du centre et du rayon ---
    Protected cx.f = (\option[1] / 100.0) * lg
    Protected cy.f = (\option[2] / 100.0) * ht

    ; Rayon basé sur la diagonale
    Protected diagonale.f = Sqr(lg * lg + ht * ht)
    Protected rayon.f = (diagonale * \option[3] / 100.0) + 1.0
    Protected inv_rayon.f = 1.0 / rayon

    ; Précalcul de l'angle max en radians (±180°)
    Protected angle_max.f = (\option[0] - 1000.0) * #PI / 180.0
    
    ; Sens de rotation (0 = horaire, 1 = anti-horaire)
    Protected sens.i = \option[4]

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
          ; Angle polaire actuel
          a = ATan2(dy, dx)

          ; La rotation s'atténue linéairement vers le bord du rayon
          rotation_angle = angle_max * (1.0 - r * inv_rayon)

          If sens
            new_a = a + rotation_angle ; Anti-horaire
          Else
            new_a = a - rotation_angle ; Horaire
          EndIf

          ; Retour aux coordonnées cartésiennes
          src_x = cx + r * Cos(new_a)
          src_y = cy + r * Sin(new_a)
        Else
          ; Hors zone : identité
          src_x = x
          src_y = y
        EndIf

        src_x_int = Int(src_x)
        src_y_int = Int(src_y)

        If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
          offset_src = (src_y_int * lg + src_x_int) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $00000000) ; Vide
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure SpiralizeEx(*FilterCtx.FilterParams)
  Restore Spiralize_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Spiralize_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Spiralize(source, cible, mask, angle=1000, cX=50, cY=50, rayon=50, sens=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = angle ; 0-2000
    \option[1] = cX    ; 0-100%
    \option[2] = cY    ; 0-100%
    \option[3] = rayon ; 0-100%
    \option[4] = sens  ; 0/1
  EndWith
  SpiralizeEx(FilterCtx)
EndProcedure

DataSection
  Spiralize_Data:
  Data.s "Spiralize"
  Data.s "Déformation en spirale (vortex) avec rotation progressive"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Angle (1000=Neutre)" : Data.i 0, 2000, 1000
  Data.s "Centre X (%)"        : Data.i 0, 100, 50
  Data.s "Centre Y (%)"        : Data.i 0, 100, 50
  Data.s "Rayon (%)"           : Data.i 0, 100, 50
  Data.s "Sens (0=H, 1=AH)"    : Data.i 0, 1, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 96
; FirstLine = 70
; Folding = -
; EnableXP
; DPIAware