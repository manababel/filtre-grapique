; ==============================================================================
; FILTRE IRREGULARHEXMOSAIC - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure.i PointDansPolygon(x.i, y.i, radius.f, sides.i, rotation.f)
  If sides < 3 : ProcedureReturn #False : EndIf
  
  Protected cosRot.f = Cos(rotation)
  Protected sinRot.f = Sin(rotation)
  
  Protected xRot.f = x * cosRot - y * sinRot
  Protected yRot.f = x * sinRot + y * cosRot
  
  Protected angle.f = ATan2(yRot, xRot)
  Protected dist.f = Sqr(xRot * xRot + yRot * yRot)
  
  Protected theta.f = 2 * #PI / sides
  Protected halfTheta.f = theta / 2
  
  angle = angle + #PI
  While angle >= theta
    angle - theta
  Wend
  While angle < 0
    angle + theta
  Wend
  angle - halfTheta
  
  Protected maxDist.f = Cos(halfTheta) / Cos(angle) * radius
  If dist <= maxDist
    ProcedureReturn 1
  Else
    ProcedureReturn 0
  EndIf
EndProcedure

Procedure IrregularHexMosaic_MT(*p.FilterParams)
  With *p
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    
    ; --- Lecture des paramètres ---
    Protected hexSize = \option[0]
    If hexSize < 4 : hexSize = 4 : EndIf
    Protected alpha = \option[4]
    clamp(alpha , 0 , 255)
    Protected inv_alpha = 255 - alpha
    Protected rotationRad.f = \option[3] * #PI / 180
    Protected sides = \option[2]
    Protected alpha2 = \option[6]
    clamp(alpha2 , 0 , 255)
    If sides < 3 : sides = 3 : EndIf
    
    ; Pré-calcul du masque polygonal
    Protected Dim polyMask(hexSize * 2 + 1, hexSize * 2 + 1)
    Protected i, j, x, y, px, py
    For j = -hexSize To hexSize
      For i = -hexSize To hexSize
        If PointDansPolygon(i, j, hexSize, sides, rotationRad)
          polyMask(i + hexSize, j + hexSize) = 1
        EndIf
      Next
    Next
    
    ; Configuration Multithreading
    Protected startY = (\thread_pos * ht) / \thread_max
    Protected stopY  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf
    
    Protected hexWidth  = 2 * hexSize
    Protected hexHeight = Int(Sqr(3) * hexSize)
    Protected stepX     = Int(hexWidth * 3 / 4)
    Protected stepY     = Int(hexHeight / 2)
    
    Protected cx, cy, offset
    Protected r, g, b, a, count, pix ,pix2
    Protected a1 , r1, g1, b1, r2 , g2 , b2
    Protected jitter = (hexSize * \option[1]) / 100
    If jitter > hexSize : jitter = hexSize : EndIf
    
    ; --- Traitement principal ---
    y = startY
    While y <= stopY
      x = 0
      While x < lg
        cx = x + Random(jitter * 2) - jitter
        cy = y + Random(jitter * 2) - jitter
        
        r = 0 : g = 0 : b = 0 : a = 0 : count = 0
        For j = -hexSize To hexSize
          For i = -hexSize To hexSize
            If polyMask(i + hexSize, j + hexSize)
              px = cx + i
              py = cy + j
              If px >= 0 And px < lg And py >= 0 And py < ht
                offset = (py * lg + px) * 4
                pix = PeekL(*source + offset)
                getargb(pix , a1 , r1 , g1 , b1)
                r + r1
                g + g1
                b + b1
                a + a1
                count + 1
              EndIf
            EndIf
          Next
        Next
        
        If count > 0
          r / count : g / count : b / count : a / count
          pix = ( (a << 24) | (r << 16) | (g << 8) | b )
          
          For j = -hexSize To hexSize
            For i = -hexSize To hexSize
              If polyMask(i + hexSize, j + hexSize)
                px = cx + i
                py = cy + j
                If px >= 0 And px < lg And py >= 0 And py < ht
                  offset = (py * lg + px) * 4
                  
                  Protected onEdge = 0
                  If \option[5]
                    If Not polyMask(i + 1 + hexSize, j + hexSize) Or
                       Not polyMask(i - 1 + hexSize, j + hexSize) Or
                       Not polyMask(i + hexSize, j + 1 + hexSize) Or
                       Not polyMask(i + hexSize, j - 1 + hexSize)
                      onEdge = 1
                    EndIf
                  EndIf
                  
                  If onEdge
                    If alpha2
                      pix2 = PeekL(*cible  + offset)
                      getrgb(pix2 , r2 , g2 , b2)
                      r = (r2 * alpha2) >> 8
                      g = (g2 * alpha2) >> 8
                      b = (b2 * alpha2) >> 8
                      PokeL(*cible + offset, (a << 24) | (r << 16) | (g << 8) | b)   
                    Else
                      PokeL(*cible + offset, RGBA(0, 0, 0, 255))
                    EndIf
                  Else
                    If alpha
                      pix2 = PeekL(*cible  + offset)
                      getrgb(pix2 , r2 , g2 , b2)
                      getARGB(pix , a , r1 , g1 , b1)
                      r = (r1 * inv_alpha + r2 * alpha) >> 8
                      g = (g1 * inv_alpha + g2 * alpha) >> 8
                      b = (b1 * inv_alpha + b2 * alpha) >> 8
                      PokeL(*cible + offset, (a << 24) | (r << 16) | (g << 8) | b)
                    Else
                      PokeL(*cible + offset, pix)
                    EndIf
                  EndIf
                EndIf
              EndIf
            Next
          Next
        EndIf
        
        x + stepX
      Wend
      y + stepY
    Wend
    FreeArray(polyMask())
  EndWith
EndProcedure

Procedure IrregularHexMosaicEx(*FilterCtx.FilterParams)
  Restore IrregularHex_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@IrregularHexMosaic_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure IrregularHexMosaic(source, cible, mask, size=12, jitter=50, sides=6, rot=0, alpha=0, edges=0, alpha_edges=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = size
    \option[1] = jitter
    \option[2] = sides
    \option[3] = rot
    \option[4] = alpha
    \option[5] = edges
    \option[6] = alpha_edges
  EndWith
  IrregularHexMosaicEx(FilterCtx)
EndProcedure

DataSection
  IrregularHex_Data:
  Data.s "IrregularHex"
  Data.s "Effet mosaïque hexagonal irrégulier"
  Data.i #FilterType_TexturePattern, #Artistic_Other
  Data.s "Taille des cellules" : Data.i 4, 64, 12
  Data.s "Taux d’irrégularité" : Data.i 0, 100, 50
  Data.s "Nombre de côtés"    : Data.i 3, 12, 6
  Data.s "Rotation"           : Data.i 0, 360, 0
  Data.s "Alpha"              : Data.i 0, 255, 0
  Data.s "Contours"           : Data.i 0, 1, 0
  Data.s "Alpha Contours"      : Data.i 0, 255, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 181
; FirstLine = 159
; Folding = -
; EnableXP
; DPIAware