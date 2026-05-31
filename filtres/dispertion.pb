UseJPEGImageDecoder() 
UseJPEG2000ImageDecoder() 
UsePNGImageDecoder() 
UseTGAImageDecoder() 
UseTIFFImageDecoder() 
UseGIFImageDecoder() 

; charge une image et la convertie en 32bit 
;------------------------------------------------------------------- 
Procedure load_image(nom,file$) 
  Protected nom_p.i , temps_p.i , x.l , y.l , r.l,g.l,b.l , i.l 
  Protected lg.l , ht.l , depth.l , temps.i  , dif.l , dif1.l 
  
  LoadImage(nom,file$) 
  If Not IsImage(nom) : ProcedureReturn 0 : EndIf 
  
  StartDrawing(ImageOutput(nom)) 
  Depth=OutputDepth() 
  StopDrawing() 
  
  If Depth=24 
    CopyImage(nom,temps) 
    FreeImage(nom) 
    StartDrawing(ImageOutput(temps)) 
    temps_p = DrawingBuffer() 
    lg = ImageWidth(temps) 
    ht = ImageHeight(temps) 
    dif = DrawingBufferPitch() - (lg*3) 
    StopDrawing() 
    
    
    CreateImage(nom,lg,ht,32) 
    StartDrawing(ImageOutput(nom)) 
    nom_p = DrawingBuffer() 
    StopDrawing() 
    
    For y=0 To ht-1 
      For x=0 To lg-1 
        i = ((y*lg)+x)*3 
        r=PeekA(temps_p + i + 2 + dif1) 
        g=PeekA(temps_p + i + 1 + dif1) 
        b=PeekA(temps_p + i + 0 + dif1) 
        PokeL(nom_p + ((y*lg)+x)*4 , r<<16 + g<<8 + b) 
      Next 
      dif1 = dif1 + dif 
    Next 
    
    FreeImage(temps) ; supprime l'image 24bits 
    
  EndIf 
  
  ProcedureReturn 1 
EndProcedure 
;------------------------------------------------------------------ 

Procedure udate(source.i , mappe.i , cible.i , scale.f , opt=0) 
  
  StartDrawing(ImageOutput(source)) 
  source_p = DrawingBuffer() 
  ht1 = ImageHeight(source) 
  lg1 = ImageWidth(source) 
  StopDrawing() 
  
  StartDrawing(ImageOutput(mappe)) 
  mappe_p = DrawingBuffer() 
  ht2 = ImageHeight(mappe) 
  lg2 = ImageWidth(mappe) 
  StopDrawing() 
  scalex.f = Abs(lg2/lg1) 
  scaley.f = Abs(ht2/ht1) 
  
  StartDrawing(ImageOutput(cible)) 
  cible_p = DrawingBuffer() 
  StopDrawing() 
  
  
  For y=0 To ht1-1 
    For x=0 To lg1-1 
      
      If opt = 0 
        x1 = Mod(x,(lg2-1)) 
        y1 = Mod(y,(ht2-1)) 
      Else 
        x1 = x * scalex 
        y1 = y * scaley 
        If x1>=lg2 : x1=lg2-1 : EndIf 
        If y1>=ht2 : y1=ht2-1 : EndIf 
      EndIf 
      
      pos2 = mappe_p + (((y1*lg2)+x1) << 2) 
      v1 = PeekA(pos2 + 1) 
      v2 = PeekA(pos2 + 2) 
      
      dx.f = (scale * ( v1 - 127) ) 
      dy.f = (scale * ( v2 - 127) ) 
      
      x1 = (x + dx) 
      y1 = (y + dy) 
      If x1<0 : x1 = 0 : EndIf 
      If y1<0 : y1 = 0 : EndIf 
      If x1>=lg1 : x1 =  lg1-1 : EndIf 
      If y1>=ht1 : y1 =  ht1-1 : EndIf 
      
      pos1 = (((y1*lg1)+x1) << 2) 
      pos3 = (((y*lg1)+x) << 2) 
      rgb = PeekL( source_p + pos1) 
      PokeL( cible_p + pos3 , rgb ) 
      
    Next 
  Next 
  
EndProcedure 


