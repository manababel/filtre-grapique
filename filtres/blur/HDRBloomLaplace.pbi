Procedure ExtractHighlights(*src, *dst, w, h, threshold)
  Protected x, y, idx
  Protected r, g, b, a, lum
  Protected total = w * h
  
  For idx = 0 To total - 1
    Protected offset = idx << 2
    Protected pixel = PeekL(*src + offset)
    
    ; Extraction ARGB
    a = (pixel >> 24) & $FF
    r = (pixel >> 16) & $FF
    g = (pixel >> 8) & $FF
    b = pixel & $FF
    
    ; Calcul de la luminance (formule standard ITU-R BT.709)
    lum = (r * 77 + g * 150 + b * 29) >> 8
    
    If lum > threshold
      ; Conserver le pixel avec sa couleur complète
      PokeL(*dst + offset, pixel)
    Else
      ; Pixel noir transparent
      PokeL(*dst + offset, 0)
    EndIf
  Next
EndProcedure

Procedure HDRBloomLaplace_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected levels = *param\option[0]
  Protected kernel = *param\option[1]
  Protected threshold = *param\option[2]
  Protected intensity.f = *param\option[3] / 100.0  ; Intensité du bloom (0-200%)
  
  If levels < 1 : levels = 1 : EndIf
  If kernel < 1 : kernel = 1 : EndIf
  If threshold < 0 : threshold = 0 : EndIf
  If threshold > 255 : threshold = 255 : EndIf
  
  ; Limitation du nombre de niveaux
  Protected maxLevels = 1
  Protected minDim = lg
  If ht < minDim : minDim = ht : EndIf
  While minDim >> maxLevels >= 4
    maxLevels + 1
  Wend
  If levels > maxLevels : levels = maxLevels : EndIf
  
  Protected l, i, pixelCount
  Protected *temp = AllocateMemory(lg * ht * 4)
  Protected *highlights = AllocateMemory(lg * ht * 4)
  
  If Not *temp Or Not *highlights
    If *temp : FreeMemory(*temp) : EndIf
    If *highlights : FreeMemory(*highlights) : EndIf
    ProcedureReturn
  EndIf
  
  ; Extraction des hautes lumières
  ExtractHighlights(*param\addr[0], *highlights, lg, ht, threshold)
  
  Dim pyramid.i(levels - 1)
  Dim laplacian_tab.i(levels - 2)
  
  ; Allocation de la pyramide
  For l = 0 To levels - 1
    pixelCount = (lg >> l) * (ht >> l) * 4
    pyramid(l) = AllocateMemory(pixelCount)
    If Not pyramid(l)
      For i = 0 To l - 1
        If pyramid(i) : FreeMemory(pyramid(i)) : EndIf
      Next
      FreeMemory(*temp)
      FreeMemory(*highlights)
      ProcedureReturn
    EndIf
  Next
  
  ; Allocation des niveaux laplaciens
  For l = 0 To levels - 2
    pixelCount = (lg >> l) * (ht >> l) * 4
    laplacian_tab(l) = AllocateMemory(pixelCount)
    If Not laplacian_tab(l)
      For i = 0 To l - 1
        If laplacian_tab(i) : FreeMemory(laplacian_tab(i)) : EndIf
      Next
      For i = 0 To levels - 1
        If pyramid(i) : FreeMemory(pyramid(i)) : EndIf
      Next
      FreeMemory(*temp)
      FreeMemory(*highlights)
      ProcedureReturn
    EndIf
  Next
  
  ; Construction de la pyramide
  LaplacianPyramidBlur_ScaleImage(*highlights, lg, ht, pyramid(0), lg, ht)
  
  For l = 1 To levels - 1
    Protected srcW = lg >> (l - 1)
    Protected srcH = ht >> (l - 1)
    Protected dstW = lg >> l
    Protected dstH = ht >> l
    LaplacianPyramidBlur_ScaleImage(pyramid(l - 1), srcW, srcH, pyramid(l), dstW, dstH)
  Next
  
  ; Calcul des niveaux laplaciens (différences avec offset)
  For l = 0 To levels - 2
    Protected currW = lg >> l
    Protected currH = ht >> l
    Protected nextW = lg >> (l + 1)
    Protected nextH = ht >> (l + 1)
    
    LaplacianPyramidBlur_UpscaleImage(pyramid(l + 1), nextW, nextH, *temp, currW, currH)
    
    pixelCount = currW * currH
    For i = 0 To pixelCount - 1
      Protected offset = i << 2
      Protected curr = PeekL(pyramid(l) + offset)
      Protected temp = PeekL(*temp + offset)
      
      ; Extraction et calcul des différences avec offset +128
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
      
      Clamp(da, 0, 255)
      Clamp(dr, 0, 255)
      Clamp(dg, 0, 255)
      Clamp(db, 0, 255)
      
      PokeL(laplacian_tab(l) + offset, (da << 24) | (dr << 16) | (dg << 8) | db)
    Next
  Next
  
  ; Flou multi-échelle
  For l = 0 To levels - 1
    LaplacianPyramidBlur_BlurBuffer(pyramid(l), lg >> l, ht >> l, kernel)
  Next
  
  ; Reconstruction
  For l = levels - 2 To 0 Step -1
     currW = lg >> l
     currH = ht >> l
     nextW = lg >> (l + 1)
     nextH = ht >> (l + 1)
    
    LaplacianPyramidBlur_UpscaleImage(pyramid(l + 1), nextW, nextH, *temp, currW, currH)
    
    pixelCount = currW * currH
    For i = 0 To pixelCount - 1
       offset = i << 2
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
      
      ; Reconstruction avec compensation de l'offset
      Protected a_out = at + (al - 128)
      Protected r_out = rt + (rl - 128)
      Protected g_out = gt + (gl - 128)
      Protected b_out = bt + (bl - 128)
      
      Clamp(a_out, 0, 255)
      Clamp(r_out, 0, 255)
      Clamp(g_out, 0, 255)
      Clamp(b_out, 0, 255)
      
      PokeL(pyramid(l) + offset, (a_out << 24) | (r_out << 16) | (g_out << 8) | b_out)
    Next
  Next
  
  ; Ajout du bloom à l'image originale avec contrôle d'intensité
  pixelCount = lg * ht
  For i = 0 To pixelCount - 1
     offset = i << 2
    Protected orig = PeekL(*param\addr[0] + offset)
    Protected glow = PeekL(pyramid(0) + offset)
    
    Protected a_orig = (orig >> 24) & $FF
    Protected r_orig = (orig >> 16) & $FF
    Protected g_orig = (orig >> 8) & $FF
    Protected b_orig = orig & $FF
    
    Protected r_glow = (glow >> 16) & $FF
    Protected g_glow = (glow >> 8) & $FF
    Protected b_glow = glow & $FF
    
    ; Application du bloom avec intensité contrôlable
    Protected r_final = r_orig + Int(r_glow * intensity)
    Protected g_final = g_orig + Int(g_glow * intensity)
    Protected b_final = b_orig + Int(b_glow * intensity)
    
    Clamp(r_final, 0, 255)
    Clamp(g_final, 0, 255)
    Clamp(b_final, 0, 255)
    
    PokeL(*param\addr[1] + offset, (a_orig << 24) | (r_final << 16) | (g_final << 8) | b_final)
  Next
  
  ; Libération
  For l = 0 To levels - 1
    If pyramid(l) : FreeMemory(pyramid(l)) : EndIf
  Next
  For l = 0 To levels - 2
    If laplacian_tab(l) : FreeMemory(laplacian_tab(l)) : EndIf
  Next
  FreeMemory(*temp)
  FreeMemory(*highlights)
EndProcedure

Procedure HDRBloomLaplace(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_MultiScale
    *param\name = "HDR / Bloom Laplacien"
    *param\remarque = "Glow / Bloom basé sur pyramide de Laplace"
    *param\info[0] = "Niveaux"
    *param\info[1] = "Kernel"
    *param\info[2] = "Seuil luminosité"
    *param\info[3] = "Intensité (%)"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 6 : *param\info_data(0, 2) = 3
    *param\info_data(1, 0) = 1 : *param\info_data(1, 1) = 20 : *param\info_data(1, 2) = 5
    *param\info_data(2, 0) = 128 : *param\info_data(2, 1) = 255 : *param\info_data(2, 2) = 200
    *param\info_data(3, 0) = 0 : *param\info_data(3, 1) = 200 : *param\info_data(3, 2) = 100
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 6)
  Clamp(*param\option[1], 1, 20)
  Clamp(*param\option[2], 128, 255)
  Clamp(*param\option[3], 0, 200)
  
  filter_start(@HDRBloomLaplace_sp(), 1)
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 195
; FirstLine = 187
; Folding = -
; EnableXP
; DPIAware