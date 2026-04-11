; Filtre de détection de contours orientés
; Détecte les contours dans des directions spécifiques

Procedure OrientedEdge_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected mul.f = *param\option[0]
  Protected angle.f = *param\option[1]
  Protected tolerance.f = *param\option[2]
  Protected toGray = *param\option[3]
  Protected inverse = *param\option[4]
  Protected showDirection = *param\option[5]
  Protected suppressNonMax = *param\option[6]
  
  clamp(mul, 0, 100)
  mul = mul * 0.1
  
  ; Normaliser l'angle entre 0 et 360
  While angle < 0.0
    angle + 360.0
  Wend
  While angle >= 360.0
    angle - 360.0
  Wend
  
  clamp(tolerance, 0, 180)
  
  ; Convertir l'angle cible en radians
  Protected target_angle_rad.f = angle * #PI / 180.0
  Protected tolerance_rad.f = tolerance * #PI / 180.0

  Protected a, r, g, b
  Protected r1, g1, b1, r2, g2, b2, r3, g3, b3, r4, g4, b4
  Protected r5, g5, b5, r6, g6, b6, r7, g7, b7, r8, g8, b8
  Protected gx.f, gy.f, mag.f, edge_angle.f, angle_diff.f
  Protected valR.f, valG.f, valB.f
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected x, y
  Protected pitch = lg * 4

  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max + 1
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max + 1
  
  If startPos < 1 : startPos = 1 : EndIf
  If endPos > ht - 2 : endPos = ht - 2 : EndIf
  
  ; Buffer temporaire pour stocker les magnitudes (pour suppression non-maximum)
  Protected Dim mag_buffer.f(lg, 3)
  Protected Dim angle_buffer.f(lg, 3)
  
  For y = startPos To endPos
    Protected *srcLinePrev = *source + (y - 1) * pitch
    Protected *srcLine = *source + y * pitch
    Protected *srcLineNext = *source + (y + 1) * pitch
    Protected *dstLine = *cible + y * pitch
    
    For x = 1 To lg - 2
      Protected offset = x * 4
      
      ; Lecture des 8 pixels voisins (masque 3x3 Sobel)
      ; Ligne du haut
      *srcPixel = *srcLinePrev + offset - 4
      getargb(*srcPixel\l, a, r1, g1, b1)
      *srcPixel = *srcLinePrev + offset
      getrgb(*srcPixel\l, r2, g2, b2)
      *srcPixel = *srcLinePrev + offset + 4
      getrgb(*srcPixel\l, r3, g3, b3)
      
      ; Ligne du milieu
      *srcPixel = *srcLine + offset - 4
      getrgb(*srcPixel\l, r4, g4, b4)
      ; Centre : r5, g5, b5 (non utilisé pour Sobel)
      *srcPixel = *srcLine + offset + 4
      getrgb(*srcPixel\l, r6, g6, b6)
      
      ; Ligne du bas
      *srcPixel = *srcLineNext + offset - 4
      getrgb(*srcPixel\l, r7, g7, b7)
      *srcPixel = *srcLineNext + offset
      getrgb(*srcPixel\l, r8, g8, b8)
      *srcPixel = *srcLineNext + offset + 4
      getrgb(*srcPixel\l, r5, g5, b5) ; r5 réutilisé pour coin bas-droit
      
      ; Opérateur Sobel
      ; Gx = [-1  0  1]   Gy = [-1 -2 -1]
      ;      [-2  0  2]        [ 0  0  0]
      ;      [-1  0  1]        [ 1  2  1]
      
      Protected gxR.f = (-r1 - 2*r4 - r7 + r3 + 2*r6 + r5)
      Protected gxG.f = (-g1 - 2*g4 - g7 + g3 + 2*g6 + g5)
      Protected gxB.f = (-b1 - 2*b4 - b7 + b3 + 2*b6 + b5)
      
      Protected gyR.f = (-r1 - 2*r2 - r3 + r7 + 2*r8 + r5)
      Protected gyG.f = (-g1 - 2*g2 - g3 + g7 + 2*g8 + g5)
      Protected gyB.f = (-b1 - 2*b2 - b3 + b7 + 2*b8 + b5)
      
      ; Magnitude du gradient par canal
      Protected magR.f = Sqr(gxR * gxR + gyR * gyR)
      Protected magG.f = Sqr(gxG * gxG + gyG * gyG)
      Protected magB.f = Sqr(gxB * gxB + gyB * gyB)
      
      ; Magnitude et gradient moyens
      mag = (magR + magG + magB) / 3.0
      gx = (gxR + gxG + gxB) / 3.0
      gy = (gyR + gyG + gyB) / 3.0
      
      ; Calculer l'angle du gradient (perpendiculaire au contour)
      edge_angle = ATan2(gy, gx)
      
      ; Calculer la différence d'angle avec l'angle cible
      angle_diff = Abs(edge_angle - target_angle_rad)
      
      ; Normaliser la différence d'angle entre 0 et PI
      If angle_diff > #PI
        angle_diff = 2.0 * #PI - angle_diff
      EndIf
      
      ; Stocker pour suppression non-maximum
      mag_buffer(x, 0) = mag
      angle_buffer(x, 0) = edge_angle
      
      ; Appliquer le filtre d'orientation
      If angle_diff <= tolerance_rad
        ; Le contour est dans la direction souhaitée
        Protected response.f = 1.0 - (angle_diff / tolerance_rad)
        
        If showDirection
          ; Mode visualisation : encoder la direction en couleur HSV
          Protected hue.f = (edge_angle * 180.0 / #PI + 180.0) ; 0-360
          While hue < 0.0 : hue + 360.0 : Wend
          While hue >= 360.0 : hue - 360.0 : Wend
          
          Protected sat.f = response
          Protected val.f = mag / 255.0
          If val > 1.0 : val = 1.0 : EndIf
          
          ; Conversion HSV -> RGB simplifiée
          Protected c.f = val * sat
          Protected x_hsv.f = c * (1.0 - Abs(Mod(hue / 60.0, 2.0) - 1.0))
          Protected m.f = val - c
          Protected sector = Int(hue / 60.0)
          
          Select sector
            Case 0 : valR = c : valG = x_hsv : valB = 0.0
            Case 1 : valR = x_hsv : valG = c : valB = 0.0
            Case 2 : valR = 0.0 : valG = c : valB = x_hsv
            Case 3 : valR = 0.0 : valG = x_hsv : valB = c
            Case 4 : valR = x_hsv : valG = 0.0 : valB = c
            Default: valR = c : valG = 0.0 : valB = x_hsv
          EndSelect
          
          valR = (valR + m) * 255.0
          valG = (valG + m) * 255.0
          valB = (valB + m) * 255.0
        Else
          ; Mode normal : magnitude pondérée par la réponse
          valR = magR * response * mul
          valG = magG * response * mul
          valB = magB * response * mul
        EndIf
      Else
        ; Contour hors direction : supprimer
        valR = 0.0
        valG = 0.0
        valB = 0.0
      EndIf
      
      ; Suppression non-maximum (optionnelle)
      If suppressNonMax And x > 1 And y > startPos
        ; Vérifier si c'est un maximum local dans la direction du gradient
        Protected cos_angle.f = Cos(angle_buffer(x, 0))
        Protected sin_angle.f = Sin(angle_buffer(x, 0))
        
        ; Pixels voisins dans la direction du gradient
        Protected mag_prev.f, mag_next.f
        
        If Abs(cos_angle) > Abs(sin_angle)
          ; Direction principalement horizontale
          mag_prev = mag_buffer(x - 1, 0)
          mag_next = mag_buffer(x + 1, 0)
        Else
          ; Direction principalement verticale
          mag_prev = mag_buffer(x, 1) ; Ligne précédente
          mag_next = mag ; Sera comparé lors du prochain passage
        EndIf
        
        If mag_buffer(x, 0) < mag_prev Or mag_buffer(x, 0) < mag_next
          ; Pas un maximum local : supprimer
          valR = 0.0
          valG = 0.0
          valB = 0.0
        EndIf
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
    
    ; Décalage du buffer pour la ligne suivante (pour suppression non-max)
    For x = 0 To lg - 1
      mag_buffer(x, 1) = mag_buffer(x, 0)
      angle_buffer(x, 1) = angle_buffer(x, 0)
    Next
  Next
EndProcedure

Procedure OrientedEdge(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Specialized
    *param\name = "OrientedEdge"
    *param\remarque = "Détection de contours dans une direction spécifique"
    *param\info[0] = "multiply"
    *param\info[1] = "angle (0-360°)"
    *param\info[2] = "tolerance (0-180°)"
    *param\info[3] = "Noir et blanc"
    *param\info[4] = "inversion"
    *param\info[5] = "afficher direction (HSV)"
    *param\info[6] = "suppression non-maximum"
    *param\info[7] = "masque"
    *param\info_data(0, 0) = 0   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 360 : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 180 : *param\info_data(2, 2) = 45
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 1   : *param\info_data(4, 2) = 0
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 1   : *param\info_data(5, 2) = 0
    *param\info_data(6, 0) = 0   : *param\info_data(6, 1) = 1   : *param\info_data(6, 2) = 0
    *param\info_data(7, 0) = 0   : *param\info_data(7, 1) = 2   : *param\info_data(7, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@OrientedEdge_MT(), 7)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 231
; FirstLine = 194
; Folding = -
; EnableXP
; DPIAware