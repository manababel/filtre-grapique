; ==============================================================================
; FILTRE SQUEEZE (COMPRESSION/ÉTIREMENT) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Squeeze_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Configuration et Précalculs ---
    Protected factor_x.f = (\option[0] / 100.0)
    Protected factor_y.f = (\option[1] / 100.0)

    Protected cx.f = ((\option[2] / 100.0) * lg)
    Protected cy.f = ((\option[3] / 100.0) * ht)

    Protected mode.i = \option[4]

    ; --- Configuration Multithreading ---
    Protected startY.i = ((\thread_pos * ht) / \thread_max)
    Protected stopY.i  = (((\thread_pos + 1) * ht) / \thread_max - 1)
    If stopY > (ht - 1) : stopY = (ht - 1) : EndIf

    Protected offset_dst.i, offset_src.i
    Protected dx.f, dy.f, distance.f, normalized_dist.f
    Protected local_factor_x.f, local_factor_y.f
    Protected max_dist.f

    If mode = 1
      max_dist = (Sqr((lg * lg) + (ht * ht)) * 0.5)
    EndIf

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = (y * lg * 4)

      For x = 0 To (lg - 1)
        
        Select mode
          Case 0  ; ===== Mode linéaire (uniforme) =====
            dx = (x - cx)
            dy = (y - cy)
            
            src_x = (cx + (dx / factor_x))
            src_y = (cy + (dy / factor_y))
            
          Case 1  ; ===== Mode radial (progressif) =====
            dx = (x - cx)
            dy = (y - cy)
            distance = Sqr((dx * dx) + (dy * dy))
            
            If distance > 0.001
              normalized_dist = (distance / max_dist)
              If normalized_dist > 1.0 : normalized_dist = 1.0 : EndIf
              
              local_factor_x = (1.0 + ((factor_x - 1.0) * normalized_dist))
              local_factor_y = (1.0 + ((factor_y - 1.0) * normalized_dist))
              
              src_x = (cx + (dx / local_factor_x))
              src_y = (cy + (dy / local_factor_y))
            Else
              src_x = x
              src_y = y
            EndIf
            
          Case 2  ; ===== Mode exponentiel (courbure) =====
            dx = (x - cx)
            dy = (y - cy)
            
            If dx >= 0
              src_x = (cx + (Pow(Abs(dx / (lg * 0.5)), 1.0 / factor_x) * (lg * 0.5)))
            Else
              src_x = (cx - (Pow(Abs(dx / (lg * 0.5)), 1.0 / factor_x) * (lg * 0.5)))
            EndIf
            
            If dy >= 0
              src_y = (cy + (Pow(Abs(dy / (ht * 0.5)), 1.0 / factor_y) * (ht * 0.5)))
            Else
              src_y = (cy - (Pow(Abs(dy / (ht * 0.5)), 1.0 / factor_y) * (ht * 0.5)))
            EndIf
            
        EndSelect

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

Procedure SqueezeEx(*FilterCtx.FilterParams)
  Restore Squeeze_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Squeeze_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Squeeze(source, cible, mask, factX=100, factY=100, cX=50, cY=50, mode=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = factX
    \option[1] = factY
    \option[2] = cX
    \option[3] = cY
    \option[4] = mode
  EndWith
  SqueezeEx(FilterCtx)
EndProcedure

DataSection
  Squeeze_Data:
  Data.s "Squeeze (Compression/Étirement)"
  Data.s "Compression ou étirement non-uniforme avec modes linéaire, radial et exponentiel"
  Data.i #FilterType_Deformation, 0
  Data.s "Facteur X (0-99:comp, 100:neutre, 101-200:étire)" : Data.i 0, 200, 100
  Data.s "Facteur Y (0-99:comp, 100:neutre, 101-200:étire)" : Data.i 0, 200, 100
  Data.s "Centre X (% largeur)" : Data.i 0, 100, 50
  Data.s "Centre Y (% hauteur)" : Data.i 0, 100, 50
  Data.s "Mode (0:Lin, 1:Rad, 2:Exp)" : Data.i 0, 2, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 115
; FirstLine = 89
; Folding = -
; EnableXP
; DPIAware