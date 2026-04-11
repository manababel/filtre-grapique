; ----------------------------------------------------------------------------------
; Thread pour appliquer l'effet "Bend" (distorsion colorimétrique par sinus).
Procedure Bend_MT(*p.parametre)
  Protected i, pixel.l, a, r, g, b
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32

  Protected tabr = *p\addr[3]
  Protected tabg = *p\addr[4]
  Protected tabb = *p\addr[5]
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  *srcPixel = *p\addr[0] + (startPos << 2)
  *dstPixel = *p\addr[1] + (startPos << 2)
  For i = startPos To endPos - 1
    pixel = *srcPixel\l
    GetARGB(pixel, a, r, g, b)
    r = PeekA(tabr + r) 
    g = PeekA(tabg + g) 
    b = PeekA(tabb + b) 
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure principale de l’effet "Bend"
Procedure Bend(*param.parametre)
  ; Mode info
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Bend"
    param\remarque = "Distorsion RGB"
    param\info[0] = "Angle Rouge"
    param\info[1] = "Angle Vert"
    param\info[2] = "Angle Bleu"
    param\info[3] = "Masque"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 512 : param\info_data(0,2) = 255
    param\info_data(1,0) = 1 : param\info_data(1,1) = 512 : param\info_data(1,2) = 255
    param\info_data(2,0) = 1 : param\info_data(2,1) = 512 : param\info_data(2,2) = 255
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2   : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  
  *param\addr[3] = AllocateMemory(256)
  *param\addr[4] = AllocateMemory(256)
  *param\addr[5] = AllocateMemory(256)
  
   ; Conversion des angles en radians
  Protected r1.f = (*param\option[0] - 180) / 255.0 * #PI / 180.0
  Protected g1.f = (*param\option[1] - 180) / 255.0 * #PI / 180.0
  Protected b1.f = (*param\option[2] - 180) / 255.0 * #PI / 180.0

  Protected r , g , b , i
  For i = 0 To 255
    r = Sin(i * r1) * 127 + i
    g = Sin(i * g1) * 127 + i
    b = Sin(i * b1) * 127 + i
    Clamp_RGB(r, g, b)
    PokeA(*param\addr[3] + i , r)
    PokeA(*param\addr[4] + i , g)
    PokeA(*param\addr[5] + i , b)
  Next

  filter_start(@Bend_MT(), 3, 1)
  
  FreeMemory(*param\addr[3])
  FreeMemory(*param\addr[4])
  FreeMemory(*param\addr[5])
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 57
; FirstLine = 13
; Folding = -
; EnableXP
; DPIAware