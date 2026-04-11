

Global Dim bits.a(0),Pitch,Count,Width,Height,Trim

Procedure Effect_ON(img)
 ; StartDrawing(ImageOutput(img))
 ; *Buffer     = DrawingBuffer() 
 ; Pitch       = DrawingBufferPitch()
 ; count       = Pitch*height
 ; ReDim bits.a(count)
 ; CopyMemory(*Buffer,@bits(),count)
 ; StopDrawing()
EndProcedure

Procedure Effect_OFF(img)
 ; StartDrawing(ImageOutput(img))
 ; *Buffer     = DrawingBuffer() 
 ; CopyMemory(@bits(),*Buffer,count)
 ; StopDrawing()
EndProcedure

;Structure ColorAmp
  ;Low.l
  ;High.l
  ;LowRed.l
  ;LowGreen.l
  ;LowBlue.l
  ;HighRed.l
  ;HighGreen.l
  ;HighBlue.l
;EndStructure

Procedure.l AssignTables (Array RedTable.a(1), Array GreenTable.a(1), Array  BlueTable.a(1), Array Bits.a(1),  Width, Height)
  Protected h , w , i
  For h = 0 To Height-1
    For w = 0 To Width-1
      i = h * pitch + trim * w
      Bits(i+2) = RedTable(Bits(i+2))
      Bits(i+1) = GreenTable(Bits(i+1))
      Bits( i ) = BlueTable(Bits( i ))
    Next
  Next  
EndProcedure

Procedure.l GradientValue ( FirstValue.d, SecondValue.d, Gradient.d)	
  If Gradient = 0.0	
    ProcedureReturn FirstValue
  EndIf
  If Gradient = 255.0
    ProcedureReturn SecondValue
  EndIf
  ProcedureReturn ((FirstValue * (255 - Gradient) + SecondValue * Gradient) / 256)
EndProcedure

;Procedure.l  MakeGradient ( *cAmp.ColorAmp,Array rTable.a(1),Array gTable.a(1),Array bTable.a(1))
  ;Protected i
  ;Define.d delta, temp
  ;If *cAmp\High = *cAmp\Low
    ;ProcedureReturn
  ;EndIf	
  ;delta = 255.0 / (*cAmp\High - *cAmp\Low)
  
  ;For i = *cAmp\Low To *cAmp\High
    ;temp = (i - *cAmp\Low) * delta
    ;rTable(i) = GradientValue (*cAmp\LowRed,   *cAmp\HighRed,   temp)
    ;gTable(i) = GradientValue (*cAmp\LowGreen, *cAmp\HighGreen, temp)
    ;bTable(i) = GradientValue (*cAmp\LowBlue,  *cAmp\HighBlue,  temp)
  ;Next  
;EndProcedure

Procedure ShiftTable (Array Table.a(1),Shift.l)  
  Protected i , NewPosition
  Dim tempTable.a (256)
  CopyMemory (@Table(), @tempTable(), 256)
  For i = 0 To 255
    NewPosition = Int(Abs(i + Shift)) &  $000000FF
    Table(NewPosition) = tempTable(i)
  Next
EndProcedure

Procedure.l  ApplyMetallicLayer (Array	Bits.a(1),Width.l ,Height.l ,Levels.l)
  Protected k , j
  Dim mTable.a (256)  
  If Levels < 2
    ProcedureReturn
  EndIf
  
  For j = 0 To 254    
    For k = 0 To 255
      mTable(j+1) = k
    Next
    While k > 1
      mTable(j+1) = k
      k-Levels
    Wend
    If Levels % 2 = 0
      mTable(255) = 0
    Else
      mTable(255) = 255
    EndIf    
    AssignTables (mTable(), mTable(), mTable(), Bits(), Width, Height)
  Next  
EndProcedure

