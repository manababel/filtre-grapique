; ---------------------------------------------------
; Bilateral tab_laplacian Blur - Version optimisée
; Multi-scale blur with edge preservation
; ---------------------------------------------------

; --- Bilateral blur optimisé sur un buffer ---
Procedure BilateralBlurBuffer(*buf, w, h, radius, sigmaColor.f)
  If radius < 1 Or w < 1 Or h < 1 : ProcedureReturn : EndIf
  
  Protected *tmp = AllocateMemory(w * h * 4)
  If Not *tmp : ProcedureReturn : EndIf
  
  Protected x, y, dx, dy, px, py
  Protected idx, idx2, offset
  Protected r0, g0, b0, a0
  Protected r, g, b, a
  Protected sumR.f, sumG.f, sumB.f, sumA.f, sumW.f
  Protected dColor.f, wColor.f, wSpace.f, wTot.f
  Protected invSigma2.f = -1.0 / (sigmaColor * sigmaColor)
  Protected radiusSq.f = radius * radius
  Protected invRadiusSq.f = -1.0 / radiusSq
  Protected dxSq, dySq, distSq
  Protected wMinus1 = w - 1
  Protected hMinus1 = h - 1
  
  For y = 0 To hMinus1
    offset = y * w << 2
    For x = 0 To wMinus1
      idx = offset + (x << 2)
      
      r0 = PeekA(*buf + idx + 2)
      g0 = PeekA(*buf + idx + 1)
      b0 = PeekA(*buf + idx)
      a0 = PeekA(*buf + idx + 3)
      
      sumR = 0.0
      sumG = 0.0
      sumB = 0.0
      sumA = 0.0
      sumW = 0.0
      
      For dy = -radius To radius
        py = y + dy
        If py < 0 : py = 0 : ElseIf py > hMinus1 : py = hMinus1 : EndIf
        dySq = dy * dy
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 : px = 0 : ElseIf px > wMinus1 : px = wMinus1 : EndIf
          
          idx2 = (py * w + px) << 2
          r = PeekA(*buf + idx2 + 2)
          g = PeekA(*buf + idx2 + 1)
          b = PeekA(*buf + idx2)
          a = PeekA(*buf + idx2 + 3)
          
          ; Distance couleur
          dColor = (r0 - r) * (r0 - r) + (g0 - g) * (g0 - g) + (b0 - b) * (b0 - b)
          wColor = Exp(dColor * invSigma2)
          
          ; Distance spatiale
          dxSq = dx * dx
          distSq = dxSq + dySq
          wSpace = Exp(distSq * invRadiusSq)
          
          wTot = wColor * wSpace
          
          sumR + r * wTot
          sumG + g * wTot
          sumB + b * wTot
          sumA + a * wTot
          sumW + wTot
        Next
      Next
      
      If sumW > 0.0001
        PokeA(*tmp + idx + 3, sumA / sumW + 0.5)
        PokeA(*tmp + idx + 2, sumR / sumW + 0.5)
        PokeA(*tmp + idx + 1, sumG / sumW + 0.5)
        PokeA(*tmp + idx    , sumB / sumW + 0.5)
      Else
        PokeA(*tmp + idx + 3, a0)
        PokeA(*tmp + idx + 2, r0)
        PokeA(*tmp + idx + 1, g0)
        PokeA(*tmp + idx    , b0)
      EndIf
    Next
  Next
  
  CopyMemory(*tmp, *buf, w * h * 4)
  FreeMemory(*tmp)
EndProcedure

