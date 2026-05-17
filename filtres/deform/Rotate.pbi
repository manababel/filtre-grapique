; ==============================================================================
; FILTRE ROTATION - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Rotation_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected sx.i, sy.i
    Protected dx.f, dy.f
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs ---
    Protected angle.f = \option[0] * #PI / 180.0
    Protected cosA.f = Cos(angle)
    Protected sinA.f = Sin(angle)

    ; Précalcul du centre de rotation
    Protected cx.f = (\option[1] / 100.0) * lg
    Protected cy.f = (\option[2] / 100.0) * ht

    ; --- Configuration Multithreading (macro_calcul_thread) ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i

    ; --- Traitement principal (Transformation inverse) ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        ; Calcul de la position relative au centre
        dx = x - cx
        dy = y - cy

        ; Application de la rotation inverse (backward mapping)
        sx = Round(cosA * dx + sinA * dy + cx, #PB_Round_Nearest)
        sy = Round(-sinA * dx + cosA * dy + cy, #PB_Round_Nearest)

        ; Vérification des limites et échantillonnage
        If sx >= 0 And sx < lg And sy >= 0 And sy < ht
          offset_src = (sy * lg + sx) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          ; Pixel hors limites = noir transparent
          PokeL(*cible + offset_dst, $00000000)
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure RotateEx(*FilterCtx.FilterParams)
  Restore Rotate_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Rotation_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Rotate(source, cible, mask, angle=0, centreX=50, centreY=50)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = angle
    \option[1] = centreX
    \option[2] = centreY
  EndWith
  RotateEx(FilterCtx)
EndProcedure

DataSection
  Rotate_Data:
  Data.s "Rotation"
  Data.s "Rotation d'image autour d'un point pivot configurable"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Angle (degrés)"    : Data.i 0, 360, 0
  Data.s "Centre X (% lg)"   : Data.i 0, 100, 50
  Data.s "Centre Y (% ht)"   : Data.i 0, 100, 50
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 69
; FirstLine = 39
; Folding = -
; EnableXP
; DPIAware