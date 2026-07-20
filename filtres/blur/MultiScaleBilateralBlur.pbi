; --- Structure d'accès rapide aux octets d'un pixel (sécurise l'ordre RGBA/BGRA) ---
Structure PB_Pixel
  StructureUnion
    l.l
    b.a[4]
  EndStructureUnion
EndStructure

Structure pixelarray_opt
  p.PB_Pixel[0]
EndStructure

;Procedure MultiScale_BilateralBlurBuffer(*buf, w, h, radius, sigmaColor.f)
Procedure MultiScale_BilateralBlurBuffer(*FilterCtx.FilterParams)
  
  Protected *buf   = *FilterCtx\addr[3]
  Protected w      = *FilterCtx\addr[4]
  Protected h      = *FilterCtx\addr[5]
  Protected radius = *FilterCtx\addr[6]
  
  ; Récupération sécurisée du flottant via son adresse
  Protected *pSigma.Float = *FilterCtx\addr[7]
  Protected sigmaColor.f  = *pSigma\f
  
  If radius < 1 : ProcedureReturn : EndIf
  
  Protected x, y, dx, dy, px, py
  Protected.l r0, g0, b0, a0
  Protected.l r, g, b, a
  Protected sumR.f, sumG.f, sumB.f, sumA.f, sumW.f
  Protected dColor
  Protected wColor.f, wSpace.f, wTot.f
  
  Protected *nbuf.pixelarray_opt = *buf
  Protected *ntmp.pixelarray_opt = *FilterCtx\addr[10]
  
  Protected *LUT_Space.floatarray = *FilterCtx\addr[8]
  Protected *LUT_Color.floatarray = *FilterCtx\addr[9]
  Protected spaceStride = radius * 2 + 1
  
  Protected srcOffset, currentIdx, srcIdx
  Protected minY, maxY, minX, maxX
  
  ; Macro d'initialisation de tes variables globales de threads (thread_start, thread_stop)
  macro_calul_tread(h)
  
  ; --- Boucle principale ---
  For y = thread_start To thread_stop - 1
    srcOffset = y * w
    
    ; Bornes verticales sécurisées pour Y
    minY = y - radius : If minY < 0 : minY = 0 : EndIf
    maxY = y + radius : If maxY >= h : maxY = h - 1 : EndIf
    
    For x = 0 To w - 1
      currentIdx = srcOffset + x
      
      ; Accès direct par octet sans bit-shift
      b0 = *nbuf\p[currentIdx]\b[0]
      g0 = *nbuf\p[currentIdx]\b[1]
      r0 = *nbuf\p[currentIdx]\b[2]
      a0 = *nbuf\p[currentIdx]\b[3]
      
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : sumW = 0.0
      
      ; Bornes horizontales sécurisées pour X
      minX = x - radius : If minX < 0 : minX = 0 : EndIf
      maxX = x + radius : If maxX >= w : maxX = w - 1 : EndIf
      
      ; --- Boucles de voisinage ---
      For py = minY To maxY
        Protected pyOffset = py * w
        Protected spaceRowOffset = ((py - y) + radius) * spaceStride + (minX - x + radius)
        
        For px = minX To maxX
          srcIdx = pyOffset + px
          
          b = *nbuf\p[srcIdx]\b[0]
          g = *nbuf\p[srcIdx]\b[1]
          r = *nbuf\p[srcIdx]\b[2]
          a = *nbuf\p[srcIdx]\b[3]
          
          dColor = (r - r0)*(r - r0) + (g - g0)*(g - g0) + (b - b0)*(b - b0)
          
          wColor = *LUT_Color\f[dColor]
          wSpace = *LUT_Space\f[spaceRowOffset]
          spaceRowOffset + 1
          
          wTot = wColor * wSpace
          
          sumR + (r * wTot)
          sumG + (g * wTot)
          sumB + (b * wTot)
          sumA + (a * wTot)
          sumW + wTot
        Next
      Next
      
      If sumW > 0.0001
        Protected invSumW.f = 1.0 / sumW
        b0 = sumB * invSumW + 0.5
        g0 = sumG * invSumW + 0.5
        r0 = sumR * invSumW + 0.5
        a0 = sumA * invSumW + 0.5
      EndIf
      
      ; Écriture directe dans la zone allouée au niveau courant (*ntmp)
      *ntmp\p[currentIdx]\b[0] = b0
      *ntmp\p[currentIdx]\b[1] = g0
      *ntmp\p[currentIdx]\b[2] = r0
      *ntmp\p[currentIdx]\b[3] = a0
    Next
  Next
  
  ; --- CORRECTION CRITIQUE ---
  ; Le CopyMemory global est supprimé d'ici. Chaque thread s'arrête gentiment 
  ; après avoir écrit ses lignes dans *ntmp.
EndProcedure

; --- Downscale image (Box Filter nettoyé des flottants dans la boucle) ---
Procedure MultiScale_DownscaleImage(*src, srcW, srcH, *dst, dstW, dstH)
  Protected x, y, px, py
  Protected sumR, sumG, sumB, sumA, count
  Protected.f scaleX = srcW / dstW
  Protected.f scaleY = srcH / dstH
  Protected.l startY, endY
  Protected.f invCount
  
  Protected *nsrc.pixelarray_opt = *src
  Protected *ndst.pixelarray_opt = *dst
  
  ; --- OPTIMISATION 1 : Pré-calcul (LUT) des coordonnées X ---
  Dim LUT_startX.l(dstW - 1)
  Dim LUT_endX.l(dstW - 1)
  For x = 0 To dstW - 1
    LUT_startX(x) = Int(x * scaleX)
    LUT_endX(x)   = Int((x + 1) * scaleX) - 1
    If LUT_endX(x) >= srcW : LUT_endX(x) = srcW - 1 : EndIf
  Next
  
  ; --- Boucle principale ---
  For y = 0 To dstH - 1
    startY = Int(y * scaleY)
    endY   = Int((y + 1) * scaleY) - 1
    If endY >= srcH : endY = srcH - 1 : EndIf
    
    Protected dstOffset = y * dstW
    
    For x = 0 To dstW - 1
      ; Récupération instantanée des bornes X pré-calculées
      Protected startX = LUT_startX(x)
      Protected endX   = LUT_endX(x)
      
      sumR = 0 : sumG = 0 : sumB = 0 : sumA = 0
      
      ; --- OPTIMISATION 2 : Parcours optimisé des pixels sources ---
      For py = startY To endY
        ; pyOffset est calculé ici, il ne dépend pas de x !
        Protected pyOffset = py * srcW 
        
        For px = startX To endX
          Protected srcIdx = pyOffset + px
          
          ; Utilisation de la structure d'octets directe (\b) -> zéro décalage de bit
          sumB + *nsrc\p[srcIdx]\b[0]
          sumG + *nsrc\p[srcIdx]\b[1]
          sumR + *nsrc\p[srcIdx]\b[2]
          sumA + *nsrc\p[srcIdx]\b[3]
        Next
      Next
      
      ; Nombre total de pixels dans le bloc
      count = (endY - startY + 1) * (endX - startX + 1)
      
      ; --- OPTIMISATION 3 : Remplacement des divisions par multiplication ---
      If count > 0
        invCount = 1.0 / count
        
        Protected destIdx = dstOffset + x
        *ndst\p[destIdx]\b[0] = sumB * invCount
        *ndst\p[destIdx]\b[1] = sumG * invCount
        *ndst\p[destIdx]\b[2] = sumR * invCount
        *ndst\p[destIdx]\b[3] = sumA * invCount
      EndIf
    Next
  Next
EndProcedure

; --- Upscale image (Bilinear Nettoyé) ---
; --- Version corrigée et blindée de l'Upscale ---
Procedure MultiScale_UpscaleImage(*src, srcW, srcH, *dst, dstW, dstH)
  Protected x, y, x0, y0, x1, y1
  Protected.f sx, sy, fx, fy, fx1, fy1
  
  ; /!\ On déclare explicitement toutes nos variables de calcul en Flottants (.f)
  Protected.f a0, g0, b0, r0, a1, g1, b1, r1
  
  Protected scaleX.f = (srcW - 1) / dstW
  Protected scaleY.f = (srcH - 1) / dstH
  Protected srcWMinus1 = srcW - 1
  Protected srcHMinus1 = srcH - 1
  Protected *nsrc.pixelarray_opt = *src
  Protected *ndst.pixelarray_opt = *dst
  
  For y = 0 To dstH - 1
    sy = y * scaleY
    y0 = Int(sy)
    y1 = y0 + 1 : If y1 > srcHMinus1 : y1 = srcHMinus1 : EndIf
    fy = sy - y0
    fy1 = 1.0 - fy
    
    Protected y0Offset = y0 * srcW
    Protected y1Offset = y1 * srcW
    
    For x = 0 To dstW - 1
      sx = x * scaleX
      x0 = Int(sx)
      x1 = x0 + 1 : If x1 > srcWMinus1 : x1 = srcWMinus1 : EndIf
      fx = sx - x0
      fx1 = 1.0 - fx

      ; Plus besoin de variables c00, c01... On pointe directement les structures d'octets (\b[index])
      ; index 0 = Bleu, 1 = Vert, 2 = Rouge, 3 = Alpha (Format standard BGRA en mémoire Windows/Linux)
      
      ; --- Canal ALPHA (b[3]) ---
      a0 = *nsrc\p[y0Offset + x0]\b[3] * fx1 + *nsrc\p[y0Offset + x1]\b[3] * fx
      a1 = *nsrc\p[y1Offset + x0]\b[3] * fx1 + *nsrc\p[y1Offset + x1]\b[3] * fx
      Protected.l al = (a0 * fy1 + a1 * fy) + 0.5
      
      ; --- Canal ROUGE (b[2]) ---
      r0 = *nsrc\p[y0Offset + x0]\b[2] * fx1 + *nsrc\p[y0Offset + x1]\b[2] * fx
      r1 = *nsrc\p[y1Offset + x0]\b[2] * fx1 + *nsrc\p[y1Offset + x1]\b[2] * fx
      Protected.l rl = (r0 * fy1 + r1 * fy) + 0.5
      
      ; --- Canal VERT (b[1]) ---
      g0 = *nsrc\p[y0Offset + x0]\b[1] * fx1 + *nsrc\p[y0Offset + x1]\b[1] * fx
      g1 = *nsrc\p[y1Offset + x0]\b[1] * fx1 + *nsrc\p[y1Offset + x1]\b[1] * fx
      Protected.l gl = (g0 * fy1 + g1 * fy) + 0.5
      
      ; --- Canal BLEU (b[0]) ---
      b0 = *nsrc\p[y0Offset + x0]\b[0] * fx1 + *nsrc\p[y0Offset + x1]\b[0] * fx
      b1 = *nsrc\p[y1Offset + x0]\b[0] * fx1 + *nsrc\p[y1Offset + x1]\b[0] * fx
      Protected.l bl = (b0 * fy1 + b1 * fy) + 0.5
      
      ; Écriture directe des octets dans le pixel de destination
      Protected destIdx = y * dstW + x
      *ndst\p[destIdx]\b[3] = al
      *ndst\p[destIdx]\b[2] = rl
      *ndst\p[destIdx]\b[1] = gl
      *ndst\p[destIdx]\b[0] = bl
    Next
  Next
EndProcedure

Procedure MultiScaleBilateralBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected levels = \option[0]
    Protected radius = \option[1]
    Protected sigmaColor.f = \option[2]
    
    ; Clamp rapide
    If levels < 1 : levels = 1 : ElseIf levels > 5 : levels = 5 : EndIf
    If radius < 1 : radius = 1 : ElseIf radius > 16 : radius = 16 : EndIf
    If sigmaColor < 1 : sigmaColor = 1 : ElseIf sigmaColor > 100 : sigmaColor = 100 : EndIf
    
    Protected l, w, h, err, idx, effectiveRadius, t
    Protected *temp
    Protected.f alpha = 0.5, invAlpha = 0.5
    
    Dim levelW.i(levels - 1)
    Dim levelH.i(levels - 1)
    Dim pyramid.i(levels - 1)
    
    For l = 0 To levels - 1
      levelW(l) = lg >> l
      levelH(l) = ht >> l
      If levelW(l) < 1 : levelW(l) = 1 : EndIf
      If levelH(l) < 1 : levelH(l) = 1 : EndIf
    Next
    
    err = 0
    For l = 0 To levels - 1
      pyramid(l) = AllocateMemory(levelW(l) * levelH(l) * 4) 
      If Not pyramid(l) : err = 1 : EndIf
    Next
    
    If err = 1 
      For l = 0 To levels - 1 : If pyramid(l) : FreeMemory(pyramid(l)) : EndIf : Next 
      ProcedureReturn 
    EndIf
    
    *temp = AllocateMemory(lg * ht * 4) 
    If Not *temp : err = 1 : EndIf
    
    ; --- CORRECTION 1 : Utilisation de la variable locale sigmaColor valide ---
    Protected sigmaColor2.f = sigmaColor * sigmaColor
    Protected invSigmaColor2.f = -1.0 / sigmaColor2
    Protected radiusSq.f = radius * radius
    Protected invRadiusSq.f = -1.0 / radiusSq
    Protected spaceStride = radius * 2 + 1
    Protected dx, dy
    
    ; Génération des LUTs partagées
    Dim LUT_Space.f(spaceStride * spaceStride - 1)
    For dy = -radius To radius
      Protected dyIdx = (dy + radius) * spaceStride
      For dx = -radius To radius
        LUT_Space(dyIdx + (dx + radius)) = Exp((dx * dx + dy * dy) * invRadiusSq)
      Next
    Next
    
    Dim LUT_Color.f(195075)
    For l = 0 To 195075
      LUT_Color(l) = Exp(l * invSigmaColor2)
    Next
    
    ; --- CORRECTION 2 : Suppression de l'allocation erronée de *tmp ici ---
    
    If err = 0
      CopyMemory(\addr[0], pyramid(0), lg * ht * 4)
      
      ; 1. Downscale de la pyramide
      For l = 1 To levels - 1
        MultiScale_DownscaleImage(pyramid(l - 1), levelW(l - 1), levelH(l - 1), pyramid(l), levelW(l), levelH(l))
      Next
      
      ; 2. Floutage Bilatéral Multi-Threadé
      For l = 0 To levels - 1
        effectiveRadius = radius >> l
        If effectiveRadius < 1 : effectiveRadius = 1 : EndIf
        
        \addr[3] = pyramid(l)            
        \addr[4] = levelW(l)             
        \addr[5] = levelH(l)             
        \addr[6] = radius ; Référence de la LUT globale               
        \addr[7] = @sigmaColor           
        \addr[8] = @LUT_Space()          
        \addr[9] = @LUT_Color()          
        \addr[10] = AllocateMemory(levelW(l) * levelH(l) * 4)
        
        ; Lancement et attente des threads pour le niveau 'l'
        Create_MultiThread_MT(@MultiScale_BilateralBlurBuffer())
        
        ; --- AJOUT ICI ---
        ; Une fois que TOUS les threads ont terminé ce niveau, on rapatrie le 
        ; résultat de \addr[10] vers le buffer du niveau courant de la pyramide.
        CopyMemory(\addr[10], pyramid(l), levelW(l) * levelH(l) * 4)
        
        If \addr[10] 
          FreeMemory(\addr[10]) 
          \addr[10] = 0
        EndIf
      Next
      
      ; 3. Upscale et Blending (Inchangé, optimisé par structure de pixels)
      For l = levels - 1 To 1 Step -1
        MultiScale_UpscaleImage(pyramid(l), levelW(l), levelH(l), *temp, levelW(l - 1), levelH(l - 1))
        
        Protected sizeBytes = levelW(l - 1) * levelH(l - 1)
        Protected *pPyr.pixelarray_opt = pyramid(l - 1)
        Protected *pTmp.pixelarray_opt = *temp
        
        For idx = 0 To sizeBytes - 1
          *pPyr\p[idx]\b[0] = *pPyr\p[idx]\b[0] * alpha + *pTmp\p[idx]\b[0] * invAlpha + 0.5
          *pPyr\p[idx]\b[1] = *pPyr\p[idx]\b[1] * alpha + *pTmp\p[idx]\b[1] * invAlpha + 0.5
          *pPyr\p[idx]\b[2] = *pPyr\p[idx]\b[2] * alpha + *pTmp\p[idx]\b[2] * invAlpha + 0.5
          *pPyr\p[idx]\b[3] = *pPyr\p[idx]\b[3] * alpha + *pTmp\p[idx]\b[3] * invAlpha + 0.5
        Next
      Next
      
      CopyMemory(pyramid(0), \addr[1], lg * ht * 4)
    EndIf
    
    ; Nettoyage final
    For l = 0 To levels - 1 : If pyramid(l) : FreeMemory(pyramid(l)) : EndIf : Next
    If *temp : FreeMemory(*temp) : EndIf
  EndWith
EndProcedure

; --- Procédure principale renommée ---
Procedure MultiScaleBilateralBlurEx(*FilterCtx.FilterParams)
  Restore MultiScaleBilateralBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  ;Create_MultiThread_MT(@MultiScaleBilateralBlur_sp())
  MultiScaleBilateralBlur_sp(*FilterCtx)
  
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

; --- Nouvelle procédure principale (Appel) ---
Procedure MultiScaleBilateralBlur(source, cible, mask, levels, radius, sigmaColor)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = radius
    \option[2] = sigmaColor
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
  Data.i 1, 16, 2
  Data.s "Sigma couleur"        
  Data.i 5, 100, 25
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 354
; FirstLine = 314
; Folding = --
; EnableXP
; DPIAware