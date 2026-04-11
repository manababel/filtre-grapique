
Procedure Balance_MT(*p.parametre)
  Protected i, pixel.l, a.l, r.l, g.l, b.l
  Protected factorR = *p\option[0]
  Protected factorG = *p\option[1]
  Protected factorB = *p\option[2]
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    pixel = *srcPixel\l
    GetARGB(pixel, a, r, g, b)
    r = (factorR * r) >> 8
    g = (factorG * g) >> 8
    b = (factorB * b) >> 8
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

Procedure Balance(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Balance"
    param\remarque = ""
    param\info[0] = "Rouge (0-255)"
    param\info[1] = "Vert (0-255)"
    param\info[2] = "Bleu (0-255)"
    param\info[3] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 512 : param\info_data(0,2) = 255
    param\info_data(1,0) = 1 : param\info_data(1,1) = 512 : param\info_data(1,2) = 255
    param\info_data(2,0) = 1 : param\info_data(2,1) = 512 : param\info_data(2,2) = 255
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2  : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
filter_start(@Balance_MT() , 3)
EndProcedure

;-------------------------

Procedure Bend_MT(*p.parametre)
  Protected i, pixel.l, a.l, r.l, g.l, b.l
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected r1.f = (*p\option[0] - 180) / 255.0 * #PI / 180.0
  Protected g1.f = (*p\option[1] - 180) / 255.0 * #PI / 180.0
  Protected b1.f = (*p\option[2] - 180) / 255.0 * #PI / 180.0
  Protected tabr = *p\addr[3]
  Protected tabg = *p\addr[4]
  Protected tabb = *p\addr[5]
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    pixel = *srcPixel\l
    GetARGB(pixel, a, r, g, b)
    r = PeekA(tabr + r) 
    g = PeekA(tabg + g) 
    b = PeekA(tabb + b) 
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

Procedure Bend(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Bend"
    param\remarque = "Distorsion RGB"
    param\info[0] = "Angle Rouge"
    param\info[1] = "Angle Vert"
    param\info[2] = "Angle Bleu"
    param\info[3] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 512 : param\info_data(0,2) = 255
    param\info_data(1,0) = 1 : param\info_data(1,1) = 512 : param\info_data(1,2) = 255
    param\info_data(2,0) = 1 : param\info_data(2,1) = 512 : param\info_data(2,2) = 255
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2  : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  Protected *source = *param\source
  Protected *cible  = *param\cible
  Protected i
  If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf
  Protected r1.f = (*param\option[0] - 180) / 255.0 * #PI / 180.0
  Protected g1.f = (*param\option[1] - 180) / 255.0 * #PI / 180.0
  Protected b1.f = (*param\option[2] - 180) / 255.0 * #PI / 180.0
  Protected tabr = AllocateMemory(255)
  Protected tabg = AllocateMemory(255)
  Protected tabb = AllocateMemory(255)
  Protected r , g , b
  For i = 0 To 255
    r = Sin(i * r1) * 127 + i
    g = Sin(i * g1) * 127 + i
    b = Sin(i * b1) * 127 + i
    Clamp_RGB(r, g, b)
    PokeA(tabr + i , r)
    PokeA(tabg + i , g)
    PokeA(tabb + i , b)
  Next
  param\addr[3] = tabr
  param\addr[4] = tabg
  param\addr[5] = tabb
  filter_start(@Bend_MT() , 3)
  FreeMemory(tabr)
  FreeMemory(tabg)
  FreeMemory(tabb)
EndProcedure

;-------------------------

Procedure BlackAndWhite_MT(*param.parametre)   
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected seuil = *param\option[0]
  Protected option = *param\option[1]
  Protected i , t , lum , l1 , l2
  Protected var , a , r , g , b
  t = (lg * ht * 4)
  Protected start = (*param\thread_pos * t) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * t) / *param\thread_max - 1
  For i = start To stop-1 Step 4
    var = PeekL(*param\addr[0] + i)
    getargb(var , a , r , g , b)
    Select option
      Case 1 
        lum = (R * 77 + G * 150 + B * 29) >> 8
      Case 2
        lum = (R * 54 + G * 183 + B * 18) >> 8
      Case 3
        max(lum,r,g)
        max(lum,lum,b)
      Case 4 
        min(lum,r,g)
        min(lum,lum,b)
      Case 5 
        l1 = g
        If (r > l1) : Swap r, l1 : EndIf
        If (l1 > b) : Swap l1, b : EndIf
        If (r > l1) : Swap r, l1 : EndIf
        lum = l1
      Case 6
        min(l1,r,g)
        min(l1,l1,b)
        max(l2,r,g)
        max(l2,l2,b)
        lum = (l1 + l2) * 0.5
      Case 7
        lum = r
      Case 8
        lum = g
      Case 9
        lum = b
      Default 
        lum = ((r + g + b) * 85)>> 8
    EndSelect
    If lum > seuil : PokeL(*param\addr[1] + i,a << 24 | $ffffff) : Else : PokeL(*param\addr[1] + i,a << 24) : EndIf
  Next      
EndProcedure

Procedure BlackAndWhite(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "BlackAndWhite"
    param\remarque = ""
    param\info[0] = "seuil"
    param\info[1] = "type" ; Rayon vertical
    param\info[2] = "Masque binaire" ; Optionnel : appliquer un masque
    param\info_data(0,0) = 1 : param\info_data(0,1) = 254 : param\info_data(0,2) = 127
    param\info_data(1,0) = 0 : param\info_data(1,1) = 9   : param\info_data(1,2) = 0
    param\info_data(2,0) = 0 : param\info_data(2,1) = 2   : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@BlackAndWhite_MT() , 2)
EndProcedure

;-------------------------

Procedure Brightness_MT(*p.parametre)
  Protected i, a, r, g, b
  Protected totalPixels = *p\lg * *p\ht
  Protected sr = *p\option[0] - 255
  Protected sg = *p\option[1] - 255
  Protected sb = *p\option[2] - 255
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    GetARGB(*srcPixel\l, a, r, g, b)
    r + sr
    g + sg
    b + sb
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

Procedure Brightness(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Brightness"
    param\remarque = ""
    param\info[0] = "ajustement Rouge"
    param\info[1] = "ajustement Vert"
    param\info[2] = "ajustement Bleu"
    param\info[3] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 512 : param\info_data(0,2) = 255
    param\info_data(1,0) = 1 : param\info_data(1,1) = 512 : param\info_data(1,2) = 255
    param\info_data(2,0) = 1 : param\info_data(2,1) = 512 : param\info_data(2,2) = 255
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2  : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Brightness_MT() , 3)
EndProcedure

;-------------------------

Macro Color_Gray()
  var =  ((R * 54 + G * 183 + B * 18) >> 8 )  * $10101
EndMacro

Procedure Color_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected maxVal , minVal , saturation
  Protected deltaRG , deltaRB , deltaGB 
  
  Protected seuil = *param\option[0]
  Protected mode = *param\option[1]
 
  Protected i, totalPixels = lg * ht * 4
  Protected var, r, g, b
  
  Protected startPos = (*param\thread_pos * totalPixels) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * totalPixels) / *param\thread_max
  
  For i = startPos To endPos - 1 Step 4
    var = PeekL(*source + i)
    getrgb(var, r, g, b)
    
    Select mode
        Case 0 :  If (g > r Or b > r Or r > seuil) : Color_Gray() : EndIf         ; Red OR >
        Case 1 :  If (r > g Or b > g Or g > seuil) : Color_Gray() : EndIf        ; Green OR >
        Case 2 :  If (g > b Or r > b Or b > seuil) : Color_Gray() : EndIf         ; Blue OR >
        
        Case 3 :  If (r < g Or r < b Or r > seuil) : Color_Gray() : EndIf         ; Red OR <
        Case 4 :  If (g < r Or g < b Or g > seuil) : Color_Gray() : EndIf         ; Green OR <
        Case 5 :  If (b < r Or b < g Or b > seuil) : Color_Gray() : EndIf          ; Blue OR <
        
        Case 6 :  If ((g > r And b > r) Or r > seuil) : Color_Gray() : EndIf       ; Red AND >
        Case 7 :  If ((r > g And b > g) Or g > seuil) : Color_Gray() : EndIf       ; Green AND >
        Case 8 :  If ((g > b And r > b) Or b > seuil) : Color_Gray() : EndIf      ; Blue AND >
        
        Case 9 :  If ((r < g And r < b) Or r > seuil) : Color_Gray() : EndIf       ; Red AND <
        Case 10:  If ((g < r And g < b) Or g > seuil) : Color_Gray() : EndIf       ; Green AND <
        Case 11:  If ((b < g And b < r) Or b > seuil) : Color_Gray() : EndIf       ; Blue AND <
        
        Case 12:  If ((g > r) XOr (b > r) Or r > seuil) : Color_Gray() : EndIf     ; Red XOR >
        Case 13:  If ((r > g) XOr (b > g) Or g > seuil) : Color_Gray() : EndIf      ; Green XOR >
        Case 14:  If ((g > b) XOr (r > b) Or b > seuil) : Color_Gray() : EndIf     ; Blue XOR >
        
        Case 15:  If ((r < g) XOr (r < b) Or r > seuil) : Color_Gray() : EndIf     ; Red XOR <
        Case 16:  If ((g < r) XOr (g < b) Or g > seuil) : Color_Gray() : EndIf     ; Green XOR <
        Case 17:  If ((b < g) XOr (b < r) Or b > seuil) : Color_Gray() : EndIf     ; Blue XOR <
        
      Case 18
        max(maxVal , r , g)
        Max(maxVal , maxVal , b)
        Min(minVal , r , g)
        Min(minVal , minVal , b)
        saturation = maxVal - minVal
        If saturation < seuil : Color_Gray() : EndIf
        
      Case 19 
        deltaRG = Abs(r - g)
        deltaRB = Abs(r - b)
        deltaGB = Abs(g - b)
        If deltaRG > seuil Or deltaRB > seuil Or deltaGB > seuil : Color_Gray() : EndIf
        
    EndSelect
    PokeL(*cible + i, var)
  Next
EndProcedure

Procedure Color(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Color"
    param\remarque = ""
    param\info[0] = "seuil"
    param\info[1] = "mode"
    param\info[2] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 255 : param\info_data(0,2) = 127
    param\info_data(1,0) = 0 : param\info_data(1,1) = 19 : param\info_data(1,2) = 0
    param\info_data(2,0) = 0 : param\info_data(2,1) = 2  : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Color_MT() , 2)
EndProcedure

;-------------------------


Procedure color_effect_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected opt = *param\option[0] 
  
  clamp(opt , 0 , 2 )  
  Protected i, var, alpha
  Protected r , g , b , r2 , g2 , b2 , rgb
  
  Protected totalPixels  = lg * ht
  Protected startPos = (*param\thread_pos * totalPixels) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * totalPixels) / *param\thread_max
  
  For i = startPos To endPos - 1
    var = PeekL(*source + i * 4)
    getrgb(var , r , g , b)
    r2 = (g + b) >> 1
    g2 = (r + b) >> 1
    b2 = (r + g) >> 1
    Select opt
      Case 0 : rgb= b2<<16 + g2<<8 + r2
      Case 1 : rgb= r2<<16 + g2<<8 + b2
      Case 2 : rgb= g2<<16 + b2<<8 + r2
      Default : rgb= b2<<16 + r2<<8 + b2
    EndSelect
    
    PokeL(*cible + i * 4, rgb)
  Next
