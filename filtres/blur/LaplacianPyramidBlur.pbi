; ---------------------------------------------------
; Laplacian Pyramid Blur - Version optimisée
; Flou multi-échelle via décomposition pyramidale
; ---------------------------------------------------

Procedure LaplacianPyramidBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected levels = \option[0]
    Protected kernel = \option[1]
    
    ; Validation des paramètres
    If levels < 1 : levels = 1 : EndIf
    If kernel < 1 : kernel = 1 : EndIf
    
    ; Limitation du nombre de niveaux
    Protected maxLevels = 1
    Protected minDim = lg
    If ht < minDim : minDim = ht : EndIf
    While minDim >> maxLevels >= 4
      maxLevels + 1
    Wend
    If levels > maxLevels : levels = maxLevels : EndIf
    
    Protected l, i, pixelCount, offset
    Protected *temp = AllocateMemory(lg * ht * 4)
    If Not *temp : ProcedureReturn : EndIf
    
    Dim pyramid.i(levels - 1)
    Dim laplacian_tab.i(levels - 2)
    
    ; Allocation de la pyramide
    For l = 0 To levels - 1
      pixelCount = (lg >> l) * (ht >> l) * 4
      pyramid(l) = AllocateMemory(pixelCount)
      If Not pyramid(l)
        For i = 0 To l - 1 : FreeMemory(pyramid(i)) : Next
        FreeMemory(*temp) : ProcedureReturn
      EndIf
    Next
    
    ; Allocation des niveaux laplaciens
    For l = 0 To levels - 2
      pixelCount = (lg >> l) * (ht >> l) * 4
      laplacian_tab(l) = AllocateMemory(pixelCount)
      If Not laplacian_tab(l)
        For i = 0 To l - 1 : FreeMemory(laplacian_tab(i)) : Next
        For i = 0 To levels - 1 : FreeMemory(pyramid(i)) : Next
        FreeMemory(*temp) : ProcedureReturn
      EndIf
    Next
    
    ; 1. Construction de la pyramide gaussienne
    ; On suppose que LaplacianPyramidBlur_ScaleImage est définie globalement
    LaplacianPyramidBlur_ScaleImage(\addr[0], lg, ht, pyramid(0), lg, ht)
    
    For l = 1 To levels - 1
      Protected srcW = lg >> (l - 1)
      Protected srcH = ht >> (l - 1)
      Protected dstW = lg >> l
      Protected dstH = ht >> l
      LaplacianPyramidBlur_ScaleImage(pyramid(l - 1), srcW, srcH, pyramid(l), dstW, dstH)
    Next
    
    ; 2. Calcul des niveaux laplaciens (différences)
    For l = 0 To levels - 2
      Protected currW = lg >> l
      Protected currH = ht >> l
      Protected nextW = lg >> (l + 1)
      Protected nextH = ht >> (l + 1)
      
      LaplacianPyramidBlur_UpscaleImage(pyramid(l + 1), nextW, nextH, *temp, currW, currH)
      
      pixelCount = currW * currH
      For i = 0 To pixelCount - 1
        offset = i * 4
        Protected curr = PeekL(pyramid(l) + offset)
        Protected temp = PeekL(*temp + offset)
        
        Protected a1 = (curr >> 24) & $FF
        Protected r1 = (curr >> 16) & $FF
        Protected g1 = (curr >> 8) & $FF
        Protected b1 = curr & $FF
        
        Protected a2 = (temp >> 24) & $FF
        Protected r2 = (temp >> 16) & $FF
        Protected g2 = (temp >> 8) & $FF
        Protected b2 = temp & $FF
        
        Protected da = a1 - a2 + 128
        Protected dr = r1 - r2 + 128
        Protected dg = g1 - g2 + 128
        Protected db = b1 - b2 + 128
        
        If da < 0 : da = 0 : ElseIf da > 255 : da = 255 : EndIf
        If dr < 0 : dr = 0 : ElseIf dr > 255 : dr = 255 : EndIf
        If dg < 0 : dg = 0 : ElseIf dg > 255 : dg = 255 : EndIf
        If db < 0 : db = 0 : ElseIf db > 255 : db = 255 : EndIf
        
        PokeL(laplacian_tab(l) + offset, (da << 24) | (dr << 16) | (dg << 8) | db)
      Next
    Next
    
    ; 3. Application du flou multi-échelle
    For l = 0 To levels - 1
      LaplacianPyramidBlur_BlurBuffer(pyramid(l), lg >> l, ht >> l, kernel)
    Next
    
    ; 4. Reconstruction
    For l = levels - 2 To 0 Step -1
      currW = lg >> l
      currH = ht >> l
      nextW = lg >> (l + 1)
      nextH = ht >> (l + 1)
      
      LaplacianPyramidBlur_UpscaleImage(pyramid(l + 1), nextW, nextH, *temp, currW, currH)
      
      pixelCount = currW * currH
      For i = 0 To pixelCount - 1
        offset = i * 4
        temp = PeekL(*temp + offset)
        Protected lap = PeekL(laplacian_tab(l) + offset)
        
        Protected at = (temp >> 24) & $FF
        Protected rt = (temp >> 16) & $FF
        Protected gt = (temp >> 8) & $FF
        Protected bt = temp & $FF
        
        Protected al = (lap >> 24) & $FF
        Protected rl = (lap >> 16) & $FF
        Protected gl = (lap >> 8) & $FF
        Protected bl = lap & $FF
        
        Protected a_out = at + (al - 128)
        Protected r_out = rt + (rl - 128)
        Protected g_out = gt + (gl - 128)
        Protected b_out = bt + (bl - 128)
        
        If a_out < 0 : a_out = 0 : ElseIf a_out > 255 : a_out = 255 : EndIf
        If r_out < 0 : r_out = 0 : ElseIf r_out > 255 : r_out = 255 : EndIf
        If g_out < 0 : g_out = 0 : ElseIf g_out > 255 : g_out = 255 : EndIf
        If b_out < 0 : b_out = 0 : ElseIf b_out > 255 : b_out = 255 : EndIf
        
        PokeL(pyramid(l) + offset, (a_out << 24) | (r_out << 16) | (g_out << 8) | b_out)
      Next
    Next
    
    ; Copie vers cible
    CopyMemory(pyramid(0), \addr[1], lg * ht * 4)
    
    ; Nettoyage
    For l = 0 To levels - 1 : FreeMemory(pyramid(l)) : Next
    For l = 0 To levels - 2 : FreeMemory(laplacian_tab(l)) : Next
    FreeMemory(*temp)
  EndWith
EndProcedure

Procedure LaplacianPyramidBlurEx(*FilterCtx.FilterParams)
  Restore LaplacianPyramidBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  ; On lance en mono-thread car la gestion de la pyramide est séquentielle
  Create_MultiThread_MT(@LaplacianPyramidBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure LaplacianPyramidBlur(source, cible, mask, levels, kernel)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = levels : \option[1] = kernel
  EndWith
  LaplacianPyramidBlurEx(FilterCtx)
EndProcedure

DataSection
  LaplacianPyramidBlur_data:
  Data.s "Laplacian Pyramid Blur"
  Data.s "Flou multi-échelle basé sur la décomposition de Laplace"
  Data.i #FilterType_Blur, #Blur_MultiScale
  Data.s "Niveaux"
  Data.i 1, 6, 3
  Data.s "Taille du kernel"
  Data.i 1, 20, 3
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 168
; FirstLine = 135
; Folding = -
; EnableXP
; DPIAware