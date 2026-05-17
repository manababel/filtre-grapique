; ============================================================================
; Filtre Sobel - Détection de contours optimisé
; ============================================================================

Procedure Sobel_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.05
    Protected mat = \option[1]      ; 0: Euclidienne, 1: Manhattan
    Protected toGray = \option[2]   ; Boolean
    Protected inverse = \option[3]  ; Boolean
    
    ; Tableaux pour le voisinage 3x3
    Protected Dim r3(8), Dim g3(8), Dim b3(8), Dim gray(8)
    
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected a, r, g, b, x, y, dx, dy, k
    Protected rx, gx, bx, ry, gy, by
    Protected magnitude, pitch = lg << 2
    
    macro_calul_tread(ht)
    
    ; On évite les bords (1 à ht-2)
    If thread_start < 1 : thread_start = 1 : EndIf
    If thread_stop > ht - 1 : thread_stop = ht - 1 : EndIf
    
    For y = thread_start To thread_stop - 1
      For x = 1 To lg - 2
        
        ; --- Lecture du voisinage 3x3 ---
        k = 0
        For dy = -1 To 1
          Protected *srcLine = \addr[0] + ((y + dy) * pitch)
          For dx = -1 To 1
            *srcPixel = *srcLine + ((x + dx) << 2)
            If toGray
              getrgb(*srcPixel\l, r, g, b)
              gray(k) = (r * 77 + g * 150 + b * 29) >> 8
            Else
              If k = 4 ; On récupère l'alpha sur le pixel central
                getargb(*srcPixel\l, a, r3(k), g3(k), b3(k))
              Else
                getrgb(*srcPixel\l, r3(k), g3(k), b3(k))
              EndIf
            EndIf
            k + 1
          Next
        Next
        
        If toGray
          ; --- MODE NIVEAU DE GRIS ---
          ; Gx = [-1 0 1, -2 0 2, -1 0 1] | Gy = [-1 -2 -1, 0 0 0, 1 2 1]
          rx = (gray(2) + (gray(5) << 1) + gray(8)) - (gray(0) + (gray(3) << 1) + gray(6))
          ry = (gray(6) + (gray(7) << 1) + gray(8)) - (gray(0) + (gray(1) << 1) + gray(2))
          
          If mat = 0
            magnitude = Sqr(rx * rx + ry * ry) * mul
          Else
            magnitude = (Abs(rx) + Abs(ry)) * mul
          EndIf
          
          If magnitude > 255 : magnitude = 255 : EndIf
          If inverse : magnitude = 255 - magnitude : EndIf
          
          r = magnitude : g = magnitude : b = magnitude
          a = 255 ; Alpha opaque par défaut en détection de contours
        Else
          ; --- MODE COULEUR ---
          rx = (r3(2) + (r3(5) << 1) + r3(8)) - (r3(0) + (r3(3) << 1) + r3(6))
          gx = (g3(2) + (g3(5) << 1) + g3(8)) - (g3(0) + (g3(3) << 1) + g3(6))
          bx = (b3(2) + (b3(5) << 1) + b3(8)) - (b3(0) + (b3(3) << 1) + b3(6))
          
          ry = (r3(6) + (r3(7) << 1) + r3(8)) - (r3(0) + (r3(1) << 1) + r3(2))
          gy = (g3(6) + (g3(7) << 1) + g3(8)) - (g3(0) + (g3(1) << 1) + g3(2))
          by = (b3(6) + (b3(7) << 1) + b3(8)) - (b3(0) + (b3(1) << 1) + b3(2))
          
          If mat = 0
            r = Sqr(rx * rx + ry * ry) * mul
            g = Sqr(gx * gx + gy * gy) * mul
            b = Sqr(bx * bx + by * by) * mul
          Else
            r = (Abs(rx) + Abs(ry)) * mul
            g = (Abs(gx) + Abs(gy)) * mul
            b = (Abs(bx) + Abs(by)) * mul
          EndIf
          
          If r > 255 : r = 255 : EndIf
          If g > 255 : g = 255 : EndIf
          If b > 255 : b = 255 : EndIf
          
          If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
        EndIf
        
        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
    
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3()) : FreeArray(gray())
  EndWith
EndProcedure

Procedure SobelEx(*FilterCtx.FilterParams)
  Restore Sobel_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@Sobel_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure Sobel(source, cible, mask, multiplicateur=10, methode=0, noir_blanc=0, inversion=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiplicateur
    \option[1] = methode
    \option[2] = noir_blanc
    \option[3] = inversion
  EndWith
  SobelEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Sobel_data:
  Data.s "Sobel"
  Data.s "Détection de contours par gradient (Opérateur de Sobel 3x3)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
  
  Data.s "Multiplicateur"
  Data.i 1, 100, 10
  Data.s "Méthode (0=Eucl, 1=Manh)"
  Data.i 0, 1, 0
  Data.s "Noir et Blanc"
  Data.i 0, 1, 0
  Data.s "Inverser"
  Data.i 0, 1, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 114
; FirstLine = 92
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger