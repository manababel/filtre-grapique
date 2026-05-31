
Macro edge_detection_decalre()
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected mul.f = *param\option[0]
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected seuillage = *param\option[4]
  clamp(mul, 0, 100)
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max
  If startPos < 1 : startPos = 1 : EndIf
EndMacro

Macro edge_detection_option(ro , go , bo)
  r = ro * mul : g = go * mul : b = bo * mul
  clamp_rgb(r, g, b)
  If seuillage > 0 : seuil_rgb(seuillage , r , g , b) : EndIf
  If toGray : r = (r * 77 + g * 150 + b * 29) >> 8 : g = r : b = r : EndIf
  If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
  *dstPixel = (*cible + (y * lg + x ) * 4)
  *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
EndMacro

Procedure canny_grayscale_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected i , var , r , g , b
  
  Protected totalPixels = lg * ht
  Protected start = (*param\thread_pos * totalPixels) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * totalPixels) / *param\thread_max
  
  For i = start To stop -1
    var = PeekL(*src + i * 4)   ; Lecture pixel source (32 bits)
    GetRGB(var, r, g, b) 
    PokeA(*dst + i , ((r * 77 + g * 150 + b * 29) >> 8) ) ; Stockage gris dans *dst (32 bits)
  Next
EndProcedure

Procedure FiltrageGaussien_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, i, j, r, g, b, v, gray , idx , var
  Dim weights(8)
  weights(0) = 1 : weights(1) = 2 : weights(2) = 1
  weights(3) = 2 : weights(4) = 4 : weights(5) = 2
  weights(6) = 1 : weights(7) = 2 : weights(8) = 1
  
  Protected start = (*param\thread_pos * ht ) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * ht ) / *param\thread_max
  If start < 1 : start = 1 : EndIf
  If stop > (ht - 2) : stop = (ht - 2) : EndIf
  For y = start To stop
    For x = 1 To lg - 2
      v = 0 : idx = 0
      For j = -1 To 1
        For i = -1 To 1
          var = PeekA(*src + ((y+j)*lg + (x+i)) ) 
          v + var * weights(idx)                  
          idx + 1
        Next
      Next
      v = v >> 4 ;
      If v > 255 : v = 255 : ElseIf v < 0 : v = 0 : EndIf
      PokeA(*dst + (y*lg + x), v )
    Next
  Next
EndProcedure

Procedure GradientSobel_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *mag  = *param\addr[1]
  Protected *dir  = *param\addr[2]
  Protected lg = *param\lg
  Protected ht = *param\ht
 
  Protected x, y, gx, gy, magnitude, angle
  Protected line0, line1, line2
  Protected idx0, idx1, idx2
  Dim line0(lg - 1)
  Dim line1(lg - 1)
  Dim line2(lg - 1)
  Protected start = (*param\thread_pos * ht ) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * ht ) / *param\thread_max
  If start < 1 : start = 1 : EndIf
  If stop > (ht - 2) : stop = (ht - 2) : EndIf
  For y = start To stop
    For x = 0 To lg - 1
      line0(x) = PeekA(*src + ((y - 1) * lg + x) )
      line1(x) = PeekA(*src + (y * lg + x) )
      line2(x) = PeekA(*src + ((y + 1) * lg + x) )
    Next
    For x = 1 To lg - 2
      gx = -line0(x-1) + line0(x+1) - 2 * line1(x-1) + 2 * line1(x+1) - line2(x-1) + line2(x+1)
      gy = -line0(x-1) - 2 * line0(x) - line0(x+1) + line2(x-1) + 2 * line2(x) + line2(x+1)
      magnitude = Abs(gx) + Abs(gy)
      If magnitude > 255 : magnitude = 255 : EndIf
      If Abs(gx) > Abs(gy)
        If gx * gy >= 0
          angle = 0   
        Else
          angle = 3   
        EndIf
      Else
        If gx * gy >= 0
          angle = 1
        Else
          angle = 2 
        EndIf
      EndIf
      PokeA(*dir + y * lg + x, angle)
      PokeA(*mag + y * lg + x, magnitude)
      PokeA(*dir + y * lg + x, angle)
    Next
  Next
EndProcedure

Procedure sobel_direction_MT(*param.parametre)
  Protected *mag = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x , y , var , pos
  Protected totalPixels = lg * ht
  Protected start = (*param\thread_pos * totalPixels) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * totalPixels) / *param\thread_max
  For pos = start To stop - 1
    var = PeekA(*mag + pos)
    PokeL(*cible + pos << 2, var * $10101)
  Next
EndProcedure

Procedure SuppressionNonMaximale_MT(*param.parametre)
  Protected *mag = *param\addr[0]
  Protected *dir  = *param\addr[1]
  Protected *dst  = *param\addr[2]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected x, y, angle, m, m1, m2
  Protected fx, fy
  
  Protected start = (*param\thread_pos * ht ) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * ht ) / *param\thread_max
  If start < 1 : start = 1 : EndIf
  If stop > (ht - 2) : stop = (ht - 2) : EndIf

  For y = start To stop
    For x = 1 To lg - 2
      m = PeekA(*mag + y*lg + x)  
      angle = PeekA(*dir + y*lg + x)

      Select angle
        Case 0  
          fx = 1 : fy = 0
        Case 1  
          fx = 1 : fy = -1
        Case 2  
          fx = 0 : fy = -1
        Case 3  
          fx = -1 : fy = -1
        Default
          fx = 0 : fy = 0 
      EndSelect
      m1 = PeekA(*mag + (y+fy)*lg + (x+fx))
      m2 = PeekA(*mag + (y-fy)*lg + (x-fx))
      If m >= m1 And m >= m2
        PokeA(*dst + y*lg + x, m)
      Else
        PokeA(*dst + y*lg + x, 0)
      EndIf
    Next
  Next
EndProcedure

Procedure SeuillageDouble_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected seuilFort = *param\option[5]
  Protected seuilFaible = *param\option[6]
  Protected totalPixels = lg * ht
  Protected start = (*param\thread_pos * totalPixels) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * totalPixels) / *param\thread_max
  Protected x, y, var , i
  For i = start To stop -1
    var = PeekA(*src + i)
    If var >= seuilFort
      PokeA(*dst + i, 255)
    ElseIf var < seuilFaible
      PokeA(*dst + i, 0)
    Else
      PokeA(*dst + i, 128)
    EndIf
  Next
EndProcedure

