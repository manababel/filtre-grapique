; ---------------------------------------------------
; Bilateral Laplacian Blur - Version optimisée et corrigée
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
  
  If sigmaColor = 0.0 : sigmaColor = 1.0 : EndIf
  Protected invSigma2.f = -1.0 / (2.0 * sigmaColor * sigmaColor)
  
  Protected radiusSq.f = radius * radius
  Protected invRadiusSq.f = -1.0 / (2.0 * radiusSq)
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
          
          sumR + (r * wTot)
          sumG + (g * wTot)
          sumB + (b * wTot)
          sumA + (a * wTot)
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
Procedure Bilateraltab_laplacian_Downscale(*FilterCtx.FilterParams)
  Protected *src.pixelarray = *FilterCtx\addr[2]
  Protected srcW = *FilterCtx\addr[3]
  Protected srcH = *FilterCtx\addr[4]
  Protected *dst.pixelarray = *FilterCtx\addr[5]
  Protected dstW = *FilterCtx\addr[6]
  Protected dstH = *FilterCtx\addr[7]
  
  Protected x, y, sx, sy, ex, ey, sumR, sumG, sumB, sumA, count, px, py
  Protected scaleX.f = srcW / dstW
  Protected scaleY.f = srcH / dstH
  Protected.l a , r , g , b
  
  macro_calul_tread(dstH)
  
  For y = thread_start To thread_stop - 1
    sy = y * scaleY : ey = (y + 1) * scaleY : If ey > srcH : ey = srcH : EndIf
    For x = 0 To dstW - 1
      sx = x * scaleX : ex = (x + 1) * scaleX : If ex > srcW : ex = srcW : EndIf
      sumR = 0 : sumG = 0 : sumB = 0 : sumA = 0 : count = 0
      For py = sy To ey - 1
        For px = sx To ex - 1
          getargb(*src\l[py * srcW + px] , a , r , g , b)
          sumA + a : sumR + r : sumG + g : sumB + b
          count + 1
        Next
      Next
      If count > 0
        a = sumA / count
        r = sumR / count
        g = sumG / count
        b = sumB / count
        ; Format ARGB strict
        *dst\l[y * dstW + x] = (a << 24) | (r << 16) | (g << 8) | b
      EndIf
    Next
  Next
EndProcedure

; --- Upscale bilinéaire ---
Procedure Bilateraltab_laplacian_Upscale(*FilterCtx.FilterParams)
  Protected *src.pixelarray = *FilterCtx\addr[2]
  Protected srcW = *FilterCtx\addr[3]
  Protected srcH = *FilterCtx\addr[4]
  Protected *dst.pixelarray = *FilterCtx\addr[5]
  Protected dstW = *FilterCtx\addr[6]
  Protected dstH = *FilterCtx\addr[7]
  
  Protected x, y, x0, y0, x1, y1
  Protected sx.f, sy.f, fx.f, fy.f, fx1.f, fy1.f
  Protected r00, g00, b00, a00, r01, g01, b01, a01, r10, g10, b10, a10, r11, g11, b11, a11
  Protected r.f, g.f, b.f, a.f
  Protected.l al , rl , gl , bl
  
  Protected scaleX.f = srcW / dstW 
  Protected scaleY.f = srcH / dstH
  
  macro_calul_tread(dstH)
  
  For y = thread_start To thread_stop - 1
    sy = (y + 0.5) * scaleY - 0.5
    If sy < 0 : sy = 0 : EndIf
    y0 = Int(sy)
    y1 = y0 + 1
    If y1 >= srcH : y1 = srcH - 1 : EndIf
    fy = sy - y0 : fy1 = 1.0 - fy
    
    For x = 0 To dstW - 1
      sx = (x + 0.5) * scaleX - 0.5
      If sx < 0 : sx = 0 : EndIf
      x0 = Int(sx)
      x1 = x0 + 1 : If x1 >= srcW : x1 = srcW - 1 : EndIf
      fx = sx - x0 : fx1 = 1.0 - fx
      
      getargb(*src\l[y0 * srcW + x0] , a00 , r00 , g00 , b00) 
      getargb(*src\l[y0 * srcW + x1] , a01 , r01 , g01 , b01)
      getargb(*src\l[y1 * srcW + x0] , a10 , r10 , g10 , b10) 
      getargb(*src\l[y1 * srcW + x1] , a11 , r11 , g11 , b11) 
      
      a = ((a00*fx1 + a01*fx)*fy1 + (a10*fx1 + a11*fx)*fy) + 0.5
      r = ((r00*fx1 + r01*fx)*fy1 + (r10*fx1 + r11*fx)*fy) + 0.5
      g = ((g00*fx1 + g01*fx)*fy1 + (g10*fx1 + g11*fx)*fy) + 0.5
      b = ((b00*fx1 + b01*fx)*fy1 + (b10*fx1 + b11*fx)*fy) + 0.5
      
      al = a : rl = r : gl = g : bl = b
      *dst\l[y * dstW + x] = (al << 24) | (rl << 16) | (gl << 8) | bl
    Next
  Next
EndProcedure

