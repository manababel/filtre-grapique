; ---------------------------------------------------
; MultiScale Bilateral Blur - Version optimisée
; ---------------------------------------------------

; --- Bilateral blur sur un buffer (optimisé) ---
Procedure MultiScale_BilateralBlurBuffer(*buf, w, h, radius, sigmaColor.f)
  If radius < 1 : ProcedureReturn : EndIf
  
  Protected *tmp = AllocateMemory(w * h * 4)
  If Not *tmp : ProcedureReturn : EndIf
  
  Protected x, y, dx, dy, px, py
  Protected idx, idx2, offset
  Protected r0, g0, b0, a0
  Protected r, g, b, a
  Protected sumR.f, sumG.f, sumB.f, sumA.f, sumW.f
  Protected dColor.f, wColor.f, wSpace.f, wTot.f
  Protected sigmaColor2.f = sigmaColor * sigmaColor
  Protected invSigmaColor2.f = -1.0 / sigmaColor2
  Protected radiusSq.f = radius * radius
  Protected invRadiusSq.f = -1.0 / radiusSq
  Protected dxSq, dySq, distSq
  
  For y = 0 To h - 1
    offset = y * w << 2
    For x = 0 To w - 1
      idx = offset + (x << 2)
      
      ; Pixel central
      a0 = PeekA(*buf + idx + 3)
      r0 = PeekA(*buf + idx + 2)
      g0 = PeekA(*buf + idx + 1)
      b0 = PeekA(*buf + idx)
      
      sumR = 0.0
      sumG = 0.0
      sumB = 0.0
      sumA = 0.0
      sumW = 0.0
      
      For dy = -radius To radius
        py = y + dy
        If py < 0 : py = 0 : ElseIf py >= h : py = h - 1 : EndIf
        dySq = dy * dy
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 : px = 0 : ElseIf px >= w : px = w - 1 : EndIf
          
          idx2 = (py * w + px) << 2
          
          r = PeekA(*buf + idx2 + 2)
          g = PeekA(*buf + idx2 + 1)
          b = PeekA(*buf + idx2)
          a = PeekA(*buf + idx2 + 3)
          
          ; Distance couleur
          dColor = (r - r0) * (r - r0) + (g - g0) * (g - g0) + (b - b0) * (b - b0)
          wColor = Exp(dColor * invSigmaColor2)
          
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

; --- Downscale image (box filter) ---
Procedure MultiScale_DownscaleImage(*src, srcW, srcH, *dst, dstW, dstH)
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

; --- Upscale image (bilinear) ---
Procedure MultiScale_UpscaleImage(*src, srcW, srcH, *dst, dstW, dstH)
  Protected x, y, sx, sy
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
      
      a00 = PeekA(*src + idx00 + 3)
      r00 = PeekA(*src + idx00 + 2)
      g00 = PeekA(*src + idx00 + 1)
      b00 = PeekA(*src + idx00)
      
      a01 = PeekA(*src + idx01 + 3)
      r01 = PeekA(*src + idx01 + 2)
      g01 = PeekA(*src + idx01 + 1)
      b01 = PeekA(*src + idx01)
      
      a10 = PeekA(*src + idx10 + 3)
      r10 = PeekA(*src + idx10 + 2)
      g10 = PeekA(*src + idx10 + 1)
      b10 = PeekA(*src + idx10)
      
      a11 = PeekA(*src + idx11 + 3)
      r11 = PeekA(*src + idx11 + 2)
      g11 = PeekA(*src + idx11 + 1)
      b11 = PeekA(*src + idx11)
      
      a0 = a00 * fx1 + a01 * fx
      a1 = a10 * fx1 + a11 * fx
      a = a0 * fy1 + a1 * fy
      
      r0 = r00 * fx1 + r01 * fx
      r1 = r10 * fx1 + r11 * fx
      r = r0 * fy1 + r1 * fy
      
      g0 = g00 * fx1 + g01 * fx
      g1 = g10 * fx1 + g11 * fx
      g = g0 * fy1 + g1 * fy
      
      b0 = b00 * fx1 + b01 * fx
      b1 = b10 * fx1 + b11 * fx
      b = b0 * fy1 + b1 * fy
      
      idx = (y * dstW + x) << 2
      PokeA(*dst + idx + 3, a + 0.5)
      PokeA(*dst + idx + 2, r + 0.5)
      PokeA(*dst + idx + 1, g + 0.5)
      PokeA(*dst + idx    , b + 0.5)
    Next
  Next
