Structure GridCell
  r.f
  g.f
  b.f
  a.f
  weight.f
EndStructure

Structure GridArray
  cell.GridCell[0]
EndStructure

; ============================================================================
; MACRO : Interpolation Trilinéaire dans la Grille Bilatérale
; ============================================================================
Macro TrilinearSlice(gx, gy, gl, r_out, g_out, b_out, a_out)
  Protected x0.i = Int(gx), y0.i = Int(gy), z0.i = Int(gl)
  Protected x1.i = x0 + 1,   y1.i = y0 + 1,   z1.i = z0 + 1
  
  If x1 >= gridSizeXY : x1 = gridSizeXY - 1 : EndIf
  If y1 >= gridSizeXY : y1 = gridSizeXY - 1 : EndIf
  If z1 >= gridSizeL  : z1 = gridSizeL - 1  : EndIf
  
  Protected fx.f = gx - x0, fy.f = gy - y0, fz.f = gl - z0
  Protected w000.f = (1.0 - fx) * (1.0 - fy) * (1.0 - fz)
  Protected w100.f = fx         * (1.0 - fy) * (1.0 - fz)
  Protected w010.f = (1.0 - fx) * fy         * (1.0 - fz)
  Protected w110.f = fx         * fy         * (1.0 - fz)
  Protected w001.f = (1.0 - fx) * (1.0 - fy) * fz
  Protected w101.f = fx         * (1.0 - fy) * fz
  Protected w011.f = (1.0 - fx) * fy         * fz
  Protected w111.f = fx         * fy         * fz
  
  Protected idx000 = z0 * gridXY2 + y0 * gridSizeXY + x0
  Protected idx100 = z0 * gridXY2 + y0 * gridSizeXY + x1
  Protected idx010 = z0 * gridXY2 + y1 * gridSizeXY + x0
  Protected idx110 = z0 * gridXY2 + y1 * gridSizeXY + x1
  Protected idx001 = z1 * gridXY2 + y0 * gridSizeXY + x0
  Protected idx101 = z1 * gridXY2 + y0 * gridSizeXY + x1
  Protected idx011 = z1 * gridXY2 + y1 * gridSizeXY + x0
  Protected idx111 = z1 * gridXY2 + y1 * gridSizeXY + x1
  
  sumW = *blurred\cell[idx000]\weight * w000 + *blurred\cell[idx100]\weight * w100 +
         *blurred\cell[idx010]\weight * w010 + *blurred\cell[idx110]\weight * w110 +
         *blurred\cell[idx001]\weight * w001 + *blurred\cell[idx101]\weight * w101 +
         *blurred\cell[idx011]\weight * w011 + *blurred\cell[idx111]\weight * w111
  
  If sumW > 0.0001
    Protected invW.f = 1.0 / sumW
    r_out = (*blurred\cell[idx000]\r * w000 + *blurred\cell[idx100]\r * w100 +
             *blurred\cell[idx010]\r * w010 + *blurred\cell[idx110]\r * w110 +
             *blurred\cell[idx001]\r * w001 + *blurred\cell[idx101]\r * w101 +
             *blurred\cell[idx011]\r * w011 + *blurred\cell[idx111]\r * w111) * invW
             
    g_out = (*blurred\cell[idx000]\g * w000 + *blurred\cell[idx100]\g * w100 +
             *blurred\cell[idx010]\g * w010 + *blurred\cell[idx110]\g * w110 +
             *blurred\cell[idx001]\g * w001 + *blurred\cell[idx101]\g * w101 +
             *blurred\cell[idx011]\g * w011 + *blurred\cell[idx111]\g * w111) * invW
             
    b_out = (*blurred\cell[idx000]\b * w000 + *blurred\cell[idx100]\b * w100 +
             *blurred\cell[idx010]\b * w010 + *blurred\cell[idx110]\b * w110 +
             *blurred\cell[idx001]\b * w001 + *blurred\cell[idx101]\b * w101 +
             *blurred\cell[idx011]\b * w011 + *blurred\cell[idx111]\b * w111) * invW
             
    a_out = (*blurred\cell[idx000]\a * w000 + *blurred\cell[idx100]\a * w100 +
             *blurred\cell[idx010]\a * w010 + *blurred\cell[idx110]\a * w110 +
             *blurred\cell[idx001]\a * w001 + *blurred\cell[idx101]\a * w101 +
             *blurred\cell[idx011]\a * w011 + *blurred\cell[idx111]\a * w111) * invW
  EndIf
EndMacro

