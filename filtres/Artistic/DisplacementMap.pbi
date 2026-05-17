;==============================================================================
; DISPLACEMENT MAP - STRUCTURE RÉVISÉE
;==============================================================================

Procedure DisplacementMap_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src  = \addr[0]
    Protected *dst  = \addr[1]
    Protected *disp = \addr[2] ; L'image de déplacement (mix)
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    
    Protected intensity.f = \option[0] * 0.5
    Protected offsetX.f   = ((\option[1] - 100) * lg) / 100
    Protected offsetY.f   = ((\option[2] - 100) * ht) / 100
    Protected wrapMode    = \option[3] ; 0 = clamp, 1 = wrap
    
    Protected startY = (\thread_pos * ht) / \thread_max
    Protected stopY  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf
    
    Protected x, y, offsetDst, offsetDisp, dispColor
    Protected srcX.f, srcY.f, dispXPos.f, dispYPos.f
    Protected dispX, dispY
    
    For y = startY To stopY
      For x = 0 To lg - 1
        dispXPos = x + offsetX
        dispYPos = y + offsetY
        
        If wrapMode = 0
          ; Clamp
          If dispXPos < 0 : dispXPos = 0 : ElseIf dispXPos > lg - 1 : dispXPos = lg - 1 : EndIf
          If dispYPos < 0 : dispYPos = 0 : ElseIf dispYPos > ht - 1 : dispYPos = ht - 1 : EndIf
        Else
          ; Wrap (Modulo)
          dispXPos = Mod(dispXPos, lg)
          If dispXPos < 0 : dispXPos + lg : EndIf
          dispYPos = Mod(dispYPos, ht)
          If dispYPos < 0 : dispYPos + ht : EndIf
        EndIf
        
        offsetDisp = (Int(dispYPos) * lg + Int(dispXPos)) << 2
        dispColor = PeekL(*disp + offsetDisp)
        
        ; Utiliser Rouge et Vert comme vecteurs de déplacement (-128 à 127)
        dispX = ((dispColor >> 16) & $FF) - 128
        dispY = ((dispColor >> 8) & $FF) - 128
        
        srcX = x + (dispX / 128.0) * intensity
        srcY = y + (dispY / 128.0) * intensity
        
        ; Clamp final pour la lecture source
        If srcX < 0 : srcX = 0 : ElseIf srcX > lg - 1 : srcX = lg - 1 : EndIf
        If srcY < 0 : srcY = 0 : ElseIf srcY > ht - 1 : srcY = ht - 1 : EndIf
        
        offsetDst = (y * lg + x) << 2
        ; Utilise BilinearSample (doit être définie dans le code global)
        PokeL(*dst + offsetDst, BilinearSample(*src, lg, ht, srcX, srcY))
      Next
    Next
  EndWith
EndProcedure

Procedure DisplacementMapEx(*FilterCtx.FilterParams)
  Restore DisplacementMap_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Sécurité : On vérifie si l'image de mixage est présente
    If \addr[2] = 0
      Debug "Erreur: Image de déplacement manquante (\addr[2])"
      ProcedureReturn 0
    EndIf
    
    Create_MultiThread_MT(@DisplacementMap_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure DisplacementMap(source, cible, displacement, mask, intensity=50, offX=100, offY=100, wrap=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mix(displacement) ; Charge l'image de déplacement dans \addr[2]
  Set_Mask(mask)
  
  With FilterCtx
    \option[0] = intensity
    \option[1] = offX
    \option[2] = offY
    \option[3] = wrap
  EndWith
  DisplacementMapEx(FilterCtx)
EndProcedure

DataSection
  DisplacementMap_Data:
  Data.s "Displacement Map (marche pas)"
  Data.s "Déformation par image (R=X, V=Y). Nécessite une image de mixage."
  Data.i #FilterType_Artistic, #Artistic_Other
  Data.s "Intensité"      : Data.i 0, 500, 50
  Data.s "Offset X Map"   : Data.i 0, 200, 100
  Data.s "Offset Y Map"   : Data.i 0, 200, 100
  Data.s "Mode (0=Clamp/1=Wrap)" : Data.i 0, 1, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 98
; FirstLine = 55
; Folding = -
; EnableXP
; DPIAware