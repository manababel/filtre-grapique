; ==============================================================================
; FILTRE GLASS (VERRE DÉPOLI) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Glass_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected offset_x.i, offset_y.i
    Protected src_x.i, src_y.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Configuration et Précalculs ---
    Protected intensity.i = \option[0]
    If intensity < 1 : intensity = 1 : EndIf

    Protected grain_size.i = \option[1]
    If grain_size < 1 : grain_size = 1 : EndIf

    Protected mode.i = \option[2] ; 0=aléa, 1=perlin, 2=cellule
    Protected seed.i = \option[3]

    ; --- Configuration Multithreading ---
    Protected startY.i = ((\thread_pos * ht) / \thread_max)
    Protected stopY.i  = (((\thread_pos + 1) * ht) / \thread_max - 1)
    If stopY > (ht - 1) : stopY = (ht - 1) : EndIf

    Protected offset_dst.i, offset_src.i
    Protected hash.i, grid_x.i, grid_y.i
    Protected frac_x.i, frac_y.i, random_int.i

    ; --- Traitement principal ---
    For y = startY To stopY
      offset_dst = (y * lg * 4)

      For x = 0 To (lg - 1)
        
        Select mode
          Case 0 ; ===== Mode aléatoire pur (bruit blanc) =====
            hash = ((x + seed) * 73856093 ! (y + seed) * 19349663)
            hash = ((hash * 1103515245 + 12345) & $7FFFFFFF)
            
            offset_x = ((hash % (intensity * 2 + 1)) - intensity)
            hash = ((hash * 1103515245 + 12345) & $7FFFFFFF)
            offset_y = ((hash % (intensity * 2 + 1)) - intensity)
            
          Case 1 ; ===== Mode Perlin-like (bruit doux) =====
            grid_x = (x / grain_size)
            grid_y = (y / grain_size)
            frac_x = (x % grain_size)
            frac_y = (y % grain_size)
            
            hash = ((grid_x + seed) * 73856093 ! (grid_y + seed) * 19349663)
            hash = ((hash * 1103515245 + 12345) & $7FFFFFFF)
            
            random_int = ((hash % (intensity * 2 + 1)) - intensity)
            
            offset_x = (random_int * (grain_size - frac_x) / grain_size)
            offset_y = (random_int * (grain_size - frac_y) / grain_size)
            
          Case 2 ; ===== Mode cellulaire (effet cristallin) =====
            grid_x = (x / grain_size)
            grid_y = (y / grain_size)
            
            hash = ((grid_x + seed) * 73856093 ! (grid_y + seed) * 19349663)
            hash = ((hash * 1103515245 + 12345) & $7FFFFFFF)
            
            offset_x = ((hash % (intensity * 2 + 1)) - intensity)
            hash = ((hash * 1103515245 + 12345) & $7FFFFFFF)
            offset_y = ((hash % (intensity * 2 + 1)) - intensity)
        EndSelect

        src_x = (x + offset_x)
        src_y = (y + offset_y)

        ; Vérification des limites avec Wrap (Bouclage)
        If src_x < 0 : src_x = ((src_x % lg) + lg) : ElseIf src_x >= lg : src_x = (src_x % lg) : EndIf
        If src_y < 0 : src_y = ((src_y % ht) + ht) : ElseIf src_y >= ht : src_y = (src_y % ht) : EndIf
        
        offset_src = ((src_y * lg + src_x) * 4)
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure GlassEx(*FilterCtx.FilterParams)
  Restore Glass_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Glass_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Glass(source, cible, mask, intensity=5, grain=3, mode=0, seed=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensity
    \option[1] = grain
    \option[2] = mode
    \option[3] = seed
  EndWith
  GlassEx(FilterCtx)
EndProcedure

DataSection
  Glass_Data:
  Data.s "Glass (Verre dépoli)"
  Data.s "Effet de verre texturé avec déplacement aléatoire des pixels"
  Data.i #FilterType_Deformation, 0
  Data.s "Intensité (px)" : Data.i 0, 100, 5
  Data.s "Taille de grain" : Data.i 1, 100, 3
  Data.s "Mode (0:Aléatoire, 1:Perlin, 2:Cellule)" : Data.i 0, 2, 0
  Data.s "Graine (0-1000)" : Data.i 0, 1000, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 101
; FirstLine = 73
; Folding = -
; EnableXP
; DPIAware