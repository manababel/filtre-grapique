IncludeFile "filtres.pbi"
UseModule filtres

; test_filtres_refactorise.pb
; Version refactorisée du programme de filtres (PureBasic-like)
; Commentaires en français, fonctions séparées, corrections principales

; ---------------------- Constantes / IDs ----------------------
#IMG_SRC1 = 1
#IMG_SRC2 = 2
#IMG_MASK = 3
#IMG_CIBLE = 5
#IMG_BLACK = 6

#BTN_SAVE = 4
#MENU_LOAD_SRC1 = 1
#MENU_LOAD_SRC2 = 2
#MENU_LOAD_MASK = 3
#MENU_SAVE_BMP = 10
#MENU_SAVE_CLIP = 11
#MENU_QUIT = 12

#FILTRE_BASE_POS = 1000
#FILTRE_WINDOWS_POS = #FILTRE_BASE_POS + 1000

; ---------------------- Structures ----------------------
Structure FilterWindow
  id_window.i
  id_filter.i
  name.s
  opt.i[20]
EndStructure
Global NewList gFilterWindows.FilterWindow()

Structure FilterInfo
  id.l
  name.s
  typ.l
  subtype.l
EndStructure

; ---------------------- Globals ----------------------
Global image_selected = -1 ; 0,1,2 pour les miniatures
Global windows_counter = 1 ; compteur d'IDs de fenetres (toujours croissant)
Global lg, ht, scx.f, scy.f
Global px, py, tx, ty, pym
Global imagetx, imagety
Global elapsedText.s

; ---------------------- Helpers mémoire image ----------------------
Procedure SafeFreeImage(id)
  If IsImage(id)
    FreeImage(id)
  EndIf
EndProcedure

Procedure SafeCreateCopy(srcImage, dstImage)
  If IsImage(dstImage) : FreeImage(dstImage) : EndIf
  If IsImage(srcImage)
    CopyImage(srcImage, dstImage)
  EndIf
EndProcedure