Procedure.l ApplyMetallicShiftLayer (Array	Bits.a(1),Width.l,Height.l,Levels.l,Shift.l)  
  Protected i , factor
  ;cAmp.ColorAmp
  Dim mTable.a (256)
  
  If Levels < 1
    ProcedureReturn
  EndIf
  
  factor = 255 / Levels
  For i = 0 To Levels-1   
    If i % 2
      ;cAmp\Low = i * factor
      ;cAmp\LowRed = 255
      ;cAmp\LowGreen = 255
      ;cAmp\LowBlue = 255            
      ;cAmp\High = (i + 1) * factor
      ;cAmp\HighRed = 0
      ;cAmp\HighGreen = 0
      ;cAmp\HighBlue = 0
      mTable(255) = 0
    Else
      ;cAmp\Low = i * factor + 1
      ;cAmp\LowRed = 0
      ;cAmp\LowGreen = 0
      ;cAmp\LowBlue = 0      
      ;cAmp\High = (i + 1) * factor      
      ;cAmp\HighRed = 255
      ;cAmp\HighGreen = 255
      ;cAmp\HighBlue = 255
      mTable(255) = 255
    EndIf
   ; MakeGradient (@cAmp, mTable(), mTable(), mTable())
  Next
  ShiftTable (mTable(), Shift)
  AssignTables (mTable(), mTable(), mTable(), Bits(), Width, Height)
EndProcedure

Procedure.l ApplyGoldLayer (Array Bits.a(1),Width.l ,Height.l)  
  ;cAmp.ColorAmp
  Dim rTable.a (256)
  Dim gTable.a (256)
  Dim bTable.a (256)
  
  ;cAmp\Low = 0
  ;cAmp\LowRed = 0
  ;cAmp\LowGreen = 0
  ;cAmp\LowBlue = 0
  ;cAmp\High = 55
  ;cAmp\HighRed = 190
  ;cAmp\HighGreen = 55
  ;cAmp\HighBlue = 0
  ;MakeGradient (@cAmp, rTable(), gTable(), bTable())
  
  ;cAmp\Low = 55
  ;cAmp\LowRed = 190
  ;cAmp\LowGreen = 55
  ;cAmp\LowBlue = 0  
  ;cAmp\High = 155
  ;cAmp\HighRed = 255
  ;cAmp\HighGreen = 190
  ;cAmp\HighBlue = 50
  ;MakeGradient (@cAmp, rTable(), gTable(), bTable())
  
  ;cAmp\Low = 155
  ;cAmp\LowRed = 255
  ;cAmp\LowGreen = 190
  ;cAmp\LowBlue = 50
  ;cAmp\High = 255
  ;cAmp\HighRed = 255
  ;cAmp\HighGreen = 255
  ;cAmp\HighBlue = 255
  ;MakeGradient (@cAmp, rTable(), gTable(), bTable())
  AssignTables (rTable(), gTable(), bTable(), Bits(), Width, Height)
EndProcedure

Procedure Metallic (img,level=1,shift=1,mode=0)
  Protected i , h , w , gray
  width = ImageWidth(img)
  height = ImageHeight(img)
  If ImageDepth(img) = 32
    trim = 4
  Else
    trim = 3
  EndIf
  
  Effect_ON(img)
  
  If Level % 2
    Level+1
  EndIf
  
  For h = 0 To Height-1
    For w = 0 To Width-1      
      i = h * pitch + trim * w
      Gray = Int(Bits(i+2) + Bits(i+1) + Bits(i) / 3)
      Bits(i+2)= Gray
      Bits(i+1) = Gray
      Bits(i) = Gray
    Next
  Next
  
  ApplyMetallicShiftLayer (Bits(), Width, Height, Level, Shift)  
  If Mode = 2     
    ApplyGoldLayer (Bits(), Width, Height)
  EndIf
  
  Effect_OFF(img)  
EndProcedure

Procedure gadtip3()
  SetGadgetText(12,Str(GetGadgetState(3)))
EndProcedure

Procedure gadtip6()
  SetGadgetText(12,Str(GetGadgetState(6)))
EndProcedure

Procedure sizeCB()
  ResizeGadget(10,#PB_Ignore,#PB_Ignore,WindowWidth(0)-20,WindowHeight(0)-60)
  ResizeGadget(12,WindowWidth(0)/2-40,WindowHeight(0)-85,80,20)
  ResizeGadget(20,#PB_Ignore,#PB_Ignore,WindowWidth(0)-20,WindowHeight(0)-60)
  ResizeGadget(0,#PB_Ignore,#PB_Ignore,WindowWidth(0)-20,WindowHeight(0)-60)
  ResizeGadget(30,#PB_Ignore,WindowHeight(0)-40,#PB_Ignore,#PB_Ignore)  
  If IsGadget(6)
    ResizeGadget(3,325,WindowHeight(0)-35 ,230,24)
    ResizeGadget(6,560,WindowHeight(0)-35 ,230,24)
  Else
    ResizeGadget(3,325,WindowHeight(0)-35 ,230,24)
  EndIf
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 68
; Folding = AA-
; EnableXP
; DPIAware