Procedure NevatiaBabu_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.000025
    Protected toGray = \option[1]   ; Boolean
    Protected inverse = \option[2]  ; Boolean
    
    Protected Dim r3(24), Dim g3(24), Dim b3(24), Dim gray(24)
    Protected Dim NBmask(5, 24)
    Protected.q rx, gx, bx, val, maxVal
    Protected *srcPixel.Pixel32, *dstPixel.Pixel32
    Protected a, r, g, b, x, y, i, j, m, k, pitch = lg << 2
    Protected dx , dy
    
    ; Chargement des 6 masques Nevatia-Babu (5x5) depuis la DataSection
    Restore NevatiaBabu_kernels
    For m = 0 To 5 : For i = 0 To 24 : Read.i NBmask(m, i) : Next : Next
    
    macro_calul_tread(ht)
    
    ; Protection des bords pour un noyau 5x5 (marge de 2 pixels)
    If thread_start < 2 : thread_start = 2 : EndIf
    If thread_stop > ht - 2 : thread_stop = ht - 2 : EndIf
    
    For y = thread_start To thread_stop - 1
      For x = 2 To lg - 3
        
        ; Lecture du voisinage 5x5
        k = 0
        For dy = -2 To 2
          Protected *srcLine = \addr[0] + ((y + dy) * pitch)
          For dx = -2 To 2
            *srcPixel = *srcLine + ((x + dx) << 2)
            ; On ne récupère l'alpha que sur le pixel central (facultatif mais propre)
            If k = 12 : getargb(*srcPixel\l, a, r3(k), g3(k), b3(k)) : Else : getrgb(*srcPixel\l, r3(k), g3(k), b3(k)) : EndIf
            If toGray : gray(k) = (r3(k) * 77 + g3(k) * 150 + b3(k) * 29) >> 8 : EndIf
            k + 1
          Next
        Next
        
        If toGray
          maxVal = 0
          For m = 0 To 5
            val = 0
            For i = 0 To 24 : val + gray(i) * NBmask(m, i) : Next
            val = Abs(val)
            If val > maxVal : maxVal = val : EndIf
          Next
          r = maxVal * mul : g = r : b = r
        Else
          rx = 0 : gx = 0 : bx = 0
          For m = 0 To 5
            Protected.q vR = 0, vG = 0, vB = 0
            For i = 0 To 24
              vR + r3(i) * NBmask(m, i)
              vG + g3(i) * NBmask(m, i)
              vB + b3(i) * NBmask(m, i)
            Next
            vR = Abs(vR) : vG = Abs(vG) : vB = Abs(vB)
            If vR > rx : rx = vR : EndIf
            If vG > gx : gx = vG : EndIf
            If vB > bx : bx = vB : EndIf
          Next
          r = rx * mul : g = gx * mul : b = bx * mul
        EndIf
        
        ; Traitement final (Limites et Inversion)
        If r > 255 : r = 255 : EndIf
        If g > 255 : g = 255 : EndIf
        If b > 255 : b = 255 : EndIf
        If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf

        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (a << 24) | (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
    
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3()) : FreeArray(gray()) : FreeArray(NBmask())
  EndWith
EndProcedure

Procedure NevatiaBabuEx(*FilterCtx.FilterParams)
  Restore NevatiaBabu_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@NevatiaBabu_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure NevatiaBabu(source, cible, mask, multiply=10, gray=0, inverse=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = gray
    \option[2] = inverse
  EndWith
  NevatiaBabuEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  NevatiaBabu_data:
  Data.s "Nevatia-Babu"
  Data.s "Détection de contours directionnelle 5x5 (6 masques)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
  
  Data.s "Multiplicateur"
  Data.i 1, 100, 10
  Data.s "Noir et Blanc"
  Data.i 0, 1, 0
  Data.s "Inverser"
  Data.i 0, 1, 0
  Data.s "XXX"

  NevatiaBabu_kernels:
  ; M0 - 0°
  Data.i  100, 100, 100, 100, 100,  100, 100, 100, 100, 100,  0, 0, 0, 0, 0, -100,-100,-100,-100,-100, -100,-100,-100,-100,-100
  ; M1 - 30°
  Data.i  100, 100, 100, 100, 0,  100, 100, 100, 0, -100,  100, 100, 0, -100,-100,  100, 0, -100,-100,-100,  0, -100,-100,-100,-100
  ; M2 - 60°
  Data.i  100, 100, 100, 0, -100,  100, 100, 0, -100,-100,  100, 0, -100,-100,-100,  0, -100,-100,-100,-100, -100,-100,-100,-100,-100
  ; M3 - 90°
  Data.i  0, 100, 100, 100, 0,  0, 100, 100, 100, 0,  0, 0, 0, 0, 0,  0, -100,-100,-100, 0,  0, -100,-100,-100, 0
  ; M4 - 120°
  Data.i  -100, 0, 100, 100, 100,  -100,-100, 0, 100, 100,  -100,-100,-100, 0, 100,  -100,-100,-100,-100, 0,  -100,-100,-100,-100,-100
  ; M5 - 150°
  Data.i  0, -100,-100,-100,-100,  100, 0, -100,-100,-100,  100, 100, 0, -100,-100,  100, 100, 100, 0, -100,  100, 100, 100, 100, 0
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 14
; FirstLine = 7
; Folding = -
; EnableXP
; DPIAware