;-------------------------------------------------------------------------------
; FlipV_MT - Thread de traitement pour le retournement vertical
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres contenant:
;                  - lg: largeur de l'image en pixels
;                  - ht: hauteur de l'image en pixels
;                  - addr[0]: pointeur vers l'image source
;                  - addr[1]: pointeur vers l'image destination
;                  - thread_pos: position de ce thread (0 à thread_max-1)
;                  - thread_max: nombre total de threads
;
; Description:
;   Effectue un retournement vertical (haut/bas) de l'image.
;   La ligne y est copiée vers la position (ht - 1 - y).
;   Chaque thread traite une portion des lignes pour paralléliser le calcul.
;
; Optimisations:
;   - Copie complète de ligne avec CopyMemory (très rapide)
;   - Précalcul de y1 pour éviter les recalculs
;   - Typage explicite des variables pour de meilleures performances
;-------------------------------------------------------------------------------
Procedure FlipV_MT(*p.parametre)
  Protected start.i, stop.i
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht
  Protected y0.i, y1.i
  Protected ligne_source.i, ligne_dest.i
  Protected taille_ligne.i
  
  ; Calcul de la portion de lignes à traiter par ce thread
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  
  ; Sécurité : ne pas dépasser la dernière ligne
  If stop > ht - 1
    stop = ht - 1
  EndIf
  
  ; Précalcul de la taille d'une ligne en octets (optimisation)
  taille_ligne = lg * 4
  
  ; Copier chaque ligne vers sa position miroir
  For y0 = start To stop
    ; Calculer la position miroir de la ligne
    y1 = ht - y0 - 1
    
    ; Précalculer les adresses pour plus de clarté
    ligne_source = *p\addr[0] + y0 * taille_ligne
    ligne_dest   = *p\addr[1] + y1 * taille_ligne
    
    ; Copier toute la ligne d'un coup (très efficace)
    CopyMemory(ligne_source, ligne_dest, taille_ligne)
  Next y0
EndProcedure

;-------------------------------------------------------------------------------
; FlipV - Filtre de retournement vertical
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Point d'entrée du filtre FlipV. En mode info, définit les métadonnées.
;   En mode traitement, lance le processus multi-threadé.
;
; Configuration:
;   - Type: Déformation géométrique
;   - Nécessite 2 buffers (source et destination)
;   - Thread-safe, multi-threadé automatiquement par filter_start()
;-------------------------------------------------------------------------------
Procedure FlipV(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0
    *param\name = "FlipV (Miroir vertical)"
    *param\remarque = "Inverse l'image verticalement (haut/bas)"
    *param\info[0] = "Retournement vertical"
    
    ; Configuration: 0 paramètres, 2 buffers (source+dest), 0 buffer supplémentaire
    *param\info_data(0, 0) = 0 : *param\info_data(0, 1) = 2 : *param\info_data(0, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-threadé
  filter_start(@FlipV_MT(), 0, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 54
; FirstLine = 13
; Folding = -
; EnableXP
; DPIAware