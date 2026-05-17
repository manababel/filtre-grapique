; ==============================================================================
; FILTRE BARREL (DISTORSION RADIALE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Barrel_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected dx.f, dy.f, r.f, r2.f, r4.f
    Protected normalized_r.f, distortion_factor.f, corrected_r.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs des constantes ---
    Protected cx.f = (\option[1] / 100.0) * lg
    Protected cy.f = (\option[2] / 100.0) * ht

    ; Normalisation basée sur la demi-diagonale
    Protected diagonale.f = Sqr(lg * lg + ht * ht)
    Protected inv_norm_dist.f = 1.0 / (diagonale * 0.5)

    ; Coefficients de distorsion (modèle Brown-Conrady)
    ; k1 : principal (centré sur 100), k2 : secondaire pour distorsions complexes
    Protected k1.f = (\option[0] - 100.0) / 100.0
    Protected k2.f = (\option[3] / 100.0) * 0.1

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        dx = x - cx
        dy = y - cy
        r = Sqr(dx * dx + dy * dy)

        If r > 0.001
          ; Normalisation de la distance (0 au centre, ~1 aux bords)
          normalized_r = r * inv_norm_dist
          r2 = normalized_r * normalized_r
          r4 = r2 * r2
          
          ; Calcul du facteur de distorsion : 1 + k1*r² + k2*r⁴
          distortion_factor = 1.0 + k1 * r2 + k2 * r4
          corrected_r = r * distortion_factor

          ; Projection inverse vers la source
          src_x = cx + (dx / r) * corrected_r
          src_y = cy + (dy / r) * corrected_r
        Else
          src_x = x
          src_y = y
        EndIf

        src_x_int = Int(src_x)
        src_y_int = Int(src_y)

        ; Échantillonnage avec protection des limites
        If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
          offset_src = (src_y_int * lg + src_x_int) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $00000000) ; Transparent
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure BarrelEx(*FilterCtx.FilterParams)
  Restore Barrel_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Barrel_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Barrel(source, cible, mask, intensity=100, posX=50, posY=50, secondary=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensity ; Distorsion (0-200, 100=neutre)
    \option[1] = posX      ; Centre X (%)
    \option[2] = posY      ; Centre Y (%)
    \option[3] = secondary ; Correction k2 (%)
  EndWith
  BarrelEx(FilterCtx)
EndProcedure

DataSection
  Barrel_Data:
  Data.s "Barrel"
  Data.s "Distorsion radiale (Barillet / Coussinet) pour correction optique"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Intensité (%)"     : Data.i 0, 200, 100
  Data.s "Centre X (%)"      : Data.i 0, 100, 50
  Data.s "Centre Y (%)"      : Data.i 0, 100, 50
  Data.s "Correction d'ordre": Data.i 0, 100, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 91
; FirstLine = 63
; Folding = -
; EnableXP
; DPIAware