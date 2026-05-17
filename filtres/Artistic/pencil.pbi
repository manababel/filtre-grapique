; ============================================================================
; FILTRE PENCIL (EFFET CRAYON/DESSIN)
; ============================================================================

; Les macros ont été ajustées pour respecter les règles de parenthésage et d'indexation

Macro pencil_Blur_IIR_int(var)
  Protected *pix32.pixel32
  Protected *dst32.pixel32 = *FilterCtx\addr[0]
  Protected lg       = *FilterCtx\image_lg[0]
  Protected ht       = *FilterCtx\image_ht[0]
  
  Protected alpha    = Int(Exp(-2.3 / *FilterCtx\option[0]) * 256 + 0.5)
  Protected inv_alpha= 256 - alpha
  
  Protected x, y, pos, mem
  Protected r, g, b
  Protected r1, g1, b1
  
  Protected start = ((*FilterCtx\thread_pos * var)) / *FilterCtx\thread_max
  Protected stop  = (((*FilterCtx\thread_pos + 1) * var)) / *FilterCtx\thread_max
  If start < 0 : start = 0 : EndIf
  If stop  > var : stop = var : EndIf
EndMacro

Macro pencil_Blur_IIR_sp0(r, g, b)
  *pix32 = *dst32 + (pos << 2)
  getrgb(*pix32\l, r, g, b) 
  r << 8 
  g << 8
  b << 8
EndMacro

Macro pencil_Blur_IIR_sp1()
  pencil_Blur_IIR_sp0(r1, g1, b1)
  r = (r * alpha + inv_alpha * r1) >> 8 
  g = (g * alpha + inv_alpha * g1) >> 8
  b = (b * alpha + inv_alpha * b1) >> 8
  r1 = (r + 128) >> 8
  g1 = (g + 128) >> 8
  b1 = (b + 128) >> 8
  *pix32\l = (r1 << 16) | (g1 << 8) | b1
EndMacro

Procedure pencil_Blur_IIR_y_MT(*FilterCtx.FilterParams)
  pencil_Blur_IIR_int(*FilterCtx\image_ht[0])
  For y = start To stop - 1
    pos = y * lg
    mem = pos 
    pencil_Blur_IIR_sp0(r, g, b)
    For x = 1 To lg - 1
      pos = mem + x
      pencil_Blur_IIR_sp1()
    Next
    pos = mem + (lg - 1)
    pencil_Blur_IIR_sp0(r, g, b)
    For x = lg - 2 To 0 Step -1
      pos = y * lg + x
      pencil_Blur_IIR_sp1()
    Next
  Next
EndProcedure

Procedure pencil_Blur_IIR_x_MT(*FilterCtx.FilterParams)
  pencil_Blur_IIR_int(*FilterCtx\image_lg[0])
  For x = start To stop - 1
    pos = x 
    pencil_Blur_IIR_sp0(r, g, b)
    For y = 1 To ht - 1
      pos = y * lg + x
      pencil_Blur_IIR_sp1()
    Next
    pos = (ht - 1) * lg + x 
    pencil_Blur_IIR_sp0(r, g, b)
    For y = ht - 2 To 0 Step -1
      pos = y * lg + x
      pencil_Blur_IIR_sp1()
    Next
  Next
EndProcedure

Procedure pencil_blur_box_create_limit(lg, ht, rx, ry, boucle)
  Protected i, ii, e
  Protected dx = lg - 1
  Protected dy = ht - 1
  If rx > dx : rx = dx : EndIf
  If ry > dy : ry = dy : EndIf
  Protected nrx = rx + 1
  Protected nry = ry + 1
  Protected sizeX = (lg + 2 * nrx) << 2
  Protected sizeY = (ht + 2 * nry) << 2
  Global *blur_box_limit = AllocateMemory(sizeX + sizeY)
  If *blur_box_limit = 0 : ProcedureReturn 0 : EndIf
  Global *blur_box_limit_x = *blur_box_limit
  Global *blur_box_limit_y = *blur_box_limit + sizeX
  If boucle
    e = dx - nrx / 2
    For i = 0 To dx + 2 * nrx
      PokeL(*blur_box_limit_x + (i << 2), (i + e) % (dx + 1))
    Next
    e = dy - nry / 2
    For i = 0 To dy + 2 * nry
      PokeL(*blur_box_limit_y + (i << 2), (i + e) % (dy + 1))
    Next
  Else
    For i = 0 To dx + 2 * nrx
      ii = i - 1 - nrx / 2
      If ii < 0 : ii = 0 : ElseIf ii > dx : ii = dx : EndIf
      PokeL(*blur_box_limit_x + (i << 2), ii)
    Next
    For i = 0 To dy + 2 * nry
      ii = i - 1 - nry / 2
      If ii < 0 : ii = 0 : ElseIf ii > dy : ii = dy : EndIf
      PokeL(*blur_box_limit_y + (i << 2), ii)
    Next
  EndIf
  ProcedureReturn 1
