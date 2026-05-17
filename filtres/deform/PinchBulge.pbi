; ==============================================================================
; FILTRE PINCH/BULGE (PINCEMENT/BOMBEMENT) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure PinchBulge_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected dx.f, dy.f, dist_carre.f, dist.f
    Protected factor.f, dist_norm.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs des paramètres ---
    Protected cx.f = (\option[1] * lg) / 100.0
    Protected cy.f = (\option[2] * ht) / 100.0
    Protected diag.f = Sqr(lg * lg + ht * ht)
    Protected rayon.f = (diag * \option[3]) / 100.0 + 1.0
    Protected rayon_carre.f = rayon * rayon
    Protected inv_rayon.f = 1.0 / rayon
    
    Protected force.f = (\option[0]) / 100.0
    Protected exposant.f = 1.0 - force 

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    ; Early exit si force nulle
    If Abs(force) < 0.001
      For y = startY To stopY
        CopyMemory(*source + (y * lg * 4), *cible + (y * lg * 4), lg * 4)
      Next y
      ProcedureReturn
    EndIf

    ; --- Optimisation : Table de lookup pour Pow() ---
    ; On génère la LUT localement par thread pour éviter les conflits d'accès
    #LUT_SIZE = 1024
    Protected Dim powerLUT.f(#LUT_SIZE)
    Protected lut_i.i
    For lut_i = 0 To #LUT_SIZE
      powerLUT(lut_i) = Pow(lut_i / #LUT_SIZE, exposant)
    Next lut_i

    Protected offset_dst.i, offset_src.i

    ; --- Traitement principal ---
    For y = startY To stopY
      dy = y - cy
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        dx = x - cx
        dist_carre = dx * dx + dy * dy

        If dist_carre < rayon_carre And dist_carre > 0.0
          dist = Sqr(dist_carre)
          dist_norm = dist * inv_rayon
          
          ; Utilisation de la LUT
          lut_i = Int(dist_norm * #LUT_SIZE)
          ; Sécurité d'index (clamp)
          If lut_i > #LUT_SIZE : lut_i = #LUT_SIZE : EndIf
          factor = powerLUT(lut_i)
          
          src_x = cx + dx * factor
          src_y = cy + dy * factor
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
          PokeL(*cible + offset_dst, $00000000) ; Vide (Alpha 0)
        EndIf

        offset_dst + 4
      Next x
    Next y
    
    FreeArray(powerLUT())
  EndWith
EndProcedure

Procedure PinchBulgeEx(*FilterCtx.FilterParams)
  Restore PinchBulge_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@PinchBulge_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure PinchBulge(source, cible, mask, force=0, cX=50, cY=50, rayon=30)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = force ; -100 à +100
    \option[1] = cX    ; 0-100%
    \option[2] = cY    ; 0-100%
    \option[3] = rayon ; 0-100%
  EndWith
  PinchBulgeEx(FilterCtx)
EndProcedure

DataSection
  PinchBulge_Data:
  Data.s "PinchBulge"
  Data.s "Déformation radiale (Négatif=Pincement, Positif=Bombement)"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Force (-100 à 100)" : Data.i -100, 100, 0
  Data.s "Centre X (%)"       : Data.i 0, 100, 50
  Data.s "Centre Y (%)"       : Data.i 0, 100, 50
  Data.s "Rayon (%)"          : Data.i 1, 100, 30
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 106
; FirstLine = 78
; Folding = -
; EnableXP
; DPIAware