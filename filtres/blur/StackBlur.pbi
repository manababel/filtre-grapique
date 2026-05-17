

Procedure StackBlur_Horizontal_MT(*FilterCtx.FilterParams)
  Protected *source = *FilterCtx\addr[0]
  Protected *temp   = *FilterCtx\addr[1]  ; image tampon
  Protected lg = *FilterCtx\image_lg[0]
  Protected ht = *FilterCtx\image_ht[0]
  Protected radiusX = *FilterCtx\option[0]
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

Procedure StackBlur_Vertical_MT(*FilterCtx.FilterParams)
  Protected *temp   = *FilterCtx\addr[0]  ; image temp
  Protected *cible  = *FilterCtx\addr[1]
  Protected lg = *FilterCtx\image_lg[0]
  Protected ht = *FilterCtx\image_ht[0]
  Protected radiusY = *FilterCtx\option[1]
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

Procedure StackBlurEx(*FilterCtx.FilterParams)
  
  Restore StackBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With FilterCtx
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]
    ;-- Allocation mémoire pour l'image temporaire
    \addr[2] = AllocateMemory(lg * ht * 4)
    If \addr[2] = 0 : ProcedureReturn : EndIf

  Protected i 
  CopyMemory(\image[0] , \image[1] , \image_lg[0] * \image_ht[0] * 4)
  
  For i = 1 To \option[2]
    \addr[0] = \image[1]
    \addr[1] = \addr[2]
    Create_MultiThread_MT(@StackBlur_Horizontal_MT())
    \addr[0] = \addr[2]
    \addr[1] = \image[1]
    Create_MultiThread_MT(@StackBlur_Vertical_MT())
  Next
  
  mask_update(*FilterCtx.FilterParams , last_data)
  
    If \addr[2] <> 0 : FreeMemory(\addr[2]) : EndIf
  EndWith
EndProcedure

Procedure StackBlur(source , cible , mask , rx , ry , ndp = 1)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rx
    \option[1] = ry
    \option[2] = ndp
  EndWith
  StackBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  StackBlur_data:
  Data.s "StackBlur"
  Data.s "Flou rapide par empilement"
  Data.i #FilterType_Blur
  Data.i #Blur_Classic
  
  Data.s "Rayon X"           ; Rayon horizontal
  Data.i 1,100,1
  Data.s "Rayon Y"           ; Rayon vertical
  Data.i 1,100,1
  Data.s "Nombre de passe"   ; Nombre d'itérations du filtre
  Data.i 1,3,1
  Data.s "XXX"
EndDataSection


; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 142
; FirstLine = 132
; Folding = -
; EnableXP
; DPIAware