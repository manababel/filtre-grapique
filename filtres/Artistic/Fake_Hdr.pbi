;==============================================================================
; FAKEHDR - Filtre d'effet HDR simulé
;==============================================================================

;-- Macro de calcul interne (respect strict du parenthésage)
Macro FakeHDR_thread_total()
  Protected lg = *FilterCtx\image_lg[0]
  Protected ht = *FilterCtx\image_ht[0]
  Protected total = (lg * ht)
  macro_calul_tread(total)
  Protected start = thread_start
  Protected stop  = thread_stop - 1
  If stop >= total : stop = total - 1 : EndIf
EndMacro

;--- Procedure de flou Guillossien (Interne MT)
Procedure FakeHDR_Guillossien_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *srcPixel1.Pixel32
    Protected *srcPixel2.Pixel32
    Protected *dstPixel.Pixel32
    Protected ax1.l, rx1.l, gx1.l, bx1.l
    Protected a1.l, r1.l, b1.l, g1.l
    Protected a2.l, r2.l, b2.l, g2.l
    Protected j, i, p1, p2
    Protected *cible = \addr[3]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected *tempo = \addr[0]
    Protected lx = \addr[1]
    Protected ly = \addr[2]
    Protected nrx = \option[17] 
    Protected nry = \option[18] 
    Protected div = \option[19] 
    
    macro_calul_tread(ht)
    Protected startPos = thread_start
    Protected endPos   = thread_stop - 1

    Protected Dim a.l(lg)
    Protected Dim r.l(lg)
    Protected Dim g.l(lg)
    Protected Dim b.l(lg)

    FillMemory(@a(), lg * 4, 0)
    FillMemory(@r(), lg * 4, 0)
    FillMemory(@g(), lg * 4, 0)
    FillMemory(@b(), lg * 4, 0)

    For j = 0 To nry - 1
      p1 = PeekL(ly + (j + startPos) << 2)
      *srcPixel1 = *cible + ((p1 * lg) << 2)
      For i = 0 To lg - 1
        getargb(*srcPixel1\l, a1, r1, g1, b1)
        a(i) = a(i) + a1
        r(i) = r(i) + r1
        g(i) = g(i) + g1
        b(i) = b(i) + b1
        *srcPixel1 + 4
      Next
    Next

    For j = startPos To endPos
      p1 = PeekL(ly + (nry + j) << 2) 
      p2 = PeekL(ly + (j << 2))       
      *srcPixel1 = *cible + (p1 * lg) << 2
      *srcPixel2 = *cible + (p2 * lg) << 2

      For i = 0 To lg - 1
        getargb(*srcPixel1\l, a1, r1, g1, b1)
        getargb(*srcPixel2\l, a2, r2, g2, b2)
        a(i) = a(i) + a1 - a2
        r(i) = r(i) + r1 - r2
        g(i) = g(i) + g1 - g2
        b(i) = b(i) + b1 - b2
        *srcPixel1 + 4
        *srcPixel2 + 4
      Next

      ax1 = 0 : rx1 = 0 : gx1 = 0 : bx1 = 0
      For i = 0 To nrx - 1
        p1 = PeekL(lx + i << 2)
        ax1 = ax1 + a(p1)
        rx1 = rx1 + r(p1)
        gx1 = gx1 + g(p1)
        bx1 = bx1 + b(p1)
      Next

      For i = 0 To lg - 1
        p1 = PeekL(lx + (nrx + i) << 2)
        p2 = PeekL(lx + i  << 2)
        ax1 = ax1 + a(p1) - a(p2)
        rx1 = rx1 + r(p1) - r(p2)
        gx1 = gx1 + g(p1) - g(p2)
        bx1 = bx1 + b(p1) - b(p2)

        a1 = (ax1 * div) >> 16
        r1 = (rx1 * div) >> 16
        g1 = (gx1 * div) >> 16
        b1 = (bx1 * div) >> 16

        clamp_argb(a1 , r1 , g1 , b1)
        *dstPixel = *tempo + ((j * lg + i) << 2)
        *dstPixel\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
      Next
    Next

    FreeArray(a())
    FreeArray(r())
    FreeArray(g())
    FreeArray(b())
  EndWith
