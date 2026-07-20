

IncludeFile "filtres.pbi"
UseModule filtres

If OpenWindow(0, 0, 0, 1000, 600, "Exemple...", #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  
  camera_device = 0
  
  If Camera_init() = #Null
    MessageRequester("Erreur" , "probleme avec la camera" , #PB_MessageRequester_Ok)
    End
  EndIf
  
  quit = 0
  source = 1
  cible = 2
  lg = 800
  ht = 600
  
  If CreateImage(cible , lg , ht , 32 ) ; image au format 32bits obligatoire

    Camera_on(camera_device , lg, ht)
    
    Repeat
      Event = WindowEvent()
      Select Event 
        Case #PB_Event_CloseWindow : quit = 1
      EndSelect
      
      CameraToImage(camera_device , cible)
      
      Prewitt(cible, cible, 0, 25 , 0 , 1 , 0 , 255)
      
      StartDrawing(WindowOutput(0))
      DrawImage(ImageID(cible) ,  1 , 1)
      StopDrawing()
      
      Delay(20)
    Until quit = 1
  EndIf
  deinitCapture(camera_device) 
EndIf


; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 38
; EnableThread
; EnableXP
; DPIAware
; DisableDebugger
; Compiler = PureBasic 6.40 - C Backend (Windows - x86)