EndProcedure

Procedure pencil_Guillossien_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *srcPixel1.Pixel32
    Protected *srcPixel2.Pixel32
    Protected *dstPixel.Pixel32
    Protected ax1, rx1, gx1, bx1
    Protected a1.l, r1.l, b1.l, g1.l
    Protected a2.l, r2.l, b2.l, g2.l
    Protected j, i, p1, p2
    Protected *cible = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected *tempo = \addr[0]
    Protected lx = \addr[1]
    Protected ly = \addr[2]
    Protected nrx = \option[17]
    Protected nry = \option[18]
    Protected div = \option[19]
    Protected thread_pos = \thread_pos
    Protected thread_max = \thread_max
    Protected startPos = (thread_pos * ht) / thread_max
    Protected endPos   = ((thread_pos + 1) * ht) / thread_max - 1
    Protected Dim a.l(lg)
    Protected Dim r.l(lg)
    Protected Dim g.l(lg)
    Protected Dim b.l(lg)
    FillMemory(@a(), lg << 2, 0)
    FillMemory(@r(), lg << 2, 0)
    FillMemory(@g(), lg << 2, 0)
    FillMemory(@b(), lg << 2, 0)
    
    For j = 0 To nry - 1
      p1 = PeekL(ly + ((j + startPos) << 2))
      *srcPixel1 = *cible + ((p1 * lg) << 2)
      For i = 0 To lg - 1
        getargb(*srcPixel1\l, a1, r1, g1, b1)
        a(i) + a1 : r(i) + r1 : g(i) + g1 : b(i) + b1
        *srcPixel1 + 4
      Next
    Next
    
    For j = startPos To endPos
      p1 = PeekL(ly + ((nry + j) << 2))
      p2 = PeekL(ly + (j << 2))
      *srcPixel1 = *cible + ((p1 * lg) << 2)
      *srcPixel2 = *cible + ((p2 * lg) << 2)
      For i = 0 To lg - 1
        getargb(*srcPixel1\l, a1, r1, g1, b1)
        getargb(*srcPixel2\l, a2, r2, g2, b2)
        a(i) + a1 - a2
        r(i) + r1 - r2
        g(i) + g1 - g2
        b(i) + b1 - b2
        *srcPixel1 + 4
        *srcPixel2 + 4
      Next
      ax1 = 0 : rx1 = 0 : gx1 = 0 : bx1 = 0
      For i = 0 To nrx - 1
        p1 = PeekL(lx + (i << 2))
        ax1 + a(p1) : rx1 + r(p1) : gx1 + g(p1) : bx1 + b(p1)
      Next
      For i = 0 To lg - 1
        p1 = PeekL(lx + ((nrx + i) << 2))
        p2 = PeekL(lx + (i << 2))
        ax1 + a(p1) - a(p2)
        rx1 + r(p1) - r(p2)
        gx1 + g(p1) - g(p2)
        bx1 + b(p1) - b(p2)
        a1 = (ax1 * div) >> 16
        r1 = (rx1 * div) >> 16
        g1 = (gx1 * div) >> 16
        b1 = (bx1 * div) >> 16
        *dstPixel = *tempo + ((j * lg + i) << 2)
        *dstPixel\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
      Next
    Next
  EndWith
  FreeArray(a())
  FreeArray(r())
  FreeArray(g())
  FreeArray(b())
EndProcedure

