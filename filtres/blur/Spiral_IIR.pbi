Procedure SpiralBlur_IIR_MT_SSE4(*FilterCtx.FilterParams)
EndProcedure
Procedure SpiralBlur_IIR_MT_AVX(*FilterCtx.FilterParams)
EndProcedure
Procedure SpiralBlur_IIR_MT_AVX512(*FilterCtx.FilterParams)
EndProcedure


Procedure SpiralBlur_IIR_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected Radius = \option[0]
    Protected cx.f = (\option[1] * lg) / 100
    Protected cy.f = (\option[2] * ht) / 100
    Protected force.i = \option[3]
    Protected quality = \option[4]
    Protected direction = \option[6]
    Protected attenuation.f = \option[7] / 100.0
    Protected pos, i, j
    
    direction = (direction * 2) - 1
    
    Protected a.i, r.f, g.f, b.f
    Protected.i  r1 , g1 , b1
    Protected firstPixel
    Protected px.f, py.f
    Protected Alpha.f, inv_Alpha.f
    Protected maxRadiusInt.i
    
    Protected cx2.f = cx * cx
    Protected cy2.f = cy * cy
    Protected lgMinusCx.f = lg - cx
    Protected htMinusCy.f = ht - cy
    Protected lgMinusCx2.f = lgMinusCx * lgMinusCx
    Protected htMinusCy2.f = htMinusCy * htMinusCy
    
    maxRadiusInt = Max_4(Sqr(cx2 + cy2), Sqr(lgMinusCx2 + cy2), Sqr(cx2 + htMinusCy2), Sqr(lgMinusCx2 + htMinusCy2))
    Protected activeRadius.f = (\option[5] * maxRadiusInt) / 100
    
    Protected angleCount = 360 * quality
    Protected forceMod = (force * direction) % angleCount
    If forceMod < 0 : forceMod + angleCount : EndIf
    
    Alpha = Exp(-2.3 / (Radius + 1))
    inv_Alpha = 1 - Alpha
    
    Protected *source.Pixelarray = \addr[0]
    Protected *cible.Pixelarray  = \addr[1]
    Protected *cosTable.Float = \addr[2]
    Protected *sinTable.Float = \addr[3]
    
    Protected activeRadiusInt.i = activeRadius
    Protected invActiveRadius.f = 0.0
    If activeRadiusInt > 0
      invActiveRadius = 1.0 / activeRadiusInt
    EndIf
    
    ; Variables de travail alignées pour le SSE2
    Protected.f curveFactor, grayMask, invGrayMask
    Protected.l p_orig, p_final
    
    macro_calul_tread(angleCount)
    
    For i = thread_start To thread_stop
      r = 0 : g = 0 : b = 0
      firstPixel = #True
      
      Protected idx.i = i
      If idx >= angleCount : idx = idx % angleCount : EndIf
      
      Protected idxOffset.i = idx << 2
      Protected cosVal.f = PeekF(*cosTable + idxOffset)
      Protected sinVal.f = PeekF(*sinTable + idxOffset)
      
      For j = 0 To maxRadiusInt
        If j > 0
          idx + forceMod
          If idx >= angleCount : idx - angleCount : EndIf
          idxOffset = idx << 2
          cosVal = PeekF(*cosTable + idxOffset)
          sinVal = PeekF(*sinTable + idxOffset)
        EndIf
        
        Protected jFloat.f = j
        px = cx + jFloat * cosVal
        py = cy + jFloat * sinVal
        
        If px < 0 Or py < 0 Or px >= lg Or py >= ht : Continue : EndIf
        
        pos = (Int(py) * lg + Int(px))
        
        ; 1. Récupération du pixel d'origine 32-bits (ARGB)
        p_orig = *source\l[pos]
        a = (p_orig >> 24) & $FF
        
        If j < activeRadiusInt
          getrgb(*source\l[pos] , r1 , g1 , b1)
          
          ; Extraction des canaux d'origine pour l'IIR interne (Filtre de base)
          Protected r_orig.f = b1
          Protected g_orig.f = g1
          Protected b_orig.f = r1
          
          If firstPixel
            r = r_orig : g = g_orig : b = b_orig
            firstPixel = #False
          Else
            r = Alpha * r + inv_Alpha * r_orig
            g = Alpha * g + inv_Alpha * g_orig
            b = Alpha * b + inv_Alpha * b_orig
          EndIf
          
          ; 2. Calcul du masque au carré
          Protected distanceFactor.f = jFloat * invActiveRadius
          curveFactor = distanceFactor * distanceFactor
          grayMask = 1.0 - (curveFactor * attenuation)
          
          If grayMask < 0.0 : grayMask = 0.0 : ElseIf grayMask > 1.0 : grayMask = 1.0 : EndIf
          invGrayMask = 1.0 - grayMask
          
          ; 3. Vectorisation SSE2 pour le mélange (Blend) et la conversion 32-bits
          !movss xmm0, [p.v_grayMask]       ; xmm0 = [ 0 | 0 | 0 | grayMask ]
          !shufps xmm0, xmm0, 0             ; xmm0 = [ grayMask | grayMask | grayMask | grayMask ]
          
          !movss xmm1, [p.v_invGrayMask]    ; xmm1 = [ 0 | 0 | 0 | invGrayMask ]
          !shufps xmm1, xmm1, 0             ; xmm1 = [ invGrayMask | invGrayMask | invGrayMask | invGrayMask ]
          
          ; Charger le pixel flouté IIR (r, g, b) dans xmm2
          !movss xmm2, [p.v_r]
          !movss xmm3, [p.v_g]
          !unpcklps xmm2, xmm3              ; xmm2 = [ 0 | 0 | g | r ]
          !movss xmm4, [p.v_b]
          !movlhps xmm2, xmm4               ; xmm2 = [ 0 | b | g | r ]
          
 
          ; Extraire le pixel source d'origine (p_orig) directement depuis l'entier vers xmm5 (en flottants)
          !movd xmm5, [p.v_p_orig]          ; xmm5 = [ 0 | 0 | 0 | A R G B ] (octets)
          !pxor xmm6, xmm6
          !punpcklbw xmm5, xmm6             ; xmm5 = [ 0 A | 0 R | 0 G | 0 B ] (words 16 bits)
          !punpcklwd xmm5, xmm6             ; xmm5 = [ A | R | G | b ] (double words 32 bits)
          !cvtdq2ps xmm5, xmm5              ; xmm5 = [ A.f | R.f | G.f | B.f ] (floats)
          
          ; Application du mixage : (Flou * Mask) + (Origine * invMask)
          !mulps xmm2, xmm0                 ; xmm2 = Flou * grayMask
          !mulps xmm5, xmm1                 ; xmm5 = Origine * invGrayMask
          !addps xmm2, xmm5                 ; xmm2 = Résultat final en Float
          
          ; Conversion Float -> Entier 32-bits avec troncature (clamping automatique implicite)
          !cvtps2dq xmm2, xmm2              ; xmm2 = [ A_int | R_int | G_int | B_int ]
          !packssdw xmm2, xmm2              ; xmm2 = [ 0 | 0 | A R | G B ] (16 bits signed)
          !packuswb xmm2, xmm2              ; xmm2 = [ 0 | 0 | 0 | A R G B ] (8 bits unsigned clamped 0-255)
          !movd [p.v_p_final], xmm2         ; p_final = 32-bit ARGB packed
          
          ; Réinjection de la couche Alpha originale (pour éviter qu'elle ait subi le mixage)
          *cible\l[pos] = (a << 24) | (p_final & $00FFFFFF)
          
        Else
          *cible\l[pos] = p_orig
        EndIf
        
      Next
    Next
  EndWith
EndProcedure

Procedure SpiralBlur_IIR_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected Radius = \option[0]
    Protected cx.f = (\option[1] * lg) / 100
    Protected cy.f = (\option[2] * ht) / 100
    Protected force.i = \option[3]
    Protected quality = \option[4]
    Protected direction = \option[6]
    Protected attenuation.f = \option[7] / 100.0 ; Option 7 convertie en facteur (0.0 à 1.0)
    Protected pos, i, j
    
    ; Précalcul direction
    direction = (direction * 2) - 1
    
    Protected a, r.f, g.f, b.f
    Protected r1, g1, b1
    Protected r_orig, g_orig, b_orig
    Protected firstPixel
    Protected px.f, py.f
    Protected Alpha.f, inv_Alpha.f
    Protected maxRadiusInt.i
    
    ; Optimisation : calcul des carrés une seule fois
    Protected cx2.f = cx * cx
    Protected cy2.f = cy * cy
    Protected lgMinusCx.f = lg - cx
    Protected htMinusCy.f = ht - cy
    Protected lgMinusCx2.f = lgMinusCx * lgMinusCx
    Protected htMinusCy2.f = htMinusCy * htMinusCy
    
    maxRadiusInt = Max_4(Sqr(cx2 + cy2), Sqr(lgMinusCx2 + cy2), Sqr(cx2 + htMinusCy2), Sqr(lgMinusCx2 + htMinusCy2))
    Protected activeRadius.f = (\option[5] * maxRadiusInt) / 100
    
    Protected angleCount = 360 * quality
    Debug force
    Debug direction
    Debug quality
    Protected forceMod = (force * direction) % angleCount
    If forceMod < 0 : forceMod + angleCount : EndIf
    
    ; Précalcul Alpha
    Alpha = Exp(-2.3 / (Radius + 1))
    inv_Alpha = 1 - Alpha
    
    Protected *source.Pixelarray = \addr[0]
    Protected *cible.Pixelarray  = \addr[1]
    
    ; Pointeurs vers les buffers pré-alloués
    Protected *cosTable.Float = \addr[2]
    Protected *sinTable.Float = \addr[3]
    
    ; Précalculs pour l'accès mémoire
    Protected lgShift2.i = lg << 2
    Protected activeRadiusInt.i = activeRadius
    
    Protected invActiveRadius.f = 0.0
    If activeRadiusInt > 0
      invActiveRadius = 1.0 / activeRadiusInt
    EndIf
    
    macro_calul_tread(angleCount)
    
    For i = thread_start To thread_stop
      r = 0 : g = 0 : b = 0
      firstPixel = #True
      
      ; idx normalisé une seule fois
      Protected idx.i = i
      If idx >= angleCount
        idx = idx % angleCount
      EndIf
      
      ; Précalcul des offsets cosinus/sinus
      Protected idxOffset.i = idx << 2
      Protected cosVal.f = PeekF(*cosTable + idxOffset)
      Protected sinVal.f = PeekF(*sinTable + idxOffset)
      
      For j = 0 To maxRadiusInt
        ; Mise à jour de l'angle avec la force
        If j > 0
          idx + forceMod
          If idx >= angleCount
            idx - angleCount
          EndIf
          idxOffset = idx << 2
          cosVal = PeekF(*cosTable + idxOffset)
          sinVal = PeekF(*sinTable + idxOffset)
        EndIf
        
        ; Calcul de la position
        Protected jFloat.f = j
        px = cx + jFloat * cosVal
        py = cy + jFloat * sinVal
        
        ; Test de limites
        If px < 0 Or py < 0 Or px >= lg Or py >= ht
          Continue
        EndIf
        
        Protected ix.i = Int(px)
        Protected iy.i = Int(py)
        
        pos = (iy * lg + ix)
        
        ; 1. ON LIT LE PIXEL D'ORIGINE SANS FILTRE
        getargb(*source\l[pos] , a , r_orig , g_orig , b_orig)
        
        ; 2. ON CALCULE LE FLOU IIR NORMAL (EN INTERNE)
        If j < activeRadiusInt
          If firstPixel
            r = r_orig
            g = g_orig
            b = b_orig
            firstPixel = #False
          Else
            r = Alpha * r + inv_Alpha * r_orig
            g = Alpha * g + inv_Alpha * g_orig
            b = Alpha * b + inv_Alpha * b_orig
          EndIf
          
          Protected distanceFactor.f = jFloat * invActiveRadius
          Protected curveFactor.f = distanceFactor * distanceFactor
          Protected grayMask.f = 1.0 - (curveFactor * attenuation)
          
          ; Sécurité d'encadrement (Clamping du facteur de masque)
          If grayMask < 0.0 : grayMask = 0.0 : EndIf
          If grayMask > 1.0 : grayMask = 1.0 : EndIf
          
          ; Mixage final simulant le masque de fusion
          r1 = (r * grayMask) + (r_orig * (1.0 - grayMask))
          g1 = (g * grayMask) + (g_orig * (1.0 - grayMask))
          b1 = (b * grayMask) + (b_orig * (1.0 - grayMask))
          
        Else
          ; Hors du rayon actif : l'image reste intacte
          r1 = r_orig
          g1 = g_orig
          b1 = b_orig
        EndIf
        
        ; Clamping
        clamp_rgb(r1 , g1 , b1)
        
        ; Écriture directe (sans toucher à la vraie couche alpha 'a')
        *cible\l[pos] = (a << 24) | (r1 << 16) | (g1 << 8) | b1
      Next
    Next
  EndWith
EndProcedure


Procedure SpiralBlur_IIREx(*FilterCtx.FilterParams)
  
  Restore SpiralBlur_IIR_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  
  With *FilterCtx
    Protected i, angle.f
    Protected quality = \option[4]
    Protected inv_quality.f = 1.0 / quality
    Protected angleCount = 360 * quality
    
    ; Allocation optimisée avec mémoire alignée
    Dim cosTable.f(angleCount)
    Dim sinTable.f(angleCount) 
    
    ; Précalcul optimisé des tables trigonométriques
    For i = 0 To angleCount - 1
      angle = Radian(i * inv_quality)
      cosTable(i) = Cos(angle)
      sinTable(i) = Sin(angle)
    Next
    
    \addr[2] = @cosTable()
    \addr[3] = @sinTable()
    
    ;Create_MultiThread_MT(@SpiralBlur_IIR_MT())
    selet_and_start_programme(SpiralBlur_IIR_MT)
    mask_update(*FilterCtx.FilterParams , last_data)
    
    FreeArray(cosTable())
    FreeArray(sinTable())
  EndWith
EndProcedure

Procedure SpiralBlur_IIR(source , cible , mask , rayon , posx , posy , force , qualite , ra , sens, attenuation)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = posx
    \option[2] = posy
    \option[3] = force
    \option[4] = qualite
    \option[5] = ra
    \option[6] = sens
    \option[7] = attenuation
  EndWith
  SpiralBlur_IIREx(FilterCtx.FilterParams)
EndProcedure


DataSection
  SpiralBlur_IIR_data:
  Data.s "Spiral_IIR"
  Data.s "appliquer un filtre de flou en spirale"
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Rayon du filtre"       
  Data.i 1,99,50
  Data.s "Pos X"   
  Data.i 0,100,50
  Data.s "Pos Y"        
  Data.i 0,100,50
  Data.s "Force de rotation"  
  Data.i 1,100,10
  Data.s "Qualité" 
  Data.i 16,64,32
  Data.s "Rayon actif"   
  Data.i 1,100,100
  Data.s "sens"  
  Data.i 0,1,0
  Data.s "Atténuation périphérique" ; <-- Libellé Option 7
  Data.i 0,100,50                   ; <-- Min 0, Max 100, Par défaut 50%
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 135
; FirstLine = 104
; Folding = --
; EnableXP
; DPIAware