; --- Procédure de traitement ---
Procedure Bilateraltab_laplacianBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected levels = \option[0], radius = \option[1]
    Protected sigma.f = \option[2] 
    
    clamp(levels , 2 , 5) 
    
    Dim levelW(levels)
    Dim levelH(levels)
    Dim pyramid(levels)
    Dim tab_laplacian(levels)
    
    Protected l, i, *temp = AllocateMemory(lg * ht * 4)
    
    If Not *temp : ProcedureReturn : EndIf
    
    For l = 0 To levels - 1
      levelW(l) = lg >> l : levelH(l) = ht >> l
      If levelW(l) < 1 : levelW(l) = 1 : EndIf
      If levelH(l) < 1 : levelH(l) = 1 : EndIf
      pyramid(l) = AllocateMemory(levelW(l) * levelH(l) * 4)
      If l < levels - 1 
        tab_laplacian(l) = AllocateMemory(levelW(l) * levelH(l) * 4) 
      EndIf
    Next
    
    CopyMemory(\addr[0], pyramid(0), lg * ht * 4)
    
    ; 1. Construction de la pyramide Gaussienne
    For l = 1 To levels - 1
      \addr[2] = pyramid(l - 1)
      \addr[3] = levelW(l - 1)
      \addr[4] = levelH(l - 1)
      \addr[5] = pyramid(l)
      \addr[6] = levelW(l)
      \addr[7] = levelH(l)
      Create_MultiThread_MT(@Bilateraltab_laplacian_Downscale())
    Next
    
    ; 2. Construction du Laplacien + Filtrage Bilatéral
    Protected t = ElapsedMilliseconds()
    For l = 0 To levels - 2
      \addr[2] = pyramid(l + 1)
      \addr[3] = levelW(l + 1)
      \addr[4] = levelH(l + 1)
      \addr[5] = *temp
      \addr[6] = levelW(l)
      \addr[7] = levelH(l)
      
      Create_MultiThread_MT(@Bilateraltab_laplacian_Upscale())
      
      Protected *pyrPtr.pixelarray = pyramid(l)
      Protected *tmpPtr.pixelarray = *temp
      Protected *lapPtr.pixelarray = tab_laplacian(l)
      Protected.l pA, pR, pG, pB, tA, tR, tG, tB, lA, lR, lG1, lB
      
      For i = 0 To (levelW(l) * levelH(l)) - 1
        getargb(*pyrPtr\l[i], pA, pR, pG, pB)
        getargb(*tmpPtr\l[i], tA, tR, tG, tB)
        
        lA = 128 + (pA - tA) / 2
        lR = 128 + (pR - tR) / 2
        lG1 = 128 + (pG - tG) / 2 ; FIXED : lG1 changé en lG
        lB = 128 + (pB - tB) / 2
        
        ; Format ARGB strict
        *lapPtr\l[i] = (lA << 24) | (lR << 16) | (lG1 << 8) | lB
      Next
      
      Protected effRad = radius >> l : If effRad < 1 : effRad = 1 : EndIf
      BilateralBlurBuffer(tab_laplacian(l), levelW(l), levelH(l), effRad, sigma)
    Next
    \tmp = ElapsedMilliseconds() - t
    
    ; 3. Reconstruction de l'image
    For l = levels - 2 To 0 Step -1
      \addr[2] = pyramid(l + 1)
      \addr[3] = levelW(l + 1)
      \addr[4] = levelH(l + 1)
      \addr[5] = pyramid(l)
      \addr[6] = levelW(l)
      \addr[7] = levelH(l)
      
      Create_MultiThread_MT(@Bilateraltab_laplacian_Upscale())
      
      Protected *pyrRec.pixelarray = pyramid(l)
      Protected *lapRec.pixelarray = tab_laplacian(l)
      Protected.l rA, rR, rG, rB, lapA, lapR, lapG, lapB, resA, resR, resG, resB
      
      For i = 0 To (levelW(l) * levelH(l)) - 1
        getargb(*pyrRec\l[i], rA, rR, rG, rB)
        getargb(*lapRec\l[i], lapA, lapR, lapG, lapB)
        
        resA = rA + (lapA - 128) * 2 : If resA < 0 : resA = 0 : ElseIf resA > 255 : resA = 255 : EndIf
        resR = rR + (lapR - 128) * 2 : If resR < 0 : resR = 0 : ElseIf resR > 255 : resR = 255 : EndIf
        resG = rG + (lapG - 128) * 2 : If resG < 0 : resG = 0 : ElseIf resG > 255 : resG = 255 : EndIf
        resB = rB + (lapB - 128) * 2 : If resB < 0 : resB = 0 : ElseIf resB > 255 : resB = 255 : EndIf
        
        ; Format ARGB strict
        *pyrRec\l[i] = (resA << 24) | (resR << 16) | (resG << 8) | resB
      Next
    Next
    
    CopyMemory(pyramid(0), \addr[1], lg * ht * 4)
    
    ; Libération mémoire propre
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
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Bilateraltab_laplacianBlur_sp(*FilterCtx)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

; --- Appel simplifie ---
Procedure BilaterallaplacianBlur(source, cible, mask, levels, radius, sigma )
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = radius
    \option[2] = sigma
  EndWith
  BilaterallaplacianBlurEx(FilterCtx)
EndProcedure




DataSection
  BilaterallaplacianBlur_data:
  Data.s "BilaterallaplacianBlur"
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
; CursorPosition = 299
; FirstLine = 277
; Folding = --
; EnableXP
; DPIAware