Macro pencil_sobel_4d_sp(i)
  getrgb(PeekL(pos + 0), r, g, b)
  p(i + 0) = ((r * 76 + g * 150 + b * 30) >> 8)
  getrgb(PeekL(pos + 4), r, g, b)
  p(i + 1) = ((r * 76 + g * 150 + b * 30) >> 8)
  getrgb(PeekL(pos + 8), r, g, b)
  p(i + 2) = ((r * 76 + g * 150 + b * 30) >> 8)
EndMacro

Procedure pencil_sobel_4d_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[3]
    Protected pos, f
    Protected r, g, b
    Protected c0, c45, c90, c135
    Protected cx0, cx45, cx90, cx135
    Protected cy0, cy45, cy90, cy135
    clamp(mul, 0, 100)
    mul * 0.1
    Protected x, y
    Protected Dim p(8)
    Protected startPos = (\thread_pos * (ht - 2)) / \thread_max
    Protected endPos   = ((\thread_pos + 1) * (ht - 2)) / \thread_max
    If startPos < 1 : startPos = 1 : EndIf
    For y = startPos To endPos
      For x = 1 To lg - 2
        pos = *source + (((y - 1) * lg + (x - 1)) << 2)
        pencil_sobel_4d_sp(0)
        pos = *source + ((y * lg + (x - 1)) << 2)
        pencil_sobel_4d_sp(3)
        pos = *source + (((y + 1) * lg + (x - 1)) << 2)
        pencil_sobel_4d_sp(6)
        cx0 = p(2) + 2 * p(5) + p(8) - (p(0) + 2 * p(3) + p(6))
        cy0 = p(0) + 2 * p(1) + p(2) - (p(6) + 2 * p(7) + p(8))
        cx45 = p(0) + 2 * p(1) + p(2) - (p(6) + 2 * p(7) + p(8))
        cy45 = p(2) + 2 * p(5) + p(8) - (p(0) + 2 * p(3) + p(6))
        cx90 = p(6) + 2 * p(7) + p(8) - (p(0) + 2 * p(1) + p(2))
        cy90 = p(2) + 2 * p(5) + p(8) - (p(0) + 2 * p(3) + p(6))
        cx135 = p(6) + 2 * p(3) + p(0) - (p(8) + 2 * p(5) + p(2))
        cy135 = p(0) + 2 * p(3) + p(6) - (p(2) + 2 * p(5) + p(8))
        c0   = Sqr(cx0   * cx0   + cy0   * cy0)
        c45  = Sqr(cx45  * cx45  + cy45  * cy45)
        c90  = Sqr(cx90  * cx90  + cy90  * cy90)
        c135 = Sqr(cx135 * cx135 + cy135 * cy135)
        max4(f, c0, c45, c90, c135)
        f * mul
        clamp(f, 0, 255)
        PokeL(*cible + ((y * lg + x) << 2), (255 - f) * $010101)
      Next
    Next
  EndWith
  FreeArray(p())
EndProcedure