Procedure Sobel_No_Hysteresis(*param.parametre)
  Protected *thresh = *param\addr[0]
  Protected *cible = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht 
  Protected x, y, var , i
  Protected start = (*param\thread_pos * ht ) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * ht ) / *param\thread_max
  For y = start To stop - 1
    For x = 0 To lg - 1
      var = PeekA(*thresh + y*lg + x)
      If var = 255
        PokeL(*cible + (y*lg + x) * 4, $FFFFFF) 
      ElseIf var = 128
        PokeL(*cible + (y*lg + x) * 4, $808080)
      Else
        PokeL(*cible + (y*lg + x) * 4, 0) 
      EndIf
    Next
  Next
  
EndProcedure

Procedure Hysteresis_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht 
  Protected x, y, dx, dy, found, var
  Protected start = (*param\thread_pos * ht ) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * ht ) / *param\thread_max
  If start < 1 : start = 1 : EndIf
  If stop > (ht - 2) : stop = (ht - 2) : EndIf
  For y = start To stop
    For x = 1 To lg - 2
      var = PeekA(*src + y*lg + x)
      If var = 128
        found = 0
        For dy = -1 To 1
          For dx = -1 To 1
            If PeekA(*src + (y+dy)*lg + (x+dx)) = 255
              found = 1 : Break 2
            EndIf
          Next
        Next
        If found
          PokeL(*dst + (y*lg + x)*4, $FFFFFF)
        Else
          PokeL(*dst + (y*lg + x)*4, 0)
        EndIf
      ElseIf var = 255
        PokeL(*dst + (y*lg + x)*4, $FFFFFF)
      Else
        PokeL(*dst + (y*lg + x)*4, 0) 
      EndIf
    Next
  Next
EndProcedure

