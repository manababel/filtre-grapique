; ==============================================================================
; FILTRE RIPPLE (ONDULATION SINUSOÏDALE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Ripple_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs des paramètres d'onde ---
    Protected amp_x.f = \option[0] ; Amplitude en pixels
    Protected amp_y.f = \option[2]

    ; Périodes (évite division par zéro)
    Protected period_x.f = (\option[1] / 100.0) * ht : If period_x < 0.1 : period_x = 0.1 : EndIf
    Protected period_y.f = (\option[3] / 100.0) * lg : If period_y < 0.1 : period_y = 0.1 : EndIf

    ; Facteurs de normalisation pour Sin()
    Protected inv_period_x.f = (2.0 * #PI) / period_x
    Protected inv_period_y.f = (2.0 * #PI) / period_y

    ; --- Configuration Multithreading (macro_calcul_thread) ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_x.f, offset_y.f
    Protected offset_dst.i, offset_src.i
    Protected y_sin_factor.f

    ; --- Traitement principal ---
    For y = startY To stopY
      ; L'onde horizontale (déplacement X) dépend de la position verticale (Y)
      y_sin_factor = y * inv_period_x
      offset_x = amp_x * Sin(y_sin_factor)
      
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        ; L'onde verticale (déplacement Y) dépend de la position horizontale (X)
        offset_y = amp_y * Sin(x * inv_period_y)

        ; Mapping inverse (backward mapping)
        src_x = x + offset_x
        src_y = y + offset_y

        src_x_int = Int(src_x)
        src_y_int = Int(src_y)

        ; Échantillonnage avec gestion des limites
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

Procedure RippleEx(*FilterCtx.FilterParams)
  Restore Ripple_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Ripple_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Ripple(source, cible, mask, ampX=5, perX=10, ampY=5, perY=10)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = ampX ; Amplitude X
    \option[1] = perX ; Période X (% ht)
    \option[2] = ampY ; Amplitude Y
    \option[3] = perY ; Période Y (% lg)
  EndWith
  RippleEx(FilterCtx)
EndProcedure

DataSection
  Ripple_Data:
  Data.s "Ripple"
  Data.s "Déformation sinusoïdale simulant des ondes ou ondulations"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Amp. Horiz (px)" : Data.i 0, 100, 5
  Data.s "Pér. Horiz (%)"  : Data.i 1, 100, 10
  Data.s "Amp. Vert (px)"  : Data.i 0, 100, 5
  Data.s "Pér. Vert (%)"   : Data.i 1, 100, 10
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 79
; FirstLine = 51
; Folding = -
; EnableXP
; DPIAware