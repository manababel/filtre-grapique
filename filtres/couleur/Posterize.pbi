; ----------------------------------------------------------------------------------
; Procédure thread pour l'effet Posterize
; ----------------------------------------------------------------------------------

Procedure Posterize_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected i, pixel, a, r, g, b
    Protected totalPixels = \image_lg[0] * \image_ht[0]
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    
    ; Calcul des segments de thread selon la structure d'origine
    Protected startPos = (\thread_pos * totalPixels) / \thread_max
    Protected endPos   = ((\thread_pos + 1) * totalPixels) / \thread_max
    
    *srcPixel = *source + (startPos << 2)
    *dstPixel = *cible + (startPos << 2)
    
    For i = startPos To endPos - 1
      pixel = *srcPixel\l
      getargb(pixel, a, r, g, b)
      
      ; Lookup des valeurs posterisées (LUT stockées dans addr[2] à [4])
      r = PeekA(\addr[2] + r)
      g = PeekA(\addr[3] + g)
      b = PeekA(\addr[4] + b)
      
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure PosterizeEx(*FilterCtx.FilterParams)
  Restore Posterize_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected levelr = \option[0]  ; 2-256
    Protected levelg = \option[1]  ; 2-256
    Protected levelb = \option[2]  ; 2-256
    
    ; Clamp des niveaux
    If levelr < 2 : levelr = 2 : ElseIf levelr > 256 : levelr = 256 : EndIf
    If levelg < 2 : levelg = 2 : ElseIf levelg > 256 : levelg = 256 : EndIf
    If levelb < 2 : levelb = 2 : ElseIf levelb > 256 : levelb = 256 : EndIf
    
    ; Allocation des tables de lookup (LUT)
    \addr[2] = AllocateMemory(256)  ; LUT rouge
    \addr[3] = AllocateMemory(256)  ; LUT vert
    \addr[4] = AllocateMemory(256)  ; LUT bleu
    
    ; Précalcul des paliers pour chaque canal
    Protected i, stepR, stepG, stepB
    
    stepR = 256 / levelr
    stepG = 256 / levelg
    stepB = 256 / levelb
    
    ; Remplissage des tables de lookup
    For i = 0 To 255
      PokeA(\addr[2] + i, (i / stepR) * stepR)  ; Rouge
      PokeA(\addr[3] + i, (i / stepG) * stepG)  ; Vert
      PokeA(\addr[4] + i, (i / stepB) * stepB)  ; Bleu
    Next
    
    ; Lance le traitement multithread
    Create_MultiThread_MT(@Posterize_MT())
    
    ; Applique le masque si présent
    mask_update(*FilterCtx, last_data)
    
    ; Libération de la mémoire
    FreeMemory(\addr[2])
    FreeMemory(\addr[3])
    FreeMemory(\addr[4])
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Posterize(source, cible, mask, level_r, level_g, level_b)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = level_r
    \option[1] = level_g
    \option[2] = level_b
  EndWith
  PosterizeEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Posterize_Data:
  Data.s "Posterize"                                   ; Nom du filtre
  Data.s "Réduit le nombre de niveaux de couleur"      ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                                             ; Sous-type
  
  Data.s "Niveaux Rouge"                               ; Label option 0
  Data.i 2, 256, 16                                    ; Min, Max, Défaut
  
  Data.s "Niveaux Vert"                                ; Label option 1
  Data.i 2, 256, 16                                    ; Min, Max, Défaut
  
  Data.s "Niveaux Bleu"                                ; Label option 2
  Data.i 2, 256, 16                                    ; Min, Max, Défaut
  
  Data.s "XXX"                                         ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 91
; FirstLine = 73
; Folding = -
; EnableXP
; DPIAware