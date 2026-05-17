; =============================================================================
; DILATE - STRUCTURE RÉVISÉE
; =============================================================================

Procedure DilateEffect_MT(*p.FilterParams)
  With *p
    Protected *src = \addr[0]
    Protected *dst = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    
    ; Calcul de la plage de lignes
    Protected startY = (\thread_pos * ht) / \thread_max
    Protected stopY  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf
    
    ; Rayon du noyau : Option 0 (0 à 4) -> Radius (1 à 5)
    ; Radius 1 = 3x3, Radius 2 = 5x5, etc.
    Protected radius = \option[0] + 1
    
    Protected x, y, nx, ny, pix
    Protected srcOffset, dstOffset
    Protected maxR, maxG, maxB, maxA
    Protected r, g, b, a
    
    Protected minY, maxY, minX, maxX
    Protected htMinus1 = ht - 1
    Protected lgMinus1 = lg - 1
    
    For y = startY To stopY
      minY = y - radius : If minY < 0 : minY = 0 : EndIf
      maxY = y + radius : If maxY > htMinus1 : maxY = htMinus1 : EndIf
      
      For x = 0 To lgMinus1
        minX = x - radius : If minX < 0 : minX = 0 : EndIf
        maxX = x + radius : If maxX > lgMinus1 : maxX = lgMinus1 : EndIf
        
        maxR = 0 : maxG = 0 : maxB = 0 : maxA = 0
        
        ; Parcours du noyau
        For ny = minY To maxY
          srcOffset = ny * lg
          For nx = minX To maxX
            pix = PeekL(*src + ((srcOffset + nx) << 2))
            
            ; Extraction ARGB
            a = (pix >> 24) & $FF
            r = (pix >> 16) & $FF
            g = (pix >> 8) & $FF
            b = pix & $FF
            
            If r > maxR : maxR = r : EndIf
            If g > maxG : maxG = g : EndIf
            If b > maxB : maxB = b : EndIf
            If a > maxA : maxA = a : EndIf
          Next
        Next
        
        dstOffset = (y * lg + x) << 2
        PokeL(*dst + dstOffset, (maxA << 24) | (maxR << 16) | (maxG << 8) | maxB)
      Next
    Next
  EndWith
EndProcedure

Procedure DilateEx(*FilterCtx.FilterParams)
  Restore Dilate_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Ce filtre nécessite une copie source pour ne pas s'auto-polluer 
    ; pendant que les autres threads lisent les pixels originaux.
    ; Filter_InitAndValidate s'occupe normalement de la préparation des buffers.
    Create_MultiThread_MT(@DilateEffect_MT())
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Dilate(source, cible, mask, taille=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = taille
  EndWith
  DilateEx(FilterCtx)
EndProcedure

DataSection
  Dilate_Data:
  Data.s "Dilate"
  Data.s "Dilatation morphologique - Étend les zones claires de l'image."
  Data.i #FilterType_Artistic, #Artistic_Other
  Data.s "Taille noyau (0:3x3 à 4:11x11)" : Data.i 0, 4, 0
  Data.s "XXX" ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 80
; FirstLine = 46
; Folding = -
; EnableXP
; DPIAware