EndProcedure

Procedure FakeHDR_sp_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[10] ; Source originale stockée en addr[10]
    Protected *dst = \addr[0]
    Protected *bright = \addr[1]
    Protected vmin.f = \option[0] * 0.05
    Protected vmax.f = \option[1] * 0.05
    Protected seuil1 = \option[2]
    Protected shadowBoos = \option[3]
    Protected seuil2 = \option[4]
    Protected i, pixel, lum, r, g, b
    Protected r0.f, g0.f, b0.f
    Protected r_under.f, g_under.f, b_under.f
    Protected r_over.f, g_over.f, b_over.f
    
    FakeHDR_thread_total()
    
    For i = start To stop 
      pixel = PeekL(*src + i << 2)
      getrgb(pixel ,r ,g , b)
      r0 = r : g0 = g : b0 = b
      r_under = r0 * vmin
      g_under = g0 * vmin
      b_under = b0 * vmin
      r_over = r0 * vmax
      g_over = g0 * vmax
      b_over = b0 * vmax
      If r_over > 255 : r_over = 255 : EndIf
      If g_over > 255 : g_over = 255 : EndIf
      If b_over > 255 : b_over = 255 : EndIf
      r = r_under * 0.3 + r0 * 0.4 + r_over * 0.3
      g = g_under * 0.3 + g0 * 0.4 + g_over * 0.3
      b = b_under * 0.3 + b0 * 0.4 + b_over * 0.3
      If r > 255 : r = 255 : EndIf
      If g > 255 : g = 255 : EndIf
      If b > 255 : b = 255 : EndIf
      lum = ((r * 77 + g * 150 + b * 29) >> 8)
      If lum < seuil1
        r = (r + ((seuil1 - lum) * shadowBoos))
        g = (g + ((seuil1 - lum) * shadowBoos))
        b = (b + ((seuil1 - lum) * shadowBoos))
      EndIf
      clamp_rgb(r ,g , b)
      PokeL(*dst + i << 2, (r<<16) | (g<<8) | b)
      lum = (r * 77 + g * 150 + b * 29) >> 8
      If lum > seuil2 : PokeL(*bright + i << 2, pixel) : Else : PokeL(*bright + i << 2, 0) : EndIf
    Next
  EndWith
EndProcedure

Macro FakeHDR_Blur_IIR_sp()
  pos = (y * lg + x) << 2
  *pix32 = *dst32 + pos
  getrgb(*pix32\l ,r1 , g1 , b1)
  r1 = r1 << 8 : g1 = g1 << 8 : b1 = b1 << 8 
  r = (r * alpha + inv_alpha * r1) >> 8 
  g = (g * alpha + inv_alpha * g1) >> 8 
  b = (b * alpha + inv_alpha * b1) >> 8 
  r2 = (r + 128 ) >> 8 : g2 = (g + 128 ) >> 8 : b2 = (b + 128 ) >> 8
  clamp_rgb(r2 ,g2 ,b2)
  *pix32\l = (r2 << 16) + (g2 << 8) + b2
EndMacro

Procedure FakeHDR_Blur_IIR_y_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *dst32.pixel32 = \addr[0]
    Protected *pix32.pixel32
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected alpha = \option[18]
    Protected inv_alpha = \option[19]
    Protected x, y, pos, r, g, b, r1, g1, b1, r2, g2, b2
    macro_calul_tread(ht)
    Protected start = thread_start
    Protected stop  = thread_stop - 1
    For y = start To stop
      r = 0 : g = 0 : b = 0
      For x = 0 To lg - 1 : FakeHDR_Blur_IIR_sp() : Next
      r = 0 : g = 0 : b = 0
      For x = lg - 1 To 0 Step -1 : FakeHDR_Blur_IIR_sp() : Next
    Next
  EndWith
EndProcedure

