;==============================================================================
; HDR ARTISTIC EFFECT
;==============================================================================

Procedure hdr_artistic_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    ; --- Dimensions ---
    Protected w = \image_lg[0]
    Protected h = \image_ht[0] ; Correction appliquée selon tes instructions
    
    ; --- Paramètres (Conversion float pour calculs) ---
    Protected strength.f          = \option[0] * 0.01
    Protected toneCompression.f   = \option[1] * 0.01
    Protected haloRadius          = \option[2]
    Protected haloIntensity.f     = \option[3] * 0.01
    Protected saturationBoost.f   = \option[4] * 0.01
    Protected detailEnhance.f     = \option[5] * 0.01
    Protected localEqualization.f = \option[6] * 0.01
    
    If strength <= 0.0 : strength = 0.01 : EndIf
    If haloRadius < 1 : haloRadius = 1 : EndIf
    If haloRadius > 10 : haloRadius = 10 : EndIf

    ; --- Variables de boucle et calcul ---
    Protected x, y, dx, dy, i, count
    Protected a, r, g, b, rC, gC, bC, valR, valG, valB
    Protected sumR.f, sumG.f, sumB.f, avgR.f, avgG.f, avgB.f
    Protected minLum.f, maxLum.f, localLum.f, luminance.f
    Protected compressedLum.f, edgeMagnitude.f, haloEffect.f
    Protected sobelX.f, sobelY.f
    Protected *src.Pixel32, *dst.Pixel32
    
    ; --- Matrice Sobel ---
    Dim kX.f(2, 2) : Dim kY.f(2, 2)
    kX(0,0)=-1: kX(1,0)=0: kX(2,0)=1: kX(0,1)=-2: kX(1,1)=0: kX(2,1)=2: kX(0,2)=-1: kX(1,2)=0: kX(2,2)=1
    kY(0,0)=-1: kY(1,0)=-2: kY(2,0)=-1: kY(0,1)=0: kY(1,1)=0: kY(2,1)=0: kY(0,2)=1: kY(1,2)=2: kY(2,2)=1

    ; --- Multithreading ---
    macro_calul_tread(h)
    Protected startY = thread_start
    Protected endY   = thread_stop - 1
    
    ; Protection bordures
    Protected margin = haloRadius + 1
    If startY < margin : startY = margin : EndIf
    If endY > h - margin : endY = h - margin : EndIf

    For y = startY To endY
      For x = margin To w - margin - 1
        
        ; 1. Pixel central
        *src = \addr[0] + ((y * w + x) << 2)
        getargb(*src\l, a, rC, gC, bC)
        luminance = rC * 0.299 + gC * 0.587 + bC * 0.114
        
        ; 2. Analyse voisinage (Tone Mapping Local)
        sumR = 0: sumG = 0: sumB = 0: minLum = 255: maxLum = 0: count = 0
        For dy = -haloRadius To haloRadius
          For dx = -haloRadius To haloRadius
            *src = \addr[0] + (((y + dy) * w + (x + dx)) << 2)
            getargb(*src\l, a, valR, valG, valB)
            localLum = valR * 0.299 + valG * 0.587 + valB * 0.114
            sumR + valR : sumG + valG : sumB + valB
            If localLum < minLum : minLum = localLum : EndIf
            If localLum > maxLum : maxLum = localLum : EndIf
            count + 1
          Next
        Next
        avgR = sumR / count : avgG = sumG / count : avgB = sumB / count
        Protected dynamicRange.f = maxLum - minLum
        If dynamicRange < 1.0 : dynamicRange = 1.0 : EndIf
        
        ; 3. Tone Mapping Logarithmique
        Protected normLum.f = (luminance - minLum) / dynamicRange
        If normLum < 0.0 : normLum = 0.0 : ElseIf normLum > 1.0 : normLum = 1.0 : EndIf
        Protected cFact.f = toneCompression * 10.0
        compressedLum = Log(1.0 + normLum * cFact) / Log(1.0 + cFact)
        compressedLum = minLum + compressedLum * dynamicRange
        compressedLum + (128.0 - compressedLum) * localEqualization * 0.3
        
        ; 4. Détection de contours (Sobel)
        sobelX = 0 : sobelY = 0
        For dy = -1 To 1
          For dx = -1 To 1
            *src = \addr[0] + (((y + dy) * w + (x + dx)) << 2)
            getargb(*src\l, a, valR, valG, valB)
            localLum = valR * 0.299 + valG * 0.587 + valB * 0.114
            sobelX + localLum * kX(dx + 1, dy + 1)
            sobelY + localLum * kY(dx + 1, dy + 1)
          Next
        Next
        edgeMagnitude = Sqr(sobelX * sobelX + sobelY * sobelY)
        Protected edgeStrength.f = edgeMagnitude / 1000.0
        If edgeStrength > 1.0 : edgeStrength = 1.0 : EndIf
        
        ; 5. Calcul du Halo
        haloEffect = 0 : Protected glowR.f = 0, glowG.f = 0, glowB.f = 0, gCount = 0
        If haloIntensity > 0.0 And edgeStrength > 0.1
          For dy = -haloRadius To haloRadius
            For dx = -haloRadius To haloRadius
              Protected dist.f = Sqr(dx * dx + dy * dy)
              If dist <= haloRadius
                *src = \addr[0] + (((y + dy) * w + (x + dx)) << 2)
                getargb(*src\l, a, valR, valG, valB)
                Protected weight.f = 1.0 - (dist / haloRadius)
                weight * weight
                glowR + valR * weight : glowG + valG * weight : glowB + valB * weight
                gCount + 1
              EndIf
            Next
          Next
          If gCount > 0
            glowR / gCount : glowG / gCount : glowB / gCount
            haloEffect = edgeStrength * haloIntensity
          EndIf
        EndIf
        
        ; 6. Application Couleurs & Détails
        Protected lumRatio.f = compressedLum / luminance
        If luminance < 1.0 : lumRatio = 1.0 : EndIf
        Protected nR.f = rC * lumRatio : Protected nG.f = gC * lumRatio : Protected nB.f = bC * lumRatio
        
        If detailEnhance > 0.0
          nR + (nR - avgR) * detailEnhance
          nG + (nG - avgG) * detailEnhance
          nB + (nB - avgB) * detailEnhance
        EndIf
        
        If haloEffect > 0.0
          nR + (glowR - nR) * haloEffect * 0.5
          nG + (glowG - nG) * haloEffect * 0.5
          nB + (glowB - nB) * haloEffect * 0.5
        EndIf
        
        ; 7. Saturation & Mix Final
        Protected nLum.f = nR * 0.299 + nG * 0.587 + nB * 0.114
        nR = nLum + (nR - nLum) * saturationBoost
        nG = nLum + (nG - nLum) * saturationBoost
        nB = nLum + (nB - nLum) * saturationBoost
        
        r = Int(rC + (nR - rC) * strength)
        g = Int(gC + (nG - gC) * strength)
        b = Int(bC + (nB - bC) * strength)
        
        clamp_rgb(r, g, b)
        *dst = \addr[1] + ((y * w + x) << 2)
        *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      Next
    Next
    FreeArray(kX()) : FreeArray(kY())
  EndWith
