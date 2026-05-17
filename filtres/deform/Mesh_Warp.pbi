; ==============================================================================
; FILTRE MESH WARP - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure MeshWarp_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Configuration et Précalculs ---
    Protected grid_size.i = \option[0]
    If grid_size < 2 : grid_size = 2 : EndIf
    If grid_size > 20 : grid_size = 20 : EndIf

    Protected warp_type.i = \option[1]
    Protected intensity.f = (\option[2] / 100.0)
    Protected interp_mode.i = \option[3]

    Protected cell_width.f = (lg / grid_size)
    Protected cell_height.f = (ht / grid_size)

    ; --- Configuration Multithreading ---
    Protected startY.i = ((\thread_pos * ht) / \thread_max)
    Protected stopY.i  = (((\thread_pos + 1) * ht) / \thread_max - 1)
    If stopY > (ht - 1) : stopY = (ht - 1) : EndIf

    Protected offset_dst.i, offset_src.i
    Protected cell_x.i, cell_y.i
    Protected local_x.f, local_y.f
    Protected u.f, v.f
    Protected deform_x.f, deform_y.f
    Protected cx.f, cy.f
    Protected distance.f, angle.f
    Protected factor.f, hash.i, dist_bubble.f, bubble_strength.f
    Protected bubble_x.f, bubble_y.f, offset_u.f, offset_v.f

    cx = (lg * 0.5)
    cy = (ht * 0.5)

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = (y * lg * 4)

      For x = 0 To (lg - 1)
        cell_x = Int(x / cell_width)
        cell_y = Int(y / cell_height)
        
        local_x = ((x - (cell_x * cell_width)) / cell_width)
        local_y = ((y - (cell_y * cell_height)) / cell_height)
        
        u = local_x
        v = local_y

        deform_x = 0
        deform_y = 0
        
        Select warp_type
          Case 0  ; ===== Ondulation sinusoïdale =====
            deform_x = (Sin(((cell_y + v) * #PI)) * intensity * cell_width * 0.3)
            deform_y = (Sin(((cell_x + u) * #PI)) * intensity * cell_height * 0.3)
            
          Case 1  ; ===== Torsion radiale =====
            distance = Sqr(((x - cx) * (x - cx)) + ((y - cy) * (y - cy)))
            angle = ATan2((y - cy), (x - cx))
            angle = (angle + ((intensity * 0.5) * (1.0 - (distance / cx))))
            
            deform_x = (((Cos(angle) * distance) + cx) - x)
            deform_y = (((Sin(angle) * distance) + cy) - y)
            
          Case 2  ; ===== Effet de vague par cellule =====
            deform_x = (Sin(((v + (cell_y * 0.5)) * #PI * 2.0)) * intensity * cell_width * 0.5)
            deform_y = (Cos(((u + (cell_x * 0.5)) * #PI * 2.0)) * intensity * cell_height * 0.5)
            
          Case 3  ; ===== Pincement alternant =====
            If ((cell_x + cell_y) % 2) = 0
              factor = (1.0 + (intensity * 0.3))
            Else
              factor = (1.0 - (intensity * 0.3))
            EndIf
            deform_x = ((u - 0.5) * (factor - 1.0) * cell_width)
            deform_y = ((v - 0.5) * (factor - 1.0) * cell_height)
            
          Case 4  ; ===== Effet damier déformé =====
            offset_u = (Sin((cell_x * #PI)) * intensity * 0.2)
            offset_v = (Cos((cell_y * #PI)) * intensity * 0.2)
            deform_x = (offset_u * cell_width)
            deform_y = (offset_v * cell_height)
            
          Case 5  ; ===== Bulles aléatoires par cellule =====
            hash = ((cell_x * 73856093) ! (cell_y * 19349663))
            hash = ((hash * 1103515245 + 12345) & $7FFFFFFF)
            bubble_x = (Mod(hash, 100) / 100.0)
            hash = ((hash * 1103515245 + 12345) & $7FFFFFFF)
            bubble_y = (Mod(hash, 100) / 100.0)
            
            dist_bubble = Sqr(((u - bubble_x) * (u - bubble_x)) + ((v - bubble_y) * (v - bubble_y)))
            
            If dist_bubble < 0.5
              bubble_strength = ((0.5 - dist_bubble) * 2.0 * intensity)
              deform_x = ((u - bubble_x) * bubble_strength * cell_width)
              deform_y = ((v - bubble_y) * bubble_strength * cell_height)
            EndIf
        EndSelect

        src_x = (x + deform_x)
        src_y = (y + deform_y)
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

Procedure MeshWarpEx(*FilterCtx.FilterParams)
  Restore MeshWarp_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@MeshWarp_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure MeshWarp(source, cible, mask, res=5, type=0, intensity=50, interp=1)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = res
    \option[1] = type
    \option[2] = intensity
    \option[3] = interp
  EndWith
  MeshWarpEx(FilterCtx)
EndProcedure

DataSection
  MeshWarp_Data:
  Data.s "Mesh Warp (Déformation grille)"
  Data.s "Déformation par grille de contrôle avec motifs prédéfinis"
  Data.i #FilterType_Deformation, 0
  Data.s "Résolution (divisions)" : Data.i 2, 20, 5
  Data.s "Type (0:Onde, 1:Tors, 2:Vague, 3:Dam, 4:Déc, 5:Bull)" : Data.i 0, 5, 0
  Data.s "Intensité (force)" : Data.i 0, 100, 50
  Data.s "Interpolation (0:Lin, 1:Bilin, 2:Bicub)" : Data.i 0, 2, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 161
; FirstLine = 110
; Folding = -
; EnableXP
; DPIAware