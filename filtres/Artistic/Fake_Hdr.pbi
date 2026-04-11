;--
Macro FakeHDR_thread_total()
  Protected lg =  *param\lg
  Protected ht =  *param\ht
  Protected total = lg * ht
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop   = ((*param\thread_pos + 1) * total) / *param\thread_max
  If stop >= total : stop = total - 1 : EndIf
EndMacro
;---
Procedure FakeHDR_Guillossien_MT(*param.parametre)
  ; Déclarations de pointeurs pixel source/destination
  Protected *srcPixel1.Pixel32
  Protected *srcPixel2.Pixel32
  Protected *dstPixel.Pixel32

  ; Accumulateurs pour composantes ARGB
  Protected ax1.l, rx1.l, gx1.l, bx1.l
  Protected a1.l, r1.l, b1.l, g1.l
  Protected a2.l, r2.l, b2.l, g2.l

  ; Index temporaires
  Protected j, i, p1, p2

  ; Paramètres de l’image
  Protected *cible = *param\addr[3]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected *tempo = *param\addr[0]
  Protected lx = *param\addr[1]
  Protected ly = *param\addr[2]

  ; Paramètres du filtre
  Protected nrx = param\option[17] ; Largeur de la fenêtre de flou (X)
  Protected nry = param\option[18] ; Hauteur de la fenêtre de flou (Y)
  Protected div = param\option[19] ; Facteur de division (65536 / (nrx * nry))

  ; Threads
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected startPos = (thread_pos * ht) / thread_max
  Protected endPos   = ((thread_pos + 1) * ht) / thread_max - 1

  ; Buffers pour accumuler les sommes par colonne
  Protected Dim a.l(lg)
  Protected Dim r.l(lg)
  Protected Dim g.l(lg)
  Protected Dim b.l(lg)

  ; Initialisation des buffers
  FillMemory(@a(), lg * 4, 0)
  FillMemory(@r(), lg * 4, 0)
  FillMemory(@g(), lg * 4, 0)
  FillMemory(@b(), lg * 4, 0)

  ; === Étape 1 : Accumule les lignes verticales pour démarrer ===
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

  ; === Étape 2 : Application du filtre pour chaque ligne ===
  For j = startPos To endPos
    ; Mise à jour du buffer colonne (soustraction d’une ancienne ligne et ajout d’une nouvelle)
    p1 = PeekL(ly + (nry + j) << 2) ; index de la ligne ajoutée
    p2 = PeekL(ly + (j << 2))       ; index de la ligne retirée
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

    ; Application du filtre horizontal (initialisation des accumulateurs)
    ax1 = 0 : rx1 = 0 : gx1 = 0 : bx1 = 0
    For i = 0 To nrx - 1
      p1 = PeekL(lx + i << 2)
      ax1 = ax1 + a(p1)
      rx1 = rx1 + r(p1)
      gx1 = gx1 + g(p1)
      bx1 = bx1 + b(p1)
    Next

    ; Boucle de sortie pour chaque pixel de la ligne (fenêtre glissante)
    For i = 0 To lg - 1
      p1 = PeekL(lx + (nrx + i) << 2)
      p2 = PeekL(lx + i  << 2)
      ax1 = ax1 + a(p1) - a(p2)
      rx1 = rx1 + r(p1) - r(p2)
      gx1 = gx1 + g(p1) - g(p2)
      bx1 = bx1 + b(p1) - b(p2)

      ; Calcul final avec facteur de division
      a1 = (ax1 * div) >> 16
      r1 = (rx1 * div) >> 16
      g1 = (gx1 * div) >> 16
      b1 = (bx1 * div) >> 16

      ; Clamp pour sécurité
      clamp_argb(a1 , r1 , g1 , b1)
      ; Écriture dans le buffer temporaire
      *dstPixel = *tempo + ((j * lg + i) << 2)
      *dstPixel\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
    Next
  Next

  ; Libération des tableaux
  FreeArray(a())
  FreeArray(r())
  FreeArray(g())
  FreeArray(b())