EndProcedure

Procedure color_effect(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "color_effect"
    param\remarque = ""
    param\info[0] = "option"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 2 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@color_effect_MT() , 1)
EndProcedure

;-------------------------

Procedure Color_hue_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected maxVal , minVal
  Protected delta.f , hue.f , deltaHue.f
  
  Protected hueTarget = *param\option[0] 
  Protected tolerance = *param\option[1] 
  
  Protected i, totalPixels = lg * ht
  Protected var, r, g, b
  
  Protected startPos = (*param\thread_pos * totalPixels) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * totalPixels) / *param\thread_max
  
  For i = startPos To endPos - 1
    var = PeekL(*source + i << 2)
    getrgb(var, r, g, b)
    
    max3(maxVal , r , g , b)
    Min3(minVal , r , g , b)
    delta = maxVal - minVal
    If delta <> 0 
      
      Select maxVal
        Case r : hue = 60 * (g - b) / delta
        Case g : hue = 120 + 60 * (b - r) / delta
        Case b : hue = 240 + 60 * (r - g) / delta
      EndSelect
      If hue < 0 : hue + 360 : EndIf
      
      deltaHue = Abs(hue - hueTarget)
      If deltaHue > 180
        deltaHue = 360 - deltaHue
      EndIf
      
      If deltaHue <= tolerance : var =  ((R * 54 + G * 183 + B * 18) >> 8 )  * $10101 : EndIf
      
    EndIf
    PokeL(*cible + i << 2, var)
  Next
EndProcedure


Procedure Color_hue(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Color_hue"
    param\remarque = ""
    param\info[0] = "hueTarget"
    param\info[1] = "tolerance"
    param\info[2] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 360 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0 : param\info_data(1,1) = 255 : param\info_data(1,2) = 20
    param\info_data(2,0) = 0 : param\info_data(2,1) = 2  : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Color_hue_MT() , 2)
EndProcedure

;-------------------------

Procedure Colorize_MT(*p.parametre)
  Protected i, r, g, b, gray, alpha
  Protected intensity.f = *p\option[0] / 128.0
  Protected invIntensity.f = 1.0 - intensity
  Protected var.l
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    var = *srcPixel\l
    getrgb(var, r, g, b)
    gray = (R * 54 + G * 183 + B * 18) >> 8 
    r = Int(r * intensity + gray * invIntensity)
    g = Int(g * intensity + gray * invIntensity)
    b = Int(b * intensity + gray * invIntensity)
    Clamp_RGB(r, g, b)
    *dstPixel\l = (r << 16) | (g << 8) | b
  Next
EndProcedure

; ────────────────────────────────────────────────────────────────
Procedure Colorize(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Colorize"
    param\remarque = ""
    param\info[0] = "intensité"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 512 : param\info_data(0,2) = 127
    param\info_data(1,1) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Colorize_MT() , 1)
EndProcedure

;-------------------------

