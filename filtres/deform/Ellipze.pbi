; ==============================================================================
; FILTRE ELLIPZE (DÉFORMATION ELLIPTIQUE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Ellipse_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected dx.f, dy.f, r.f
    Protected facteur.f, sqrt_r.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs du centre et des rayons ---
    Protected cx.f = (\option[1] / 100.0) * lg
    Protected cy.f = (\option[2] / 100.0) * ht

    ; Rayons indépendants en X et Y
    Protected rayon_x.f = (lg * \option[3] / 100.0) + 10.0
    Protected rayon_y.f = (ht * \option[4] / 100.0) + 10.0

    ; Précalcul des inverses pour éviter les divisions dans la boucle
    Protected inv_rayon_x.f = 1.0 / rayon_x
    Protected inv_rayon_y.f = 1.0 / rayon_y

    ; Force centrée sur 200 (0-199: concave, 200: neutre, 201-600: convexe)
    Protected force.f = (\option[0] - 200.0) / 100.0

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        ; Position relative au centre, normalisée par les rayons respectifs
        dx = (x - cx) * inv_rayon_x
        dy = (y - cy) * inv_rayon_y

        ; Distance normalisée au carré (r²)
        r = dx * dx + dy * dy

        ; Application de la déformation seulement si on est dans l'ellipse (r² <= 1.0)
        If r <= 1.0
          sqrt_r = Sqr(r)
          
          ; Interpolation via Sinus pour une transition douce
          facteur = Pow(Sin(sqrt_r * #PI * 0.5), 1.0 + force)
          
          src_x = cx + (dx * rayon_x) * facteur
          src_y = cy + (dy * rayon_y) * facteur
        Else
          ; Identité hors zone
          src_x = x
          src_y = y
        EndIf

        src_x_int = Int(src_x)
        src_y_int = Int(src_y)

        If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
          offset_src = (src_y_int * lg + src_x_int) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $00000000) ; Noir transparent
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure EllipzeEx(*FilterCtx.FilterParams)
  Restore Ellipze_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Ellipse_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Ellipze(source, cible, mask, force=200, cX=50, cY=50, rayonX=50, rayonY=50)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = force  ; 0-600 (200=Neutre)
    \option[1] = cX     ; 0-100%
    \option[2] = cY     ; 0-100%
    \option[3] = rayonX ; 0-100%
    \option[4] = rayonY ; 0-100%
  EndWith
  EllipzeEx(FilterCtx)
EndProcedure

DataSection
  Ellipze_Data:
  Data.s "Ellipze"
  Data.s "Déformation elliptique simulant une lentille ovale réglable"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Force (200=Neutre)" : Data.i 0, 600, 200
  Data.s "Centre X (%)"       : Data.i 0, 100, 50
  Data.s "Centre Y (%)"       : Data.i 0, 100, 50
  Data.s "Rayon X (%)"        : Data.i 0, 100, 50
  Data.s "Rayon Y (%)"        : Data.i 0, 100, 50
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 92
; FirstLine = 66
; Folding = -
; EnableXP
; DPIAware