quit=0 
windoww=1024
windowh=768
If OpenWindow(0, 0, 0, 1024, 768, "Exemple...", #PB_Window_SystemMenu | #PB_Window_ScreenCentered) 
  
  CreateMenu(0, WindowID(0)) 
  MenuTitle("Load") 
  MenuItem( 1, "Load Image") 
  MenuItem( 6, "Load map") 
  MenuTitle("Save")    
  MenuItem( 2, "Save BMP") 
  ;MenuItem( 3, "Save JPG") 
  MenuItem( 4, "Save Clipboard") 
  MenuTitle("option") 
  ; 		MenuItem( 7, "none") 
  MenuItem( 8, "scale") 
  MenuTitle("Quit") 
  MenuItem( 5, "Quit") 
  
  TrackBarGadget(10, 10, 0, 512, 20, 0, 128 ) 
  ScrollAreaGadget(11,0,MenuHeight()+GadgetHeight(10)+0,
                   1020,windowh-MenuHeight()-GadgetHeight(10)-50,32000,32000)
  CanvasGadget(12,0,0,windoww,windoww)
  CloseGadgetList()
  ; 			SetWindowState(0,#PB_Window_Maximize)
  ;------------------------------------------------------------ 
  ;------------------------------------------------------------  
  
  source = 1 
  mappe = 2 
  cible = 3 
  
  Repeat    
    
    Event = WaitWindowEvent() 
    
    Select Event 
        
      Case #PB_Event_Gadget 
        Select EventGadget() 
          Case 10 
            var = GetGadgetState(10) 
            scale.f= (var / 100.0) 
            If IsImage(1) And IsImage(2) And  IsImage(3) 
              udate(source,mappe,cible,scale,opt) 
              StartDrawing(CanvasOutput(12))
              If IsImage(cible) 
                
                DrawImage(ImageID(cible),0,0) 
                
              EndIf 
              StopDrawing() 
            EndIf 
            
            
        EndSelect 
        
      Case #PB_Event_Menu 
        
        Select EventMenu() 
          Case 1 
            If IsImage(source) : FreeImage(source) : EndIf 
            If IsImage(mappe) : FreeImage(mappe) : EndIf 
          file$ = OpenFileRequester("Image","","",0) 
           
            If file$
              If Not Load_Image(1,file$) 
                MessageRequester("load_image","erreur de chargement",#PB_MessageRequester_Ok | #PB_MessageRequester_Error) 
              EndIf 
              CopyImage(source,cible)
              iw=ImageWidth(cible)
              ih=ImageHeight(cible)
              If iw>GadgetWidth(11)
                x=0
              Else
                x=(GadgetWidth(11)-iw)/2
                
              EndIf
              If ih>GadgetHeight(11)
                y=0
              Else
                
                y=(GadgetHeight(11)-ih)/2
              EndIf
              ResizeGadget(12,x,y,iw,ih)
              StartDrawing(CanvasOutput(12))
              If IsImage(cible) 
                
                DrawImage(ImageID(cible),0,0) 
                
              EndIf 
              StopDrawing() 
              
            EndIf
            
          Case 6 
            If Not IsImage(source) 
              MessageRequester("load_image","vous devez charger une image avant",#PB_MessageRequester_Ok | #PB_MessageRequester_Error) 
            Else 
              
              If IsImage(mappe) : FreeImage(mappe) : EndIf 
              file$ = OpenFileRequester("Image","","",0) 
              
              If file$
                If Not Load_Image(mappe,file$) 
                  MessageRequester("load_image","erreur de chargement",#PB_MessageRequester_Ok | #PB_MessageRequester_Error) 
                EndIf 
              EndIf
            EndIf 
            
          Case 2 
            nom$ = SaveFileRequester("Save BMP", "", "", 0) 
            If nom$ <> "" : SaveImage(cible, nom$+".bmp" ,#PB_ImagePlugin_BMP ) : EndIf 
            
            
          Case 5 
            quit = 1 
            
            ; 							Case 7 
            ; 								opt = 0 
            ; 								If IsImage(1) And IsImage(2) And  IsImage(3) 
            ; 									udate(source,mappe,cible,scale,opt) 
            ; 								EndIf 
            
          Case 8 
            If GetMenuItemState(0,8)
              SetMenuItemState(0,8,#False)
              opt = 0 
              
            Else
              
              SetMenuItemState(0,8,#True)
              opt = 1
            EndIf
            
            If IsImage(1) And IsImage(2) And  IsImage(3) 
              udate(source,mappe,cible,scale,opt) 
            EndIf 
            
        EndSelect 
        
    EndSelect 
    
    
    
    
    
  Until Event = #PB_Event_CloseWindow Or quit=1 
EndIf 
End
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 137
; Folding = -
; EnableXP
; DPIAware