EndProcedure

; --- Procédure de traitement interne (sp) ---
Procedure MultiScaleBilateralBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected levels = \option[0]
    Protected radius = \option[1]
    Protected sigmaColor.f = \option[2]
    
    If levels < 1 : levels = 1 : EndIf
    If levels > 5 : levels = 5 : EndIf
    If radius < 1 : radius = 1 : EndIf
    If sigmaColor < 1.0 : sigmaColor = 10.0 : EndIf
    
    Protected l, w, h
    Protected *temp
    
    Dim levelW.i(levels - 1)
    Dim levelH.i(levels - 1)
    Dim pyramid.i(levels - 1)
    
    For l = 0 To levels - 1
      levelW(l) = lg >> l
      levelH(l) = ht >> l
      If levelW(l) < 1 : levelW(l) = 1 : EndIf
      If levelH(l) < 1 : levelH(l) = 1 : EndIf
    Next
    
    For l = 0 To levels - 1
      pyramid(l) = AllocateMemory(levelW(l) * levelH(l) * 4)
      If Not pyramid(l)
        For l = 0 To levels - 1
          If pyramid(l) : FreeMemory(pyramid(l)) : EndIf
        Next
        ProcedureReturn
      EndIf
    Next
    
    *temp = AllocateMemory(lg * ht * 4)
    If Not *temp
      For l = 0 To levels - 1
        FreeMemory(pyramid(l))
      Next
      ProcedureReturn
    EndIf
    
    CopyMemory(\addr[0], pyramid(0), lg * ht * 4)
    
    For l = 1 To levels - 1
      MultiScale_DownscaleImage(pyramid(l - 1), levelW(l - 1), levelH(l - 1), 
                                 pyramid(l), levelW(l), levelH(l))
    Next
    
    For l = 0 To levels - 1
      Protected effectiveRadius = radius >> l
      If effectiveRadius < 1 : effectiveRadius = 1 : EndIf
      
      MultiScale_BilateralBlurBuffer(pyramid(l), levelW(l), levelH(l), 
                                      effectiveRadius, sigmaColor)
    Next
    
    For l = levels - 1 To 1 Step -1
      MultiScale_UpscaleImage(pyramid(l), levelW(l), levelH(l), 
                               *temp, levelW(l - 1), levelH(l - 1))
      
      Protected idx, alpha.f = 0.5
      For idx = 0 To levelW(l - 1) * levelH(l - 1) * 4 - 1
        Protected v1 = PeekA(pyramid(l - 1) + idx)
        Protected v2 = PeekA(*temp + idx)
        PokeA(pyramid(l - 1) + idx, v1 * alpha + v2 * (1.0 - alpha) + 0.5)
      Next
    Next
    
    CopyMemory(pyramid(0), \addr[1], lg * ht * 4)
    
    For l = 0 To levels - 1
      FreeMemory(pyramid(l))
    Next
    FreeMemory(*temp)
  EndWith
EndProcedure

; --- Procédure principale renommée ---
Procedure MultiScaleBilateralBlurEx(*FilterCtx.FilterParams)
  Restore MultiScaleBilateralBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@MultiScaleBilateralBlur_sp())
  
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

; --- Nouvelle procédure principale (Appel) ---
Procedure MultiScaleBilateralBlur(source, cible, mask, levels, radius, sigmaColor, mask_type)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = radius
    \option[2] = sigmaColor
    \option[3] = mask_type
  EndWith
  MultiScaleBilateralBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  MultiScaleBilateralBlur_data:
  Data.s "MultiScaleBilateralBlur"
  Data.s "Lissage multi-échelle préservant les contours"
  Data.i #FilterType_Blur
  Data.i #Blur_EdgeAware
  
  Data.s "Niveaux pyramide"       
  Data.i 1, 5, 3
  Data.s "Rayon spatial"   
  Data.i 1, 16, 4
  Data.s "Sigma couleur"        
  Data.i 5, 100, 25
  Data.s "Masque"  
  Data.i 0, 2, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 311
; FirstLine = 295
; Folding = --
; EnableXP
; DPIAware