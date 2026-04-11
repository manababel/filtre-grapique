Macro sobel_4d_sp1(v0 , v1 , v2 , v3 , v4 , v5 , v6 )
  Protected r#v0 = r3(v1) + 2 * r3(v2) + r3(v3) - (r3(v4) + 2 * r3(v5) + r3(v6))
  Protected g#v0 = g3(v1) + 2 * g3(v2) + g3(v3) - (g3(v4) + 2 * g3(v5) + g3(v6))
  Protected b#v0 = b3(v1) + 2 * b3(v2) + b3(v3) - (b3(v4) + 2 * b3(v5) + b3(v6))
EndMacro
    
Macro sobel_4d_sp2(v0)
  r#v0 = Abs(rx#v0) + Abs(ry#v0)
  g#v0 = Abs(gx#v0) + Abs(gy#v0)
  b#v0 = Abs(bx#v0) + Abs(by#v0)
EndMacro

Macro sobel_4d_sp3(v0)
  r#v0 = Sqr(rx#v0 * rx#v0 + ry#v0 * ry#v0)
  g#v0 = Sqr(gx#v0 * gx#v0 + gy#v0 * gy#v0)
  b#v0 = Sqr(bx#v0 * bx#v0 + by#v0 * by#v0)
EndMacro
        
Procedure sobel_4d_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected mul.f = *param\option[0]
  Protected mat = *param\option[1]
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected r0 , r45 , r90 , r135
  Protected g0 , g45 , g90 , g135
  Protected b0 , b45 , b90 , b135
  clamp(mul, 0, 100)
  mul = mul * 0.1
  Protected x, y, i
  Protected a , r, g, b
  Protected Dim r3(9)
  Protected Dim g3(9)
  Protected Dim b3(9)
  Protected startPos = (*param\thread_pos * (ht-2)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht-2)) / *param\thread_max
  If startPos < 1 : startPos = 1 : EndIf
  For y = startPos To endPos
    For x = 1 To lg - 2
      ; Lecture des 9 pixels voisins (3x3 autour du pixel courant)
      *srcPixel = (*source + ((y + -1) * lg + (x + -1)) * 4)
      getrgb(*srcPixel\l , r3(0) , g3(0) , b3(0) )
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l , r3(1) , g3(1) , b3(1) )
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l , r3(2) , g3(2) , b3(2) )
      *srcPixel = (*source + ((y + 0) * lg + (x + -1)) * 4)
      getrgb(*srcPixel\l , r3(3) , g3(3) , b3(3) )
      *srcPixel = *srcPixel + 4
      getargb(*srcPixel\l , a , r3(4) , g3(4) , b3(4) )
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l , r3(5) , g3(5) , b3(5) )
      *srcPixel = (*source + ((y + 1) * lg + (x + -1)) * 4)
      getrgb(*srcPixel\l , r3(6) , g3(6) , b3(6) )
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l , r3(7) , g3(7) , b3(7) )
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l , r3(8) , g3(8) , b3(8) )
      ; Gradient direction 0°
      sobel_4d_sp1(x0 , 2 , 5 , 8 , 0 , 3 , 6)
      sobel_4d_sp1(y0 , 0 , 1 , 2 , 6 , 7 , 8) 
      ; Gradient direction 45°
      sobel_4d_sp1(x45 , 0 , 1 , 2 , 6 , 7 , 8) 
      sobel_4d_sp1(y45 , 2 , 5 , 8 , 0 , 3 , 6)
      ; Gradient direction 90°
      sobel_4d_sp1(x90 , 6 , 7 , 8 , 0 , 1 , 2)
      sobel_4d_sp1(y90 , 0 , 3 , 6 , 2 , 5 , 6) 
      ; Gradient direction 135°
      sobel_4d_sp1(x135 , 6 , 3 , 0 , 8 , 5 , 2)
      sobel_4d_sp1(y135 , 2 , 5 , 8 , 0 , 3 , 6) 
      ; Magnitudes (sqrt des 2 directions combinées)
      If mat
        sobel_4d_sp2(0) : sobel_4d_sp2(45) : sobel_4d_sp2(90) : sobel_4d_sp2(135)
      Else
        sobel_4d_sp3(0) : sobel_4d_sp3(45) : sobel_4d_sp3(90) : sobel_4d_sp3(135)
      EndIf
      ; Max des directions
      max4(r , r0 , r45 , r90 , r135)
      max4(g , g0 , g45 , g90 , g135)
      max4(b , b0 , b45 , b90 , b135)
      r * mul : g * mul : b * mul
      clamp_rgb(r, g, b)
      ; Gris ?
      If toGray : r = (r * 77 + g * 150 + b * 29) >> 8 : g = r : b = r : EndIf
      ; Inversion ?
      If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
      *dstPixel = (*cible + (y * lg + x ) * 4)
      *dstPixel\l = (a << 24 ) | (r << 16) | (g << 8) | b
    Next
  Next
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
EndProcedure

Procedure Sobel_4d(*param.parametre)
  ; Affichage des informations de configuration si demandé
  If param\info_active
    param\typ = #FilterType_EdgeDetection
    param\subtype = #EdgeDetect_Gradient
    param\name = "Sobel 4 directions"
    param\remarque = ""
    param\info[0] = "multiply"             
    param\info[1] = "ABS/SQR"            
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
  filter_start(@sobel_4d_MT() , 4)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 104
; FirstLine = 58
; Folding = -
; EnableXP
; DPIAware