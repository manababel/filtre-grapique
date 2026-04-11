
; ratio ∈ [0.0 – 1.0], stocké en "fixed point" (0 – 1000)
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
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected totalPixels = lg * ht
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  *srcPixel = *p\addr[0] + (startPos << 2)
  *dstPixel = *p\addr[1] + (startPos << 2)
  For i = startPos To endPos - 1
    getargb(*srcPixel\l , a , r , g , b)
    Protected grey = ((r * 1225 + g * 2405 + b * 466) >> 12)
    Protected ratio = (grey * 4016) >> 10
    Protected color = PeekL(*p\addr[2] + (ratio << 2))
    getargb(color, a, r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

Procedure FalseColour(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "False Colour"
    param\remarque = "Teinte basée sur l'intensité"
    param\info[0] = "Mode Couleur"
    param\info[1] = "Masque"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 360 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  
  Protected teinte.f = *param\option[0] ;* 0.01
  *param\addr[2] = AllocateMemory(1001 * 4)
  Protected i
  For i = 0 To 1000 : PokeL(*param\addr[2] + (i << 2) , FalseColour_RGBfromHSL(Mod((i/1000.0*360 + teinte) , 360), 1, 0.5)): Next
  
  filter_start(@FalseColour_MT(), 1, 1)
  FreeMemory(*param\addr[2])
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 36
; Folding = -
; EnableXP
; DPIAware