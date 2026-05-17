; ==============================================================================
; FILTRE SHEAR (CISAILLEMENT) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Shear_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected src_x.i, src_y.i
    Protected offset_x.f, offset_y.f
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalcul des facteurs de cisaillement ---
    ; 100 = neutre, plage de -1.0 à 1.0
    Protected shear_x.f = (\option[0] - 100.0) / 100.0
    Protected shear_y.f = (\option[1] - 100.0) / 100.0

    ; --- Précalcul du point d'ancrage (pivot immobile) ---
    Protected anchor_x.f = (\option[2] / 100.0) * lg
    Protected anchor_y.f = (\option[3] / 100.0) * ht

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i
    Protected dy.f

    ; --- Traitement principal ---
    For y = startY To stopY
      dy = y - anchor_y ; Distance verticale constante pour la ligne
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        ; Calcul de la position source (inverse de la déformation)
        ; x' = x - (shear_x * dy)
        ; y' = y - (shear_y * dx)
        offset_x = shear_x * dy
        offset_y = shear_y * (x - anchor_x)
        
        src_x = x - Int(offset_x)
        src_y = y - Int(offset_y)

        ; Échantillonnage avec vérification des limites
        If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
          offset_src = (src_y * lg + src_x) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $00000000) ; Transparent
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure ShearEx(*FilterCtx.FilterParams)
  Restore Shear_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Shear_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Shear(source, cible, mask, shearX=100, shearY=100, anchorX=50, anchorY=50)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = shearX   ; Cisaillement horizontal (0-200)
    \option[1] = shearY   ; Cisaillement vertical (0-200)
    \option[2] = anchorX  ; Pivot X (%)
    \option[3] = anchorY  ; Pivot Y (%)
  EndWith
  ShearEx(FilterCtx)
EndProcedure

DataSection
  Shear_Data:
  Data.s "Shear"
  Data.s "Déformation oblique (parallélogramme) avec ancrage ajustable"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Cisaillement X (%)" : Data.i 0, 200, 100
  Data.s "Cisaillement Y (%)" : Data.i 0, 200, 100
  Data.s "Pivot X (%)"         : Data.i 0, 100, 50
  Data.s "Pivot Y (%)"         : Data.i 0, 100, 50
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 71
; FirstLine = 43
; Folding = -
; EnableXP
; DPIAware