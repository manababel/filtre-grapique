; ---------------------------------------------------
; Laplacian Pyramid Blur - Version OPTIMISÉE
; ---------------------------------------------------

; Optimisation de la mise à l'échelle (Bilinear Interpolation)
Procedure LaplacianPyramidBlur_ScaleImage_opt(*src.PixelArray, oldW, oldH, *dst.PixelArray, newW, newH)
  Protected x, y, sx, sy, v, v1
  Protected.f fx, fy, dx, dy, d1, d2
  Protected.l a0, r0, g0, b0, a1, r1, g1, b1, a2, r2, g2, b2, a3, r3, g3, b3
  Protected a, r, g, b
  
  ; Précalcul des coordonnées X pour éviter les divisions dans la boucle interne
  Dim lookup_x.i(newW - 1)
  Dim lookup_dx.f(newW - 1)
  
  If newW > 1
    For x = 0 To newW - 1
      fx = x * (oldW - 1) / (newW - 1)
      lookup_x(x) = Int(fx)
      lookup_dx(x) = fx - lookup_x(x)
    Next
  Else
    lookup_x(0) = 0
    lookup_dx(0) = 0
  EndIf

  For y = 0 To newH - 1
    If newH > 1
      fy = y * (oldH - 1) / (newH - 1)
    Else
      fy = 0
    EndIf
    sy = Int(fy)
    dy = fy - sy
    d2 = 1.0 - dy
    
    ; Bornage Y
    If sy < 0 : sy = 0 : ElseIf sy > oldH - 1 : sy = oldH - 1 : EndIf
    v1 = sy + 1
    If v1 > oldH - 1 : v1 = oldH - 1 : EndIf
    
    Protected sy_oldW = sy * oldW
    Protected v1_oldW = v1 * oldW
    Protected y_newW = y * newW

    For x = 0 To newW - 1
      sx = lookup_x(x)
      dx = lookup_dx(x)
      d1 = 1.0 - dx
      
      v = sx + 1
      If v > oldW - 1 : v = oldW - 1 : EndIf
      
      ; Accès directs mémoire sans Peek
      getargb(*src\l[sy_oldW + sx], a0, r0, g0, b0)
      getargb(*src\l[sy_oldW + v],  a1, r1, g1, b1)
      getargb(*src\l[v1_oldW + sx], a2, r2, g2, b2)
      getargb(*src\l[v1_oldW + v],  a3, r3, g3, b3)
      
      ; Interpolation bilinéaire rapide
      a = a0 * d1 * d2 + a1 * dx * d2 + a2 * d1 * dy + a3 * dx * dy
      r = r0 * d1 * d2 + r1 * dx * d2 + r2 * d1 * dy + r3 * dx * dy
      g = g0 * d1 * d2 + g1 * dx * d2 + g2 * d1 * dy + g3 * dx * dy
      b = b0 * d1 * d2 + b1 * dx * d2 + b2 * d1 * dy + b3 * dx * dy
      
      *dst\l[y_newW + x] = (a << 24) | (r << 16) | (g << 8) | b
    Next
  Next
EndProcedure

Procedure LaplacianPyramidBlur_UpscaleImage_opt(*src, oldW, oldH, *dst, newW, newH)
  LaplacianPyramidBlur_ScaleImage_opt(*src, oldW, oldH, *dst, newW, newH)
EndProcedure

; Optimisation majeure : Algorithme Box Blur en O(1) par fenêtre glissante (Sliding Window)
Procedure LaplacianPyramidBlur_BlurBuffer_opt(*buf.PixelArray, w, h, radius)
  If radius < 1 : ProcedureReturn : EndIf
  
  Protected *tmp.PixelArray = AllocateMemory(w * h * 4)
  If Not *tmp : ProcedureReturn : EndIf
  
  Protected x, y, li, ri, val
  Protected.q sa, sr, sg, sb ; Utilisation de Quad pour éviter les débordements de somme
  Protected.l a, r, g, b
  Protected div.f = 1.0 / (radius * 2 + 1)
  
  ; 1. Passe Horizontale (Fenêtre glissante)
  For y = 0 To h - 1
    sa = 0 : sr = 0 : sg = 0 : sb = 0
    Protected y_w = y * w
    
    ; Initialisation de la fenêtre pour le premier pixel (x = 0)
    For x = -radius To radius
      val = x
      If val < 0 : val = 0 : ElseIf val > w - 1 : val = w - 1 : EndIf
      getargb(*buf\l[y_w + val], a, r, g, b)
      sa + a : sr + r : sg + g : sb + b
    Next
    *tmp\l[y_w] = (Int(sa * div) << 24) | (Int(sr * div) << 16) | (Int(sg * div) << 8) | Int(sb * div)
    
    ; Glissement de la fenêtre
    For x = 1 To w - 1
      li = x - radius - 1
      ri = x + radius
      If li < 0 : li = 0 : EndIf
      If ri > w - 1 : ri = w - 1 : EndIf
      
      ; Retirer le pixel sortant (gauche)
      getargb(*buf\l[y_w + li], a, r, g, b)
      sa - a : sr - r : sg - g : sb - b
      
      ; Ajouter le pixel entrant (droite)
      getargb(*buf\l[y_w + ri], a, r, g, b)
      sa + a : sr + r : sg + g : sb + b
      
      *tmp\l[y_w + x] = (Int(sa * div) << 24) | (Int(sr * div) << 16) | (Int(sg * div) << 8) | Int(sb * div)
    Next
  Next
  
  ; 2. Passe Verticale (Fenêtre glissante)
  For x = 0 To w - 1
    sa = 0 : sr = 0 : sg = 0 : sb = 0
    
    ; Initialisation de la fenêtre verticale (y = 0)
    For y = -radius To radius
      val = y
      If val < 0 : val = 0 : ElseIf val > h - 1 : val = h - 1 : EndIf
      getargb(*tmp\l[val * w + x], a, r, g, b)
      sa + a : sr + r : sg + g : sb + b
    Next
    *buf\l[x] = (Int(sa * div) << 24) | (Int(sr * div) << 16) | (Int(sg * div) << 8) | Int(sb * div)
    
    ; Glissement de la fenêtre
    For y = 1 To h - 1
      li = y - radius - 1
      ri = y + radius
      If li < 0 : li = 0 : EndIf
      If ri > h - 1 : ri = h - 1 : EndIf
      
      ; Retirer le pixel sortant (haut)
      getargb(*tmp\l[li * w + x], a, r, g, b)
      sa - a : sr - r : sg - g : sb - b
      
      ; Ajouter le pixel entrant (bas)
      getargb(*tmp\l[ri * w + x], a, r, g, b)
      sa + a : sr + r : sg + g : sb + b
      
      *buf\l[y * w + x] = (Int(sa * div) << 24) | (Int(sr * div) << 16) | (Int(sg * div) << 8) | Int(sb * div)
    Next
  Next
  
  FreeMemory(*tmp)
