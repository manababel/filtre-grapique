; ==============================================================================
; FILTRE SPHERIZE (SPHÉRISATION / EFFET LENTILLE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Spherize_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected dx.f, dy.f, r.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs de la zone d'effet ---
    Protected cx.f = (\option[1] / 100.0) * lg
    Protected cy.f = (\option[2] / 100.0) * ht

    ; Rayon basé sur la diagonale pour une couverture totale possible
    Protected diagonale.f = Sqr(lg * lg + ht * ht)
    Protected rayon.f = (diagonale * \option[3] / 100.0) + 1.0
    Protected inv_rayon.f = 1.0 / rayon 

    ; Normalisation de la force (0.0 = neutre)
    Protected force.f = (\option[0] - 100.0) / 100.0

    ; --- Configuration Multithreading (macro_calcul_thread) ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected angle.f, facteur.f
    Protected offset_dst.i, offset_src.i

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        ; Position relative au centre (normalisée 0.0 -> 1.0)
        dx = (x - cx) * inv_rayon
        dy = (y - cy) * inv_rayon
        r = Sqr(dx * dx + dy * dy)

        If r <= 1.0
          ; Algorithme de distorsion sphérique
          angle = r * #PI * 0.5
          facteur = Pow(Sin(angle), 1.0 + force)
          
          src_x = cx + dx * facteur * rayon
          src_y = cy + dy * facteur * rayon
        Else
          ; Hors rayon d'action
          src_x = x
          src_y = y
        EndIf

        src_x_int = Int(src_x)
        src_y_int = Int(src_y)

        If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
          offset_src = (src_y_int * lg + src_x_int) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $00000000) ; Vide (Alpha 0)
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure SpherizeEx(*FilterCtx.FilterParams)
  Restore Spherize_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Spherize_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Spherize(source, cible, mask, force=100, cX=50, cY=50, rayon=50)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = force ; 0-600
    \option[1] = cX    ; 0-100%
    \option[2] = cY    ; 0-100%
    \option[3] = rayon ; 0-100%
  EndWith
  SpherizeEx(FilterCtx)
EndProcedure

DataSection
  Spherize_Data:
  Data.s "Spherize"
  Data.s "Effet de loupe ou de pincement sphérique (lentille optique)"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Force (100=Neutre)" : Data.i 0, 600, 100
  Data.s "Centre X (%)"       : Data.i 0, 100, 50
  Data.s "Centre Y (%)"       : Data.i 0, 100, 50
  Data.s "Rayon (%)"          : Data.i 0, 100, 50
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 85
; FirstLine = 57
; Folding = -
; EnableXP
; DPIAware