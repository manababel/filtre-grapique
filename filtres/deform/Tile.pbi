; ==============================================================================
; FILTRE TILE (PIXELISATION / MOSAÏQUE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Tile_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected tile_x.i, tile_y.i
    Protected src_x.i, src_y.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Précalculs des paramètres ---
    Protected tilesX.i = \option[0]
    Protected tilesY.i = \option[1]
    
    ; Protections minimales
    If tilesX < 1 : tilesX = 1 : EndIf
    If tilesY < 1 : tilesY = 1 : EndIf

    ; Taille d'une tuile (en pixels réels)
    Protected tile_width.f  = lg / tilesX
    Protected tile_height.f = ht / tilesY

    ; --- Configuration Multithreading ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected offset_dst.i, offset_src.i
    Protected current_tile_y.i = -1
    Protected src_y_cached.i

    ; --- Traitement principal ---
    For y = startY To stopY
      ; Calcul de la ligne source (centre de la tuile verticale)
      tile_y = Int(y / tile_height)
      If tile_y >= tilesY : tile_y = tilesY - 1 : EndIf
      
      ; Optimisation : ne recalculer src_y que si on change de tuile verticale
      If tile_y <> current_tile_y
        src_y_cached = (tile_y * ht / tilesY) + (ht / tilesY / 2)
        If src_y_cached >= ht : src_y_cached = ht - 1 : EndIf
        current_tile_y = tile_y
      EndIf
      
      offset_dst = y * lg * 4

      For x = 0 To lg - 1
        ; Calcul de la colonne source (centre de la tuile horizontale)
        tile_x = Int(x / tile_width)
        If tile_x >= tilesX : tile_x = tilesX - 1 : EndIf
        
        src_x = (tile_x * lg / tilesX) + (lg / tilesX / 2)
        If src_x >= lg : src_x = lg - 1 : EndIf

        ; Échantillonnage du pixel central de la tuile et duplication
        offset_src = (src_y_cached * lg + src_x) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure TileEx(*FilterCtx.FilterParams)
  Restore Tile_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Tile_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Tile(source, cible, mask, tilesX=10, tilesY=10)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = tilesX ; Nombre de divisions horizontales
    \option[1] = tilesY ; Nombre de divisions verticales
  EndWith
  TileEx(FilterCtx)
EndProcedure

DataSection
  Tile_Data:
  Data.s "Tile"
  Data.s "Effet de pixelisation (mosaïque) par division en tuiles"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Tuiles Horiz." : Data.i 1, 100, 10
  Data.s "Tuiles Vert."  : Data.i 1, 100, 10
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 79
; FirstLine = 47
; Folding = -
; EnableXP
; DPIAware