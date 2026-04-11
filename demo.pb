

IncludeFile "filtres.pbi"
UseModule filtres


; ---------------------- Constantes / IDs ----------------------


#Menu_load_Source = 1
#Menu_load_Mix = 2
#Menu_load_Mask = 3
;#Menu_load_Mask2 = 4

#save = 4
#save2 = 5
#quit = 6
#mask_e = 7
#mask_d = 8
#mask_n = 9
#copy1 = 10
#copy2 = 11
#copy3 = 12

Enumeration images
  #img_source = 1
  #img_mix
  #img_mask
  #img_cible
  #img_tempo_source
  #img_tempo_cible
  #img_aff
  
  #img_miniature_source ; copie de la copie pour eviter la degradation de la miniature apres un scale screen
  #img_miniature_mix
  #img_miniature_mask
  #img_miniature_Black
  
  #img_miniature_source_copy ; copie de l'original
  #img_miniature_mix_copy
  #img_miniature_mask_copy
EndEnumeration


#filtre_pos = 1000
#filtre_windows_pos = #filtre_pos + 1000


Global image_selected = -1


Structure filtre
  id.i
  name.s
  remarque.s
  ht.i
  close.i
  Array typ.i(20)
  Array info.s(20)
  Array opt.f(20,9)
EndStructure
Global NewList list_filtre.filtre()
Global NewList list_filtre_selected.filtre()


; global pour la fenetre principale
Global Window_SizeX.l
Global Window_SizeY.l

; global pour les miniatures
Global Miniature_taille
Global Miniature_px
Global Miniature_py
Global Miniature_decal

; global pour l'image tempo
Global tempo_px
Global tempo_py
Global tempo_tx
Global tempo_ty

Global lg , ht
Global tx , ty
Global scx.f , scy.f
Global px , py
Global imagetx , imagety
Global pym
Global lgi ,hti

Global windows_id

Global valider_loop = 0

Global filtre_special_fire = 0
;----------


Procedure draw_miniature(image , pos)
  If Not IsImage(image) : ProcedureReturn : EndIf
  Select pos
    Case 0 : t$ = "source"
    Case 1 : t$ = "mix"
    Case 2 : t$ = "mask"
  EndSelect
  
  px = Miniature_px
  py = Miniature_decal  + (Miniature_py + Miniature_taille) * pos
  
  StartDrawing(CanvasOutput(0))
  DrawText(px , py - Miniature_decal , t$)
  DrawImage(ImageID(image) , px , py)
  StopDrawing()
EndProcedure