; ---------------------- UI : thumbnails et preview ----------------------
Procedure DrawThumbnail(imgID, slot)
  If Not IsImage(imgID)
    StartDrawing(WindowOutput(0))
    ; dessine la case noire
    DrawImage(ImageID(#IMG_BLACK), px, py + (pym * slot + 10) * scy)
    StopDrawing()
    ProcedureReturn
  EndIf
  If IsImage(#IMG_BLACK) : ; on conserve #IMG_BLACK comme template
  EndIf
  ; crée une miniature temporaire, la dessine et la libère
  CopyImage(imgID, #IMG_CIBLE + 1) ; image temporaire
  ResizeImage(#IMG_CIBLE + 1, tx, ty)
  StartDrawing(WindowOutput(0))
  DrawImage(ImageID(#IMG_CIBLE + 1), px, py + (pym * slot + 10) * scy)
  StopDrawing()
  FreeImage(#IMG_CIBLE + 1)
EndProcedure

Procedure DrawSelectedOverlay()
  StartDrawing(WindowOutput(0))
  For i = 0 To 2
    x = px - 2
    y = (py + (pym * i + 10) * scy) - 2
    If i = image_selected : col = $ff00 : Else : col = $7f7f7f : EndIf
    Box(x, y, tx + 2, 2, col)
    Box(x, y, 2, ty + 2, col)
    Box(x + tx + 2, y, 2, ty + 2, col)
    Box(x, y + ty + 2, tx + 2, 2, col)
  Next

  ; dessine la grande preview si disponible
  If image_selected >= 0
    imgID = image_selected + #IMG_SRC1
    If IsImage(imgID)
      CopyImage(imgID, #IMG_CIBLE)
      ResizeImage(#IMG_CIBLE, imagetx * scx, imagety * scy, #PB_Image_Raw)
      DrawImage(ImageID(#IMG_CIBLE), (lg/10 + 5) * scx, py * scy)
      FreeImage(#IMG_CIBLE)
    EndIf
  EndIf
  StopDrawing()
EndProcedure

; ---------------------- Chargement / copie d'image ----------------------
Procedure LoadImageToSlot(slotImage)
  file$ = OpenFileRequester("Image", "", "", 0)
  If file$ = "" : ProcedureReturn : EndIf
  ; on suppose une fonction load_image_32() disponible (comme dans l'original)
  If load_image_32(slotImage, file$) = 1
    If slotImage = #IMG_SRC1
      ; si source1 change, redimensionne les autres si présents
      lgi = ImageWidth(#IMG_SRC1)
      hti = ImageHeight(#IMG_SRC1)
      If IsImage(#IMG_SRC2) : ResizeImage(#IMG_SRC2, lgi, hti) : EndIf
      If IsImage(#IMG_MASK)  : ResizeImage(#IMG_MASK, lgi, hti)  : EndIf
      ; recrée la cible principale selon taille
      If IsImage(#IMG_CIBLE) : FreeImage(#IMG_CIBLE) : EndIf
      CreateImage(#IMG_CIBLE, lgi, hti, 32)
    Else
      If IsImage(#IMG_SRC1)
        ResizeImage(slotImage, ImageWidth(#IMG_SRC1), ImageHeight(#IMG_SRC1))
      EndIf
    EndIf
    DrawThumbnail(slotImage, slotImage - 1)
  EndIf
EndProcedure

Procedure CopyImageFromTo(src, dst)
  ; copie mémoire directe en sécurité : on récupère les buffers si disponibles
  *srcbuf = 0
  *dstbuf = 0
  If IsImage(src) And StartDrawing(ImageOutput(src)) : *srcbuf = DrawingBuffer() : StopDrawing() : EndIf
  If IsImage(dst) And StartDrawing(ImageOutput(dst)) : *dstbuf = DrawingBuffer() : StopDrawing() : EndIf
  If *srcbuf <> 0 And *dstbuf <> 0
    lg0 = ImageWidth(src)
    ht0 = ImageHeight(src)
    CopyMemory(*dstbuf, *srcbuf, lg0 * ht0 * 4)
    DrawThumbnail(src, src - 1)
  EndIf
EndProcedure

; ---------------------- Menu dynamique de filtres ----------------------
; On suppose l'existence de tabfunc(i) et CallFunctionFast comme dans l'original
Procedure BuildFilterMenu()
  NewList tmp.FilterInfo()
  For i = 0 To 999
    If tabfunc(i) <> 0
      Clear_Data_Filter(param)
      param\info_active = 1
      CallFunctionFast(tabfunc(i), param)
      If param\typ <> 0
        AddElement(tmp())
        tmp()\id = i
        tmp()\name = param\name
        tmp()\typ = param\typ
        tmp()\subtype = param\subtype
      EndIf
      param\info_active = 0
    EndIf
  Next

  MenuTitle("Filtre")
  ForEach tmp()
    Select tmp()\typ
      Case #FilterType_Blur
        ; crée sous-menu Blur (on regroupe par type)
        ; simplification : on liste directement
        MenuItem(#FILTRE_BASE_POS + tmp()\id, Str(tmp()\id) + " " + tmp()\name)
      Default
        MenuItem(#FILTRE_BASE_POS + tmp()\id, Str(tmp()\id) + " " + tmp()\name)
    EndSelect
  Next

  FreeList(tmp())
EndProcedure

; ---------------------- Fenêtres d'options des filtres ----------------------
Procedure OpenFilterWindow(filterID)
  ; récupération des paramètres par défaut
  Clear_Data_Filter(param)
  param\info_active = 1
  CallFunctionFast(tabfunc(filterID), param)
  param\info_active = 0

  AddElement(gFilterWindows())
  gFilterWindows()\id_window = windows_counter
  gFilterWindows()\id_filter = filterID
  gFilterWindows()\name = "Window " + Str(windows_counter) + " - Filtre " + Str(filterID) + " : " + param\name
  ; stocke les options par défaut
  For i = 0 To 19
    gFilterWindows()\opt[i] = param\info_data(i, 2)
  Next

  ; ouvre la fenêtre
  OpenWindow(windows_counter, 0, 0, 500, 300, gFilterWindows()\name, #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  StickyWindow(windows_counter, #True)

  ; génère gadgets d'exemple (refaire selon param\info si besoin)
  ButtonGadget(#FILTRE_WINDOWS_POS + windows_counter * 10 + 7, 150, 250, 100, 25, "VALIDE")
  ButtonGadget(#FILTRE_WINDOWS_POS + windows_counter * 10 + 8, 270, 250, 100, 25, "QUITTER")

  windows_counter + 1
EndProcedure

Procedure CloseFilterWindow(winID)
  ; supprime la structure
  ForEach gFilterWindows()
    If gFilterWindows()\id_window = winID
      DeleteElement(gFilterWindows())
      Break
    EndIf
  Next
  CloseWindow(winID)
EndProcedure

Procedure UpdateFilterWindowEvent()
  id = GetActiveWindow()
  If id < 1 : ProcedureReturn 0 : EndIf
  ev = EventGadget()
  If ev = 0 : ProcedureReturn 0 : EndIf

  ; si clique sur valide / quitter
  np1 = ev - #FILTRE_WINDOWS_POS
  If np1 = 7 : CloseFilterWindow(id) : CopyImageFromTo(image_selected + #IMG_SRC1, #IMG_SRC1) : ProcedureReturn 1 : EndIf
  If np1 = 8 : CloseFilterWindow(id) : ProcedureReturn 1 : EndIf

  ProcedureReturn 0
EndProcedure

; ---------------------- Application des filtres ----------------------
Procedure ApplyFiltersIfNeeded(updateFlag)
  If updateFlag = 0 : ProcedureReturn : EndIf
  If Not IsImage(#IMG_SRC1) : ProcedureReturn : EndIf

  ; prépare buffers
  *srcBuf = 0 : *src2Buf = 0 : *maskBuf = 0 : *destBuf = 0
  If IsImage(#IMG_SRC1) And StartDrawing(ImageOutput(#IMG_SRC1)) : *srcBuf = DrawingBuffer() : StopDrawing() : EndIf
  If IsImage(#IMG_SRC2) And StartDrawing(ImageOutput(#IMG_SRC2)) : *src2Buf = DrawingBuffer() : StopDrawing() : EndIf
  If IsImage(#IMG_MASK) And StartDrawing(ImageOutput(#IMG_MASK))   : *maskBuf = DrawingBuffer() : StopDrawing() : EndIf
  If IsImage(#IMG_CIBLE) And StartDrawing(ImageOutput(#IMG_CIBLE)) : *destBuf = DrawingBuffer() : StopDrawing() : EndIf

  ; tempo = image sélectionnée (src1/src2/mask)
  If image_selected = 0 And *srcBuf : CopyImage(#IMG_SRC1, #IMG_CIBLE + 2) : EndIf
  If image_selected = 1 And *src2Buf: CopyImage(#IMG_SRC2, #IMG_CIBLE + 2) : EndIf
  If image_selected = 2 And *maskBuf: CopyImage(#IMG_MASK, #IMG_CIBLE + 2) : EndIf

  If IsImage(#IMG_CIBLE + 2)
    StartDrawing(ImageOutput(#IMG_CIBLE + 2)) : *tempo = DrawingBuffer() : StopDrawing()
  EndIf

  ; itère sur les fenêtres de filtres et appelle les fonctions
  t = ElapsedMilliseconds()
  ForEach gFilterWindows()
    ; reconstruction de param depuis gFilterWindows()\opt
    For i = 0 To 19 : param\option[i] = gFilterWindows()\opt[i] : Next
    param\source = *tempo
    param\source2 = *src2Buf
    param\mask = *maskBuf
    param\lg = ImageWidth(#IMG_SRC1)
    param\ht = ImageHeight(#IMG_SRC1)
    CallFunctionFast(tabfunc(gFilterWindows()\id_filter), param)
    ; after call, param\cible contient le résultat (selon convention)
    param\source = param\cible
  Next
  t = ElapsedMilliseconds() - t
  elapsedText = " temps = " + Str(t) + " ms"

  ; affiche la cible dans la fenêtre principale
  StartDrawing(WindowOutput(0))
  If IsImage(#IMG_CIBLE)
    CopyImage(#IMG_CIBLE, #IMG_CIBLE + 3)
    ResizeImage(#IMG_CIBLE + 3, imagetx * scx, imagety * scy, #PB_Image_Raw)
    DrawImage(ImageID(#IMG_CIBLE + 3), (lg/10 + 5) * scx, py * scy)
    FreeImage(#IMG_CIBLE + 3)
  EndIf
  SetWindowTitle(0, "test_filtres" + elapsedText)
  StopDrawing()

  ; nettoyage temporaire
  If IsImage(#IMG_CIBLE + 2) : FreeImage(#IMG_CIBLE + 2) : EndIf
EndProcedure

; ---------------------- Initialisation UI ----------------------
Procedure InitUI()
  lg = 1600 : ht = 900
  lg = lg * 100 / DesktopUnscaledX(100)
  ht = ht * 100 / DesktopUnscaledY(100)
  scx = (100 / DesktopUnscaledX(100))
  scy = (100 / DesktopUnscaledY(100))

  px = 5
  py = 5
  tx = lg / 10.526
  ty = ht / 6.105
  pym = ht / 5.6
  imagetx = (lg - lg/20) - (20 + lg/20)
  imagety = ht - 40

  If OpenWindow(0, 0, 0, lg, ht, "test_filtres_refactorise", #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget)

    CreateMenu(0, WindowID(0))
    MenuTitle("File")
    OpenSubMenu("Load")
    MenuItem(#MENU_LOAD_SRC1, "Load Image 1")
    MenuItem(#MENU_LOAD_SRC2, "Load Image 2")
    MenuItem(#MENU_LOAD_MASK, "Load mask")
    CloseSubMenu()
    OpenSubMenu("Save")
    MenuItem(#MENU_SAVE_BMP, "Save BMP")
    MenuItem(#MENU_SAVE_CLIP, "Save Clipboard")
    CloseSubMenu()
    MenuBar()
    MenuItem(#MENU_QUIT, "Quit")

    BuildFilterMenu()

    FrameGadget(100, lg/10 + 5, py, imagetx, imagety, "")
    FrameGadget(101, px, py + pym * 3, tx, ht - (py + pym * 3.2), "")

    CreateImage(#IMG_BLACK, tx * scx, ty * scy)
    StartDrawing(ImageOutput(#IMG_BLACK))
    Box(0, 0, tx * scx, ty * scy, 0)
    StopDrawing()

    DrawThumbnail(#IMG_BLACK, 0)
    DrawThumbnail(#IMG_BLACK, 1)
    DrawThumbnail(#IMG_BLACK, 2)
  EndIf
EndProcedure

; ---------------------- Boucle principale ----------------------
InitUI()

quit = 0
updateNeeded = 0

Repeat
  Event = WaitWindowEvent()

  Select Event
    Case #PB_EventType_LeftClick
      x = WindowMouseX(0)
      y = WindowMouseY(0)
      x1 = px
      x2 = x1 + (tx * scx)
      If x >= x1 And x <= x2
        For i = 0 To 2
          y1 = py + (pym * i + 10) * scy
          y2 = y1 + (ty * scy)
          If y >= y1 And y <= y2
            image_selected = i
            DrawSelectedOverlay()
            updateNeeded = 1
          EndIf
        Next
      EndIf

    Case #PB_Event_Menu
      var = EventMenu()
      Select var
        Case #MENU_LOAD_SRC1 : LoadImageToSlot(#IMG_SRC1) : updateNeeded = 1
        Case #MENU_LOAD_SRC2 : If IsImage(#IMG_SRC1) : LoadImageToSlot(#IMG_SRC2) : EndIf : updateNeeded = 1
        Case #MENU_LOAD_MASK : If IsImage(#IMG_SRC1) : LoadImageToSlot(#IMG_MASK) : EndIf : updateNeeded = 1
        Case #MENU_SAVE_BMP : nom$ = SaveFileRequester("Save BMP", "", "", 0) : If nom$ <> "" : SaveImage(#IMG_SRC1, nom$ + ".bmp", #PB_ImagePlugin_BMP) : EndIf
        Case #MENU_SAVE_CLIP: If IsImage(#IMG_SRC1) : SetClipboardImage(#IMG_SRC1) : EndIf
        Case #MENU_QUIT : quit = 1
        Case #FILTRE_BASE_POS To (#FILTRE_BASE_POS + 999)
          pos = var - #FILTRE_BASE_POS
          OpenFilterWindow(pos)
          updateNeeded = 1
      EndSelect

    Case #PB_Event_CloseWindow
      If EventWindow() = 0
        quit = 1
      Else
        CloseFilterWindow(EventWindow())
      EndIf
  EndSelect

  ; mise à jour des fenêtres de filtres
  updateNeeded + UpdateFilterWindowEvent()

  ; application des filtres si besoin
  If updateNeeded And ListSize(gFilterWindows()) > 0
    ApplyFiltersIfNeeded(updateNeeded)
    updateNeeded = 0
  EndIf

Until quit = 1

; nettoyage final
If IsImage(#IMG_CIBLE) : FreeImage(#IMG_CIBLE) : EndIf
If IsImage(#IMG_BLACK) : FreeImage(#IMG_BLACK) : EndIf
CloseWindow(0)

; Fin du fichier

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 209
; FirstLine = 209
; Folding = ---
; EnableXP
; DPIAware