Procedure FakeHDR_Blur_IIR_x_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *dst32.pixel32 = \addr[0]
    Protected *pix32.pixel32
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected alpha = \option[18]
    Protected inv_alpha = \option[19]
    Protected x, y, pos, r, g, b, r1, g1, b1, r2, g2, b2
    macro_calul_tread(lg)
    Protected start = thread_start
    Protected stop  = thread_stop - 1
    For x = start To stop
      r = 0 : g = 0 : b = 0
      For y = 0 To ht - 1 : FakeHDR_Blur_IIR_sp() : Next
      r = 0 : g = 0 : b = 0
      For x = ht - 1 To 0 Step -1 : FakeHDR_Blur_IIR_sp() : Next
    Next
  EndWith
EndProcedure

Procedure FakeHDR_GlowEffect_IIR_sp2_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0]
    Protected *bright = \addr[1]
    Protected *dst = \addr[2]
    Protected glowStrength = ((\option[5] * 256) / 100)
    Protected i , pixel, r, g, b, r0, g0, b0
    FakeHDR_thread_total()
    For i = start To stop
      pixel = PeekL(*src + i << 2)
      getrgb(pixel , r0 , g0 , b0)
      pixel = PeekL(*bright + i << 2)
      getrgb(pixel , r , g , b)
      r = r0 + ((r * glowStrength) >> 8)
      g = g0 + ((g * glowStrength) >> 8)
      b = b0 + ((b * glowStrength) >> 8)
      clamp_rgb(r, g, b)
      PokeL(*dst + i << 2, (r << 16) + (g << 8) + b)
    Next
  EndWith
EndProcedure

Procedure FakeHDR_UnsharpMask_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src  = \addr[0]
    Protected *dst  = \addr[1]
    Protected *blur = \addr[2]
    Protected strengthQ8 = Int((\option[6] * 25.6))
    Protected i, pixelOrig, pixelBlur, rOrig, gOrig, bOrig, rBlur, gBlur, bBlur
    Protected rDiff, gDiff, bDiff, r, g, b
    FakeHDR_thread_total()  
    For i = start To stop
        pixelOrig = PeekL(*src + i << 2)
        pixelBlur = PeekL(*blur + i << 2)
        getrgb(pixelOrig, rOrig, gOrig, bOrig)
        getrgb(pixelBlur, rBlur, gBlur, bBlur)
        rDiff = rOrig - rBlur
        gDiff = gOrig - gBlur
        bDiff = bOrig - bBlur
        r = rOrig + ((rDiff * strengthQ8) >> 8)
        g = gOrig + ((gDiff * strengthQ8) >> 8)
        b = bOrig + ((bDiff * strengthQ8) >> 8)
        clamp_rgb(r, g, b)
        PokeL(*dst + i <<2 , (r << 16) + (g << 8) + b)
    Next
  EndWith
EndProcedure

Procedure FakeHDR_LocalContrast_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src1 = \addr[0]
    Protected *dst = \addr[11] ; On utilise l'adresse cible finale stockée en 11
    Protected contrastQ8 = Int((\option[8] * 10))
    Protected factorQ8 = Int((\option[9] * 10))
    Protected levels = (100 - \option[10])
    If levels < 2 : levels = 2 : EndIf
    If contrastQ8 < 26 : contrastQ8 = 26 : EndIf
    Protected scaleQuant = (((levels - 1) << 8) / 255)
    Protected scaleDequant = ((255 << 8) / (levels - 1))
    Protected half = 128
    Protected i , lum, r1, g1, b1, r2, g2, b2, r, g, b , rF, gF, bF
    FakeHDR_thread_total() 
    For i = start To stop
        getrgb(PeekL(*src1 + i << 2), r1, g1, b1)
        getrgb(PeekL(*dst + i << 2), r2, g2, b2)
        r = ((r1 - r2) * contrastQ8) >> 8 + r2
        g = ((g1 - g2) * contrastQ8) >> 8 + g2
        b = ((b1 - b2) * contrastQ8) >> 8 + b2
        clamp_rgb(r, g, b)
        lum = (r * 77 + g * 150 + b * 29) >> 8
        rF = lum + ((r - lum) * factorQ8) >> 8
        gF = lum + ((g - lum) * factorQ8) >> 8
        bF = lum + ((b - lum) * factorQ8) >> 8
        clamp_rgb(rF, gF, bF)
        r = (((rf * scaleQuant + half) >> 8) * scaleDequant + half) >> 8
        g = (((gf * scaleQuant + half) >> 8) * scaleDequant + half) >> 8
        b = (((bf * scaleQuant + half) >> 8) * scaleDequant + half) >> 8
        clamp_rgb(r, g, b)
        PokeL(*dst + i << 2, (r << 16) | (g << 8) | b)
    Next
  EndWith
