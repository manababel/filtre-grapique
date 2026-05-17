; ==============================================================================
; FILTRE PERSPECTIVE SIMPLE (TRAPÈZE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure PerspectiveTrapezeLin_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected sx.f, sy.f, u.f, v.f
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs de normalisation ---
    Protected inv_lg.f = 1.0 / (lg - 1)
    Protected inv_ht.f = 1.0 / (ht - 1)
    Protected half_lg.f = lg * 0.5
    Protected half_ht.f = ht * 0.5

    ; Calcul des offsets symétriques
    Protected offsetY_Gauche.f = ((50.0 - \option[0]) / 50.0) * half_ht
    Protected offsetY_Droite.f = ((50.0 - \option[1]) / 50.0) * half_ht
    Protected offsetX_HautGauche.f = ((50.0 - \option[2]) / 50.0) * half_lg
    Protected offsetX_BasGauche.f  = ((50.0 - \option[3]) / 50.0) * half_lg

    ; Calcul des positions des 4 coins déformés
    Protected x00.f = 0.0 + offsetX_HautGauche
    Protected y00.f = 0.0 - offsetY_Gauche
    Protected x10.f = (lg - 1) - offsetX_HautGauche
    Protected y10.f = 0.0 - offsetY_Droite
    Protected x01.f = 0.0 + offsetX_BasGauche
    Protected y01.f = (ht - 1) + offsetY_Gauche
    Protected x11.f = (lg - 1) - offsetX_BasGauche
    Protected y11.f = (ht - 1) + offsetY_Droite

    ; Précalcul des différentielles des bords
    Protected deltaY_Left.f  = y01 - y00
    Protected deltaY_Right.f = y11 - y10
    
    ; --- Configuration Multithreading (macro_calcul_thread) ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected borderLeftY.f, borderRightY.f
    Protected borderLeftX.f, borderRightX.f
    Protected deltaBorderX.f, deltaBorderY.f
    Protected offset_dst.i, offset_src.i
    Protected sx_int.i, sy_int.i

    ; --- Traitement principal ---
    For y = startY To stopY
      v = y * inv_ht

      ; Coordonnées Y des bords pour cette ligne
      borderLeftY  = y00 + v * deltaY_Left
      borderRightY = y10 + v * deltaY_Right
      
      borderLeftX  = x00
      borderRightX = x10

      deltaBorderX = borderRightX - borderLeftX
      deltaBorderY = borderRightY - borderLeftY

      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        u = x * inv_lg

        ; Interpolation linéaire horizontale entre les deux bords
        sx = borderLeftX + u * deltaBorderX
        sy = borderLeftY + u * deltaBorderY

        sx_int = Int(sx)
        sy_int = Int(sy)

        If sx_int >= 0 And sx_int < lg And sy_int >= 0 And sy_int < ht
          offset_src = (sy_int * lg + sx_int) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $FF000000) ; Noir opaque
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure PerspectiveSimpleEx(*FilterCtx.FilterParams)
  Restore PerspectiveSimple_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@PerspectiveTrapezeLin_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure PerspectiveSimple(source, cible, mask, offVG=50, offVD=50, offHH=50, offHB=50)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = offVG
    \option[1] = offVD
    \option[2] = offHH
    \option[3] = offHB
  EndWith
  PerspectiveSimpleEx(FilterCtx)
EndProcedure

DataSection
  PerspectiveSimple_Data:
  Data.s "Perspective Simple"
  Data.s "Déformation trapèze avec décalage symétrique des bords"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Décalage vertical gauche (%)"   : Data.i 0, 100, 50
  Data.s "Décalage vertical droite (%)"   : Data.i 0, 100, 50
  Data.s "Décalage horizontal haut (%)"   : Data.i 0, 100, 50
  Data.s "Décalage horizontal bas (%)"    : Data.i 0, 100, 50
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 100
; FirstLine = 72
; Folding = -
; EnableXP
; DPIAware