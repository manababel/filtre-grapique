; ==============================================================================
; FILTRE LENS (LENTILLE / LOUPE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Lens_MT(*p.FilterParams)
  With *p
    Protected startY.i, stopY.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]
    
    ; --- Précalculs des paramètres ---
    Protected cx.f = (\option[1] * lg) / 100.0
    Protected cy.f = (\option[2] * ht) / 100.0
    Protected zoom.f = \option[0] / 100.0
    
    ; Diagonale pour le calcul du rayon
    Protected diag.f = Sqr(lg * lg + ht * ht)
    Protected rayon.f = (diag * \option[3]) / 100.0 + 1.0
    Protected rayon_carre.f = rayon * rayon
    Protected inv_rayon.f = 1.0 / rayon
    
    Protected x.i, y.i
    Protected dx.f, dy.f, dist_carre.f, dist.f
    Protected factor.f, inv_factor.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected offset_dst.i, offset_src.i

    ; --- Configuration Multithreading ---
    startY = (\thread_pos * ht) / \thread_max
    stopY  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    ; Early exit si pas de zoom (identité)
    If zoom = 0.0
      For y = startY To stopY
        CopyMemory(*source + (y * lg * 4), *cible + (y * lg * 4), lg * 4)
      Next y
      ProcedureReturn
    EndIf

    ; --- Traitement principal ---
    For y = startY To stopY
      dy = y - cy
      offset_dst = y * lg * 4
      
      For x = 0 To lg - 1
        dx = x - cx
        dist_carre = dx * dx + dy * dy
        
        ; Vérification si dans le rayon d'action
        If dist_carre < rayon_carre And dist_carre > 0.0
          dist = Sqr(dist_carre)
          
          ; Facteur : zoom max au centre, s'estompe vers les bords
          factor = 1.0 + zoom * (1.0 - dist * inv_rayon)
          
          ; Mapping inverse pour le zoom
          inv_factor = 1.0 / factor
          src_x = cx + dx * inv_factor
          src_y = cy + dy * inv_factor
        Else
          src_x = x
          src_y = y
        EndIf
        
        src_x_int = Int(src_x)
        src_y_int = Int(src_y)
        
        ; Échantillonnage
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

Procedure LensEx(*FilterCtx.FilterParams)
  Restore Lens_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Lens_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Lens(source, cible, mask, zoom=100, cX=50, cY=50, rayon=30)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = zoom  ; -100 à 300%
    \option[1] = cX    ; 0-100%
    \option[2] = cY    ; 0-100%
    \option[3] = rayon ; 0-100%
  EndWith
  LensEx(FilterCtx)
EndProcedure

DataSection
  Lens_Data:
  Data.s "Lens"
  Data.s "Effet loupe ou lentille circulaire (Zoom positif ou négatif)"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Zoom (%)"     : Data.i -100, 300, 100
  Data.s "Centre X (%)" : Data.i 0, 100, 50
  Data.s "Centre Y (%)" : Data.i 0, 100, 50
  Data.s "Rayon (%)"    : Data.i 1, 100, 30
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 96
; FirstLine = 68
; Folding = -
; EnableXP
; DPIAware