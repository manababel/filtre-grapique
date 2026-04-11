; Filtre de détection de contours subpixel
; Utilise l'interpolation pour détecter les contours avec précision subpixel

Procedure SubpixelEdge_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected mul.f = *param\option[0]
  Protected threshold.f = *param\option[1]
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected interpolation = *param\option[4]
  Protected showPosition = *param\option[5]
  
  clamp(mul, 0, 100)
  mul = mul * 0.1
  clamp(threshold, 0, 255)

  Protected a, r, g, b
  Protected r0, g0, b0, r1, g1, b1, r2, g2, b2
  Protected gx.f, gy.f, mag.f, subpixel_x.f, subpixel_y.f
  Protected valR.f, valG.f, valB.f
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected x, y
  Protected pitch = lg * 4

  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max + 1
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max + 1
  
  If startPos < 1 : startPos = 1 : EndIf
  If endPos > ht - 2 : endPos = ht - 2 : EndIf
  
  For y = startPos To endPos
    Protected *srcLinePrev = *source + (y - 1) * pitch
    Protected *srcLine = *source + y * pitch
    Protected *srcLineNext = *source + (y + 1) * pitch
    Protected *dstLine = *cible + y * pitch
    
    For x = 1 To lg - 2
      Protected offset = x * 4
      
      ; Lecture des pixels pour le gradient (Sobel 3x3 simplifié)
      ; Pixel gauche
      *srcPixel = *srcLine + offset - 4
      getargb(*srcPixel\l, a, r0, g0, b0)
      
      ; Pixel centre
      *srcPixel = *srcLine + offset
      getrgb(*srcPixel\l, r1, g1, b1)
      
      ; Pixel droite
      *srcPixel = *srcLine + offset + 4
      getrgb(*srcPixel\l, r2, g2, b2)
      
      ; Gradient horizontal (simpllifié)
      Protected gxR.f = (r2 - r0) * 0.5
      Protected gxG.f = (g2 - g0) * 0.5
      Protected gxB.f = (b2 - b0) * 0.5
      
      ; Pixel haut
      *srcPixel = *srcLinePrev + offset
      getrgb(*srcPixel\l, r0, g0, b0)
      
      ; Pixel bas
      *srcPixel = *srcLineNext + offset
      getrgb(*srcPixel\l, r2, g2, b2)
      
      ; Gradient vertical
      Protected gyR.f = (r2 - r0) * 0.5
      Protected gyG.f = (g2 - g0) * 0.5
      Protected gyB.f = (b2 - b0) * 0.5
      
      ; Calcul de la magnitude du gradient
      Protected magR.f = Sqr(gxR * gxR + gyR * gyR)
      Protected magG.f = Sqr(gxG * gxG + gyG * gyG)
      Protected magB.f = Sqr(gxB * gxB + gyB * gyB)
      
      ; Magnitude moyenne
      mag = (magR + magG + magB) / 3.0
      
      If interpolation And mag > threshold
        ; Calcul de la position subpixel du contour
        ; En utilisant l'interpolation parabolique
        Protected grad_center.f = mag
        
        ; Gradient dans la direction du gradient maximum
        gx = (gxR + gxG + gxB) / 3.0
        gy = (gyR + gyG + gyB) / 3.0
        Protected grad_norm.f = Sqr(gx * gx + gy * gy)
        
        If grad_norm > 0.001
          ; Normalisation du gradient
          Protected nx.f = gx / grad_norm
          Protected ny.f = gy / grad_norm
          
          ; Lecture du gradient voisin dans la direction du gradient
          Protected offset_next = offset + Int(nx + 0.5) * 4
          Protected *srcLine_next = *srcLine + Int(ny + 0.5) * pitch
          
          If offset_next >= 0 And offset_next < (lg - 1) * 4
            *srcPixel = *srcLine_next + offset_next - 4
            getrgb(*srcPixel\l, r0, g0, b0)
            *srcPixel = *srcLine_next + offset_next + 4
            getrgb(*srcPixel\l, r2, g2, b2)
            
            Protected gxR_next.f = (r2 - r0) * 0.5
            Protected gxG_next.f = (g2 - g0) * 0.5
            Protected gxB_next.f = (b2 - b0) * 0.5
            
            *srcPixel = *srcLine_next + offset_next - pitch
            getrgb(*srcPixel\l, r0, g0, b0)
            *srcPixel = *srcLine_next + offset_next + pitch
            getrgb(*srcPixel\l, r2, g2, b2)
            
            Protected gyR_next.f = (r2 - r0) * 0.5
            Protected gyG_next.f = (g2 - g0) * 0.5
            Protected gyB_next.f = (b2 - b0) * 0.5
            
            Protected magR_next.f = Sqr(gxR_next * gxR_next + gyR_next * gyR_next)
            Protected magG_next.f = Sqr(gxG_next * gxG_next + gyG_next * gyG_next)
            Protected magB_next.f = Sqr(gxB_next * gxB_next + gyB_next * gyB_next)
            
            Protected grad_next.f = (magR_next + magG_next + magB_next) / 3.0
            
            ; Interpolation parabolique pour trouver la position subpixel
            Protected denom.f = 2.0 * (grad_center - grad_next)
            If Abs(denom) > 0.001
              subpixel_x = 0.5 * (grad_center + grad_next) / denom
              subpixel_x = subpixel_x * nx
              subpixel_y = subpixel_x * ny
              
              ; Limiter le décalage subpixel
              If Abs(subpixel_x) > 1.0 : subpixel_x = 0.0 : EndIf
              If Abs(subpixel_y) > 1.0 : subpixel_y = 0.0 : EndIf
            Else
              subpixel_x = 0.0
              subpixel_y = 0.0
            EndIf
          EndIf
        EndIf
        
        ; Affiner la magnitude avec la position subpixel
        mag = mag * (1.0 + Abs(subpixel_x) + Abs(subpixel_y))
        
        If showPosition
          ; Visualiser la position subpixel en couleur
          ; Rouge = décalage positif X, Vert = décalage positif Y
          valR = mag * mul + Abs(subpixel_x) * 100.0
          valG = mag * mul + Abs(subpixel_y) * 100.0
          valB = mag * mul
        Else
          valR = magR * mul
          valG = magG * mul
          valB = magB * mul
        EndIf
      Else
        ; Mode standard sans interpolation
        valR = magR * mul
        valG = magG * mul
        valB = magB * mul
      EndIf
      
      ; Conversion en entier et clamp
      r = Int(valR)
      g = Int(valG)
      b = Int(valB)
      
      clamp_rgb(r, g, b)
      
      ; Passage en niveaux de gris si demandé
      If toGray
        r = (r * 77 + g * 150 + b * 29) >> 8
        g = r
        b = r
      EndIf

      ; Inversion si demandé
      If inverse
        r = 255 - r
        g = 255 - g
        b = 255 - b
      EndIf

      ; Écrire le pixel dans la cible
      *dstPixel = *dstLine + offset
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    Next
  Next
EndProcedure

Procedure SubpixelEdge(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Specialized
    *param\name = "SubpixelEdge"
    *param\remarque = "Détection de contours avec précision subpixel"
    *param\info[0] = "multiply"
    *param\info[1] = "threshold"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "inversion"
    *param\info[4] = "interpolation subpixel"
    *param\info[5] = "afficher position subpixel"
    *param\info[6] = "masque"
    *param\info_data(0, 0) = 0   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 255 : *param\info_data(1, 2) = 30
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 1   : *param\info_data(4, 2) = 1
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 1   : *param\info_data(5, 2) = 0
    *param\info_data(6, 0) = 0   : *param\info_data(6, 1) = 2   : *param\info_data(5, 2) = 6
    ProcedureReturn
  EndIf
  filter_start(@SubpixelEdge_MT(), 6)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 192
; FirstLine = 155
; Folding = -
; EnableXP
; DPIAware