Procedure Laplacian_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0]
    Protected mode = \option[1] ; 0 ou 1 pour type Laplacian
    Protected toGray = \option[2]
    Protected inverse = \option[3]

    clamp(mul, 0, 100)
    mul = mul * 0.1

    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected Dim r3(9)
    Protected Dim g3(9)
    Protected Dim b3(9)
    Protected a, r, g, b
    Protected x, y
    
    macro_calul_tread((ht - 2))
    Protected startPos = thread_start + 1
    Protected endPos   = thread_stop + 1

    If startPos < 1 : startPos = 1 : EndIf
    If endPos > ht - 2 : endPos = ht - 2 : EndIf

    For y = startPos To endPos
      For x = 1 To lg - 2
        ; Lecture des 9 pixels voisins 3x3 autour de (x, y)
        *srcPixel = (*source + ((y - 1) * lg + (x - 1)) * 4)
        getrgb(*srcPixel\l, r3(0), g3(0), b3(0))
        *srcPixel = *srcPixel + 4
        getrgb(*srcPixel\l, r3(1), g3(1), b3(1))
        *srcPixel = *srcPixel + 4
        getrgb(*srcPixel\l, r3(2), g3(2), b3(2))
        *srcPixel = (*source + (y * lg + (x - 1)) * 4)
        getrgb(*srcPixel\l, r3(3), g3(3), b3(3))
        *srcPixel = *srcPixel + 4
        getargb(*srcPixel\l, a, r3(4), g3(4), b3(4)) ; lecture alpha
        *srcPixel = *srcPixel + 4
        getrgb(*srcPixel\l, r3(5), g3(5), b3(5))
        *srcPixel = (*source + ((y + 1) * lg + (x - 1)) * 4)
        getrgb(*srcPixel\l, r3(6), g3(6), b3(6))
        *srcPixel = *srcPixel + 4
        getrgb(*srcPixel\l, r3(7), g3(7), b3(7))
        *srcPixel = *srcPixel + 4
        getrgb(*srcPixel\l, r3(8), g3(8), b3(8))

        ; Application du masque Laplacian
        If mode = 0
          r = (r3(1) + r3(3) + r3(5) + r3(7)) - (4 * r3(4))
          g = (g3(1) + g3(3) + g3(5) + g3(7)) - (4 * g3(4))
          b = (b3(1) + b3(3) + b3(5) + b3(7)) - (4 * b3(4))
        Else
          r = (r3(0) + r3(1) + r3(2) + r3(3) + r3(5) + r3(6) + r3(7) + r3(8)) - (8 * r3(4))
          g = (g3(0) + g3(1) + g3(2) + g3(3) + g3(5) + g3(6) + g3(7) + g3(8)) - (8 * g3(4))
          b = (b3(0) + b3(1) + b3(2) + b3(3) + b3(5) + b3(6) + b3(7) + b3(8)) - (8 * b3(4))
        EndIf

        r = r * mul
        g = g * mul
        b = b * mul
        clamp_rgb(r, g, b)

        If toGray
          r = (r * 77 + g * 150 + b * 29) >> 8 : g = r : b = r
        EndIf

        If inverse
          r = 255 - r : g = 255 - g : b = 255 - b
        EndIf

        *dstPixel = (*cible + (y * lg + x) * 4)
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure LaplacianEx(*FilterCtx.FilterParams)
  
  Restore Laplacian_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@Laplacian_MT())
  
  mask_update(*FilterCtx.FilterParams , last_data)
  
EndProcedure

Procedure Laplacian(source , cible , mask , multiply , mode , noir_et_blanc , inversion)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = mode
    \option[2] = noir_et_blanc
    \option[3] = inversion
  EndWith
  LaplacianEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Laplacian_data:
  Data.s "Laplacian"
  Data.s ""
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Laplacian
  
  Data.s "multiply"        
  Data.i 0,100,10
  Data.s "mode"   
  Data.i 0,1,0
  Data.s "Noir et blanc"        
  Data.i 0,1,0
  Data.s "inversion"  
  Data.i 0,1,0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 22
; FirstLine = 2
; Folding = -
; EnableXP
; DPIAware