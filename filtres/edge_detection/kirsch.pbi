Procedure Kirsch_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.05
    Protected toGray = \option[1]   ; Boolean
    Protected inverse = \option[2]  ; Boolean
    
    Protected Dim r3(8), Dim g3(8), Dim b3(8), Dim gray(8)
    Protected Dim mask(7, 8)
    Protected rMax, gMax, bMax, maxVal, valGray, valR, valG, valB
    Protected *srcPixel.Pixel32, *dstPixel.Pixel32
    Protected a, r, g, b, x, y, i, dir, k, pitch = lg << 2
    Protected dx , dy
    
    ; Chargement des masques Kirsch (8 directions)
    Restore kirsch_kernel
    For dir = 0 To 7 : For i = 0 To 8 : Read.i mask(dir, i) : Next : Next
    
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
          maxVal = 0
          For dir = 0 To 7
            valGray = 0
            For i = 0 To 8 : valGray + gray(i) * mask(dir, i) : Next
            valGray = Abs(valGray)
            If valGray > maxVal : maxVal = valGray : EndIf
          Next
          r = maxVal * mul : g = r : b = r
        Else
          rMax = 0 : gMax = 0 : bMax = 0
          For dir = 0 To 7
            valR = 0 : valG = 0 : valB = 0
            For i = 0 To 8
              valR + r3(i) * mask(dir, i)
              valG + g3(i) * mask(dir, i)
              valB + b3(i) * mask(dir, i)
            Next
            valR = Abs(valR) : valG = Abs(valG) : valB = Abs(valB)
            If valR > rMax : rMax = valR : EndIf
            If valG > gMax : gMax = valG : EndIf
            If valB > bMax : bMax = valB : EndIf
          Next
          r = rMax * mul : g = gMax * mul : b = bMax * mul
        EndIf
        
        ; Traitement final
        If r > 255 : r = 255 : EndIf
        If g > 255 : g = 255 : EndIf
        If b > 255 : b = 255 : EndIf
        If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf

        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (a << 24) | (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
    
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3()) : FreeArray(gray()) : FreeArray(mask())
  EndWith
EndProcedure

Procedure KirschEx(*FilterCtx.FilterParams)
  Restore Kirsch_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@Kirsch_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure Kirsch(source, cible, mask, multiply=10, gray=0, inverse=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = gray
    \option[2] = inverse
  EndWith
  KirschEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Kirsch_data:
  Data.s "Kirsch"
  Data.s "Détection de contours par boussole 8 directions"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
  
  Data.s "Multiplicateur"
  Data.i 1, 100, 10
  Data.s "Noir et Blanc"
  Data.i 0, 1, 0
  Data.s "Inverser"
  Data.i 0, 1, 0
  Data.s "XXX"

  kirsch_kernel:
  Data.i  5,  5,  5, -3,  0, -3, -3, -3, -3 ; N
  Data.i  5,  5, -3,  5,  0, -3, -3, -3, -3 ; NE
  Data.i -3,  5,  5, -3,  0,  5, -3, -3, -3 ; E
  Data.i -3, -3,  5, -3,  0,  5, -3, -3,  5 ; SE
  Data.i -3, -3, -3, -3,  0, -3,  5,  5,  5 ; S
  Data.i -3, -3, -3, -3,  0,  5,  5,  5, -3 ; SW
  Data.i -3, -3, -3,  5,  0,  5,  5, -3, -3 ; W
  Data.i  5, -3, -3,  5,  0, -3,  5, -3, -3 ; NW
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 14
; FirstLine = 7
; Folding = -
; EnableXP
; DPIAware