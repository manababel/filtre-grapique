Procedure Mosaic_MT(*p.parametre)
  Protected start, stop, y, x, xx, yy
  Protected pixSize = *p\option[0]
  If pixSize < 1 : pixSize = 8 : EndIf
  
  Protected *source = *p\addr[0]
  Protected *cible = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected pix, srcOffset, dstOffset

  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf

  start - Mod(start, pixSize)
  stop  - Mod(stop, pixSize)

  y = start
  While y <= stop
    x = 0
    While x < lg
      srcOffset = *source + (y * lg + x) * 4
      pix = PeekL(srcOffset)

      Protected blockBottom = y + pixSize - 1
      If blockBottom > ht - 1 : blockBottom = ht - 1 : EndIf
      Protected blockRight = x + pixSize - 1
      If blockRight > lg - 1 : blockRight = lg - 1 : EndIf

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
EndProcedure

Procedure Mosaic(*param.parametre)
  If param\info_active
    param\typ = #FilterType_TexturePattern
    param\name = "Mosaic"
    param\remarque = "Effet de pixelisation en blocs"
    param\info[0] = "Taille des blocs"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 32 : param\info_data(0,2) = 8
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2 : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf

  filter_start(@Mosaic_MT(), 1, 1)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 51
; Folding = -
; EnableXP
; DPIAware