Procedure Prewitt_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.05
    Protected toGray = \option[2]
    Protected inverse = \option[3]
    
    ; Arrays pour les valeurs RGB du voisinage 3x3
    Protected Dim r3(8), Dim g3(8), Dim b3(8)
    ; Masques Prewitt pour les 8 directions
    Protected Dim mask(7, 8)
    
    Protected a, r, g, b, x, y, i, dir
    Protected valR, valG, valB, rMax, gMax, bMax
    Protected *srcPixel.Pixel32, *dstPixel.Pixel32
    Protected pitch = lg << 2
    Protected dx , dy
    
    ; Initialisation des masques de direction
    Restore Prewitt_Masks
    For dir = 0 To 7
      For i = 0 To 8
        Read.i mask(dir, i)
      Next
    Next

    macro_calul_tread(ht)
    
    ; On évite les bords (1 à ht-2)
    If thread_start < 1 : thread_start = 1 : EndIf
    If thread_stop > ht - 1 : thread_stop = ht - 1 : EndIf

    For y = thread_start To thread_stop - 1
      For x = 1 To lg - 2
        
        ; Lecture du voisinage 3x3
        Protected k = 0
        For dy = -1 To 1
          Protected *srcLine = \addr[0] + ((y + dy) * pitch)
          For dx = -1 To 1
            *srcPixel = *srcLine + ((x + dx) << 2)
            If k = 4 ; Pixel central : on récupère l'alpha
              getargb(*srcPixel\l, a, r3(k), g3(k), b3(k))
            Else
              getrgb(*srcPixel\l, r3(k), g3(k), b3(k))
            EndIf
            k + 1
          Next
        Next

        ; Calcul du gradient maximum parmi les 8 directions
        rMax = 0 : gMax = 0 : bMax = 0
        For dir = 0 To 7
          valR = 0 : valG = 0 : valB = 0
          For i = 0 To 8
            valR + r3(i) * mask(dir, i)
            valG + g3(i) * mask(dir, i)
            valB + b3(i) * mask(dir, i)
          Next
          
          ; Valeur absolue pour la magnitude
          valR = Abs(valR) : valG = Abs(valG) : valB = Abs(valB)
          
          If valR > rMax : rMax = valR : EndIf
          If valG > gMax : gMax = valG : EndIf
          If valB > bMax : bMax = valB : EndIf
        Next

        r = rMax * mul : g = gMax * mul : b = bMax * mul
        
        ; Clamping
        If r > 255 : r = 255 : EndIf
        If g > 255 : g = 255 : EndIf
        If b > 255 : b = 255 : EndIf
        
        If toGray
          r = (r * 77 + g * 150 + b * 29) >> 8
          g = r : b = r
        EndIf

        If inverse
          r = 255 - r : g = 255 - g : b = 255 - b
        EndIf

        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next

    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3()) : FreeArray(mask())
  EndWith
EndProcedure

Procedure PrewittEx(*FilterCtx.FilterParams)
  Restore Prewitt_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@Prewitt_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure Prewitt(source, cible, mask, multiplicateur=10, noir_blanc=0, inversion=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiplicateur
    \option[1] = 0 ; Réservé pour compatibilité structure
    \option[2] = noir_blanc
    \option[3] = inversion
  EndWith
  PrewittEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Prewitt_data:
  Data.s "Prewitt"
  Data.s "Détection de contours par l'opérateur de Prewitt (8 directions)"
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

  Prewitt_Masks:
  Data.i  1, 1, 1,  0, 0, 0, -1,-1,-1 ; N
  Data.i  0, 1, 1, -1, 0, 1, -1,-1, 0 ; NE
  Data.i -1, 0, 1, -1, 0, 1, -1, 0, 1 ; E
  Data.i -1,-1, 0, -1, 0, 1,  0, 1, 1 ; SE
  Data.i -1,-1,-1,  0, 0, 0,  1, 1, 1 ; S
  Data.i  0,-1,-1,  1, 0,-1,  1, 1, 0 ; SW
  Data.i  1, 0,-1,  1, 0,-1,  1, 0,-1 ; W
  Data.i  1, 1, 0,  1, 0,-1,  0,-1,-1 ; NW
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 18
; Folding = -
; EnableXP
; DPIAware