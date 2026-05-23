

IncludeFile "filtres.pbi"
UseModule filtres

;IncludeFile "xnview\xnview.pbi"
;If  XnViewLoader::Init()
;Debug "lib xnview ok"
;Else
;MessageRequester("Erreur", "Impossible de charger libgfl.dll")
;EndIf

; ---------------------- Constantes / IDs ----------------------
Enumeration 
  #Menu_load_Source = 1
  #Menu_load_Mix
  #Menu_load_Mask
  
  #save_bmp1
  #save_jpg1
  #save_png1
  #save_clipboard1
  #save_bmp2
  #save_jpg2
  #save_png2
  #save_clipboard2
  #save_bmp3
  #save_jpg3
  #save_png3
  #save_clipboard3
  #save_bmp4
  #save_jpg4
  #save_png4
  #save_clipboard4
  #quit
  #mask_e
  #mask_d
  #mask_n
  #copy1
  #copy2
  #copy3
  
  #menu_image_source
  #menu_image_mix
  #menu_image_masque
  #menu_image_travail
  
  #boutton_Appliquer_source
  #boutton_Appliquer_mix
  #boutton_Appliquer_mask
  
  #resize
  #favoris
  #info_cpu
  #info_image
  
  #boutton_Apercu
  #boutton_Auto_Rendu
  #boutton_mask
  #boutton_thread
  #boutton_asm
  #boutton_aide
  #boutton_fermer_filtre
  
  #frame_filters ; options toujour visible ( static )
  #frame_options ; options des filtres graphiques
  
  #canvas_option
  #canvas_affichage
  #canvas_miniature_source
  #canvas_miniature_mix
  #canvas_miniature_mask
  
  #menu_favori_trier_name
  #menu_favori_trier_id
  #menu_favori_trier_type
  #menu_favori_supprimer
EndEnumeration

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
  
EndEnumeration

#filtre_pos = 1000
#filtre_windows_pos = #filtre_pos + 1000
#filtre_pos_sup = 5000

Global img_save

Global image_selected = -1

Structure my_gadget
  Window_lg.l
  window_ht.l
  
  frame1_px.l
  frame1_py.l
  frame1_lg.l
  frame1_ht.l
  
  frame2_px.l
  frame2_py.l
  frame2_lg.l
  frame2_ht.l
  
  canvas_px.l
  canvas_py.l
  canvas_lg.l
  canvas_ht.l
  
  boutton_px.l[19]
  boutton_py.l[19]
  boutton_lg.l[19]
  boutton_ht.l[19]
  boutton_text.s[19]
  
EndStructure
Global entity.my_gadget

Structure filtre
  id.i
  name.s
  type_filter.i
  remarque.s
  ht.i
  close.i
  thread.i
  langue.i
  StructureUnion
    convol3.l[9] ; (3 * 3)
    convol5.l[25]; (5 * 5)
    convol7.l[49]; (7 * 7)
  EndStructureUnion
  Array typ.i(20)
  Array info.s(20)
  Array opt.f(20,9)
EndStructure
Global NewList list_filtre.filtre()
Global NewList list_filtre_selected.filtre()
;Global NewList list_favoris.filtre()


Structure favori_data
  name.s
  id.i
  typ.i
EndStructure
Global NewList favori.favori_data()
Global favori_write

Structure filter_resize_stucture
  id.i
  name.s
EndStructure
Global NewList filter_resize.filter_resize_stucture()

; global pour la fenetre principale
Global Window_SizeX.l
Global Window_SizeY.l

; global pour les miniatures
Global Miniature_taille
Global Miniature_px
Global Miniature_py
Global Miniature_decal

; global pour l'image de travail = #img_aff
Global travail_tx
Global travail_ty

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
Global valider_source = 0
Global valider_mix = 0
Global valider_mask = 0

Global filtre_special_fire = 0

;----------

Global track_drag.b = #False      ; Est-on en train de glisser ?
Global track_id_drag.i = -1       ; Quel slider est actif ?
Global mouseUp.b = #False         ; Le bouton vient-il d'être relâché ?
Global mat_focus_id.i = -1        ; -1 = aucune cellule, 0 à 8 = cellule matrice

Procedure update_miniature_sp(var1, var2 , col)
  If IsImage(var2)
    StartDrawing(CanvasOutput(var1))
    Box(0 , 0,Miniature_taille , Miniature_taille , col)
    DrawImage(ImageID(var2), 4, 4)
    StopDrawing() 
  EndIf
EndProcedure