EndProcedure
;--
Procedure FakeHDR_sp_MT(*param.parametre)
  Protected *src = *param\source
  Protected *dst = *param\addr[0]
  Protected *bright =  *param\addr[1]
  Protected vmin.f =  *param\option[0] * 0.05
  Protected vmax.f =  *param\option[1] * 0.05
  Protected seuil1 = *param\option[2]
  Protected shadowBoos = *param\option[3]
  Protected seuil2 = *param\option[4]
  Protected i , pixel , lum
  Protected r0.f, g0.f, b0.f
  Protected r_under.f, g_under.f, b_under.f
  Protected r_over.f, g_over.f, b_over.f
  Protected r, g, b
  
  ;Protected Dim tab(255)
  ;For i = 0 To 255
    ;tab(i) = Pow(i / 255 , 2.2) * 255
  ;Next
  
  FakeHDR_thread_total()
  
    For i = start To stop 
      pixel = PeekL(*src + i << 2)
      getrgb(pixel ,r ,g , b)
      ;r = tab(r)
      ;g = tab(g)
      ;b = tab(b)
      r0 = r : g0 = g : b0 = b
      ; Sous-exposition
      r_under = r0 * vmin
      g_under = g0 * vmin
      b_under = b0 * vmin
      ; Sur-exposition
      r_over = r0 * vmax
      g_over = g0 * vmax
      b_over = b0 * vmax
      If r_over > 255 : r_over = 255 : EndIf
      If g_over > 255 : g_over = 255 : EndIf
      If b_over > 255 : b_over = 255 : EndIf
      ; Fusion pondérée
      r = r_under * 0.3 + r0 * 0.4 + r_over * 0.3
      g = g_under * 0.3 + g0 * 0.4 + g_over * 0.3
      b = b_under * 0.3 + b0 * 0.4 + b_over * 0.3
      ; Clamp
      If r > 255 : r = 255 : EndIf
      If g > 255 : g = 255 : EndIf
      If b > 255 : b = 255 : EndIf
      
      ; FakeHDR_ShadowBoost_MT
      lum = ((r * 77 + g * 150 + b * 29) >> 8)
      If lum < seuil1
        r = (r + ((seuil1 - lum) * shadowBoos))
        g = (g + ((seuil1 - lum) * shadowBoos))
        b = (b + ((seuil1 - lum) * shadowBoos))
      EndIf
      clamp_rgb(r ,g , b)
      PokeL(*dst + i << 2, (r<<16) | (g<<8) | b)
      
      ;Procedure FakeHDR_GlowEffect_IIR_sp1_MT
      lum = (r * 77 + g * 150 + b * 29) >> 8
      If lum > seuil2 : PokeL(*bright + i << 2, pixel) : Else : PokeL(*bright + i << 2, 0) : EndIf
      
    Next
    ;FreeArray(tab())
  EndProcedure
  ;--
  

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

Procedure FakeHDR_Blur_IIR_y_MT(*param.parametre)
  Protected *dst32.pixel32 = *param\addr[0]
  Protected *pix32.pixel32
  Protected lg =  *param\lg
  Protected ht =  *param\ht
  Protected alpha = *param\option[18]
  Protected inv_alpha = *param\option[19]
  Protected x, y, pos
  Protected r, g, b
  Protected r1, g1, b1
  Protected r2, g2, b2
  Protected pixel
  Protected start = (*param\thread_pos * ht) / *param\thread_max
  Protected stop   = ((*param\thread_pos + 1) * ht) / *param\thread_max
  For y = start To stop -1
    r = 0 : g = 0 : b = 0
    For x = 0 To lg - 1 : FakeHDR_Blur_IIR_sp() : Next
  Next
  For y = start To stop -1
    r = 0 : g = 0 : b = 0
    For x = lg - 1 To 0 Step -1 : FakeHDR_Blur_IIR_sp() : Next
  Next
EndProcedure