EndProcedure

Procedure FakeHDR_MixWithOriginal_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src1 = \addr[10] ; Source originale
    Protected *src2 = \addr[11] ; Cible finale
    Protected mixPercent = \option[11]
    If mixPercent < 0 : mixPercent = 0 : EndIf
    If mixPercent > 100 : mixPercent = 100 : EndIf
    Protected mix = ((mixPercent * 256) / 100)
    Protected invMix = (256 - mix)
    Protected half = 128
    Protected i, pixel1, pixel2, r1, g1, b1, r2, g2, b2, r, g, b
    FakeHDR_thread_total()
    For i = start To stop
      pixel1 = PeekL(*src1 + i << 2)
      pixel2 = PeekL(*src2 + i << 2)
      getrgb(pixel1, r1, g1, b1)
      getrgb(pixel2, r2, g2, b2)
      r = (r1 * invMix + r2 * mix + half) >> 8
      g = (g1 * invMix + g2 * mix + half) >> 8
      b = (b1 * invMix + b2 * mix + half) >> 8
      clamp_rgb(r, g, b)
      PokeL(*src2 + i << 2, (r << 16) + (g << 8) | b)
    Next
  EndWith
EndProcedure

;-- Orchestration et Metadata
Procedure FakeHDREx(*FilterCtx.FilterParams)
  Restore FakeHDR_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected *temp1 = AllocateMemory(lg * ht * 4)
    Protected *temp2 = AllocateMemory(lg * ht * 4)
    Protected *bright = AllocateMemory(lg * ht * 4)
    Protected *blur = AllocateMemory(lg * ht * 4)
    Protected *tempo = AllocateMemory(lg * ht * 4)
    
    ; Sauvegarde des pointeurs d'origine
    \addr[10] = \addr[0] ; Source
    \addr[11] = \addr[1] ; Cible
    
    ; Étape 1 : Extraction et Pre-HDR
    \addr[0] = *temp1
    \addr[1] = *bright
    Create_MultiThread_MT(@FakeHDR_sp_MT())
    
    ; Étape 2 : Flou IIR sur zones brillantes
    Protected Radius0.f = 0.3
    \option[18] = Int((Exp(-2.3 / (Radius0 + 1.0))) * 256)
    \option[19] = 256 - \option[18]
    \addr[0] = *bright
    Create_MultiThread_MT(@FakeHDR_Blur_IIR_y_MT())
    Create_MultiThread_MT(@FakeHDR_Blur_IIR_x_MT())
    
    \addr[0] = *temp1
    \addr[1] = *bright
    \addr[2] = *temp2
    Create_MultiThread_MT(@FakeHDR_GlowEffect_IIR_sp2_MT())

    ; Étape 3 : Sharpen (Guillossien)
    Protected radius.f = \option[7] 
    radius * 0.1
    If radius < 1 : radius = 1 : EndIf
    
    Protected dx = lg - 1, dy = ht - 1
    Protected nrx = radius + 1, nry = radius + 1
    Protected *lx = AllocateMemory((lg + 2 * nrx) * 4)
    Protected *ly = AllocateMemory((ht + 2 * nry) * 4)
    Protected i, ii
    For i = 0 To dx + 2 * nrx : ii = i - 1 - nrx / 2 : If ii < 0 : ii = 0 : ElseIf ii > dx : ii = dx : EndIf : PokeL(*lx + i * 4, ii) : Next
    For i = 0 To dy + 2 * nry : ii = i - 1 - nry / 2 : If ii < 0 : ii = 0 : ElseIf ii > dy : ii = dy : EndIf : PokeL(*ly + i * 4, ii) : Next
    
    \addr[1] = *lx : \addr[2] = *ly
    \option[17] = nrx : \option[18] = nry : \option[19] = Int((65536 / (nrx * nry)))
    \addr[0] = *blur : \addr[3] = *temp2
    Create_MultiThread_MT(@FakeHDR_Guillossien_MT())
    FreeMemory(*lx) : FreeMemory(*ly)
    
    \addr[0] = *temp2 : \addr[1] = *temp1 : \addr[2] = *blur  
    Create_MultiThread_MT(@FakeHDR_UnsharpMask_MT())

    ; Étape 4 : Local Contrast
    radius = 3 : nrx = radius + 1 : nry = radius + 1
    *lx = AllocateMemory((lg + 2 * nrx) * 4) : *ly = AllocateMemory((ht + 2 * nry) * 4)
    For i = 0 To dx + 2 * nrx : ii = i - 1 - nrx / 2 : If ii < 0 : ii = 0 : ElseIf ii > dx : ii = dx : EndIf : PokeL(*lx + i * 4, ii) : Next
    For i = 0 To dy + 2 * nry : ii = i - 1 - nry / 2 : If ii < 0 : ii = 0 : ElseIf ii > dy : ii = dy : EndIf : PokeL(*ly + i * 4, ii) : Next
    
    \addr[1] = *lx : \addr[2] = *ly
    \option[17] = nrx : \option[18] = nry : \option[19] = Int((65536 / (nrx * nry)))
    \addr[0] = *temp2 : \addr[3] = *temp1
    Create_MultiThread_MT(@FakeHDR_Guillossien_MT())
    FreeMemory(*lx) : FreeMemory(*ly)
    
    \addr[0] = *temp1
    Create_MultiThread_MT(@FakeHDR_LocalContrast_MT())

    ; Mixage Final
    Create_MultiThread_MT(@FakeHDR_MixWithOriginal_MT())

    mask_update(*FilterCtx, last_data)

    FreeMemory(*temp1) : FreeMemory(*temp2) : FreeMemory(*bright) : FreeMemory(*blur) : FreeMemory(*tempo)
  EndWith
