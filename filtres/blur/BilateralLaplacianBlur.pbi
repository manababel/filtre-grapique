; ---------------------------------------------------
; Bilateral Laplacian Blur - Version optimisée
; Flou multi-échelle avec préservation des contours
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
      
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : sumW = 0.0
      
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
          
          dColor = (r0 - r) * (r0 - r) + (g0 - g) * (g0 - g) + (b0 - b) * (b0 - b)
          wColor = Exp(dColor * invSigma2)
          
          dxSq = dx * dx
          distSq = dxSq + dySq
          wSpace = Exp(distSq * invRadiusSq)
          
          wTot = wColor * wSpace
          
          sumR + r * wTot : sumG + g * wTot : sumB + b * wTot : sumA + a * wTot
          sumW + wTot
        Next
      Next
      
      If sumW > 0.0001
        PokeA(*tmp + idx + 3, sumA / sumW + 0.5)
        PokeA(*tmp + idx + 2, sumR / sumW + 0.5)
        PokeA(*tmp + idx + 1, sumG / sumW + 0.5)
        PokeA(*tmp + idx    , sumB / sumW + 0.5)
      Else
        PokeA(*tmp + idx + 3, a0) : PokeA(*tmp + idx + 2, r0)
        PokeA(*tmp + idx + 1, g0) : PokeA(*tmp + idx    , b0)
      EndIf
    Next
  Next
  
  CopyMemory(*tmp, *buf, w * h * 4)
  FreeMemory(*tmp)
EndProcedure

; --- Downscale ---
Procedure Bilateraltab_laplacian_Downscale(*src, srcW, srcH, *dst, dstW, dstH)
  Protected x, y, sx, sy, ex, ey, sumR, sumG, sumB, sumA, count, px, py, idx, idx2
  Protected scaleX.f = srcW / dstW : Protected scaleY.f = srcH / dstH
  For y = 0 To dstH - 1
    sy = y * scaleY : ey = (y + 1) * scaleY : If ey > srcH : ey = srcH : EndIf
    For x = 0 To dstW - 1
      sx = x * scaleX : ex = (x + 1) * scaleX : If ex > srcW : ex = srcW : EndIf
      sumR = 0 : sumG = 0 : sumB = 0 : sumA = 0 : count = 0
      For py = sy To ey - 1
        For px = sx To ex - 1
          idx = (py * srcW + px) << 2
          sumA + PeekA(*src + idx + 3) : sumR + PeekA(*src + idx + 2)
          sumG + PeekA(*src + idx + 1) : sumB + PeekA(*src + idx)
          count + 1
        Next
      Next
      If count > 0
        idx2 = (y * dstW + x) << 2
        PokeA(*dst + idx2 + 3, sumA / count) : PokeA(*dst + idx2 + 2, sumR / count)
        PokeA(*dst + idx2 + 1, sumG / count) : PokeA(*dst + idx2    , sumB / count)
      EndIf
    Next
  Next
EndProcedure

; --- Upscale bilinéaire ---
Procedure Bilateraltab_laplacian_Upscale(*src, srcW, srcH, *dst, dstW, dstH)
  Protected x, y, sx.f, sy.f, x0, y0, x1, y1, idx
  Protected fx.f, fy.f, fx1.f, fy1.f
  Protected r00, g00, b00, a00, r01, g01, b01, a01, r10, g10, b10, a10, r11, g11, b11, a11
  Protected r0.f, g0.f, b0.f, a0.f, r1.f, g1.f, b1.f, a1.f, r.f, g.f, b.f, a.f
  Protected scaleX.f = (srcW - 1) / dstW : Protected scaleY.f = (srcH - 1) / dstH
  For y = 0 To dstH - 1
    sy = y * scaleY : y0 = sy : y1 = y0 + 1 : If y1 >= srcH : y1 = srcH - 1 : EndIf
    fy = sy - y0 : fy1 = 1.0 - fy
    For x = 0 To dstW - 1
      sx = x * scaleX : x0 = sx : x1 = x0 + 1 : If x1 >= srcW : x1 = srcW - 1 : EndIf
      fx = sx - x0 : fx1 = 1.0 - fx
      idx = (y * dstW + x) << 2
      a00 = PeekA(*src + (y0*srcW+x0)*4 + 3) : r00 = PeekA(*src + (y0*srcW+x0)*4 + 2)
      g00 = PeekA(*src + (y0*srcW+x0)*4 + 1) : b00 = PeekA(*src + (y0*srcW+x0)*4)
      a01 = PeekA(*src + (y0*srcW+x1)*4 + 3) : r01 = PeekA(*src + (y0*srcW+x1)*4 + 2)
      g01 = PeekA(*src + (y0*srcW+x1)*4 + 1) : b01 = PeekA(*src + (y0*srcW+x1)*4)
      a10 = PeekA(*src + (y1*srcW+x0)*4 + 3) : r10 = PeekA(*src + (y1*srcW+x0)*4 + 2)
      g10 = PeekA(*src + (y1*srcW+x0)*4 + 1) : b10 = PeekA(*src + (y1*srcW+x0)*4)
      a11 = PeekA(*src + (y1*srcW+x1)*4 + 3) : r11 = PeekA(*src + (y1*srcW+x1)*4 + 2)
      g11 = PeekA(*src + (y1*srcW+x1)*4 + 1) : b11 = PeekA(*src + (y1*srcW+x1)*4)
      a = (a00*fx1+a01*fx)*fy1 + (a10*fx1+a11*fx)*fy
      r = (r00*fx1+r01*fx)*fy1 + (r10*fx1+r11*fx)*fy
      g = (g00*fx1+g01*fx)*fy1 + (g10*fx1+g11*fx)*fy
      b = (b00*fx1+b01*fx)*fy1 + (b10*fx1+b11*fx)*fy
      PokeA(*dst + idx + 3, a + 0.5) : PokeA(*dst + idx + 2, r + 0.5)
      PokeA(*dst + idx + 1, g + 0.5) : PokeA(*dst + idx    , b + 0.5)
    Next
  Next