Procedure Teinte_Simple_YUV_MT(*p.parametre)
  Protected *src = *p\addr[0]
  Protected *dst = *p\addr[1]
  Protected angleA.f = *p\option[0]
  Protected angleB.f = *p\option[1]
  Protected tolerance.f = *p\option[2]
  Protected mode = *p\option[3] 
  
  angleA = Mod(angleA, 360)
  angleB = Mod(angleB, 360)

  Protected angleA_rad.f = #PI * angleA / 180
  Protected angleB_rad.f = #PI * angleB / 180

  Protected cosA.f = Cos(angleA_rad)
  Protected sinA.f = Sin(angleA_rad)
  Protected cosB.f = Cos(angleB_rad)
  Protected sinB.f = Sin(angleB_rad)

  Protected w = *p\lg
  Protected h = *p\ht
  Protected start = (*p\thread_pos * w * h) / *p\thread_max
  Protected stop  = ((*p\thread_pos + 1) * w * h) / *p\thread_max

  Protected i, var, a, r, g, b , xpos , ypos
  Protected y.f, u.f, v.f
  Protected u2.f, v2.f
  Protected rA, gA, bA, rB, gB, bB
  Protected countA = 0, countB = 0

  If mode
    r = 0
    g = 255
    b = 0
      y =  0.299 * r + 0.587 * g + 0.114 * b
      u = -0.14713 * r - 0.28886 * g + 0.436 * b
      v =  0.615 * r - 0.51499 * g - 0.10001 * b
      u2 = u * cosA - v * sinA
      v2 = u * sinA + v * cosA
      rA = y + 1.13983 * v2
      gA = y - 0.39465 * u2 - 0.58060 * v2
      bA = y + 2.03211 * u2
      Clamp_rgb(rA, gA, bA)
      u2 = u * cosB - v * sinB
      v2 = u * sinB + v * cosB
      rB = y + 1.13983 * v2
      gB = y - 0.39465 * u2 - 0.58060 * v2
      bB = y + 2.03211 * u2
      Clamp_rgb(rB, gB, bB)
    Protected squareSize = 32
    For yPos = 0 To squareSize - 1
      For xPos = 0 To squareSize - 1
        PokeL(*dst + ((yPos * w) + xPos) * 4, $FF000000 | (rA << 16) | (gA << 8) | bA)
        PokeL(*dst + ((yPos * w) + ( squareSize + xPos + 1)) * 4, $FF000000 | (rB << 16) | (gB << 8) | bB)
      Next
    Next
  EndIf
  
  Protected angle_src_rad.f = #PI * angleB / 180  
  Protected angle_dst_rad.f = #PI * angleA / 180   
  Protected tolerance_deg.f = tolerance           
  Protected tol_rad.f = #PI * tolerance_deg / 180

  For i = start To stop - 1
    var = PeekL(*src + i * 4)
    getargb(var, a, r, g, b)
    y =  0.299 * r + 0.587 * g + 0.114 * b
    u = -0.14713 * r - 0.28886 * g + 0.436 * b
    v =  0.615 * r - 0.51499 * g - 0.10001 * b
    Protected angle_pixel.f = ATan2(v, u)
    Protected angle_diff.f = angle_pixel - angle_src_rad
    If angle_diff > #PI : angle_diff - 2 * #PI : EndIf
    If angle_diff < -#PI : angle_diff + 2 * #PI : EndIf
    angle_diff = Abs(angle_diff)
    If angle_diff <= tol_rad
      Protected angle_delta.f = angle_dst_rad - angle_pixel
      Protected cosD.f = Cos(angle_delta)
      Protected sinD.f = Sin(angle_delta)
      u2 = u * cosD - v * sinD
      v2 = u * sinD + v * cosD
      r = y + 1.13983 * v2
      g = y - 0.39465 * u2 - 0.58060 * v2
      b = y + 2.03211 * u2
      Clamp_rgb(r, g, b)
    EndIf
    PokeL(*dst + i * 4, a << 24 | r << 16 | g << 8 | b)
  Next
EndProcedure


Procedure ColorPermutation(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "ColorPermutation"
    param\remarque = ""
    param\info[0] = "Teinte 1"
    param\info[1] = "Teinte 2"
    param\info[2] = "tolerence"
    param\info[3] = "affiche"
    param\info[4] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 360 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0 : param\info_data(1,1) = 360 : param\info_data(1,2) = 0
    param\info_data(2,0) = 0 : param\info_data(2,1) = 180 : param\info_data(2,2) = 25
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1 : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2 : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Teinte_Simple_YUV_MT() , 4)
EndProcedure

;-------------------------

Procedure Contrast_MT(*p.parametre)
  Protected i, a, r, g, b, contrast, alpha, var
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected *mask = *p\mask
  contrast = (( *p\option[0] - 128 ) * 256 ) / 128 + 256
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    var = *srcPixel\l
    GetARGB(var, a, r, g, b)
    r = ((r - 128) * contrast) >> 8 + 128
    g = ((g - 128) * contrast) >> 8 + 128
    b = ((b - 128) * contrast) >> 8 + 128
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

Procedure Contrast(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Contrast"
    param\remarque = ""
    param\info[0] = "Contraste"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 512 : param\info_data(0,2) = 255
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Contrast_MT() , 1)
EndProcedure

;-------------------------

Procedure Dichromatic_MT(*p.parametre)
  Protected i, a, r, g, b
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected definition.f = (*p\option[0] / 100.0) * 255
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected totalPixels = lg * ht
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    getargb(*srcPixel\l , a, r , g , b)
    Protected grey = ((r * 1225 + g * 2405 + b * 466) >> 12)
    If grey < definition
      *dstPixel\l = ( (a << 24) )
    Else
      *dstPixel\l = ( (a << 24) | $ffffff)
    EndIf
  Next
EndProcedure

Procedure Dichromatic(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Dichromatic"
    param\remarque = ""
    param\info[0] = "Intensité"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 25 : param\info_data(0,1) = 75 : param\info_data(0,2) = 50
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Dichromatic_MT() , 1)
EndProcedure

;-------------------------

Procedure Exposure_MT(*p.parametre)
  Protected i, a, r, g, b, alpha, var
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected exposure.f = *p\option[0]
  Clamp(exposure, 1, 255)
  exposure * 0.1
  Protected Dim tab.a(255)
  For i = 0 To 255
    Protected val.f = 255 * (1.0 - Exp(-i * exposure / 255.0))
    If val > 255 : val = 255 : EndIf
    tab(i) = Int(val)
  Next
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    var = *srcPixel\l
    getargb(var, a, r, g, b)
    r = tab(r)
    g = tab(g)
    b = tab(b)
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
  FreeArray(tab())
EndProcedure

Procedure Exposure(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Exposure"
    param\remarque = "Correction d’exposition (type photo)"
    param\info[0] = "Exposition"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 255 : param\info_data(0,2) = 15
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2 : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Exposure_MT() , 1)
EndProcedure

;-------------------------