Procedure update_miniature(selected , col = $ff00)
  
  update_miniature_sp(#canvas_miniature_source , #img_miniature_source , 0)
  update_miniature_sp(#canvas_miniature_mix    , #img_miniature_mix , 0)
  update_miniature_sp(#canvas_miniature_mask   , #img_miniature_mask , 0)
  
  Select selected
    Case 1 : update_miniature_sp(#canvas_miniature_source , #img_miniature_source , col)
    Case 2 : update_miniature_sp(#canvas_miniature_mix    , #img_miniature_mix    , col)
    Case 3 : update_miniature_sp(#canvas_miniature_mask   , #img_miniature_mask   , col)
  EndSelect
  
  ;If IsImage(selected)
  ;CopyImage(selected , #img_aff) : ResizeImage(#img_aff , travail_tx , travail_ty)
  ;StartDrawing(CanvasOutput(#canvas_affichage))
  ;DrawImage(ImageID(#img_aff), 0, 0)
  ;StopDrawing()
  ;EndIf
  
  ProcedureReturn selected
EndProcedure

Procedure update_image_aff()
  If IsImage(image_selected)
    CopyImage(image_selected , #img_aff)
    ResizeImage(#img_aff , travail_tx , travail_ty)
    StartDrawing(CanvasOutput(#canvas_affichage))
    DrawImage(ImageID(#img_aff), 0, 0)
    StopDrawing()
  EndIf
EndProcedure

;----------

Procedure load_image_sp(var1 , var2 , pos)
  If IsImage(var2) <> 0 : FreeImage(var2) : EndIf ; supprime la miniature
  CopyImage(var1 , var2)
  ResizeImage(var2 , Miniature_taille - 8, Miniature_taille - 8)
  
  StartDrawing(CanvasOutput(pos))
  DrawImage(ImageID(var2), 2, 2)
  StopDrawing() 
EndProcedure

Procedure load_img(var)
  file$ = OpenFileRequester("Image","","",0)
  ;ig = XnViewLoader::LoadToPB(file$)
  ;If ig
  If load_image_32(var,file$) = 1
    Select var
      Case #img_source
        load_image_sp(#img_source , #img_miniature_source , #canvas_miniature_source)
      Case #img_mix
        load_image_sp(#img_mix    , #img_miniature_mix    , #canvas_miniature_mix)
      Case #img_mask
        load_image_sp(#img_mask   , #img_miniature_mask   , #canvas_miniature_mask)
    EndSelect
  EndIf
EndProcedure

;----------

Structure FilterInfo
  id.l
  name.s
  typ.l
  subtype.l
EndStructure
Global Dim typ(999)


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
  
  For i = 0 To 999 : typ(i)= 0 : Next
  
  With FilterCtx
    \info_active = 1
    ; Liste temporaire pour tous les filtres
    NewList filterList.FilterInfo()
    
    ; Collecte de tous les filtres (y compris ID 0)
    For i = 0 To 999
      ; CORRECTION : Vérifier si la fonction existe ET est valide
      If tabfunc(i) <> 0
        ; Réinitialiser les champs avant l'appel
        \name = ""
        \typ = 0
        \subtype = 0
        CallFunctionFast(tabfunc(i), FilterCtx)
        
        ; CORRECTION : Vérifier si le filtre a retourné des infos valides
        ; Un filtre valide doit avoir au minimum un nom
        If \name <> ""
          AddElement(filterList())
          filterList()\id      = i
          filterList()\name    = \name
          filterList()\typ     = \typ
          filterList()\subtype = \subtype
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
        Case #FilterType_Convolution
          create_menu_filtre_add_sp2(filterList() , #FilterType_Convolution , "Convolution" , 12)
        Case #FilterType_Resize
          AddElement(filter_resize())
          filter_resize()\name = filterList()\name
          filter_resize()\id   = filterList()\id
        Default
          create_menu_filtre_add_sp2(filterList() , filterList()\typ , "Autres" , 14) 
      EndSelect
      
      PopListPosition(filterList())
    Next
    CloseSubMenu()
    \info_active = 0
    ClearList(filterList()) 
  EndWith
EndProcedure

;----------

Procedure affiche_info_aide()
  Protected t$, win, web
  
  t$ = GetCurrentDirectory() + "filtres\aide\aide.html"

  If FileSize(t$) >= 0

    ; #PB_Any génère automatiquement un numéro d'identifiant unique et libre
    win = OpenWindow(#PB_Any, 0, 0, 800, 600, "aide", #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
    
    If win
      ; On utilise aussi #PB_Any pour le gadget, lié à sa fenêtre
      web = WebGadget(#PB_Any, 0, 0, 800, 600, "file://" + t$)
    EndIf
    
  Else
    Debug "Fichier HTML non trouvé : " + t$
  EndIf
EndProcedure


Procedure affiche_info()
  Protected t$, win, web
  
  t$ = GetCurrentDirectory() + "filtres\aide\" + List_filtre_selected()\name + ".html"

  If FileSize(t$) >= 0

    ; #PB_Any génère automatiquement un numéro d'identifiant unique et libre
    win = OpenWindow(#PB_Any, 0, 0, 800, 600, List_filtre_selected()\name, #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
    
    If win
      ; On utilise aussi #PB_Any pour le gadget, lié à sa fenêtre
      web = WebGadget(#PB_Any, 0, 0, 800, 600, "file://" + t$)
    EndIf
    
  Else
    Debug "Fichier HTML non trouvé : " + t$
  EndIf
EndProcedure


;----------
;--creation du menu
Procedure create_menu_part1()
  ClearList(filter_resize())
  CreateMenu(0, WindowID(0))
  MenuTitle("File")
  
  OpenSubMenu("Load")
  MenuItem( #Menu_load_Source, "Load Image 1 (source)")
  MenuItem( #Menu_load_Mix, "Load Image 2 (mixage)")
  MenuItem( #Menu_load_Mask, "Load Mask (masque)")
  CloseSubMenu()
  
  OpenSubMenu("Save")   
    OpenSubMenu("source 1") 
      MenuItem( #save_bmp1, "Save BMP")
      MenuItem( #save_jpg1, "Save JPG")
      MenuItem( #save_png1, "Save PNG")
      MenuItem( #save_clipboard1, "Save Clipboard")
    CloseSubMenu()
    OpenSubMenu("source 2(mixage)") 
      MenuItem( #save_bmp2, "Save BMP")
      MenuItem( #save_jpg2, "Save JPG")
      MenuItem( #save_png2, "Save PNG")
      MenuItem( #save_clipboard2, "Save Clipboard")    
    CloseSubMenu()
    OpenSubMenu("masque") 
      MenuItem( #save_bmp3, "Save BMP")
      MenuItem( #save_jpg3, "Save JPG")
      MenuItem( #save_png3, "Save PNG")
      MenuItem( #save_clipboard3, "Save Clipboard")    
    CloseSubMenu()
    OpenSubMenu("image de travail") 
      MenuItem( #save_bmp4, "Save BMP")
      MenuItem( #save_jpg4, "Save JPG")
      MenuItem( #save_png4, "Save PNG")
      MenuItem( #save_clipboard4, "Save Clipboard")    
    CloseSubMenu()  
  CloseSubMenu()
  MenuBar()
  ;MenuTitle("Quit")
  MenuItem( #quit, "Quit")
    
  ; la position de boutons n'est pas bonne , ils sont tous replacer dans le fonction resize_screen
  ButtonGadget(#boutton_Appliquer_source, 5, 5, 110, 25, "Appliquer -> Source")
  ButtonGadget(#boutton_Appliquer_mix,  120, 5, 110, 25, "Appliquer -> Mixage")
  ButtonGadget(#boutton_Appliquer_mask, 235, 5, 110, 25, "Appliquer -> Masque")
  ButtonGadget(#boutton_Apercu,         120, 5, 110, 25, "Apercu")
  
  ButtonGadget(#boutton_Auto_Rendu,     235, 5, 110, 25, "Auto_Rendu : Off", #PB_Button_Toggle)
  SetGadgetState(#boutton_Auto_Rendu , 0)
  
  ButtonGadget(#boutton_mask,             5, 5, 110, 25, "afficher -> masque : Off" , #PB_Button_Toggle)
  ButtonGadget(#boutton_thread,         120, 5, 110, 25, "affiche -> thread : Off" , #PB_Button_Toggle)
  ButtonGadget(#boutton_asm,            235, 5, 110, 25, "affiche -> language : Off" , #PB_Button_Toggle)
  
  ButtonGadget(#boutton_aide,             5, 5, 110, 25, "Aide")
  ButtonGadget(#boutton_fermer_filtre,  120, 5, 110, 25, "Fermer tous les filtres")
  
  FrameGadget(#frame_filters, 0, 0, 10, 10, "" ,#PB_Frame_Flat)
  FrameGadget(#frame_options, 0, 0, 10, 10, "" ,#PB_Frame_Flat)
  
  create_menu_filtre()
  
  MenuTitle("resize")
  ForEach filter_resize()
    MenuItem( filter_resize()\id, filter_resize()\name)
  Next
  
  MenuTitle("Favoris")
  OpenSubMenu("Favoris")
EndProcedure

Procedure create_menu_part2()
  CloseSubMenu()
  OpenSubMenu("trier") 
  MenuItem( #menu_favori_trier_name, "trier par nom")
  MenuItem( #menu_favori_trier_id, "trier par ID")
  MenuItem( #menu_favori_trier_type, "trier par type")
  CloseSubMenu()
  OpenSubMenu("supprimer") 
  ForEach favori()
    MenuItem(#filtre_pos_sup + favori()\id , favori()\name)
  Next
  CloseSubMenu()
  MenuTitle("info")
  MenuItem( #info_cpu, "info_cpu")
  MenuItem( #info_image, "info_image")
EndProcedure

;----------
Procedure load_favori()
  Protected t$
  ; #PS$ s'adapte automatiquement : "\" sur Windows, "/" sur Mac/Linux
  t$ = GetCurrentDirectory() + "filtres" + #PS$ + "favori"
  
  If OpenFile(0, t$)
    ClearList(favori())
    While Eof(0) = 0
      l$ = ReadString(0) ; Note : C'est ReadString(0) pour lire une ligne de texte
                         ; On nettoie les espaces inutiles et on vérifie que la ligne n'est pas vide
      l$ = Trim(l$)
      If l$ <> ""
        AddElement(favori())
        ; StringField(chaîne, position, "séparateur")
        favori()\name = StringField(l$, 1, ",")
        favori()\id   = Val(StringField(l$, 2, ","))
        favori()\typ  = Val(StringField(l$, 3, ","))
      EndIf
    Wend
    CloseFile(0)
    ForEach favori()
      MenuItem(#filtre_pos + favori()\id , favori()\name)
    Next
  Else
    If CreateFile(0, t$) ; Si OpenFile échoue, on tente de le créer
      Debug "Le fichier n'existait pas, il a été créé."
      CloseFile(0)
    Else
      favori_write = 1 ; impossible de creer un fichier
      Debug "Impossible de créer le fichier (vérifiez que le dossier 'filtre' existe)."
    EndIf
  EndIf
EndProcedure

Procedure add_favori(nom$ , id ,typ)
  With favori()
    ForEach favori()
      If \name = nom$ : ProcedureReturn : EndIf
    Next
    AddElement(favori())
    \name = nom$
    \id = id
    \typ = typ
    t$ = GetCurrentDirectory() + "filtres" + #PS$ + "favori"
    If OpenFile(0, t$) And favori_write = 0
      ForEach favori()
        l$ = \name + "," + Str(\id) + "," + Str(\typ)
        WriteStringN(0,l$)
      Next
      CloseFile(0)
      l$ = "Le filtre " + \name + " a bien été ajouté dans vos favoris."
      MessageRequester("Ajouter un filtre en favori", l$, #PB_MessageRequester_Ok)
      create_menu_part1()
      ForEach favori()
        MenuItem(#filtre_pos + \id , \name)
      Next
      create_menu_part2()
    EndIf 
  EndWith
EndProcedure

Procedure update_favori()
    If favori_write = 1 : ProcedureReturn : EndIf
    t$ = GetCurrentDirectory() + "filtres" + #PS$ + "favori"
    If OpenFile(0, t$)
      ForEach favori()
        l$ = favori()\name + "," + Str(favori()\id) + "," + Str(favori()\typ)
        WriteStringN(0,l$)
      Next
      CloseFile(0)
      create_menu_part1()
      ForEach favori()
        MenuItem(#filtre_pos + favori()\id , favori()\name)
      Next
      create_menu_part2()
    EndIf 
EndProcedure

;----------

Procedure draw_bouton(px , py , lg , ht , mx , my , clic ,  t$ = "" , c1 = $ffffff , opt = 0)
  Protected c2, c3, lg_text, var = 0
  
  ; --- VERROUILLAGE ---
  ; Si un slider est manipulé, le bouton ignore le clic
  If track_id_drag <> -1
    clic = 0
  EndIf
  
  c2 = $77 - 40
  c3 = $77 + 40
  If opt <> 0 : Swap c2 , c3 : EndIf
  
  Box(px + 0, py + 0, lg - 0, ht - 0, RGB(c3, c3, c3))   ; haut
  Box(px + 2, py + 2, lg - 2, ht - 2, RGB(c2, c2, c2))   ; bas
  Box(px + 2, py + 2, lg - 4, ht - 4, $777777)           ; fond
  
  lg_text = TextWidth(t$)
  
  ; Détection du survol uniquement si aucun slider n'est actif
  If track_id_drag = -1 And mx > px And mx < (px + lg) And my > py And my < (py + ht)
    DrawText(px + (lg - lg_text) * 0.5 , py , t$ , $af)
    If clic = 1 : var = 1 : EndIf
  Else
    If opt : c1 = $dfdfdf : EndIf
    DrawText(px + (lg - lg_text) * 0.5 , py , t$ , c1)
    var = 0
  EndIf
  
  ProcedureReturn var
EndProcedure



Procedure bouton_filtre_up_down(px , py , lg , ht , mx, my , clic , t$)
  col = $ffffff
  over = 0
  If  (mx >= px) And (mx <= (px + lg)) And (my >= py) And (my <= (py + ht)) : over = 1  : col = $ff : EndIf
  
  draw_bouton(px , py , lg , ht , 0 , 0 , clic)
  ;Box(px, py, lg, ht, col)
  DrawRotatedText(px  , py + 13 , t$, 90, col)
  ;DrawText(px + 5, py + 1, t$, col)
  
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
  draw_bouton(px , py , tx , ty , 0 , 0 , clic)
  DrawText(px + 3 , py + 1 , "X" , col)
EndProcedure

Procedure.f bouton_TrackBar(id_unique, x.f, y.f, w.f, h.f, vmin.f, vmax.f, var.f, mx.f, my.f, clic , opt = 0)
  Protected knobX.f, over = #False, col
  Protected nv.f
  
  ; 1. Détection du survol (uniquement si rien n'est verrouillé ou si c'est nous l'ID actif)
  If track_id_drag = -1 Or track_id_drag = id_unique
    If mx >= x And mx <= x + w And my >= y - 2 And my <= y + h + 2
      over = #True
    EndIf
  EndIf
  
  ; 2. Logique de Drag & Drop avec VERROU
  ; On ne peut cliquer que si personne d'autre ne "drague"
  If clic = 1 And over And track_id_drag = -1
    track_drag = #True
    track_id_drag = id_unique
  EndIf
  
  ; Libération du verrou (mouseUp est mis à jour dans la boucle principale)
  If mouseUp
    track_drag = #False
    track_id_drag = -1
  EndIf
  
  ; 3. Mise à jour de la valeur (uniquement si on est le propriétaire du verrou)
  If track_drag And track_id_drag = id_unique
    nv = (mx - x) / w
    If nv < 0 : nv = 0 : EndIf
    If nv > 1 : nv = 1 : EndIf
    var = vmin + nv * (vmax - vmin)
    If opt : var = Int(var) : EndIf
  EndIf
  
  ; --- DESSIN --- (Le reste du code de dessin inchangé)
  Box(x, y + h/2 - 2, w, 4, $444444) 
  knobX = x + ((var - vmin) / (vmax - vmin)) * w
  
  col = $5050FF
  If over : col = $8080FF : EndIf
  If track_id_drag = id_unique : col = $00FFFF : EndIf ; Cyan quand on manipule
  
  Box(knobX - 4, y, 8, h, col)
  DrawText(x + w + 10, y, StrF(var, 1), $FFFFFF, $333333)
  
  ProcedureReturn var
EndProcedure

;----------

Procedure add_filtre(pos)
  
  With FilterCtx
    Clear_Data_Filter(FilterCtx)
    \info_active = 1
    If tabfunc(pos) <> 0
      CallFunctionFast(tabfunc(pos),FilterCtx); recupere les paramtres par defaut du filtre
      AddElement(list_filtre_selected())
      
      list_filtre_selected()\id = pos
      list_filtre_selected()\name = \name
      list_filtre_selected()\type_filter = \typ
      list_filtre_selected()\remarque = \remarque
      list_filtre_selected()\ht = 1  
      list_filtre_selected()\thread = \thread
      For i = 0 To 19
        If \info[i] = "" :Break : EndIf
        list_filtre_selected()\info(i) = \info[i]
        list_filtre_selected()\opt(i,0) = \info_data(i,0)
        list_filtre_selected()\opt(i,1) = \info_data(i,1)
        list_filtre_selected()\opt(i,2) = \info_data(i,2)
        list_filtre_selected()\ht + 1
        
        list_filtre_selected()\typ(i) = 0
        If \info_data(i,1) - \info_data(i,0) = 1
          list_filtre_selected()\typ(i) = 1
        EndIf
        If \info_data(i,1) - \info_data(i,0) > 1
          list_filtre_selected()\typ(i) = 2
        EndIf
        
      Next
      
    EndIf
    \info_active = 0
  EndWith
EndProcedure


Procedure update_filtre(clic)
  StartDrawing(CanvasOutput(#canvas_option))
  With entity
    Box(0,0,\canvas_lg , \canvas_ht , $ffffff)
    
    DrawingMode(#PB_2DDrawing_Transparent)
    
    mx = GetGadgetAttribute(#canvas_option, #PB_Canvas_MouseX)
    my = GetGadgetAttribute(#canvas_option, #PB_Canvas_MouseY)
    
    ; ---------------------
    option_px = 0
    option_py = 0
    option_lg = \canvas_lg
    
    size = 22
    ht = 0
    py = ht
    
    If clic = 10
      clic = 0
      ForEach list_filtre_selected()
        DeleteElement(list_filtre_selected())
      Next
    EndIf
    
    ForEach list_filtre_selected()
      
      If List_filtre_selected()\close = 1 And clic = 1
        DeleteElement(list_filtre_selected(),1)
        StopDrawing()
        ProcedureReturn 0
      EndIf
      
      ; determine la taille de la fentre des options
      ht = ((List_filtre_selected()\ht + 1) + GetGadgetState(#boutton_mask) + GetGadgetState(#boutton_thread) + GetGadgetState(#boutton_asm))* size 
      
      ; modifie la taille de la fentre des options pour la convolution
      opt_boutton = 0
      Select list_filtre_selected()\name
        Case "Convolution 3x3"
          ht = ht + 4 * size
          opt_boutton = 3
        Case "Convolution 5x5"
          ht = ht + 6 * size
          opt_boutton = 5
        Case "Convolution 7x7"
          ht = ht + 8 * size
          opt_boutton = 7
      EndSelect
      
      ;-- affiche les fentres des options
      If mx >= option_px And mx <= (option_px + option_lg) And my >= (option_py + py) And my <= (option_py + ht + py)
        Box(option_px + 0, option_py + py + 0 , option_lg + 0, ht + 0 , $00ff00)
        Box(option_px + 1, option_py + py + 1 , option_lg - 2, ht - 2 , $333333)
      Else
        Box(option_px + 0, option_py + py + 0 , option_lg + 0, ht + 0 , $333333)
      EndIf
      
      bx = option_px + option_lg - 70
      by = option_py + py
            
      ;-- affiche le bouton "quitter"
      bouton_quit(option_px + option_lg - 19 , by + 1, 18 , 18 , mx , my)
      
      ; === BOUTONS :  Monter / Descendre 
      ;-- affiche le bouton "monter"
      ;If bouton_filtre_up_down(bx , by + 1, 18 , 18 , mx, my , clic , "↑")
      If bouton_filtre_up_down(bx , by + 1, 18 , 18 , mx, my , clic , ">")
        If ListSize(list_filtre_selected()) > 0 
          *pos = @list_filtre_selected()
          If PreviousElement(list_filtre_selected()) <> 0
            *npos = @list_filtre_selected()
            SwapElements(list_filtre_selected() , *pos, *npos)
          EndIf
        EndIf
      EndIf
      
      ;-- affiche le bouton "descendre"
      If bouton_filtre_up_down((bx + 20) , by + 1 , 18 , 18 , mx, my , clic , "<")
        If ListSize(list_filtre_selected()) > 0
          *pos = @list_filtre_selected()
          If NextElement(list_filtre_selected()) <> 0
            *npos = @list_filtre_selected()
            SwapElements(list_filtre_selected() , *pos, *npos)
          EndIf
        EndIf
      EndIf
      
      ;-- affiche le bouton "help"
      If draw_bouton(option_px + option_lg - 70 , by + size, 30 , 18 , mx , my , clic , "aide") : affiche_info() : EndIf

      
      ;-- affiche le bouton "add"
      If draw_bouton(option_px + option_lg - 35 , by + size, 30 , 18 , mx , my , clic , "add")
        add_favori(List_filtre_selected()\name , list_filtre_selected()\id , list_filtre_selected()\type_filter)
      EndIf
      
      ;-- affiche le nom du filtre
      DrawText(option_px + 2 + 200 , py + 3, List_filtre_selected()\name)
      py + size
      If  DrawText(option_px + 1 , py + 3, List_filtre_selected()\remarque )
        py + size
      EndIf
      
      For i = 0 To 19
        ; 1. Sortie anticipée
        If List_filtre_selected()\info(i) = "" : Break : EndIf
        Protected current_id = @list_filtre_selected() + i
        ; 2. Préparation des variables (pour éviter de retaper des lignes à rallonge)
        nom_option$ = Trim(LCase(List_filtre_selected()\info(i)))
        val_min = List_filtre_selected()\opt(i, 0)
        val_max = List_filtre_selected()\opt(i, 1)
        val_cur = List_filtre_selected()\opt(i, 2)
        
        DrawText(option_px + 2 , py + 3, List_filtre_selected()\info(i))
        
        ; 3. Calcul de la géométrie (Une seule fois !)
        l = val_max - val_min
        
        l1 = 240 / (l + 1)
        l2 = l1 - 10
        l3 = (l1 - l2) / l
        If l = 1 Or l = 4 : l3 = (l1 - l2) * 0.5 : EndIf
        
        ; 4. Logique d'affichage
        If l < 5
          ; Boucle d'affichage des boutons
          For j = 0 To l
            pn = option_px + 200 + (j * l1) + l3
            
            ; On détermine le texte et l'état de sélection
            txt$ = Str(val_min + j)
            is_opt = Bool(val_cur = (val_min + j))
            
            ; Dessin et interaction
            If draw_bouton(pn, py + 3, l2, 18, mx, my, clic, txt$, $ffffff, is_opt)
              res = val_min + j
              If val_cur <> res
                List_filtre_selected()\opt(i, 2) = res
                valider = 1
              EndIf
            EndIf
          Next
          
        Else
          ; Cas Trackbar
          ;res = bouton_TrackBar(option_px + 200, py + 3, 240, 18, val_min, val_max, val_cur, mx, my, clic)
          res = bouton_TrackBar(current_id, option_px + 200, py + 3, 240, 18, val_min, val_max, val_cur, mx, my, clic)
          If res <> val_cur
            List_filtre_selected()\opt(i, 2) = res
            valider = 1
          EndIf
        EndIf
        py + size
      Next
      
      ;-- affiche la grille de boutton pour les filtres de convolution
      If opt_boutton > 0
        Protected mat_idx = 0
        Protected txt_mat$
        
        ; afficher une liste deroulante avec toutes les options
        ; if opt > -1 and opt < 50
        ;convolution3x3_select(opt)
        ;endif
        
        ; --- AFFICHAGE DE LA GRILLE ---
        For y = 0 To opt_boutton - 1
          For x = 0 To opt_boutton - 1
            ; On stocke les valeurs de la matrice à partir de l'index 10 du tableau opt
            ; pour ne pas écraser les paramètres de division/décalage (index 0 et 1)
            Protected cell_val.f = List_filtre_selected()\convol7[mat_idx]
            txt_mat$ = StrF(cell_val, 0)
            
            ; Couleur spéciale si la cellule a le focus clavier
            Protected is_focused = #False
            If mat_focus_id = mat_idx : is_focused = #True : EndIf
            
            ; Dessin de la cellule
            px2 = 200
            If opt_boutton = 7 : px2 = 100 : EndIf
            If draw_bouton(option_px + px2 + x * 52, py + 3, 50, 18, mx, my, clic, txt_mat$, $ffffff, is_focused)
              mat_focus_id = mat_idx ; On donne le focus à cette cellule
            EndIf
            
            mat_idx + 1
          Next
          py + size
        Next
      EndIf
      
      
      
      ;-- option de l'affichage des parametres du masque
      If GetGadgetState(#boutton_mask) 
        Protected val_int.i = Int(List_filtre_selected()\opt(i, 2))
        DrawText(option_px + 2, py + 3, "Masque")
        l = 3 : l1 = 240 / 4 : l2 = l1 - 10 : l3 = (l1 - l2) * 0.5
        For j = 0 To 3
          pn = option_px + 200 + (j * l1) + l3
          txt$ = StringField("Off,Bin,Gray,Inv", j + 1, ",")
          ; Test de sélection sur l'entier
          If j < 3 : is_opt = Bool((val_int & 3) = j) : Else : is_opt = Bool(val_int & 4) : EndIf
          If draw_bouton(pn, py + 3, l2, 18, mx, my, clic, txt$, $ffffff, is_opt)
            If j < 3
              val_int = (val_int & 4) | j  ; Calcul binaire sur l'entier
            Else
              val_int = val_int ! 4        ; Toggle du bit 4 sur l'entier
            EndIf
            ; On renvoie l'entier vers le champ float
            List_filtre_selected()\opt(i, 2) = val_int
            valider = 1
          EndIf
        Next
        py + size
      EndIf
      
      ;-- option de l'affichage des parametres des threads
      If GetGadgetState(#boutton_thread) 
        val_max = CountCPUs(#PB_System_CPUs) - 1
        If val_max < 1 : val_max = 1 : EndIf
        val_min = 1
        DrawText(option_px + 2, py + 3, "threads")
        mem = List_filtre_selected()\thread
        res = bouton_TrackBar(current_id, option_px + 200, py + 3, 240, 18, val_min, val_max, List_filtre_selected()\thread, mx, my, clic , 1)
        If res And mem <> res
          List_filtre_selected()\thread = res
          mem = res
          valider = 1
        EndIf     
        py + size
      Else
        List_filtre_selected()\thread = 4 ; active 4 threads par defaut
      EndIf
      
      ;-- option de l'affichage des parametres du language de programmation
      If GetGadgetState(#boutton_asm) 
        DrawText(option_px + 2, py + 3, "Language") ; Correction orthographe "Language"
        l1 = 240 / 4 : l2 = l1 - 8 : l3 = 0
        If get_language_max() = 4 : l3 = -20 : EndIf
        For j = 0 To get_language_max()
          pn = option_px + 200 + (j * l1) + l3
          txt$ = StringField("PB,SSE2,SSE4,AVX2,AVX512", j + 1, ",")
          ;opt = Bool(j = get_language())
          opt = Bool( j = List_filtre_selected()\langue)
          If draw_bouton(pn, py + 3, l2, 18, mx, my, clic, txt$, $ffffff, opt)
            List_filtre_selected()\langue = j
            set_language(j) : valider = 1
          EndIf
        Next
        py + size
      EndIf
      
      py + 4
    Next
  EndWith
  StopDrawing()
  ProcedureReturn valider
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
  If Window_SizeX < 800 : Window_SizeX = 800 : EndIf
  If Window_SizeY < 600 : Window_SizeY = 600 : EndIf
  ResizeWindow(0, #PB_Ignore , #PB_Ignore , Window_SizeX ,  Window_SizeY)
  
  ; redefinit la taille des miiature
  Miniature_taille = (Window_SizeY * 20) / 100 ; 20% 
  Miniature_px = 1 * Window_Sizex / 100
  Miniature_py = 1 * Window_SizeY / 100
  If IsImage(#img_source) : CopyImage(#img_source , #img_miniature_source) : ResizeImage(#img_miniature_source , Miniature_taille - 8, Miniature_taille - 8) : EndIf 
  If IsImage(#img_mix) : CopyImage(#img_mix , #img_miniature_mix) : ResizeImage(#img_miniature_mix , Miniature_taille - 8, Miniature_taille - 8) : EndIf
  If IsImage(#img_mask) : CopyImage(#img_mask , #img_miniature_mask) : ResizeImage(#img_miniature_mask , Miniature_taille - 8, Miniature_taille - 8) : EndIf
  ResizeGadget(#canvas_miniature_source, Miniature_px, Miniature_py + Miniature_taille * 0 + 00, Miniature_taille , Miniature_taille)
  ResizeGadget(#canvas_miniature_mix   , Miniature_px, Miniature_py + Miniature_taille * 1 + 10, Miniature_taille , Miniature_taille)
  ResizeGadget(#canvas_miniature_mask  , Miniature_px, Miniature_py + Miniature_taille * 2 + 20, Miniature_taille , Miniature_taille)
  update_miniature(image_selected)
  
  ; redefinit la taille de l'image de travail
  travail_tx = Window_SizeX  - ( 500 + Miniature_px + Miniature_taille + 30 ) ; 500 = taille du grame 1
  travail_ty = 640
  tx = Window_SizeX  - ( 500 + Miniature_px + Miniature_taille + 30 ) ; 500 = taille du grame 1
  ResizeGadget(#canvas_affichage, Miniature_px + Miniature_taille + 10, Miniature_py , travail_tx , travail_ty)
  If IsImage(image_selected) : CopyImage(image_selected , #img_aff) : ResizeImage(#img_aff , travail_tx , travail_ty) : EndIf
  update_image_aff()
  
  With entity
    \Window_lg = WindowWidth(0)
    \window_ht = WindowHeight(0)
    
    \frame1_lg = 500
    \frame1_px = \Window_lg - \frame1_lg - 5
    \frame1_py = 2
    \frame1_ht = \window_ht - 30
    ResizeGadget(#frame_filters, \frame1_px, \frame1_py, \frame1_lg, \frame1_ht)
    
    
    \frame2_lg = \frame1_lg - 10
    \frame2_ht = 110
    \frame2_px = \frame1_px + 5
    \frame2_py = \frame1_py + 5
    ResizeGadget(#frame_options, \frame2_px, \frame2_py, \frame2_lg, \frame2_ht)
    
    lg = 150
    \boutton_px[0] = \frame2_px + 5
    \boutton_py[0] = \frame2_py + 5
    \boutton_lg[0] = lg
    \boutton_ht[0] = 24
    ResizeGadget(#boutton_Appliquer_source, \boutton_px[0], \boutton_py[0], \boutton_lg[0], \boutton_ht[0])
    
    
    \boutton_px[1] = \boutton_px[0] + lg + 10
    \boutton_py[1] = \frame2_py + 5
    \boutton_lg[1] = lg
    \boutton_ht[1] = 24
    ResizeGadget(#boutton_Appliquer_mix, \boutton_px[1], \boutton_py[1], \boutton_lg[1], \boutton_ht[1])
    
    
    \boutton_px[2] = \boutton_px[1] + lg + 10
    \boutton_py[2] = \frame2_py + 5
    \boutton_lg[2] = lg
    \boutton_ht[2] = 24
    ResizeGadget(#boutton_Appliquer_mask, \boutton_px[2], \boutton_py[2], \boutton_lg[2], \boutton_ht[2])
    
    
    \boutton_px[3] = \frame2_px + 5
    \boutton_py[3] = \frame2_py + 5 + 25
    \boutton_lg[3] = lg
    \boutton_ht[3] = 24
    ResizeGadget(#boutton_Apercu, \boutton_px[3], \boutton_py[3], \boutton_lg[3], \boutton_ht[3])
    
    
    \boutton_px[4] = \frame2_px + 5 + 200
    \boutton_py[4] = \boutton_py[3] 
    \boutton_lg[4] = 200
    \boutton_ht[4] = 24
    ResizeGadget(#boutton_Auto_Rendu, \boutton_px[4], \boutton_py[4], \boutton_lg[4], \boutton_ht[4])
    
    \boutton_px[5] = \frame2_px + 5
    \boutton_py[5] = \boutton_py[3] + 25
    \boutton_lg[5] = lg
    \boutton_ht[5] = 24
    ResizeGadget(#boutton_mask, \boutton_px[5], \boutton_py[5], \boutton_lg[5], \boutton_ht[5])
    
    \boutton_px[6] = \boutton_px[0] + lg + 10
    \boutton_py[6] = \boutton_py[3] + 25
    \boutton_lg[6] = lg
    \boutton_ht[6] = 24
    ResizeGadget(#boutton_thread, \boutton_px[6], \boutton_py[6], \boutton_lg[6], \boutton_ht[6])
    
    \boutton_px[7] = \boutton_px[1] + lg + 10
    \boutton_py[7] = \boutton_py[3] + 25
    \boutton_lg[7] = lg
    \boutton_ht[7] = 24
    ResizeGadget(#boutton_asm , \boutton_px[7], \boutton_py[7], \boutton_lg[7], \boutton_ht[7])
    
    \boutton_px[8] = \boutton_px[0]
    \boutton_py[8] = \boutton_py[3] + 50
    \boutton_lg[8] = lg
    \boutton_ht[8] = 24
    ResizeGadget(#boutton_aide , \boutton_px[8], \boutton_py[8], \boutton_lg[8], \boutton_ht[8])
    
    \boutton_px[9] = \boutton_px[1] + lg + 10
    \boutton_py[9] = \boutton_py[3] + 50
    \boutton_lg[9] = lg
    \boutton_ht[9] = 24
    ResizeGadget(#boutton_fermer_filtre , \boutton_px[9], \boutton_py[9], \boutton_lg[9], \boutton_ht[9])
    
    StartDrawing(CanvasOutput(#canvas_option))
    Box(0,0,\canvas_lg , \canvas_ht , $ffffffff)
    StopDrawing()
    \canvas_px = \frame2_px
    \canvas_py = \frame2_py + \frame2_ht + 5
    \canvas_lg = \frame2_lg
    \canvas_ht = \frame1_ht - \frame2_ht - 15
    ResizeGadget(#canvas_option, \canvas_px , \canvas_py , \canvas_lg , \canvas_ht )
  EndWith
  update_filtre(0)
EndProcedure



;----------
;-- programme

ExamineDesktops()
Window_SizeX = DesktopWidth(0)
Window_SizeY = DesktopHeight(0)

; --- Calcul possition et taille des miniatures
Miniature_taille = (Window_SizeY * 20) / 100 ; 20% 
Miniature_px = 1 * Window_SizeY / 100
Miniature_py = 3 * Window_SizeY / 100
Miniature_decal = 1.5 * Window_SizeY / 100

If OpenWindow(0, 0, 0, 1920, 1080, "test_filtres", #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget | #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget)
  
  create_menu_part1()
  load_favori()
  create_menu_part2()
  FirstElement(filter_resize())
  resize_start = filter_resize()\id
  LastElement(filter_resize())
  resize_stop = filter_resize()\id
    
  CanvasGadget(#canvas_affichage, 0, 0, 1, 1 , 0) ; fentre d'affichage du rendu
  CanvasGadget(#canvas_miniature_source, 0, 0, 1, 1 , 0 )
  CanvasGadget(#canvas_miniature_mix, 0, 0, 1, 1 , 0 )
  CanvasGadget(#canvas_miniature_mask, 0, 0, 1, 1 , 0 )
  CanvasGadget(#canvas_option, 0, 0, 1, 1 , #PB_Canvas_Keyboard) ; fenetre des options
  
  resize_screen()
  
  ;-- boucle
  ;Repeat
  update_auto = 0
  Repeat
    validation = 0
    update = 0
    clic = 0
    Event = WindowEvent()
    mouseUp = #False
    If Event = #PB_Event_Gadget And EventGadget() = #canvas_option
      If EventType() = #PB_EventType_LeftButtonUp
        mouseUp = #True
      EndIf
    EndIf
    
    If event <> 0  Or valider_loop
      ;If (WindowWidth(0) <> Window_SizeX) Or (WindowHeight(0) <> Window_SizeY) : resize_screen() : EndIf
      
      Select Event
          
        Case #PB_Event_CloseWindow
          fenetreActive = EventWindow()
          Debug fenetreActive
          If fenetreActive = 0
            quit = 1
          Else
            CloseWindow(fenetreActive)
          EndIf
          
        Case #PB_Event_SizeWindow
          resize_screen()
          
          ;-- gestion des options du menu
        Case #PB_Event_Menu
          var = EventMenu()
          Select var
              
            Case #Menu_load_Source : load_img(#img_source)      
            Case #Menu_load_Mix    : load_img(#img_mix)
            Case #Menu_load_Mask   : load_img(#img_mask)
              
            ; ajoute un filtre 
            Case #filtre_pos To (#filtre_pos + 500)
              pos = (var - #filtre_pos)
              SelectElement(list_filtre(), pos)
              add_filtre(pos)
              validation = update_filtre(0)
              
            Case #save_bmp1 To #save_clipboard4
              var1 = var - #save_bmp1 
              var2 = (var1 & %1100)>> 2 ; var2 = l'image a sauvegarder
              var1 = var1 & % 11        ; var1 = le type de sauvegarde ( jpg , bmp ...)
              Select var2
                Case 0 : img_save = #img_source
                Case 1 : img_save = #img_mix 
                Case 2 : img_save = #img_mask
                Case 3 : img_save = #img_tempo_cible
              EndSelect
              If IsImage(img_save)
                
                Select var1
                  Case 0
                    nom$ = SaveFileRequester("Save", "", "", 0)
                    If nom$ <> "" : SaveImage(img_save, nom$+".bmp" ,#PB_ImagePlugin_BMP )
                    Else
                      MessageRequester("erreur" , "nom de fichier incorrecte" , #PB_MessageRequester_Warning)
                    EndIf
                  Case 1
                    nom$ = SaveFileRequester("Save", "", "", 0)
                    If nom$ <> "" : SaveImage(img_save, nom$+".jpg" ,#PB_ImagePlugin_JPEG )
                    Else
                      MessageRequester("erreur" , "nom de fichier incorrecte" , #PB_MessageRequester_Warning)
                    EndIf
                  Case 2
                    nom$ = SaveFileRequester("Save", "", "", 0)
                    If nom$ <> "" : SaveImage(img_save, nom$+".png" ,#PB_ImagePlugin_PNG )
                    Else
                      MessageRequester("erreur" , "nom de fichier incorrecte" , #PB_MessageRequester_Warning)
                    EndIf
                  Case 3
                    SetClipboardImage(img_save)
                EndSelect
                
              Else
                MessageRequester("erreur" , "pas d'image" , #PB_MessageRequester_Warning)
              EndIf
          
              
            Case #menu_favori_trier_name , #menu_favori_trier_id , #menu_favori_trier_type
              If ListSize(favori()) > 1
                Select var
                  Case #menu_favori_trier_name : SortStructuredList(favori(), #PB_Sort_Ascending, OffsetOf(favori_data\name), #PB_String) 
                  Case  #menu_favori_trier_id  : SortStructuredList(favori(), #PB_Sort_Ascending, OffsetOf(favori_data\id), #PB_Long) 
                  Case #menu_favori_trier_type : SortStructuredList(favori(), #PB_Sort_Ascending, OffsetOf(favori_data\typ), #PB_Long)
                EndSelect
                update_favori()
              EndIf
              
            
            Case #filtre_pos_sup To (#filtre_pos_sup +  999)
              er = 0
              ForEach favori()
                If favori()\id = (var - #filtre_pos_sup)
                  DeleteElement(favori())
                  er = 1
                  Break
                EndIf
              Next
              If er = 1 : update_favori() : EndIf
              
            ; filtre resize
            Case resize_start To resize_stop
              Select image_selected
                  Case 0 : If IsImage(#img_tempo_cible) : CopyImage(#img_tempo_cible , #img_tempo_source) : EndIf
                  Case 1 : If IsImage(#img_source) : CopyImage(#img_source , #img_tempo_source) : EndIf
                  Case 2 : If IsImage(#img_mix)    : CopyImage(#img_mix    , #img_tempo_source) : EndIf
                  Case 3 : If IsImage(#img_mask)   : CopyImage(#img_mask   , #img_tempo_source) : EndIf
              EndSelect
              
              If IsImage(#img_tempo_source) = 0 
                If IsImage(#img_source) : CopyImage(#img_source , #img_tempo_source) : EndIf
              EndIf
              
              If IsImage(#img_tempo_source)
                
                Clear_Data_Filter(FilterCtx)
                FilterCtx\info_active = 1
                If tabfunc(var) <> 0 : CallFunctionFast(tabfunc(var),FilterCtx) : EndIf
                FilterCtx\info_active = 0
                If image_selected = 0 : update_miniature(1 , $ff) : Else : update_miniature(image_selected , $ff) : EndIf
                
                Select FilterCtx\name
                  Case "resize2xSaI" , "ResizeAdvMAME2x" , "ResizeHq2x" , "ResizeScale2x" , "ResizeXBRZ2x"
                    CreateImage(#img_tempo_cible , ImageWidth(#img_tempo_source) * 2 , ImageHeight(#img_tempo_source) * 2 , 32) 
                  Case "ResizeHq3x" , "ResizeXBRZ3x"
                    CreateImage(#img_tempo_cible , ImageWidth(#img_tempo_source) * 3 , ImageHeight(#img_tempo_source) * 3 , 32)
                  Case "ResizeHq4x" , "ResizeXBRZ4x"
                    CreateImage(#img_tempo_cible , ImageWidth(#img_tempo_source) * 4 , ImageHeight(#img_tempo_source) * 4 , 32)
                  Case "ResizeXBRZ5x"
                    CreateImage(#img_tempo_cible , ImageWidth(#img_tempo_source) * 5 , ImageHeight(#img_tempo_source) * 5 , 32)
                  Case "ResizeXBRZ6x"
                    CreateImage(#img_tempo_cible , ImageWidth(#img_tempo_source) * 6 , ImageHeight(#img_tempo_source) * 6 , 32)
                EndSelect
                
                      
                
                set_Source(#img_tempo_source)
                set_cible(#img_tempo_cible)
           
                t = ElapsedMilliseconds()
                ;For i = 0 To 19 : FilterCtx\option[i] = list_filtre_selected()\opt(i,2) : Next
                If tabfunc(var) <> 0 : CallFunctionFast(tabfunc(var),FilterCtx) : EndIf
                t = ElapsedMilliseconds() - t
                
                SetWindowTitle(0, "test_filtres : "+Str(t) ) 
                update_miniature(image_selected , $ff00)
                
                CopyImage(#img_tempo_cible , #img_aff)
                ResizeImage(#img_aff , travail_tx , travail_ty , #PB_Image_Raw)
                StartDrawing(CanvasOutput(#canvas_affichage))
                DrawImage(ImageID(#img_aff), 0, 0)
                StopDrawing()
              EndIf
              
            Case #info_image
              t$ = "source : "
              If IsImage(#img_source)
                lg = ImageWidth(#img_source)
                ht = ImageHeight(#img_source)
                t$ = t$ + Str(lg) + " x " + Str(ht) + Chr(13)
              EndIf
              
              t$ = t$ + Chr(13) + "mixage : "
              If IsImage(#img_mix)
                lg = ImageWidth(#img_mix)
                ht = ImageHeight(#img_mix)
                t$ = t$ + Str(lg) + " x " + Str(ht) + Chr(13)
              EndIf
              
              t$ = t$ + Chr(13) + "masque : "
              If IsImage(#img_mask)
                lg = ImageWidth(#img_mask)
                ht = ImageHeight(#img_mask)
                t$ = t$ + Str(lg) + " x " + Str(ht) + Chr(13)
              EndIf
              
              t$ = t$ + Chr(13) + "travail : "
              If IsImage(#img_tempo_cible)
                lg = ImageWidth(#img_tempo_cible)
                ht = ImageHeight(#img_tempo_cible)
                t$ = t$ + Str(lg) + " x " + Str(ht) + Chr(13)
              EndIf
              
              MessageRequester("Info Image" , t$  , #PB_MessageRequester_Ok)
              
            Case #info_cpu
              t$ = ""
              var = DetectCPU()
              
              Select var
                Case $02000000  : t$ = "SSE2"
                Case $00000001  : t$ = "SSE3"
                Case $00000200  : t$ = "SSSE3"
                Case $00080000  : t$ = "SSE41"
                Case $00100000  : t$ = "SSE42"
                Case $10000000  : t$ = "AVX"
                Case $00000020  : t$ = "AVX2"
                Case $00010000  : t$ = "AVX512"
              EndSelect
              MessageRequester("Info CPU" , t$  , #PB_MessageRequester_Ok)
              
            Case #quit
              quit = 1
          EndSelect
          
        Case #PB_Event_Gadget
          
          Select EventGadget()
            Case #boutton_Appliquer_source
              If IsImage(#img_tempo_cible) : CopyImage(#img_tempo_cible, #img_source) : resize_screen() : EndIf
            Case #boutton_Appliquer_mix
              If IsImage(#img_tempo_cible) : CopyImage(#img_tempo_cible, #img_mix)    : resize_screen() : EndIf
            Case #boutton_Appliquer_mask
              If IsImage(#img_tempo_cible) : CopyImage(#img_tempo_cible, #img_mask)   : resize_screen() : EndIf
            Case #boutton_Apercu
              update = 1
            
            Case #boutton_Auto_Rendu
              update_auto = GetGadgetState(#boutton_Auto_Rendu)
              If update_auto
                SetGadgetText(#boutton_Auto_Rendu , "Auto_Rendu : On")
              Else
                SetGadgetText(#boutton_Auto_Rendu , "Auto_Rendu : Off")
              EndIf
              
            Case #boutton_thread
              update_auto_thread = GetGadgetState(#boutton_thread)
              If update_auto_thread
                SetGadgetText(#boutton_thread , "affiche -> thread : On")
              Else
                SetGadgetText(#boutton_thread , "affiche -> thread : Off")
              EndIf
              update_filtre(0)
              
            Case #boutton_mask
              update_auto_thread = GetGadgetState(#boutton_mask)
              If update_auto_thread
                SetGadgetText(#boutton_mask , "afficher -> masque : On")
              Else
                SetGadgetText(#boutton_mask , "afficher -> masque : Off")
              EndIf
              update_filtre(0)
              
            Case #boutton_asm
              update_auto_thread = GetGadgetState(#boutton_asm)
              If update_auto_thread
                SetGadgetText(#boutton_asm , "affiche -> language : On")
              Else
                SetGadgetText(#boutton_asm , "affiche -> language : Off")
              EndIf
              update_filtre(0)    
              
            Case #boutton_fermer_filtre
              update_filtre(10) ; 10 => fermer tous les filtres
              
            Case #boutton_aide
              affiche_info_aide()
              
            Case #canvas_option ; fenetre des filtres graphiques
              clic = 0
              Select EventType()
                Case #PB_EventType_LeftButtonDown
                  clic = 1
                  SetActiveGadget(#canvas_option)
                Case #PB_EventType_LeftButtonUp
                  mouseUp = #True
              EndSelect
              
              If EventType() = #PB_EventType_LeftButtonDown
                SetActiveGadget(#canvas_option)
              EndIf
              
              If EventType() = #PB_EventType_LeftButtonDown 
                clic = 1 
                SetActiveGadget(#canvas_option) ; Indispensable pour le clavier
              EndIf
              
              ; --- 2. GESTION DU CLAVIER (Si focus matrice actif) --- convolution
              If mat_focus_id <> -1
                
                ; Capture des caractères (chiffres et point/virgule)
                If EventType() = #PB_EventType_Input
                  char$ = Chr(GetGadgetAttribute(#canvas_option, #PB_Canvas_Input))
                  ;current_val.f = List_filtre_selected()\opt(10 + mat_focus_id, 2)
                  current_val.f = List_filtre_selected()\convol7[mat_focus_id]
                  s_val$ = StrF(current_val, 0)
                  
                  If char$ >= "0" And char$ <= "9"
                    If s_val$ = "0" : s_val$ = "" : EndIf
                    If Len(s_val$) < 3
                      ;List_filtre_selected()\opt(10 + mat_focus_id, 2) = ValF(s_val$ + char$)
                      List_filtre_selected()\convol7[mat_focus_id] = ValF(s_val$ + char$)
                      validation = 1
                    EndIf
                  ElseIf char$ = "." Or char$ = ","
                    ; Optionnel : gestion des flottants si votre matrice le supporte
                  EndIf
                EndIf
                
                ; Capture des touches de contrôle (Signe moins, Delete, Back)
                If EventType() = #PB_EventType_KeyDown
                  key = GetGadgetAttribute(#canvas_option, #PB_Canvas_Key)
                  Select key
                    Case #PB_Shortcut_Subtract
                      ; Inverse le signe de la valeur actuelle
                      List_filtre_selected()\convol7[mat_focus_id] * -1
                      validation = 1
                    Case #PB_Shortcut_Back, #PB_Shortcut_Delete
                      List_filtre_selected()\convol7[mat_focus_id] = 0
                      validation = 1
                    Case #PB_Shortcut_Return, #PB_Shortcut_Tab
                      nb = 9 : If opt_boutton > 0 : nb = opt_boutton * opt_boutton : EndIf
                      mat_focus_id = (mat_focus_id + 1) % nb
                      validation = 1
                  EndSelect
                EndIf
              EndIf
              
              ; --- 3. MISE À JOUR GRAPHIQUE DES FILTRES ---
              
              If validation = 1
                update_filtre(clic)
              Else
                validation = update_filtre(clic)
              EndIf
              
                
            Case #canvas_miniature_source
              If GetGadgetAttribute(#canvas_miniature_source, #PB_Canvas_Buttons) = #PB_Canvas_LeftButton : image_selected = update_miniature(1) : update_image_aff() : EndIf
            Case #canvas_miniature_mix
              If GetGadgetAttribute(#canvas_miniature_mix   , #PB_Canvas_Buttons) = #PB_Canvas_LeftButton : image_selected = update_miniature(2) : update_image_aff() : EndIf
            Case #canvas_miniature_mask
              If GetGadgetAttribute(#canvas_miniature_mask  , #PB_Canvas_Buttons) = #PB_Canvas_LeftButton : image_selected = update_miniature(3) : update_image_aff() : EndIf 
              ; on selectionne le zone de travail
            Case #canvas_affichage
              If GetGadgetAttribute(#canvas_affichage, #PB_Canvas_Buttons) = #PB_Canvas_LeftButton  : image_selected = update_miniature(0) : EndIf
              
              ; Gestion des miniatures
            Case #canvas_miniature_source To #canvas_miniature_mask
              If EventType() = #PB_EventType_LeftButtonDown
                idx = EventGadget() - #canvas_miniature_source + 1
                image_selected = update_miniature(idx)
                update_image_aff()
              EndIf
                
            EndSelect
            
        EndSelect
        
        
        If update Or (update_auto And validation) Or valider_loop
          With FilterCtx
            Clear_Data_Filter(FilterCtx)
            
            Select image_selected
                Case 1 : If IsImage(#img_source) : CopyImage(#img_source , #img_tempo_source) : EndIf
                Case 2 : If IsImage(#img_mix)    : CopyImage(#img_mix    , #img_tempo_source) : EndIf
                Case 3 : If IsImage(#img_mask)   : CopyImage(#img_mask   , #img_tempo_source) : EndIf
            EndSelect
            
            If IsImage(#img_tempo_source)
              CopyImage(#img_tempo_source , #img_tempo_cible)
              set_Source(#img_tempo_source)
              set_cible(#img_tempo_cible)
              set_mix(#img_mix)
              set_mask(#img_mask)
              If list_filtre_selected()\thread < 1 : list_filtre_selected()\thread = 1 : EndIf
              set_thread(list_filtre_selected()\thread)
              update_miniature(image_selected , $ff)
              t = ElapsedMilliseconds()
              ForEach list_filtre_selected()
                For i = 0 To 19 : \option[i] = list_filtre_selected()\opt(i,2) : Next
                For i = 0 To 48 : \convol7[i] = list_filtre_selected()\convol7[i] : Next
                If tabfunc(list_filtre_selected()\id) <> 0 : CallFunctionFast(tabfunc(list_filtre_selected()\id),FilterCtx) : EndIf
                \image[0] = \image[1]
              Next
              t = ElapsedMilliseconds() - t
              SetWindowTitle(0, "test_filtres : "+Str(t) ) 
              update_miniature(image_selected , $ff00)
            EndIf
          EndWith
          
          
          If IsImage(#img_tempo_cible)
            CopyImage(#img_tempo_cible , #img_aff)
            ResizeImage(#img_aff , travail_tx , travail_ty , #PB_Image_Raw)
            StartDrawing(CanvasOutput(#canvas_affichage))
            DrawImage(ImageID(#img_aff), 0, 0)
            StopDrawing()
            ;FreeImage(#img_tempo_cible)
          EndIf
        EndIf
        
      EndIf
      Delay(1)
    Until quit = 1
    ;If IsImage(#cible) : FreeImage(#cible) : EndIf
    ;If IsImage(#Black_image) : FreeImage(#Black_image) : EndIf
    CloseWindow(0)
    ;XnViewLoader::Free()
  EndIf
  
  

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 1467
; FirstLine = 1445
; Folding = -----
; EnableThread
; EnableXP
; CPU = 5
; Compiler = PureBasic 6.40 (Windows - x64)