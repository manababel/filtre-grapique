; ==============================================================================
; FILTRE LIQUIFY (LIQUIDIFICATION) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Liquify_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected dx.f, dy.f, distance.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Configuration et Précalculs ---
    Protected radius.f = \option[0]
    If radius < 5.0 : radius = 5.0 : EndIf
    If radius > 200.0 : radius = 200.0 : EndIf
    
    Protected radius_sq.f = (radius * radius)
    Protected inv_radius.f = (1.0 / radius)
    Protected intensity.f = (\option[1] / 100.0)
    
    Protected cx.f = ((\option[2] / 100.0) * lg)
    Protected cy.f = ((\option[3] / 100.0) * ht)
    Protected mode.i = \option[4]

    ; --- Configuration Multithreading ---
    Protected startY.i = ((\thread_pos * ht) / \thread_max)
    Protected stopY.i  = (((\thread_pos + 1) * ht) / \thread_max - 1)
    If stopY > (ht - 1) : stopY = (ht - 1) : EndIf

    Protected offset_dst.i, offset_src.i
    Protected normalized_dist.f, strength.f
    Protected angle.f, rotation_angle.f
    Protected offset_x.f, offset_y.f
    Protected distance_sq.f
    Protected factor.f

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = (y * lg * 4)

      For x = 0 To (lg - 1)
        dx = (x - cx)
        dy = (y - cy)
        distance_sq = ((dx * dx) + (dy * dy))

        ; Test de proximité pour optimisation
        If distance_sq > radius_sq
          offset_src = ((y * lg + x) * 4)
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
          offset_dst + 4
          Continue
        EndIf

        distance = Sqr(distance_sq)
        normalized_dist = (distance * inv_radius)
        
        ; Atténuation douce (Courbe Cosinus)
        strength = ((Cos(normalized_dist * #PI) + 1.0) * 0.5 * intensity)

        Select mode
          Case 0  ; ===== Push (Pousser) =====
            If distance > 0.001
              offset_x = ((dx / distance) * strength * radius * 0.5)
              offset_y = ((dy / distance) * strength * radius * 0.5)
            Else
              offset_x = 0 : offset_y = 0
            EndIf
            src_x = (x - offset_x)
            src_y = (y - offset_y)

          Case 1  ; ===== Pull (Tirer) =====
            If distance > 0.001
              offset_x = ((dx / distance) * strength * radius * 0.5)
              offset_y = ((dy / distance) * strength * radius * 0.5)
            Else
              offset_x = 0 : offset_y = 0
            EndIf
            src_x = (x + offset_x)
            src_y = (y + offset_y)

          Case 2  ; ===== Twirl CW (Tourbillon horaire) =====
            If distance > 0.001
              angle = ATan2(dy, dx)
              rotation_angle = (strength * #PI * 0.5)
              angle = (angle - rotation_angle)
              src_x = (cx + (distance * Cos(angle)))
              src_y = (cy + (distance * Sin(angle)))
            Else
              src_x = x : src_y = y
            EndIf

          Case 3  ; ===== Twirl CCW (Tourbillon anti-horaire) =====
            If distance > 0.001
              angle = ATan2(dy, dx)
              rotation_angle = (strength * #PI * 0.5)
              angle = (angle + rotation_angle)
              src_x = (cx + (distance * Cos(angle)))
              src_y = (cy + (distance * Sin(angle)))
            Else
              src_x = x : src_y = y
            EndIf

          Case 4  ; ===== Bloat (Gonfler) =====
            If distance > 0.001
              factor = (1.0 - (strength * 0.5))
              src_x = (cx + (dx * factor))
              src_y = (cy + (dy * factor))
            Else
              src_x = x : src_y = y
            EndIf

          Case 5  ; ===== Pinch (Pincer) =====
            If distance > 0.001
              factor = (1.0 + (strength * 0.5))
              src_x = (cx + (dx * factor))
              src_y = (cy + (dy * factor))
            Else
              src_x = x : src_y = y
            EndIf
        EndSelect

        src_x_int = Int(src_x)
        src_y_int = Int(src_y)

        If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
          offset_src = ((src_y_int * lg + src_x_int) * 4)
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          ; Protection : Si hors limites, on garde le pixel d'origine
          offset_src = ((y * lg + x) * 4)
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure LiquifyEx(*FilterCtx.FilterParams)
  Restore Liquify_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Liquify_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Liquify(source, cible, mask, radius=50, intensity=50, posX=50, posY=50, mode=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = intensity
    \option[2] = posX
    \option[3] = posY
    \option[4] = mode
  EndWith
  LiquifyEx(FilterCtx)
EndProcedure

DataSection
  Liquify_Data:
  Data.s "Liquify (Liquidification) ( a modifier)"
  Data.s "Déformation locale interactive avec atténuation cosusoïdale"
  Data.i #FilterType_Deformation, 0
  Data.s "Rayon pinceau (px)" : Data.i 5, 200, 50
  Data.s "Intensité (force)" : Data.i 0, 100, 50
  Data.s "Position X (%)" : Data.i 0, 100, 50
  Data.s "Position Y (%)" : Data.i 0, 100, 50
  Data.s "Mode (0:Psh, 1:Pll, 2:Tw↻, 3:Tw↺, 4:Blo, 5:Pin)" : Data.i 0, 5, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 170
; FirstLine = 128
; Folding = -
; EnableXP
; DPIAware