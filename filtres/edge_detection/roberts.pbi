; Conversion HSV → RGB pour le mode orientation
Procedure Roberts_RGBFromHSV(*r.Integer, *g.Integer, *b.Integer, h.f, s.f, v.f)
  Protected c.f = v * s
  Protected x.f = c * (1.0 - Abs(Mod(h / 60.0, 2.0) - 1.0))
  Protected m.f = v - c
  Protected r1.f, g1.f, b1.f
  Protected sector = h / 60.0
  
  ; Sécurité pour s'assurer que le secteur reste entre 0 et 5
  Select Int(sector) % 6
    Case 0 : r1 = c   : g1 = x   : b1 = 0.0
    Case 1 : r1 = x   : g1 = c   : b1 = 0.0
    Case 2 : r1 = 0.0 : g1 = c   : b1 = x
    Case 3 : r1 = 0.0 : g1 = x   : b1 = c
    Case 4 : r1 = x   : g1 = 0.0 : b1 = c
    Default: r1 = c   : g1 = 0.0 : b1 = x ; Secteur 5
  EndSelect
  
  *r\i = Int((r1 + m) * 255.0)
  *g\i = Int((g1 + m) * 255.0)
  *b\i = Int((b1 + m) * 255.0)
EndProcedure

Procedure Roberts_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.05
    Protected math = \option[1]       ; 0: SQR, 1: ABS
    Protected toGray = \option[2]     ; Boolean
    Protected inverse = \option[3]    ; Boolean
    Protected seuillage = \option[4]  ; 0-255
    Protected orientation = \option[5]; Boolean
    Protected angle_add.f = \option[6]
    
    Protected x, y, pos
    Protected a, r, g, b
    Protected r1, g1, b1, r2, g2, b2, r3, g3, b3, r4, g4, b4
    Protected gxR, gxG, gxB, gyR, gyG, gyB
    Protected valR.f, valG.f, valB.f, gx, gy, mag.f, angle.f
    Protected *src.Pixelarray32 = \addr[0]
    Protected *dst.Pixelarray32 = \addr[1]
    
    macro_calul_tread(ht)
    
    If thread_stop >= (ht - 1) : thread_stop = ht - 2 : EndIf
    
    For y = thread_start To thread_stop   
      For x = 0 To lg - 2
        pos = (y * lg) + x
        
        getargb(*src\Pixel[pos], a, r1, g1, b1)          ; P(x, y)
        getrgb(*src\Pixel[pos + 1], r2, g2, b2)          ; P(x+1, y)
        getrgb(*src\Pixel[pos + lg], r3, g3, b3)         ; P(x, y+1)
        getrgb(*src\Pixel[pos + lg + 1], r4, g4, b4)     ; P(x+1, y+1)

        gxR = r1 - r4 : gxG = g1 - g4 : gxB = b1 - b4
        gyR = r2 - r3 : gyG = g2 - g3 : gyB = b2 - b3
        
        If orientation
          ; On moyenne ou on cumule les canaux pour l'orientation globale
          gx = gxR + gxG + gxB
          gy = gyR + gyG + gyB
          mag = Sqr(gx * gx + gy * gy) * mul
          
          If mag > 0.0
            angle = ATan2(gx, gy) * 180.0 / #PI + angle_add
            If angle < 0.0 : angle + 360.0 : EndIf
            If angle >= 360.0 : angle - 360.0 : EndIf
          Else
            angle = 0.0
          EndIf
          
          If mag > 255.0 : mag = 255.0 : EndIf
          Roberts_RGBFromHSV(@r, @g, @b, angle, 1.0, mag / 255.0)
        Else
          If math
            valR = Abs(gxR) + Abs(gyR)
            valG = Abs(gxG) + Abs(gyG)
            valB = Abs(gxB) + Abs(gyB)
          Else
            valR = Sqr(gxR * gxR + gyR * gyR) 
            valG = Sqr(gxG * gxG + gyG * gyG) 
            valB = Sqr(gxB * gxB + gyB * gyB) 
          EndIf
          
          r = Int(valR * mul)
          g = Int(valG * mul)
          b = Int(valB * mul)
        EndIf
        
        clamp_rgb(r , g , b)
        
        If seuillage > 0 : seuil_rgb(seuillage , r , g , b) : EndIf
        If toGray : r = (r * 77 + g * 150 + b * 29) >> 8 : g = r : b = r : EndIf
        If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf

        *dst\pixel[pos] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

; Correction de la typo sur le nom de la procédure (Robets -> Roberts)
Procedure Roberts_bords(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y
    Protected *dst.Pixelarray32 = \addr[1]
    
    ; Étape A : On complète le bord droit (dernière colonne)
    For y = 0 To ht - 2
      *dst\pixel[(y * lg) + lg - 1] = *dst\pixel[(y * lg) + lg - 2]
    Next
    
    ; Étape B : On complète toute la dernière ligne
    Protected last_line_offset = (ht - 1) * lg
    Protected prev_line_offset = (ht - 2) * lg
    For x = 0 To lg - 1
      *dst\pixel[last_line_offset + x] = *dst\pixel[prev_line_offset + x]
    Next
  EndWith
EndProcedure

Procedure RobertsEx(*FilterCtx.FilterParams)
  Restore Roberts_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  With *FilterCtx
    Protected size = \image_lg[0] * \image_ht[0] * 4
    If \addr[1] = \addr[0] 
      \addr[2] = AllocateMemory(size) 
      If \addr[2]
        CopyMemory(\addr[0] , \addr[2] , size) 
        \addr[0] = \addr[2]
        
        Create_MultiThread_MT(@Roberts_MT())
        Roberts_bords(*FilterCtx) ; Correction typo
        FreeMemory(\addr[2]) 
      EndIf
    Else
      Create_MultiThread_MT(@Roberts_MT())
      Roberts_bords(*FilterCtx) ; Correction typo
    EndIf 
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Roberts(source, cible, mask, multiply=10, math=0, gray=0, inverse=0, seuil=0, orient=0, angle=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = math
    \option[2] = gray
    \option[3] = inverse
    \option[4] = seuil
    \option[5] = orient
    \option[6] = angle
  EndWith
  RobertsEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Roberts_data:
  Data.s "Roberts"
  Data.s "Détection de contours par l'opérateur de Roberts (gradient 2x2)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
  
  Data.s "Multiplicateur"
  Data.i 0, 100, 10
  Data.s "Math (0:SQR, 1:ABS)"
  Data.i 0, 1, 0
  Data.s "Niveaux de gris"
  Data.i 0, 1, 0
  Data.s "Inverser"
  Data.i 0, 1, 0
  Data.s "Seuillage (0=Off)"
  Data.i 0, 255, 0
  Data.s "Orientation (HSV)"
  Data.i 0, 1, 0
  Data.s "Angle d'ajustement"
  Data.i 0, 360, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; Folding = -
; EnableXP
; DPIAware