Procedure FakeHDR_Blur_IIR_x_MT(*param.parametre)
  Protected *dst32.pixel32 =  *param\addr[0]
  Protected *pix32.pixel32
  Protected lg =  *param\lg
  Protected ht =  *param\ht
  Protected alpha = *param\option[18]
  Protected inv_alpha = *param\option[19]
  Protected x, y, pos
  Protected r, g, b
  Protected r1, g1, b1
  Protected r2, g2, b2
  Protected pixel
  Protected start = (*param\thread_pos * lg) / *param\thread_max
  Protected stop   = ((*param\thread_pos + 1) * lg) / *param\thread_max
  For x = start To stop -1
    r = 0 : g = 0 : b = 0
    For y = 0 To ht - 1 : FakeHDR_Blur_IIR_sp() : Next
  Next
  For x = start To stop -1
    r = 0 : g = 0 : b = 0
    For y = ht - 1 To 0 Step -1 : FakeHDR_Blur_IIR_sp() : Next
  Next
EndProcedure

;--
Procedure FakeHDR_GlowEffect_IIR_sp2_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *bright = *param\addr[1]
  Protected *dst = *param\addr[2]
  Protected glowStrength = (*param\option[5] * 256) / 100
  Protected i , pixel, r, g, b
  Protected r0, g0, b0
  FakeHDR_thread_total()
  For i = start To stop
    pixel = PeekL(*src + i << 2)
    getrgb(pixel , r0 , g0 , b0)
    pixel = PeekL(*bright + i << 2)
    getrgb(pixel , r , g , b)
    ; Mélange glow + original avec intensité
    r = r0 + ((r * glowStrength) >> 8)
    g = g0 + ((g * glowStrength) >> 8)
    b = b0 + ((b * glowStrength) >> 8)
    clamp_rgb(r, g, b)
    PokeL(*dst + i << 2, (r << 16) + (g << 8) + b)
  Next
EndProcedure
;--
Procedure UnsharpMask_MT(*param.parametre)
  Protected *src  = *param\addr[0]
  Protected *dst  = *param\addr[1]
  Protected *blur = *param\addr[2]
  Protected strengthQ8 = Int(*param\option[6] * 25.6) ; 0.0–10.0 → 0–2560 (Q8)

  Protected i, pixelOrig, pixelBlur
  Protected rOrig, gOrig, bOrig, rBlur, gBlur, bBlur
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
EndProcedure
;--
Procedure LocalContrast_MT(*param.parametre)
  Protected *src1 =  *param\addr[0]
  Protected *dst =  *param\cible

  ; Conversion de contrast en Q8 (x256)
  Protected contrastQ8 = Int(*param\option[8] * 10)
  Protected factorQ8 = Int(*param\option[9] * 10) ; Q8
  Protected levels = 100 - *param\option[10]
  If levels < 2 : levels = 2 : EndIf
  If contrastQ8 < 26 : contrastQ8 = 26 : EndIf ; équivaut à 0.1
  
  ; On calcule en Q8 fixed point les échelles pour quantification et déquantification
  ; scaleQuant = (levels - 1) << 8 / 255  -> pour r * scaleQuant >> 8 = quantification en [0..levels-1]
  Protected scaleQuant = ((levels - 1) << 8) / 255
  ; scaleDequant = 255 << 8 / (levels - 1) -> pour restituer la valeur dans [0..255]
  Protected scaleDequant = (255 << 8) / (levels - 1)
  
  Protected half = 128 ; pour arrondi (0.5 en Q8)
  
  Protected i , lum
  Protected r1, g1, b1, r2, g2, b2
  Protected r, g, b , rF, gF, bF
  FakeHDR_thread_total() 

  For i = start To stop
      getrgb(PeekL(*src1 + i << 2), r1, g1, b1)
      getrgb(PeekL(*dst + i << 2), r2, g2, b2)

      r = ((r1 - r2) * contrastQ8) >> 8 + r2
      g = ((g1 - g2) * contrastQ8) >> 8 + g2
      b = ((b1 - b2) * contrastQ8) >> 8 + b2

      clamp_rgb(r, g, b)
      ;PokeL(*dst + i << 2, (r << 16) + (g << 8) + b)
      
      ;procedure FakeHDR_sat_MT
     lum = (r * 77 + g * 150 + b * 29) >> 8

    ; Saturation ajustée avec Q8 fixed point
    rF = lum + ((r - lum) * factorQ8) >> 8
    gF = lum + ((g - lum) * factorQ8) >> 8
    bF = lum + ((b - lum) * factorQ8) >> 8

    clamp_rgb(rF, gF, bF)
    ;PokeL(*dst + i << 2, (rF << 16) + (gF << 8) + bF)     
    
    ;procedure PosterizeDoucement_MT
    r = (((rf * scaleQuant + half) >> 8) * scaleDequant + half) >> 8
    g = (((gf * scaleQuant + half) >> 8) * scaleDequant + half) >> 8
    b = (((bf * scaleQuant + half) >> 8) * scaleDequant + half) >> 8
    clamp_rgb(r, g, b)
    PokeL(*dst + i << 2, (r << 16) | (g << 8) | b)
  Next
