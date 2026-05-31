Macro Macro_Sobel_calcul_gray()
  v\r[0] = (v\r[0] * 77 + v\g[0] * 150 + v\b[0] * 29) >> 8
  v\r[1] = (v\r[1] * 77 + v\g[1] * 150 + v\b[1] * 29) >> 8
  v\r[2] = (v\r[2] * 77 + v\g[2] * 150 + v\b[2] * 29) >> 8
  v\r[3] = (v\r[3] * 77 + v\g[3] * 150 + v\b[3] * 29) >> 8
  ; v\r[4] est le pixel central
  v\r[5] = (v\r[5] * 77 + v\g[5] * 150 + v\b[5] * 29) >> 8
  v\r[6] = (v\r[6] * 77 + v\g[6] * 150 + v\b[6] * 29) >> 8
  v\r[7] = (v\r[7] * 77 + v\g[7] * 150 + v\b[7] * 29) >> 8
  v\r[8] = (v\r[8] * 77 + v\g[8] * 150 + v\b[8] * 29) >> 8
  rx = (v\r[2] + (v\r[5] << 1) + v\r[8]) - (v\r[0] + (v\r[3] << 1) + v\r[6])
  ry = (v\r[6] + (v\r[7] << 1) + v\r[8]) - (v\r[0] + (v\r[1] << 1) + v\r[2])
  r = (Sqr(rx * rx + ry * ry) * mul)
  r = r >> 16
  clamp(r, 0, 255)
  If inverse : r = 255 - r : EndIf
  g = r : b = r
EndMacro

Macro Macro_Sobel_calcul()
   rx = (v\r[2] + (v\r[5] << 1) + v\r[8]) - (v\r[0] + (v\r[3] << 1) + v\r[6])
   gx = (v\g[2] + (v\g[5] << 1) + v\g[8]) - (v\g[0] + (v\g[3] << 1) + v\g[6])
   bx = (v\b[2] + (v\b[5] << 1) + v\b[8]) - (v\b[0] + (v\b[3] << 1) + v\b[6])
   ry = (v\r[6] + (v\r[7] << 1) + v\r[8]) - (v\r[0] + (v\r[1] << 1) + v\r[2])
   gy = (v\g[6] + (v\g[7] << 1) + v\g[8]) - (v\g[0] + (v\g[1] << 1) + v\g[2])
   by = (v\b[6] + (v\b[7] << 1) + v\b[8]) - (v\b[0] + (v\b[1] << 1) + v\b[2])
  valR = Sqr(rx * rx + ry * ry)
  valG = Sqr(gx * gx + gy * gy)
  valB = Sqr(bx * bx + by * by)
  r = (valR * mul) >> 16
  g = (valG * mul) >> 16
  b = (valB * mul) >> 16
  clamp_rgb(r , g , b)
  If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
EndMacro

Macro Macro_Sobel_lecture_pixel3x3()
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

Procedure Sobel_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul = \option[0]
    Protected toGray = \option[1]
    Protected inverse = \option[2]
    Protected seuil_bas  = \option[3]  ; AJOUT OPTION
    Protected seuil_haut = \option[4]  ; AJOUT OPTION
    Protected v.edge_detection
    Protected a, r, g, b, x, y , pos
    Protected rx , ry , gx , gy , bx , by 
    Protected valR, valG, valB
    Protected *src.pixelarray32
    Protected *dst.Pixelarray32    
    *src = \addr[2]
    *dst = \addr[1]
    mul = (mul * 1024)
    macro_calul_tread(ht)
    If thread_start < 1 : thread_start = 1 : EndIf
    If thread_stop > ht - 2 : thread_stop = ht - 2 : EndIf
    For y = thread_start To thread_stop
      For x = 1 To lg - 2
        Macro_Sobel_lecture_pixel3x3()
        If toGray
          Macro_Sobel_calcul_gray()
        Else
          Macro_Sobel_calcul()
        EndIf
        If seuil_bas  >   0 : seuil_min_rgb(seuil_bas  , r , g , b) : EndIf
        If seuil_haut < 255 : seuil_max_rgb(seuil_haut , r , g , b) : EndIf
        *dst\Pixel[(y * lg) + x] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure Sobel_bords(*FilterCtx.FilterParams)
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

Procedure SobelEx(*FilterCtx.FilterParams)
  Restore Sobel_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  With *FilterCtx
    Protected size = \image_lg[0] * \image_ht[0] * 4
    If \addr[1] = \addr[0]
      \addr[2] = AllocateMemory(size)
      If \addr[2]
        CopyMemory(\addr[0] , \addr[2] , size)
        Create_MultiThread_MT(@Sobel_MT())
        Sobel_bords(*FilterCtx)
        FreeMemory(\addr[2]) 
      EndIf
    Else
      \addr[2] = \addr[0]
      Create_MultiThread_MT(@Sobel_MT())
      Sobel_bords(*FilterCtx)
    EndIf  
    mask_update(*FilterCtx, last_data) 
  EndWith
EndProcedure

Procedure Sobel(source, cible, mask, multiplicateur=10, noir_blanc=0, inversion=0, seuil_bas = 0, seuil_haut = 255)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiplicateur
    \option[1] = noir_blanc
    \option[2] = inversion
    \option[3] = seuil_bas
    \option[4] = seuil_haut
  EndWith
  SobelEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Sobel_data:
  Data.s "Sobel"
  Data.s "Détection de contours par l'opérateur de Sobel 3x3 (Magnitude seule)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
   
  Data.s "Multiplicateur"
  Data.i 0, 100, 25
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
; CursorPosition = 112
; FirstLine = 95
; Folding = --
; EnableXP
; DPIAware
; DisableDebugger