; ==============================================================================
; FILTRE WAVE CIRCULAR (ONDULATIONS RADIALES) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure WaveCircular_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected dx.f, dy.f, r.f
    Protected offset.f, displacement_factor.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs du centre et de l'onde ---
    Protected cx.f = (\option[1] / 100.0) * lg
    Protected cy.f = (\option[2] / 100.0) * ht
    Protected amplitude.f = \option[0]

    ; Longueur d'onde basée sur la diagonale
    Protected diagonale.f = Sqr(lg * lg + ht * ht)
    Protected wavelength.f = (\option[3] / 100.0) * diagonale
    If wavelength < 0.1 : wavelength = 0.1 : EndIf
    
    Protected inv_wavelength.f = (2.0 * #PI) / wavelength
    Protected phase.f = (\option[4] / 360.0) * 2.0 * #PI

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

        If r > 0.001 ; Sécurité division par zéro
          ; Décalage sinusoïdal radial
          offset = amplitude * Sin(r * inv_wavelength + phase)
          
          ; On déplace le pixel d'échantillonnage le long du rayon
          inv_r = 1.0 / r
          displacement_factor = 1.0 + offset * inv_r
          
          src_x = cx + dx * displacement_factor
          src_y = cy + dy * displacement_factor
        Else
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

Procedure WaveCircularEx(*FilterCtx.FilterParams)
  Restore WaveCircular_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@WaveCircular_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure WaveCircular(source, cible, mask, amp=10, cX=50, cY=50, wavelength=20, phase=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = amp        ; Amplitude en pixels
    \option[1] = cX         ; Centre X %
    \option[2] = cY         ; Centre Y %
    \option[3] = wavelength ; Longueur d'onde %
    \option[4] = phase      ; Phase en degrés
  EndWith
  WaveCircularEx(FilterCtx)
EndProcedure

DataSection
  WaveCircular_Data:
  Data.s "WaveCircular"
  Data.s "Ondulations concentriques simulant des rides à la surface de l'eau"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Amplitude (px)" : Data.i 0, 100, 10
  Data.s "Centre X (%)"    : Data.i 0, 100, 50
  Data.s "Centre Y (%)"    : Data.i 0, 100, 50
  Data.s "Long. Onde (%)"  : Data.i 1, 100, 20
  Data.s "Phase (degrés)"  : Data.i 0, 360, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 88
; FirstLine = 62
; Folding = -
; EnableXP
; DPIAware