; Macros pour le calcul des gradients Sobel 4D
Macro sobel_4d_calc(v0, v1, v2, v3, v4, v5, v6)
  ; Sobel utilise les coefficients [1, 2, 1]
  r#v0 = r3(v1) + (r3(v2) << 1) + r3(v3) - (r3(v4) + (r3(v5) << 1) + r3(v6))
  g#v0 = g3(v1) + (g3(v2) << 1) + g3(v3) - (g3(v4) + (g3(v5) << 1) + g3(v6))
  b#v0 = b3(v1) + (b3(v2) << 1) + b3(v3) - (b3(v4) + (b3(v5) << 1) + b3(v6))
EndMacro

Procedure sobel_4d_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.1
    Protected mat = \option[1]      ; 0: SQR, 1: ABS
    Protected toGray = \option[2]   ; Boolean
    Protected inverse = \option[3]  ; Boolean
    
    Protected Dim r3(8), Dim g3(8), Dim b3(8)
    
    ; Gradients intermédiaires
    Protected rx0, gx0, bx0, ry0, gy0, by0
    Protected rx45, gx45, bx45, ry45, gy45, by45
    Protected rx90, gx90, bx90, ry90, gy90, by90
    Protected rx135, gx135, bx135, ry135, gy135, by135
    
    ; Magnitudes par direction
    Protected r0.f, g0.f, b0.f, r45.f, g45.f, b45.f
    Protected r90.f, g90.f, b90.f, r135.f, g135.f, b135.f
    
    Protected *srcPixel.Pixel32, *dstPixel.Pixel32
    Protected a, r, g, b, x, y, k, pitch = lg << 2
    Protected dx , dy
    
    macro_calul_tread(ht)
    
    ; Éviter les bords
    If thread_start < 1 : thread_start = 1 : EndIf
    If thread_stop > ht - 1 : thread_stop = ht - 1 : EndIf
    
    For y = thread_start To thread_stop - 1
      For x = 1 To lg - 2
        
        ; Lecture du voisinage 3x3
        k = 0
        For dy = -1 To 1
          Protected *srcLine = \addr[0] + ((y + dy) * pitch)
          For dx = -1 To 1
            *srcPixel = *srcLine + ((x + dx) << 2)
            If k = 4 : getargb(*srcPixel\l, a, r3(k), g3(k), b3(k)) : Else : getrgb(*srcPixel\l, r3(k), g3(k), b3(k)) : EndIf
            k + 1
          Next
        Next
        
        ; Calcul des gradients (Gx et Gy) pour chaque angle
        sobel_4d_calc(x0, 2, 5, 8, 0, 3, 6)   : sobel_4d_calc(y0, 6, 7, 8, 0, 1, 2)
        sobel_4d_calc(x45, 1, 2, 5, 3, 6, 7)  : sobel_4d_calc(y45, 5, 8, 7, 1, 0, 3)
        sobel_4d_calc(x90, 6, 7, 8, 0, 1, 2)  : sobel_4d_calc(y90, 2, 5, 8, 0, 3, 6)
        sobel_4d_calc(x135, 7, 8, 5, 1, 0, 3) : sobel_4d_calc(y135, 3, 6, 7, 1, 2, 5)

        ; Calcul Magnitude Finale
        If mat ; ABS
          r0 = Abs(rx0)+Abs(ry0) : g0 = Abs(gx0)+Abs(gy0) : b0 = Abs(bx0)+Abs(by0)
          r45 = Abs(rx45)+Abs(ry45) : g45 = Abs(gx45)+Abs(gy45) : b45 = Abs(bx45)+Abs(by45)
          r90 = Abs(rx90)+Abs(ry90) : g90 = Abs(gx90)+Abs(gy90) : b90 = Abs(bx90)+Abs(by90)
          r135 = Abs(rx135)+Abs(ry135) : g135 = Abs(gx135)+Abs(gy135) : b135 = Abs(bx135)+Abs(by135)
        Else   ; SQR
          r0 = Sqr(rx0*rx0+ry0*ry0) : g0 = Sqr(gx0*gx0+gy0*gy0) : b0 = Sqr(bx0*bx0+by0*by0)
          r45 = Sqr(rx45*rx45+ry45*ry45) : g45 = Sqr(gx45*gx45+gy45*gy45) : b45 = Sqr(bx45*bx45+by45*by45)
          r90 = Sqr(rx90*rx90+ry90*ry90) : g90 = Sqr(gx90*gx90+gy90*gy90) : b90 = Sqr(bx90*bx90+by90*by90)
          r135 = Sqr(rx135*rx135+ry135*ry135) : g135 = Sqr(gx135*gx135+gy135*gy135) : b135 = Sqr(bx135*bx135+by135*by135)
        EndIf

        ; Sélection du gradient maximal
        r = r0 : If r45 > r : r = r45 : EndIf : If r90 > r : r = r90 : EndIf : If r135 > r : r = r135 : EndIf
        g = g0 : If g45 > g : g = g45 : EndIf : If g90 > g : g = g90 : EndIf : If g135 > g : g = g135 : EndIf
        b = b0 : If b45 > b : b = b45 : EndIf : If b90 > b : b = b90 : EndIf : If b135 > b : b = b135 : EndIf
        
        r * mul : g * mul : b * mul
        
        If r > 255 : r = 255 : EndIf
        If g > 255 : g = 255 : EndIf
        If b > 255 : b = 255 : EndIf
        
        If toGray : r = (r * 77 + g * 150 + b * 29) >> 8 : g = r : b = r : EndIf
        If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf

        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (a << 24) | (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3())
  EndWith
EndProcedure

Procedure Sobel_4dEx(*FilterCtx.FilterParams)
  Restore Sobel_4d_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@sobel_4d_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure Sobel_4d(source, cible, mask, multiply=10, math=0, gray=0, inverse=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = math
    \option[2] = gray
    \option[3] = inverse
  EndWith
  Sobel_4dEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Sobel_4d_data:
  Data.s "Sobel 4D"
  Data.s "Contours Sobel multidirectionnels (0°, 45°, 90°, 135°)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
  
  Data.s "Multiplicateur"
  Data.i 0, 100, 10
  Data.s "Math (0:SQR, 1:ABS)"
  Data.i 0, 1, 0
  Data.s "Noir et Blanc"
  Data.i 0, 1, 0
  Data.s "Inverser"
  Data.i 0, 1, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 32
; FirstLine = 9
; Folding = -
; EnableXP
; DPIAware