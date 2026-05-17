; ==============================================================================
; FILTRE TRANSLATE (TRANSLATION) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Translate_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected src_x.i, src_y.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalcul des décalages en pixels (centré sur 100%) ---
    Protected dx.i = ((\option[0] - 100) * lg) / 100
    Protected dy.i = ((\option[1] - 100) * ht) / 100

    ; Mode de gestion des bords (0=wrap/bouclage, 1=transparent)
    Protected mode.i = \option[2]

    ; --- Configuration Multithreading (macro_calcul_thread) ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        ; Calcul de la position source (backward mapping)
        src_x = x - dx
        src_y = y - dy

        ; Vérification des limites
        If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
          ; Position source valide
          offset_src = (src_y * lg + src_x) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          ; Position source hors limites
          If mode
            ; Mode transparent : noir transparent
            PokeL(*cible + offset_dst, $00000000)
          Else
            ; Mode wrap : bouclage (modulo sécurisé)
            If src_x >= lg : src_x = src_x % lg : EndIf
            If src_x < 0   : src_x = (src_x % lg) + lg : EndIf
            If src_y >= ht : src_y = src_y % ht : EndIf
            If src_y < 0   : src_y = (src_y % ht) + ht : EndIf
            
            offset_src = (src_y * lg + src_x) * 4
            PokeL(*cible + offset_dst, PeekL(*source + offset_src))
          EndIf
        EndIf

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure TranslateEx(*FilterCtx.FilterParams)
  Restore Translate_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Translate_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Translate(source, cible, mask, offsetX=100, offsetY=100, mode=1)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = offsetX
    \option[1] = offsetY
    \option[2] = mode
  EndWith
  TranslateEx(FilterCtx)
EndProcedure

DataSection
  Translate_Data:
  Data.s "Translate"
  Data.s "Déplacement de l'image avec mode wrap ou transparent"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Décalage X (100=neutre)" : Data.i 0, 200, 100
  Data.s "Décalage Y (100=neutre)" : Data.i 0, 200, 100
  Data.s "Mode (0=Wrap, 1=Transp)" : Data.i 0, 1, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 75
; FirstLine = 45
; Folding = -
; EnableXP
; DPIAware