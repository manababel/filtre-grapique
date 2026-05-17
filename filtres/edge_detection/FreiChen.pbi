Procedure FreiChen_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.05
    Protected toGray = \option[1]   ; Boolean
    Protected inverse = \option[2]  ; Boolean
    
    Protected Dim r3.f(8), Dim g3.f(8), Dim b3.f(8), Dim gray.f(8)
    Protected Dim mask.f(7, 8)
    Protected.f rMax, gMax, bMax, maxVal, valGray, valR, valG, valB
    Protected *srcPixel.Pixel32, *dstPixel.Pixel32
    Protected a, r, g, b, x, y, i, dir, k, pitch = lg << 2
    Protected dx , dy , gr
    
    ; Chargement des masques Frei-Chen (8 directions, valeurs flottantes)
    Restore FreiChen_kernel
    For dir = 0 To 7 : For i = 0 To 8 : Read.f mask(dir, i) : Next : Next
    
    macro_calul_tread(ht)
    
    ; Protection des bords pour le noyau 3x3
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
            ; Extraction des canaux
            Protected cr, cg, cb
            If k = 4 : getargb(*srcPixel\l, a, cr, cg, cb) : Else : getrgb(*srcPixel\l, cr, cg, cb) : EndIf
            r3(k) = cr : g3(k) = cg : b3(k) = cb
            If toGray : gr = (cr * 77 + cg * 150 + cb * 29) >> 8 : gray(k) = gr :EndIf
            k + 1
          Next
        Next
        
        If toGray
          maxVal = 0.0
          For dir = 0 To 7
            valGray = 0.0
            For i = 0 To 8 : valGray + gray(i) * mask(dir, i) : Next
            valGray = Abs(valGray)
            If valGray > maxVal : maxVal = valGray : EndIf
          Next
          r = maxVal * mul : g = r : b = r
        Else
          rMax = 0.0 : gMax = 0.0 : bMax = 0.0
          For dir = 0 To 7
            valR = 0.0 : valG = 0.0 : valB = 0.0
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
        
        ; Finalisation des couleurs (Clamping et Inversion)
        If r > 255 : r = 255 : ElseIf r < 0 : r = 0 : EndIf
        If g > 255 : g = 255 : ElseIf g < 0 : g = 0 : EndIf
        If b > 255 : b = 255 : ElseIf b < 0 : b = 0 : EndIf
        
        If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf

        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (a << 24) | (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
    
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3()) : FreeArray(gray()) : FreeArray(mask())
  EndWith
EndProcedure

Procedure FreiChenEx(*FilterCtx.FilterParams)
  Restore FreiChen_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@FreiChen_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure FreiChen(source, cible, mask, multiply=10, gray=0, inverse=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = gray
    \option[2] = inverse
  EndWith
  FreiChenEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  FreiChen_data:
  Data.s "Frei-Chen"
  Data.s "Détection de contours par masques normalisés (Précision Flottante)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
  
  Data.s "Multiplicateur"
  Data.i 1, 100, 10
  Data.s "Noir et Blanc"
  Data.i 0, 1, 0
  Data.s "Inverser"
  Data.i 0, 1, 0
  Data.s "XXX"

  FreiChen_kernel:
  ; M1 (Nord)
  Data.f  1,  1.4142,  1,       0,   0,   0,      -1, -1.4142, -1
  ; M2 (Nord-Est)
  Data.f  0,  1,       1.4142, -1,   0,   1.4142, -1, -1,      0
  ; M3 (Est)
  Data.f -1,  0,       1,      -1,   0,   1,      -1,  0,      1
  ; M4 (Sud-Est)
  Data.f -1, -1.4142,  0,      -1,   0,   1.4142,  0,  1.4142, 1
  ; M5 (Sud)
  Data.f -1, -1.4142, -1,       0,   0,   0,       1,  1.4142, 1
  ; M6 (Sud-Ouest)
  Data.f  0, -1,      -1.4142,  1,   0,  -1.4142,  1,  1,      0
  ; M7 (Ouest)
  Data.f  1,  0,      -1,       1,   0,  -1,       1,  0,     -1
  ; M8 (Nord-Ouest)
  Data.f  1,  1.4142,  0,       1,   0,  -1.4142,  0, -1.4142,-1
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 38
; Folding = -
; EnableXP
; DPIAware