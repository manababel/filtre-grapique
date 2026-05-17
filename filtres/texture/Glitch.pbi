; ==============================================================================
; FILTRE GLITCH - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Glitch_MT(*p.FilterParams)
  With *p
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected intensity = \option[0] ; [0–100] % déplacement max
    Protected noiseMax = \option[1]  ; Niveau de bruit maximum
    Protected sliceHeight = 4 + Random(8)

    ; --- Configuration Multithreading (macro_calcul_thread) ---
    Protected startY = (\thread_pos * ht) / \thread_max
    Protected stopY  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected j, x, x1 , x2 , y = startY
    Protected srcX, srcOffset, dstOffset
    Protected pix, r, g, b, a, noiseLevel

    ; --- Traitement principal ---
    While y <= stopY
      If y % sliceHeight = 0
        Protected offsetX = Random((lg * intensity) / 100) - (lg * intensity) / 200
        If offsetX = 0 : offsetX = 1 : EndIf
        
        ; --- Glitch horizontal décalé
        For j = 0 To sliceHeight - 1
          If y + j >= ht : Break : EndIf
          For x = 0 To lg - 1
            srcX = x + offsetX
            If srcX < 0 : srcX = 0 : ElseIf srcX >= lg : srcX = lg - 1 : EndIf
            srcOffset = ((y + j) * lg + srcX) * 4
            dstOffset = ((y + j) * lg + x) * 4
            PokeL(*cible + dstOffset, PeekL(*source + srcOffset))
          Next
        Next
        
        ; --- Ajout ligne horizontale bruitée
        If y + sliceHeight < ht
          Protected lineY = y + sliceHeight
          noiseLevel = Random(noiseMax) + (noiseMax / 2)
          
          For x = 0 To lg - 1
            srcOffset = (lineY * lg + x) * 4
            pix = PeekL(*source + srcOffset)
            a = (pix >> 24) & $FF
            
            x1 = x + 2
            x2 = x - 2
            Clamp(x1, 0, (lg - 1))
            Clamp(x2, 0, (lg - 1))
            
            ; Respect strict du mode d'accès aux canaux d'origine
            r = PeekA(*source + ((lineY * lg + x1) * 4 + 1)) ; R décalé
            g = PeekA(*source + ((lineY * lg + x2) * 4 + 2)) ; G décalé
            b = PeekA(*source + ((lineY * lg + x) * 4 + 3))  ; B normal
            
            ; Ajout du bruit
            r + Random(noiseLevel) - noiseLevel / 2 : Clamp(r, 0, 255)
            g + Random(noiseLevel) - noiseLevel / 2 : Clamp(g, 0, 255)
            b + Random(noiseLevel) - noiseLevel / 2 : Clamp(b, 0, 255)
            
            PokeL(*cible + srcOffset, RGBA(r, g, b, a))
          Next
        EndIf
        
        y + sliceHeight + 1 ; on saute après la ligne bruitée
      Else
        y + 1
      EndIf
    Wend
  EndWith
EndProcedure

Procedure GlitchEx(*FilterCtx.FilterParams)
  Restore Glitch_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Glitch_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Glitch(source, cible, mask, intensity=30, noise=32)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensity
    \option[1] = noise
  EndWith
  GlitchEx(FilterCtx)
EndProcedure

DataSection
  Glitch_Data:
  Data.s "Glitch"
  Data.s "Effet Glitch Numérique avec décalage horizontal et bruit chromatique"
  Data.i #FilterType_TexturePattern, #Artistic_Other
  Data.s "Intensité"      : Data.i 0, 100, 30
  Data.s "Niveau de bruit" : Data.i 0, 128, 32
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 89
; FirstLine = 57
; Folding = -
; EnableXP
; DPIAware