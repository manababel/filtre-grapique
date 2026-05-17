IncludeFile "filtres.pbi"
UseModule filtres

If OpenWindow(0, 0, 0, 1000, 600, "Exemple...", #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  
  source = 1
  cible = 2
  
  file$ = OpenFileRequester("1e image : source","","",0)
  If load_image_32(source , file$) = 0
    End
  Else
    ResizeImage(source, 900, 700)
  EndIf
    
  CopyImage(source,cible)
  
  convolution3x3(source , cible , 0 , 19)
  
  StartDrawing(WindowOutput(0))
  DrawImage(ImageID(cible) ,  10 , 10)
  StopDrawing()
  
  Repeat
    Event = WaitWindowEvent()
    Select Event 
      Case #PB_Event_Gadget
        Select EventGadget()
          Case 1 
            CloseWindow(0)
            End  
        EndSelect
    EndSelect

  Until Event = #PB_Event_CloseWindow
EndIf
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 17
; EnableThread
; EnableXP
; DPIAware