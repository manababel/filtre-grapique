Procedure Kayyali_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.1
    Protected method = \option[1]  ; 0 = Euclidienne, 1 = Manhattan
    Protected toGray = \option[2]  ; Boolean
    Protected inverse = \option[3] ; Boolean
    
    Protected Dim r3(8), Dim g3(8), Dim b3(8), Dim gray(8)
    Protected rx, gx, bx, ry, gy, by, magnitude
    Protected *srcPixel.Pixel32, *dstPixel.Pixel32
    Protected a, r, g, b, x, y, k, pitch = lg << 2
    Protected dx , dy
    macro_calul_tread(ht)
    
    ; Protection des bords
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
            If toGray : gray(k) = (r3(k) * 77 + g3(k) * 150 + b3(k) * 29) >> 8 : EndIf
            k + 1
          Next
        Next
        
        If toGray
          ; Gradient Kayyali Gx/Gy sur niveaux de gris
          rx = (gray(2) + gray(5) + gray(8)) - (gray(0) + gray(3) + gray(6))
          ry = (gray(6) + gray(7) + gray(8)) - (gray(0) + gray(1) + gray(2))
          
          If method = 0
            magnitude = Sqr(rx * rx + ry * ry) * mul
          Else
            magnitude = (Abs(rx) + Abs(ry)) * mul
          EndIf
          r = magnitude : g = magnitude : b = magnitude
        Else
          ; Gradient Kayyali sur canaux RGB
          rx = (r3(2) + r3(5) + r3(8)) - (r3(0) + r3(3) + r3(6))
          gx = (g3(2) + g3(5) + g3(8)) - (g3(0) + g3(3) + g3(6))
          bx = (b3(2) + b3(5) + b3(8)) - (b3(0) + b3(3) + b3(6))
          
          ry = (r3(6) + r3(7) + r3(8)) - (r3(0) + r3(1) + r3(2))
          gy = (g3(6) + g3(7) + g3(8)) - (g3(0) + g3(1) + g3(2))
          by = (b3(6) + b3(7) + b3(8)) - (b3(0) + b3(1) + b3(2))
          
          If method = 0
            r = Sqr(rx * rx + ry * ry) * mul
            g = Sqr(gx * gx + gy * gy) * mul
            b = Sqr(bx * bx + by * by) * mul
          Else
            r = (Abs(rx) + Abs(ry)) * mul
            g = (Abs(gx) + Abs(gy)) * mul
            b = (Abs(bx) + Abs(by)) * mul
          EndIf
        EndIf
        
        ; Traitement final (Clamping et Inversion)
        If r > 255 : r = 255 : ElseIf r < 0 : r = 0 : EndIf
        If g > 255 : g = 255 : ElseIf g < 0 : g = 0 : EndIf
        If b > 255 : b = 255 : ElseIf b < 0 : b = 0 : EndIf
        
        If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf

        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (a << 24) | (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
    
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3()) : FreeArray(gray())
  EndWith
EndProcedure

Procedure KayyaliEx(*FilterCtx.FilterParams)
  Restore Kayyali_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@Kayyali_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure Kayyali(source, cible, mask, multiply=10, method=1, gray=0, inverse=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = method
    \option[2] = gray
    \option[3] = inverse
  EndWith
  KayyaliEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Kayyali_data:
  Data.s "Kayyali"
  Data.s "Détection de contours rapide (Opérateur de Kayyali)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
  
  Data.s "Multiplicateur"
  Data.i 1, 100, 10
  Data.s "Méthode (Eucl/Manh)"
  Data.i 0, 1, 1
  Data.s "Noir et Blanc"
  Data.i 0, 1, 0
  Data.s "Inverser"
  Data.i 0, 1, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 13
; FirstLine = 6
; Folding = -
; EnableXP
; DPIAware