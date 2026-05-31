
Procedure Diffuse_MT(*p.parametre)
  Protected i, x, y, px, py, a, b, var, alpha
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected opt = *p\option[0]
  Protected totalPixels = lg * ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected *mask = *p\mask

  ; Clamp de l'option d'intensité
  Clamp(opt, 0, 256)
  ; Calcul des bornes pour la gestion du multithreading
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    ; Calcul des coordonnées du pixel courant
    y = i / lg
    x = i % lg
    ; Génération d'un décalage aléatoire dans un carré centré sur le pixel
    a = Random(opt) - (opt >> 1)
    b = Random(opt) - (opt >> 1)
    px = x + a
    py = y + b
    ; Clamp pour ne pas sortir des limites de l'image
    Clamp(px, 0, lg - 1)
    Clamp(py, 0, ht - 1)
    ; Récupération de la couleur source du pixel décalé
    var = PeekL(*p\addr[0] + ((py * lg + px) << 2))
    ; Ecriture de la couleur dans la cible
    PokeL(*p\addr[1] + (i << 2), var)
  Next
EndProcedure

; Procédure principale pour lancer l'effet de diffusion avec multithreading et masque alpha
Procedure Diffuse(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_FX
    param\name = "Diffuse"
    param\remarque = ""
    param\info[0] = "intensité"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 256 : param\info_data(0,2) = 1
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2 : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Diffuse_MT() , 1)
EndProcedure

;--------------

Procedure DilateEffect_MT(*p.parametre)
  Protected *src = *p\addr[0]
  Protected *dst = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht

  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  Protected x, y, nx, ny
  Protected srcOffset, dstOffset
  Protected maxR, maxG, maxB, maxA
  Protected r, g, b, a
  Protected pix

  For y = startY To stopY
    For x = 0 To lg - 1
      maxR = 0
      maxG = 0
      maxB = 0
      maxA = 0

      ; Parcourir voisins 3x3
      For ny = y - 1 To y + 1
        If ny < 0 Or ny >= ht : Continue : EndIf; hors limites en Y
        For nx = x - 1 To x + 1
          If nx < 0 Or nx >= lg : Continue : EndIf ; hors limites en X

          srcOffset = (ny * lg + nx) * 4
          pix = PeekL(*src + srcOffset)
          getargb(pix , a , r , g , b)

          If r > maxR : maxR = r : EndIf
          If g > maxG : maxG = g : EndIf
          If b > maxB : maxB = b : EndIf
          If a > maxA : maxA = a : EndIf
        Next
      Next

      dstOffset = (y * lg + x) * 4
      PokeL(*dst + dstOffset, (a<<24) | (r<<16) | (g<<8) | b)
    Next
  Next
EndProcedure


