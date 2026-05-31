Macro SummedArea_declaration()
  Protected.l lg = *FilterCtx\image_lg[0]
  Protected.l ht = *FilterCtx\image_ht[0]
  Protected *satA.array32 = *FilterCtx\addr[2]
  Protected *satR.array32 = *FilterCtx\addr[3]
  Protected *satG.array32 = *FilterCtx\addr[4]
  Protected *satB.array32 = *FilterCtx\addr[5]
  Protected.l x, y
EndMacro

Procedure SummedArea_Create_SAT_part1(*FilterCtx.FilterParams)
  SummedArea_declaration()
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected.a a, r, g, b 
    Protected.l idx, idxPrev   
    macro_calul_tread(ht) 
    For y = thread_start To thread_stop -1
      idx = y * lg
      getargb(*src\pixel[idx], a, r, g, b)
      *satA\l[idx] = a : *satR\l[idx] = r : *satG\l[idx] = g : *satB\l[idx] = b
      For x = 1 To lg - 1
        idx = y * lg + x
        idxPrev = idx - 1
        getargb(*src\pixel[idx], a, r, g, b)
        *satA\l[idx] = a + *satA\l[idxPrev]
        *satR\l[idx] = r + *satR\l[idxPrev]
        *satG\l[idx] = g + *satG\l[idxPrev]
        *satB\l[idx] = b + *satB\l[idxPrev]
      Next
    Next
  EndWith
EndProcedure

Procedure SummedArea_Create_SAT_part2(*FilterCtx.FilterParams)
  SummedArea_declaration()
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected.a a, r, g, b
    Protected.l sA, sR, sG, sB
    Protected.l idx, idxPrev   
    macro_calul_tread(lg)  
    For x = thread_start To thread_stop - 1
      For y = 1 To ht - 1
        idx = y * lg + x
        idxPrev = (y - 1) * lg + x
        *satA\l[idx] + *satA\l[idxPrev]
        *satR\l[idx] + *satR\l[idxPrev]
        *satG\l[idx] + *satG\l[idxPrev]
        *satB\l[idx] + *satB\l[idxPrev]
      Next
    Next
  EndWith
EndProcedure

Macro SummedArea_GetRectSum(pSAT, targetVar)
  targetVar = pSAT\l[y2 * lg + x2]
  If x1 >= 0 : targetVar - pSAT\l[y2 * lg + x1] : EndIf
  If y1 >= 0 : targetVar - pSAT\l[y1 * lg + x2] : EndIf
  If x1 >= 0 And y1 >= 0 : targetVar + pSAT\l[y1 * lg + x1] : EndIf
EndMacro

Procedure SummedArea_SAT_Apply(*FilterCtx.FilterParams)
  SummedArea_declaration()
  With *FilterCtx
    Protected.l rx = \option[0]
    Protected.l ry = \option[0] 
    Protected *dst.PixelArray32 = \addr[1]
    Protected.l x1, y1, x2, y2
    Protected.l count, resA, resR, resG, resB, val
    Protected.l tempX1
    Protected.l tempY1
    macro_calul_tread(ht) 
    For y = thread_start To thread_stop -1
      For x = 0 To lg - 1
        x1 = x - rx - 1 : x2 = x + rx
        y1 = y - ry - 1 : y2 = y + ry
        If x2 > lg - 1 : x2 = lg - 1 : EndIf
        If y2 > ht - 1 : y2 = ht - 1 : EndIf
        tempX1 = x1
        tempY1 = y1
        If tempX1 < -1 : tempX1 = -1 : EndIf
        If tempY1 < -1 : tempY1 = -1 : EndIf
        count = (x2 - tempX1) * (y2 - tempY1)
        If count > 0
          SummedArea_GetRectSum(*satA, resA)
          SummedArea_GetRectSum(*satR, resR)
          SummedArea_GetRectSum(*satG, resG)
          SummedArea_GetRectSum(*satB, resB)
          *dst\pixel[y * lg + x] = ((resA / count) << 24) | ((resR / count) << 16) | ((resG / count) << 8) | (resB / count)
        Else
          *dst\pixel[y * lg + x] = 0
        EndIf
      Next
    Next
  EndWith
EndProcedure

Macro SummedAreaEx_PB()
  Create_MultiThread_MT(@SummedArea_Create_SAT_part1())
  Create_MultiThread_MT(@SummedArea_Create_SAT_part2())
  Create_MultiThread_MT(@SummedArea_SAT_Apply())
EndMacro

Procedure SummedAreaEx(*FilterCtx.FilterParams)
  Restore SummedArea_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  With *FilterCtx
    Protected i
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]   
    For i = 2 To 5 : \addr[i] = AllocateMemory(lg * ht * 4) : Next
    If \addr[2] And \addr[3]  And \addr[4]  And \addr[5] 
      SummedAreaEx_PB()    
      mask_update(*FilterCtx.FilterParams , last_data)
    EndIf
    ; Libération mémoire
    For i = 2 To 5 : If \addr[i] : FreeMemory(\addr[i]) : EndIf : Next
  EndWith
EndProcedure

Procedure SummedArea(source , cible , mask , rayon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  FilterCtx\option[0] = rayon
  SummedAreaEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  SummedArea_data:
  Data.s "SummedArea"
  Data.s "Flou Box area ( aide:ok , Pb:Ok )"
  Data.i #FilterType_Blur
  Data.i #Blur_Classic
  
  Data.s "Rayon"           ; Rayon horizontal
  Data.i 1,100,1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 23
; FirstLine = 84
; Folding = --
; EnableXP
; DPIAware