; --- Downscale avec filtre gaussien ---
Procedure Bilateraltab_laplacian_Downscale(*src, srcW, srcH, *dst, dstW, dstH)
  Protected x, y, sx, sy, ex, ey
  Protected sumR, sumG, sumB, sumA, count
  Protected px, py, idx, idx2
  Protected scaleX.f = srcW / dstW
  Protected scaleY.f = srcH / dstH
  
  For y = 0 To dstH - 1
    sy = y * scaleY
    ey = (y + 1) * scaleY
    If ey > srcH : ey = srcH : EndIf
    
    For x = 0 To dstW - 1
      sx = x * scaleX
      ex = (x + 1) * scaleX
      If ex > srcW : ex = srcW : EndIf
      
      sumR = 0
      sumG = 0
      sumB = 0
      sumA = 0
      count = 0
      
      For py = sy To ey - 1
        For px = sx To ex - 1
          idx = (py * srcW + px) << 2
          sumA + PeekA(*src + idx + 3)
          sumR + PeekA(*src + idx + 2)
          sumG + PeekA(*src + idx + 1)
          sumB + PeekA(*src + idx)
          count + 1
        Next
      Next
      
      If count > 0
        idx2 = (y * dstW + x) << 2
        PokeA(*dst + idx2 + 3, sumA / count)
        PokeA(*dst + idx2 + 2, sumR / count)
        PokeA(*dst + idx2 + 1, sumG / count)
        PokeA(*dst + idx2    , sumB / count)
      EndIf
    Next
  Next
EndProcedure

; --- Upscale bilinéaire ---
Procedure Bilateraltab_laplacian_Upscale(*src, srcW, srcH, *dst, dstW, dstH)
  Protected x, y, sx.f, sy.f
  Protected x0, y0, x1, y1
  Protected fx.f, fy.f, fx1.f, fy1.f
  Protected idx00, idx01, idx10, idx11, idx
  Protected r00, g00, b00, a00
  Protected r01, g01, b01, a01
  Protected r10, g10, b10, a10
  Protected r11, g11, b11, a11
  Protected r0.f, g0.f, b0.f, a0.f
  Protected r1.f, g1.f, b1.f, a1.f
  Protected r.f, g.f, b.f, a.f
  Protected scaleX.f = (srcW - 1) / dstW
  Protected scaleY.f = (srcH - 1) / dstH
  Protected srcWMinus1 = srcW - 1
  Protected srcHMinus1 = srcH - 1
  
  For y = 0 To dstH - 1
    sy = y * scaleY
    y0 = sy
    y1 = y0 + 1
    If y1 > srcHMinus1 : y1 = srcHMinus1 : EndIf
    fy = sy - y0
    fy1 = 1.0 - fy
    
    For x = 0 To dstW - 1
      sx = x * scaleX
      x0 = sx
      x1 = x0 + 1
      If x1 > srcWMinus1 : x1 = srcWMinus1 : EndIf
      fx = sx - x0
      fx1 = 1.0 - fx
      
      idx00 = (y0 * srcW + x0) << 2
      idx01 = (y0 * srcW + x1) << 2
      idx10 = (y1 * srcW + x0) << 2
      idx11 = (y1 * srcW + x1) << 2
      
      a00 = PeekA(*src + idx00 + 3) : r00 = PeekA(*src + idx00 + 2)
      g00 = PeekA(*src + idx00 + 1) : b00 = PeekA(*src + idx00)
      
      a01 = PeekA(*src + idx01 + 3) : r01 = PeekA(*src + idx01 + 2)
      g01 = PeekA(*src + idx01 + 1) : b01 = PeekA(*src + idx01)
      
      a10 = PeekA(*src + idx10 + 3) : r10 = PeekA(*src + idx10 + 2)
      g10 = PeekA(*src + idx10 + 1) : b10 = PeekA(*src + idx10)
      
      a11 = PeekA(*src + idx11 + 3) : r11 = PeekA(*src + idx11 + 2)
      g11 = PeekA(*src + idx11 + 1) : b11 = PeekA(*src + idx11)
      
      ; Interpolation bilinéaire
      a0 = a00 * fx1 + a01 * fx : a1 = a10 * fx1 + a11 * fx : a = a0 * fy1 + a1 * fy
      r0 = r00 * fx1 + r01 * fx : r1 = r10 * fx1 + r11 * fx : r = r0 * fy1 + r1 * fy
      g0 = g00 * fx1 + g01 * fx : g1 = g10 * fx1 + g11 * fx : g = g0 * fy1 + g1 * fy
      b0 = b00 * fx1 + b01 * fx : b1 = b10 * fx1 + b11 * fx : b = b0 * fy1 + b1 * fy
      
      idx = (y * dstW + x) << 2
      PokeA(*dst + idx + 3, a + 0.5)
      PokeA(*dst + idx + 2, r + 0.5)
      PokeA(*dst + idx + 1, g + 0.5)
      PokeA(*dst + idx    , b + 0.5)
    Next
  Next
