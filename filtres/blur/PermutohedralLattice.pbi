Structure GridCell
  r.q
  g.q
  b.q
  a.q
  count.q
EndStructure

Procedure PermutohedralLattice_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected spatialSigma.f = \option[0]
    Protected rangeSigma.f = \option[1]
    
    If spatialSigma < 1.0 : spatialSigma = 1.0 : EndIf
    If rangeSigma < 1.0 : rangeSigma = 1.0 : EndIf
    
    ; Grille pour le filtrage bilateral
    Protected gridSizeXY = 64
    Protected gridSizeL = 32
    Protected gridSize.q = gridSizeXY * gridSizeXY * gridSizeL
    
    ; Allocation de la grille (Locale au thread pour cette implémentation simplifiée)
    Protected *grid.GridCell = AllocateMemory(gridSize * SizeOf(GridCell))
    Protected *blurred.GridCell = AllocateMemory(gridSize * SizeOf(GridCell))
    If Not *grid Or Not *blurred : Goto Cleanup : EndIf
    
    Protected x, y, index, value
    Protected r, g, b, a, lum
    Protected gx.f, gy.f, gl.f
    Protected ix, iy, il
    Protected *cell.GridCell
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    
    macro_calul_tread(ht)
    
    ; ==== Phase 1: Splat (Uniquement sur la zone du thread) ====
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        *srcPixel = \addr[0] + ((y * lg + x) << 2)
        value = *srcPixel\l
        
        a = (value >> 24) & $FF
        r = (value >> 16) & $FF
        g = (value >> 8) & $FF
        b = value & $FF
        
        lum = (r * 77 + g * 150 + b * 29) >> 8
        
        gx = (x * (gridSizeXY - 1.0)) / (lg * spatialSigma)
        gy = (y * (gridSizeXY - 1.0)) / (ht * spatialSigma)
        gl = (lum * (gridSizeL - 1.0)) / (255.0 * rangeSigma)
        
        ix = Int(gx) : iy = Int(gy) : il = Int(gl)
        If ix < 0 : ix = 0 : ElseIf ix > gridSizeXY - 1 : ix = gridSizeXY - 1 : EndIf
        If iy < 0 : iy = 0 : ElseIf iy > gridSizeXY - 1 : iy = gridSizeXY - 1 : EndIf
        If il < 0 : il = 0 : ElseIf il > gridSizeL - 1 : il = gridSizeL - 1 : EndIf
        
        *cell = *grid + (il * gridSizeXY * gridSizeXY + iy * gridSizeXY + ix) * SizeOf(GridCell)
        *cell\r + r : *cell\g + g : *cell\b + b : *cell\a + a : *cell\count + 1
      Next
    Next
    
    ; ==== Phase 2: Normalisation & Blur dans le lattice ====
    Protected i, j, k, dx, dy, dz, nx, ny, nz
    Protected *srcCell.GridCell, *dstCell.GridCell
    
    For k = 0 To gridSizeL - 1
      For j = 0 To gridSizeXY - 1
        For i = 0 To gridSizeXY - 1
          Protected sumR.q = 0, sumG.q = 0, sumB.q = 0, sumA.q = 0, sumCount.q = 0
          
          For dz = -1 To 1
            nz = k + dz
            If nz < 0 Or nz >= gridSizeL : Continue : EndIf
            For dy = -1 To 1
              ny = j + dy
              If ny < 0 Or ny >= gridSizeXY : Continue : EndIf
              For dx = -1 To 1
                nx = i + dx
                If nx < 0 Or nx >= gridSizeXY : Continue : EndIf
                
                *srcCell = *grid + (nz * gridSizeXY * gridSizeXY + ny * gridSizeXY + nx) * SizeOf(GridCell)
                If *srcCell\count > 0
                  sumR + *srcCell\r / *srcCell\count
                  sumG + *srcCell\g / *srcCell\count
                  sumB + *srcCell\b / *srcCell\count
                  sumA + *srcCell\a / *srcCell\count
                  sumCount + 1
                EndIf
              Next
            Next
          Next
          
          *dstCell = *blurred + (k * gridSizeXY * gridSizeXY + j * gridSizeXY + i) * SizeOf(GridCell)
          If sumCount > 0
            *dstCell\r = sumR / sumCount
            *dstCell\g = sumG / sumCount
            *dstCell\b = sumB / sumCount
            *dstCell\a = sumA / sumCount
            *dstCell\count = 1
          EndIf
        Next
      Next
    Next
    
    ; ==== Phase 3: Slice (Interpolation trinaire simplifiée) ====
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        *srcPixel = \addr[0] + ((y * lg + x) << 2)
        value = *srcPixel\l
        r = (value >> 16) & $FF : g = (value >> 8) & $FF : b = value & $FF : a = (value >> 24) & $FF
        lum = (r * 77 + g * 150 + b * 29) >> 8
        
        gx = (x * (gridSizeXY - 1.0)) / (lg * spatialSigma)
        gy = (y * (gridSizeXY - 1.0)) / (ht * spatialSigma)
        gl = (lum * (gridSizeL - 1.0)) / (255.0 * rangeSigma)
        
        ix = Int(gx) : iy = Int(gy) : il = Int(gl)
        If ix > gridSizeXY - 1 : ix = gridSizeXY - 1 : EndIf
        If iy > gridSizeXY - 1 : iy = gridSizeXY - 1 : EndIf
        If il > gridSizeL - 1 : il = gridSizeL - 1 : EndIf
        
        *cell = *blurred + (il * gridSizeXY * gridSizeXY + iy * gridSizeXY + ix) * SizeOf(GridCell)
        If *cell\count > 0
          r = *cell\r : g = *cell\g : b = *cell\b : a = *cell\a
        EndIf
        
        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
    
    Cleanup:
    If *grid : FreeMemory(*grid) : EndIf
    If *blurred : FreeMemory(*blurred) : EndIf
  EndWith
EndProcedure

Procedure PermutohedralLatticeEx(*FilterCtx.FilterParams)
  Restore PermutohedralLattice_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@PermutohedralLattice_MT())
  
  mask_update(*FilterCtx , last_data)
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
; CursorPosition = 151
; FirstLine = 123
; Folding = -
; EnableXP
; DPIAware