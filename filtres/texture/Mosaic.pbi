; ==============================================================================
; FILTRE MOSAIC - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Mosaic_MT(*p.FilterParams)
  With *p
    ; --- Déclaration des variables ---
    Protected start, stop, y, x, xx, yy
    
    ; --- Lecture des paramètres via la nouvelle structure ---
    Protected pixSize = \option[0]
    If pixSize < 1 : pixSize = 8 : EndIf
    
    Protected *source = \addr[0]
    Protected *cible = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected pix, srcOffset, dstOffset

    ; ============================================================================
    ; CONFIGURATION MULTITHREADING (macro_calcul_thread)
    ; ============================================================================
    
    start = (\thread_pos * ht) / \thread_max
    stop  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stop > ht - 1 : stop = ht - 1 : EndIf

    ; Alignement sur la taille des blocs pour éviter les déchirures visuelles
    start - Mod(start, pixSize)
    stop  - Mod(stop, pixSize)

    ; ============================================================================
    ; TRAITEMENT PRINCIPAL
    ; ============================================================================
    
    y = start
    While y <= stop
      x = 0
      While x < lg
        ; Calcul de l'offset source
        srcOffset = *source + (y * lg + x) * 4
        pix = PeekL(srcOffset)

        ; Définition des limites du bloc
        Protected blockBottom = y + pixSize - 1
        If blockBottom > ht - 1 : blockBottom = ht - 1 : EndIf
        Protected blockRight = x + pixSize - 1
        If blockRight > lg - 1 : blockRight = lg - 1 : EndIf

        ; Remplissage du bloc dans la cible
        For yy = y To blockBottom
          For xx = x To blockRight
            dstOffset = *cible + (yy * lg + xx) * 4
            PokeL(dstOffset, pix)
          Next
        Next

        x + pixSize
      Wend
      y + pixSize
    Wend
  EndWith
EndProcedure

Procedure MosaicEx(*FilterCtx.FilterParams)
  Restore Mosaic_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Mosaic_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Mosaic(source, cible, mask, pixSize=8)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = pixSize
  EndWith
  MosaicEx(FilterCtx)
EndProcedure

DataSection
  Mosaic_Data:
  Data.s "Mosaic"
  Data.s "Effet de pixelisation en blocs"
  Data.i #FilterType_TexturePattern, #Artistic_Other
  Data.s "Taille des blocs" : Data.i 1, 32, 8
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 75
; FirstLine = 41
; Folding = -
; EnableXP
; DPIAware