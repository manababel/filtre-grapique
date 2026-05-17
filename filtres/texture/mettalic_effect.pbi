

Procedure.l AssignTables (*FilterCtx.FilterParams)
  
  With *FilterCtx
    Protected *rt.PixelArray8 = *FilterCtx\addr[2]
    Protected *gt.PixelArray8 = *FilterCtx\addr[3]
    Protected *bt.PixelArray8 = *FilterCtx\addr[4]
    Protected *source.PixelArray32 = \addr[0]
    Protected *cible.PixelArray32  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected tt = lg * ht
    Protected  i , r , g  , b

    For i = 0 To tt - 1
      getrgb(*cible\pixel[i] , r , g , b)
      *cible\pixel[i] = *rt\b[r] << 16 + *gt\b[g] << 8 + *bt\b[b]
    Next
  EndWith
  
EndProcedure

Procedure.l Mettalic_GradientValue (*FilterCtx.FilterParams , FirstValue, SecondValue, Gradient.f)
  Protected *mem.Array32 = *FilterCtx\addr[5]
  Protected v1.f = *mem\l[FirstValue]
  Protected v2.f = *mem\l[SecondValue]
  If Gradient = 0.0 : ProcedureReturn *mem\l[FirstValue] : EndIf
  If Gradient = 255.0 : ProcedureReturn *mem\l[SecondValue] :EndIf
  ProcedureReturn ((v1 * (255 - Gradient) + v2 * Gradient) / 256) 
EndProcedure

Procedure.l  Mettalic_MakeGradient(*FilterCtx.FilterParams)
    
  Protected *rt.PixelArray8 = *FilterCtx\addr[2]
  Protected *gt.PixelArray8 = *FilterCtx\addr[3]
  Protected *bt.PixelArray8 = *FilterCtx\addr[4]
  Protected *mem.Array32 = *FilterCtx\addr[5]
  
  Protected.i i
  Define.f delta, temp
  If *mem\l[4] = *mem\l[0] : ProcedureReturn : EndIf   
  delta = 255.0 / (*mem\l[4] - *mem\l[0])
  
  For i = *mem\l[0] To *mem\l[4]
    temp = (i - *mem\l[0]) * delta
    *rt\b[i] = Mettalic_GradientValue (*FilterCtx ,1, 5, temp) 
    *gt\b[i] = Mettalic_GradientValue (*FilterCtx ,2, 6, temp) 
    *bt\b[i] = Mettalic_GradientValue (*FilterCtx ,3, 7, temp) 
  Next 
EndProcedure

Procedure.l ApplyMetallicShiftLayer (*FilterCtx.FilterParams) 
  With *FilterCtx
    If \option[1] < 1 : ProcedureReturn : EndIf

    Protected levels.l = \option[1]
    Protected option.l = \option[2]
    Protected i , NewPosition , factor
    Protected *mt.PixelArray8 = \addr[2]
    Protected *gt.PixelArray8 = \addr[3]
    Protected *bt.PixelArray8 = \addr[4]
    Protected *tt.PixelArray8 = \addr[6]
    Protected *mem.Array32 = \addr[5]
    
    factor = 255 / levels
    For i = 0 To Levels-1   
      If i % 2
        *mem\l[0] = i * factor
        *mem\l[1] = 255 : *mem\l[2] = 255 : *mem\l[3] = 255
        *mem\l[4] = (i + 1) * factor
        *mem\l[5] = 0 : *mem\l[6] = 0 : *mem\l[7] = 0
        *mt\b[255] = 0
      Else
        *mem\l[0] = i * factor + 1
        *mem\l[1] = 0 : *mem\l[2] = 0 : *mem\l[3] = 0       
        *mem\l[4] = (i + 1) * factor
        *mem\l[5] = 255 : *mem\l[6] = 255 : *mem\l[7] = 255
        *mt\b[255] = 255
      EndIf
      Mettalic_MakeGradient (*FilterCtx)
    Next
    
    CopyMemory (*mt, *tt , 256)
    For i = 0 To 255
      NewPosition = (i + option) & $FF
      *mt\b[NewPosition] = *tt\b[i]
      *gt\b[NewPosition] = *tt\b[i]
      *bt\b[NewPosition] = *tt\b[i]
    Next 
    
    AssignTables(*FilterCtx)
  EndWith
EndProcedure

Procedure.l ApplyGoldLayer(*FilterCtx.FilterParams) 
  
  Dim rTable.a (256)
  Dim gTable.a (256)
  Dim bTable.a (256)
  
  Protected *mem.Array32 = *FilterCtx\addr[5]
  
  With *mem
    \l[0] = 0  : \l[1] = 0   : \l[2] = 0  : \l[3] = 0
    \l[4] = 55 : \l[5] = 190 : \l[6] = 55 : \l[7] = 0
    Mettalic_MakeGradient (*FilterCtx.FilterParams)
    
    \l[0] = 55  : \l[1] = 190 : \l[2] = 55  : \l[3] = 0
    \l[4] = 155 : \l[5] = 255 : \l[6] = 190 : \l[7] = 50
    Mettalic_MakeGradient (*FilterCtx.FilterParams)
    
    \l[0] = 155 : \l[1] = 255 : \l[2] = 190 : \l[3] = 50
    \l[4] = 255 : \l[5] = 255 : \l[6] = 255 : \l[7] = 255
    Mettalic_MakeGradient (*FilterCtx.FilterParams)
    AssignTables (*FilterCtx)
  EndWith
EndProcedure

Procedure Metallic_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.PixelArray32 = \addr[0]
    Protected *cible.PixelArray32  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected tt = lg * ht
    Protected  i , r , g  , b , gray
 
    For i = 0 To tt - 1
      getrgb(*source\pixel[i] , r , g , b)
      Gray = (Int((r + g + b / 3)))  & 255
      *cible\pixel[i] = gray * $10101
    Next
  
    ApplyMetallicShiftLayer (*FilterCtx) 
    If \option[0]      
      ApplyGoldLayer(*FilterCtx)
    EndIf
    
  EndWith
EndProcedure



Procedure MetallicEx(*FilterCtx.FilterParams)
  Restore Metalic_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    \addr[2] = AllocateMemory(256)
    \addr[3] = AllocateMemory(256)
    \addr[4] = AllocateMemory(256)
    \addr[6] = AllocateMemory(256)
    \addr[5] = AllocateMemory(9 * 4)
  EndWith
  
  Create_MultiThread_MT(@Metallic_MT())
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure Metallic(source, cible, mask, gray , var2 , var3)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = gray
    \option[1] = var2
    \option[2] = var3
  EndWith
  MetallicEx(FilterCtx)
EndProcedure

DataSection
  Metalic_Data:
  Data.s "Metallic"
  Data.s ""
  Data.i #FilterType_TexturePattern
  Data.i 0
  
  Data.s "gray / color" : Data.i 0, 1, 0
  Data.s "option 1" : Data.i 1, 10, 1
  Data.s "option 2" : Data.i 0, 255, 0
  Data.s "XXX"
EndDataSection







; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 85
; FirstLine = 81
; Folding = --
; EnableXP
; DPIAware