Macro Macro_Kayyali_calcul()
  ; Gx = (v\r[2] + v\r[5] + v\r[8]) - (v\r[0] + v\r[3] + v\r[6])
  ; Gy = (v\r[6] + v\r[7] + v\r[8]) - (v\r[0] + v\r[1] + v\r[2])
  
  If method = 0 ; --- MODE EUCLIDIENNE ---
    rx = (v\r[2] + v\r[5] + v\r[8]) - (v\r[0] + v\r[3] + v\r[6])
    ry = (v\r[6] + v\r[7] + v\r[8]) - (v\r[0] + v\r[1] + v\r[2])
    r = Sqr(rx * rx + ry * ry) * mul
    
    gx = (v\g[2] + v\g[5] + v\g[8]) - (v\g[0] + v\g[3] + v\g[6])
    gy = (v\g[6] + v\g[7] + v\g[8]) - (v\g[0] + v\g[1] + v\g[2])
    g = Sqr(gx * gx + gy * gy) * mul
    
    bx = (v\b[2] + v\b[5] + v\b[8]) - (v\b[0] + v\b[3] + v\b[6])
    by = (v\b[6] + v\b[7] + v\b[8]) - (v\b[0] + v\b[1] + v\b[2])
    b = Sqr(bx * bx + by * by) * mul
  Else          ; --- MODE MANHATTAN ---
    rx = (v\r[2] + v\r[5] + v\r[8]) - (v\r[0] + v\r[3] + v\r[6])
    ry = (v\r[6] + v\r[7] + v\r[8]) - (v\r[0] + v\r[1] + v\r[2])
    r = (Abs(rx) + Abs(ry)) * mul
    
    gx = (v\g[2] + v\g[5] + v\g[8]) - (v\g[0] + v\g[3] + v\g[6])
    gy = (v\g[6] + v\g[7] + v\g[8]) - (v\g[0] + v\g[1] + v\g[2])
    g = (Abs(gx) + Abs(gy)) * mul
    
    bx = (v\b[2] + v\b[5] + v\b[8]) - (v\b[0] + v\b[3] + v\b[6])
    by = (v\b[6] + v\b[7] + v\b[8]) - (v\b[0] + v\b[1] + v\b[2])
    b = (Abs(bx) + Abs(by)) * mul
  EndIf
EndMacro

Macro Macro_Kayyali_lecture_pixel3x3()
  pos = ((y - 1) * lg) + (x - 1)
  getrgb(*src\pixel[pos + 0], v\r[0], v\g[0], v\b[0])
  getrgb(*src\pixel[pos + 1], v\r[1], v\g[1], v\b[1])
  getrgb(*src\pixel[pos + 2], v\r[2], v\g[2], v\b[2])
  pos + lg
  getrgb( *src\pixel[pos + 0],    v\r[3], v\g[3], v\b[3])
  getargb(*src\pixel[pos + 1], a, v\r[4], v\g[4], v\b[4])
  getrgb( *src\pixel[pos + 2],    v\r[5], v\g[5], v\b[5])
  pos + lg  
  getrgb(*src\pixel[pos + 0], v\r[6], v\g[6], v\b[6])
  getrgb(*src\pixel[pos + 1], v\r[7], v\g[7], v\b[7]) 
  getrgb(*src\pixel[pos + 2], v\r[8], v\g[8], v\b[8])
EndMacro