; ============================================================================
; PHASE 1 : SPLATTING (Séquentiel pour éviter les crashs de concurrence)
; ============================================================================
Procedure Permutohedral_Splat(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected spatialSigma.f = \option[0]
    Protected rangeSigma.f   = \option[1]
    If spatialSigma < 1.0 : spatialSigma = 1.0 : EndIf
    If rangeSigma < 1.0   : rangeSigma = 1.0   : EndIf
    
    Protected gridSizeXY.i = 64
    Protected gridSizeL.i  = 32
    Protected gridXY2.i    = gridSizeXY * gridSizeXY
    
    Protected *grid.GridArray = \addr[2]
    Protected *srcPixel.Pixel32
    Protected x.i, y.i, idx.i, value.l
    Protected r.l, g.l, b.l, a.l, lum.l
    Protected gx.f, gy.f, gl.f
    Protected ix.i, iy.i, il.i
    
    For y = 0 To ht - 1
      For x = 0 To lg - 1
        *srcPixel = \addr[0] + ((y * lg + x) << 2)
        value = *srcPixel\l
        
        a = (value >> 24) & $FF
        r = (value >> 16) & $FF
        g = (value >> 8)  & $FF
        b = value & $FF
        
        lum = (r * 77 + g * 150 + b * 29) >> 8
        
        gx = (x * (gridSizeXY - 1.0)) / (lg * spatialSigma)
        gy = (y * (gridSizeXY - 1.0)) / (ht * spatialSigma)
        gl = (lum * (gridSizeL - 1.0)) / (255.0 * rangeSigma)
        
        ix = Int(gx) : iy = Int(gy) : il = Int(gl)
        If ix < 0 : ix = 0 : ElseIf ix >= gridSizeXY : ix = gridSizeXY - 1 : EndIf
        If iy < 0 : iy = 0 : ElseIf iy >= gridSizeXY : iy = gridSizeXY - 1 : EndIf
        If il < 0 : il = 0 : ElseIf il >= gridSizeL  : il = gridSizeL - 1  : EndIf
        
        idx = il * gridXY2 + iy * gridSizeXY + ix
        
        *grid\cell[idx]\r + r
        *grid\cell[idx]\g + g
        *grid\cell[idx]\b + b
        *grid\cell[idx]\a + a
        *grid\cell[idx]\weight + 1.0
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PHASE 2 : BLUR 3D MT (Correction du découpage Z pour éviter l'Out-Of-Bounds)
; ============================================================================
Procedure Permutohedral_Blur3D_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected ht = \image_ht[0]
    Protected gridSizeXY.i = 64
    Protected gridSizeL.i  = 32
    Protected gridXY2.i    = gridSizeXY * gridSizeXY
    
    Protected *grid.GridArray    = \addr[2]
    Protected *blurred.GridArray = \addr[3]
    
    Protected i.i, j.i, k.i, dx.i, dy.i, dz.i, nx.i, ny.i, nz.i
    Protected sumR.f, sumG.f, sumB.f, sumA.f, sumW.f
    Protected srcIdx.i, dstIdx.i
    
    macro_calul_tread(ht)
    
    ; Conversion des bornes de threads (basées sur ht) vers les tranches Z (0-31)
    Protected z_start.i = (thread_start * gridSizeL) / ht
    Protected z_stop.i  = (thread_stop * gridSizeL) / ht
    If z_stop <= z_start : z_stop = z_start + 1 : EndIf
    If z_stop > gridSizeL : z_stop = gridSizeL : EndIf
    
    For k = z_start To z_stop - 1
      For j = 0 To gridSizeXY - 1
        For i = 0 To gridSizeXY - 1
          sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : sumW = 0.0
          
          For dz = -1 To 1
            nz = k + dz
            If nz < 0 Or nz >= gridSizeL : Continue : EndIf
            
            For dy = -1 To 1
              ny = j + dy
              If ny < 0 Or ny >= gridSizeXY : Continue : EndIf
              
              For dx = -1 To 1
                nx = i + dx
                If nx < 0 Or nx >= gridSizeXY : Continue : EndIf
                
                srcIdx = nz * gridXY2 + ny * gridSizeXY + nx
                If *grid\cell[srcIdx]\weight > 0.0
                  sumR + *grid\cell[srcIdx]\r
                  sumG + *grid\cell[srcIdx]\g
                  sumB + *grid\cell[srcIdx]\b
                  sumA + *grid\cell[srcIdx]\a
                  sumW + *grid\cell[srcIdx]\weight
                EndIf
              Next
            Next
          Next
          
          dstIdx = k * gridXY2 + j * gridSizeXY + i
          *blurred\cell[dstIdx]\r = sumR
          *blurred\cell[dstIdx]\g = sumG
          *blurred\cell[dstIdx]\b = sumB
          *blurred\cell[dstIdx]\a = sumA
          *blurred\cell[dstIdx]\weight = sumW
        Next
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PHASE 3 : SLICE MT (Sûr pour le multi-threading car lecture seule)
; ============================================================================
Procedure Permutohedral_Slice_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected spatialSigma.f = \option[0]
    Protected rangeSigma.f   = \option[1]
    If spatialSigma < 1.0 : spatialSigma = 1.0 : EndIf
    If rangeSigma < 1.0   : rangeSigma = 1.0   : EndIf
    
    Protected gridSizeXY.i = 64
    Protected gridSizeL.i  = 32
    Protected gridXY2.i    = gridSizeXY * gridSizeXY
    
    Protected *blurred.GridArray = \addr[3]
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    
    Protected x.i, y.i, value.l
    Protected r.l, g.l, b.l, a.l, lum.l
    Protected gx.f, gy.f, gl.f
    Protected fr.f, fg.f, fb.f, fa.f, sumW.f
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        *srcPixel = \addr[0] + ((y * lg + x) << 2)
        value = *srcPixel\l
        r = (value >> 16) & $FF : g = (value >> 8) & $FF : b = value & $FF : a = (value >> 24) & $FF
        lum = (r * 77 + g * 150 + b * 29) >> 8
        
        gx = (x * (gridSizeXY - 1.0)) / (lg * spatialSigma)
        gy = (y * (gridSizeXY - 1.0)) / (ht * spatialSigma)
        gl = (lum * (gridSizeL - 1.0)) / (255.0 * rangeSigma)
        
        If gx < 0.0 : gx = 0.0 : ElseIf gx > gridSizeXY - 1 : gx = gridSizeXY - 1 : EndIf
        If gy < 0.0 : gy = 0.0 : ElseIf gy > gridSizeXY - 1 : gy = gridSizeXY - 1 : EndIf
        If gl < 0.0 : gl = 0.0 : ElseIf gl > gridSizeL - 1  : gl = gridSizeL - 1  : EndIf
        
        fr = r : fg = g : fb = b : fa = a
        TrilinearSlice(gx, gy, gl, fr, fg, fb, fa)
        
        ; Clamping final
        If fr < 0.0 : r = 0 : ElseIf fr > 255.0 : r = 255 : Else : r = Int(fr) : EndIf
        If fg < 0.0 : g = 0 : ElseIf fg > 255.0 : g = 255 : Else : g = Int(fg) : EndIf
        If fb < 0.0 : b = 0 : ElseIf fb > 255.0 : b = 255 : Else : b = Int(fb) : EndIf
        If fa < 0.0 : a = 0 : ElseIf fa > 255.0 : a = 255 : Else : a = Int(fa) : EndIf
        
        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; LANCEUR GLOBAL
; ============================================================================
Procedure PermutohedralLatticeEx(*FilterCtx.FilterParams)
  Restore PermutohedralLattice_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  With *FilterCtx
    Protected gridSizeXY.i = 64
    Protected gridSizeL.i  = 32
    Protected totalCells.i = gridSizeXY * gridSizeXY * gridSizeL
    Protected memSize.i    = totalCells * SizeOf(GridCell)
    
    ; Allocation unique partagée
    \addr[2] = AllocateMemory(memSize) ; *grid
    \addr[3] = AllocateMemory(memSize) ; *blurred
    
    If \addr[2] And \addr[3]
      ; Initialisation explicite de la mémoire à zéro
      FillMemory(\addr[2], memSize, 0)
      FillMemory(\addr[3], memSize, 0)
      
      ; 1. Splatting Séquentiel (Rapide et évite toute collision entre threads)
      Permutohedral_Splat(*FilterCtx)
      
      ; 2. Blur 3D et Slice en Multi-Thread
      Create_MultiThread_MT(@Permutohedral_Blur3D_MT())
      Create_MultiThread_MT(@Permutohedral_Slice_MT())
      
      FreeMemory(\addr[2])
      FreeMemory(\addr[3])
    EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure PermutohedralLattice(source, cible, mask, sigma_spatial, sigma_couleur)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = sigma_spatial
    \option[1] = sigma_couleur
  EndWith
  PermutohedralLatticeEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  PermutohedralLattice_data:
  Data.s "PermutohedralLattice"
  Data.s "Filtrage bilatéral via grille 3D Lattice"
  Data.i #FilterType_Blur
  Data.i #Blur_Advanced
  
  Data.s "Sigma spatial"
  Data.i 1, 10, 3
  Data.s "Sigma couleur"
  Data.i 1, 30, 8
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 310
; FirstLine = 255
; Folding = --
; EnableXP
; DPIAware