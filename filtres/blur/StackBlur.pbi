

Procedure StackBlur_Horizontal_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *temp   = *param\addr[1]  ; image tampon
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radiusX = *param\option[0]
  If radiusX <= 0 Or *source = 0 Or *temp = 0 : ProcedureReturn : EndIf
  Protected x , y , i
  Protected r , g , b
  
  macro_calul_tread(ht)
  
  Protected div = radiusX * 2 + 1
  Protected wm = lg - 1
  Protected *stack = AllocateMemory(div * 3 * SizeOf(Long))
  If *stack = 0 : ProcedureReturn : EndIf
  
   Protected *scr.Pixel32
   
  For y = thread_start To thread_stop - 1
    Protected rSum, gSum, bSum
    rSum = 0
    gSum = 0
    bSum = 0

    For i = -radiusX To radiusX
      Protected px = i
      Clamp(px, 0, wm)
      *scr = *source + ((y * lg + px) << 2)
      getrgb(*scr\l , r , g , b )
      Protected idx = (i + radiusX) * 3
      PokeL(*stack + idx << 2, r)
      PokeL(*stack + (idx + 1) << 2, g)
      PokeL(*stack + (idx + 2) << 2, b)
      rSum + r : gSum + g : bSum + b
    Next

    For x = 0 To lg - 1
      Protected rAvg = rSum / div
      Protected gAvg = gSum / div
      Protected bAvg = bSum / div
      PokeL(*temp + ((y * lg + x) << 2), (rAvg << 16) | (gAvg << 8) | bAvg)

      Protected outIdx = ((x - radiusX + div) % div) * 3
      rSum - PeekL(*stack + outIdx << 2)
      gSum - PeekL(*stack + (outIdx + 1) << 2)
      bSum - PeekL(*stack + (outIdx + 2) << 2)

      Protected nextX = x + radiusX + 1
      Clamp(nextX, 0, wm)
      *scr = *source + ((y * lg + nextX) << 2)
      getrgb(*scr\l , r , g , b )
      Protected inIdx = ((x + radiusX + 1) % div) * 3
      PokeL(*stack + inIdx << 2, r)
      PokeL(*stack + (inIdx + 1) << 2, g)
      PokeL(*stack + (inIdx + 2) << 2, b)
      rSum + r : gSum + g : bSum + b
    Next
  Next

  FreeMemory(*stack)
EndProcedure

Procedure StackBlur_Vertical_MT(*param.parametre)
  Protected *temp   = *param\addr[0]  ; image temp
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radiusY = *param\option[1]
  If radiusY <= 0 Or *temp = 0 Or *cible = 0 : ProcedureReturn : EndIf
  Protected x , y , i
  Protected r , g , b

  macro_calul_tread(lg)
  
  Protected div = radiusY * 2 + 1
  Protected hm = ht - 1
  Protected *stack = AllocateMemory(div * 3 * SizeOf(Long))
  If *stack = 0 : ProcedureReturn : EndIf
  
   Protected *scr.Pixel32
   
  For x = thread_start To thread_stop - 1
    Protected rSum, gSum, bSum
    rSum = 0
    gSum = 0
    bSum = 0

    For i = -radiusY To radiusY
      Protected py = i
      Clamp(py, 0, hm)
      *scr = *temp + ((py * lg + x) << 2)
      getrgb(*scr\l , r , g , b )
      Protected idx = (i + radiusY) * 3
      PokeL(*stack + idx << 2, r)
      PokeL(*stack + (idx + 1) << 2, g)
      PokeL(*stack + (idx + 2) << 2, b)
      rSum + r : gSum + g : bSum + b
    Next

    For y = 0 To ht - 1
      Protected rAvg = rSum / div
      Protected gAvg = gSum / div
      Protected bAvg = bSum / div
      PokeL(*cible + ((y * lg + x) << 2), (rAvg << 16) | (gAvg << 8) | bAvg)

      Protected outIdx = ((y - radiusY + div) % div) * 3
      rSum - PeekL(*stack + outIdx << 2)
      gSum - PeekL(*stack + (outIdx + 1) << 2)
      bSum - PeekL(*stack + (outIdx + 2) << 2)

      Protected nextY = y + radiusY + 1
      Clamp(nextY, 0, hm)
      *scr = *temp + ((nextY * lg + x) << 2)
      getrgb(*scr\l , r , g , b )
      Protected inIdx = ((y + radiusY + 1) % div) * 3
      PokeL(*stack + inIdx << 2, r)
      PokeL(*stack + (inIdx + 1) << 2, g)
      PokeL(*stack + (inIdx + 2) << 2, b)
      rSum + r : gSum + g : bSum + b
    Next
  Next

  FreeMemory(*stack)
EndProcedure

Procedure StackBlur_boucle(*param.parametre)
  Protected i 
  CopyMemory(*param\addr[0] , *param\addr[1] , *param\lg * *param\ht * 4)
  
  For i = 1 To *param\option[2]
    
    *param\addr[0] = *param\addr[1]
    *param\addr[1] = *param\addr[2]
    MultiThread_MT(@StackBlur_Horizontal_MT())
    
    *param\addr[0] = *param\addr[2]
    *param\addr[1] = *param\cible
    MultiThread_MT(@StackBlur_Vertical_MT())
    
  Next
EndProcedure

Procedure StackBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Classic
    *param\name = "StackBlur"
    *param\remarque = "Flou rapide par empilement"
    *param\info[0] = "Radius X"
    *param\info[1] = "Radius Y"
    *param\info[2] = "Nombre de passe"
    *param\info[3] = "Masque"
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 100 : *param\info_data(0,2) = 5
    *param\info_data(1,0) = 1 : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 5
    *param\info_data(2,0) = 1 : *param\info_data(2,1) = 3   : *param\info_data(2,2) = 1
    *param\info_data(3,0) = 0 : *param\info_data(3,1) = 2   : *param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  
  clamp(*param\addr[0] , 1 , 100)
  clamp(*param\addr[1] , 1 , 100)
  clamp(*param\addr[2] , 1 , 3)
  
  *param\addr[2] = AllocateMemory(*param\lg * *param\ht * 4)
  If *param\addr[2] = 0 : ProcedureReturn : EndIf
  
  Filter_BufferPrepare(*param.parametre)
  StackBlur_boucle(*param.parametre)
  macro_Filter_BufferFinalize(3)
  
  If *param\addr[2] <> 0 : FreeMemory(*param\addr[2]) : EndIf
  
EndProcedure




; IDE Options = PureBasic 6.21 (Windows - x86)
; CursorPosition = 103
; Folding = -
; EnableXP
; DPIAware