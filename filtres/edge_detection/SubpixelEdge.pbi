; ============================================================================
; Filtre Subpixel Edge - Détection de contours avec précision subpixel
; ============================================================================

Procedure SubpixelEdge_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    
    ; Récupération des options
    Protected mul.f        = \option[0] * 0.1
    Protected threshold.f  = \option[1]
    Protected toGray       = \option[2]
    Protected inverse      = \option[3]
    Protected interpolate  = \option[4]
    Protected showPos      = \option[5]
    
    Protected x, y, a, r, g, b, r0, g0, b0, r1, g1, b1, r2, g2, b2
    Protected gx.f, gy.f, mag.f, sub_x.f, sub_y.f, valR.f, valG.f, valB.f
    Protected pitch = lg * 4
    Protected *srcPixel.Pixel32, *dstPixel.Pixel32
    
    ; Calcul des bornes du thread
    macro_calul_tread((ht - 2))
    Protected startPos = thread_start + 1
    Protected endPos   = thread_stop + 1
    
    For y = startPos To endPos
      Protected *srcLinePrev = *source + (y - 1) * pitch
      Protected *srcLine     = *source + y * pitch
      Protected *srcLineNext = *source + (y + 1) * pitch
      Protected *dstLine     = *cible + y * pitch
      
      For x = 1 To lg - 2
        Protected offset = x * 4
        
        ; --- Calcul du Gradient (Sobel simplifié) ---
        ; Horizontal
        *srcPixel = *srcLine + offset - 4 : getargb(*srcPixel\l, a, r0, g0, b0)
        *srcPixel = *srcLine + offset + 4 : getrgb(*srcPixel\l, r2, g2, b2)
        Protected gxR.f = (r2 - r0) * 0.5
        Protected gxG.f = (g2 - g0) * 0.5
        Protected gxB.f = (b2 - b0) * 0.5
        
        ; Vertical
        *srcPixel = *srcLinePrev + offset : getrgb(*srcPixel\l, r0, g0, b0)
        *srcPixel = *srcLineNext + offset : getrgb(*srcPixel\l, r2, g2, b2)
        Protected gyR.f = (r2 - r0) * 0.5
        Protected gyG.f = (g2 - g0) * 0.5
        Protected gyB.f = (b2 - b0) * 0.5
        
        ; Magnitude
        Protected magR.f = Sqr(gxR * gxR + gyR * gyR)
        Protected magG.f = Sqr(gxG * gxG + gyG * gyG)
        Protected magB.f = Sqr(gxB * gxB + gyB * gyB)
        mag = (magR + magG + magB) / 3.0
        
        sub_x = 0 : sub_y = 0
        
        If interpolate And mag > threshold
          gx = (gxR + gxG + gxB) / 3.0
          gy = (gyR + gyG + gyB) / 3.0
          Protected g_norm.f = Sqr(gx * gx + gy * gy)
          
          If g_norm > 0.001
            Protected nx.f = gx / g_norm
            Protected ny.f = gy / g_norm
            
            ; Voisin dans la direction du gradient
            Protected off_next = offset + Int(nx + 0.5) * 4
            Protected *line_next = *srcLine + Int(ny + 0.5) * pitch
            
            If off_next >= 0 And off_next < (lg - 1) * 4
               ; Interpolation parabolique simplifiée
               ; (Note: ceci est une approximation de la localisation du pic)
               *srcPixel = *line_next + off_next
               Protected r_n, g_n, b_n
               getrgb(*srcPixel\l, r_n, g_n, b_n)
               Protected mag_next.f = (r_n + g_n + b_n) / 3.0 ; Approximation rapide
               
               Protected denom.f = 2.0 * (mag - mag_next)
               If Abs(denom) > 0.001
                 Protected shift.f = (mag + mag_next) / denom
                 sub_x = shift * nx
                 sub_y = shift * ny
                 Clamp(sub_x, -1.0, 1.0)
                 Clamp(sub_y, -1.0, 1.0)
               EndIf
            EndIf
          EndIf
          
          mag * (1.0 + Abs(sub_x) + Abs(sub_y))
          
          If showPos
            valR = mag * mul + Abs(sub_x) * 100.0
            valG = mag * mul + Abs(sub_y) * 100.0
            valB = mag * mul
          Else
            valR = magR * mul : valG = magG * mul : valB = magB * mul
          EndIf
        Else
          valR = magR * mul : valG = magG * mul : valB = magB * mul
        EndIf
        
        r = Int(valR) : g = Int(valG) : b = Int(valB)
        Clamp_RGB(r, g, b)
        
        If toGray
          Protected gray = (r * 77 + g * 150 + b * 29) >> 8
          r = gray : g = gray : b = gray
        EndIf
        
        If inverse
          r = 255 - r : g = 255 - g : b = 255 - b
        EndIf
        
        *dstPixel = *dstLine + offset
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure SubpixelEdgeEx(*FilterCtx.FilterParams)
  Restore SubpixelEdge_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@SubpixelEdge_MT())
  mask_update(*FilterCtx, last_data)
EndProcedure

; Interface simplifiée
Procedure SubpixelEdge(source, cible, mask, mul=10, thresh=30, gray=0, inv=0, interp=1, show=0)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = mul : \option[1] = thresh : \option[2] = gray
    \option[3] = inv : \option[4] = interp : \option[5] = show
  EndWith
  SubpixelEdgeEx(FilterCtx)
EndProcedure

DataSection
  SubpixelEdge_data:
  Data.s "Subpixel Edge (crash)"
  Data.s "Détection de contours haute précision avec interpolation"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Specialized
  
  Data.s "Multiplicateur"
  Data.i 0, 100, 10
  Data.s "Seuil (Threshold)"
  Data.i 0, 255, 30
  Data.s "Noir et Blanc"
  Data.i 0, 1, 0
  Data.s "Inversion"
  Data.i 0, 1, 0
  Data.s "Interpolation Subpixel"
  Data.i 0, 1, 1
  Data.s "Afficher positions"
  Data.i 0, 1, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 146
; FirstLine = 113
; Folding = -
; EnableXP
; DPIAware