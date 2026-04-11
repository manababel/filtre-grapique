; -------------------------------------------------------------------------------
; Tile_MT - Effet de pixelisation/mosaïque avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: nombre de tuiles horizontales (1-100)
;                  - option[1]: nombre de tuiles verticales (1-100)
;
; Description:
;   Crée un effet de pixelisation en divisant l'image en tuiles.
;   Chaque tuile affiche un pixel agrandi de l'image source, créant
;   un effet de "gros pixels" ou mosaïque.
;
; Optimisations:
;   - Précalcul de la taille des tuiles
;   - Calcul direct de l'index du pixel source
;   - Utilisation d'offsets directs pour accès mémoire
;   - Minimisation des calculs dans la boucle interne
; -------------------------------------------------------------------------------
Procedure Tile_MT(*p.parametre)
  Protected x.i, y.i
  Protected tile_x.i, tile_y.i
  Protected src_x.i, src_y.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Récupération du nombre de tuiles avec protection minimale
  Protected tilesX.i = *p\option[0]
  Protected tilesY.i = *p\option[1]
  
  ; Protection contre division par zéro
  If tilesX < 1 : tilesX = 1 : EndIf
  If tilesY < 1 : tilesY = 1 : EndIf

  ; Précalcul de la taille de chaque tuile en pixels
  Protected tile_width.f = lg / tilesX
  Protected tile_height.f = ht / tilesY

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected pixel_color.l

  ; Traitement pixel par pixel
  For y = startY To stopY
    ; Calcul de l'index de la tuile verticale
    tile_y = Int(y / tile_height)
    If tile_y >= tilesY : tile_y = tilesY - 1 : EndIf
    
    ; Position Y dans l'image source (centre de la tuile)
    src_y = tile_y * ht / tilesY + (ht / tilesY / 2)
    If src_y >= ht : src_y = ht - 1 : EndIf
    
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Calcul de l'index de la tuile horizontale
      tile_x = Int(x / tile_width)
      If tile_x >= tilesX : tile_x = tilesX - 1 : EndIf
      
      ; Position X dans l'image source (centre de la tuile)
      src_x = tile_x * lg / tilesX + (lg / tilesX / 2)
      If src_x >= lg : src_x = lg - 1 : EndIf

      ; Échantillonnage du pixel source et copie dans toute la tuile
      offset_src = (src_y * lg + src_x) * 4
      PokeL(*cible + offset_dst, PeekL(*source + offset_src))

      offset_dst + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; Tile - Filtre de pixelisation/mosaïque
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Crée un effet de pixelisation en divisant l'image en tuiles rectangulaires.
;   Chaque tuile affiche un seul pixel agrandi, créant un effet de "gros pixels"
;   ou mosaïque. Plus le nombre de tuiles est faible, plus les pixels sont gros.
;
; Paramètres utilisateur:
;   [0] Nombre de tuiles horizontales (1-100, défaut=10)
;       Valeurs faibles = gros pixels, valeurs élevées = petits pixels
;   [1] Nombre de tuiles verticales (1-100, défaut=10)
;       Valeurs faibles = gros pixels, valeurs élevées = petits pixels
;
; Utilisations:
;   - Effet de pixelisation/mosaïque
;   - Style rétro 8-bit/16-bit
;   - Censure/anonymisation de zones
;   - Effet artistique low-poly
; -------------------------------------------------------------------------------
Procedure Tile(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Tile (Pixelisation)"
    *param\remarque = "Effet de pixelisation avec gros pixels (mosaïque)"
    
    *param\info[0] = "Tuiles horizontales (moins = plus gros pixels)"
    *param\info[1] = "Tuiles verticales (moins = plus gros pixels)"
    *param\info[2] = "masque"
    
    ; Configuration tuiles horizontales (1-100, défaut 10)
    *param\info_data(0, 0) = 1
    *param\info_data(0, 1) = 100
    *param\info_data(0, 2) = 10
    
    ; Configuration tuiles verticales (1-100, défaut 10)
    *param\info_data(1, 0) = 1
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 10
    
    ; Configuration du masque
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 2
    *param\info_data(2, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (2 paramètres, 1 buffer destination)
  filter_start(@Tile_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 136
; FirstLine = 67
; Folding = -
; EnableXP
; DPIAware