Procedure Laplacian_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected mul.f = *param\option[0]
  Protected mode = *param\option[1] ; 0 ou 1 pour type Laplacian
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]

  clamp(mul, 0, 100)
  mul = mul * 0.1

  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected Dim r3(9)
  Protected Dim g3(9)
  Protected Dim b3(9)
  Protected a, r, g, b
  Protected x, y
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max + 1
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max + 1
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
EndProcedure
  
Procedure Laplacian(*param.parametre)
  ; Affichage des informations de configuration si demandé
  If param\info_active
    param\typ = #FilterType_EdgeDetection
    param\subtype = #EdgeDetect_Laplacian
    param\name = "Laplacian"
    param\remarque = ""
    param\info[0] = "multiply"             
    param\info[1] = "mode"            
    param\info[2] = "Noir et blanc"       
    param\info[3] = "inversion"           
    param\info[4] = "Masque binaire"           
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100  : param\info_data(0,2) = 10 ;
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0 
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1  : param\info_data(2,2) = 0 
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1  : param\info_data(3,2) = 0 
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2  : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Laplacian_MT() , 4)
EndProcedure



; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 81
; FirstLine = 37
; Folding = -
; EnableXP
; DPIAware