Procedure PermutohedralLattice_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected spatialSigma.f = *param\option[0]
  Protected rangeSigma.f = *param\option[1]
  
  If spatialSigma < 1.0 : spatialSigma = 1.0 : EndIf
  If rangeSigma < 1.0 : rangeSigma = 1.0 : EndIf
  
  ; Grille plus fine pour éviter les artefacts
  Protected gridSizeXY = 64
  Protected gridSizeL = 32
  
  ; Structure pour chaque cellule de la grille
  Structure GridCell
    r.q
    g.q
    b.q
    a.q
    count.q
  EndStructure
  
  ; Allocation de la grille
  Protected gridSize.q = gridSizeXY * gridSizeXY * gridSizeL
  Protected *grid.GridCell = AllocateMemory(gridSize * SizeOf(GridCell))
  If Not *grid : ProcedureReturn : EndIf
  
  ; Initialisation à zéro
  FillMemory(*grid, gridSize * SizeOf(GridCell), 0)
  
  Protected x, y, index, value
  Protected r, g, b, a, lum
  Protected gx.f, gy.f, gl.f
  Protected ix, iy, il
  Protected *cell.GridCell
  
  ; ==== Phase 1: Splat avec accumulation ====
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      index = (y * lg + x) << 2
      value = PeekL(*param\addr[0] + index)
      
      a = (value >> 24) & $FF
      r = (value >> 16) & $FF
      g = (value >> 8) & $FF
      b = value & $FF
      
      ; Luminance
      lum = (r * 77 + g * 150 + b * 29) >> 8
      
      ; Position dans la grille (normalisée par sigma)
      gx = (x * (gridSizeXY - 1.0)) / (lg * spatialSigma)
      gy = (y * (gridSizeXY - 1.0)) / (ht * spatialSigma)
      gl = (lum * (gridSizeL - 1.0)) / (255.0 * rangeSigma)
      
      ; Position entière
      ix = Int(gx)
      iy = Int(gy)
      il = Int(gl)
      
      Clamp(ix, 0, gridSizeXY - 1)
      Clamp(iy, 0, gridSizeXY - 1)
      Clamp(il, 0, gridSizeL - 1)
      
      ; Accumulation dans la cellule
      *cell = *grid + (il * gridSizeXY * gridSizeXY + iy * gridSizeXY + ix) * SizeOf(GridCell)
      *cell\r + r
      *cell\g + g
      *cell\b + b
      *cell\a + a
      *cell\count + 1
    Next
  Next
  
  ; ==== Phase 2: Calcul des moyennes dans la grille ====
  Protected i, j, k
  For k = 0 To gridSizeL - 1
    For j = 0 To gridSizeXY - 1
      For i = 0 To gridSizeXY - 1
        *cell = *grid + (k * gridSizeXY * gridSizeXY + j * gridSizeXY + i) * SizeOf(GridCell)
        If *cell\count > 0
          *cell\r / *cell\count
          *cell\g / *cell\count
          *cell\b / *cell\count
          *cell\a / *cell\count
          *cell\count = 1  ; Marquer comme valide
        EndIf
      Next
    Next
  Next
  
  ; ==== Phase 3: Blur dans le lattice (5x5x5 pour plus de douceur) ====
  Protected *blurred.GridCell = AllocateMemory(gridSize * SizeOf(GridCell))
  If Not *blurred
    FreeMemory(*grid)
    ProcedureReturn
  EndIf
  
  Protected dx, dy, dz, nx, ny, nz
  Protected *srcCell.GridCell, *dstCell.GridCell
  Protected blurRadius = 2
  
  For k = 0 To gridSizeL - 1
    For j = 0 To gridSizeXY - 1
      For i = 0 To gridSizeXY - 1
        Protected sumR.q = 0, sumG.q = 0, sumB.q = 0, sumA.q = 0, sumCount.q = 0
        
        ; Kernel de flou
        For dz = -blurRadius To blurRadius
          nz = k + dz
          If nz < 0 Or nz >= gridSizeL : Continue : EndIf
          
          For dy = -blurRadius To blurRadius
            ny = j + dy
            If ny < 0 Or ny >= gridSizeXY : Continue : EndIf
            
            For dx = -blurRadius To blurRadius
              nx = i + dx
              If nx < 0 Or nx >= gridSizeXY : Continue : EndIf
              
              *srcCell = *grid + (nz * gridSizeXY * gridSizeXY + ny * gridSizeXY + nx) * SizeOf(GridCell)
              
              If *srcCell\count > 0
                sumR + *srcCell\r
                sumG + *srcCell\g
                sumB + *srcCell\b
                sumA + *srcCell\a
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
  
  ; ==== Phase 4: Slice avec interpolation trilinéaire ====
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      index = (y * lg + x) << 2
      value = PeekL(*param\addr[0] + index)
      
      r = (value >> 16) & $FF
      g = (value >> 8) & $FF
      b = value & $FF
      a = (value >> 24) & $FF
      lum = (r * 77 + g * 150 + b * 29) >> 8
      
      ; Position dans la grille
      gx = (x * (gridSizeXY - 1.0)) / (lg * spatialSigma)
      gy = (y * (gridSizeXY - 1.0)) / (ht * spatialSigma)
      gl = (lum * (gridSizeL - 1.0)) / (255.0 * rangeSigma)
      
      ix = Int(gx)
      iy = Int(gy)
      il = Int(gl)
      
      Clamp(ix, 0, gridSizeXY - 2)
      Clamp(iy, 0, gridSizeXY - 2)
      Clamp(il, 0, gridSizeL - 2)
      
      ; Interpolation trilinéaire simple (moyenne des 8 voisins)
      sumR.q = 0: sumG.q = 0: sumB.q = 0: sumA.q = 0
      Protected validCount = 0
      
      For dz = 0 To 1
        For dy = 0 To 1
          For dx = 0 To 1
            *cell = *blurred + ((il + dz) * gridSizeXY * gridSizeXY + (iy + dy) * gridSizeXY + (ix + dx)) * SizeOf(GridCell)
            If *cell\count > 0
              sumR + *cell\r
              sumG + *cell\g
              sumB + *cell\b
              sumA + *cell\a
              validCount + 1
            EndIf
          Next
        Next
      Next
      
      If validCount > 0
        r = sumR / validCount
        g = sumG / validCount
        b = sumB / validCount
        a = sumA / validCount
      EndIf
      
      Clamp(r, 0, 255)
      Clamp(g, 0, 255)
      Clamp(b, 0, 255)
      Clamp(a, 0, 255)
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
  
  FreeMemory(*blurred)
  FreeMemory(*grid)
EndProcedure

Procedure PermutohedralLattice(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Advanced
    *param\name = "PermutohedralLattice"
    *param\remarque = "Filtrage bilateral rapide via lattice 3D"
    *param\info[0] = "Sigma spatial"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 10 : *param\info_data(0, 2) = 3
    *param\info[1] = "Sigma couleur"
    *param\info_data(1, 0) = 1 : *param\info_data(1, 1) = 30 : *param\info_data(1, 2) = 8
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 10)
  Clamp(*param\option[1], 1, 30)
  
  filter_start(@PermutohedralLattice_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 173
; FirstLine = 157
; Folding = -
; EnableXP
; DPIAware