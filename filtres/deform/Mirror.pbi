; -------------------------------------------------------------------------------
; Mirror_MT - Effet miroir avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: axe de symétrie (0=vertical, 1=horizontal, 2=diagonal /, 3=diagonal \)
;                  - option[1]: position de l'axe (0-100%, 50=centre)
;                  - option[2]: côté à conserver (0=gauche/haut, 1=droite/bas, 2=mixte)
;                  - option[3]: fondu à l'axe (0-100, 0=net, 100=fondu progressif)
;
; Description:
;   Applique un effet miroir selon différents axes de symétrie.
;   Peut créer des symétries verticales, horizontales ou diagonales.
;   Le côté conservé est reflété de l'autre côté de l'axe.
;
; Optimisations:
;   - Précalcul de la position de l'axe
;   - Sélection optimisée du mode de symétrie
;   - Utilisation d'offsets directs pour accès mémoire
;   - Calcul incrémental des offsets destination
; -------------------------------------------------------------------------------
Procedure Mirror_MT(*p.parametre)
  Protected x.i, y.i
  Protected src_x.i, src_y.i
  Protected mirror_pos.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Type d'axe de symétrie
  Protected axis_type.i = *p\option[0]  ; 0=vert, 1=horiz, 2=diag/, 3=diag\

  ; Position de l'axe (0-100%)
  Protected axis_position.f = *p\option[1] / 100.0

  ; Côté à conserver (0=gauche/haut, 1=droite/bas, 2=mixte)
  Protected keep_side.i = *p\option[2]

  ; Fondu à l'axe (0-100)
  Protected fade_amount.f = *p\option[3] / 100.0

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected distance_to_axis.f, fade_factor.f, max_distance.f
  Protected pixel_src.l, pixel_mirror.l
  Protected r1.i, g1.i, b1.i, a1.i
  Protected r2.i, g2.i, b2.i, a2.i
  Protected r.i, g.i, b.i, a.i

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      
      ; Sélection de l'axe de symétrie
      Select axis_type
        Case 0  ; ===== Axe vertical =====
          mirror_pos = Int(axis_position * lg)
          
          If keep_side = 0  ; Conserver gauche
            If x < mirror_pos
              src_x = x
            Else
              src_x = 2 * mirror_pos - x
            EndIf
            src_y = y
            
          ElseIf keep_side = 1  ; Conserver droite
            If x > mirror_pos
              src_x = x
            Else
              src_x = 2 * mirror_pos - x
            EndIf
            src_y = y
            
          Else  ; Mode mixte (fondu)
            distance_to_axis = Abs(x - mirror_pos)
            max_distance = mirror_pos
            
            ; Pixel du côté gauche
            src_x = x
            src_y = y
            
          EndIf
          
        Case 1  ; ===== Axe horizontal =====
          mirror_pos = Int(axis_position * ht)
          
          If keep_side = 0  ; Conserver haut
            src_x = x
            If y < mirror_pos
              src_y = y
            Else
              src_y = 2 * mirror_pos - y
            EndIf
            
          ElseIf keep_side = 1  ; Conserver bas
            src_x = x
            If y > mirror_pos
              src_y = y
            Else
              src_y = 2 * mirror_pos - y
            EndIf
            
          Else  ; Mode mixte
            distance_to_axis = Abs(y - mirror_pos)
            max_distance = mirror_pos
            src_x = x
            src_y = y
            
          EndIf
          
        Case 2  ; ===== Diagonale / (bas-gauche vers haut-droite) =====
          ; Symétrie par rapport à la diagonale principale
          If keep_side = 0
            ; Au-dessus de la diagonale : garder original
            ; En-dessous : symétrie
            If y < x
              src_x = x
              src_y = y
            Else
              src_x = y
              src_y = x
            EndIf
          Else
            ; Inverse
            If y > x
              src_x = x
              src_y = y
            Else
              src_x = y
              src_y = x
            EndIf
          EndIf
          
        Case 3  ; ===== Diagonale \ (haut-gauche vers bas-droite) =====
          ; Symétrie par rapport à la diagonale secondaire
          If keep_side = 0
            If y < (ht - x)
              src_x = x
              src_y = y
            Else
              src_x = ht - y
              src_y = lg - x
            EndIf
          Else
            If y > (ht - x)
              src_x = x
              src_y = y
            Else
              src_x = ht - y
              src_y = lg - x
            EndIf
          EndIf
          
      EndSelect

      ; Vérification des limites et échantillonnage
      If src_x >= 0 And src_x < lg And src_y >= 0 And src_y < ht
        offset_src = (src_y * lg + src_x) * 4
        
        ; Mode mixte avec fondu
        If keep_side = 2 And (axis_type = 0 Or axis_type = 1) And fade_amount > 0
          ; Calculer le pixel miroir
          If axis_type = 0  ; Vertical
            Protected mirror_x.i = 2 * mirror_pos - x
            If mirror_x >= 0 And mirror_x < lg
              Protected offset_mirror.i = (y * lg + mirror_x) * 4
              pixel_src = PeekL(*source + offset_src)
              pixel_mirror = PeekL(*source + offset_mirror)
              
              ; Calcul du facteur de fondu
              fade_factor = (distance_to_axis / max_distance) * fade_amount
              fade_factor = 1.0 - fade_factor
              If fade_factor < 0 : fade_factor = 0 : EndIf
              If fade_factor > 1 : fade_factor = 1 : EndIf
              
              ; Décomposition et mélange des couleurs
              r1 = (pixel_src >> 16) & $FF
              g1 = (pixel_src >> 8) & $FF
              b1 = pixel_src & $FF
              a1 = (pixel_src >> 24) & $FF
              
              r2 = (pixel_mirror >> 16) & $FF
              g2 = (pixel_mirror >> 8) & $FF
              b2 = pixel_mirror & $FF
              a2 = (pixel_mirror >> 24) & $FF
              
              r = r1 * fade_factor + r2 * (1.0 - fade_factor)
              g = g1 * fade_factor + g2 * (1.0 - fade_factor)
              b = b1 * fade_factor + b2 * (1.0 - fade_factor)
              a = a1 * fade_factor + a2 * (1.0 - fade_factor)
              
              PokeL(*cible + offset_dst, (a << 24) | (r << 16) | (g << 8) | b)
            Else
              PokeL(*cible + offset_dst, PeekL(*source + offset_src))
            EndIf
          ElseIf axis_type = 1  ; Horizontal
            Protected mirror_y.i = 2 * mirror_pos - y
            If mirror_y >= 0 And mirror_y < ht
              offset_mirror = (mirror_y * lg + x) * 4
              pixel_src = PeekL(*source + offset_src)
              pixel_mirror = PeekL(*source + offset_mirror)
              
              fade_factor = (distance_to_axis / max_distance) * fade_amount
              fade_factor = 1.0 - fade_factor
              If fade_factor < 0 : fade_factor = 0 : EndIf
              If fade_factor > 1 : fade_factor = 1 : EndIf
              
              r1 = (pixel_src >> 16) & $FF
              g1 = (pixel_src >> 8) & $FF
              b1 = pixel_src & $FF
              a1 = (pixel_src >> 24) & $FF
              
              r2 = (pixel_mirror >> 16) & $FF
              g2 = (pixel_mirror >> 8) & $FF
              b2 = pixel_mirror & $FF
              a2 = (pixel_mirror >> 24) & $FF
              
              r = r1 * fade_factor + r2 * (1.0 - fade_factor)
              g = g1 * fade_factor + g2 * (1.0 - fade_factor)
              b = b1 * fade_factor + b2 * (1.0 - fade_factor)
              a = a1 * fade_factor + a2 * (1.0 - fade_factor)
              
              PokeL(*cible + offset_dst, (a << 24) | (r << 16) | (g << 8) | b)
            Else
              PokeL(*cible + offset_dst, PeekL(*source + offset_src))
            EndIf
          EndIf
        Else
          ; Mode simple sans fondu
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        EndIf
      Else
        ; Pixel hors limites = noir transparent
        PokeL(*cible + offset_dst, $00000000)
      EndIf

      offset_dst + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; Mirror - Filtre effet miroir (symétrie)
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Crée un effet miroir selon différents axes de symétrie.
;   Permet de créer des images parfaitement symétriques en reflétant
;   une moitié de l'image de l'autre côté d'un axe.
;
; Paramètres utilisateur:
;   [0] Axe de symétrie (0-3, défaut=0)
;       0 : Vertical (miroir gauche-droite) |
;       1 : Horizontal (miroir haut-bas) ―
;       2 : Diagonal / (bas-gauche vers haut-droite)
;       3 : Diagonal \ (haut-gauche vers bas-droite)
;   [1] Position de l'axe (0-100%, défaut=50% = centre)
;       Déplace l'axe de symétrie (0=bord gauche/haut, 100=bord droit/bas)
;   [2] Côté à conserver (0-2, défaut=0)
;       0 : Gauche/Haut - réfléchit le côté gauche/haut vers la droite/bas
;       1 : Droite/Bas - réfléchit le côté droit/bas vers la gauche/haut
;       2 : Mixte - crée un fondu entre les deux côtés
;   [3] Fondu à l'axe (0-100, défaut=0)
;       0   : Transition nette à l'axe
;       50  : Fondu progressif modéré
;       100 : Fondu très progressif (effet de mélange étendu)
;       Note: Fonctionne uniquement en mode mixte (côté=2) pour axes vert/horiz
;
; Utilisations:
;   - Création de visages/objets parfaitement symétriques
;   - Effets artistiques de réflexion
;   - Correction de symétrie faciale
;   - Création de motifs décoratifs
;   - Effets de reflet dans l'eau (horizontal)
;   - Kaleidoscope simple (2 miroirs)
;
; Exemples créatifs:
;   Portrait symétrique:
;     Axe=0 (vertical), Position=50%, Côté=0
;     → Visage parfaitement symétrique
;   
;   Reflet dans l'eau:
;     Axe=1 (horizontal), Position=70%, Côté=0, Fondu=30
;     → Effet de surface d'eau avec reflet
;   
;   Effet kaléidoscope simple:
;     Appliquer 2 fois : vertical puis horizontal
;     → Symétrie quadruple
;
; Note: Différent de FlipH/FlipV qui retournent toute l'image,
; Mirror crée une vraie symétrie en dupliquant un côté.
; -------------------------------------------------------------------------------
Procedure Mirror(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Mirror (Symétrie)"
    *param\remarque = "Effet miroir avec symétrie verticale, horizontale ou diagonale"
    
    *param\info[0] = "Axe (0=vert |, 1=horiz ―, 2=diag /, 3=diag \)"
    *param\info[1] = "Position axe (% image)"
    *param\info[2] = "Côté (0=gauche/haut, 1=droite/bas, 2=mixte)"
    *param\info[3] = "Fondu (0=net, 100=progressif)"
    *param\info[4] = "masque"
    
    ; Configuration axe (0-3, défaut 0 = vertical)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 3
    *param\info_data(0, 2) = 0
    
    ; Configuration position (0-100%, défaut 50% = centre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Configuration côté (0-2, défaut 0 = gauche/haut)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 2
    *param\info_data(2, 2) = 0
    
    ; Configuration fondu (0-100, défaut 0 = net)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 100
    *param\info_data(3, 2) = 0
    
    ; Configuration du masque
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 2
    *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (4 paramètres, 1 buffer destination)
  filter_start(@Mirror_MT(), 4, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 304
; FirstLine = 281
; Folding = -
; EnableXP
; DPIAware