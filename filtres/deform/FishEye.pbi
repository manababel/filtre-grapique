; ==============================================================================
; FILTRE FISH-EYE (ULTRA GRAND-ANGLE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure FishEye_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected dx.f, dy.f, r.f
    Protected normalized_r.f, theta.f, mapped_r.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs des constantes ---
    Protected cx.f = (\option[1] / 100.0) * lg
    Protected cy.f = (\option[2] / 100.0) * ht

    ; Rayon d'effet basé sur la diagonale
    Protected diagonale.f = Sqr(lg * lg + ht * ht)
    Protected rayon.f = (diagonale * \option[3] / 100.0) + 1.0
    Protected inv_rayon.f = 1.0 / rayon

    ; Intensité (100 = neutre, <100 = défisheye, >100 = distorsion)
    Protected intensity.f = (\option[0] - 100.0) / 100.0
    Protected projection_type.i = \option[4]

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i
    Protected inv_r.f

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        dx = x - cx
        dy = y - cy
        r = Sqr(dx * dx + dy * dy)

        If r <= rayon And r > 0.001
          normalized_r = r * inv_rayon
          theta = normalized_r * #PI * 0.5 ; Angle d'incidence (90° max)

          ; Modèles de projection
          Select projection_type
            Case 0 ; Stéréographique (Naturel) : r' = 2 * tan(θ/2)
              mapped_r = 2.0 * Tan(theta * 0.5)
            Case 1 ; Équidistante (Linéaire) : r' = θ
              mapped_r = theta
            Case 2 ; Orthographique (Hémisphérique) : r' = sin(θ)
              mapped_r = Sin(theta)
          EndSelect

          ; Interpolation entre r linéaire et r projeté selon l'intensité
          mapped_r = normalized_r + (mapped_r - normalized_r) * intensity
          mapped_r * rayon ; Retour à l'échelle absolue

          ; Projection inverse vers la source
          inv_r = 1.0 / r
          src_x = cx + dx * inv_r * mapped_r
          src_y = cy + dy * inv_r * mapped_r
        Else
          src_x = x
          src_y = y
        EndIf

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

Procedure FishEyeEx(*FilterCtx.FilterParams)
  Restore FishEye_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@FishEye_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure FishEye(source, cible, mask, intensity=100, posX=50, posY=50, radius=70, type=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensity ; Intensité (0-200)
    \option[1] = posX      ; Centre X (%)
    \option[2] = posY      ; Centre Y (%)
    \option[3] = radius    ; Rayon d'action (%)
    \option[4] = type      ; Type (0:Stéréo, 1:Équi, 2:Ortho)
  EndWith
  FishEyeEx(FilterCtx)
EndProcedure

DataSection
  FishEye_Data:
  Data.s "FishEye"
  Data.s "Simule un objectif ultra grand-angle avec projections sphériques"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Intensité (%)"      : Data.i 0, 200, 100
  Data.s "Centre X (%)"       : Data.i 0, 100, 50
  Data.s "Centre Y (%)"       : Data.i 0, 100, 50
  Data.s "Rayon d'action (%)" : Data.i 0, 100, 70
  Data.s "Projection (0-2)"   : Data.i 0, 2, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 101
; FirstLine = 75
; Folding = -
; EnableXP
; DPIAware