Procedure draw_miniature_selected(pos)
  StartDrawing(CanvasOutput(0))
  
  px = Miniature_px
  For i = 0 To 2
    If  (i + 1 ) = image_selected : col = $ff00 : Else : col = $7f7f7f : EndIf
    py = Miniature_decal  + (Miniature_py + Miniature_taille) * i
    Box(px - 2 , py - 2 , Miniature_taille + 4 , Miniature_taille + 4 , col)
    If IsImage(i + #img_miniature_source) <> 0
      DrawImage(ImageID(i + #img_miniature_source) , px , py)
    Else
      DrawImage(ImageID(#img_miniature_Black) , px , py)
    EndIf  
  Next
  
  StopDrawing()
EndProcedure

Procedure test_miniature()
  x = WindowMouseX(0)
  y = WindowMouseY(0)
  x1 = Miniature_px
  x2 = Miniature_px + Miniature_taille
  If x >= x1 And x <= x2
    For i = 0 To 2
      y1 = Miniature_decal  + (Miniature_py + Miniature_taille) * i
      y2 = y1 + Miniature_taille
      If y >= y1 And y <= y2
        ProcedureReturn (i + 1)
        ;image_selected = i
        ;draw_miniature_selected(i)
      EndIf
    Next
  EndIf
  ProcedureReturn 0
EndProcedure

;----------

Procedure load_image_sp(var1 , var2 , pos)
  If IsImage(var2) <> 0 : FreeImage(var2) : EndIf
  CopyImage(var1 , var2)
  ResizeImage(var2 , Miniature_taille , Miniature_taille)
  draw_miniature(var2 , pos)
EndProcedure

Procedure load_img(var)
  file$ = OpenFileRequester("Image","","",0)
  If load_image_32(var,file$) = 1
    Select var
      Case #img_source : load_image_sp(#img_source , #img_miniature_source , 0) : CopyImage(#img_miniature_source , #img_miniature_source_copy)
      Case #img_mix    : load_image_sp(#img_mix    , #img_miniature_mix    , 1) : CopyImage(#img_miniature_mix    , #img_miniature_mix_copy)
      Case #img_mask   : load_image_sp(#img_mask   , #img_miniature_mask   , 2) : CopyImage(#img_miniature_mask , #img_miniature_mask_copy)
    EndSelect
  EndIf
EndProcedure

Procedure copy_image(var)
  
EndProcedure

;----------


Structure FilterInfo
  id.l
  name.s
  typ.l
  subtype.l
EndStructure
Global Dim typ(99)


; ===============================
; Ajoute un type de filtre + sous-types avec second niveau
; ===============================
Macro create_menu_filtre_add_sp2_star()
  currentSubMenu = -1
  ForEach filterList()
    If filterList()\typ = var
      
      ; Si le sous-type change, gérer les sous-menus
      If filterList()\subtype <> currentSubMenu
        ; Fermer le sous-menu précédent si nécessaire
        If currentSubMenu <> -1
          CloseSubMenu()
        EndIf
        
        ; Ouvrir le nouveau sous-menu selon le subtype
        currentSubMenu = filterList()\subtype
EndMacro
      
Macro create_menu_filtre_add_sp2_stop()
  EndIf
        ; Ajouter le filtre dans le sous-menu
        MenuItem(#filtre_pos + filterList()\id, Str(filterList()\id) + " " + filterList()\name)
      EndIf
    Next
    
    ; Fermer le dernier sous-menu 
    If currentSubMenu <> -1
      CloseSubMenu()
    EndIf
EndMacro
  
Procedure create_menu_filtre_add_sp2(List filterList.FilterInfo(), var, name$, test)
  Protected currentSubMenu
  If typ(test) = 0
    typ(test) = 1
    If test <> 1 : CloseSubMenu() : EndIf
    
    ; --- Sous-menu principal pour le type ---
    OpenSubMenu(name$)
    
    ; Cas spécial pour Blur : créer un second niveau de sous-menus
    ;If var = #FilterType_Blur
    Select var
      Case #FilterType_Blur
        create_menu_filtre_add_sp2_star()
        Select filterList()\subtype
          Case #Blur_Classic
            OpenSubMenu("Classic")
          Case #Blur_Directional
            OpenSubMenu("Directional")
          Case #Blur_Gaussian
            OpenSubMenu("Gaussian")
          Case #Blur_EdgeAware
            OpenSubMenu("Edge Aware")
          Case #Blur_Adaptive
            OpenSubMenu("Adaptive")
          Case #Blur_Stochastic
            OpenSubMenu("Stochastic")
          Case #Blur_Optical
            OpenSubMenu("Optical")
          Case #Blur_MultiScale
            OpenSubMenu("Multi-Scale")
          Case #Blur_Morphological
            OpenSubMenu("Morphological")
          Case #Blur_Artistic
            OpenSubMenu("Artistic")
          Case #Blur_Specialized
            OpenSubMenu("Specialized")
          Case #Blur_Advanced
            OpenSubMenu("Advanced")
          Default
            OpenSubMenu("Other")
        EndSelect
        ;EndIf
        create_menu_filtre_add_sp2_stop()
        
      Case #FilterType_EdgeDetection
        create_menu_filtre_add_sp2_star()
        Select filterList()\subtype
          Case #EdgeDetect_Gradient
            OpenSubMenu("Gradient")
          Case #EdgeDetect_Laplacian
            OpenSubMenu("Laplacian")
          Case #EdgeDetect_Advanced
            OpenSubMenu("Advanced")
          Case #EdgeDetect_Morphological
            OpenSubMenu("Morphological")
          Case #EdgeDetect_MultiScale
            OpenSubMenu("MultiScale")
          Case #EdgeDetect_Specialized
            OpenSubMenu("Specialized")
          Default
            OpenSubMenu("Other")
        EndSelect
        ;EndIf
        create_menu_filtre_add_sp2_stop()
        
      Case #FilterType_Dithering
        create_menu_filtre_add_sp2_star()
        Select filterList()\subtype
          Case #Dither_ErrorDiffusion
            OpenSubMenu("ErrorDiffusion")
          Case #Dither_Ordered
            OpenSubMenu("Ordered")
          Case #Dither_Random
            OpenSubMenu("Random")
          Case #Dither_Stochastic
            OpenSubMenu("stochastique")
          Case #Dither_Adaptive
            OpenSubMenu("Adaptive")
          Case #Dither_Hybrid
            OpenSubMenu("Hybride")
          Case #Dither_Fast
            OpenSubMenu("Rapide")
          Default
            OpenSubMenu("Other")
        EndSelect
        ;EndIf
        create_menu_filtre_add_sp2_stop()
        
      Case #FilterType_BlendModes
        create_menu_filtre_add_sp2_star()
        Select filterList()\subtype
          Case #Blend_Additive
            OpenSubMenu("Additive")
          Case #Blend_Subtractive
            OpenSubMenu("Subtractive")
          Case #Blend_Multiply
            OpenSubMenu("Multiply")
          Case #Blend_Contrast
            OpenSubMenu("Contrast")
          Case #Blend_Soft
            OpenSubMenu("Soft")
          Case #Blend_Hard
            OpenSubMenu("Hard")
          Default
            OpenSubMenu("Other")
        EndSelect
        ;EndIf
        create_menu_filtre_add_sp2_stop()
        
      Case #FilterType_Artistic
        create_menu_filtre_add_sp2_star()
        Select filterList()\subtype
          Case #Artistic_Light
            OpenSubMenu("Light")
          Case #Artistic_Material
            OpenSubMenu("Material")
          Case #Artistic_Other
            OpenSubMenu("Other")
          Default
            OpenSubMenu("inconnu")
        EndSelect
        ;EndIf
        create_menu_filtre_add_sp2_stop()
        
        
      Default
        ; Comportement standard pour les autres types (avec séparateurs)
        Protected lastSubtype = -1
        
        ForEach filterList()
          If filterList()\typ = var
            ; Si le sous-type change → insérer un séparateur
            If lastSubtype <> -1 And filterList()\subtype <> lastSubtype
              MenuBar()
            EndIf
            ; Ajouter le filtre dans le menu
            MenuItem(#filtre_pos + filterList()\id, Str(filterList()\id) + " " + filterList()\name)
            lastSubtype = filterList()\subtype
          EndIf
        Next
    EndSelect
  EndIf
EndProcedure

; ===============================
; Crée la hiérarchie
; ===============================
Procedure create_menu_filtre()
  
  param\info_active = 1
  ; Liste temporaire pour tous les filtres
  NewList filterList.FilterInfo()
  
  ; Collecte de tous les filtres (y compris ID 0)
  For i = 0 To 999
    ; CORRECTION : Vérifier si la fonction existe ET est valide
    If tabfunc(i) <> 0
      ; Réinitialiser les champs avant l'appel
      param\name = ""
      param\typ = 0
      param\subtype = 0
      
      CallFunctionFast(tabfunc(i), param)
      
      ; CORRECTION : Vérifier si le filtre a retourné des infos valides
      ; Un filtre valide doit avoir au minimum un nom
      If param\name <> ""
        AddElement(filterList())
        filterList()\id      = i
        filterList()\name    = param\name
        filterList()\typ     = param\typ
        filterList()\subtype = param\subtype
        Debug param\name
      EndIf
    EndIf
  Next
  
  ; Debug : Afficher la liste pour vérifier
  Debug "=== Liste des filtres collectés ==="
  ForEach filterList()
    Debug "ID: " + Str(filterList()\id) + " | Name: " + filterList()\name + " | Type: " + Str(filterList()\typ)
  Next
  Debug "=== Fin de la liste ==="
  
  ;SortStructuredList(filterList() , #PB_Sort_Ascending , OffsetOf(FilterInfo\id) , #PB_Long)
  
  MenuTitle("Filtre")
  ; Création du menu
  ForEach filterList()
    PushListPosition(filterList())
    Select filterList()\typ
      Case #FilterType_Blur
        create_menu_filtre_add_sp2(filterList() , #FilterType_Blur , "Blur" , 1)
      Case #FilterType_EdgeDetection
        create_menu_filtre_add_sp2(filterList() , #FilterType_EdgeDetection , "Edge Detection" , 2)
      Case #FilterType_ColorAdjustment
        create_menu_filtre_add_sp2(filterList() , #FilterType_ColorAdjustment , "Color Adjustment" , 3)
      Case #FilterType_ColorEffect
        create_menu_filtre_add_sp2(filterList() , #FilterType_ColorEffect , "Color Effect" , 4)
      Case #FilterType_Dithering
        create_menu_filtre_add_sp2(filterList() , #FilterType_Dithering , "Dithering" , 5)
      Case #FilterType_Artistic
        create_menu_filtre_add_sp2(filterList() , #FilterType_Artistic , "Artistic" , 6)
      Case #FilterType_TexturePattern
        create_menu_filtre_add_sp2(filterList() , #FilterType_TexturePattern , "Texture Pattern" , 7)
      Case #FilterType_Deformation
        create_menu_filtre_add_sp2(filterList() , #FilterType_Deformation , "Deformation" , 8)
      Case #FilterType_ColorSpace
        create_menu_filtre_add_sp2(filterList() , #FilterType_ColorSpace , "Color Space" , 9)
      Case #FilterType_BlendModes
        create_menu_filtre_add_sp2(filterList() , #FilterType_BlendModes , "Blend Modes" , 10)
      Case #FilterType_Texture
        create_menu_filtre_add_sp2(filterList() , #FilterType_Texture , "Texture" , 11)
      Default
        create_menu_filtre_add_sp2(filterList() , filterList()\typ , "Autres" , 12) 
    EndSelect
    
    PopListPosition(filterList())
  Next
  CloseSubMenu()
  param\info_active = 0
  
EndProcedure

;----------
Procedure draw_bouton(px , py , lg , ht , mx , my , clic ,  t$ = "" , c1 = $ffffff , opt = 0)
  c2 = $77 - 40
  c3 = $77 + 40
  If opt <> 0 : Swap c2 , c3 : EndIf
  Box(px + 0, py + 0, lg - 0, ht - 0, RGB(c3, c3, c3))   ; haut
  Box(px + 2, py + 2, lg - 2, ht - 2, RGB(c2, c2, c2))   ; bas
  Box(px + 2, py + 2, lg - 4, ht - 4, $777777)           ; fond de la barre
  lg_text = TextWidth(t$)
  
  If mx > px And mx < (px + lg) And my > py And my < (py + ht)
    DrawText(px + (lg - lg_text) * 0.5 , py , t$ , $af)
    If clic = 1 : var = 1 : EndIf
  Else
    If opt : c1 = $dfdfdf : EndIf
    DrawText(px + (lg - lg_text) * 0.5 , py , t$ , c1)
    var = 0
  EndIf
  ProcedureReturn var
EndProcedure

Procedure bouton_filtre_validation(px , py , ht , mx , my , clic , t$ , opt = 0)
  lg  = TextWidth(t$) + 4
  over = 0
  c = $ffffff
  If  (mx >= (px - 2)) And (mx <= (px - 2 + lg)) And (my >= py - 2) And (my <= (py - 2 + ht - 4)) : over = 1  : c = $777777 : EndIf
  draw_bouton(px - 2, py - 2 , lg + 2 , ht - 6 , mx , my , clic , t$ , $ffffff , opt)
  ;DrawText(px , py , t$ , c , $777777 ); $ffffff , c)
  ProcedureReturn ( over & clic )
EndProcedure

Procedure bouton_filtre_up_down(px , py , lg , ht , mx, my , clic , t$)
  col = $ffffff
  over = 0
  If  (mx >= px) And (mx <= (px + lg)) And (my >= py) And (my <= (py + ht)) : over = 1  : col = $ff : EndIf
  
  draw_bouton(px , py , lg , ht , 0 , 0 , clic)
  ;Box(px, py, lg, ht, col)
  DrawText(px + 4, py, t$, col)
  
  If clic And over = 1
    ProcedureReturn 1
  EndIf
  ProcedureReturn 0
EndProcedure

Procedure bouton_quit(px , py , tx , ty , mx , my)
  col = $ffffff
  List_filtre_selected()\close = 0
  If mx >= px And my >= py And mx <= (px + tx) And my <= (py + ty)
    col = $ff
    List_filtre_selected()\close = 1
  EndIf
  ;Box(px , py , tx , ty , $777777)
  draw_bouton(px , py , tx , ty , 0 , 0 , clic)
  DrawText(px + 2 , py , "X" , col)
EndProcedure

Procedure.f bouton_TrackBar(x.f, y.f, w.f, h.f, vmin.f, vmax.f, var.f, mx.f, my.f, clic)
  
  Protected knobX.f, over = #False, col
  Protected nv.f = (mx - x) / w
  vard = vmin + nv * (vmax - vmin)
  
  ; --- Détection de la souris sur la zone du slider ---
  If mx >= x And mx <= x + w And my >= y - 1 And my <= y + h + 1
    over = #True
  EndIf
  
  ; --- Gestion du clic / drag ---
  If clic And over
    track_drag = #True
    track_id_drag = id
  EndIf
  
  If mouseUp
    track_drag = #False
    track_id_drag = -1
  EndIf
  
  
  If track_drag And track_id_drag = id
    If nv < 0 : nv = 0 : EndIf
    If nv > 1 : nv = 1 : EndIf
    var = vmin + nv * (vmax - vmin)
  EndIf
  
  
  ; --- Dessin du slider ---
  draw_bouton(x , y , w , h  , 0 , 0 , clic)
  ;Box(x + 0, y + 0, w - 0, h - 0, RGB(99, 99, 99))   ; haut
  ;Box(x + 2, y + 2, w - 2, h - 2, RGB(60, 60, 60))   ; bas
  ;Box(x + 2, y + 2, w - 4, h - 4, RGB(80, 80, 80))   ; fond de la barre
  
  ; Position du curseur
  knobX = x + ((var - vmin) / (vmax - vmin)) * w
  col = RGB(255, 80, 80)
  If over : col = RGB(255, 120, 120) : EndIf
  Circle(knobX, y + h/2, 6, col)     ; curseur
  
  ; --- Affichage des valeurs ---
  DrawText(x - 30      , y + h/2 - 5, Str(vmin), RGB(255, 255, 255))   ; valeur minimale à gauche
  DrawText(x + w + 10  , y + h/2 - 5, Str(vmax), RGB(255, 255, 255))   ; valeur maximale à droite
  DrawText(x + w/2 - 10, y + h/2 - 5, Str(var), RGB(255, 255, 255))    ; valeur actuelle au milieu de la barre
  
  If over
    DrawText(mx  , y + h/2 - 10, Str(vard), RGB(255, 255, 255))
  EndIf
  
  ProcedureReturn var
EndProcedure

;----------

Procedure draw_filter_window(px , py ,lg , ht , mx , my , List list_filtre_selected.filtre())
  c = $333333
  If mx >= px And mx <= (px + lg) And my >= py And my <= (py + ht)
    c = $ff0000
  EndIf
  Box(px, py, lg, ht, c)               ; fond de la boîte
  Box(px +2, py+2, lg-4, ht-4, $777777); bordure
  bouton_quit(px + lg - 16 , py , 16 , 16 , mx , my)
EndProcedure


;----------

Procedure add_filtre(pos)
  
  Clear_Data_Filter(param)
  param\info_active = 1
  If tabfunc(pos) <> 0
    CallFunctionFast(tabfunc(pos),param); recupere les paramtres par defaut du filtre
    AddElement(list_filtre_selected())
    
    list_filtre_selected()\id = pos
    list_filtre_selected()\name = param\name
    list_filtre_selected()\remarque = param\remarque
    If list_filtre_selected()\remarque <> "" : list_filtre_selected()\ht + 1 : EndIf 
    For i = 0 To 19
      If param\info[i] = "" :Break : EndIf
      list_filtre_selected()\info(i) = param\info[i]
      list_filtre_selected()\opt(i,0) = param\info_data(i,0)
      list_filtre_selected()\opt(i,1) = param\info_data(i,1)
      list_filtre_selected()\opt(i,2) = param\info_data(i,2)
      list_filtre_selected()\ht + 1
      
      list_filtre_selected()\typ(i) = 0
      If param\info_data(i,1) - param\info_data(i,0) = 1
        list_filtre_selected()\typ(i) = 1
      EndIf
      If param\info_data(i,1) - param\info_data(i,0) > 1
        list_filtre_selected()\typ(i) = 2
      EndIf
      
    Next
    
  EndIf
  param\info_active = 0
EndProcedure

Procedure update_filtre(clic)
  Protected valider_tempo = 0
  Static validation
  Static Asm_active
  DrawingMode(#PB_2DDrawing_Transparent)
  
  mx = WindowMouseX(0)
  my = WindowMouseY(0)
  
  px = 85 * Window_SizeX / 100
  py = 0
  size = 22
  lg = 360
  
  ; ---------------------
  ; affiche le scrollbar
  scrollbar_lg = 24
  scrollbar_px = Window_SizeX - 26
  scrollbar_py = 2
  scrollbar_ht = Window_Sizey - 24
  Box(scrollbar_px + 0 , scrollbar_py + 0 , scrollbar_lg + 0 , scrollbar_ht + 0 , 0)
  Box(scrollbar_px + 1 , scrollbar_py + 1 , scrollbar_lg - 2 , scrollbar_ht - 2 , $afafaf)
  
  ; ---------------------
  ; affiche la fentre global des otions
  screen_option_lg = 500
  screen_option_px = Window_SizeX - screen_option_lg - scrollbar_lg - 3
  screen_option_py =   2
  screen_option_ht = Window_Sizey - 24
  Box(screen_option_px + 0 , screen_option_py + 0 , screen_option_lg + 0 , screen_option_ht + 0 , 0)
  Box(screen_option_px + 1 , screen_option_py + 1 , screen_option_lg - 2 , screen_option_ht - 2 , $afafaf)
  
  
  ; ---------------------
  option_px = screen_option_px + 2
  option_py = screen_option_py + 2
  option_lg = screen_option_lg - 3
  
  
  ; affiche la fentre de validation
  ht = size * 2 + 4
  If mx >= option_px And mx <= (option_px + option_lg) And my >= (option_py + py) And my <= (option_py + ht + py)
    Box(option_px + 0, option_py + py + 0 , option_lg + 0, ht + 0 , $00ff00)
    Box(option_px + 1, option_py + py + 1 , option_lg - 2, ht - 2 , $333333)
  Else
    Box(option_px + 0, option_py + py + 0 , option_lg + 0, ht + 0 , $333333)
  EndIf
  
  valider = 0
  If draw_bouton(option_px + 3 + 000, option_py + py + 5 , TextWidth("Vallider source") + 4 , 18 , mx , my , clic , "Vallider source", $ffffff) : valider = 0 : EndIf
  If draw_bouton(option_px + 3 + 130, option_py + py + 5 , TextWidth("Vallider mix") + 4 , 18 , mx , my , clic , "Vallider mix" , $ffffff) : valider = 0 : EndIf
  If draw_bouton(option_px + 3 + 240, option_py + py + 5 , TextWidth("Vallider mask") + 4 , 18 , mx , my , clic , "Vallider mask" , $ffffff) : valider = 0 : EndIf
  If draw_bouton(option_px + option_lg - 17 , option_py + py + 3 , TextWidth("X") + 4 , 18 , mx , my , clic , "X" , $ffffff) : ClearList(list_filtre_selected()) : EndIf 
  If draw_bouton(option_px + 3 + 000, option_py + py + 5+20 , TextWidth("Affichage") + 20 , 18 , mx , my , clic , "Affichage" , $ffffff ) : valider_tempo = 1 : EndIf
  If validation = 1 : t$ = "   On   " : Else : t$ = "   Off  " : EndIf
  If draw_bouton(option_px + 3 + 130, option_py + py + 5+20 , 50 , 18 , mx , my , clic , t$  , $ffffff , validation) : validation = (validation + 1) & 1 : EndIf
  
  If draw_bouton(option_px + 3 + 250, option_py + py + 5+20 , TextWidth("Loop") + 20 , 18 , mx , my , clic , "Loop" , $ffffff , valider_loop ) : valider_loop = (valider_loop + 1) & 1 : EndIf
  
  If Asm_active = 0 : t$ = "ASM_OFF" : Else : t$ = "ASM_ON" : EndIf
  If draw_bouton(option_px + 3 + 400, option_py + py + 5+20 , TextWidth(t$) + 20 , 18 , mx , my , clic , t$ , $ffffff ) : Asm_active = (Asm_active + 1) & 1 : active_asm(Asm_active) : EndIf
  py = ht + 2
  
  ForEach list_filtre_selected()
    If List_filtre_selected()\close = 1 And clic = 1
      DeleteElement(list_filtre_selected(),1)
      ProcedureReturn
    EndIf
    
    ht = (List_filtre_selected()\ht + 1) * size 
    
    ; affiche les fentres des options
    If mx >= option_px And mx <= (option_px + option_lg) And my >= (option_py + py) And my <= (option_py + ht + py)
      Box(option_px + 0, option_py + py + 0 , option_lg + 0, ht + 0 , $00ff00)
      Box(option_px + 1, option_py + py + 1 , option_lg - 2, ht - 2 , $333333)
    Else
      Box(option_px + 0, option_py + py + 0 , option_lg + 0, ht + 0 , $333333)
    EndIf
    
    
    ; affiche le bouton "quitter"
    bouton_quit(option_px + option_lg - 17 , py + 6 , 16 , 16 , mx , my)
    
    ; === BOUTONS :  Monter / Descendre 
    bx = option_px + option_lg - 80
    by = option_py + py + 2
    
    If bouton_filtre_up_down(bx , by , 16 , 16 , mx, my , clic , "↑")
      If ListSize(list_filtre_selected()) > 0 
        *pos = @list_filtre_selected()
        If PreviousElement(list_filtre_selected()) <> 0
          *npos = @list_filtre_selected()
          SwapElements(list_filtre_selected() , *pos, *npos)
        EndIf
      EndIf
    EndIf
    
    If bouton_filtre_up_down((bx + 20) , by , 16 , 16 , mx, my , clic , "↓")
      If ListSize(list_filtre_selected()) > 0
        *pos = @list_filtre_selected()
        If NextElement(list_filtre_selected()) <> 0
          *npos = @list_filtre_selected()
          SwapElements(list_filtre_selected() , *pos, *npos)
        EndIf
      EndIf
    EndIf
    
    
    DrawText(option_px + 2 + 200 , py + 3, List_filtre_selected()\name)
    py + size
    If List_filtre_selected()\remarque <> ""
      DrawText(option_px + 1 , py + 3, List_filtre_selected()\remarque )
      py + size
    EndIf
    
    For i = 0 To 19
      If List_filtre_selected()\info(i) = "" : Break : EndIf
      DrawText(option_px + 2 , py + 3, List_filtre_selected()\info(i))
      l.i = list_filtre_selected()\opt(i,1) - list_filtre_selected()\opt(i,0)
      l1 = 240 / (l+1)
      l2 = l1 - 10
      l3 = (l1 - l2) / l
      If l = 1 : l3 = (l1 - l2) * 0.5 : EndIf
      If l = 4 : l3 = (l1 - l2) * 0.5 : EndIf
      
      If l < 5
        For j = list_filtre_selected()\opt(i,0) To list_filtre_selected()\opt(i,1)
          pn  = option_px + 200 + ((j - list_filtre_selected()\opt(i,0)) * l1 ) + l3
          If list_filtre_selected()\opt(i,2) = j : opt = 1 : Else : opt = 0 : EndIf
          If Trim(LCase(List_filtre_selected()\info(i))) = "masque"
            Dim t$(3) : t$(0) = "Off" : t$(1) = "binary" : t$(2) = "Gray"
            If draw_bouton(pn , py + 3 , l2 , 18 , mx , my , clic , t$(j), $ffffff , opt) : list_filtre_selected()\opt(i,2) = j : EndIf
          Else
            If draw_bouton(pn , py + 3 , l2 , 18 , mx , my , clic , Str(j) , $ffffff , opt)
              m = list_filtre_selected()\opt(i,2)
              list_filtre_selected()\opt(i,2) = j
              If m <> j : valider = 1 : EndIf
            EndIf
          EndIf
        Next
      Else
        m1 = list_filtre_selected()\opt(i,2)
        list_filtre_selected()\opt(i,2) = bouton_TrackBar(option_px + 200, py + 3 , 240, 18 , list_filtre_selected()\opt(i,0) , list_filtre_selected()\opt(i,1) , list_filtre_selected()\opt(i,2) , mx  , my , clic)
        m2 = list_filtre_selected()\opt(i,2) ; list_filtre_selected()\opt(i,2) = float : m1,m2 = int
        If m1 <> m2 : valider = 1 : EndIf
      EndIf
      py + size
    Next
    py + 4
  Next
  
  ProcedureReturn ((valider & validation) | valider_tempo)
EndProcedure

Procedure delete_filtre(pos)
  
  ForEach list_filtre_selected()
    If list_filtre_selected()\id = pos
      DeleteElement(list_filtre_selected())
      ProcedureReturn
    EndIf
  Next
EndProcedure

;----------

Procedure resize_screen()
  Window_SizeX = WindowWidth(0)
  Window_SizeY = WindowHeight(0)
  ResizeGadget(0 , 0 , 0 , Window_SizeX , Window_SizeY)
  StartDrawing(CanvasOutput(0))
  Box(0 , 0 , Window_SizeX , Window_SizeY , $ffffffff)
  StopDrawing()
  
  Miniature_taille = (Window_SizeY * 20) / 100 ; 20% 
  Miniature_px = 1 * Window_SizeY / 100
  Miniature_py = 3 * Window_SizeY / 100
  Miniature_decal = 1.5 * Window_SizeY / 100
  ResizeImage(#img_miniature_Black , Miniature_taille -2, Miniature_taille -2)
  
  If IsImage(#img_miniature_source) : CopyImage(#img_miniature_source_copy , #img_miniature_source ) : ResizeImage(#img_miniature_source , Miniature_taille -2, Miniature_taille -2) : EndIf
  If IsImage(#img_miniature_mix)    : CopyImage(#img_miniature_mix_copy , #img_miniature_mix )       : ResizeImage(#img_miniature_mix , Miniature_taille -2, Miniature_taille -2)    : EndIf
  If IsImage(#img_miniature_mask)   : CopyImage(#img_miniature_mask_copy , #img_miniature_mask )     : ResizeImage(#img_miniature_mask , Miniature_taille -2, Miniature_taille -2)   : EndIf
  
  If IsImage(#img_miniature_source) : draw_miniature(#img_miniature_source , 0) : Else : draw_miniature(#img_miniature_Black,0) : EndIf
  If IsImage(#img_miniature_mix)    : draw_miniature(#img_miniature_mix , 1)    : Else : draw_miniature(#img_miniature_Black,1) : EndIf
  If IsImage(#img_miniature_mask)   : draw_miniature(#img_miniature_mask , 2)   : Else : draw_miniature(#img_miniature_Black,2) : EndIf
  
  ResizeImage(#img_aff , Window_SizeX - Miniature_taille - 600 , Window_SizeY - 24)
EndProcedure

;----------


;-- programme


ExamineDesktops()
Window_SizeX = (DesktopWidth(0)  * DesktopUnscaledX(100) / 100) - 256
Window_SizeY = (DesktopHeight(0) * DesktopUnscaledY(100) / 100) - 256

; --- Calcul possition et taille des miniatures
Miniature_taille = (Window_SizeY * 20) / 100 ; 20% 
Miniature_px = 1 * Window_SizeY / 100
Miniature_py = 3 * Window_SizeY / 100
Miniature_decal = 1.5 * Window_SizeY / 100

If OpenWindow(0, 0, 0, Window_SizeX, Window_SizeY, "test_filtres", #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget | #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget)
  
  
  ;--creation du menu
  CreateMenu(0, WindowID(0))
  MenuTitle("File")
  
  OpenSubMenu("Load")
  MenuItem( #Menu_load_Source, "Load Image 1 (source)")
  MenuItem( #Menu_load_Mix, "Load Image 2 (mixage)")
  MenuItem( #Menu_load_Mask, "Load Mask (masque)")
  CloseSubMenu()
  
  OpenSubMenu("Save")   
  MenuItem( #save, "Save BMP")
  ;MenuItem( 3, "Save JPG")
  MenuItem( #save2, "Save Clipboard")
  CloseSubMenu()
  MenuBar()
  ;MenuTitle("Quit")
  MenuItem( #quit, "Quit")
  
  MenuTitle("Valider")
  MenuItem( #copy1 , "modifier la source 1")
  MenuItem( #copy2 , "modifier la source 2")
  MenuItem( #copy3 , "modifier le Mask")
  
  create_menu_filtre()
  
  CanvasGadget(0, 0, 0, Window_SizeX, Window_SizeY )
  
  Window_SizeX = DesktopWidth(0) - 256
  Window_SizeY = DesktopHeight(0) - 256
  
  ;--creation de l'image tempo
  ;tempo_px = (Window_SizeX * 13) / 100
  ;tempo_py = (Window_SizeY *  1) / 100
  ;px = (Window_SizeX * 99) / 100
  ;py = (Window_SizeY * 99) / 100
  ;tempo_tx = px - tempo_px
  ;tempo_ty = py - tempo_py
  ;CreateImage(#img_tempo , tempo_tx , tempo_ty , 32)
  
  ;--creation des miniatures
  CreateImage(#img_miniature_Black , Miniature_taille -2, Miniature_taille -2)
  StartDrawing(ImageOutput(#img_miniature_Black))
  Box(0 , 0 , Miniature_taille , Miniature_taille , 0)
  StopDrawing()
  
  draw_miniature(#img_miniature_Black,0)
  draw_miniature(#img_miniature_Black,1)
  draw_miniature(#img_miniature_Black,2)
  
  CreateImage(#img_aff , Window_SizeX - Miniature_taille - 600 , Window_SizeY - 24 , 32)
  StartDrawing(ImageOutput(#img_miniature_Black))
  Box(0 , 0 , Window_SizeX - Miniature_taille - 600 , Window_SizeY - 4 , 0)
  StopDrawing()
  
  ;-- boucle
  ;Repeat
  Repeat
    update = 0
    Event = WindowEvent()
    
    If event <> 0  Or valider_loop
      If (WindowWidth(0) <> Window_SizeX) Or (WindowHeight(0) <> Window_SizeY) : resize_screen() : EndIf
    ;EndIf
    
    clic = 0
    If Event = #PB_Event_Gadget
      
      clic = 0
      Select EventGadget() 
        Case 0
          If EventType() = #PB_EventType_LeftButtonDown
            clic = 1 
          EndIf
          
          If EventType() = #PB_EventType_RightButtonDown
            
            ;clic = 1
            var = test_miniature()
            If var <> 0
              image_selected = var
              draw_miniature_selected(var)
              If IsImage(image_selected) <> 0
                t = 99
                CopyImage(image_selected , t)
                ResizeImage(t , ImageWidth(#img_aff) , ImageHeight(#img_aff) )
                CopyImage(t , #img_aff)
                FreeImage(t)
                t = 0
                StartDrawing(CanvasOutput(0))
                DrawImage(ImageID(#img_aff) ,  Miniature_taille + 32 , 2)
                StopDrawing()
              EndIf
            EndIf
            
          EndIf
      EndSelect
    EndIf
    
    
    Select Event
        
      Case #PB_Event_Menu
        var = EventMenu()
        Select var
            
          Case #Menu_load_Source : load_img(#img_source)      
          Case #Menu_load_Mix    : load_img(#img_mix)
          Case #Menu_load_Mask   : load_img(#img_mask)
            
          Case #filtre_pos To (#filtre_pos + 500)
            pos = (var - #filtre_pos)
            SelectElement(list_filtre(), pos)
            add_filtre(pos)
            update0 = 1
            
            ;Case #copy1 : copy_image(#source1)
            ;Case #copy2 : copy_image(#source2)
            ;Case #copy3 : copy_image(#mask)
            
          Case #save
            nom$ = SaveFileRequester("Save BMP", "", "", 0)
            ;If nom$ <> "" : SaveImage(#source1, nom$+".bmp" ,#PB_ImagePlugin_BMP ) : EndIf
            
          Case #save2
            ;SetClipboardImage(#source1)
            
          Case #quit
            quit = 1
        EndSelect
        
        
    EndSelect
    
    
    ;If clic
    
    StartDrawing(CanvasOutput(0))
    var = update_filtre(clic)
    StopDrawing()
    ;Debug var
    
    If var Or valider_loop
      
      param\source = 0 : param\mix = 0 : param\cible = 0 : param\mask = 0
      *source = 0 : *mix = 0 : *cible = 0 : *mask = 0 : *tempo_source = 0 : *tempo_cible = 0
      If IsImage(#img_tempo_source) : FreeImage(#img_tempo_source) : EndIf
      If IsImage(#img_tempo_cible)  : FreeImage(#img_tempo_cible)  : EndIf
      If IsImage(#img_source) And StartDrawing(ImageOutput(#img_source)) : *source = DrawingBuffer() : StopDrawing() : EndIf
      If IsImage(#img_mix) And StartDrawing(ImageOutput(#img_mix))       : *mix     = DrawingBuffer() : StopDrawing() : EndIf
      If IsImage(#img_cible) And StartDrawing(ImageOutput(#img_cible))   : *cible   = DrawingBuffer() : StopDrawing() : EndIf
      If IsImage(#img_mask) And StartDrawing(ImageOutput(#img_mask))     : *mask    = DrawingBuffer() : StopDrawing() : EndIf
      
      Select image_selected
        Case 1
          If *source : CopyImage(#img_source , #img_tempo_source) : EndIf
        Case 2
          If *mix : CopyImage(#img_mix , #img_tempo_source) : EndIf
        Case 3
          If *mask : CopyImage(#img_mask , #img_tempo_source) : EndIf
      EndSelect
      
      If IsImage(#img_tempo_source) And StartDrawing(ImageOutput(#img_tempo_source)) : *tempo_source = DrawingBuffer() : StopDrawing() : CopyImage(#img_tempo_source , #img_tempo_cible) : EndIf
      If IsImage(#img_tempo_cible)  And StartDrawing(ImageOutput(#img_tempo_cible))  : *tempo_cible  = DrawingBuffer() : StopDrawing() : EndIf
      
      param\source = *tempo_source
      param\mix = *mix
      param\cible = *tempo_cible
      
      If *mix
        param\mix = *mix
        param\lg_mix = ImageWidth(#img_mix)
        param\ht_mix = ImageHeight(#img_mix) 
      EndIf
      
      If *mask
        param\mask = *mask
        param\lg_mask = ImageWidth(#img_mask)
        param\ht_mask = ImageHeight(#img_mask) 
      EndIf
      
      param\source_mask = param\source
      If IsImage(#img_tempo_source)
        param\lg = ImageWidth(#img_tempo_source)
        param\ht = ImageHeight(#img_tempo_source) 
        t = ElapsedMilliseconds()
        ForEach list_filtre_selected()
          For i = 0 To 19 : param\option[i] = list_filtre_selected()\opt(i,2) : Next
          If tabfunc(list_filtre_selected()\id) <> 0 : CallFunctionFast(tabfunc(list_filtre_selected()\id),param) : EndIf
          param\source = param\cible
        Next
        t = ElapsedMilliseconds() - t
        SetWindowTitle(0, "test_filtres : "+Str(t) ) 
      EndIf
      
    EndIf
    
    If IsImage(#img_tempo_cible)
      ResizeImage(#img_tempo_cible , ImageWidth(#img_aff) , ImageHeight(#img_aff) )
      CopyImage(#img_tempo_cible , #img_aff)
      FreeImage(#img_tempo_cible)
    EndIf
    
    StartDrawing(CanvasOutput(0))
    DrawImage(ImageID(#img_aff) ,  Miniature_taille + 32 , 2)
    StopDrawing()
    
    EndIf
    Delay(1)
  Until Event = #PB_Event_CloseWindow Or quit = 1
  ;If IsImage(#cible) : FreeImage(#cible) : EndIf
  ;If IsImage(#Black_image) : FreeImage(#Black_image) : EndIf
  CloseWindow(0)
  
EndIf



; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 25
; Folding = ----
; EnableThread
; EnableXP
; DPIAware
; CPU = 5
; DisableDebugger
; Compiler = PureBasic 6.21 - C Backend (Windows - x64)