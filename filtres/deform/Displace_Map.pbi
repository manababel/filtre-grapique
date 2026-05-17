; ==============================================================================
; FILTRE DISPLACE MAP (CARTE DE DÉPLACEMENT) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure DisplaceMap_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected displace_x.f, displace_y.f
    Protected src_x.i, src_y.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected *displace.Long = \addr[2] ; La carte doit être passée dans addr[2]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Sécurité : Si aucune carte n'est fournie, copie simple ---
    If *displace = 0
      For y = (\thread_pos * ht) / \thread_max To ((\thread_pos + 1) * ht) / \thread_max - 1
        If y > (ht - 1) : Break : EndIf
        CopyMemory(*source + (y * lg * 4), *cible + (y * lg * 4), lg * 4)
      Next
      ProcedureReturn
    EndIf

    ; --- Configuration et Précalculs ---
    Protected intensity_x.f = ((\option[0] - 100.0) / 100.0)
    Protected intensity_y.f = ((\option[1] - 100.0) / 100.0)
    Protected channel_x.i   = \option[2]
    Protected channel_y.i   = \option[3]
    Protected wrap_mode.i   = \option[4]
    
    Protected max_displacement.f = (Sqr(lg * lg + ht * ht) * 0.5)

    ; --- Configuration Multithreading ---
    Protected startY.i = ((\thread_pos * ht) / \thread_max)
    Protected stopY.i  = (((\thread_pos + 1) * ht) / \thread_max - 1)
    If stopY > (ht - 1) : stopY = (ht - 1) : EndIf

    ; Variables de boucle
    Protected offset_dst.i, offset_src.i, offset_disp.i
    Protected pixel_disp.l
    Protected r.i, g.i, b.i
    Protected value_x.f, value_y.f
    Protected temp_x.i, temp_y.i

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst  = (y * lg * 4)
      offset_disp = (y * lg * 4)

      For x = 0 To (lg - 1)
        ; Lecture de la carte de déplacement
        pixel_disp = PeekL(*displace + offset_disp)
        
        ; Extraction RGB (format Little Endian supposé BBGGRRAA ou sim.)
        r = (pixel_disp >> 16) & $FF
        g = (pixel_disp >> 8) & $FF
        b = pixel_disp & $FF

        ; Calcul de la valeur normalisée (-1.0 à 1.0) pour X
        Select channel_x
          Case 0 : value_x = (r / 255.0) * 2.0 - 1.0 ; Rouge
          Case 1 : value_x = (g / 255.0) * 2.0 - 1.0 ; Vert
          Case 2 : value_x = (b / 255.0) * 2.0 - 1.0 ; Bleu
          Case 3 : value_x = ((r + g + b) / 765.0) * 2.0 - 1.0 ; Luminosité
        EndSelect

        ; Calcul de la valeur normalisée pour Y
        Select channel_y
          Case 0 : value_y = (r / 255.0) * 2.0 - 1.0
          Case 1 : value_y = (g / 255.0) * 2.0 - 1.0
          Case 2 : value_y = (b / 255.0) * 2.0 - 1.0
          Case 3 : value_y = ((r + g + b) / 765.0) * 2.0 - 1.0
        EndSelect

        ; Calcul des coordonnées cibles
        src_x = x + Int(value_x * intensity_x * max_displacement)
        src_y = y + Int(value_y * intensity_y * max_displacement)

        ; --- Gestion du Wrap Mode ---
        Select wrap_mode
          Case 0 ; CLAMP
            If src_x < 0 : src_x = 0 : ElseIf src_x >= lg : src_x = (lg - 1) : EndIf
            If src_y < 0 : src_y = 0 : ElseIf src_y >= ht : src_y = (ht - 1) : EndIf
            
          Case 1 ; WRAP (Boucle)
            src_x % lg : If src_x < 0 : src_x + lg : EndIf
            src_y % ht : If src_y < 0 : src_y + ht : EndIf
            
          Case 2 ; MIRROR
            temp_x = src_x : temp_y = src_y
            ; Miroir X
            While temp_x < 0 Or temp_x >= lg
              If temp_x < 0 : temp_x = -temp_x - 1 : ElseIf temp_x >= lg : temp_x = (2 * lg - temp_x - 1) : EndIf
            Wend
            ; Miroir Y
            While temp_y < 0 Or temp_y >= ht
              If temp_y < 0 : temp_y = -temp_y - 1 : ElseIf temp_y >= ht : temp_y = (2 * ht - temp_y - 1) : EndIf
            Wend
            src_x = temp_x : src_y = temp_y
        EndSelect

        ; Échantillonnage final
        offset_src = (src_y * lg + src_x) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))

        offset_dst  + 4
        offset_disp + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure DisplaceMapEx(*FilterCtx.FilterParams)
  Restore DisplaceMap_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; On spécifie 5 options, 1 buffer destination et 1 buffer carte displacement (addr[2])
    Create_MultiThread_MT(@DisplaceMap_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure DisplaceMap(source, cible, displace_map, mask, intensityX=100, intensityY=100, chanX=0, chanY=1, wrap=1)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mix(displace_map)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensityX
    \option[1] = intensityY
    \option[2] = chanX
    \option[3] = chanY
    \option[4] = wrap
  EndWith
  DisplaceMapEx(FilterCtx)
EndProcedure

DataSection
  DisplaceMap_Data:
  Data.s "Carte de Déplacement (Displace Map) (marche pas)"
  Data.s "Déforme l'image en utilisant les couleurs d'une carte externe"
  Data.i #FilterType_Deformation, 0
  Data.s "Intensité X (0-200, 100=Neutre)" : Data.i 0, 200, 100
  Data.s "Intensité Y (0-200, 100=Neutre)" : Data.i 0, 200, 100
  Data.s "Canal X (0:R, 1:V, 2:B, 3:Lum)" : Data.i 0, 3, 0
  Data.s "Canal Y (0:R, 1:V, 2:B, 3:Lum)" : Data.i 0, 3, 1
  Data.s "Wrap (0:Clamp, 1:Wrap, 2:Mirror)" : Data.i 0, 2, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 142
; FirstLine = 100
; Folding = -
; EnableXP
; DPIAware