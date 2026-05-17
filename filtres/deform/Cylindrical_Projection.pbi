; ==============================================================================
; FILTRE CYLINDRICAL PROJECTION - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure CylindricalProjection_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Configuration et Précalculs ---
    Protected direction.i = \option[0]
    Protected curvature.f = ((\option[1] - 100.0) / 100.0)
    Protected center_pos.f = (\option[2] / 100.0)
    Protected radius_percent.f = (\option[3] / 100.0)
    If radius_percent < 0.1 : radius_percent = 0.1 : EndIf
    Protected mode.i = \option[4]

    ; --- Configuration Multithreading ---
    Protected startY.i = ((\thread_pos * ht) / \thread_max)
    Protected stopY.i  = (((\thread_pos + 1) * ht) / \thread_max - 1)
    If stopY > (ht - 1) : stopY = (ht - 1) : EndIf

    ; Variables de calcul
    Protected pos.f, normalized_pos.f
    Protected theta.f, radius.f
    Protected projected_pos.f
    Protected dimension.i, center.f
    Protected offset_dst.i, offset_src.i

    ; Calcul du rayon et du centre selon la direction
    If direction = 0  ; Horizontal (Cylindre vertical)
      dimension = lg
      center = (center_pos * lg)
      radius = ((lg * radius_percent) / #PI)
    Else              ; Vertical (Cylindre horizontal)
      dimension = ht
      center = (center_pos * ht)
      radius = ((ht * radius_percent) / #PI)
    EndIf

    If radius < 1.0 : radius = 1.0 : EndIf

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = (y * lg * 4)

      For x = 0 To (lg - 1)
        
        If direction = 0
          pos = x
        Else
          pos = y
        EndIf

        Select mode
          Case 0, 1  ; ===== Mode Normal / Inverse (Wrap) =====
            normalized_pos = ((pos - center) / radius)
            
            If curvature >= 0  ; Convexe
              theta = (normalized_pos * curvature)
              If Abs(theta) < (#PI / 2.0)
                projected_pos = (radius * Sin(theta))
              Else
                projected_pos = (normalized_pos * radius)
              EndIf
            Else               ; Concave
              theta = (normalized_pos / radius)
              If Abs(theta) < 1.0
                projected_pos = ((radius * ASin(theta)) / Abs(curvature))
              Else
                projected_pos = (normalized_pos * radius)
              EndIf
            EndIf
            
          Case 2     ; ===== Panorama → Plat (Déroulement) =====
            normalized_pos = ((pos - center) / (dimension * 0.5))
            theta = (normalized_pos * #PI * 0.5)
            projected_pos = (radius * Tan(theta))
            
          Case 3     ; ===== Plat → Panorama (Enroulement) =====
            normalized_pos = ((pos - center) / radius)
            If Abs(normalized_pos) < 10.0
              theta = ATan(normalized_pos)
              projected_pos = ((theta / (#PI * 0.5)) * (dimension * 0.5))
            Else
              projected_pos = (normalized_pos * radius)
            EndIf
        EndSelect

        ; Reconstruction des coordonnées source
        If direction = 0
          src_x = (center + projected_pos)
          src_y = y
        Else
          src_x = x
          src_y = (center + projected_pos)
        EndIf

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

Procedure CylindricalProjectionEx(*FilterCtx.FilterParams)
  Restore CylindricalProjection_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@CylindricalProjection_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure CylindricalProjection(source, cible, mask, direction=0, curvature=100, center=50, radius=50, mode=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = direction
    \option[1] = curvature
    \option[2] = center
    \option[3] = radius
    \option[4] = mode
  EndWith
  CylindricalProjectionEx(FilterCtx)
EndProcedure

DataSection
  CylindricalProjection_Data:
  Data.s "Projection Cylindrique"
  Data.s "Enroulement/déroulement sur cylindre et conversion panorama"
  Data.i #FilterType_Deformation, 0
  Data.s "Direction (0:Horiz, 1:Vert)" : Data.i 0, 1, 0
  Data.s "Courbure (0:Conc, 100:Plat, 200:Conv)" : Data.i 0, 200, 100
  Data.s "Position centre (%)" : Data.i 0, 100, 50
  Data.s "Rayon effectif (%)" : Data.i 0, 100, 50
  Data.s "Mode (0:Norm, 1:Inv, 2:P→F, 3:F→P)" : Data.i 0, 3, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 130
; FirstLine = 104
; Folding = -
; EnableXP
; DPIAware