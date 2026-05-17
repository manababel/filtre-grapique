; ==============================================================================
; FILTRE WAVE (ONDULATION LINÉAIRE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Wave_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected offset_x.f, offset_y.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Configuration et Précalculs ---
    Protected amplitude.f = \option[0]
    Protected wavelength.f = \option[1]
    If wavelength < 1.0 : wavelength = 1.0 : EndIf
    Protected inv_wavelength.f = (2.0 * #PI) / wavelength

    Protected direction.i = \option[2] ; 0=horiz, 1=vert, 2=les deux
    Protected phase.f     = (\option[3] / 360.0) * 2.0 * #PI
    Protected wave_type.i = \option[4] ; 0=sinus, 1=carré, 2=triangle, 3=scie

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i
    Protected t.f, wave_value.f, frac_part.f

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        offset_x = 0
        offset_y = 0

        ; Calcul de l'onde pour chaque axe activé
        ; Note : La direction 0 (Horizontal) déforme l'image verticalement (offset_y)
        ;        La direction 1 (Vertical) déforme l'image horizontalement (offset_x)
        
        ; --- Axe Horizontal (vagues se déplaçant selon X) ---
        If direction = 0 Or direction = 2
          t = x * inv_wavelength + phase
          
          Select wave_type
            Case 0 : wave_value = Sin(t)
            Case 1 : If Sin(t) >= 0 : wave_value = 1.0 : Else : wave_value = -1.0 : EndIf
            Case 2 : frac_part = (t / (2.0 * #PI)) - Int(t / (2.0 * #PI))
                     If frac_part < 0 : frac_part + 1.0 : EndIf
                     If frac_part < 0.25 : wave_value = frac_part * 4.0
                     ElseIf frac_part < 0.75 : wave_value = 1.0 - (frac_part - 0.25) * 4.0
                     Else : wave_value = -1.0 + (frac_part - 0.75) * 4.0 : EndIf
            Case 3 : frac_part = (t / (2.0 * #PI)) - Int(t / (2.0 * #PI))
                     If frac_part < 0 : frac_part + 1.0 : EndIf
                     wave_value = frac_part * 2.0 - 1.0
          EndSelect
          offset_y = amplitude * wave_value
        EndIf

        ; --- Axe Vertical (vagues se déplaçant selon Y) ---
        If direction = 1 Or direction = 2
          t = y * inv_wavelength + phase
          
          Select wave_type
            Case 0 : wave_value = Sin(t)
            Case 1 : If Sin(t) >= 0 : wave_value = 1.0 : Else : wave_value = -1.0 : EndIf
            Case 2 : frac_part = (t / (2.0 * #PI)) - Int(t / (2.0 * #PI))
                     If frac_part < 0 : frac_part + 1.0 : EndIf
                     If frac_part < 0.25 : wave_value = frac_part * 4.0
                     ElseIf frac_part < 0.75 : wave_value = 1.0 - (frac_part - 0.25) * 4.0
                     Else : wave_value = -1.0 + (frac_part - 0.75) * 4.0 : EndIf
            Case 3 : frac_part = (t / (2.0 * #PI)) - Int(t / (2.0 * #PI))
                     If frac_part < 0 : frac_part + 1.0 : EndIf
                     wave_value = frac_part * 2.0 - 1.0
          EndSelect
          offset_x = amplitude * wave_value
        EndIf

        ; Mapping source
        src_x_int = Int(x + offset_x)
        src_y_int = Int(y + offset_y)

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

Procedure WaveEx(*FilterCtx.FilterParams)
  Restore Wave_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Wave_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Wave(source, cible, mask, amp=10, waveL=50, dir=0, phase=0, type=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = amp   ; Amplitude en pixels
    \option[1] = waveL ; Longueur d'onde en pixels
    \option[2] = dir   ; Direction (0-2)
    \option[3] = phase ; Décalage (0-360°)
    \option[4] = type  ; Forme (0-3)
  EndWith
  WaveEx(FilterCtx)
EndProcedure

DataSection
  Wave_Data:
  Data.s "Wave"
  Data.s "Ondulation directionnelle (Sinus, Carré, Triangle, Scie)"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Amplitude (px)"       : Data.i 0, 100, 10
  Data.s "Longueur d'onde (px)" : Data.i 1, 500, 50
  Data.s "Direction (0:H, 1:V, 2:HV)" : Data.i 0, 2, 0
  Data.s "Phase (°)"            : Data.i 0, 360, 0
  Data.s "Type d'onde (0-3)"    : Data.i 0, 3, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 112
; FirstLine = 86
; Folding = -
; EnableXP
; DPIAware