EndProcedure
;--

;--
Procedure FakeHDR_MixWithOriginal_MT(*param.parametre)
  Protected *src1 = *param\source
  Protected *src2 = *param\cible
  
  ; mix en pourcentage [0..100], on convertit en Q8 [0..256]
  Protected mixPercent = *param\option[11]
  If mixPercent < 0 : mixPercent = 0 : EndIf
  If mixPercent > 100 : mixPercent = 100 : EndIf
  Protected mix = (mixPercent * 256) / 100
  Protected invMix = 256 - mix
  Protected half = 128 ; pour arrondi
  
  Protected i, pixel1, pixel2
  Protected r1, g1, b1, r2, g2, b2
  Protected r, g, b
  
  ;Protected Dim tab(255)
  ;For i = 0 To 255
    ;tab(i) = Pow(i/255  ,1 /  2.2) * 255
  ;Next
  
  FakeHDR_thread_total()

  For i = start To stop
    pixel1 = PeekL(*src1 + i << 2)
    pixel2 = PeekL(*src2 + i << 2)
    getrgb(pixel1, r1, g1, b1)
    getrgb(pixel2, r2, g2, b2)
    ;r2 = tab(r2)
    ;g2 = tab(g2)
    ;b2 = tab(b2)

    ; Interpolation en Q8 avec arrondi
    r = (r1 * invMix + r2 * mix + half) >> 8
    g = (g1 * invMix + g2 * mix + half) >> 8
    b = (b1 * invMix + b2 * mix + half) >> 8

    clamp_rgb(r, g, b)
    PokeL(*src2 + i << 2, (r << 16) + (g << 8) + b)
  Next
  ;FreeArray(tab())
EndProcedure
;--
Macro FakeHDR_sp1()
  dx = lg - 1
  dy = ht - 1
  If radius > dx : radius = dx : EndIf
  If radius > dy : radius = dy : EndIf
  nrx = radius + 1
  nry = radius + 1
  ; Allocation mémoire pour les tables d’indices en X et Y
  *lx = AllocateMemory((lg + 2 * nrx) * 4)
  *ly = AllocateMemory((ht + 2 * nry) * 4)
  ; Remplissage des tables selon le mode bord ou boucle
  For i = 0 To dx + 2 * nrx : ii = i - 1 - nrx / 2 : If ii < 0 : ii = 0 : ElseIf ii > dx : ii = dx : EndIf : PokeL(*lx + i * 4, ii) : Next
  For i = 0 To dy + 2 * nry : ii = i - 1 - nry / 2 : If ii < 0 : ii = 0 : ElseIf ii > dy : ii = dy : EndIf : PokeL(*ly + i * 4, ii) : Next
  param\addr[1] = *lx
  param\addr[2] = *ly
  param\option[17] = nrx
  param\option[18] = nry
  param\option[19] = Int(65536 / (nrx * nry)) ; Facteur normalisation
