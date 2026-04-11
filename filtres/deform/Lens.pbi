;-------------------------------------------------------------------------------
; Lens_MT - Thread de traitement pour l'effet de lentille/loupe
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres contenant:
;                  - lg, ht: dimensions de l'image
;                  - addr[0]: image source
;                  - addr[1]: image destination
;                  - option[0]: zoom (-100 à +300%)
;                  - option[1]: centre X (0-100%)
;                  - option[2]: centre Y (0-100%)
;                  - option[3]: rayon (1-100%)
;
; Description:
;   Applique un effet de lentille circulaire. À l'intérieur du rayon,
;   les pixels sont déformés selon le facteur de zoom. Le zoom est maximum
;   au centre et diminue linéairement jusqu'au bord du rayon.
;
; Formule:
;   factor = 1 + zoom * (1 - dist/rayon)
;   src = centre + (pixel - centre) / factor
;
; Optimisations:
;   - Précalcul de toutes les constantes en dehors des boucles
;   - Utilisation de rayon² pour éviter Sqr() dans la boucle
;   - Calcul incrémental de l'adresse cible (évite multiplication)
;   - Typage explicite pour meilleures performances
;   - Early exit quand zoom = 0 (pas de déformation)
;-------------------------------------------------------------------------------
Procedure Lens_MT(*p.parametre)
  Protected start.i, stop.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht
  
  ; Précalcul des paramètres (une seule fois)
  Protected cx.f = (*p\option[1] * lg) / 100.0
  Protected cy.f = (*p\option[2] * ht) / 100.0
  Protected zoom.f = *p\option[0] / 100.0
  Protected diag.f = Sqr(lg * lg + ht * ht)  ; Diagonale de l'image
  Protected rayon.f = (diag * *p\option[3]) / 100.0 + 1.0
  Protected rayon_carre.f = rayon * rayon    ; Évite Sqr() dans la boucle
  Protected inv_rayon.f = 1.0 / rayon        ; Précalcul de 1/rayon
  
  Protected x.i, y.i
  Protected dx.f, dy.f, dist_carre.f, dist.f
  Protected factor.f, inv_factor.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected offset_cible.i, offset_source.i
  Protected pix.l
  
  ; Calcul de la portion de lignes à traiter
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  ; Early exit si pas de zoom (optimisation)
  If zoom = 0.0
    ; Copie simple sans déformation
    For y = start To stop
      offset_cible = (y * lg) * 4
      CopyMemory(*source + offset_cible, *cible + offset_cible, lg * 4)
    Next y
    ProcedureReturn
  EndIf
  
  ; Traitement pixel par pixel
  For y = start To stop
    dy = y - cy
    offset_cible = y * lg * 4  ; Adresse de début de ligne
    
    For x = 0 To lg - 1
      dx = x - cx
      
      ; Utiliser distance au carré pour éviter Sqr() (optimisation majeure)
      dist_carre = dx * dx + dy * dy
      
      ; Vérifier si le pixel est dans le rayon de la lentille
      If dist_carre < rayon_carre And dist_carre > 0.0
        ; Calculer la distance réelle seulement si nécessaire
        dist = Sqr(dist_carre)
        
        ; Calculer le facteur de déformation
        ; factor = 1 + zoom * (1 - dist/rayon)
        factor = 1.0 + zoom * (1.0 - dist * inv_rayon)
        
        ; Calculer la position source avec déformation
        inv_factor = 1.0 / factor
        src_x = cx + dx * inv_factor
        src_y = cy + dy * inv_factor
      Else
        ; En dehors du rayon : pas de déformation
        src_x = x
        src_y = y
      EndIf
      
      ; Vérifier les limites et récupérer le pixel
      src_x_int = Int(src_x)
      src_y_int = Int(src_y)
      
      If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
        offset_source = (src_y_int * lg + src_x_int) * 4
        pix = PeekL(*source + offset_source)
      Else
        pix = 0  ; Noir en dehors de l'image
      EndIf
      
      ; Écrire le pixel dans l'image de destination
      PokeL(*cible + offset_cible, pix)
      offset_cible + 4  ; Incrément pour le prochain pixel
    Next x
  Next y
EndProcedure

;-------------------------------------------------------------------------------
; Lens - Filtre effet de lentille/loupe
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique un effet de déformation circulaire simulant une lentille.
;   Zoom positif = effet loupe (agrandissement)
;   Zoom négatif = effet fish-eye inversé (réduction)
;
; Paramètres utilisateur:
;   [0] Zoom: -100% (forte réduction) à +300% (fort agrandissement)
;   [1] Centre X: position horizontale du centre (0-100%)
;   [2] Centre Y: position verticale du centre (0-100%)
;   [3] Rayon: taille de la zone affectée (1-100% de la diagonale)
;-------------------------------------------------------------------------------
Procedure Lens(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0
    *param\name = "Lens (Lentille/Loupe)"
    *param\remarque = "Effet loupe ou lentille. Zoom positif = loupe, négatif = fish-eye"
    
    ; Définition des paramètres
    *param\info[0] = "Zoom (%)"        ; -100 (réduction) à +300 (agrandissement)
    *param\info[1] = "Centre X (%)"    ; Position horizontale du centre
    *param\info[2] = "Centre Y (%)"    ; Position verticale du centre
    *param\info[3] = "Rayon (%)"       ; Taille de la zone affectée
    *param\info[4] = "masque"
    
    ; Configuration des plages de valeurs (min, max, défaut)
    *param\info_data(0, 0) = -100 : *param\info_data(0, 1) = 300 : *param\info_data(0, 2) = 100   ; Zoom
    *param\info_data(1, 0) = 0    : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 50    ; Centre X
    *param\info_data(2, 0) = 0    : *param\info_data(2, 1) = 100 : *param\info_data(2, 2) = 50    ; Centre Y
    *param\info_data(3, 0) = 1    : *param\info_data(3, 1) = 100 : *param\info_data(3, 2) = 30    ; Rayon
    *param\info_data(4, 0) = 0    : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-threadé
  ; 4 paramètres (zoom, cx, cy, rayon), 1 buffer destination
  filter_start(@Lens_MT(), 4, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 136
; FirstLine = 91
; Folding = -
; EnableXP
; DPIAware