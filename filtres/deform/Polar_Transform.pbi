; ==============================================================================
; FILTRE POLAR TRANSFORM (CARTÉSIEN <-> POLAIRE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure PolarTransform_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Configuration et Précalculs ---
    Protected mode.i = \option[0]       ; 0=Cart->Polar, 1=Polar->Cart
    Protected cx.f = (\option[1] / 100.0) * lg
    Protected cy.f = (\option[2] / 100.0) * ht
    Protected start_angle.f = (\option[3] / 360.0) * #PI * 2.0
    Protected wrap_mode.i = \option[4]  ; 0=Noir, 1=Wrap

    Protected diagonale.f = Sqr(lg * lg + ht * ht)
    Protected max_radius.f = diagonale * 0.5
    Protected inv_max_radius.f = 1.0 / max_radius
    Protected inv_lg.f = 1.0 / lg
    Protected inv_ht.f = 1.0 / ht
    Protected two_pi.f = #PI * 2.0

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i
    Protected r.f, theta.f, dx.f, dy.f

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        
        If mode = 0
          ; ===== MODE CARTÉSIEN -> POLAIRE (Déroulement) =====
          dx = x - cx
          dy = y - cy
          r = Sqr(dx * dx + dy * dy)
          theta = ATan2(dy, dx) + start_angle
          
          ; Normalisation de l'angle
          While theta < 0 : theta + two_pi : Wend
          While theta >= two_pi : theta - two_pi : Wend
          
          src_x = (theta / two_pi) * lg
          src_y = (r * inv_max_radius) * ht
          
        Else
          ; ===== MODE POLAIRE -> CARTÉSIEN (Enroulement) =====
          theta = (x * inv_lg) * two_pi + start_angle
          r = (y * inv_ht) * max_radius
          
          src_x = cx + r * Cos(theta)
          src_y = cy + r * Sin(theta)
        EndIf

        src_x_int = Int(src_x)
        src_y_int = Int(src_y)

        ; Gestion des limites et de l'échantillonnage
        If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
          offset_src = (src_y_int * lg + src_x_int) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        ElseIf wrap_mode
          ; Bouclage horizontal (continuité de l'angle)
          src_x_int = (src_x_int % lg + lg) % lg
          If src_y_int >= 0 And src_y_int < ht
            offset_src = (src_y_int * lg + src_x_int) * 4
            PokeL(*cible + offset_dst, PeekL(*source + offset_src))
          Else
            PokeL(*cible + offset_dst, $00000000)
          EndIf
        Else
          PokeL(*cible + offset_dst, $00000000)
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure PolarTransformEx(*FilterCtx.FilterParams)
  Restore Polar_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@PolarTransform_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure PolarTransform(source, cible, mask, mode=0, posX=50, posY=50, angle=0, wrap=1)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = mode  ; 0: Déroule, 1: Enroule
    \option[1] = posX  ; Centre X (%)
    \option[2] = posY  ; Centre Y (%)
    \option[3] = angle ; Rotation (0-360°)
    \option[4] = wrap  ; 0: Noir, 1: Wrap
  EndWith
  PolarTransformEx(FilterCtx)
EndProcedure

DataSection
  Polar_Data:
  Data.s "Polar Transform"
  Data.s "Conversion Cartésien <-> Polaire (Déroulement / Enroulement circulaire)"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Mode (0:Déroule, 1:Enroule)" : Data.i 0, 1, 0
  Data.s "Centre X (%)"                : Data.i 0, 100, 50
  Data.s "Centre Y (%)"                : Data.i 0, 100, 50
  Data.s "Angle de départ (°)"         : Data.i 0, 360, 0
  Data.s "Remplissage (0:Noir, 1:Wrap)": Data.i 0, 1, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 102
; FirstLine = 76
; Folding = -
; EnableXP
; DPIAware