EndProcedure

; --- Procédure de traitement ---
Procedure Bilateraltab_laplacianBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected levels = \option[0], radius = \option[1], sigma.f = \option[2]
    If levels < 2 : levels = 2 : ElseIf levels > 5 : levels = 5 : EndIf
    
    Dim levelW(levels)
    Dim levelH(levels)
    Dim pyramid(levels)
    Dim tab_laplacian(levels)
    Protected c , l, i, offset, size, *temp = AllocateMemory(lg * ht * 4)
    
    For l = 0 To levels - 1
      levelW(l) = lg >> l : levelH(l) = ht >> l
      If levelW(l) < 1 : levelW(l) = 1 : EndIf
      If levelH(l) < 1 : levelH(l) = 1 : EndIf
      pyramid(l) = AllocateMemory(levelW(l) * levelH(l) * 4)
      If l < levels - 1 : tab_laplacian(l) = AllocateMemory(levelW(l) * levelH(l) * 4) : EndIf
    Next
    
    CopyMemory(\addr[0], pyramid(0), lg * ht * 4)
    For l = 1 To levels - 1
      Bilateraltab_laplacian_Downscale(pyramid(l - 1), levelW(l - 1), levelH(l - 1), pyramid(l), levelW(l), levelH(l))
    Next
    
    For l = 0 To levels - 2
      Bilateraltab_laplacian_Upscale(pyramid(l + 1), levelW(l + 1), levelH(l + 1), *temp, levelW(l), levelH(l))
      For i = 0 To (levelW(l) * levelH(l)) - 1
        offset = i << 2
        PokeA(tab_laplacian(l) + offset + 3, 128 + (PeekA(pyramid(l)+offset+3) - PeekA(*temp+offset+3)) / 2)
        PokeA(tab_laplacian(l) + offset + 2, 128 + (PeekA(pyramid(l)+offset+2) - PeekA(*temp+offset+2)) / 2)
        PokeA(tab_laplacian(l) + offset + 1, 128 + (PeekA(pyramid(l)+offset+1) - PeekA(*temp+offset+1)) / 2)
        PokeA(tab_laplacian(l) + offset    , 128 + (PeekA(pyramid(l)+offset)   - PeekA(*temp+offset))   / 2)
      Next
      Protected effRad = radius >> l : If effRad < 1 : effRad = 1 : EndIf
      BilateralBlurBuffer(tab_laplacian(l), levelW(l), levelH(l), effRad, sigma)
    Next
    
    For l = levels - 2 To 0 Step -1
      Bilateraltab_laplacian_Upscale(pyramid(l + 1), levelW(l + 1), levelH(l + 1), pyramid(l), levelW(l), levelH(l))
      For i = 0 To (levelW(l) * levelH(l)) - 1
        offset = i << 2
        For c = 0 To 3
          Protected res = PeekA(pyramid(l)+offset+c) + (PeekA(tab_laplacian(l)+offset+c) - 128) * 2
          If res < 0 : res = 0 : ElseIf res > 255 : res = 255 : EndIf
          PokeA(pyramid(l) + offset + c, res)
        Next
      Next
    Next
    
    CopyMemory(pyramid(0), \addr[1], lg * ht * 4)
    For l = 0 To levels - 1
      If pyramid(l) : FreeMemory(pyramid(l)) : EndIf
      If l < levels - 1 And tab_laplacian(l) : FreeMemory(tab_laplacian(l)) : EndIf
    Next
    FreeMemory(*temp)
  EndWith
EndProcedure

; --- Procédure Ex ---
Procedure BilaterallaplacianBlurEx(*FilterCtx.FilterParams)
  Restore BilaterallaplacianBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@Bilateraltab_laplacianBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

; --- Appel simplifie ---
Procedure BilaterallaplacianBlur(source, cible, mask, levels, radius, sigma, mask_type)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = levels : \option[1] = radius : \option[2] = sigma : \option[3] = mask_type
  EndWith
  BilaterallaplacianBlurEx(FilterCtx)
EndProcedure

DataSection
  BilaterallaplacianBlur_data:
  Data.s "BilaterallaplacianBlur (probleme)"
  Data.s "Flou multi-échelle préservant les contours (Laplacian)"
  Data.i #FilterType_Blur, #Blur_EdgeAware
  Data.s "Niveaux"
  Data.i 2, 5, 3    ; Niveaux
  Data.s "Rayon"
  Data.i 1, 12, 4   ; Rayon
  Data.s "Sigma Couleur"
  Data.i 5, 100, 25 ; Sigma
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 222
; FirstLine = 181
; Folding = --
; EnableXP
; DPIAware