Procedure FalseColour_RGBfromHSL(h.f, s.f, l.f)
  Protected r.f, g.f, b.f
  Protected c.f = (1 - Abs(2 * l - 1)) * s
  Protected x.f = c * (1 - Abs(Mod(h / 60, 2) - 1))
  Protected m.f = l - c / 2
  Select Int(h / 60)
    Case 0 : r=c : g=x : b=0
    Case 1 : r=x : g=c : b=0
    Case 2 : r=0 : g=c : b=x
    Case 3 : r=0 : g=x : b=c
    Case 4 : r=x : g=0 : b=c
    Default: r=c : g=0 : b=x
  EndSelect
  r = (r + m) * 255
  g = (g + m) * 255
  b = (b + m) * 255

  ProcedureReturn $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b)
EndProcedure

Procedure FalseColour_MT(*p.parametre)
  Protected i, a, r, g, b
  Protected teinte.f = *p\option[0] ;* 0.01
  Protected Dim RainbowLUT(1000)
  For i = 0 To 1000 : RainbowLUT(i) = FalseColour_RGBfromHSL(Mod((i/1000.0*360 + teinte) , 360), 1, 0.5): Next
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected totalPixels = lg * ht
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    getargb(*srcPixel\l , a , r , g , b)
    Protected grey = ((r * 1225 + g * 2405 + b * 466) >> 12)
    Protected ratio = (grey * 1000) / 255
    Protected color = RainbowLUT(ratio)
    getargb(color, a, r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
  FreeArray(RainbowLUT())
EndProcedure

Procedure FalseColour(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "False Colour"
    param\remarque = "Teinte basée sur l'intensité"
    param\info[0] = "Mode Couleur"
    param\info[1] = "Masque"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 360 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2   : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@FalseColour_MT() , 1)
EndProcedure

;-------------------------

Procedure Gamma_MT(*p.parametre)
  Protected i, var, a, r, g, b, alpha
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected totalPixels = lg * ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  Protected lut = *p\addr[2]
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    getargb(*srcPixel\l , a , r ,g , b)
    r = PeekA(lut + r)
    g = PeekA(lut + g)
    b = PeekA(lut + b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

Procedure Gamma(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Gamma"
    param\remarque = ""
    param\info[0] = "Gamma"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 255 : param\info_data(0,2) = 127
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  Protected i , var
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  Protected lut = AllocateMemory(255)
  Protected div.f
  Protected gamma_raw.f = 255 - *param\option[0]
  clamp(gamma_raw, 0, 255)
  Protected gamma_f.f = gamma_raw / 100
  For i = 0 To 255
    div = i
    var = Pow(div / 255.0, gamma_f) * 255.0
    Clamp(var, 0, 255)
    PokeA(lut + i , var)
  Next
  *param\addr[2] = lut
  filter_start(@Gamma_MT() , 1)
  FreeMemory(lut)
EndProcedure

;-------------------------

Procedure Grayscale_MT(*param.parametre) 
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected typ = *param\option[0]
  Protected i, var
  Protected a , r, g, b, gray
  Protected t = lg * ht
  Protected start = (*param\thread_pos * t) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * t) / *param\thread_max - 1
  For i = start To stop - 1
    var = PeekL(*param\addr[0] + i * 4)
    getargb( var , a , r , g , b)
    Select typ    
      Case 1
        gray = (r * 1225 + g * 2405 + b * 466) >> 12
      Case 2 
        gray = (r * 870 + g * 2930 + b * 296) >> 12 
      Case 3
        gray = (r * 1293 + g * 2156 + b * 647) >> 12  
      Case 4 
        gray = r : If g > gray : gray = g : EndIf
        If b > gray : gray = b : EndIf  
      Case 5 
        gray = r : If g < gray : gray = g : EndIf
        If b < gray : gray = b : EndIf     
      Case 6 
        If r > g : Swap r, g : EndIf
        If g > b : Swap g, b : EndIf
        If r > g : Swap r, g : EndIf
        gray = g    
      Case 7 
        gray = r       
      Case 8 
        gray = g    
      Case 9 
        gray = b      
      Case 10 
        gray = Sqr(r * r * 0.299 + g * g * 0.587 + b * b * 0.114)  
      Case 11 
        gray = Sqr(r * r * 0.2126 + g * g *0.7152 + b * b * 0.0722)   
      Case 12
        max3( r , r , g , b)
        min3( g , r , g ,b)
        gray = (r + g) >> 1 
      Case 13 
         Max3( gray , r, g, b) 
      Default 
        gray = (r * 1365 + g * 1365 + b * 1366) >> 12
    EndSelect
    Clamp(gray, 0, 255)
    PokeL(*param\addr[1] + i * 4, a << 24 | gray * $10101)
  Next
EndProcedure

Procedure Grayscale(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Grayscale"
    param\remarque = ""
    param\info[0] = "type" 
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 13 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Grayscale_MT() , 1)
EndProcedure

;-------------------------

Procedure Hollow_MT(*p.parametre)
  Protected i, r, g, b, var, alpha
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected *mask = *p\mask
  Protected opt = *p\option[0]
  Protected hollow = *p\option[1]
  Protected v.f, v1.f

  clamp(opt, 0, 360)

  v = opt / 255.0 * #PI / 180.0

  Protected Dim tab_hollow.f(255)
  For i = 0 To 255
    If hollow
      v1 = 255 * (1 - Sin(i * v))
    Else
      v1 = 255 * (Sin(i * v))
    EndIf
    clamp(v1, 0, 255)
    tab_hollow(i) = v1
  Next

  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max

  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)

    var = *srcPixel\l
    getrgb(var, r, g, b)

    r = tab_hollow(r)
    g = tab_hollow(g)
    b = tab_hollow(b)

    *dstPixel\l = RGB(r, g, b)
  Next

  FreeArray(tab_hollow()) 
EndProcedure


Procedure Hollow(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Hollow"
    param\remarque = ""
    param\info[0] = "angle"
    param\info[1] = "Hollow/Ledge"
    param\info[2] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 360 : param\info_data(0,2) = 180
    param\info_data(1,1) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0
    param\info_data(2,1) = 0 : param\info_data(2,1) = 2  : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Hollow_MT() , 2)
EndProcedure

;-------------------------

Procedure Negatif_MT(*p.parametre)
  Protected i, a, r, g, b, alpha, var
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected *mask = *p\mask

  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max

  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    var = *srcPixel\l
    GetARGB(var, a, r, g, b)
    *dstPixel\l = ~var
  Next
EndProcedure


Procedure Negatif(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Négatif"
    param\remarque = ""
    param\info[0] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 2 : param\info_data(0,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Negatif_MT() , 0)
EndProcedure

;-------------------------

Procedure Normalize_Color(*p.parametre)
  Protected start, stop, i
  Protected var.l
  Protected r, g, b
  Protected rmin = 255, gmin = 255, bmin = 255
  Protected rmax = 0, gmax = 0, bmax = 0
  Protected rangeR, rangeG, rangeB
  Protected pixelCount = *p\lg * *p\ht
  Protected *source = *p\addr[0]
  Protected *cible = *p\addr[1]
  start = ( *p\thread_pos * pixelCount ) / *p\thread_max
  stop  = ( (*p\thread_pos + 1) * pixelCount ) / *p\thread_max - 1
  For i = 0 To pixelCount - 1
    var = PeekL(*source + i << 2)
    getrgb(var, r, g, b)
    
    If r < rmin : rmin = r : EndIf
    If g < gmin : gmin = g : EndIf
    If b < bmin : bmin = b : EndIf
    
    If r > rmax : rmax = r : EndIf
    If g > gmax : gmax = g : EndIf
    If b > bmax : bmax = b : EndIf
  Next
  rangeR = rmax - rmin
  rangeG = gmax - gmin
  rangeB = bmax - bmin
  If rangeR = 0 : rangeR = 1 : EndIf
  If rangeG = 0 : rangeG = 1 : EndIf
  If rangeB = 0 : rangeB = 1 : EndIf
  
  For i = start To stop
    var = PeekL(*source + i << 2)
    getrgb(var, r, g, b)
    r = ((r - rmin) * 255) / rangeR
    g = ((g - gmin) * 255) / rangeG
    b = ((b - bmin) * 255) / rangeB
    Clamp_rgb(r, g, b)
    PokeL(*cible + i << 2, (var & $FF000000) | (r << 16) | (g << 8) | b)
  Next
EndProcedure

Procedure Normalize_Color_Filter(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Normalize_Color"
    param\remarque = ""
    param\info[0] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 2 : param\info_data(0,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Normalize_Color() , 0)
EndProcedure

;-------------------------

Procedure Pencil_MT(*p.parametre)
  Protected i, a, r, g, b, grey, pixel , grey1
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected intensity.f = ((*p\option[0] /5) + 40) / 100
  Protected limit = *p\option[1]
  Protected couleur = *p\option[2]
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected totalPixels = lg * ht
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max

  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    getargb(*srcPixel\l, a, r, g, b)
    grey = ((r * 1225 + g * 2405 + b * 466) >> 12)
    grey1 = grey
    If couleur
      grey = grey / couleur
      grey = grey * couleur
    EndIf
    If grey1 < (limit * intensity)
      If grey > 0
        grey - ((i % 4) * 4 * intensity)
        grey + (((i / lg) % 8) * 2 * intensity)
        pixel = Random(grey)
        If pixel < grey * intensity
          grey = pixel
        EndIf
      Else
        grey = Random(Int(intensity * 32.0))
      EndIf
    Else
      If grey > (254 - (16 * intensity)) : grey = 255 : EndIf
    EndIf
    clamp(grey , 0 , 255)
    *dstPixel\l = (a << 24) | (grey << 16) | (grey << 8) | grey
  Next
EndProcedure


Procedure PencilImage(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Pencil Sketch"
    param\remarque = "Effet Crayon à Papier"
    param\info[0] = "Intensité"
    param\info[1] = "limite"
    param\info[2] = "couleur"
    param\info[3] = "Masque"
    param\info_data(0,0) = 0   : param\info_data(0,1) = 100 : param\info_data(0,2) = 50
    param\info_data(1,0) = 0   : param\info_data(1,1) = 255 : param\info_data(1,2) = 240
    param\info_data(2,0) = 0   : param\info_data(2,1) = 64  : param\info_data(2,2) = 0
    param\info_data(3,0) = 0   : param\info_data(3,1) = 2   : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Pencil_MT() , 3)
EndProcedure

;------------------------


Procedure Posterize_MT(*p.parametre)
  Protected i, pixel.l, a.l, r.l, g.l, b.l
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  Protected *cr = *p\addr[2]
  Protected *cg = *p\addr[3]
  Protected *cb = *p\addr[4]
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    pixel = *srcPixel\l
    GetARGB(pixel, a, r, g, b)
    r = PeekA(*cr + r)
    g = PeekA(*cg + g)
    b = PeekA(*cb + b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

Procedure Posterize(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Posterize"
    param\remarque = "reduit le nombre de couleur"
    param\info[0] = "rourge"
    param\info[1] = "vert"
    param\info[2] = "bleu"
    param\info[3] = "masque"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 255 : param\info_data(0,2) = 255
    param\info_data(1,0) = 1 : param\info_data(1,1) = 255 : param\info_data(1,2) = 255
    param\info_data(2,0) = 1 : param\info_data(2,1) = 255 : param\info_data(2,2) = 255
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2  : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf

  Protected i
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  Protected levelr = *param\option[0]
  Protected levelg = *param\option[1]
  Protected levelb = *param\option[2]
  clamp(levelr , 1 , 255)
  clamp(levelg , 1 , 255)
  clamp(levelb , 1 , 255)
  levelr = 256 - levelr
  levelg = 256 - levelg
  levelb = 256 - levelb
  Protected *cr = AllocateMemory(256)
  Protected *cg = AllocateMemory(256)
  Protected *cb = AllocateMemory(256)
  For i = 0 To 255
    PokeA(*cr + i , ((i / levelr) * levelr) )
    PokeA(*cg + i , ((i / levelg) * levelg) )
    PokeA(*cb + i , ((i / levelb) * levelb) )
  Next
  *param\addr[2] = *cr
  *param\addr[3] = *cg
  *param\addr[4] = *cb
  
  filter_start(@Posterize_MT() , 3)
  
  FreeMemory(*cr)
  FreeMemory(*cg)
  FreeMemory(*cb)
EndProcedure

;------------------------

Procedure RaviverCouleurs_MT(*p.parametre)
  Protected i, a, r, g, b, gray
  Protected diffR, diffG, diffB, maxDiff
  Protected lightness, saturation, factor, factorInput
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected minSaturation = 4
  Protected minLightness = 32
  factorInput = *p\option[0]
  clamp(factorInput, 0, 500)
  factorInput = 256 + (factorInput * 256) / 100
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    GetARGB(*srcPixel\l, a, r, g, b)
    gray = (r * 1365 + g * 1365 + b * 1366) >> 12
    lightness = gray
    diffR = r - gray
    diffG = g - gray
    diffB = b - gray
    max3(maxDiff, Abs(diffR), Abs(diffG), Abs(diffB))
    If maxDiff > minSaturation And lightness > minLightness
      saturation = (maxDiff << 8) / 128 
      factor = 256 + ((factorInput - 256) * saturation) >> 8
      r = gray + (diffR * factor) >> 8
      g = gray + (diffG * factor) >> 8
      b = gray + (diffB * factor) >> 8
    EndIf
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

Procedure RaviverCouleurs(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "RaviverCouleurs"
    param\remarque = ""
    param\info[0] = "Intensité"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 512 : param\info_data(0,2) = 255
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@RaviverCouleurs_MT() , 1)
EndProcedure

;------------------------

Procedure Saturation_MT(*p.parametre)
  Protected i, a.l ,r.l, g.l, b.l , gray
  Protected intensity.i = *p\option[0]
  clamp( intensity , 0 , 255)
  Protected invIntensity.i = 256 - intensity
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected totalPixels = *p\lg * *p\ht
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    getargb(*srcPixel\l, a, r, g, b)
    gray = (r * 77 + g * 151 + b * 28) >> 8
    r = (r * intensity + gray * invIntensity) >> 8
    g = (g * intensity + gray * invIntensity) >> 8
    b = (b * intensity + gray * invIntensity) >> 8
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) + (r << 16) + (g << 8) + b
  Next
EndProcedure

Procedure Saturation(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Saturation"
    param\remarque = ""
    param\info[0] = "saturation"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 255 : param\info_data(0,2) = 255
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf 
  filter_start(@Saturation_MT() , 1)
EndProcedure

;------------------------

Procedure Sepia_MT(*p.parametre)
  Protected i, r, g, b, a, var, alpha
  Protected totalPixels = *p\lg * *p\ht
  Protected *src.Pixel32
  Protected *dst.Pixel32
  Protected *mask = *p\mask
  Protected factor.f = (*p\option[0] - 100)/100
  Protected start = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected stop  = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = start To stop - 1
    *src = *p\addr[0] + (i << 2)
    *dst = *p\addr[1] + (i << 2)
    var = *src\l
    GetARGB(var, a, r, g, b)
    Protected r2 = (r * 101 + g * 197 + b * 48) >> 8
    Protected g2 = (r * 89  + g * 175 + b * 43) >> 8
    Protected b2 = (r * 70  + g * 137 + b * 33) >> 8
    r2 + (factor * 40)
    b2 - (factor * 40)
    Clamp_RGB(r2, g2, b2)
    *dst\l = (a << 24) | (r2 << 16) | (g2 << 8) | b2
  Next
EndProcedure

Procedure Sepia(*param.parametre)
  If *param\info_active
    param\typ = #Filter_Type_Color
    param\name = "Sepia"
    param\remarque = "Convertit l'image avec une teinte sépia chaude"
    *param\info[0] = "Filtre sépia"
    *param\info[1] = "Chaud\froid"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 200  : param\info_data(0,2) = 100
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Sepia_MT() , 1)
EndProcedure

;------------------------

Procedure SquareLaw_MT(*p.parametre)
  Protected i, a, r, g, b, alpha, var
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected *mask = *p\mask

  Clamp(*p\option[0], 1, 255)
  Protected sqrval = *p\option[0] * *p\option[0]
  Protected Dim tab.a(255)
  For i = 0 To 255
    Protected inv = 255 - i
    Protected val.f = sqrval - inv * inv
    If val < 0 : val = 0 : EndIf
    tab(i) = Int(Sqr(val))
  Next
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    var = *srcPixel\l
    getargb(var, a , r, g, b)
    r = tab(r)
    g = tab(g)
    b = tab(b)
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a<< 24) | (r << 16) | (g << 8) | b
  Next
  FreeArray(tab())
EndProcedure


Procedure SquareLaw_Lightening(*param.parametre)
  If *param\info_active
    param\typ = #Filter_Type_Color
    param\name = "SquareLaw_Lightening"
    param\remarque = "Éclaircissement par loi quadratique"
    *param\info[0] = "Intensité"
    *param\info[1] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 255 : param\info_data(0,2) = 127
    param\info_data(1,1) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@SquareLaw_MT() , 1)
EndProcedure

;------------------------

Procedure.f HUEtoRGB(p.f, q.f, t.f)
  If t < 0 : t + 360 : EndIf
  If t >= 360 : t - 360 : EndIf
  If t < 60
    ProcedureReturn p + (q - p) * t / 60
  ElseIf t < 180
    ProcedureReturn q
  ElseIf t < 240
    ProcedureReturn p + (q - p) * (240 - t) / 60
  Else
    ProcedureReturn p
  EndIf
EndProcedure

Procedure teinte_MT(*p.parametre)
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected totalPixels = lg * ht
  Protected mode = *p\option[1]
  Protected angle = (#PI * *p\option[0]) / 180
  Protected cs = Cos(angle) * 256
  Protected sc  = Sin(angle) * 256
  Protected d.f = 1 / 100
  Protected j, var, a, r, g, b
  Protected ry.f, by.f, y.f, ryy.f, byy.f, gyy.f
  Protected h.f, rf.f, gf.f, bf.f
  Protected q.f, p.f , i.f
  Protected start = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected stop  = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For j = start To stop - 1
    var = PeekL(*source + j << 2)
    getargb(var, a, r, g, b)
    Select mode
      Case 0 
        ry = (70 * r - 59 * g - 11 * b) * d
        by = (-30 * r - 59 * g + 89 * b) * d
        y  = (30 * r + 59 * g + 11 * b) * d
        ryy = (sc * by + cs * ry) /256
        byy = (cs * by - sc * ry) /256
        gyy = (-51 * ryy - 19 * byy) * d
        r = y + ryy
        g = y + gyy
        b = y + byy
      Case 1
        I = 0.596*r - 0.274*g - 0.322*b
        q = 0.211*r - 0.523*g + 0.312*b
        y = 0.299*r + 0.587*g + 0.114*b
        Protected I2.f = I * Cos(angle) - Q * Sin(angle)
        Protected Q2.f = I * Sin(angle) + Q * Cos(angle)
        r = y + 0.956*I2 + 0.621*Q2
        g = y - 0.272*I2 - 0.647*Q2
        b = y - 1.106*I2 + 1.703*Q2
      Case 2 
        rf = r / 255.0
        gf = g / 255.0
        bf = b / 255.0
        Protected maxVal.f = rf
        If gf > maxVal : maxVal = gf : EndIf
        If bf > maxVal : maxVal = bf : EndIf
        Protected minVal.f = rf
        If gf < minVal : minVal = gf : EndIf
        If bf < minVal : minVal = bf : EndIf
        Protected l.f = (maxVal + minVal) / 2.0
        Protected s.f = 0.0
        Protected delta.f = maxVal - minVal
        If delta = 0.0
          rf = l : gf = l : bf = l
        Else
          If l < 0.5
            s = delta / (maxVal + minVal)
          Else
            s = delta / (2.0 - maxVal - minVal)
          EndIf

          Select maxVal
            Case rf
              h = (gf - bf) / delta
              If gf < bf : h = h + 6.0 : EndIf
            Case gf
              h = (bf - rf) / delta + 2.0
            Case bf
              h = (rf - gf) / delta + 4.0
          EndSelect
          h * 60.0
          h = h + *p\option[0]
          If h >= 360 : h = h - 360 : EndIf
          If h < 0    : h = h + 360 : EndIf
          If l < 0.5
            q = l * (1 + s)
          Else
            q = l + s - (l * s)
          EndIf
          p = 2 * l - q
          rf = HUEtoRGB(p, q, h + 120)
          gf = HUEtoRGB(p, q, h)
          bf = HUEtoRGB(p, q, h - 120)
        EndIf
        r = rf * 255
        g = gf * 255
        b = bf * 255
    EndSelect
    Clamp_rgb(r, g, b)
    PokeL(*cible + j << 2, a << 24 | r << 16 | g << 8 | b)
  Next

EndProcedure

Procedure teinte(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Color
    param\name = "teinte"
    param\remarque = ""
    param\info[0] = "angle"
    param\info[1] = "YUV, YIQ, HSL"
    param\info[2] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 360 : param\info_data(0,2) = 1
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2 : param\info_data(1,2) = 0
    param\info_data(2,0) = 0 : param\info_data(2,1) = 2 : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@teinte_MT() , 2)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 1276
; FirstLine = 1409
; Folding = ---------
; EnableXP
; DPIAware