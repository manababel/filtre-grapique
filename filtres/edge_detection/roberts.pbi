
; Conversion HSV → RGB (simple)
Procedure Roberts_RGBFromHSV(*r.Integer, *g.Integer, *b.Integer, h.f, s.f, v.f)
  Protected c.f = v * s
  Protected x.f = c * (1.0 - Abs(Mod(h / 60.0, 2.0) - 1.0))
  Protected m.f = v - c
  Protected r1.f, g1.f, b1.f
  Protected sector = h / 60.0
  
  Select Int(sector)
    Case 0 : r1 = c : g1 = x : b1 = 0.0
    Case 1 : r1 = x : g1 = c : b1 = 0.0
    Case 2 : r1 = 0.0 : g1 = c : b1 = x
    Case 3 : r1 = 0.0 : g1 = x : b1 = c
    Case 4 : r1 = x : g1 = 0.0 : b1 = c
    Default: r1 = c : g1 = 0.0 : b1 = x
  EndSelect
  
  *r\i = Int((r1 + m) * 255.0)
  *g\i = Int((g1 + m) * 255.0)
  *b\i = Int((b1 + m) * 255.0)
EndProcedure


Procedure Roberts_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected mul.f = *param\option[0]
  Protected math = *param\option[1]
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected seuillage = *param\option[4]
  Protected orientation = *param\option[5]
  Protected angle_add.f = *param\option[6]
  
  clamp(mul, 0, 100)
  mul = mul * 0.05

  Protected a, r, g, b
  Protected r1, g1, b1, r2, g2, b2, r3, g3, b3, r4, g4, b4
  Protected gxR, gxG, gxB, gyR, gyG, gyB
  Protected valR, valG, valB, gx, gy, mag.f, angle.f
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected x, y
  Protected pitch = lg * 4  ; Optimisation : précalcul du pitch

  Protected startPos = (*param\thread_pos * (ht - 1)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 1)) / *param\thread_max
  
  If startPos < 0 : startPos = 0 : EndIf
  If endPos > ht - 1 : endPos = ht - 1 : EndIf
  
  For y = startPos To endPos - 1
    ; Optimisation : calcul de la position de ligne une seule fois
    Protected *srcLine = *source + y * pitch
    Protected *srcLineNext = *srcLine + pitch
    Protected *dstLine = *cible + y * pitch
    
    For x = 0 To lg - 2
      ; Optimisation : accès direct via offset
      Protected offset = x * 4
      
      ; Lire les 4 pixels 2x2 pour le masque Roberts
      *srcPixel = *srcLine + offset
      getargb(*srcPixel\l, a, r1, g1, b1)

      *srcPixel = *srcLine + offset + 4
      getrgb(*srcPixel\l, r2, g2, b2)

      *srcPixel = *srcLineNext + offset
      getrgb(*srcPixel\l, r3, g3, b3)

      *srcPixel = *srcLineNext + offset + 4
      getrgb(*srcPixel\l, r4, g4, b4)

      ; Calcul Roberts : Gx = pixel haut gauche - pixel bas droite
      gxR = r1 - r4
      gxG = g1 - g4
      gxB = b1 - b4

      ; Gy = pixel haut droite - pixel bas gauche
      gyR = r2 - r3
      gyG = g2 - g3
      gyB = b2 - b3
      
      If orientation
        ; ---- Mode orientation couleur ----
        gx = gxR + gxG + gxB
        gy = gyR + gyG + gyB
        mag = Sqr(gx * gx + gy * gy) * mul
        angle = ATan2(gy, gx) * 180.0 / #PI
        
        ; Normalisation de l'angle entre 0 et 360
        angle + angle_add
        While angle < 0.0
          angle + 360.0
        Wend
        While angle >= 360.0
          angle - 360.0
        Wend
        
        ; Clamp magnitude
        If mag > 255.0 : mag = 255.0 : EndIf
        
        Roberts_RGBFromHSV(@valR, @valG, @valB, angle, 1.0, mag / 255.0)
      Else
        ; Calcul de la magnitude du gradient
        If math
          valR = Abs(gxR) + Abs(gyR)
          valG = Abs(gxG) + Abs(gyG)
          valB = Abs(gxB) + Abs(gyB)
        Else
          valR = Sqr(gxR * gxR + gyR * gyR) 
          valG = Sqr(gxG * gxG + gyG * gyG) 
          valB = Sqr(gxB * gxB + gyB * gyB) 
        EndIf
        
        ; Appliquer multiplicateur
        valR = valR * mul
        valG = valG * mul
        valB = valB * mul
      EndIf
      
      ; Conversion en entier et clamp
      r = Int(valR)
      g = Int(valG)
      b = Int(valB)
      
      clamp_rgb(r, g, b)
      
      ; Seuillage
      If seuillage > 0
        If r > seuillage : r = 255 : Else : r = 0 : EndIf
        If g > seuillage : g = 255 : Else : g = 0 : EndIf
        If b > seuillage : b = 255 : Else : b = 0 : EndIf
      EndIf
      
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

Procedure Roberts(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Gradient
    *param\subtype = #EdgeDetect_Gradient
    *param\name = "Roberts"
    *param\remarque = "Détection 2 directions"
    *param\info[0] = "multiply"
    *param\info[1] = "math (ABS ou SQR)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "inversion"
    *param\info[4] = "seuillage : 0 = off"
    *param\info[5] = "orientation"
    *param\info[6] = "angle"
    *param\info[7] = "masque"
    *param\info_data(0, 0) = 0   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 255 : *param\info_data(4, 2) = 0
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 1   : *param\info_data(5, 2) = 0
    *param\info_data(6, 0) = 0   : *param\info_data(6, 1) = 360 : *param\info_data(6, 2) = 0
    *param\info_data(7, 0) = 0   : *param\info_data(7, 1) = 2   : *param\info_data(7, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Roberts_MT(), 7)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 187
; FirstLine = 118
; Folding = -
; EnableXP
; DPIAware