EndMacro
;--
Procedure FakeHDR(*param.parametre)
  
  If param\info_active
    param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Light
    param\name = "FakeHDR"
    param\remarque = ""
    param\info[0] = "vmin"
    param\info[1] = "vmax"
    param\info[2] = "ShadowBoost_seuil"
    param\info[3] = "ShadowBoost_value"
    param\info[4] = "seuil"
    param\info[5] = "Intensité Glow"
    param\info[6] = "strength"
    param\info[7] = "radius"
    param\info[8] = "contrast"
    param\info[9] = "factor"
    param\info[10] = "Posterize"
    param\info[11] = "Mix final"
    param\info[12] = "Masque binaire"
    
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 30
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 40
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100 : param\info_data(2,2) = 7
    param\info_data(3,0) = 0 : param\info_data(3,1) = 100 : param\info_data(3,2) = 4
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 127
    param\info_data(5,0) = 0 : param\info_data(5,1) = 100 : param\info_data(5,2) = 6
    param\info_data(6,0) = 0 : param\info_data(6,1) = 100 : param\info_data(6,2) = 50
    param\info_data(7,0) = 0 : param\info_data(7,1) = 100 : param\info_data(7,2) = 100
    param\info_data(8,0) = 0 : param\info_data(8,1) = 100 : param\info_data(8,2) = 30
    param\info_data(9,0) = 0 : param\info_data(9, 1) = 100 : param\info_data(9, 2) = 60
    param\info_data(10,0) = 0 : param\info_data(10,1) = 100 : param\info_data(10,2) = 0
    param\info_data(11,0) = 0 : param\info_data(11,1) = 100 : param\info_data(11,2) = 100 ; Mix final
    param\info_data(12,0) = 0 : param\info_data(12,1) = 1 : param\info_data(12,2) = 0     ; Masque binaire
    
    ProcedureReturn
  EndIf
  
  Protected *source = *param\source
  Protected *cible = *param\cible
  Protected *mask = *param\mask
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected i
  If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf
  
  Protected *temp1 = AllocateMemory(lg * ht * 4)
  Protected *temp2 = AllocateMemory(lg * ht * 4)
  Protected *bright = AllocateMemory(lg * ht * 4)
  Protected *blur = AllocateMemory(lg * ht * 4)
  Protected *tempo = AllocateMemory(lg * ht * 4)
  
  ; Détermine le nombre de threads disponibles
  Protected thread = CountCPUs(#PB_System_CPUs)
  clamp(thread , 1 , 128)
  Protected Dim tr(thread)
  
  Protected ii, e, passe , t

  ; Étape 1 : Fake HDR
  ;FakeHDR_sp(*source, *temp1, lg, ht ,  vmin , vmax)
  *param\addr[0] = *temp1
  *param\addr[1] = *bright
  MultiThread_MT(@FakeHDR_sp_MT())
  

  Protected Radius0.f = 0.3
  *param\option[18] = Int((Exp(-2.3 / (Radius0 + 1.0))) * 256)
  *param\option[19]  = 256 - *param\option[18]
  *param\addr[0] = *bright
  MultiThread_MT(@FakeHDR_Blur_IIR_y_MT())
  MultiThread_MT(@FakeHDR_Blur_IIR_x_MT())
  
  *param\addr[0] = *temp1
  *param\addr[1] = *bright
  *param\addr[2] = *temp2
  MultiThread_MT(@FakeHDR_GlowEffect_IIR_sp2_MT())

  

  ; Étape 3 : Sharpen
  Protected dx , dy , nrx ,nry
  Protected *lx , *ly
  Protected radius.f = *param\option[7] 
  clamp(radius, 1, 100)
  radius * 0.1
  FakeHDR_sp1()
  param\addr[0] = *blur
  param\addr[3] = *temp2
  MultiThread_MT(@FakeHDR_Guillossien_MT())
  FreeMemory(*lx) : FreeMemory(*ly)
  
  param\addr[0] = *temp2
  param\addr[1] = *temp1
  param\addr[2] = *blur  
  MultiThread_MT(@UnsharpMask_MT())

  
  ; Étape 4 : Local contrast
  radius = 3
  FakeHDR_sp1()
  param\addr[0] = *temp2
  param\addr[3] = *temp1
  MultiThread_MT(@FakeHDR_Guillossien_MT())
  FreeMemory(*lx) : FreeMemory(*ly)
  
  param\addr[0] = *temp1
  param\addr[1] = *temp2
  MultiThread_MT(@LocalContrast_Mt())


  MultiThread_MT(@FakeHDR_MixWithOriginal_MT())

  
  FreeMemory(*temp1)
  FreeMemory(*temp2)
  FreeMemory(*bright)
  FreeMemory(*blur)
  FreeMemory(*tempo)
  FreeArray(tr())
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 433
; FirstLine = 428
; Folding = ---
; EnableXP
; DPIAware