EndProcedure

; --- Procédure principale ---
Procedure Bilateraltab_laplacianBlur_sp(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected levels = *param\option[0]
  Protected radius = *param\option[1]
  Protected sigma.f = *param\option[2]
  
  If levels < 2 : levels = 2 : EndIf
  If levels > 5 : levels = 5 : EndIf
  If radius < 1 : radius = 1 : EndIf
  If sigma < 1.0 : sigma = 10.0 : EndIf
  
  Protected l, i, size
  Protected *temp
  
  ; Dimensions de chaque niveau
  Dim levelW.i(levels - 1)
  Dim levelH.i(levels - 1)
  Dim pyramid.i(levels - 1)
  Dim tab_laplacian.i(levels - 2)
  
  For l = 0 To levels - 1
    levelW(l) = lg >> l
    levelH(l) = ht >> l
    If levelW(l) < 1 : levelW(l) = 1 : EndIf
    If levelH(l) < 1 : levelH(l) = 1 : EndIf
  Next
  
  ; Allocation de la pyramide
  For l = 0 To levels - 1
    size = levelW(l) * levelH(l) * 4
    pyramid(l) = AllocateMemory(size)
    If Not pyramid(l) : Goto cleanup : EndIf
  Next
  
  ; Allocation des laplaciens
  For l = 0 To levels - 2
    size = levelW(l) * levelH(l) * 4
    tab_laplacian(l) = AllocateMemory(size)
    If Not tab_laplacian(l) : Goto cleanup : EndIf
  Next
  
  *temp = AllocateMemory(lg * ht * 4)
  If Not *temp : Goto cleanup : EndIf
  
  ; 1. Construction de la pyramide gaussienne
  CopyMemory(*param\addr[0], pyramid(0), lg * ht * 4)
  
  For l = 1 To levels - 1
    Bilateraltab_laplacian_Downscale(pyramid(l - 1), levelW(l - 1), levelH(l - 1),
                                  pyramid(l), levelW(l), levelH(l))
  Next
  
  ; 2. Calcul des pyramides laplaciennes
  For l = 0 To levels - 2
    ; Upscale du niveau suivant
    Bilateraltab_laplacian_Upscale(pyramid(l + 1), levelW(l + 1), levelH(l + 1),
                                *temp, levelW(l), levelH(l))
    
    ; Laplacien = niveau courant - niveau suivant upscalé
    size = levelW(l) * levelH(l)
    For i = 0 To size - 1
      Protected offset = i << 2
      Protected a0 = PeekA(pyramid(l) + offset + 3)
      Protected r0 = PeekA(pyramid(l) + offset + 2)
      Protected g0 = PeekA(pyramid(l) + offset + 1)
      Protected b0 = PeekA(pyramid(l) + offset)
      
      Protected a1 = PeekA(*temp + offset + 3)
      Protected r1 = PeekA(*temp + offset + 2)
      Protected g1 = PeekA(*temp + offset + 1)
      Protected b1 = PeekA(*temp + offset)
      
      ; Différence signée (stocker comme unsigned avec offset 128)
      PokeA(tab_laplacian(l) + offset + 3, 128 + (a0 - a1) / 2)
      PokeA(tab_laplacian(l) + offset + 2, 128 + (r0 - r1) / 2)
      PokeA(tab_laplacian(l) + offset + 1, 128 + (g0 - g1) / 2)
      PokeA(tab_laplacian(l) + offset    , 128 + (b0 - b1) / 2)
    Next
  Next
  
  ; 3. Appliquer le bilateral blur sur chaque laplacien
  For l = 0 To levels - 2
    Protected effectiveRadius
    Max(effectiveRadius , 1, (radius >> l))
    BilateralBlurBuffer(tab_laplacian(l), levelW(l), levelH(l), effectiveRadius, sigma)
  Next
  
  ; 4. Reconstruction
  For l = levels - 2 To 0 Step -1
    ; Upscale du niveau supérieur
    Bilateraltab_laplacian_Upscale(pyramid(l + 1), levelW(l + 1), levelH(l + 1),
                                *temp, levelW(l), levelH(l))
    
    ; Ajouter le laplacien filtré
    size = levelW(l) * levelH(l)
    For i = 0 To size - 1
      offset = i << 2
      
      a1 = PeekA(*temp + offset + 3)
      r1 = PeekA(*temp + offset + 2)
      g1 = PeekA(*temp + offset + 1)
      b1 = PeekA(*temp + offset)
      
      ; Récupérer le laplacien (reconvertir depuis offset 128)
      Protected aL = (PeekA(tab_laplacian(l) + offset + 3) - 128) * 2
      Protected rL = (PeekA(tab_laplacian(l) + offset + 2) - 128) * 2
      Protected gL = (PeekA(tab_laplacian(l) + offset + 1) - 128) * 2
      Protected bL = (PeekA(tab_laplacian(l) + offset) - 128) * 2
      
      ; Somme
      Protected aFinal = a1 + aL
      Protected rFinal = r1 + rL
      Protected gFinal = g1 + gL
      Protected bFinal = b1 + bL
      
      ; Clamping
      If aFinal < 0 : aFinal = 0 : ElseIf aFinal > 255 : aFinal = 255 : EndIf
      If rFinal < 0 : rFinal = 0 : ElseIf rFinal > 255 : rFinal = 255 : EndIf
      If gFinal < 0 : gFinal = 0 : ElseIf gFinal > 255 : gFinal = 255 : EndIf
      If bFinal < 0 : bFinal = 0 : ElseIf bFinal > 255 : bFinal = 255 : EndIf
      
      PokeA(pyramid(l) + offset + 3, aFinal)
      PokeA(pyramid(l) + offset + 2, rFinal)
      PokeA(pyramid(l) + offset + 1, gFinal)
      PokeA(pyramid(l) + offset    , bFinal)
    Next
  Next
  
  ; Copier le résultat final
  CopyMemory(pyramid(0), *param\addr[1], lg * ht * 4)
  
  cleanup:
  ; Libération
  For l = 0 To levels - 1
    If pyramid(l) : FreeMemory(pyramid(l)) : EndIf
  Next
  For l = 0 To levels - 2
    If tab_laplacian(l) : FreeMemory(tab_laplacian(l)) : EndIf
  Next
  If *temp : FreeMemory(*temp) : EndIf
EndProcedure

; --- Wrapper ---
Procedure BilaterallaplacianBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_EdgeAware
    *param\name = "Bilateral laplacian Blur"
    *param\remarque = "Flou multi-échelle préservant les contours via pyramide laplacienne (ne marche pas)"
    *param\info[0] = "Niveaux pyramide"
    *param\info[1] = "Rayon spatial"
    *param\info[2] = "Sigma couleur"
    *param\info[3] = "Masque"
    *param\info_data(0, 0) = 2 : *param\info_data(0, 1) = 5  : *param\info_data(0, 2) = 3
    *param\info_data(1, 0) = 1 : *param\info_data(1, 1) = 12 : *param\info_data(1, 2) = 3
    *param\info_data(2, 0) = 5 : *param\info_data(2, 1) = 100: *param\info_data(2, 2) = 25
    *param\info_data(3, 0) = 0 : *param\info_data(3, 1) = 2  : *param\info_data(3, 2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Bilateraltab_laplacianBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 355
; FirstLine = 299
; Folding = -
; EnableXP
; DPIAware