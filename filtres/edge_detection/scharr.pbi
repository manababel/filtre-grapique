Procedure Scharr_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.05
    Protected mat = \option[1]      ; 0: SQR, 1: ABS
    Protected toGray = \option[2]   ; Boolean
    Protected inverse = \option[3]  ; Boolean
    
    Protected Dim r3(8), Dim g3(8), Dim b3(8)
    Protected rx.f, gx.f, bx.f, ry.f, gy.f, by.f
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
            ; On récupère l'Alpha seulement sur le pixel central (k=4)
            If k = 4 : getargb(*srcPixel\l, a, r3(k), g3(k), b3(k)) : Else : getrgb(*srcPixel\l, r3(k), g3(k), b3(k)) : EndIf
            k + 1
          Next
        Next
        
        ; Gradient Horizontal (Gx)
        rx = (r3(2)*3 + r3(5)*10 + r3(8)*3) - (r3(0)*3 + r3(3)*10 + r3(6)*3)
        gx = (g3(2)*3 + g3(5)*10 + g3(8)*3) - (g3(0)*3 + g3(3)*10 + g3(6)*3)
        bx = (b3(2)*3 + b3(5)*10 + b3(8)*3) - (b3(0)*3 + b3(3)*10 + b3(6)*3)
        
        ; Gradient Vertical (Gy)
        ry = (r3(6)*3 + r3(7)*10 + r3(8)*3) - (r3(0)*3 + r3(1)*10 + r3(2)*3)
        gy = (g3(6)*3 + g3(7)*10 + g3(8)*3) - (g3(0)*3 + g3(1)*10 + g3(2)*3)
        by = (b3(6)*3 + b3(7)*10 + b3(8)*3) - (b3(0)*3 + b3(1)*10 + b3(2)*3)
        
        ; Magnitude
        If mat ; Mode Manhattan (ABS)
          r = (Abs(rx) + Abs(ry)) * mul
          g = (Abs(gx) + Abs(gy)) * mul
          b = (Abs(bx) + Abs(by)) * mul
        Else   ; Mode Euclidien (SQR)
          r = Sqr(rx*rx + ry*ry) * mul
          g = Sqr(gx*gx + gy*gy) * mul
          b = Sqr(bx*bx + by*by) * mul
        EndIf
        
        ; Traitement final (Limites, Gris, Inversion)
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

Procedure ScharrEx(*FilterCtx.FilterParams)
  Restore Scharr_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@Scharr_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure Scharr(source, cible, mask, multiply=10, math=0, gray=0, inverse=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = math
    \option[2] = gray
    \option[3] = inverse
  EndWith
  ScharrEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Scharr_data:
  Data.s "Scharr"
  Data.s "Détection de contours optimisée (Sobel amélioré)"
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
; CursorPosition = 13
; Folding = -
; EnableXP
; DPIAware