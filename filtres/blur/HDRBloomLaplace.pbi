Procedure HDRBloomLaplace_LaplacianPyramidBlur_ScaleImage(*src, oldW, oldH, *dst, newW, newH)
  Protected x, y, sx, sy
  Protected fx.f, fy.f, dx.f, dy.f
  Protected a, r, g, b
  Protected a0, r0, g0, b0, a1, r1, g1, b1, a2, r2, g2, b2, a3, r3, g3, b3
  Protected v, v1
  
  Protected *nsrc.pixelarray = *src
  Protected *ndst.pixelarray = *dst
  
  For y = 0 To newH - 1
    If newH > 1 : fy = y * (oldH - 1.0) / (newH - 1.0) : Else : fy = 0.0 : EndIf
    sy = Int(fy) : dy = fy - sy
    
    For x = 0 To newW - 1
      If newW > 1 : fx = x * (oldW - 1.0) / (newW - 1.0) : Else : fx = 0.0 : EndIf
      sx = Int(fx) : dx = fx - sx
      
      CLAMP(sx, 0, oldW - 1)
      CLAMP(sy, 0, oldH - 1)
      
      v  = sx + 1 : CLAMP(v , 0, oldW - 1)
      v1 = sy + 1 : CLAMP(v1, 0, oldH - 1)
      
      getargb(*nsrc\l[sy * oldW + sx], a0, r0, g0, b0)
      getargb(*nsrc\l[sy * oldW + v ], a1, r1, g1, b1)
      getargb(*nsrc\l[v1 * oldW + sx], a2, r2, g2, b2)
      getargb(*nsrc\l[v1 * oldW + v ], a3, r3, g3, b3)

      Protected w0.f = (1.0 - dx) * (1.0 - dy)
      Protected w1.f = dx * (1.0 - dy)
      Protected w2.f = (1.0 - dx) * dy
      Protected w3.f = dx * dy
      
      a = Int(a0 * w0 + a1 * w1 + a2 * w2 + a3 * w3)
      r = Int(r0 * w0 + r1 * w1 + r2 * w2 + r3 * w3)
      g = Int(g0 * w0 + g1 * w1 + g2 * w2 + g3 * w3)
      b = Int(b0 * w0 + b1 * w1 + b2 * w2 + b3 * w3)
      
      clamp_argb(a, r, g, b)
      
      *ndst\l[y * newW + x] = (a << 24) | (r << 16) | (g << 8) | b
    Next
  Next
EndProcedure


Procedure HDRBloomLaplace_LaplacianPyramidBlur_UpscaleImage(*src, oldW, oldH, *dst, newW, newH)
  HDRBloomLaplace_LaplacianPyramidBlur_ScaleImage(*src, oldW, oldH, *dst, newW, newH)
EndProcedure


Procedure HDRBloomLaplace_LaplacianPyramidBlur_BlurBuffer_passe_horizontal(*FilterCtx.FilterParams)
  With *FilterCtx
    If \option[1] < 1 : ProcedureReturn : EndIf
    Protected *buf.pixelarray = \addr[3]
    Protected *tmp.pixelarray = \addr[4]
    Protected w = \option[4]
    Protected h = \option[5]
    Protected x, y, i, px
    Protected sr, sg, sb, sa, c
    Protected ca, cr, cg, cb
    
    macro_calul_tread(h) ; Découpe de la hauteur (lignes) entre threads
    
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        sr = 0 : sg = 0 : sb = 0 : sa = 0 : c = 0
        For i = -\option[1] To \option[1]
          px = x + i : CLAMP(px, 0, w - 1)
          getargb(*buf\l[y * w + px], ca, cr, cg, cb)
          sa + ca : sr + cr : sg + cg : sb + cb
          c + 1
        Next
        *tmp\l[y * w + x] = ((sa / c) << 24) | ((sr / c) << 16) | ((sg / c) << 8) | (sb / c)
      Next
    Next
  EndWith
EndProcedure

Procedure HDRBloomLaplace_LaplacianPyramidBlur_BlurBuffer_passe_vertical(*FilterCtx.FilterParams)
  With *FilterCtx
    If \option[1] < 1 : ProcedureReturn : EndIf
    Protected *buf.pixelarray = \addr[3]
    Protected *tmp.pixelarray = \addr[4]
    Protected w = \option[4]
    Protected h = \option[5]
    Protected x, y, i, py
    Protected sr, sg, sb, sa, c
    Protected ca, cr, cg, cb
    
    macro_calul_tread(w) ; Découpe de la largeur (colonnes) entre threads
    
    For x = thread_start To thread_stop - 1
      For y = 0 To h - 1
        sr = 0 : sg = 0 : sb = 0 : sa = 0 : c = 0
        For i = -\option[1] To \option[1]
          py = y + i : CLAMP(py, 0, h - 1)
          getargb(*tmp\l[py * w + x], ca, cr, cg, cb)
          sa + ca : sr + cr : sg + cg : sb + cb
          c + 1
        Next
        ; Correction : utilisation de w au lieu de \w
        *buf\l[y * w + x] = ((sa / c) << 24) | ((sr / c) << 16) | ((sg / c) << 8) | (sb / c)
      Next
    Next
  EndWith