EndProcedure

;-- Interface simplifiée
Procedure FakeHDR(source, cible, mask, vmin, vmax, sh_seuil, sh_val, seuil, glow, strength, radius, contrast, factor, posterize, mix)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = vmin : \option[1] = vmax : \option[2] = sh_seuil : \option[3] = sh_val
    \option[4] = seuil : \option[5] = glow : \option[6] = strength : \option[7] = radius
    \option[8] = contrast : \option[9] = factor : \option[10] = posterize : \option[11] = mix
  EndWith
  FakeHDREx(FilterCtx)
EndProcedure

;-- DataSection
DataSection
  FakeHDR_Data:
  Data.s "FakeHDR (crash)"
  Data.s "Simulation d'effet HDR par fusion d'expositions et contraste local."
  Data.i #FilterType_Artistic
  Data.i #Artistic_Light
  
  Data.s "vmin" : Data.i 0, 100, 30
  Data.s "vmax" : Data.i 0, 100, 40
  Data.s "ShadowBoost Seuil" : Data.i 0, 100, 7
  Data.s "ShadowBoost Valeur" : Data.i 0, 100, 4
  Data.s "Seuil" : Data.i 0, 255, 127
  Data.s "Intensité Glow" : Data.i 0, 100, 6
  Data.s "Strength" : Data.i 0, 100, 50
  Data.s "Radius" : Data.i 0, 100, 100
  Data.s "Contrast" : Data.i 0, 100, 30
  Data.s "Factor" : Data.i 0, 100, 60
  Data.s "Posterize" : Data.i 0, 100, 0
  Data.s "Mix final" : Data.i 0, 100, 100
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 427
; FirstLine = 395
; Folding = ---
; EnableXP
; DPIAware