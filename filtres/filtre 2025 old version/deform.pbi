Procedure Ellipse_MT(*p.parametre)
  Protected start, stop
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  
  Protected cx.f = (*p\option[1] * lg) / 100
  Protected cy.f = (*p\option[2] * ht) / 100
  Protected rayon_x.f = (lg * *p\option[3]) / 100 + 10
  Protected rayon_y.f = (ht * *p\option[4]) / 100 + 10
  Protected force.f = (*p\option[0] - 200.0) / 100.0 
  
  Protected x, y
  Protected dx.f, dy.f, r.f, facteur.f
  Protected src_x.f, src_y.f
  Protected ligne_source, ligne_cible
  Protected pix.l
  
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = (( *p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    For x = 0 To lg - 1
      dx = (x - cx) / rayon_x
      dy = (y - cy) / rayon_y
      r = dx * dx + dy * dy
      
      If r <= 1.0
        facteur = Pow(Sin(Sqr(r) * #PI / 2), 1 + force)
        src_x = cx + dx * rayon_x * facteur
        src_y = cy + dy * rayon_y * facteur
      Else
        src_x = x
        src_y = y
      EndIf
      
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ligne_source = *source + (Int(src_y) * lg + Int(src_x)) * 4
        pix = PeekL(ligne_source)
      Else
        pix = 0
      EndIf
      
      ligne_cible = *cible + (y * lg + x) * 4
      PokeL(ligne_cible, pix)
    Next
  Next
EndProcedure


Procedure Ellipze(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Ellipze"
    param\remarque = "Déformation elliptique (lentille)"
    param\info[0] = "Force"
    param\info[1] = "PosX"
    param\info[2] = "PosY"
    param\info[3] = "Rayon X"
    param\info[4] = "Rayon Y"
    param\info[5] = "Masque binaire"
    param\info_data(0,0) = 0   : param\info_data(0,1) = 600 : param\info_data(0,2) = 200
    param\info_data(1,0) = 0   : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0   : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 0   : param\info_data(3,1) = 100 : param\info_data(3,2) = 50
    param\info_data(4,0) = 0   : param\info_data(4,1) = 100 : param\info_data(4,2) = 50
    param\info_data(5,0) = 0   : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Ellipse_MT() , 5)
EndProcedure

;-----------------------

Procedure FlipH_MT(*p.parametre)
  Protected start, stop, i
  Protected pix.l
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected y0 , y1
  
  start = ( *p\thread_pos * ht ) / *p\thread_max
  stop  = ( (*p\thread_pos + 1) * ht ) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht -1 : EndIf
  For y0 = start To stop
    y1 = ht - y0 - 1 
    CopyMemory(*p\addr[0] + y0 * lg * 4, *p\addr[1] + y1 * lg * 4, lg * 4)
  Next
EndProcedure


Procedure FlipH(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "FlipH"
    param\remarque = "Miroir horizontal"
    param\info[0] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 2 : param\info_data(0,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@FlipH_MT() , 0)
  
EndProcedure

;-----------------------

Procedure FlipV_MT(*p.parametre)
  Protected start, stop
  Protected pix.l
  Protected lg      = *p\lg
  Protected ht      = *p\ht
  Protected x, y, x0, x1
  Protected ligne_source, ligne_cible
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = (( *p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    ligne_source = *p\addr[0] + y * lg * 4
    ligne_cible  = *p\addr[1]  + y * lg * 4
    For x = 0 To lg - 1
      x0 = x
      x1 = lg - 1 - x
      pix = PeekL(ligne_source + x0 * 4)
      PokeL(ligne_cible  + x1 * 4, pix)
    Next
  Next
EndProcedure


Procedure FlipV(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "FlipV"
    param\remarque = "Miroir vertical"
    param\info[0] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 2 : param\info_data(0,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@FlipV_MT() , 0)
EndProcedure

;-----------------------

Procedure Lens_MT(*p.parametre)
  Protected start, stop
  Protected *source = *p\source
  Protected *cible  = *p\cible
  Protected lg = *p\lg
  Protected ht = *p\ht
  
  Protected cx.f = (*p\option[1] * lg) / 100
  Protected cy.f = (*p\option[2] * ht) / 100
  Protected rayon.f = ((Sqr(lg * lg + ht * ht) * *p\option[3]) / 100) + 1
  Protected zoom.f = *p\option[0] / 100.0
  
  Protected x, y
  Protected dx.f, dy.f, dist.f
  Protected factor.f
  Protected src_x.f, src_y.f
  Protected ligne_source, ligne_cible
  Protected pix.l
  
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = (( *p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    For x = 0 To lg - 1
      dx = x - cx
      dy = y - cy
      dist = Sqr(dx*dx + dy*dy)
      
      If dist < rayon And dist > 0
        factor = 1 + zoom * (1 - (dist / rayon))
        src_x = cx + dx / factor
        src_y = cy + dy / factor
      Else
        src_x = x
        src_y = y
      EndIf
      
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ligne_source = *source + (Int(src_y) * lg + Int(src_x)) * 4
        pix = PeekL(ligne_source)
      Else
        pix = 0
      EndIf
      
      ligne_cible = *cible + (y * lg + x) * 4
      PokeL(ligne_cible, pix)
    Next
  Next
EndProcedure

Procedure Lens(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Lens"
    param\remarque = "Effet loupe ou lentille"
    param\info[0] = "Zoom (%)"
    param\info[1] = "Centre X (%)"
    param\info[2] = "Centre Y (%)"
    param\info[3] = "Rayon (%)"
    param\info[4] = "Masque binaire"
    
    param\info_data(0,0) = -100 : param\info_data(0,1) = 300 : param\info_data(0,2) = 100
    param\info_data(1,0) = 0    : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0    : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 1    : param\info_data(3,1) = 100 : param\info_data(3,2) = 30
    param\info_data(4,0) = 0    : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Lens_MT() , 4)
EndProcedure

;-----------------------

Procedure Perspective_MT(*p.parametre)
  Protected x, y
  Protected sx.f, sy.f, u.f, v.f
  Protected *srcPixel.LONG, *dstPixel.LONG
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht

  Protected deltaX = lg / 2
  Protected deltaY = ht / 2
  
  Protected x00.f = deltaX * ((*p\option[0] - 50) / 50) + 0
  Protected y00.f = deltaY * ((*p\option[1] - 50) / 50) + 0
  
  Protected x10.f = deltaX * ((*p\option[2] - 50) / 50) + lg
  Protected y10.f = deltaY * ((*p\option[3] - 50) / 50) + 0
  
  Protected x01.f = deltaX * ((*p\option[4] - 50) / 50) + 0
  Protected y01.f = deltaY * ((*p\option[5] - 50) / 50) + ht
  
  Protected x11.f = deltaX * ((*p\option[6] - 50) / 50) + lg
  Protected y11.f = deltaY * ((*p\option[7] - 50) / 50) + ht
  
  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf
  
  For y = startY To stopY
    v = y / ht
    For x = 0 To lg - 1
      u = x / lg
      sx = (1 - u) * (1 - v) * x00 + u * (1 - v) * x10 + (1 - u) * v * x01 + u * v * x11
      sy = (1 - u) * (1 - v) * y00 + u * (1 - v) * y10 + (1 - u) * v * y01 + u * v * y11
      
      *dstPixel = *cible + (y * lg + x) * 4
      If sx >= 0 And sx < lg And sy >= 0 And sy < ht
        *srcPixel = *source + (Int(sy) * lg + Int(sx)) * 4
        *dstPixel\l = *srcPixel\l
      Else
        *dstPixel\l = 0
      EndIf
    Next
  Next
EndProcedure

Procedure.f Area2D(x1.f, y1.f, x2.f, y2.f, x3.f, y3.f)
  ProcedureReturn Abs((x2 - x1)*(y3 - y1) - (x3 - x1)*(y2 - y1)) / 2.0
EndProcedure

Procedure.b PointInQuad(x.f, y.f, Array  pts.f(1) )
  Protected A_x = pts(0), A_y = pts(1)
  Protected B_x = pts(2), B_y = pts(3)
  Protected C_x = pts(6), C_y = pts(7)
  Protected D_x = pts(4), D_y = pts(5)
  
  Protected areaQuad.f = Area2D(A_x, A_y, B_x, B_y, C_x, C_y) + Area2D(A_x, A_y, C_x, C_y, D_x, D_y)

  Protected areaSum.f , quadArea
  areaSum + Area2D(x, y, A_x, A_y, B_x, B_y)
  areaSum + Area2D(x, y, B_x, B_y, C_x, C_y)
  areaSum + Area2D(x, y, C_x, C_y, D_x, D_y)
  areaSum + Area2D(x, y, D_x, D_y, A_x, A_y)
  
  If Abs(quadArea - quadArea) < 0.5
    ProcedureReturn #True
  Else
    ProcedureReturn #False
  EndIf
EndProcedure


Procedure DrawTextureInQuad_MT(*param.parametre)

  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  
  Protected srcWidth = param\lg
  Protected srcHeight = param\ht
  Protected dstWidth = param\lg
  Protected dstHeight = param\ht
  
  Protected Dim ptsSrc.f(7)
  ptsSrc(0) = 0 : ptsSrc(1) = 0
  ptsSrc(2) = srcWidth - 1 : ptsSrc(3) = 0
  ptsSrc(4) = 0 : ptsSrc(5) = srcHeight - 1
  ptsSrc(6) = srcWidth - 1 : ptsSrc(7) = srcHeight - 1
  
  Protected Dim ptsDst.f(7)
  
  ptsDst(0) = ((param\option[0]) / 100.0) * (dstWidth - 1)
  ptsDst(1) = ((param\option[1]) / 100.0) * (dstHeight - 1)
  ptsDst(2) = ((param\option[2]) / 100.0) * (dstWidth - 1)
  ptsDst(3) = ((param\option[3]) / 100.0) * (dstHeight - 1)
  ptsDst(4) = ((param\option[4]) / 100.0) * (dstWidth - 1)
  ptsDst(5) = ((param\option[5]) / 100.0) * (dstHeight - 1)
  ptsDst(6) = ((param\option[6]) / 100.0) * (dstWidth - 1)
  ptsDst(7) = ((param\option[7]) / 100.0) * (dstHeight - 1)
  
  Protected Dim A.f(63)
  Protected Dim b.f(7)
  Protected Dim H.f(8)
  Protected xi.f, yi.f, xdi.f, ydi.f
  Protected i , k , j
  
  For i = 0 To 3
    xi = ptsSrc(i*2)
    yi = ptsSrc(i*2 + 1)
    xdi = ptsDst(i*2)
    ydi = ptsDst(i*2 + 1)

    A(2*i*8 + 0) = xi
    A(2*i*8 + 1) = yi
    A(2*i*8 + 2) = 1
    A(2*i*8 + 3) = 0
    A(2*i*8 + 4) = 0
    A(2*i*8 + 5) = 0
    A(2*i*8 + 6) = -xi * xdi
    A(2*i*8 + 7) = -yi * xdi
    b(2*i) = xdi

    A((2*i+1)*8 + 0) = 0
    A((2*i+1)*8 + 1) = 0
    A((2*i+1)*8 + 2) = 0
    A((2*i+1)*8 + 3) = xi
    A((2*i+1)*8 + 4) = yi
    A((2*i+1)*8 + 5) = 1
    A((2*i+1)*8 + 6) = -xi * ydi
    A((2*i+1)*8 + 7) = -yi * ydi
    b(2*i + 1) = ydi
  Next
  
  For i = 0 To 7
    Protected maxRow = i
    For  k = i + 1 To 7
      If Abs(A(k*8 + i)) > Abs(A(maxRow*8 + i)) : maxRow = k : EndIf
    Next
    If maxRow <> i
      For  j = 0 To 7
        Protected tmp.f = A(i*8 + j)
        A(i*8 + j) = A(maxRow*8 + j)
        A(maxRow*8 + j) = tmp
      Next
      tmp.f = b(i)
      b(i) = b(maxRow)
      b(maxRow) = tmp
    EndIf
    
    Protected pivot.f = A(i*8 + i)
    If pivot = 0.0 : ProcedureReturn : EndIf
    
    For  j = i To 7
      A(i*8 + j) / pivot
    Next
    b(i) / pivot
    
    For  k = 0 To 7
      If k <> i
        Protected factor.f = A(k*8 + i)
        For  j = i To 7
          A(k*8 + j) - factor * A(i*8 + j)
        Next
        b(k) - factor * b(i)
      EndIf
    Next
  Next
  
  For i = 0 To 7
    H(i) = b(i)
  Next
  H(8) = 1.0
  
  Protected denom.f, u.f, v.f
  Protected sx.l, sy.l, posSrc.l, posDst.l
  Protected x , y
  
  For y = 0 To dstHeight - 1
    For x = 0 To dstWidth - 1
      If PointInQuad(x, y, ptsDst())
        denom = H(6)*x + H(7)*y + H(8)
        If denom <> 0.0
          u = (H(0)*x + H(1)*y + H(2)) / denom
          v = (H(3)*x + H(4)*y + H(5)) / denom
          
          If u >= 0 And u < srcWidth And v >= 0 And v < srcHeight
            sx = Int(u)
            sy = Int(v)
            posSrc = (sy * srcWidth + sx) * 4
            posDst = (y * dstWidth + x) * 4
            PokeL((*cible) + posDst, PeekL((*source) + posSrc))
          Else
            posDst = (y * dstWidth + x) * 4
            PokeL((*cible) + posDst, $FF000000)
          EndIf
        EndIf
      Else
        posDst = (y * dstWidth + x) * 4
        PokeL((*cible) + posDst, $FF000000)
      EndIf
    Next
  Next
  
EndProcedure


Procedure Perspective(*param.parametre)
  Protected i
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Perspective"
    param\remarque = "Déformation quadrilatérale (4 coins)"
    
    param\info[0] = "Haut gauche X"
    param\info[1] = "Haut gauche Y"
    param\info[2] = "Haut droite X"
    param\info[3] = "Haut droite Y"
    param\info[4] = "Bas gauche X"
    param\info[5] = "Bas gauche Y"
    param\info[6] = "Bas droite X"
    param\info[7] = "Bas droite Y"
    param\info[8] = "Masque binaire"
    For i = 0 To 7
      param\info_data(i, 0) = 0
      param\info_data(i, 1) = 100
      param\info_data(i, 2) = 50
    Next
    
    param\info_data(8, 0) = 0 : param\info_data(8, 1) = 2 : param\info_data(8, 2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Perspective_MT() , 8)
EndProcedure

;-----------------------

Procedure Perspective4Borders_MT(*p.parametre)
  Protected start, stop
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  
  Protected tiltTop.f    = (*p\option[0] - 100) / 100.0
  Protected tiltBottom.f = (*p\option[1] - 100) / 100.0
  Protected tiltLeft.f   = (*p\option[2] - 100) / 100.0
  Protected tiltRight.f  = (*p\option[3] - 100) / 100.0
  Protected scaleGlobal.f = *p\option[4] / 100.0
  If scaleGlobal <= 0.01 : scaleGlobal = 0.01 : EndIf
  Protected shiftX.f = ((*p\option[5] - 100) * lg) /100
  Protected shiftY.f = ((*p\option[6] - 100) * ht) /100
  Protected angle.f = Radian(*p\option[7])
  Protected cosA.f = Cos(angle)
  Protected sinA.f = Sin(angle)  
  Clamp(tiltTop, -1.0, 1.0)
  Clamp(tiltBottom, -1.0, 1.0)
  Clamp(tiltLeft, -1.0, 1.0)
  Clamp(tiltRight, -1.0, 1.0)
  
  Protected y, x
  Protected u.f, v.f
  Protected scaleX.f, scaleY.f
  Protected src_x.f, src_y.f
  Protected ligne_source, ligne_cible
  Protected pix.l
  
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = (( *p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    v = y / (ht - 1)
    scaleX = 1.0 - ((1.0 - v) * tiltTop + v * tiltBottom)
    
    For x = 0 To lg - 1
      u = x / (lg - 1)
      scaleY = 1.0 - ((1.0 - u) * tiltLeft + u * tiltRight)
      
      If scaleX <= 0.01 : scaleX = 0.01 : EndIf
      If scaleY <= 0.01 : scaleY = 0.01 : EndIf
      
      Protected tmp_x.f, tmp_y.f
      
      tmp_x = ((x - (lg / 2)) / (scaleX * scaleGlobal)) + shiftX
      tmp_y = ((y - (ht / 2)) / (scaleY * scaleGlobal)) + shiftY
      
      src_x = tmp_x * cosA - tmp_y * sinA + (lg / 2)
      src_y = tmp_x * sinA + tmp_y * cosA + (ht / 2)
      
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ligne_source = *source + (Int(src_y) * lg + Int(src_x)) * 4
        pix = PeekL(ligne_source)
      Else
        pix = 0
      EndIf
      
      ligne_cible = *cible + (y * lg + x) * 4
      PokeL(ligne_cible, pix)
    Next
  Next
EndProcedure


Procedure Perspective2(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Perspective2"
    param\remarque = "Effet trapèze indépendant sur 4 bords"
    param\info[0] = "haut"
    param\info[1] = "bas"
    param\info[2] = "gauche"
    param\info[3] = "droite"
    param\info[4] = "Zoom"
    param\info[5] = "Pos X"
    param\info[6] = "Pos Y"
    param\info[7] = "Rotation"
    param\info[8] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 200 : param\info_data(0,2) = 100
    param\info_data(1,0) = 0 : param\info_data(1,1) = 200 : param\info_data(1,2) = 100
    param\info_data(2,0) = 0 : param\info_data(2,1) = 200 : param\info_data(2,2) = 100
    param\info_data(3,0) = 0 : param\info_data(3,1) = 200 : param\info_data(3,2) = 100
    param\info_data(4,0) = 0 : param\info_data(4,1) = 200 : param\info_data(4,2) = 100
    param\info_data(5,0) = 0 : param\info_data(5,1) = 200 : param\info_data(5,2) = 100
    param\info_data(6,0) = 0 : param\info_data(6,1) = 200 : param\info_data(6,2) = 100
    param\info_data(7,0) = 0 : param\info_data(7,1) = 360 : param\info_data(7,2) = 0
    param\info_data(8,0) = 0 : param\info_data(8,1) = 2   : param\info_data(8,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Perspective4Borders_MT() , 8)
EndProcedure

;-----------------------
;-----------------------
Procedure PerspectiveTrapezeLin_MT(*p.parametre)
  Protected x, y , x1.f , y1.f
  Protected sx.f, sy.f, u.f, v.f
  Protected *srcPixel.LONG, *dstPixel.LONG
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  
  Protected offsetY_Gauche.f = ((50.0 - *p\option[0]) / 50.0) * (ht * 0.5)
  Protected offsetY_Droite.f = ((50.0 - *p\option[1]) / 50.0) * (ht * 0.5)
  
  Protected offsetX_HautGauche.f  = ((50.0 - *p\option[2]) / 50.0) * (lg * 0.5)
  Protected offsetX_HautDroit.f   = -offsetX_HautGauche
  
  Protected offsetX_BasGauche.f   = ((50.0 - *p\option[3]) / 50.0) * (lg * 0.5)
  Protected offsetX_BasDroit.f    = -offsetX_BasGauche
  
  Protected x00.f = 0 + offsetX_HautGauche
  Protected y00.f = 0 - offsetY_Gauche
  
  Protected x10.f = (lg - 1) + offsetX_HautDroit
  Protected y10.f = 0 - offsetY_Droite
  
  Protected x01.f = 0 + offsetX_BasGauche
  Protected y01.f = (ht - 1) + offsetY_Gauche
  
  Protected x11.f = (lg - 1) + offsetX_BasDroit
  Protected y11.f = (ht - 1) + offsetY_Droite
  
  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf
  
  For y = startY To stopY
    v = y / (ht - 1)
    
    Protected borderLeftX  = x00 
    Protected borderLeftY  = y00 + v * (y01 - y00)
    
    Protected borderRightX = x10 
    Protected borderRightY = y10 + v * (y11 - y10)
    
    For x = 0 To lg - 1
      u = x / (lg - 1)
      
      sx = borderLeftX + u * (borderRightX - borderLeftX)
      sy = borderLeftY + u * (borderRightY - borderLeftY)
      
      *dstPixel = *cible + (y * lg + x) * 4
      
      If sx >= 0 And sx < lg And sy >= 0 And sy < ht
        *srcPixel = *source + (Int(sy) * lg + Int(sx)) * 4
        *dstPixel\l = *srcPixel\l
      Else
        *dstPixel\l = 0
      EndIf
    Next
  Next
EndProcedure

Procedure DrawTexturePerspective_MT(*p.parametre)
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected *srcPixel.LONG, *dstPixel.LONG
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected x, y

  Define.f x0 = ((*p\option[0] - 50.0) / 50.0) * (lg * 0.5) + 0
  Define.f y0 = ((*p\option[1] - 50.0) / 50.0) * (ht * 0.5) + 0
  
  Define.f x1 = ((*p\option[2] - 50.0) / 50.0) * (lg * 0.5) + (lg - 1)
  Define.f y1 = ((*p\option[3] - 50.0) / 50.0) * (ht * 0.5) + 0
  
  Define.f x2 = ((*p\option[4] - 50.0) / 50.0) * (lg * 0.5) + (lg - 1)
  Define.f y2 = ((*p\option[5] - 50.0) / 50.0) * (ht * 0.5) + (ht - 1)
  
  Define.f x3 = ((*p\option[6] - 50.0) / 50.0) * (lg * 0.5) + 0
  Define.f y3 = ((*p\option[7] - 50.0) / 50.0) * (ht * 0.5) + (ht - 1)
  
  Define.f dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3
  Define.f dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3
  
  Define.f det = dx1 * dy2 - dx2 * dy1
  If det = 0 : ProcedureReturn : EndIf
  
  Define.f a13 = (dx3 * dy2 - dx2 * dy3) / det
  Define.f a23 = (dx1 * dy3 - dx3 * dy1) / det
  
  Define.f h11 = x1 - x0 + a13 * x1
  Define.f h12 = x3 - x0 + a23 * x3
  Define.f h13 = x0
  Define.f h21 = y1 - y0 + a13 * y1
  Define.f h22 = y3 - y0 + a23 * y3
  Define.f h23 = y0
  Define.f h31 = a13
  Define.f h32 = a23
  Define.f h33 = 1.0

  Define startY = (*p\thread_pos * ht) / *p\thread_max
  Define stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf
  
  For y = startY To stopY
    For x = 0 To lg - 1
      X1 = x:Y1 = y
      Define.f denom = h31 * X1 + h32 * Y1 + h33
      If denom = 0 : Continue : EndIf
      
      Define.f u = (h11 * X1 + h12 * Y1 + h13) / denom
      Define.f v = (h21 * X1 + h22 * Y1 + h23) / denom

      If u >= 0 And u <= lg - 1 And v >= 0 And v <= ht - 1
        *dstPixel = *cible + (y * lg + x) * 4
        *srcPixel = *source + (Int(v) * lg + Int(u)) * 4
        *dstPixel\l = *srcPixel\l
      EndIf
    Next
  Next
EndProcedure

Procedure PerspectiveSimple(*param.parametre)
  Protected i
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "PerspectiveSimple"
    param\remarque = "Déformation simple : décalage gauche, droite, haut, bas"
    param\info[0] = "Décalage Gauche"
    param\info[1] = "Décalage Droite"
    param\info[2] = "Décalage Haut"
    param\info[3] = "Décalage Bas"
    param\info[4] = "Masque binaire"
    For i = 0 To 3
      param\info_data(i, 0) = 0
      param\info_data(i, 1) = 100
      param\info_data(i, 2) = 50 ; Valeur par défaut = 50%, pas de décalage
    Next
    param\info_data(4, 0) = 0 : param\info_data(4, 1) = 2 : param\info_data(4, 2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@PerspectiveTrapezeLin_MT() , 4)
EndProcedure
;-----------------------
;-----------------------

Procedure PinchBulge_MT(*p.parametre)
  Protected start, stop
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected cx.f = (*p\option[1] * lg) / 100
  Protected cy.f = (*p\option[2] * ht) / 100
  Protected rayon.f = ((Sqr(lg * lg + ht * ht) * *p\option[3]) / 100) + 1
  Protected force.f = (*p\option[0]) / 100.0 
  
  Protected x, y
  Protected dx.f, dy.f, dist.f, factor.f
  Protected src_x.f, src_y.f
  Protected ligne_source, ligne_cible
  Protected pix.l
  
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = (( *p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    For x = 0 To lg - 1
      dx = x - cx
      dy = y - cy
      dist = Sqr(dx * dx + dy * dy)
      
      If dist < rayon And dist > 0
        factor = Pow(dist / rayon, 1.0 - force)

        src_x = cx + dx * factor
        src_y = cy + dy * factor
      Else
        src_x = x
        src_y = y
      EndIf
      
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ligne_source = *source + (Int(src_y) * lg + Int(src_x)) * 4
        pix = PeekL(ligne_source)
      Else
        pix = 0
      EndIf
      
      ligne_cible = *cible + (y * lg + x) * 4
      PokeL(ligne_cible, pix)
    Next
  Next
EndProcedure

Procedure PinchBulge(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Pinch / Bulge"
    param\remarque = "Déformation en pincement ou bombement"
    param\info[0] = "Force (-100 à 100)"
    param\info[1] = "PosX (%)"
    param\info[2] = "PosY (%)"
    param\info[3] = "Rayon (%)"
    param\info[4] = "Masque binaire"
    param\info_data(0,0) = -100 : param\info_data(0,1) = 100 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0    : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0    : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 0    : param\info_data(3,1) = 100 : param\info_data(3,2) = 30
    param\info_data(4,0) = 0    : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@PinchBulge_MT() , 4)
EndProcedure

;-----------------------

Procedure Ripple_MT(*p.parametre)
  Protected start, stop
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  
  Protected amp_x.f = *p\option[0] / 1.0       ; Amplitude horizontale
  Protected period_x.f = (*p\option[1] / 100.0) * ht    ; Période horizontale
  
  Protected amp_y.f = *p\option[2] / 1.0       ; Amplitude verticale
  Protected period_y.f = (*p\option[3] / 100.0) * lg   ; Période verticale
  
  Protected x, y
  Protected offset_x.f, offset_y.f
  Protected src_x, src_y
  Protected ligne_source, ligne_cible
  Protected pix.l
  
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = (( *p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    For x = 0 To lg - 1
      offset_x = amp_x * Sin((y / period_x) * 2 * #PI)
      offset_y = amp_y * Sin((x / period_y) * 2 * #PI)
      
      src_x = x + offset_x
      src_y = y + offset_y
      
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ligne_source = *source + (Int(src_y) * lg + Int(src_x)) * 4
        pix = PeekL(ligne_source)
      Else
        pix = 0
      EndIf
      
      ligne_cible = *cible + (y * lg + x) * 4
      PokeL(ligne_cible, pix)
    Next
  Next
EndProcedure

Procedure Ripple(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Ripple"
    param\remarque = "Déformation sinusoïdale"
    param\info[0] = "Amplitude X"
    param\info[1] = "Période X"
    param\info[2] = "Amplitude Y"
    param\info[3] = "Période Y"
    param\info[4] = "Masque binaire"
    
    param\info_data(0,0) = 0   : param\info_data(0,1) = 100 : param\info_data(0,2) = 0
    param\info_data(1,0) = 1   : param\info_data(1,1) = 100 : param\info_data(1,2) = 1
    param\info_data(2,0) = 0   : param\info_data(2,1) = 100 : param\info_data(2,2) = 0
    param\info_data(3,0) = 1   : param\info_data(3,1) = 100 : param\info_data(3,2) = 1
    param\info_data(4,0) = 0   : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Ripple_MT() , 4)
EndProcedure

;-----------------------

Procedure Rotation_MT(*p.parametre)
  Protected x, y, sx, sy, dx.f, dy.f
  Protected pix.l
  Protected *srcPixel.LONG, *dstPixel.LONG
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  
  Protected angle.f = *p\option[0] * #PI / 180.0 ; Angle en radians
  Protected cosA.f = Cos(angle)
  Protected sinA.f = Sin(angle)
  
  Protected cx.f = *p\option[1] / 100 * lg
  Protected cy.f = *p\option[2] / 100 * ht
  
  Protected startY = ( *p\thread_pos * ht ) / *p\thread_max
  Protected stopY  = ( (*p\thread_pos + 1) * ht ) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht -1 : EndIf
  
  For y = startY To stopY
    For x = 0 To lg - 1
      ; Calcul position dans l'image source
      dx.f = x - cx
      dy.f = y - cy
      
      sx = Round( cosA * dx + sinA * dy + cx, #PB_Round_Nearest )
      sy = Round(-sinA * dx + cosA * dy + cy, #PB_Round_Nearest )
      
      If sx >= 0 And sx < lg And sy >= 0 And sy < ht
        *srcPixel = *source + (sy * lg + sx) * 4
        *dstPixel = *cible  + (y  * lg + x ) * 4
        *dstPixel\l = *srcPixel\l
      Else
        *dstPixel = *cible  + (y  * lg + x ) * 4
        *dstPixel\l = 0 ; Transparent ou noir
      EndIf
    Next
  Next
EndProcedure

Procedure Rotate(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Rotation"
    param\remarque = "Rotation d'image de 0 à 360°"
    param\info[0] = "Angle"
    param\info[1] = "PosX"
    param\info[2] = "PosY"
    param\info[3] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 360 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2 : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Rotation_MT() , 3)
EndProcedure

;-----------------------

Procedure Spherize_MT(*p.parametre)
  Protected start, stop
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected cx.f = (*p\option[1] * lg) / 100
  Protected cy.f = (*p\option[2] * ht) / 100
  Protected rayon.f = ((Sqr(lg * lg + ht * ht) * *p\option[3])/100) + 1

  Protected force.f = ((*p\option[0] - 200.0) / 100.0)
  Protected x, y
  Protected dx.f, dy.f, r.f, angle.f, facteur.f
  Protected src_x.f, src_y.f
  Protected pix.l
  Protected ligne_source, ligne_cible
  
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = (( *p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    For x = 0 To lg - 1
      dx = (x - cx) / rayon
      dy = (y - cy) / rayon
      r = Sqr(dx*dx + dy*dy)
      
      If r <= 1.0
        angle = r * #PI / 2
        facteur = Pow(Sin(angle), 1 + force)
        src_x = cx + dx * facteur * rayon
        src_y = cy + dy * facteur * rayon
      Else
        src_x = x
        src_y = y
      EndIf
      
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ligne_source = *source + (Int(src_y) * lg + Int(src_x)) * 4
        pix = PeekL(ligne_source)
      Else
        pix = 0
      EndIf
      
      ligne_cible = *cible + (y * lg + x) * 4
      PokeL(ligne_cible, pix)
    Next
  Next
EndProcedure

Procedure Spherize(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Spherize"
    param\remarque = "Effet lentille convexe ou concave"
    param\info[0] = "Force"
    param\info[1] = "PosX"
    param\info[2] = "PosY"
    param\info[3] = "Rayon"
    param\info[4] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 600 : param\info_data(0,2) = 100
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 0 : param\info_data(3,1) = 100 : param\info_data(3,2) = 50
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Spherize_MT() , 4)
EndProcedure

;-----------------------

Procedure Spiralize_MT(*p.parametre)
  Protected start, stop
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  
  Protected cx.f = (*p\option[1] * lg) / 100
  Protected cy.f = (*p\option[2] * ht) / 100
  Protected rayon.f = ((Sqr(lg * lg + ht * ht) * *p\option[3]) / 100) + 1
  Protected angle_max.f = (*p\option[0] - 1000) * #PI / 180.0 
  
  Protected x, y
  Protected dx.f, dy.f, r.f, a.f, new_a.f
  Protected src_x.f, src_y.f
  Protected ligne_source, ligne_cible
  Protected pix.l
  
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = (( *p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    For x = 0 To lg - 1
      dx = x - cx
      dy = y - cy
      r = Sqr(dx * dx + dy * dy)
      
      If r <= rayon
        a = ATan2(dy, dx) + #PI/2
        new_a = a + angle_max * (1.0 - (r / rayon))
        
        src_x = cx + r * Cos(new_a)
        src_y = cy + r * Sin(new_a)
      Else
        src_x = x
        src_y = y
      EndIf
      
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ligne_source = *source + (Int(src_y) * lg + Int(src_x)) * 4
        pix = PeekL(ligne_source)
      Else
        pix = 0
      EndIf
      
      ligne_cible = *cible + (y * lg + x) * 4
      PokeL(ligne_cible, pix)
    Next
  Next
EndProcedure


Procedure Spiralize(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Spiralize"
    param\remarque = "Déformation en spirale"
    param\info[0] = "Rotation"     ; de 0 à 200 (100 = neutre)
    param\info[1] = "PosX"
    param\info[2] = "PosY"
    param\info[3] = "Rayon"
    param\info[4] = "Masque binaire"
    
    param\info_data(0,0) = 0   : param\info_data(0,1) = 2000 : param\info_data(0,2) = 1000
    param\info_data(1,0) = 0   : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0   : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 0   : param\info_data(3,1) = 100 : param\info_data(3,2) = 50
    param\info_data(4,0) = 0   : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Spiralize_MT() , 4)
EndProcedure

;-----------------------

Procedure Tile_MT(*p.parametre)
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  
  Protected tilesX = *p\option[0]
  Protected tilesY = *p\option[1]

  Protected x, y
  Protected src_x, src_y
  Protected ligne_source, ligne_cible
  Protected pix.l

  Protected start, stop
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf

  For y = start To stop
    For x = 0 To lg - 1
      src_x = Mod(x * tilesX, lg)
      src_y = Mod(y * tilesY, ht)
      ligne_source = *source + (src_y * lg + src_x) * 4
      ligne_cible  = *cible  + (y * lg + x) * 4
      pix = PeekL(ligne_source)
      PokeL(ligne_cible, pix)
    Next
  Next
EndProcedure

Procedure Tile(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Tile"
    param\remarque = "Répétition en mosaïque"
    param\info[0] = "Nb Horizontal"
    param\info[1] = "Nb Vertical"
    param\info[2] = "Masque binaire"
    
    param\info_data(0,0) = 1   : param\info_data(0,1) = 100 : param\info_data(0,2) = 3
    param\info_data(1,0) = 1   : param\info_data(1,1) = 100 : param\info_data(1,2) = 3
    param\info_data(2,0) = 0   : param\info_data(2,1) = 2   : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  Protected *tempo = 0
  *tempo = AllocateMemory(*param\lg * *param\ht * 4)
  If Not *tempo : ProcedureReturn : EndIf
  CopyMemory(*param\source , *tempo , *param\lg * *param\ht * 4)
  *param\addr[0] = *tempo
  *param\addr[1] = *param\cible    
  MultiThread_MT(@Tile_MT())
  If *param\mask And *param\option[2] : *param\mask_type = *param\option[2] - 1 : MultiThread_MT(@_mask()) : EndIf
  If *tempo : FreeMemory(*tempo) : EndIf

EndProcedure

;-----------------------

Procedure Translate_MT(*p.parametre)
  Protected start, stop
  Protected pix.l
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg      = *p\lg
  Protected ht      = *p\ht
  Protected dx, dy
  Protected x, y, src_x, src_y
  Protected ligne_source, ligne_cible
  
  dx = ((*p\option[0]-100) * lg) / 100
  dy = ((*p\option[1]-100) * ht) / 100
  
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = (( *p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    For x = 0 To lg - 1
      src_x = x - dx
      src_y = y - dy
      
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ligne_source = *source + (src_y * lg + src_x) * 4
        pix = PeekL(ligne_source)
      Else
        If *p\option[2] 
          pix = 0
        Else
          If src_x >= lg : src_x = src_x - lg : EndIf
          If src_x < 0 : src_x = src_x + lg : EndIf
          If src_y >= ht : src_y = src_y - ht : EndIf
          If src_y < 0 : src_y = src_y + ht : EndIf
          ligne_source = *source + (src_y * lg + src_x) * 4
          pix = PeekL(ligne_source)
        EndIf
      EndIf     
      ligne_cible = *cible + (y * lg + x) * 4
      PokeL(ligne_cible, pix)
    Next
  Next
EndProcedure

Procedure Translate(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Translate"
    param\remarque = "Translation en pourcentage + mode"
    param\info[0] = "Décalage X (%)"
    param\info[1] = "Décalage Y (%)"
    param\info[2] = "Rot/Trans"
    param\info[3] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 200 : param\info_data(0,2) = 100
    param\info_data(1,0) = 0 : param\info_data(1,1) = 200 : param\info_data(1,2) = 100
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1   : param\info_data(2,2) = 1
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2   : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Translate_MT() , 3)
  
EndProcedure

;-----------------------

Procedure WaveCircular_MT(*p.parametre)
  Protected start, stop
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  
  Protected cx.f = (*p\option[1] * lg) / 100
  Protected cy.f = (*p\option[2] * ht) / 100
  Protected amplitude.f = *p\option[0]
  Protected wavelength.f = (*p\option[3] / 100.0) * Sqr(lg * lg + ht * ht)
  Protected phase.f = (*p\option[4] / 360.0) * 2 * #PI   
  
  Protected x, y
  Protected dx.f, dy.f, r.f
  Protected offset.f
  Protected src_x.f, src_y.f
  Protected ligne_source, ligne_cible
  Protected pix.l
  
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = (( *p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    For x = 0 To lg - 1
      dx = x - cx
      dy = y - cy
      r = Sqr(dx*dx + dy*dy)
      offset = amplitude * Sin((2 * #PI * r / wavelength) + phase)
      If r <> 0
        src_x = cx + dx * (1 + offset / r)
        src_y = cy + dy * (1 + offset / r)
      Else
        src_x = x
        src_y = y
      EndIf
      
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        ligne_source = *source + (Int(src_y) * lg + Int(src_x)) * 4
        pix = PeekL(ligne_source)
      Else
        pix = 0
      EndIf
      
      ligne_cible = *cible + (y * lg + x) * 4
      PokeL(ligne_cible, pix)
    Next
  Next
EndProcedure

Procedure WaveCircular(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Wave Circular"
    param\remarque = "Ondulations concentriques"
    param\info[0] = "Amplitude"
    param\info[1] = "Centre X (%)"
    param\info[2] = "Centre Y (%)"
    param\info[3] = "Longueur d’onde (%)"
    param\info[4] = "Phase (°)"
    param\info[5] = "Masque binaire"
    
    param\info_data(0,0) = 0    : param\info_data(0,1) = 100 : param\info_data(0,2) = 10
    param\info_data(1,0) = 0    : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0    : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 1    : param\info_data(3,1) = 100 : param\info_data(3,2) = 20
    param\info_data(4,0) = 0    : param\info_data(4,1) = 360 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0    : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@WaveCircular_MT() , 5)
EndProcedure


;-----------------------

Procedure deform_Bend_MT(*p.parametre)
  Protected start, stop, y, x
  Protected newX, newY, offsetX, offsetY
  Protected amplitudeX.f = *p\option[0]
  Protected frequencyX.f = *p\option[1] / 1000
  Protected amplitudeY.f = *p\option[2]
  Protected frequencyY.f = *p\option[3] / 1000
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected *src_pixel, *dst_pixel

  start = ( *p\thread_pos * ht ) / *p\thread_max
  stop  = ( (*p\thread_pos + 1) * ht ) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht -1 : EndIf

  For y = start To stop
    For x = 0 To lg - 1
      offsetX = Int(Sin(y * frequencyX) * amplitudeX)
      offsetY = Int(Sin(x * frequencyY) * amplitudeY)
      newX = x + offsetX
      newY = y + offsetY

      If newX >= 0 And newX < lg And newY >= 0 And newY < ht
        *src_pixel = *p\addr[0] + (newY * lg + newX) * 4
        *dst_pixel = *p\addr[1] + (y * lg + x) * 4
        CopyMemory(*src_pixel, *dst_pixel, 4)
      Else
        PokeL(*p\addr[1] + (y * lg + x) * 4, 0)
      EndIf
    Next
  Next
EndProcedure

Procedure deform_Bend(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Deform
    param\name = "Bend2D"
    param\remarque = "Courbure bidirectionnelle (X & Y)"
    param\info[0] = "Amplitude X"
    param\info[1] = "Fréquence X"
    param\info[2] = "Amplitude Y"
    param\info[3] = "Fréquence Y"
    param\info[4] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 20
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1000 : param\info_data(1,2) = 200
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100 : param\info_data(2,2) = 20
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1000 : param\info_data(3,2) = 200
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2 : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf

  filter_start(@deform_Bend_MT(), 4)
EndProcedure

;-----------------------



; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 1309
; FirstLine = 1245
; Folding = -------
; EnableXP
; DPIAware