Procedure pencil_color_dodge(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *dodge = \addr[0]
    Protected *blur  = \addr[1]
    Protected *cible = \addr[2]
    Protected lg      = \image_lg[0]
    Protected ht      = \image_ht[0]
    Protected total   = lg * ht
    Protected intensity = (\option[1] * 255) / 100
    Protected gamma.f   = \option[2] * 0.1
    Protected start = (\thread_pos * total) / \thread_max
    Protected stop  = ((\thread_pos + 1) * total) / \thread_max
    If stop > total : stop = total : EndIf
    Protected i, pos
    Protected r, g, b
    Protected r1, g1, b1
    Protected r2, g2, b2
    Protected r3, g3, b3
    Protected Dim GammaLUT(255)
    For i = 0 To 255
      GammaLUT(i) = Int(255.0 * Pow(i / 255.0, gamma))
      clamp(GammaLUT(i), 0, 255)
    Next
    For i = start To stop - 1
      pos = i << 2
      getrgb(PeekL(*dodge + pos), r1, g1, b1)
      getrgb(PeekL(*blur  + pos), r2, g2, b2)
      r3 = 255 - r1 : If r3 < 1 : r3 = 1 : EndIf
      g3 = 255 - g1 : If g3 < 1 : g3 = 1 : EndIf
      b3 = 255 - b1 : If b3 < 1 : b3 = 1 : EndIf
      r = (r2 << 8) / r3
      g = (g2 << 8) / g3
      b = (b2 << 8) / b3
      r = (r * intensity) >> 8
      g = (g * intensity) >> 8
      b = (b * intensity) >> 8
      clamp_rgb(r, g, b)
      r = GammaLUT(r)
      g = GammaLUT(g)
      b = GammaLUT(b)
      PokeL(*cible + pos, (r << 16) | (g << 8) | b)
    Next
  EndWith
  FreeArray(GammaLUT())
EndProcedure

Procedure pencil_gray_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg      = \image_lg[0]
    Protected ht      = \image_ht[0]
    Protected total   = lg * ht
    Protected start = (\thread_pos * total) / \thread_max
    Protected stop  = ((\thread_pos + 1) * total) / \thread_max
    If stop > total : stop = total : EndIf
    Protected i, lum, a, r, g, b
    For i = start To stop - 1
      getargb(PeekL(*source + (i << 2)), a, r, g, b)
      lum = ((r * 76 + g * 150 + b * 30) >> 8)
      PokeL(*cible + (i << 2), lum * $010101)
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel Ex
; ----------------------------------------------------------------------------------

Procedure pencilEx(*FilterCtx.FilterParams)
  Restore pencil_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected i 
    Protected *source = \addr[0]
    Protected *cible = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    
    If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf
    
    Protected *gray = AllocateMemory(lg * ht * 4)
    Protected *blur = AllocateMemory(lg * ht * 4)
    Protected *sobel = AllocateMemory(lg * ht * 4)
    Protected *tmp = AllocateMemory(lg * ht * 4)
    
    If *gray = 0 Or *blur = 0 Or *sobel = 0 Or *tmp = 0
      If *gray : FreeMemory(*gray) : EndIf
      If *blur : FreeMemory(*blur) : EndIf
      If *sobel : FreeMemory(*sobel) : EndIf
      If *tmp : FreeMemory(*tmp) : EndIf
      ProcedureReturn
    EndIf
    
    \addr[0] = *source
    \addr[1] = *gray
    Create_MultiThread_MT(@pencil_gray_MT())
    
    If pencil_blur_box_create_limit(lg, ht, 3, 3, 0)
      Protected *tempo = AllocateMemory(lg * ht * 4)
      If *tempo
        \addr[0] = *tempo
        \addr[1] = *blur_box_limit_x
        \addr[2] = *blur_box_limit_y
        \option[17] = 3
        \option[18] = 3
        \option[19] = Int(65536 / (3 * 3))
        Protected passe
        For  passe = 1 To 2
          Create_MultiThread_MT(@pencil_Guillossien_MT())
          CopyMemory(*tempo, *cible, lg * ht * 4)
        Next
        FreeMemory(*tempo)
      EndIf
      If *blur_box_limit
        FreeMemory(*blur_box_limit)
        *blur_box_limit = 0
      EndIf
    EndIf
    
    CopyMemory(*gray, *blur, lg * ht * 4)
    \addr[0] = *blur
    Create_MultiThread_MT(@pencil_Blur_IIR_y_MT())
    Create_MultiThread_MT(@pencil_Blur_IIR_x_MT())
    
    \addr[0] = *blur
    \addr[1] = *sobel
    Create_MultiThread_MT(@pencil_sobel_4d_MT())
    
    Select \option[4]
      Case 0
        \addr[0] = *sobel
        \addr[1] = *blur
        \addr[2] = *cible
        Create_MultiThread_MT(@pencil_color_dodge())
      Case 1
        \addr[0] = *gray
        \addr[1] = *cible
        Create_MultiThread_MT(@pencil_sobel_4d_MT())
      Case 2
        \addr[0] = *blur
        \addr[1] = *sobel
        \addr[2] = *cible
        Create_MultiThread_MT(@pencil_color_dodge())
      Case 3
        Protected old_intensity = \option[3]
        \option[3] = old_intensity / 2
        \addr[0] = *sobel
        \addr[1] = *blur
        \addr[2] = *cible
        Create_MultiThread_MT(@pencil_color_dodge())
        \option[3] = old_intensity
      Case 4
        For i = 0 To (lg * ht - 1)
          Protected val = PeekL(*blur + (i << 2)) & $FF
          val + Random(10) - 5
          clamp(val, 0, 255)
          PokeL(*blur + (i << 2), val * $010101)
        Next
        \addr[0] = *sobel
        \addr[1] = *blur
        \addr[2] = *cible
        Create_MultiThread_MT(@pencil_color_dodge())
      Case 5
        For i = 0 To (lg * ht - 1)
          Protected v = PeekL(*sobel + (i << 2)) & $FF
          Protected blur_val = PeekL(*blur + (i << 2)) & $FF
          v = v + ((255 - blur_val) >> 1)
          clamp(v, 0, 255)
          PokeL(*sobel + (i << 2), v * $010101)
        Next
        \addr[0] = *sobel
        \addr[1] = *blur
        \addr[2] = *cible
        Create_MultiThread_MT(@pencil_color_dodge())
      Case 6
        For i = 0 To (lg * ht - 1)
          v = PeekL(*sobel + (i << 2)) & $FF
          If v > 128
            PokeL(*sobel + (i << 2), $FFFFFF)
          Else
            PokeL(*sobel + (i << 2), $000000)
          EndIf
        Next
        \addr[0] = *sobel
        \addr[1] = *blur
        \addr[2] = *cible
        Create_MultiThread_MT(@pencil_color_dodge())
      Case 7
        For i = 0 To (lg * ht - 1)
          Protected v1 = PeekL(*gray + (i << 2)) & $FF
          Protected v2 = PeekL(*blur + (i << 2)) & $FF
          Protected mix = (v1 * 3 + v2) >> 2
          PokeL(*blur + (i << 2), mix * $010101)
        Next
        \addr[0] = *sobel
        \addr[1] = *blur
        \addr[2] = *cible
        Create_MultiThread_MT(@pencil_color_dodge())
      Case 8
        For i = 0 To (lg * ht - 1)
          v1 = PeekL(*gray + (i << 2)) & $FF
          v2 = PeekL(*blur + (i << 2)) & $FF
          mix = (v1 + v2 * 3) >> 2
          PokeL(*blur + (i << 2), mix * $010101)
        Next
        \addr[0] = *sobel
        \addr[1] = *blur
        \addr[2] = *cible
        Create_MultiThread_MT(@pencil_color_dodge())
      Case 9
        \addr[0] = *gray
        \addr[1] = *tmp
        Create_MultiThread_MT(@pencil_sobel_4d_MT())
        For i = 0 To (lg * ht - 1)
          Protected lum = PeekL(*gray + (i << 2)) & $FF
          Protected steps = 4
          Protected level = (lum * steps) / 256
          If steps > 1
            lum = (255 * level) / (steps - 1)
          Else
            lum = 255
          EndIf
          clamp(lum, 0, 255)
          PokeL(*gray + (i << 2), lum * $010101)
        Next
        For i = 0 To (lg * ht - 1)
          Protected edge = PeekL(*tmp + (i << 2)) & $FF
          Protected base = PeekL(*gray + (i << 2)) & $FF
          Protected final = base - (edge >> 1)
          clamp(final, 0, 255)
          PokeL(*cible + (i << 2), final * $010101)
        Next
    EndSelect
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
  
  FreeMemory(*gray)
  FreeMemory(*blur)
  FreeMemory(*sobel)
  FreeMemory(*tmp)
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure pencil(source, cible, mask, rayon, intensite_melange, gamma, intensite_contours, style)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = intensite_melange
    \option[2] = gamma
    \option[3] = intensite_contours
    \option[4] = style
  EndWith
  pencilEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  pencil_Data:
  Data.s "Pencil (crash)"
  Data.s "Effet dessin au crayon avec styles variés"
  Data.i #FilterType_Artistic
  Data.i #Artistic_Material
  
  Data.s "Rayon flou"
  Data.i 1, 80, 3
  
  Data.s "Intensité mélange"
  Data.i 1, 100, 50
  
  Data.s "Gamma"
  Data.i 1, 100, 10
  
  Data.s "Intensité contours"
  Data.i 1, 100, 10
  
  Data.s "Style (0-9)"
  Data.i 0, 9, 0
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 530
; FirstLine = 500
; Folding = ---
; EnableXP
; DPIAware
; DisableDebugger