EndProcedure

Procedure hdr_artisticEx(*FilterCtx.FilterParams)
  Restore HDR_Artistic_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@hdr_artistic_MT())
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure hdr_artistic(source, cible, mask, strength, tone, halo_r, halo_i, sat, details, equal)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = strength : \option[1] = tone : \option[2] = halo_r : \option[3] = halo_i
    \option[4] = sat : \option[5] = details : \option[6] = equal
  EndWith
  hdr_artisticEx(FilterCtx)
EndProcedure

DataSection
  HDR_Artistic_Data:
  Data.s "HDR Artistic"
  Data.s "Effet HDR artistique avec tone mapping local et halos lumineux"
  Data.i #FilterType_Artistic
  Data.i #Artistic_Light
  
  Data.s "Intensité" : Data.i 1, 100, 80
  Data.s "Tone mapping" : Data.i 0, 200, 120
  Data.s "Rayon halo" : Data.i 1, 10, 4
  Data.s "Intensité halo" : Data.i 0, 200, 80
  Data.s "Saturation" : Data.i 0, 300, 150
  Data.s "Détails" : Data.i 0, 200, 100
  Data.s "Égalisation locale" : Data.i 0, 100, 40
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 170
; FirstLine = 138
; Folding = -
; EnableXP
; DPIAware