EndProcedure


Procedure HDRBloomLaplace_ExtractHighlights(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected *src.pixelarray = \addr[0]
    Protected *dst.pixelarray = \addr[2]
    Protected threshold = \option[2]
    Protected idx ,var
    Protected r, g, b, a, lum
    Protected total = lg * ht
    
    For idx = 0 To total - 1
      var = *src\l[idx]
      getrgb(var, r, g, b)
      lum = (r * 77 + g * 150 + b * 29) >> 8
      If lum > threshold
        *dst\l[idx] = var
      Else
        *dst\l[idx] = 0
      EndIf
    Next
  EndWith
EndProcedure


Procedure HDRBloomLaplace_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected levels = \option[0]
    Protected kernel = \option[1]
    Protected threshold = \option[2]
    Protected intensity.f = \option[3] / 100.0
    If levels < 1 : levels = 1 : EndIf
    If kernel < 1 : kernel = 1 : EndIf
    Clamp(threshold, 0, 255)
    Protected maxLevels = 1
    Protected minDim = lg
    If ht < minDim : minDim = ht : EndIf
    While minDim >> maxLevels >= 4 : maxLevels + 1 : Wend
    If levels > maxLevels : levels = maxLevels : EndIf
    Protected l, i, pixelCount
    Protected *temp = AllocateMemory(lg * ht * 4)
    \addr[2] = AllocateMemory(lg * ht * 4)
    
    If Not *temp Or Not \addr[2]
      If *temp : FreeMemory(*temp) : EndIf
      If \addr[2] : FreeMemory(\addr[2]) : EndIf
      ProcedureReturn
    EndIf
    
    HDRBloomLaplace_ExtractHighlights(*FilterCtx)
    
    Dim pyramid.i(levels - 1)
    
    Protected lapLevels = levels - 2
    If lapLevels < 0 : lapLevels = 0 : EndIf
    Dim laplacian_tab.i(lapLevels)
    
    ; Allocation pyramide
    For l = 0 To levels - 1
      pixelCount = (lg >> l) * (ht >> l) * 4
      If pixelCount < 4 : pixelCount = 4 : EndIf
      pyramid(l) = AllocateMemory(pixelCount)
      If Not pyramid(l)
        For i = 0 To l - 1
          If pyramid(i) : FreeMemory(pyramid(i)) : EndIf
        Next
        FreeMemory(*temp)
        FreeMemory(\addr[2])
        ProcedureReturn
      EndIf
    Next
    
    ; Allocation laplacien
    If levels > 1
      For l = 0 To levels - 2
        pixelCount = (lg >> l) * (ht >> l) * 4
        If pixelCount < 4 : pixelCount = 4 : EndIf
        laplacian_tab(l) = AllocateMemory(pixelCount)
        If Not laplacian_tab(l)
          For i = 0 To l - 1
            If laplacian_tab(i) : FreeMemory(laplacian_tab(i)) : EndIf
          Next
          For i = 0 To levels - 1
            If pyramid(i) : FreeMemory(pyramid(i)) : EndIf
          Next
          FreeMemory(*temp)
          FreeMemory(\addr[2])
          ProcedureReturn
        EndIf
      Next
    EndIf
    
    ; Construction de la pyramide
    
    HDRBloomLaplace_LaplacianPyramidBlur_ScaleImage(\addr[2], lg, ht, pyramid(0), lg, ht)
    
    For l = 1 To levels - 1
      Protected srcW = lg >> (l - 1)
      Protected srcH = ht >> (l - 1)
      Protected dstW = lg >> l
      Protected dstH = ht >> l
      HDRBloomLaplace_LaplacianPyramidBlur_ScaleImage(pyramid(l - 1), srcW, srcH, pyramid(l), dstW, dstH)
    Next
    
    Protected *ntemp.pixelarray = *temp
    
    ; Niveaux laplaciens
    If levels > 1
      For l = 0 To levels - 2
        Protected currW = lg >> l
        Protected currH = ht >> l
        Protected nextW = lg >> (l + 1)
        Protected nextH = ht >> (l + 1)
        
        HDRBloomLaplace_LaplacianPyramidBlur_UpscaleImage(pyramid(l + 1), nextW, nextH, *temp, currW, currH)
        
        Protected *pyr.pixelarray = pyramid(l)
        Protected *lap.pixelarray = laplacian_tab(l)
        Protected a1, r1, g1, b1, a2, r2, g2, b2
        
        pixelCount = currW * currH
        For i = 0 To pixelCount - 1
          getargb(*pyr\l[i], a1, r1, g1, b1)
          getargb(*ntemp\l[i], a2, r2, g2, b2)
          
          Protected da = a1 - a2 + 128
          Protected dr = r1 - r2 + 128
          Protected dg = g1 - g2 + 128
          Protected db = b1 - b2 + 128
          
          Clamp(da, 0, 255)
          Clamp(dr, 0, 255)
          Clamp(dg, 0, 255)
          Clamp(db, 0, 255)
          
          *lap\l[i] = (da << 24) | (dr << 16) | (dg << 8) | db
        Next
      Next
    EndIf
    
    ; Flou multi-échelle
    Protected *tmp = AllocateMemory(lg * ht * 4)
    
    Protected nlg , nht
    If *tmp
      For l = 0 To levels - 1
        ; 1. Mise à jour impérative des dimensions pour le niveau 'l'
        nlg = lg >> l
        nht = ht >> l
        \option[4] = nlg ; Largeur (w)
        \option[5] = nht ; Hauteur (h)
        
        ; --- PASSE 1 : HORIZONTALE ---
        ; Source (lecture) = pyramid(l) | Destination (écriture) = *tmp
        \addr[3] = pyramid(l) 
        \addr[4] = *tmp
        Create_MultiThread_MT(@HDRBloomLaplace_LaplacianPyramidBlur_BlurBuffer_passe_horizontal())
        
        ; --- PASSE 2 : VERTICALE ---
        ; Source (lecture) = *tmp | Destination (écriture) = pyramid(l)
        ; (Dans ta procédure verticale : *tmp=\addr[3] est lu, *buf=\addr[2] est écrit)
        \addr[3] = pyramid(l)
        \addr[4] = *tmp
        Create_MultiThread_MT(@HDRBloomLaplace_LaplacianPyramidBlur_BlurBuffer_passe_vertical())
      Next
      FreeMemory(*tmp)
    EndIf
    
    ; Reconstruction
    If levels > 1
      For l = levels - 2 To 0 Step -1
        currW = lg >> l
        currH = ht >> l
        nextW = lg >> (l + 1)
        nextH = ht >> (l + 1)
        
        HDRBloomLaplace_LaplacianPyramidBlur_UpscaleImage(pyramid(l + 1), nextW, nextH, *temp, currW, currH)
        
        *pyr = pyramid(l)
        *lap = laplacian_tab(l)
        Protected at, rt, gt, bt, al, rl, gl, bl
        
        pixelCount = currW * currH
        For i = 0 To pixelCount - 1
          getargb(*ntemp\l[i], at, rt, gt, bt)
          getargb(*lap\l[i], al, rl, gl, bl)
          
          Protected a_out = at + (al - 128)
          Protected r_out = rt + (rl - 128)
          Protected g_out = gt + (gl - 128)
          Protected b_out = bt + (bl - 128)
          
          Clamp(a_out, 0, 255)
          Clamp(r_out, 0, 255)
          Clamp(g_out, 0, 255)
          Clamp(b_out, 0, 255)
          
          *pyr\l[i] = (a_out << 24) | (r_out << 16) | (g_out << 8) | b_out
        Next
      Next
    EndIf
    
    ; Fusion Finale
    Protected *orig.pixelarray = \addr[0]
    Protected *dst.pixelarray  = \addr[1]
    Protected *glowPyr.pixelarray = pyramid(0)
    Protected a_orig, r_orig, g_orig, b_orig
    Protected a_glow, r_glow, g_glow, b_glow
    
    pixelCount = lg * ht
    For i = 0 To pixelCount - 1
      getargb(*orig\l[i], a_orig, r_orig, g_orig, b_orig)
      getargb(*glowPyr\l[i], a_glow, r_glow, g_glow, b_glow)
      
      Protected r_final = r_orig + Int(r_glow * intensity)
      Protected g_final = g_orig + Int(g_glow * intensity)
      Protected b_final = b_orig + Int(b_glow * intensity)
      
      Clamp(r_final, 0, 255)
      Clamp(g_final, 0, 255)
      Clamp(b_final, 0, 255)
      
      *dst\l[i] = (a_orig << 24) | (r_final << 16) | (g_final << 8) | b_final
    Next
    
    ; Nettoyage
    For l = 0 To levels - 1
      If pyramid(l) : FreeMemory(pyramid(l)) : EndIf
    Next
    If levels > 1
      For l = 0 To levels - 2
        If laplacian_tab(l) : FreeMemory(laplacian_tab(l)) : EndIf
      Next
    EndIf
    FreeMemory(*temp)
    FreeMemory(\addr[2])
  EndWith
EndProcedure


Procedure HDRBloomLaplaceEx(*FilterCtx.FilterParams)
  Restore HDRBloomLaplace_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  HDRBloomLaplace_sp(*FilterCtx)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure HDRBloomLaplace(source, cible, mask, levels, kernel, threshold, intensity)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = kernel
    \option[2] = threshold
    \option[3] = intensity
  EndWith
  HDRBloomLaplaceEx(FilterCtx)
EndProcedure

DataSection
  HDRBloomLaplace_data:
  Data.s "HDR_Bloom Laplacien"
  Data.s "Glow / Bloom basé sur pyramide de Laplace"
  Data.i #FilterType_Blur, #Blur_MultiScale
  Data.s "Niveaux"
  Data.i 1, 6, 3
  Data.s "Kernel"
  Data.i 1, 20, 5
  Data.s "Seuil luminosité"
  Data.i 128, 255, 200
  Data.s "Intensité (%)"
  Data.i 0, 200, 100
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 205
; FirstLine = 186
; Folding = --
; EnableXP
; DPIAware