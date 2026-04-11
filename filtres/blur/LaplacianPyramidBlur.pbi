Procedure LaplacianPyramidBlur_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected levels = *param\option[0]
  Protected kernel = *param\option[1]
  
  ; Validation des paramètres
  If levels < 1 : levels = 1 : EndIf
  If kernel < 1 : kernel = 1 : EndIf
  
  ; Limitation du nombre de niveaux en fonction de la taille de l'image
  Protected maxLevels = 1
  Protected minDim = lg
  If ht < minDim : minDim = ht : EndIf
  While minDim >> maxLevels >= 4
    maxLevels + 1
  Wend
  If levels > maxLevels : levels = maxLevels : EndIf
  
  Protected l, i, pixelCount
  Protected *temp = AllocateMemory(lg * ht * 4)
  If Not *temp : ProcedureReturn : EndIf
  
  Dim pyramid.i(levels - 1)
  Dim laplacian_tab.i(levels - 2)
  
  ; Allocation de la pyramide
  For l = 0 To levels - 1
    pixelCount = (lg >> l) * (ht >> l) * 4
    pyramid(l) = AllocateMemory(pixelCount)
    If Not pyramid(l)
      ; Libération en cas d'échec
      For i = 0 To l - 1
        If pyramid(i) : FreeMemory(pyramid(i)) : EndIf
      Next
      FreeMemory(*temp)
      ProcedureReturn
    EndIf
  Next
  
  ; Allocation des niveaux laplaciens
  For l = 0 To levels - 2
    pixelCount = (lg >> l) * (ht >> l) * 4
    laplacian_tab(l) = AllocateMemory(pixelCount)
    If Not laplacian_tab(l)
      ; Libération en cas d'échec
      For i = 0 To l - 1
        If laplacian_tab(i) : FreeMemory(laplacian_tab(i)) : EndIf
      Next
      For i = 0 To levels - 1
        If pyramid(i) : FreeMemory(pyramid(i)) : EndIf
      Next
      FreeMemory(*temp)
      ProcedureReturn
    EndIf
  Next
  
  ; Construction de la pyramide gaussienne
  LaplacianPyramidBlur_ScaleImage(*param\addr[0], lg, ht, pyramid(0), lg, ht)
  
  For l = 1 To levels - 1
    Protected srcW = lg >> (l - 1)
    Protected srcH = ht >> (l - 1)
    Protected dstW = lg >> l
    Protected dstH = ht >> l
    LaplacianPyramidBlur_ScaleImage(pyramid(l - 1), srcW, srcH, pyramid(l), dstW, dstH)
  Next
  
  ; Calcul des niveaux laplaciens (différences)
  For l = 0 To levels - 2
    Protected currW = lg >> l
    Protected currH = ht >> l
    Protected nextW = lg >> (l + 1)
    Protected nextH = ht >> (l + 1)
    
    ; Upscale du niveau inférieur
    LaplacianPyramidBlur_UpscaleImage(pyramid(l + 1), nextW, nextH, *temp, currW, currH)
    
    ; Calcul de la différence (canal par canal pour éviter underflow)
    pixelCount = currW * currH
    For i = 0 To pixelCount - 1
      Protected offset = i * 4
      Protected curr = PeekL(pyramid(l) + offset)
      Protected temp = PeekL(*temp + offset)
      
      Protected a1 = (curr >> 24) & 255
      Protected r1 = (curr >> 16) & 255
      Protected g1 = (curr >> 8) & 255
      Protected b1 = curr & 255
      
      Protected a2 = (temp >> 24) & 255
      Protected r2 = (temp >> 16) & 255
      Protected g2 = (temp >> 8) & 255
      Protected b2 = temp & 255
      
      ; Différence avec gestion du signe (stockage en signed)
      Protected da = a1 - a2 + 128
      Protected dr = r1 - r2 + 128
      Protected dg = g1 - g2 + 128
      Protected db = b1 - b2 + 128
      
      ; Clamp pour éviter débordement
      Clamp(da, 0, 255)
      Clamp(dr, 0, 255)
      Clamp(dg, 0, 255)
      Clamp(db, 0, 255)
      
      PokeL(laplacian_tab(l) + offset, (da << 24) | (dr << 16) | (dg << 8) | db)
    Next
  Next
  
  ; Application du flou multi-échelle sur chaque niveau
  For l = 0 To levels - 1
    LaplacianPyramidBlur_BlurBuffer(pyramid(l), lg >> l, ht >> l, kernel)
  Next
  
  ; Reconstruction de l'image (du bas vers le haut)
  For l = levels - 2 To 0 Step -1
     currW = lg >> l
     currH = ht >> l
     nextW = lg >> (l + 1)
     nextH = ht >> (l + 1)
    
    ; Upscale du niveau inférieur
    LaplacianPyramidBlur_UpscaleImage(pyramid(l + 1), nextW, nextH, *temp, currW, currH)
    
    ; Addition avec le niveau laplacien
    pixelCount = currW * currH
    For i = 0 To pixelCount - 1
       offset = i * 4
       temp = PeekL(*temp + offset)
      Protected lap = PeekL(laplacian_tab(l) + offset)
      
      Protected at = (temp >> 24) & 255
      Protected rt = (temp >> 16) & 255
      Protected gt = (temp >> 8) & 255
      Protected bt = temp & 255
      
      Protected al = (lap >> 24) & 255
      Protected rl = (lap >> 16) & 255
      Protected gl = (lap >> 8) & 255
      Protected bl = lap & 255
      
      ; Reconstruction avec compensation du décalage
      Protected a_out = at + (al - 128)
      Protected r_out = rt + (rl - 128)
      Protected g_out = gt + (gl - 128)
      Protected b_out = bt + (bl - 128)
      
      ; Clamp final
      Clamp(a_out, 0, 255)
      Clamp(r_out, 0, 255)
      Clamp(g_out, 0, 255)
      Clamp(b_out, 0, 255)
      
      PokeL(pyramid(l) + offset, (a_out << 24) | (r_out << 16) | (g_out << 8) | b_out)
    Next
  Next
  
  ; Copie du résultat final
  CopyMemory(pyramid(0), *param\addr[1], lg * ht * 4)
  
  ; Libération de la mémoire
  For l = 0 To levels - 1
    If pyramid(l) : FreeMemory(pyramid(l)) : EndIf
  Next
  For l = 0 To levels - 2
    If laplacian_tab(l) : FreeMemory(laplacian_tab(l)) : EndIf
  Next
  If *temp : FreeMemory(*temp) : EndIf
EndProcedure

Procedure LaplacianPyramidBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_MultiScale
    *param\name = "LaplacianPyramidBlur"
    *param\remarque = "Flou multi-échelle basé sur la pyramide de Laplace"
    *param\info[0] = "Niveaux"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 6 : *param\info_data(0, 2) = 3
    *param\info[1] = "Taille du kernel"
    *param\info_data(1, 0) = 1 : *param\info_data(1, 1) = 20 : *param\info_data(1, 2) = 3
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 6)
  Clamp(*param\option[1], 1, 20)
  
  filter_start(@LaplacianPyramidBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 128
; FirstLine = 80
; Folding = -
; EnableXP
; DPIAware