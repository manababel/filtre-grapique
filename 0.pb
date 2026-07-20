IncludeFile "filtres.pbi"
UseModule filtres

If OpenWindow(0, 0, 0, 800, 600, "Exemple...", #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  
  SourceImage = 1
  CibleImage  = 2
  AucunMasque = 0

   
  file$ = OpenFileRequester("Image","","",0)
  If load_image_32(SourceImage , file$) = 0
    End
  Else
    ResizeImage(SourceImage, 800, 600)
  EndIf
  
  CopyImage(SourceImage,CibleImage)
  
  Clear_Data_Filter(FilterCtx)
  
  FilterCtx\option[0] = 7 ; RayonX 
  FilterCtx\option[1] = 7 ; Rayony
  FilterCtx\option[2] = 3 ; passe
  FilterCtx\option[3] = 1 ; bord
  
  Set_Source(SourceImage)
  ; ou Set_SourceEx(adresse_memoire_image , lg , ht) si vous connaisez l'adresse memoire de l'image
  ; ou 
  ; FilterCtx\image[0] = adresse memoire de l'image
  ; FilterCtx\image_lg[0] = longueur de l'image
  ; FilterCtx\image_ht[0] = hauteure de l'image
  Set_cible(CibleImage)
  ; ou Set_cible(SourceImage) si la cible est la source
  ; ou Set_CibleEx(adresse_memoire_image , lg , ht) si vous connaisez l'adresse memoire de l'image
  ; ou 
  ; FilterCtx\image[1] = adresse memoire de l'image
  ; FilterCtx\image_lg[1] = longueur de l'image
  ; FilterCtx\image_ht[1] = hauteure de l'image
  
  BoxBlurEx(FilterCtx)
  ; L'image cible peut être la même que l'image source :
  ; BoxBlur(SourceImage, SourceImage, AucunMasque, RayonX, RayonY, Passes, ModeBord)
  
  StartDrawing(WindowOutput(0))
  DrawImage(ImageID(CibleImage) ,  10 , 10)
  ; DrawImage(ImageID(SourceImage) ,  0 , 0)
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
; CursorPosition = 22
; FirstLine = 13
; EnableXP
; DPIAware
; Compiler = PureBasic 6.40 - C Backend (Windows - x64)