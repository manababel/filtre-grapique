; ==============================================================================
; FILTRE PERSPECTIVE HOMOGRAPHIQUE (MATRICE 3x3) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure PerspectiveHomography_MT(*p.FilterParams)
  With *p
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]
    Protected *source.Long = \addr[0]  
    Protected *cible.Long  = \addr[1]  
    Protected x.i, y.i

    ; --- Précalcul des constantes de dimensions ---
    Protected half_lg.f = lg * 0.5
    Protected half_ht.f = ht * 0.5
    Protected lg_max.f = lg - 1
    Protected ht_max.f = ht - 1

    ; --- Calcul des 4 coins destination (en % de décalage autour des coins réels) ---
    ; On transforme le 0-100% (défaut 50%) en un décalage relatif au coin
    Protected x0.f = ((\option[0] - 50.0) / 50.0) * half_lg + 0.0
    Protected y0.f = ((\option[1] - 50.0) / 50.0) * half_ht + 0.0
    Protected x1.f = ((\option[2] - 50.0) / 50.0) * half_lg + lg_max
    Protected y1.f = ((\option[3] - 50.0) / 50.0) * half_ht + 0.0
    Protected x2.f = ((\option[4] - 50.0) / 50.0) * half_lg + lg_max
    Protected y2.f = ((\option[5] - 50.0) / 50.0) * half_ht + ht_max
    Protected x3.f = ((\option[6] - 50.0) / 50.0) * half_lg + 0.0
    Protected y3.f = ((\option[7] - 50.0) / 50.0) * half_ht + ht_max

    ; --- Construction de l'homographie inverse ---
    Protected dx1.f = x1 - x2
    Protected dx2.f = x3 - x2
    Protected dx3.f = x0 - x1 + x2 - x3
    Protected dy1.f = y1 - y2
    Protected dy2.f = y3 - y2
    Protected dy3.f = y0 - y1 + y2 - y3

    Protected det.f = dx1 * dy2 - dx2 * dy1
    
    ; Vérification de la validité (déterminant non nul)
    If Abs(det) < 0.0001
      ; Copie simple par thread si transformation impossible
      Protected start_Y.i = (\thread_pos * ht) / \thread_max
      Protected stop_Y.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
      If stop_Y > ht - 1 : stop_Y = ht - 1 : EndIf
      For y = start_Y To stop_Y
        CopyMemory(*source + y * lg * 4, *cible + y * lg * 4, lg * 4)
      Next y
      ProcedureReturn
    EndIf

    ; Coefficients de la matrice
    Protected a13.f = (dx3 * dy2 - dx2 * dy3) / det
    Protected a23.f = (dx1 * dy3 - dx3 * dy1) / det

    ; Matrice d'homographie [H]
    Protected h11.f = x1 - x0 + a13 * x1
    Protected h12.f = x3 - x0 + a23 * x3
    Protected h13.f = x0
    Protected h21.f = y1 - y0 + a13 * y1
    Protected h22.f = y3 - y0 + a23 * y3
    Protected h23.f = y0
    Protected h31.f = a13
    Protected h32.f = a23
    Protected h33.f = 1.0

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected denom.f, u.f, v.f
    Protected u_int.i, v_int.i
    Protected offset_dst.i, offset_src.i

    ; --- Boucle de rendu ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        ; Transformation homographique inverse : (x,y) cible -> (u,v) source
        denom = h31 * x + h32 * y + h33

        If Abs(denom) > 0.0001
          u = (h11 * x + h12 * y + h13) / denom
          v = (h21 * x + h22 * y + h23) / denom

          u_int = Int(u)
          v_int = Int(v)

          If u_int >= 0 And u_int < lg And v_int >= 0 And v_int < ht
            offset_src = (v_int * lg + u_int) * 4
            PokeL(*cible + offset_dst, PeekL(*source + offset_src))
          Else
            PokeL(*cible + offset_dst, $00000000) ; Vide (Alpha 0)
          EndIf
        Else
          PokeL(*cible + offset_dst, $00000000)
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure PerspectiveHomographyEx(*FilterCtx.FilterParams)
  Restore PerspectiveHomography_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@PerspectiveHomography_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure PerspectiveHomography(source, cible, mask, x0=50, y0=50, x1=50, y1=50, x2=50, y2=50, x3=50, y3=50)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = x0 : \option[1] = y0 ; Coin Haut-Gauche
    \option[2] = x1 : \option[3] = y1 ; Coin Haut-Droit
    \option[4] = x2 : \option[5] = y2 ; Coin Bas-Droit
    \option[6] = x3 : \option[7] = y3 ; Coin Bas-Gauche
  EndWith
  PerspectiveHomographyEx(FilterCtx)
EndProcedure

DataSection
  PerspectiveHomography_Data:
  Data.s "PerspectiveHomography (probleme)"
  Data.s "Transformation perspective complète par homographie (matrice 3x3)"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "H-G X (%)" : Data.i 0, 100, 50
  Data.s "H-G Y (%)" : Data.i 0, 100, 50
  Data.s "H-D X (%)" : Data.i 0, 100, 50
  Data.s "H-D Y (%)" : Data.i 0, 100, 50
  Data.s "B-D X (%)" : Data.i 0, 100, 50
  Data.s "B-D Y (%)" : Data.i 0, 100, 50
  Data.s "B-G X (%)" : Data.i 0, 100, 50
  Data.s "B-G Y (%)" : Data.i 0, 100, 50
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 132
; FirstLine = 93
; Folding = -
; EnableXP
; DPIAware