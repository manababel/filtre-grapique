; ==============================================================================
; FILTRE KALEIDOSCOPE - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Kaleidoscope2_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected dx.f, dy.f, r.f, theta.f
    Protected sector_angle.f, reflected_angle.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Configuration et Précalculs ---
    Protected segments.i = \option[0]
    If segments < 2 : segments = 2 : EndIf
    
    Protected cx.f = (\option[1] / 100.0) * lg
    Protected cy.f = (\option[2] / 100.0) * ht
    Protected rotation.f = (\option[3] / 360.0) * #PI * 2.0
    Protected mirror_mode.i = \option[4] ; 0:Simple, 1:Double (V-Mirror)

    Protected two_pi.f = #PI * 2.0
    Protected sector_size.f = two_pi / segments
    Protected half_sector.f = sector_size * 0.5

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i
    Protected sector_index.i
    Protected angle_in_sector.f

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        dx = x - cx
        dy = y - cy

        ; Conversion Polaire
        r = Sqr(dx * dx + dy * dy)
        theta = ATan2(dy, dx) + rotation

        ; Normalisation de l'angle [0, 2PI]
        theta = theta - (two_pi * (theta / two_pi))

        ; Calcul de la position dans le secteur
        sector_index = Int(theta / sector_size)
        angle_in_sector = theta - (sector_index * sector_size)

        ; Application de la symétrie
        If mirror_mode = 0
          ; Mode Simple : Inverse un secteur sur deux
          If sector_index % 2 = 1
            reflected_angle = sector_size - angle_in_sector
          Else
            reflected_angle = angle_in_sector
          EndIf
        Else
          ; Mode Double : Symétrie en V au sein de chaque secteur
          If angle_in_sector > half_sector
            reflected_angle = sector_size - angle_in_sector
          Else
            reflected_angle = angle_in_sector
          EndIf
        EndIf

        ; Retour aux coordonnées cartésiennes de la source
        src_x = cx + r * Cos(reflected_angle - rotation)
        src_y = cy + r * Sin(reflected_angle - rotation)

        src_x_int = Int(src_x)
        src_y_int = Int(src_y)

        ; Échantillonnage
        If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
          offset_src = (src_y_int * lg + src_x_int) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $00000000)
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure Kaleidoscope2Ex(*FilterCtx.FilterParams)
  Restore Kaleidoscope2_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Kaleidoscope2_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Kaleidoscope2(source, cible, mask, segments=6, posX=50, posY=50, angle=0, mode=1)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = segments ; Nombre de miroirs radiaux
    \option[1] = posX     ; Centre X (%)
    \option[2] = posY     ; Centre Y (%)
    \option[3] = angle    ; Rotation globale (°)
    \option[4] = mode     ; 0: Simple, 1: Double (V)
  EndWith
  KaleidoscopeEx(FilterCtx)
EndProcedure

DataSection
  Kaleidoscope2_Data:
  Data.s "Kaleidoscope (marche pas)"
  Data.s "Effet de miroirs radiaux créant des motifs symétriques complexes"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Segments (miroirs)"  : Data.i 2, 32, 6
  Data.s "Centre X (%)"        : Data.i 0, 100, 50
  Data.s "Centre Y (%)"        : Data.i 0, 100, 50
  Data.s "Rotation (°)"        : Data.i 0, 360, 0
  Data.s "Mode (0:Simp, 1:Dbl)": Data.i 0, 1, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 122
; FirstLine = 80
; Folding = -
; EnableXP
; DPIAware