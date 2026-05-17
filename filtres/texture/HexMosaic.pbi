; ==============================================================================
; FILTRE HEXMOSAIC - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure HexMosaic_MT(*p.FilterParams)
  With *p
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected hexSize = \option[0]
    If hexSize < 4 : hexSize = 8 : EndIf

    ; --- Configuration Multithreading (macro_calcul_thread) ---
    Protected startY = (\thread_pos * ht) / \thread_max
    Protected stopY  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected hexWidth  = 2 * hexSize
    Protected hexHeight = Int(Sqr(3) * hexSize)
    Protected stepX     = Int(hexWidth * 3 / 4)
    Protected stepY     = Int(hexHeight / 2)

    Protected cx, cy, offset
    Protected r, g, b, a, count, pix
    Protected i, j, x, y, px, py

    ; --- Traitement principal ---
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

        ; --- Moyenne des couleurs ---
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

          ; --- Remplissage ---
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
  EndWith
EndProcedure

Procedure HexMosaicEx(*FilterCtx.FilterParams)
  Restore HexMosaic_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@HexMosaic_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure HexMosaic(source, cible, mask, hexSize=12)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = hexSize
  EndWith
  HexMosaicEx(FilterCtx)
EndProcedure

DataSection
  HexMosaic_Data:
  Data.s "HexMosaic"
  Data.s "Effet mosaïque hexagonal"
  Data.i #FilterType_TexturePattern, #Artistic_Other
  Data.s "Taille" : Data.i 4, 64, 12
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 117
; FirstLine = 66
; Folding = -
; EnableXP
; DPIAware