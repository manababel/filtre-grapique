Procedure Glitch_MT(*p.parametre)
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected intensity = *p\option[0] ; [0–100] % déplacement max
  Protected sliceHeight = 4 + Random(8)

  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  Protected j, x, x1 , x2 , y = startY
  Protected srcX, srcOffset, dstOffset
  Protected pix, r, g, b, a, noiseLevel

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
        noiseLevel = Random(32) + 16 ; Niveau de bruit (plus = plus intense)
        
        For x = 0 To lg - 1
          srcOffset = (lineY * lg + x) * 4
          pix = PeekL(*source + srcOffset)
          a = (pix >> 24) & $FF
          
          x1 = x + 2
          x2 = x - 2
          Clamp(x1, 0, (lg - 1))
          Clamp(x2, 0, (lg - 1))
          r = PeekA(*source + ((lineY * lg + x1) * 4 + 1)) ; R décalé
          g = PeekA(*source + ((lineY * lg + x2) * 4 + 2)) ; G décalé
          b = PeekA(*source + ((lineY * lg + x) * 4 + 3))                       ; B normal
          
          ; Ajouter un peu de bruit si tu veux
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
EndProcedure

Procedure Glitch(*param.parametre)
  If param\info_active
    param\typ = #FilterType_TexturePattern
    param\name = "GlitchEffect"
    param\remarque = "Effet Glitch Numérique"
    param\info[0] = "Intensité"
    param\info[1] = "Niveau de bruit"
    param\info[2] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 30
    param\info_data(1,0) = 0 : param\info_data(1,1) = 128 : param\info_data(1,2) = 32
    param\info_data(2,0) = 0 : param\info_data(2,1) = 2 : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Glitch_MT(), 2, 1)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 81
; FirstLine = 23
; Folding = -
; EnableXP
; DPIAware