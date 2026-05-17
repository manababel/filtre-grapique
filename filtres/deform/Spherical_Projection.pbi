; ==============================================================================
; FILTRE SPHERICAL PROJECTION - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure SphericalProjection_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Configuration et Précalculs ---
    Protected proj_type.i = \option[0]
    Protected cx.f = ((\option[1] / 100.0) * lg)
    Protected cy.f = ((\option[2] / 100.0) * ht)
    
    Protected fov.f = ((\option[3] / 180.0) * #PI)
    If fov < 0.1 : fov = 0.1 : EndIf
    If fov > #PI : fov = #PI : EndIf

    Protected rotation.f = ((\option[4] / 360.0) * 2.0 * #PI)
    Protected max_radius.f = (Sqr(lg * lg + ht * ht) * 0.5)

    ; --- Configuration Multithreading ---
    Protected startY.i = ((\thread_pos * ht) / \thread_max)
    Protected stopY.i  = (((\thread_pos + 1) * ht) / \thread_max - 1)
    If stopY > (ht - 1) : stopY = (ht - 1) : EndIf

    ; Variables de calcul
    Protected offset_dst.i, offset_src.i
    Protected dx.f, dy.f, r.f
    Protected theta.f, phi.f
    Protected nx.f, ny.f, nz.f
    Protected u.f, v.f
    Protected denom.f, angular_dist.f, sin_c.f, cos_c.f
    Protected tan_dist.f, dist_factor.f, mercator_y.f

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = (y * lg * 4)

      For x = 0 To (lg - 1)
        dx = ((x - cx) / max_radius)
        dy = ((y - cy) / max_radius)
        r = Sqr((dx * dx) + (dy * dy))

        Select proj_type
          Case 0  ; ===== Équirectangulaire (lat/long) =====
            u = ((x / lg) * 2.0 * #PI + rotation)
            v = ((y / ht) * #PI)
            phi = (v - (#PI * 0.5))
            theta = u
            nx = (Cos(phi) * Cos(theta))
            ny = Sin(phi)
            nz = (Cos(phi) * Sin(theta))
            
            If nz > -0.99
              src_x = (cx + (nx / (1.0 + nz)) * max_radius * (fov / #PI))
              src_y = (cy + (ny / (1.0 + nz)) * max_radius * (fov / #PI))
            Else
              src_x = x : src_y = y
            EndIf

          Case 1  ; ===== Stéréographique =====
            If r < 2.0
              denom = (1.0 + (r * r * 0.25))
              nx = (dx / denom)
              ny = (dy / denom)
              nz = ((1.0 - (r * r * 0.25)) / denom)
              phi = ASin(ny)
              theta = (ATan2(nz, nx) + rotation)
              src_x = (((theta / (2.0 * #PI)) + 0.5) * lg)
              src_y = (((phi / #PI) + 0.5) * ht)
            Else
              src_x = x : src_y = y
            EndIf

          Case 2  ; ===== Orthographique (Vue Satellite) =====
            If r <= 1.0
              nz = Sqr(1.0 - (r * r))
              nx = dx : ny = dy
              phi = ASin(ny)
              theta = (ATan2(nz, nx) + rotation)
              src_x = (((theta / (2.0 * #PI)) + 0.5) * lg)
              src_y = (((phi / #PI) + 0.5) * ht)
            Else
              src_x = x : src_y = y
            EndIf

          Case 3  ; ===== Azimuthale équidistante =====
            angular_dist = (r * fov * 0.5)
            If r > 0.001 And angular_dist < #PI
              sin_c = Sin(angular_dist)
              cos_c = Cos(angular_dist)
              phi = ASin((cos_c * Sin(dy)) + ((dy * sin_c * Cos(dy)) / r))
              theta = (ATan2((dx * sin_c), (r * Cos(dy) * cos_c - dy * Sin(dy) * sin_c)) + rotation)
              src_x = (((theta / (2.0 * #PI)) + 0.5) * lg)
              src_y = (((phi / #PI) + 0.5) * ht)
            Else
              src_x = x : src_y = y
            EndIf

          Case 4  ; ===== Gnomonic (Lignes droites) =====
            tan_dist = (r * Tan(fov * 0.5))
            If tan_dist < 10.0 And r > 0.001
              dist_factor = ATan(tan_dist)
              nx = ((dx / r) * Sin(dist_factor))
              ny = ((dy / r) * Sin(dist_factor))
              nz = Cos(dist_factor)
              phi = ASin(ny)
              theta = (ATan2(nz, nx) + rotation)
              src_x = (((theta / (2.0 * #PI)) + 0.5) * lg)
              src_y = (((phi / #PI) + 0.5) * ht)
            Else
              src_x = x : src_y = y
            EndIf

          Case 5  ; ===== Mercator (Navigation) =====
            u = ((x / lg) * 2.0 * #PI + rotation)
            mercator_y = (((y - cy) / max_radius) * fov)
            If Abs(mercator_y) < 3.0
              phi = (2.0 * ATan(Exp(mercator_y)) - (#PI * 0.5))
              theta = u
              src_x = (((theta / (2.0 * #PI)) + 0.5) * lg)
              src_y = (((phi / #PI) + 0.5) * ht)
            Else
              src_x = x : src_y = y
            EndIf
        EndSelect

        ; Wrap horizontal (longitude)
        While src_x < 0 : src_x + lg : Wend
        While src_x >= lg : src_x - lg : Wend

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

Procedure SphericalProjectionEx(*FilterCtx.FilterParams)
  Restore SphericalProjection_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@SphericalProjection_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure SphericalProjection(source, cible, mask, type=0, posX=50, posY=50, fov=90, rotation=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = type
    \option[1] = posX
    \option[2] = posY
    \option[3] = fov
    \option[4] = rotation
  EndWith
  SphericalProjectionEx(FilterCtx)
EndProcedure

DataSection
  SphericalProjection_Data:
  Data.s "Projection Sphérique"
  Data.s "Conversion entre images planes et mappings sphériques (VR/360)"
  Data.i #FilterType_Deformation, 0
  Data.s "Type (0:Equi, 1:Stér, 2:Orth, 3:Azim, 4:Gnom, 5:Merc)" : Data.i 0, 5, 0
  Data.s "Centre X (%)" : Data.i 0, 100, 50
  Data.s "Centre Y (%)" : Data.i 0, 100, 50
  Data.s "FOV (degrés)" : Data.i 10, 180, 90
  Data.s "Rotation (degrés)" : Data.i 0, 360, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 164
; FirstLine = 138
; Folding = -
; EnableXP
; DPIAware