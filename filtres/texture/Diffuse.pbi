; ==============================================================================
; FILTRE DIFFUSE - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Diffuse_MT(*p.FilterParams)
  With *p
    ; --- Déclaration des variables ---
    Protected i, x, y, px, py, a, b, var, alpha
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected opt = \option[0]
    Protected totalPixels = lg * ht
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
  

    ; --- Clamp de l'option d'intensité ---
    Clamp(opt, 0, 256)

    ; --- Configuration Multithreading (macro_calcul_thread) ---
    Protected startPos = (\thread_pos * totalPixels) / \thread_max
    Protected endPos = ((\thread_pos + 1) * totalPixels) / \thread_max

    ; --- Traitement principal ---
    For i = startPos To endPos - 1
      ; Calcul des coordonnées du pixel courant
      y = i / lg
      x = i % lg
      
      ; Génération d'un décalage aléatoire dans un carré centré sur le pixel
      a = Random(opt) - (opt >> 1)
      b = Random(opt) - (opt >> 1)
      
      px = x + a
      py = y + b
      
      ; Clamp pour ne pas sortir des limites de l'image
      Clamp(px, 0, lg - 1)
      Clamp(py, 0, ht - 1)
      
      ; Récupération de la couleur source du pixel décalé
      var = PeekL(\addr[0] + ((py * lg + px) << 2))
      
      ; Ecriture de la couleur dans la cible
      PokeL(\addr[1] + (i << 2), var)
    Next
  EndWith
EndProcedure

Procedure DiffuseEx(*FilterCtx.FilterParams)
  Restore Diffuse_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Diffuse_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Diffuse(source, cible, mask, intensite=1)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensite
  EndWith
  DiffuseEx(FilterCtx)
EndProcedure

DataSection
  Diffuse_Data:
  Data.s "Diffuse"
  Data.s "Effet de diffusion (flou de déplacement aléatoire)"
  Data.i #FilterType_TexturePattern, #Artistic_Other
  Data.s "intensité" : Data.i 0, 256, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 14
; Folding = -
; EnableXP
; DPIAware