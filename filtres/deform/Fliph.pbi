;-------------------------------------------------------------------------------
; FlipH_MT - Thread de traitement pour le retournement horizontal (miroir)
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
;   Effectue un retournement horizontal (effet miroir) de l'image.
;   Chaque pixel à la position x est copié vers la position (lg - 1 - x).
;   Chaque thread traite une portion des lignes pour paralléliser le calcul.
;
; Optimisations:
;   - Parcours optimisé en sens inverse pour éviter les calculs redondants
;   - Précalcul des adresses de lignes pour réduire les calculs répétitifs
;   - Variables protégées pour la sécurité multi-thread
;   - Version optimisée utilisant un parcours en sens inverse
;   - Évite le calcul de (lg - 1 - x) à chaque itération
;-------------------------------------------------------------------------------
Procedure FlipH_MT(*p.parametre)
  Protected start.i, stop.i
  Protected pix.l
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht
  Protected x.i, y.i, x_miroir.i
  Protected ligne_source.i, ligne_cible.i
  
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    ligne_source = *p\addr[0] + y * lg * 4
    ligne_cible  = *p\addr[1] + y * lg * 4
    ; Parcours optimisé : x_miroir décrémente au lieu de calculer (lg - 1 - x)
    x_miroir = lg - 1
    For x = 0 To lg - 1
      pix = PeekL(ligne_source + x * 4)
      PokeL(ligne_cible + x_miroir * 4, pix)
      x_miroir - 1  ; Décrémentation au lieu de calcul
    Next x
  Next y
EndProcedure

;-------------------------------------------------------------------------------
; FlipH - Filtre de retournement horizontal (miroir)
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Point d'entrée du filtre. En mode info, définit les métadonnées.
;   En mode traitement, lance le processus multi-threadé.
;
; Configuration:
;   - Type: Déformation géométrique
;   - Nécessite 2 buffers (source et destination)
;   - Thread-safe, multi-threadé automatiquement par filter_start()
;-------------------------------------------------------------------------------
Procedure FlipH(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0
    *param\name = "FlipH (Miroir horizontal)"
    *param\remarque = "Inverse l'image horizontalement (effet miroir)"
    *param\info[0] = "Retournement horizontal"
    
    *param\info_data(0, 0) = 0 : *param\info_data(0, 1) = 2 : *param\info_data(0, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@FlipH_MT(), 0, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 67
; FirstLine = 7
; Folding = -
; EnableXP
; DPIAware