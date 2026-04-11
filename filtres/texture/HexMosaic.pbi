Procedure HexMosaic_MT(*p.parametre)
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected hexSize = *p\option[0]
  If hexSize < 4 : hexSize = 8 : EndIf

  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  Protected hexWidth  = 2 * hexSize
  Protected hexHeight = Int(Sqr(3) * hexSize)
  Protected stepX     = Int(hexWidth * 3 / 4)
  Protected stepY     = Int(hexHeight / 2)

  Protected cx, cy, offset
  Protected r, g, b, a, count, pix
  Protected i, j, x, y, px, py

  y = startY
  While y <= stopY
    x = 0
    While x < lg
      If (x / stepX) % 2 = 1
        cy = y + stepY
      Else
        cy = y
      EndIf
      cx = x

      ; Moyenne des couleurs
      r = 0
      g = 0
      b = 0
      a = 0
      count = 0
      For j = -hexSize To hexSize
        For i = -hexSize To hexSize
          If Sqr(i*i + j*j) <= hexSize
            px = cx + i
            py = cy + j
            If px >= 0 And px < lg And py >= 0 And py < ht
              offset = (py * lg + px) * 4
              pix = PeekL(*source + offset)
              r + (pix & $FF)
              g + ((pix >> 8) & $FF)
              b + ((pix >> 16) & $FF)
              a + ((pix >> 24) & $FF)
              count + 1
            EndIf
          EndIf
        Next
      Next

      If count > 0
        r / count : g / count : b / count : a / count
        pix = RGBA(r, g, b, a)

        ; Remplissage
        For j = -hexSize To hexSize
          For i = -hexSize To hexSize
            If Sqr(i*i + j*j) <= hexSize
              px = cx + i
              py = cy + j
              If px >= 0 And px < lg And py >= 0 And py < ht
                offset = (py * lg + px) * 4
                PokeL(*cible + offset, pix)
              EndIf
            EndIf
          Next
        Next
      EndIf

      x + stepX
    Wend
    y + stepY
  Wend
EndProcedure



Procedure HexMosaic(*param.parametre)
  If param\info_active
    param\typ = #FilterType_TexturePattern
    param\name = "HexMosaic"
    param\remarque = "Effet mosaïque hexagonal"
    param\info[0] = "Taille"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 4 : param\info_data(0,1) = 64 : param\info_data(0,2) = 12
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2 : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf

  filter_start(@HexMosaic_MT(), 1, 1)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 91
; FirstLine = 37
; Folding = -
; EnableXP
; DPIAware