Procedure Dilate(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_FX
    param\name = "Dilate"
    param\remarque = "Dilat. morph. 3x3"
    param\info[0] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 2 : param\info_data(0,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@DilateEffect_MT() , 0)
EndProcedure


;--------------


Procedure DisplacementMap_MT(*p.parametre)
  Protected *src = *p\addr[0]
  Protected *dst = *p\addr[1]
  Protected *disp = *p\source2
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected intensity.f = *p\option[0] * 0.5
  Protected offsetX.f = ((*p\option[1] - 100) * lg) / 100
  Protected offsetY.f = ((*p\option[2] - 100) * ht) / 100
  Protected wrapMode = *p\option[3]  ; 0 = clamp, 1 = wrap (modulo)

  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  Protected x, y
  Protected srcX.f, srcY.f
  Protected dispXPos.f, dispYPos.f
  Protected offsetDst, offsetDisp

  For y = startY To stopY
    For x = 0 To lg - 1
      dispXPos = x + offsetX
      dispYPos = y + offsetY
      
      If wrapMode = 0
        Clamp(dispXPos, 0, lg - 1)
        Clamp(dispYPos, 0, ht - 1)
      Else
        ; Wrap autour avec modulo
        dispXPos =  Mod(dispXPos , lg)
        If dispXPos < 0 : dispXPos + lg : EndIf
        dispYPos =  Mod(dispYPos , ht)
        If dispYPos < 0 : dispYPos + ht : EndIf
      EndIf

      offsetDisp = (Int(dispYPos) * lg + Int(dispXPos)) * 4
      Protected dispColor = PeekL(*disp + offsetDisp)

      ; Utiliser rouge et vert comme vecteurs de déplacement
      Protected dispX = ((dispColor >> 16) & $FF) - 128 ; rouge
      Protected dispY = ((dispColor >> 8) & $FF) - 128 ; vert

      srcX = x + (dispX / 128.0) * intensity
      srcY = y + (dispY / 128.0) * intensity

      Clamp(srcX, 0, (lg - 1))
      Clamp(srcY, 0, (ht - 1))

      offsetDst = (y * lg + x) * 4
      PokeL(*dst + offsetDst, BilinearSample(*src, lg, ht, srcX, srcY))
    Next
  Next
EndProcedure

Procedure DisplacementMap(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_FX
    param\name = "DisplacementMap"
    param\remarque = "Nécessite 2 images : source + displacement"
    param\info[0] = "intensity"
    param\info[1] = "offset X"
    param\info[2] = "offset Y"
    param\info[3] = "Wrap mode"
    param\info[4] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 500 : param\info_data(0,2) = 1
    param\info_data(1,0) = 0 : param\info_data(1,1) = 200 : param\info_data(1,2) = 100
    param\info_data(2,0) = 0 : param\info_data(2,1) = 200 : param\info_data(2,2) = 100
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  If *param\source2 = 0 : ProcedureReturn : EndIf
  
  filter_start(@DisplacementMap_MT() , 4)
EndProcedure

;--------------

Procedure Emboss_bump_MT(*p.parametre)
  Protected x, y, pos, j, i
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected a, r, g, b
  Protected lValue
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected Dim l(2,2)  ; 3x3 pour le gradient

  ; === Paramètres de lumière ===
  Protected azimuth.f   = *p\option[0]   ; 0..360°
  Protected elevation.f = *p\option[1] * 90 / 100  ; 0..90°
  If elevation < 1 : elevation = 1 : EndIf
  Protected intensity.f = (*p\option[2] + 50) / 100.0
  Protected light_mix   = *p\option[3]
  Protected bn     = *p\option[5]
  Protected mix_strength.f = *p\option[4] / 100
  Protected invert   = *p\option[6]
  
  ; --- Calcul vecteur lumière ---
  Protected lx.f, ly.f, lz.f
  lx = Cos(Radian(azimuth)) * Sin(Radian(elevation))
  ly = Sin(Radian(azimuth)) * Sin(Radian(elevation))
  lz = Cos(Radian(elevation))
  ; Normalisation correcte (affectation)
  Protected llen.f = Sqr(lx*lx + ly*ly + lz*lz)
  If llen <> 0.0
    lx = lx / llen : ly = ly / llen : lz = lz / llen
  EndIf

  ; --- Calcul plage verticale pour le thread ---
  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * ht) / *p\thread_max
  If endY > ht : endY = ht : EndIf
  Protected readStart = startY
  Protected readEnd   = endY
  If readStart < 1 : readStart = 1 : EndIf
  If readEnd > ht-2 : readEnd = ht-2 : EndIf

  For y = readStart To readEnd
    For x = 1 To lg-2
      pos = *p\addr[0] + ((y * lg + x) << 2)
      ; --- Lecture des 3x3 voisins ---
      For j = -1 To 1
        For i = -1 To 1
          *srcPixel = pos + ((j * lg + i) << 2)
          GetARGB(*srcPixel\l, a, r, g, b)
          l(i+1, j+1) = (r * 1225 + g * 2405 + b * 466) >> 12
        Next i
      Next j
      ; --- Calcul gradient ---
      Protected gx.f, gy.f, gz.f
      gx = ((l(2,0) + 2*l(2,1) + l(2,2)) - (l(0,0) + 2*l(0,1) + l(0,2)))
      gy = ((l(0,2) + 2*l(1,2) + l(2,2)) - (l(0,0) + 2*l(1,0) + l(2,0)))
      gz = 1.0  ; normalisation approximative

      ; --- Produit scalaire lumière × gradient ---
      lValue = 128 + intensity * (gx * lx + gy * ly + gz * lz)
      If bn
        lValue = lValue - 128
        If invert
          lValue = 255 - lValue
        EndIf 
      EndIf  
      lValue = Pow(lValue/255.0, 1.2) * 255
      Clamp(lValue, 0, 255)
      If y >= startY And y < endY
        *dstPixel = *p\addr[1] + ((y * lg + x) << 2)
        ; ---- Mélange lumière / couleur d'origine ----
        If light_mix
          ; récupération de la couleur d'origine
          GetARGB(*srcPixel\l, a, r, g, b)
          ; mélange (tu peux ajuster le facteur de mixage 0.5 → 0.2..0.8)
          r = r * (1.0 - mix_strength) + lValue * mix_strength
          g = g * (1.0 - mix_strength) + lValue * mix_strength
          b = b * (1.0 - mix_strength) + lValue * mix_strength
          
          Clamp_rgb(r, g , b)
          *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
        Else
          ; rendu emboss pur en niveaux de gris
          *dstPixel\l = (a << 24) | lValue * $10101
        EndIf
      EndIf
    Next
  Next
EndProcedure

    
    ;For y=0 To ht
    ;For x=0 To lg
        ;k1=0
        ;For yy=-val To 0
        ;For xx=-val To 0
            ;If ((x+xx)>=0 And (y+yy)>=0) Then
                ;rgb=tab(x+xx,y+yy)
                ;r=((rgb And $ff0000)Shr 16)
                ;g=((rgb And $00ff00)Shr 8)
                ;b=((rgb And $0000ff))
                ;c=(tabr(r)+tabg(g)+tabb(b))Shr 10
                ;If (xx+yy)=0 Then
                    ;k1=(c-(k1/k2)+255)Shr 1
                ;Else
                    ;k1=k1+c
                ;EndIf
            ;EndIf
        ;Next
        ;Next
            ;WritePixelFast(x,y,taba(k1),ImageBuffer(img))
    ;Next
  ;Next
  
; ----------------------------------------------------------------------------------
; Procédure principale d'effet Emboss (relief directionnel)

Procedure Emboss_bump(*param.parametre)
  If *param\info_active
    *param\typ = #Filter_Type_FX
    *param\name = "Emboss"
    *param\remarque = "Emboss (relief directionnel niveaux de gris)"
    *param\info[0] = "angle"
    *param\info[1] = "inclinaison"
    *param\info[2] = "intensity"
    *param\info[3] = "Mix_image"
    *param\info[4] = "mix_alpha"
    *param\info[5] = "Blanc/noir"
    *param\info[6] = "invert"
    *param\info[7] = "masque"
    *param\info_data(0,0) = 0    : *param\info_data(0,1) = 360  : *param\info_data(0,2) = 50
    *param\info_data(1,0) = 1    : *param\info_data(1,1) = 100  : *param\info_data(1,2) = 25
    *param\info_data(2,0) = 1    : *param\info_data(2,1) = 500  : *param\info_data(2,2) = 250
    *param\info_data(3,0) = 0    : *param\info_data(3,1) = 1    : *param\info_data(3,2) = 0
    *param\info_data(4,0) = 0    : *param\info_data(4,1) = 100  : *param\info_data(4,2) = 50
    *param\info_data(5,0) = 0    : *param\info_data(5,1) = 1    : *param\info_data(5,2) = 0
    *param\info_data(6,0) = 0    : *param\info_data(6,1) = 1    : *param\info_data(6,2) = 0
    *param\info_data(7,0) = 0    : *param\info_data(7,1) = 2    : *param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected *tempo
  If *param\source =  *param\cible
    *tempo = AllocateMemory(*param\lg * *param\ht * 4)
    If *tempo = 0 : ProcedureReturn : EndIf
    CopyMemory(*param\cible , *tempo , *param\lg * *param\ht * 4)
    *param\addr[0] = *tempo
  Else
    *param\addr[0] = *param\source
  EndIf
  *param\addr[1] = *param\cible
  MultiThread_MT(@Emboss_bump_MT())
  If *param\mask And *param\option[7] : *param\mask_type = *param\option[7] - 1 : MultiThread_MT(@_mask()) : EndIf
  If *tempo : FreeMemory(*tempo) : EndIf
  
EndProcedure

;--------------



Procedure FlowLiquify_MT(*p.parametre)
  Protected *src = *p\addr[0]
  Protected *dst = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected intensity.f = *p\option[0] ; Amplitude max déplacement
  Protected scale.f = *p\option[1] / 100 ; Echelle du bruit
  
  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf
  
  Protected x, y
  Protected srcX.f, srcY.f
  Protected offsetDst
  
  For y = startY To stopY
    For x = 0 To lg - 1
      Protected angle.f = PerlinNoise(x * scale, y * scale) * 2.0 * #PI  ; angle entre 0 et 2PI
      Protected vx.f = Cos(angle) * intensity
      Protected vy.f = Sin(angle) * intensity
      ;Protected vx.f = (PerlinFractal(x * scale, y * scale) - 0.5) * 2.0 * intensity
      ;Protected vy.f = (PerlinFractal((x + 1000) * scale, (y + 1000) * scale) - 0.5) * 2.0 * intensity
      srcX = x + vx
      srcY = y + vy
      Clamp(srcX, 0, (lg - 1))
      Clamp(srcY, 0, (ht - 1))
      
      offsetDst = (y * lg + x) * 4
      PokeL(*dst + offsetDst, BilinearSample(*src, lg, ht, srcX, srcY))
    Next
  Next
EndProcedure


Procedure FlowLiquify(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_FX
    param\name = "FlowLiquify"
    param\remarque = "Effet déformation fluide/liquide avec bruit 2D"
    param\info[0] = "Intensité"
    param\info[1] = "Echelle bruit"
    param\info[2] = "gradients"
    param\info[3] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 50 : param\info_data(0,2) = 5
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 10
    param\info_data(2,0) = 0 : param\info_data(2,1) = 5 : param\info_data(2,2) = 0
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2 : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  ; filtre / perlin noise
  SetupGradients(param\option[2])
  filter_start(@FlowLiquify_MT() , 3)
EndProcedure

;--------------

Procedure GlitchEffect_MT(*p.parametre)
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected intensity = *p\option[0] ; [0–100] % déplacement max
  Protected sliceHeight = 4 + Random(8)

  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  Protected j, x, x1 , x2 , y = startY
  Protected srcX, srcOffset, dstOffset
  Protected pix, r, g, b, a, noiseLevel

  While y <= stopY
    If y % sliceHeight = 0
      Protected offsetX = Random((lg * intensity) / 100) - (lg * intensity) / 200
      If offsetX = 0 : offsetX = 1 : EndIf
      
      ; --- Glitch horizontal décalé
      For j = 0 To sliceHeight - 1
        If y + j >= ht : Break : EndIf
        For x = 0 To lg - 1
          srcX = x + offsetX
          If srcX < 0 : srcX = 0 : ElseIf srcX >= lg : srcX = lg - 1 : EndIf
          srcOffset = ((y + j) * lg + srcX) * 4
          dstOffset = ((y + j) * lg + x) * 4
          PokeL(*cible + dstOffset, PeekL(*source + srcOffset))
        Next
      Next
      
      ; --- Ajout ligne horizontale bruitée
      If y + sliceHeight < ht
        Protected lineY = y + sliceHeight
        noiseLevel = Random(32) + 16 ; Niveau de bruit (plus = plus intense)
        
        For x = 0 To lg - 1
          srcOffset = (lineY * lg + x) * 4
          pix = PeekL(*source + srcOffset)
          a = (pix >> 24) & $FF
          
          x1 = x + 2
          x2 = x - 2
          Clamp(x1, 0, (lg - 1))
          Clamp(x2, 0, (lg - 1))
          r = PeekA(*source + ((lineY * lg + x1) * 4 + 1)) ; R décalé
          g = PeekA(*source + ((lineY * lg + x2) * 4 + 2)) ; G décalé
          b = PeekA(*source + ((lineY * lg + x) * 4 + 3))                       ; B normal
          
          ; Ajouter un peu de bruit si tu veux
          r + Random(noiseLevel) - noiseLevel / 2 : Clamp(r, 0, 255)
          g + Random(noiseLevel) - noiseLevel / 2 : Clamp(g, 0, 255)
          b + Random(noiseLevel) - noiseLevel / 2 : Clamp(b, 0, 255)
          
          PokeL(*cible + srcOffset, RGBA(r, g, b, a))
        Next
      EndIf
      
      y + sliceHeight + 1 ; on saute après la ligne bruitée
    Else
      y + 1
    EndIf
  Wend
EndProcedure

Procedure Glitch(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_FX
    param\name = "GlitchEffect"
    param\remarque = "Effet Glitch Numérique"
    param\info[0] = "Intensité"
    param\info[1] = "Niveau de bruit"
    param\info[2] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 30
    param\info_data(1,0) = 0 : param\info_data(1,1) = 128 : param\info_data(1,2) = 32
    param\info_data(2,0) = 0 : param\info_data(2,1) = 2 : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@GlitchEffect_MT() , 2)
EndProcedure

;--------------

Procedure HexMosaic_MT(*p.parametre)
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected hexSize = *p\option[0]
  If hexSize < 4 : hexSize = 8 : EndIf

  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  Protected hexWidth  = 2 * hexSize
  Protected hexHeight = Int(Sqr(3) * hexSize)
  Protected stepX     = Int(hexWidth * 3 / 4)
  Protected stepY     = Int(hexHeight / 2)

  Protected cx, cy, offset
  Protected r, g, b, a, count, pix
  Protected i, j, x, y, px, py

  y = startY
  While y <= stopY
    x = 0
    While x < lg
      If (x / stepX) % 2 = 1
        cy = y + stepY
      Else
        cy = y
      EndIf
      cx = x

      ; Moyenne des couleurs
      r = 0
      g = 0
      b = 0
      a = 0
      count = 0
      For j = -hexSize To hexSize
        For i = -hexSize To hexSize
          If Sqr(i*i + j*j) <= hexSize
            px = cx + i
            py = cy + j
            If px >= 0 And px < lg And py >= 0 And py < ht
              offset = (py * lg + px) * 4
              pix = PeekL(*source + offset)
              r + (pix & $FF)
              g + ((pix >> 8) & $FF)
              b + ((pix >> 16) & $FF)
              a + ((pix >> 24) & $FF)
              count + 1
            EndIf
          EndIf
        Next
      Next

      If count > 0
        r / count : g / count : b / count : a / count
        pix = RGBA(r, g, b, a)

        ; Remplissage
        For j = -hexSize To hexSize
          For i = -hexSize To hexSize
            If Sqr(i*i + j*j) <= hexSize
              px = cx + i
              py = cy + j
              If px >= 0 And px < lg And py >= 0 And py < ht
                offset = (py * lg + px) * 4
                PokeL(*cible + offset, pix)
              EndIf
            EndIf
          Next
        Next
      EndIf

      x + stepX
    Wend
    y + stepY
  Wend
EndProcedure

Procedure HexMosaic(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_FX
    param\name = "HexMosaic"
    param\remarque = "Effet mosaïque hexagonal"
    param\info[0] = "Taille"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 4 : param\info_data(0,1) = 64 : param\info_data(0,2) = 12
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2 : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@HexMosaic_MT() , 1)
EndProcedure

;--------------

Procedure.i PointDansPolygon(x.i, y.i, radius.f, sides.i, rotation.f)
  If sides < 3 : ProcedureReturn #False : EndIf
  
  Protected cosRot.f = Cos(rotation)
  Protected sinRot.f = Sin(rotation)
  
  Protected xRot.f = x * cosRot - y * sinRot
  Protected yRot.f = x * sinRot + y * cosRot
  
  Protected angle.f = ATan2(yRot, xRot)
  Protected dist.f = Sqr(xRot * xRot + yRot * yRot)
  
  Protected theta.f = 2 * #PI / sides
  Protected halfTheta.f = theta / 2
  
  angle = angle + #PI
  While angle >= theta
    angle - theta
  Wend
  While angle < 0
    angle + theta
  Wend
  angle - halfTheta
  
  Protected maxDist.f = Cos(halfTheta) / Cos(angle) * radius
  If dist <= maxDist
    ProcedureReturn 1
  Else
    ProcedureReturn 0
  EndIf
EndProcedure

Procedure IrregularHexMosaic_MT(*p.parametre)
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected hexSize = *p\option[0]
  If hexSize < 4 : hexSize = 4 : EndIf
  Protected alpha = *p\option[4]
  clamp(alpha , 0 , 255)
  Protected inv_alpha = 255 - alpha
  Protected rotationRad.f = *p\option[3] * #PI / 180
  Protected sides = *p\option[2]
  Protected alpha2 = *p\option[6]
  clamp(alpha2 , 0 , 255)
  If sides < 3 : sides = 3 : EndIf
  
  ; Pré-calcul du masque polygonal
  Protected Dim polyMask(hexSize * 2 + 1, hexSize * 2 + 1)
  Protected i, j, x, y, px, py
  For j = -hexSize To hexSize
    For i = -hexSize To hexSize
      If PointDansPolygon(i, j, hexSize, sides, rotationRad)
        polyMask(i + hexSize, j + hexSize) = 1
      EndIf
    Next
  Next
  
  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf
  
  Protected hexWidth  = 2 * hexSize
  Protected hexHeight = Int(Sqr(3) * hexSize)
  Protected stepX     = Int(hexWidth * 3 / 4)
  Protected stepY     = Int(hexHeight / 2)
  
  Protected cx, cy, offset
  Protected r, g, b, a, count, pix ,pix2
  Protected a1 , r1, g1, b1, r2 , g2 , b2
  Protected jitter = (hexSize * *p\option[1]) / 100
  If jitter > hexSize : jitter = hexSize : EndIf
  
  y = startY
  While y <= stopY
    x = 0
    While x < lg
      cx = x + Random(jitter * 2) - jitter
      cy = y + Random(jitter * 2) - jitter
      
      r = 0 : g = 0 : b = 0 : a = 0 : count = 0
      For j = -hexSize To hexSize
        For i = -hexSize To hexSize
          If polyMask(i + hexSize, j + hexSize)
            px = cx + i
            py = cy + j
            If px >= 0 And px < lg And py >= 0 And py < ht
              offset = (py * lg + px) * 4
              pix = PeekL(*source + offset)
              getargb(pix , a1 , r1 , g1 , b1)
              r + r1
              g + g1
              b + b1
              a + a1
              count + 1
            EndIf
          EndIf
        Next
      Next
      
      If count > 0
        r / count : g / count : b / count : a / count
        pix = ( (a << 24) | (r << 16) | (g << 8) | b )
        
        For j = -hexSize To hexSize
          For i = -hexSize To hexSize
            If polyMask(i + hexSize, j + hexSize)
              px = cx + i
              py = cy + j
              If px >= 0 And px < lg And py >= 0 And py < ht
                offset = (py * lg + px) * 4
                
                Protected onEdge = 0
                If *p\option[5]
                  If Not polyMask(i + 1 + hexSize, j + hexSize) Or
                     Not polyMask(i - 1 + hexSize, j + hexSize) Or
                     Not polyMask(i + hexSize, j + 1 + hexSize) Or
                     Not polyMask(i + hexSize, j - 1 + hexSize)
                    onEdge = 1
                  EndIf
                EndIf
                
                If onEdge
                  If alpha2
                    pix2 = PeekL(*cible  + offset)
                    getrgb(pix2 , r2 , g2 , b2)
                    r = (r2 * alpha2) >> 8
                    g = (g2 * alpha2) >> 8
                    b = (b2 * alpha2) >> 8
                    PokeL(*cible + offset, (a << 24) | (r << 16) | (g << 8) | b)   
                  Else
                    PokeL(*cible + offset, RGBA(0, 0, 0, 255))
                  EndIf
                Else
                  If alpha
                    pix2 = PeekL(*cible  + offset)
                    getrgb(pix2 , r2 , g2 , b2)
                    getARGB(pix , a , r1 , g1 , b1)
                    r = (r1 * inv_alpha + r2 * alpha) >> 8
                    g = (g1 * inv_alpha + g2 * alpha) >> 8
                    b = (b1 * inv_alpha + b2 * alpha) >> 8
                    PokeL(*cible + offset, (a << 24) | (r << 16) | (g << 8) | b)
                  Else
                    
                    PokeL(*cible + offset, pix)
                  EndIf
                EndIf
              EndIf
            EndIf
          Next
        Next
      EndIf
      
      x + stepX
    Wend
    y + stepY
  Wend
  FreeArray(polyMask())
EndProcedure



Procedure IrregularHexMosaic(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_FX
    param\name = "IrregularHex"
    param\remarque = "Effet mosaïque hexagonal irrégulier"
    param\info[0] = "Taille des cellules"
    param\info[1] = "Taux d’irrégularité"
    param\info[2] = "Nombre de côtés"
    param\info[3] = "Rotation"
    param\info[4] = "Alpha"
    param\info[5] = "Contours"
    param\info[6] = "Alpha Contours"
    param\info[7] = "Masque binaire"
    param\info_data(0,0) = 4 : param\info_data(0,1) = 64  : param\info_data(0,2) = 12
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 3 : param\info_data(2,1) = 12  : param\info_data(2,2) = 6
    param\info_data(3,0) = 0 : param\info_data(3,1) = 360 : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 1   : param\info_data(5,2) = 0
    param\info_data(6,0) = 0 : param\info_data(6,1) = 255 : param\info_data(6,2) = 0
    param\info_data(7,0) = 0 : param\info_data(7,1) = 2   : param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@IrregularHexMosaic_MT() , 7)
EndProcedure


;--------------

Procedure KaleidoscopeEffect_MT(*p.parametre)
  Protected *src = *p\addr[0]
  Protected *dst = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected numSlices = *p\option[0]
  If numSlices < 1 : numSlices = 1 : EndIf

  Protected rotationDeg.f = *p\option[1] - 360
  Protected zoom.f = *p\option[2] / 100.0
  If zoom <= 0.01 : zoom = 0.01 : EndIf

  Protected angleOffset.f = Radian(rotationDeg)
  Protected angleStep.f = 2 * #PI / numSlices

  Protected cx = lg / 2
  Protected cy = ht / 2

  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  Protected x, y, dx.f, dy.f, angle.f, dist.f, srcAngle.f
  Protected sx.f, sy.f, sxi, syi
  Protected offsetSrc, offsetDst

  For y = startY To stopY
    dy = y - cy
    For x = 0 To lg - 1
      dx = x - cx
      
      angle = ATan2(dy, dx) + angleOffset
      dist  = Sqr(dx*dx + dy*dy) * zoom

      ; ramener angle dans [0, 2PI]
      While angle < 0 : angle + 2 * #PI : Wend
      While angle >= 2 * #PI : angle - 2 * #PI : Wend

      ; Miroir tous les secteurs impairs
      srcAngle = Mod(angle, angleStep)
      If Mod(Int(angle / angleStep), 2) = 1
        srcAngle = angleStep - srcAngle
      EndIf

      sx = cx + Cos(srcAngle) * dist
      sy = cy + Sin(srcAngle) * dist

      Clamp(sx, 0, lg - 1)
      Clamp(sy, 0, ht - 1)

      sxi = Int(sx)
      syi = Int(sy)

      offsetSrc = (syi * lg + sxi) * 4
      offsetDst = (y * lg + x) * 4

      PokeL(*dst + offsetDst, PeekL(*src + offsetSrc))
    Next
  Next
EndProcedure

Procedure Kaleidoscope(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_FX
    param\name = "Kaleidoscope"
    param\remarque = "Effet kaléidoscopique avec rotation et zoom"
    param\info[0] = "Nb secteurs"
    param\info[1] = "Rotation"
    param\info[2] = "Zoom"
    param\info[3] = "Masque binaire"
    param\info_data(0,0) = 1  : param\info_data(0,1) = 24  : param\info_data(0,2) = 6
    param\info_data(1,0) = 0 : param\info_data(1,1) = 720 : param\info_data(1,2) = 360
    param\info_data(2,0) = 10 : param\info_data(2,1) = 500 : param\info_data(2,2) = 100
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2 : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@KaleidoscopeEffect_MT() , 3)
  
EndProcedure

;--------------

Procedure Mosaic_MT(*p.parametre)
  Protected start, stop, y, x, xx, yy
  Protected pixSize = *p\option[0]
  If pixSize < 1 : pixSize = 8 : EndIf
  
  Protected *source = *p\addr[0]
  Protected *cible = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected pix, srcOffset, dstOffset

  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf

  start - Mod(start, pixSize)
  stop  - Mod(stop, pixSize)

  y = start
  While y <= stop
    x = 0
    While x < lg
      srcOffset = *source + (y * lg + x) * 4
      pix = PeekL(srcOffset)

      Protected blockBottom = y + pixSize - 1
      If blockBottom > ht - 1 : blockBottom = ht - 1 : EndIf
      Protected blockRight = x + pixSize - 1
      If blockRight > lg - 1 : blockRight = lg - 1 : EndIf

      For yy = y To blockBottom
        For xx = x To blockRight
          dstOffset = *cible + (yy * lg + xx) * 4
          PokeL(dstOffset, pix)
        Next
      Next

      x + pixSize
    Wend
    y + pixSize
  Wend
EndProcedure

Procedure Mosaic(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_FX
    param\name = "Mosaic"
    param\remarque = "Effet de pixelisation en blocs"
    param\info[0] = "Taille des blocs"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 32 : param\info_data(0,2) = 8
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2 : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Mosaic_MT() , 1)
  
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 876
; FirstLine = 861
; Folding = ----
; EnableXP
; DPIAware