EndProcedure

Procedure LaplacianPyramidBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected levels = \option[0]
    Protected kernel = \option[1]
    Protected.l a1, r1, g1, b1, a2, r2, g2, b2
    
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
    
    Protected l, i, pixelCount
    Protected *temp.PixelArray = AllocateMemory(lg * ht * 4)
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
    LaplacianPyramidBlur_ScaleImage_opt(\addr[0], lg, ht, pyramid(0), lg, ht)
    
    For l = 1 To levels - 1
      Protected srcW = lg >> (l - 1)
      Protected srcH = ht >> (l - 1)
      Protected dstW = lg >> l
      Protected dstH = ht >> l
      LaplacianPyramidBlur_ScaleImage_opt(pyramid(l - 1), srcW, srcH, pyramid(l), dstW, dstH)
    Next
    
    ; 2. Calcul des niveaux laplaciens (différences)
    ; Typage direct des buffers pour éviter PeekL/PokeL
    Protected *pyramid_l.PixelArray
    Protected *laplacian_l.PixelArray
    
    For l = 0 To levels - 2
      Protected currW = lg >> l
      Protected currH = ht >> l
      Protected nextW = lg >> (l + 1)
      Protected nextH = ht >> (l + 1)
      
      LaplacianPyramidBlur_UpscaleImage_opt(pyramid(l + 1), nextW, nextH, *temp, currW, currH)
      
      *pyramid_l = pyramid(l)
      *laplacian_l = laplacian_tab(l)
      pixelCount = currW * currH
      
      For i = 0 To pixelCount - 1
        ; Remplacement des PeekL/PokeL par un adressage direct par pointeur
        getargb(*pyramid_l\l[i], a1, r1, g1, b1)
        getargb(*temp\l[i], a2, r2, g2, b2)
        
        a1 = a1 - a2 + 128
        r1 = r1 - r2 + 128
        g1 = g1 - g2 + 128
        b1 = b1 - b2 + 128
        
        clamp_argb(a1, r1, g1, b1)
        
        *laplacian_l\l[i] = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
      Next
    Next
    
    ; 3. Application du flou multi-échelle
    For l = 0 To levels - 1
      LaplacianPyramidBlur_BlurBuffer_opt(pyramid(l), lg >> l, ht >> l, kernel)
    Next
    
    ; 4. Reconstruction
    For l = levels - 2 To 0 Step -1
      currW = lg >> l
      currH = ht >> l
      nextW = lg >> (l + 1)
      nextH = ht >> (l + 1)
      
      LaplacianPyramidBlur_UpscaleImage_opt(pyramid(l + 1), nextW, nextH, *temp, currW, currH)
      
      *pyramid_l = pyramid(l)
      *laplacian_l = laplacian_tab(l)
      pixelCount = currW * currH
      
      For i = 0 To pixelCount - 1
        getargb(*temp\l[i], a1, r1, g1, b1)
        getargb(*laplacian_l\l[i], a2, r2, g2, b2)
        
        a1 = a1 + (a2 - 128)
        r1 = r1 + (r2 - 128)
        g1 = g1 + (g2 - 128)
        b1 = b1 + (b2 - 128)
        
        clamp_argb(a1, r1, g1, b1)
        
        *pyramid_l\l[i] = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
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
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  ; On lance en mono-thread car la gestion de la pyramide est séquentielle
  Create_MultiThread_MT(@LaplacianPyramidBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure LaplacianPyramidBlur(source, cible, mask, levels, kernel)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = kernel
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
; CursorPosition = 3
; Folding = --
; EnableXP
; DPIAware