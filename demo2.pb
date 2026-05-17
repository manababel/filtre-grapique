IncludeFile "filtres.pbi"
UseModule filtres

If OpenWindow(0, 0, 0, 1000, 600, "Exemple...", #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  
  source = 1
  cible = 2
  mix = 3
  
  file$ = OpenFileRequester("1e image : source","","",0)
  If load_image_32(source , file$) = 0
    End
  Else
    ResizeImage(source, 900, 700)
  EndIf
  
  file$ = OpenFileRequester("2e image : mix","","",0)
  If load_image_32(mix , file$) = 0
    End
  EndIf
    
  CopyImage(source,cible)
  
  Blend_additive(source , cible , mix , mask )
  
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
; CursorPosition = 23
; EnableXP
; DPIAware