Procedure canny(*param.parametre)
  
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "canny"
    param\remarque = ""
    param\info[0] = "seuil_Fort"
    param\info[1] = "seuil_Faible"
    param\info[2] = "Sortie brute"
    param\info[3] = "hystérésis"
    param\info[4] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 255 : param\info_data(0,2) = 100
    param\info_data(1,0) = 0 : param\info_data(1,1) = 255 : param\info_data(1,2) = 50
    param\info_data(2,1) = 0 : param\info_data(2,1) = 1  : param\info_data(2,2) = 0
    param\info_data(3,1) = 0 : param\info_data(3,1) = 1  : param\info_data(3,2) = 0
    param\info_data(4,1) = 0 : param\info_data(4,1) = 2  : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  
  Protected *source = *param\source
  Protected *cible  = *param\cible
  Protected *mask   = *param\mask
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected  *gray , *blurred , *mag , *dir , *nms , *thresh , *final
  Protected val , x , y , i
  
  If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf
  Protected thread = CountCPUs(#PB_System_CPUs)
  clamp(thread , 1 , 128)
  Protected Dim tr(thread)

  *gray      = AllocateMemory(lg * ht)  
  *blurred   = AllocateMemory(lg * ht)
  *mag       = AllocateMemory(lg * ht)
  *dir       = AllocateMemory(lg * ht)
  *nms       = AllocateMemory(lg * ht)
  *thresh    = AllocateMemory(lg * ht)
  *final     = AllocateMemory(lg * ht * 4)
  Protected seuilFort = param\option[0]
  Protected seuilFaible = param\option[1]
  Protected seuillage = param\option[2]
  Protected hysteresis = param\option[3]
  clamp(seuilFort , 1 ,255)
  clamp(seuilFaible , 1 ,255)

  *param\addr[0] = *source
  *param\addr[1] = *gray
  MultiThread_MT(@canny_grayscale_MT())

  *param\addr[0] = *gray
  *param\addr[1] = *blurred
  MultiThread_MT(@FiltrageGaussien_MT())

  *param\addr[0] = *blurred
  *param\addr[1] = *mag
  *param\addr[2] = *dir
  MultiThread_MT(@GradientSobel_MT())  
  
  If seuillage = 1
    *param\addr[0] = *mag
    *param\addr[1] = *cible
    MultiThread_MT(@sobel_direction_MT())
  Else
    *param\addr[0] = *mag
    *param\addr[1] = *dir
    *param\addr[2] = *nms
    MultiThread_MT(@SuppressionNonMaximale_MT())  

    *param\addr[0] = *nms
    *param\addr[1] = *thresh
    *param\option[5] = seuilFort
    *param\option[6] = seuilFaible
    MultiThread_MT(@SeuillageDouble_MT())  
    
    If hysteresis = 0
      *param\addr[0] = *thresh
      *param\addr[1] = *cible
      MultiThread_MT(@Sobel_No_Hysteresis()) 
    Else
      *param\addr[0] = *thresh
      *param\addr[1] = *cible
      MultiThread_MT(@Hysteresis_MT()) 
    EndIf
  EndIf
  If *param\mask And *param\option[4] : *param\mask_type = *param\option[4] - 1 : MultiThread_MT(@_mask()) : EndIf
  
  FreeMemory(*gray)
  FreeMemory(*blurred)
  FreeMemory(*mag)
  FreeMemory(*dir)
  FreeMemory(*nms)
  FreeMemory(*thresh)
  FreeMemory(*final)
  FreeArray(tr())
EndProcedure

;-------------------------

Procedure FreiChen_MT(*param.parametre)
  edge_detection_decalre()
  mul = mul * 0.05
  Protected Dim r3(9)
  Protected Dim g3(9)
  Protected Dim b3(9)
  Protected a, r, g, b
  Protected x, y, i, dir
  Protected valR, valG, valB
  Protected rMax, gMax, bMax
  ; Les masques sont normalisés, utilisant sqrt(2) ~ 1.4142
  Protected Dim mask(7, 8)
  DataSection
    FreiChen_data:
    Data.f  1,  1.4142,  1,     0,   0,   0,    -1, -1.4142, -1   
    Data.f  0,  1,       1.4142, -1,  0,  1.4142, -1, -1,      0 
    Data.f -1, 0,       1,     -1,  0,  1,      -1,  0,      1  
    Data.f -1, -1.4142, 0,     -1,  0,  1.4142, 0,   1.4142,  1  
    Data.f -1, -1.4142, -1,     0,  0,  0,      1,   1.4142,  1  
    Data.f  0, -1,     -1.4142, 1,  0, -1.4142, 1,   1,       0   
    Data.f  1,  0,     -1,      1,  0, -1,      1,   0,      -1  
    Data.f  1,  1,      0,      1,  0, -1,      0,  -1,      -1 
  EndDataSection
  Restore FreiChen_data
  For dir = 0 To 7 : For i = 0 To 8 : Read.f mask(dir, i) : Next : Next
  For y = startPos To endPos
    For x = 1 To lg - 2
      *srcPixel = (*source + ((y - 1) * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(0), g3(0), b3(0)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(1), g3(1), b3(1)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(2), g3(2), b3(2))
      *srcPixel = (*source + (y * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(3), g3(3), b3(3)) : *srcPixel + 4
      getargb(*srcPixel\l , a, r3(4), g3(4), b3(4)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(5), g3(5), b3(5))
      *srcPixel = (*source + ((y + 1) * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(6), g3(6), b3(6)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(7), g3(7), b3(7)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(8), g3(8), b3(8))
      
      rMax = 0 : gMax = 0 : bMax = 0
      For dir = 0 To 7
        valR = 0 : valG = 0 : valB = 0
        For i = 0 To 8
          valR + r3(i) * mask(dir, i)
          valG + g3(i) * mask(dir, i)
          valB + b3(i) * mask(dir, i)
        Next
        valR = Abs(valR)
        valG = Abs(valG)
        valB = Abs(valB)
        If valR > rMax : rMax = valR : EndIf
        If valG > gMax : gMax = valG : EndIf
        If valB > bMax : bMax = valB : EndIf
      Next
      edge_detection_option(rMax , gMax , bMax)
    Next
  Next
  FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3())
EndProcedure

Procedure FreiChen(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "FreiChen"
    param\remarque = ""
    param\info[0] = "multiply"             
    param\info[1] = "ABS/SQR"            
    param\info[2] = "Noir et blanc"       
    param\info[3] = "inversion"   
    param\info[4] = "seuillage : 0 = off"
    param\info[5] = "Masque binaire"           
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 10 ;
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1   : param\info_data(1,2) = 0 
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1   : param\info_data(2,2) = 0 
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1   : param\info_data(3,2) = 0 
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@FreiChen_MT() , 5)
EndProcedure

;-------------------------

Procedure Kirsch_MT(*param.parametre)
  edge_detection_decalre()
  Protected i, j
  Protected rMax, gMax, bMax
  clamp(mul, 0, 100)
  mul = mul * 0.05
  Protected Dim r3(9)
  Protected Dim g3(9)
  Protected Dim b3(9)
  Protected a, r, g, b
  Protected x, y
  Protected dir, valR, valG, valB
  Protected Dim mask(7, 8)
  DataSection
    kirsch_data:
    Data.i 5, 5, 5, -3, 0, -3, -3, -3, -3  
    Data.i 5, 5, -3, 5, 0, -3, -3, -3, -3  
    Data.i -3, 5, 5, -3, 0, 5, -3, -3, -3  
    Data.i -3, -3, 5, -3, 0, 5, -3, -3, 5  
    Data.i -3, -3, -3, -3, 0, -3, 5, 5, 5   
    Data.i -3, -3, -3, -3, 0, -3, 5, 5, -3 
    Data.i -3, -3, -3, 5, 0, -3, 5, 5, -3  
    Data.i 5, -3, -3, 5, 0, -3, 5, -3, -3  
  EndDataSection
  
  Restore kirsch_data
  For dir = 0 To 7 : For i = 0 To 8 : Read.i mask(dir, i) : Next : Next
  For y = startPos To endPos
    For x = 1 To lg - 2
      *srcPixel = (*source + ((y - 1) * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(0), g3(0), b3(0)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(1), g3(1), b3(1)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(2), g3(2), b3(2))
      *srcPixel = (*source + ((y) * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(3), g3(3), b3(3)) : *srcPixel + 4
      getargb(*srcPixel\l , a, r3(4), g3(4), b3(4)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(5), g3(5), b3(5))
      *srcPixel = (*source + ((y + 1) * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(6), g3(6), b3(6)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(7), g3(7), b3(7)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(8), g3(8), b3(8))
      rMax = 0 : gMax = 0 : bMax = 0
      For dir = 0 To 7
        valR = 0 : valG = 0 : valB = 0
        For i = 0 To 8
          valR + r3(i) * mask(dir, i)
          valG + g3(i) * mask(dir, i)
          valB + b3(i) * mask(dir, i)
        Next
        If valR > rMax : rMax = valR : EndIf
        If valG > gMax : gMax = valG : EndIf
        If valB > bMax : bMax = valB : EndIf
      Next
      edge_detection_option(Abs(rMax) , Abs(gMax) , Abs(bMax))
    Next
  Next
  FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3())
EndProcedure

Procedure Kirsch(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "Kirsch"
    param\remarque = "Détection 8 directions (fort)"
    param\info[0] = "multiply"
    param\info[1] = "math"
    param\info[2] = "Noir et blanc"
    param\info[3] = "inversion"
    param\info[4] = "seuillage : 0 = off"
    param\info[5] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 10
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1 : param\info_data(1,2) = 0
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1   : param\info_data(2,2) = 0
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Kirsch_MT() , 5)
EndProcedure

;-------------------------

Procedure Laplacian_MT(*param.parametre)
  edge_detection_decalre()
  Protected mode = *param\option[1]
  mul = mul * 0.1
  Protected Dim r3(9)
  Protected Dim g3(9)
  Protected Dim b3(9)
  Protected a, r, g, b
  Protected x, y
  If endPos > ht - 2 : endPos = ht - 2 : EndIf
  For y = startPos To endPos
    For x = 1 To lg - 2
      *srcPixel = (*source + ((y - 1) * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l, r3(0), g3(0), b3(0))
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l, r3(1), g3(1), b3(1))
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l, r3(2), g3(2), b3(2))
      *srcPixel = (*source + (y * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l, r3(3), g3(3), b3(3))
      *srcPixel = *srcPixel + 4
      getargb(*srcPixel\l, a, r3(4), g3(4), b3(4))
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l, r3(5), g3(5), b3(5))
      *srcPixel = (*source + ((y + 1) * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l, r3(6), g3(6), b3(6))
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l, r3(7), g3(7), b3(7))
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l, r3(8), g3(8), b3(8))
      If mode = 0
        r = (r3(1) + r3(3) + r3(5) + r3(7)) - (4 * r3(4))
        g = (g3(1) + g3(3) + g3(5) + g3(7)) - (4 * g3(4))
        b = (b3(1) + b3(3) + b3(5) + b3(7)) - (4 * b3(4))
      Else
        r = (r3(0) + r3(1) + r3(2) + r3(3) + r3(5) + r3(6) + r3(7) + r3(8)) - (8 * r3(4))
        g = (g3(0) + g3(1) + g3(2) + g3(3) + g3(5) + g3(6) + g3(7) + g3(8)) - (8 * g3(4))
        b = (b3(0) + b3(1) + b3(2) + b3(3) + b3(5) + b3(6) + b3(7) + b3(8)) - (8 * b3(4))
      EndIf
      edge_detection_option(r , g , b)
    Next
  Next
EndProcedure

Procedure Laplacian(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "Laplacian"
    param\remarque = ""
    param\info[0] = "multiply"             
    param\info[1] = "mode"            
    param\info[2] = "Noir et blanc"       
    param\info[3] = "inversion"           
    param\info[4] = "seuillage : 0 = off"
    param\info[5] = "Masque binaire"          
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100  : param\info_data(0,2) = 10 ;
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0 
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1  : param\info_data(2,2) = 0 
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1  : param\info_data(3,2) = 0 
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Laplacian_MT() , 5)
EndProcedure

;-------------------------

Procedure LaplacianOfGaussian_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected seuil = *param\option[0]
  Protected mul.f = *param\option[1]
  Protected maskSize = *param\option[2] 
  Protected sigma.f = *param\option[3] 
  Protected invese = *param\option[4]
  Protected toGray = *param\option[5]
  Protected seuillage = *param\option[6]
  maskSize = (maskSize * 2) + 1
  clamp(seuil, 0, 255)
  clamp(mul, 1, 100)
  clamp(sigma, 1, 100)
  sigma = sigma *0.01 + 0.1
  mul = mul * 0.1 + 1
  Protected offset = maskSize / 2
  Protected maskArea = maskSize * maskSize
  Dim logMask.l(maskArea - 1)
  Dim logMaskf.f(maskArea - 1) 
  Protected i, j, x, y, dx, dy, pos, r, g, b
  Protected cx = maskSize / 2
  Protected norm.f, value.f
  Protected sum.f = 0
  For y = 0 To maskSize - 1
    For x = 0 To maskSize - 1
      dx = x - cx
      dy = y - cx
      norm = (dx * dx + dy * dy) / (2 * sigma * sigma)
      value = -1 / (#PI * Pow(sigma, 4)) * (1 - norm) * Exp(-norm)
      sum = sum + value
      logMaskF(y * maskSize + x) = value
    Next
  Next
  For i = 0 To maskArea - 1 : logMask(i) = Int((logMaskF(i) - sum / maskArea) * mul) : Next
  Protected rf.f, gf.f, bf.f
  Protected rr, gg, bb, gray
  Protected startPos = offset + (*param\thread_pos * (ht - 2 * offset)) / *param\thread_max
  Protected endPos   = offset + ((*param\thread_pos + 1) * (ht - 2 * offset)) / *param\thread_max
  If startPos < offset : startPos = offset : EndIf
  If endPos > ht - offset : endPos = ht - offset : EndIf
  For y = startPos To endPos - 1
    For x = offset To lg - offset - 1
      rr = 0 : gg = 0 : bb = 0 : i = 0
      For dy = -offset To offset
        For dx = -offset To offset
          pos = PeekL(*source + ((y + dy) * lg + (x + dx)) * 4)
          GetRGB(pos, r, g, b)
          rr + r * logMask(i)
          gg + g * logMask(i)
          bb + b * logMask(i)
          i + 1
        Next
      Next
      If rr < 0 : rr = -rr : EndIf
      If gg < 0 : gg = -gg : EndIf
      If bb < 0 : bb = -bb : EndIf
      rr = rr >> 8 : gg = gg >> 8 : bb = bb >> 8
      clamp_rgb(rr, gg, bb) 
      If seuillage > 0 : seuil_rgb(seuillage , rr , gg , bb) : EndIf
      If toGray : gray = (rr * 77 + gg * 150 + bb * 29) >> 8 : rr = gray : gg = gray : bb = gray : EndIf
      If (rr + gg + bb) / 3 < seuil : rr = 0 : gg = 0 : bb = 0 : EndIf   
      If invese  : rr = 255 - rr : gg = 255 - gg : bb = 255 - bb : EndIf
      PokeL(*cible + (y * lg + x) * 4, rr << 16 + gg << 8 + bb)
    Next
  Next
  FreeArray(logMaskf())
  FreeArray(logMask())
EndProcedure

Procedure LaplacianOfGaussian(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "LaplacianOfGaussian"
    param\remarque = ""
    param\info[0] = "seuil"             
    param\info[1] = "multiply"                  
    param\info[2] = "maskSize"   
    param\info[3] = "sigma"
    param\info[4] = "inverse"
    param\info[5] = "togray" 
    param\info[6] = "seuillage : 0 = off"
    param\info[7] = "Masque binaire"           
    param\info_data(0,0) = 0 : param\info_data(0,1) = 255  : param\info_data(0,2) = 50
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100  : param\info_data(1,2) = 60 
    param\info_data(2,0) = 1 : param\info_data(2,1) = 5   : param\info_data(2,2) = 1
    param\info_data(3,0) = 1 : param\info_data(3,1) = 10  : param\info_data(3,2) = 3
    param\info_data(4,0) = 0 : param\info_data(4,1) = 1   : param\info_data(4,2) = 0 
    param\info_data(5,0) = 0 : param\info_data(5,1) = 1   : param\info_data(5,2) = 0
    param\info_data(6,0) = 0 : param\info_data(6,1) = 255 : param\info_data(6,2) = 0
    param\info_data(7,0) = 0 : param\info_data(7,1) = 2   : param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@LaplacianOfGaussian_MT() , 7)
EndProcedure

;-------------------------

Procedure Prewitt_MT(*param.parametre)
  edge_detection_decalre()
  mul = mul * 0.05
  Protected Dim r3(9)
  Protected Dim g3(9)
  Protected Dim b3(9)
  Protected a, r, g, b
  Protected x, y, i, dir
  Protected valR, valG, valB
  Protected rMax, gMax, bMax
  Protected Dim mask(7, 8)
  DataSection
    Prewitt_data:
    Data.i   1,  1,  1,   0,  0,  0,  -1, -1, -1
    Data.i   0,  1,  1,  -1,  0,  1,  -1, -1,  0
    Data.i  -1,  0,  1,  -1,  0,  1,  -1,  0,  1 
    Data.i  -1, -1,  0,  -1,  0,  1,   0,  1,  1
    Data.i  -1, -1, -1,   0,  0,  0,   1,  1,  1 
    Data.i   0, -1, -1,   1,  0, -1,   1,  1,  0  
    Data.i   1,  0, -1,   1,  0, -1,   1,  0, -1
    Data.i   1,  1,  0,   1,  0, -1,   0, -1, -1
  EndDataSection
  Restore Prewitt_data
  For dir = 0 To 7 : For i = 0 To 8 : Read.i mask(dir, i) : Next : Next
  For y = startPos To endPos
    For x = 1 To lg - 2
      *srcPixel = (*source + ((y - 1) * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(0), g3(0), b3(0)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(1), g3(1), b3(1)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(2), g3(2), b3(2))
      *srcPixel = (*source + (y * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(3), g3(3), b3(3)) : *srcPixel + 4
      getargb(*srcPixel\l , a, r3(4), g3(4), b3(4)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(5), g3(5), b3(5))
      *srcPixel = (*source + ((y + 1) * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(6), g3(6), b3(6)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(7), g3(7), b3(7)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(8), g3(8), b3(8))
      rMax = 0 : gMax = 0 : bMax = 0
      For dir = 0 To 7
        valR = 0 : valG = 0 : valB = 0
        For i = 0 To 8
          valR + r3(i) * mask(dir, i)
          valG + g3(i) * mask(dir, i)
          valB + b3(i) * mask(dir, i)
        Next
        valR = Abs(valR)
        valG = Abs(valG)
        valB = Abs(valB)
        If valR > rMax : rMax = valR : EndIf
        If valG > gMax : gMax = valG : EndIf
        If valB > bMax : bMax = valB : EndIf
      Next
      edge_detection_option(rMax , gMax , bMax)
    Next
  Next
  FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3())
EndProcedure

Procedure Prewitt(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "Prewitt"
    param\remarque = "Détection 8 directions"
    param\info[0] = "multiply"
    param\info[1] = "math"
    param\info[2] = "Noir et blanc"
    param\info[3] = "inversion"
    param\info[4] = "seuillage : 0 = off"
    param\info[5] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 10
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1 : param\info_data(1,2) = 0
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1   : param\info_data(2,2) = 0
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Prewitt_MT() , 5)
EndProcedure

;-------------------------

Procedure Roberts_RGBFromHSV(*r.Integer, *g.Integer, *b.Integer, h.f, s.f, v.f)
  Protected c.f = v * s
  Protected x.f = c * (1 - Abs(Mod(h / 60.0, 2) - 1))
  Protected m.f = v - c
  Protected r1.f, g1.f, b1.f
  Select Int(h / 60)
    Case 0 : r1 = c : g1 = x : b1 = 0
    Case 1 : r1 = x : g1 = c : b1 = 0
    Case 2 : r1 = 0 : g1 = c : b1 = x
    Case 3 : r1 = 0 : g1 = x : b1 = c
    Case 4 : r1 = x : g1 = 0 : b1 = c
    Default: r1 = c : g1 = 0 : b1 = x
  EndSelect
  *r\i = (r1 + m) * 255
  *g\i = (g1 + m) * 255
  *b\i = (b1 + m) * 255
EndProcedure


Procedure Roberts_MT(*param.parametre)
  edge_detection_decalre()
  Protected math = *param\option[1]
  Protected orientation = *param\option[5]
  Protected angle_add = *param\option[6]
  mul = mul * 0.05
  Protected a, r, g, b
  Protected r1, g1, b1, r2, g2, b2, r3, g3, b3, r4, g4, b4
  Protected gxR, gxG, gxB, gyR, gyG, gyB
  Protected valR, valG, valB , gx,gy, mag, angle.f
  Protected x, y
  For y = startPos To endPos - 1
    For x = 0 To lg - 2
      *srcPixel = (*source + (y * lg + x) * 4)
      getargb(*srcPixel\l, a, r1, g1, b1)
      *srcPixel = (*source + (y * lg + x + 1) * 4)
      getrgb(*srcPixel\l, r2, g2, b2)
      *srcPixel = (*source + ((y + 1) * lg + x) * 4)
      getrgb(*srcPixel\l, r3, g3, b3)
      *srcPixel = (*source + ((y + 1) * lg + x + 1) * 4)
      getrgb(*srcPixel\l, r4, g4, b4)
      gxR = r1 - r4
      gxG = g1 - g4
      gxB = b1 - b4
      gyR = r2 - r3
      gyG = g2 - g3
      gyB = b2 - b3
      If orientation
        gx = gxR + gxG + gxB
        gy = gyR + gyG + gyB
        mag   = Sqr(gx*gx + gy*gy) * mul
        angle = ATan2(gy, gx) * 180 / #PI
        If angle < 0 : angle + 360 : EndIf
        angle + angle_add
        If angle > 360 : angle - 360 : EndIf
        Roberts_RGBFromHSV(@valr, @valg, @valb, angle, 1.0, mag/255.0)
      Else
        If math
          valR = Abs(gxR) + Abs(gyR)
          valG = Abs(gxG) + Abs(gyG)
          valB = Abs(gxB) + Abs(gyB)
        Else
          valR = Sqr(gxR * gxR + gyR *gyR) 
          valG = Sqr(gxG * gxG + gyG *gyG) 
          valB = Sqr(gxB * gxB + gyB *gyB) 
        EndIf
      EndIf
      edge_detection_option(valR , valG , valB)
    Next
  Next
EndProcedure

Procedure Roberts(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "Roberts"
    param\remarque = "Détection 2 directions"
    param\info[0] = "multiply"
    param\info[1] = "math (ABS ou SQR)"
    param\info[2] = "Noir et blanc"
    param\info[3] = "inversion"
    param\info[4] = "seuillage : 0 = off"
    param\info[5] = "orientation"
    param\info[6] = "angle"
    param\info[7] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 10
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1 : param\info_data(1,2) = 0
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1   : param\info_data(2,2) = 0
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255   : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 1 : param\info_data(5,2) = 0
    param\info_data(6,0) = 0 : param\info_data(6,1) = 360 : param\info_data(6,2) = 0
    param\info_data(7,0) = 0 : param\info_data(7,1) = 2   : param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Roberts_MT() , 7)
EndProcedure

;-------------------------

Procedure Robinson_MT(*param.parametre)
  edge_detection_decalre()
  mul = mul * 0.05
  Protected Dim r3(9)
  Protected Dim g3(9)
  Protected Dim b3(9)
  Protected a, r, g, b
  Protected x, y, i, dir
  Protected valR, valG, valB
  Protected rMax, gMax, bMax
  Protected Dim mask(7, 8)
  DataSection
    robinson_data:
    Data.i  1,  1,  1,  0,  0,  0, -1, -1, -1 
    Data.i  0,  1,  1, -1,  0,  1, -1, -1,  0  
    Data.i -1,  0,  1, -1,  0,  1, -1,  0,  1  
    Data.i -1, -1,  0, -1,  0,  1,  0,  1,  1 
    Data.i -1, -1, -1,  0,  0,  0,  1,  1,  1  
    Data.i  0, -1, -1,  1,  0, -1,  1,  1,  0  
    Data.i  1,  0, -1,  1,  0, -1,  1,  0, -1  
    Data.i  1,  1,  0,  1,  0, -1,  0, -1, -1  
  EndDataSection
  Restore robinson_data
  For dir = 0 To 7 : For i = 0 To 8 : Read.i mask(dir, i) : Next : Next
  For y = startPos To endPos
    For x = 1 To lg - 2
      *srcPixel = (*source + ((y - 1) * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(0), g3(0), b3(0)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(1), g3(1), b3(1)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(2), g3(2), b3(2))
      *srcPixel = (*source + (y * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(3), g3(3), b3(3)) : *srcPixel + 4
      getargb(*srcPixel\l , a, r3(4), g3(4), b3(4)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(5), g3(5), b3(5))
      *srcPixel = (*source + ((y + 1) * lg + (x - 1)) * 4)
      getrgb(*srcPixel\l , r3(6), g3(6), b3(6)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(7), g3(7), b3(7)) : *srcPixel + 4
      getrgb(*srcPixel\l , r3(8), g3(8), b3(8))
      rMax = 0 : gMax = 0 : bMax = 0
      For dir = 0 To 7
        valR = 0 : valG = 0 : valB = 0
        For i = 0 To 8
          valR + r3(i) * mask(dir, i)
          valG + g3(i) * mask(dir, i)
          valB + b3(i) * mask(dir, i)
        Next
        valR = Abs(valR)
        valG = Abs(valG)
        valB = Abs(valB)
        If valR > rMax : rMax = valR : EndIf
        If valG > gMax : gMax = valG : EndIf
        If valB > bMax : bMax = valB : EndIf
      Next
      edge_detection_option(rMax , gMax , bMax)
    Next
  Next
  FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3())
EndProcedure

Procedure Robinson(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "Robinson"
    param\remarque = "Détection 8 directions"
    param\info[0] = "multiply"
    param\info[1] = "math"
    param\info[2] = "Noir et blanc"
    param\info[3] = "inversion"
    param\info[4] = "seuillage : 0 = off"
    param\info[5] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 10
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1 : param\info_data(1,2) = 0
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1   : param\info_data(2,2) = 0
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Robinson_MT() , 5)
EndProcedure

;-------------------------

Procedure Scharr_MT(*param.parametre)
  edge_detection_decalre()
  Protected i, j
  Protected rGx, gGx, bGx, rGy, gGy, bGy
  Protected mat = *param\option[1]
  mul = mul * 0.05
  Protected Dim r3(9)
  Protected Dim g3(9)
  Protected Dim b3(9)
  Protected a, r, g, b
  Protected x, y
  Protected rx, gx, bx, ry, gy, by
  For y = startPos To endPos
    For x = 1 To lg - 2
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
      rx = (r3(2)*3 + r3(5)*10 + r3(8)*3) - (r3(0)*3 + r3(3)*10 + r3(6)*3)
      gx = (g3(2)*3 + g3(5)*10 + g3(8)*3) - (g3(0)*3 + g3(3)*10 + g3(6)*3)
      bx = (b3(2)*3 + b3(5)*10 + b3(8)*3) - (b3(0)*3 + b3(3)*10 + b3(6)*3)
      ry = (r3(0)*3 + r3(1)*10 + r3(2)*3) - (r3(6)*3 + r3(7)*10 + r3(8)*3)
      gy = (g3(0)*3 + g3(1)*10 + g3(2)*3) - (g3(6)*3 + g3(7)*10 + g3(8)*3)
      by = (b3(0)*3 + b3(1)*10 + b3(2)*3) - (b3(6)*3 + b3(7)*10 + b3(8)*3)
      If mat = 0
        r = Sqr(rx * rx + ry * ry)
        g = Sqr(gx * gx + gy * gy)
        b = Sqr(bx * bx + by * by)
      Else 
        r = ((Abs(rx) + Abs(ry)))
        g = ((Abs(gx) + Abs(gy)))
        b = ((Abs(bx) + Abs(by)))
      EndIf
      edge_detection_option(r , g , b)
    Next
  Next
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
EndProcedure

Procedure Scharr(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "Scharr"
    param\remarque = ""
    param\info[0] = "multiply"             
    param\info[1] = "ABS/SQR"            
    param\info[2] = "Noir et blanc"       
    param\info[3] = "inversion"           
    param\info[4] = "seuillage : 0 = off"
    param\info[5] = "Masque binaire"        
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100  : param\info_data(0,2) = 10 ;
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0 
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1  : param\info_data(2,2) = 0 
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1  : param\info_data(3,2) = 0 
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Scharr_MT() , 5)
EndProcedure

;-------------------------

Macro Scharr_4d_sp1(v0 , v1 , v2 , v3 , v4 , v5 , v6 )
  Protected r#v0 = r3(v1)*3 + r3(v2)*10 + r3(v3)*3 - (r3(v4)*3 + r3(v5)*10 + r3(v6)*3)
  Protected g#v0 = g3(v1)*3 + g3(v2)*10 + g3(v3)*3 - (g3(v4)*3 + g3(v5)*10 + g3(v6)*3)
  Protected b#v0 = b3(v1)*3 + b3(v2)*10 + b3(v3)*3 - (b3(v4)*3 + b3(v5)*10 + b3(v6)*3)
EndMacro

Macro Scharr_4d_sp2(v0)
  r#v0 = Abs(rx#v0) + Abs(ry#v0)
  g#v0 = Abs(gx#v0) + Abs(gy#v0)
  b#v0 = Abs(bx#v0) + Abs(by#v0)
EndMacro

Macro Scharr_4d_sp3(v0)
  r#v0 = Sqr(rx#v0 * rx#v0 + ry#v0 * ry#v0)
  g#v0 = Sqr(gx#v0 * gx#v0 + gy#v0 * gy#v0)
  b#v0 = Sqr(bx#v0 * bx#v0 + by#v0 * by#v0)
EndMacro

Procedure Scharr_4d_MT(*param.parametre)
  edge_detection_decalre()
  Protected mat = *param\option[1]
  Protected r0 , r45 , r90 , r135
  Protected g0 , g45 , g90 , g135
  Protected b0 , b45 , b90 , b135
  mul = mul * 0.1
  Protected x, y, i
  Protected a , r, g, b
  Protected Dim r3(9)
  Protected Dim g3(9)
  Protected Dim b3(9)
  For y = startPos To endPos
    For x = 1 To lg - 2
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
      Scharr_4d_sp1(x0 , 2 , 5 , 8 , 0 , 3 , 6)
      Scharr_4d_sp1(y0 , 0 , 1 , 2 , 6 , 7 , 8) 
      Scharr_4d_sp1(x45 , 0 , 1 , 2 , 6 , 7 , 8) 
      Scharr_4d_sp1(y45 , 2 , 5 , 8 , 0 , 3 , 6)
      Scharr_4d_sp1(x90 , 6 , 7 , 8 , 0 , 1 , 2)
      Scharr_4d_sp1(y90 , 0 , 3 , 6 , 2 , 5 , 6) 
      Scharr_4d_sp1(x135 , 6 , 3 , 0 , 8 , 5 , 2)
      Scharr_4d_sp1(y135 , 2 , 5 , 8 , 0 , 3 , 6) 
      If mat
        Scharr_4d_sp2(0) : Scharr_4d_sp2(45) : Scharr_4d_sp2(90) : Scharr_4d_sp2(135)
      Else
        Scharr_4d_sp3(0) : Scharr_4d_sp3(45) : Scharr_4d_sp3(90) : Scharr_4d_sp3(135)
      EndIf
      max4(r , r0 , r45 , r90 , r135)
      max4(g , g0 , g45 , g90 , g135)
      max4(b , b0 , b45 , b90 , b135)
      edge_detection_option(r , g , b)
    Next
  Next
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
EndProcedure

Procedure Scharr_4d(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "Scharr 4 directions"
    param\remarque = ""
    param\info[0] = "multiply"             
    param\info[1] = "ABS/SQR"            
    param\info[2] = "Noir et blanc"       
    param\info[3] = "inversion"           
    param\info[4] = "seuillage : 0 = off"
    param\info[5] = "Masque binaire"           
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100  : param\info_data(0,2) = 10 ;
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0 
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1  : param\info_data(2,2) = 0 
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1  : param\info_data(3,2) = 0 
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Scharr_4d_MT() , 5)
EndProcedure

;-------------------------

Procedure Sobel_MT(*param.parametre)
  edge_detection_decalre()
  Protected mat = *param\option[1]
  Protected i, j
  Protected rGx, gGx, bGx, rGy, gGy, bGy
  mul = mul * 0.05
  Protected Dim r3(9)
  Protected Dim g3(9)
  Protected Dim b3(9)
  Protected a, r, g, b
  Protected x, y
  Protected rx, gx, bx, ry, gy, by
  For y = startPos To endPos
    For x = 1 To lg - 2
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
      rx = (r3(2) + (r3(5) << 1) + r3(8)) - (r3(0) + (r3(3) << 1) + r3(6))
      gx = (g3(2) + (g3(5) << 1) + g3(8)) - (g3(0) + (g3(3) << 1) + g3(6))
      bx = (b3(2) + (b3(5) << 1) + b3(8)) - (b3(0) + (b3(3) << 1) + b3(6))
      ry = (r3(0) + (r3(1) << 1) + r3(2)) - (r3(6) + (r3(7) << 1) + r3(8))
      gy = (g3(0) + (g3(1) << 1) + g3(2)) - (g3(6) + (g3(7) << 1) + g3(8))
      by = (b3(0) + (b3(1) << 1) + b3(2)) - (b3(6) + (b3(7) << 1) + b3(8))
      If mat = 0
        r = Sqr(rx * rx + ry * ry) 
        g = Sqr(gx * gx + gy * gy) 
        b = Sqr(bx * bx + by * by) 
      Else 
        r = ((Abs(rx) + Abs(ry)) )
        g = ((Abs(gx) + Abs(gy)) )
        b = ((Abs(bx) + Abs(by)) )
      EndIf
      edge_detection_option(r , g , b)
    Next
  Next
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
EndProcedure

Procedure Sobel(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "Sobel"
    param\remarque = ""
    param\info[0] = "multiply"             
    param\info[1] = "ABS/SQR"            
    param\info[2] = "Noir et blanc"       
    param\info[3] = "inversion"           
    param\info[4] = "seuillage : 0 = off"
    param\info[5] = "Masque binaire"             
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100  : param\info_data(0,2) = 10 ;
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0 
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1  : param\info_data(2,2) = 0 
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1  : param\info_data(3,2) = 0 
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@sobel_MT() , 5)
EndProcedure

;-------------------------

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
  edge_detection_decalre()
  Protected mat = *param\option[1]
  Protected r0 , r45 , r90 , r135
  Protected g0 , g45 , g90 , g135
  Protected b0 , b45 , b90 , b135
  mul = mul * 0.1
  Protected x, y, i
  Protected a , r, g, b
  Protected Dim r3(9)
  Protected Dim g3(9)
  Protected Dim b3(9)
  For y = startPos To endPos
    For x = 1 To lg - 2
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
      sobel_4d_sp1(x0 , 2 , 5 , 8 , 0 , 3 , 6)
      sobel_4d_sp1(y0 , 0 , 1 , 2 , 6 , 7 , 8) 
      sobel_4d_sp1(x45 , 0 , 1 , 2 , 6 , 7 , 8) 
      sobel_4d_sp1(y45 , 2 , 5 , 8 , 0 , 3 , 6)
      sobel_4d_sp1(x90 , 6 , 7 , 8 , 0 , 1 , 2)
      sobel_4d_sp1(y90 , 0 , 3 , 6 , 2 , 5 , 6) 
      sobel_4d_sp1(x135 , 6 , 3 , 0 , 8 , 5 , 2)
      sobel_4d_sp1(y135 , 2 , 5 , 8 , 0 , 3 , 6) 
      If mat
        sobel_4d_sp2(0) : sobel_4d_sp2(45) : sobel_4d_sp2(90) : sobel_4d_sp2(135)
      Else
        sobel_4d_sp3(0) : sobel_4d_sp3(45) : sobel_4d_sp3(90) : sobel_4d_sp3(135)
      EndIf
      max4(r , r0 , r45 , r90 , r135)
      max4(g , g0 , g45 , g90 , g135)
      max4(b , b0 , b45 , b90 , b135)
      edge_detection_option(r , g , b)
    Next
  Next
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
EndProcedure

Procedure Sobel_4d(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "Sobel 4 directions"
    param\remarque = ""
    param\info[0] = "multiply"             
    param\info[1] = "ABS/SQR"            
    param\info[2] = "Noir et blanc"       
    param\info[3] = "inversion"           
    param\info[4] = "seuillage : 0 = off"
    param\info[5] = "Masque binaire"          
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100  : param\info_data(0,2) = 10 ;
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0 
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1  : param\info_data(2,2) = 0 
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1  : param\info_data(3,2) = 0 
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@sobel_4d_MT() , 5)
EndProcedure

;-------------------------

Procedure CreateGaussianKernel(*kernel, radius, sigma.f)
  Protected x, i, value.f, sum.f = 0.0
  If sigma <= 0.0 : sigma = 1.0 : EndIf
  If radius < 1 : radius = Int(sigma * 2) : EndIf
  Protected div.f = 2.0 * sigma * sigma
  For x = -radius To radius
    value = Exp(-(x * x) / div)
    PokeF(*kernel + (x + radius) * 4, value)
    sum = sum + value
  Next
  If sum = 0.0 : sum = 1.0 : EndIf
  For i = 0 To 2 * radius
    value = PeekF(*kernel + i * 4) / sum
    PokeF(*kernel + i * 4, value)
  Next
EndProcedure

Procedure GaussianBlur1D_MT(*param.parametre)
  Protected Dim kernel.f(64)
  
  Protected *src = *param\addr[2]  
  Protected *dst = *param\addr[3] 
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected sigma.f = *param\option[0]
  Protected radius = Int(sigma * 2)
  Protected horizontal = *param\option[9]
  clamp(radius , 1 , 32)
  CreateGaussianKernel(@kernel(), radius, sigma)
  Protected x, y, k, offset, idx
  Protected a , r , g, b
  Protected sumR.f, sumG.f, sumB.f
  Protected *srcPixel.Pixel32, *dstPixel.Pixel32
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * ht) / *param\thread_max
  If startPos < 0 : startPos = 0 : EndIf
  If endPos > ht : endPos = ht : EndIf
  For y = startPos To endPos - 1
    For x = 0 To lg - 1
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0
      For k = -radius To radius
        If horizontal
          offset = x + k
          If offset < 0 : offset = 0
          ElseIf offset >= lg : offset = lg - 1
          EndIf
          idx = (y * lg + offset) * 4
        Else
          offset = y + k
          If offset < 0 : offset = 0
          ElseIf offset >= ht : offset = ht - 1
          EndIf
          idx = (offset * lg + x) * 4
        EndIf
        *srcPixel = *src + idx
        getargb(*srcPixel\l, a, r, g, b)
        sumR = sumR + r * kernel(k + radius)
        sumG = sumG + g * kernel(k + radius)
        sumB = sumB + b * kernel(k + radius)
      Next
      *dstPixel = *dst + (y * lg + x) * 4
      *dstPixel\l = (a << 24) | (Int(sumR + 0.5) << 16) | (Int(sumG + 0.5) << 8) | Int(sumB + 0.5)
    Next
  Next
  FreeArray(kernel())
EndProcedure

Procedure DoG_MT(*param.parametre)
  Protected *blur1 = *param\addr[2]
  Protected *blur2 = *param\addr[3]
  Protected *cible = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected math = *param\option[2]
  Protected toGray = *param\option[3]
  Protected inverse = *param\option[4]
  Protected seuillage = *param\option[5]
  Protected multiply = *param\option[6] + 10
  clamp(multiply, 0, 100)
  multiply = multiply * 0.05
  Protected x, y, a
  Protected r1, g1, b1, r2, g2, b2
  Protected *p1.Pixel32, *p2.Pixel32, *dst.Pixel32
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * ht) / *param\thread_max
  If startPos < 0 : startPos = 0 : EndIf
  If endPos > ht : endPos = ht : EndIf
  For y = startPos To endPos - 1
    For x = 0 To lg - 1
      *p1 = *blur1 + (y * lg + x) * 4
      *p2 = *blur2 + (y * lg + x) * 4
      getargb(*p1\l, a, r1, g1, b1)
      getrgb(*p2\l, r2, g2, b2)
      If Not math
        r1 = Abs(r1 - r2)
        g1 = Abs(g1 - g2)
        b1 = Abs(b1 - b2)
      Else
        r1 = Sqr(Abs(r1 * r1 - r2 * r2))
        g1 = Sqr(Abs(g1 * g1 - g2 * g2))
        b1 = Sqr(Abs(b1 * b1 - b2 * b2))
        clamp_rgb(r1 , g1 , b1)
      EndIf
      r1 * multiply : g1 * multiply : b1 * multiply
      
      If seuillage > 0 : seuil_rgb(seuillage , r1 , g1 , b1) : EndIf
      If toGray : r1 = (r1 * 77 + g1 * 150 + b1 * 29) >> 8 : g1 = r1 : b1 = r1 : EndIf
      If inverse : r1 = 255 - r1 : g1 = 255 - g1 : b1 = 255 - b1 : EndIf
      *dst = *cible + (y * lg + x) * 4
      *dst\l = (a << 24) | (Int(r1) << 16) | (Int(g1) << 8) | Int(b1)
    Next
  Next
EndProcedure

Procedure DoG(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\name = "DoG (programme buggé avec les threads)"
    param\remarque = "Difference of Gaussian"
    param\info[0] = "sigma1"
    param\info[1] = "sigma2"
    param\info[2] = "math (ABS ou SQR)"
    param\info[3] = "Noir et blanc"
    param\info[4] = "inversion"
    param\info[5] = "seuillage : 0 = off"
    param\info[6] = "multiply"
    param\info[7] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 10 : param\info_data(0,2) = 1
    param\info_data(1,0) = 2 : param\info_data(1,1) = 20 : param\info_data(1,2) = 5
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1  : param\info_data(2,2) = 0
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1  : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 1  : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 255: param\info_data(5,2) = 0
    param\info_data(6,0) = 0 : param\info_data(6,1) = 100: param\info_data(6,2) = 10
    param\info_data(7,0) = 0 : param\info_data(7,1) = 2   : param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  Protected *tempo = 0
  If *param\source = *param\cible
    *tempo = AllocateMemory(*param\lg * *param\ht * 4)
    If Not *tempo
      ProcedureReturn
    EndIf
    CopyMemory(*param\source, *tempo, *param\lg * *param\ht * 4)
    *param\addr[0] = *tempo
  Else
    *param\addr[0] = *param\source
  EndIf
  Protected *blur1 = AllocateMemory(*param\lg * *param\ht * 4)
  Protected *blur2 = AllocateMemory(*param\lg * *param\ht * 4)
  If Not *blur1 Or Not *blur2
    If *tempo : FreeMemory(*tempo) : EndIf
    If *blur1 : FreeMemory(*blur1) : EndIf
    If *blur2 : FreeMemory(*blur2) : EndIf
    ProcedureReturn
  EndIf
  *param\option[0] = *param\option[0] 
  *param\addr[2] = *param\addr[0]
  *param\addr[3] = *blur1
  *param\option[9] = #True
  MultiThread_MT(@GaussianBlur1D_MT())
  *param\addr[2] = *blur1
  *param\addr[3] = *blur1
  *param\option[9] = #False
  MultiThread_MT(@GaussianBlur1D_MT())
  *param\option[0] = *param\option[1] 
  *param\addr[2] = *param\addr[0]
  *param\addr[3] = *blur2
  *param\option[9] = #True
  MultiThread_MT(@GaussianBlur1D_MT())
  *param\addr[2] = *blur2
  *param\addr[3] = *blur2
  *param\option[9] = #False
  MultiThread_MT(@GaussianBlur1D_MT())
  *param\addr[2] = *blur1
  *param\addr[3] = *blur2
  *param\addr[1] = *param\cible
  MultiThread_MT(@DoG_MT())
  If *param\mask And *param\option[7] : *param\mask_type = *param\option[7] - 1 : MultiThread_MT(@_mask()) : EndIf
  If *tempo : FreeMemory(*tempo) : EndIf
  FreeMemory(*blur1)
  FreeMemory(*blur2)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 1251
; FirstLine = 1248
; Folding = --------
; EnableXP
; DPIAware