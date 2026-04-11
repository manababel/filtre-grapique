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

Procedure IrregularHexMosaic_MT(*p.parametre)
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected hexSize = *p\option[0]
  If hexSize < 4 : hexSize = 4 : EndIf
  Protected alpha = *p\option[4]
  clamp(alpha , 0 , 255)
  Protected inv_alpha = 255 - alpha
  Protected rotationRad.f = *p\option[3] * #PI / 180
  Protected sides = *p\option[2]
  Protected alpha2 = *p\option[6]
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
  
  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf
  
  Protected hexWidth  = 2 * hexSize
  Protected hexHeight = Int(Sqr(3) * hexSize)
  Protected stepX     = Int(hexWidth * 3 / 4)
  Protected stepY     = Int(hexHeight / 2)
  
  Protected cx, cy, offset
  Protected r, g, b, a, count, pix ,pix2
  Protected a1 , r1, g1, b1, r2 , g2 , b2
  Protected jitter = (hexSize * *p\option[1]) / 100
  If jitter > hexSize : jitter = hexSize : EndIf
  
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
                If *p\option[5]
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
EndProcedure



Procedure IrregularHexMosaic(*param.parametre)
  If param\info_active
    param\typ = #FilterType_TexturePattern
    param\name = "IrregularHex"
    param\remarque = "Effet mosaïque hexagonal irrégulier"
    param\info[0] = "Taille des cellules"
    param\info[1] = "Taux d’irrégularité"
    param\info[2] = "Nombre de côtés"
    param\info[3] = "Rotation"
    param\info[4] = "Alpha"
    param\info[5] = "Contours"
    param\info[6] = "Alpha Contours"
    param\info[7] = "Masque binaire"
    param\info_data(0,0) = 4 : param\info_data(0,1) = 64  : param\info_data(0,2) = 12
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 3 : param\info_data(2,1) = 12  : param\info_data(2,2) = 6
    param\info_data(3,0) = 0 : param\info_data(3,1) = 360 : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 1   : param\info_data(5,2) = 0
    param\info_data(6,0) = 0 : param\info_data(6,1) = 255 : param\info_data(6,2) = 0
    param\info_data(7,0) = 0 : param\info_data(7,1) = 2   : param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@IrregularHexMosaic_MT(), 7, 1)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 183
; FirstLine = 129
; Folding = -
; EnableXP
; DPIAware