Procedure Kayyali_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul = \option[0] * 1024
    Protected method = \option[1]
    Protected toGray = \option[2]
    Protected inverse = \option[3]
    Protected seuil_bas  = \option[4]
    Protected seuil_haut = \option[5]
    Protected v.edge_detection
    Protected a, r, g, b, x, y , pos
    Protected rx, gx, bx, ry, gy, by
    Protected *src.pixelarray32
    Protected *dst.Pixelarray32    
    *src = \addr[2]
    *dst = \addr[1]

    macro_calul_tread(ht)
    If thread_start < 1 : thread_start = 1 : EndIf
    If thread_stop > ht - 2 : thread_stop = ht - 2 : EndIf
    
    For y = thread_start To thread_stop
      For x = 1 To lg - 2
        Macro_Kayyali_lecture_pixel3x3()
        
        If toGray 
          v\r[0] = (v\r[0] * 77 + v\g[0] * 150 + v\b[0] * 29) >> 8
          v\r[1] = (v\r[1] * 77 + v\g[1] * 150 + v\b[1] * 29) >> 8
          v\r[2] = (v\r[2] * 77 + v\g[2] * 150 + v\b[2] * 29) >> 8
          v\r[3] = (v\r[3] * 77 + v\g[3] * 150 + v\b[3] * 29) >> 8
          v\r[5] = (v\r[5] * 77 + v\g[5] * 150 + v\b[5] * 29) >> 8
          v\r[6] = (v\r[6] * 77 + v\g[6] * 150 + v\b[6] * 29) >> 8
          v\r[7] = (v\r[7] * 77 + v\g[7] * 150 + v\b[7] * 29) >> 8
          v\r[8] = (v\r[8] * 77 + v\g[8] * 150 + v\b[8] * 29) >> 8
          
          ; On injecte la luminance pure de v\r dans la macro en court-circuitant les calculs G et B
          rx = (v\r[2] + v\r[5] + v\r[8]) - (v\r[0] + v\r[3] + v\r[6])
          ry = (v\r[6] + v\r[7] + v\r[8]) - (v\r[0] + v\r[1] + v\r[2])
          
          If method = 0
            r = Sqr(rx * rx + ry * ry) * mul
          Else
            r = (Abs(rx) + Abs(ry)) * mul
          EndIf
          r = r >> 16
          If inverse : r = 255 - r : EndIf
          g = r : b = r
        Else
          Macro_Kayyali_calcul()
          r = r >> 16
          g = g >> 16
          b = b >> 16
          clamp_rgb(r , g , b)
          If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
        EndIf

        If seuil_bas  >   0 : seuil_min_rgb(seuil_bas  , r , g , b) : EndIf
        If seuil_haut < 255 : seuil_max_rgb(seuil_haut , r , g , b) : EndIf
        
        *dst\Pixel[(y * lg) + x] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure Kayyali_bords(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y
    Protected *dst.Pixelarray32 = \addr[1]
    
    For y = 1 To ht - 2
      *dst\pixel[y * lg] = *dst\pixel[y * lg + 1]
      *dst\pixel[(y * lg) + lg - 1] = *dst\pixel[(y * lg) + lg - 2]
    Next
    
    Protected top_line_offset = 0
    Protected sec_line_offset = lg
    For x = 0 To lg - 1
      *dst\pixel[top_line_offset + x] = *dst\pixel[sec_line_offset + x]
    Next
    
    Protected last_line_offset = (ht - 1) * lg
    Protected prev_line_offset = (ht - 2) * lg
    For x = 0 To lg - 1
      *dst\pixel[last_line_offset + x] = *dst\pixel[prev_line_offset + x]
    Next
  EndWith
EndProcedure

Procedure KayyaliEx(*FilterCtx.FilterParams)
  Restore Kayyali_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  With *FilterCtx
    Protected size = \image_lg[0] * \image_ht[0] * 4
    If \addr[1] = \addr[0]
      \addr[2] = AllocateMemory(size)
      If \addr[2]
        CopyMemory(\addr[0] , \addr[2] , size)
        Create_MultiThread_MT(@Kayyali_MT())
        Kayyali_bords(*FilterCtx)
        FreeMemory(\addr[2]) 
      EndIf
    Else
      \addr[2] = \addr[0]
      Create_MultiThread_MT(@Kayyali_MT())
      Kayyali_bords(*FilterCtx)
    EndIf  
    mask_update(*FilterCtx, last_data) 
  EndWith
EndProcedure

Procedure Kayyali(source, cible, mask, multiply=10, method=1, gray=0, inverse=0, seuil_bas = 0, seuil_haut = 255)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = method
    \option[2] = gray
    \option[3] = inverse
    \option[4] = seuil_bas
    \option[5] = seuil_haut
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
  Data.s "seuil bas"
  Data.i 0, 255, 0
  Data.s "seuil haut"
  Data.i 0, 255, 255
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 91
; FirstLine = 69
; Folding = --
; EnableXP
; DPIAware