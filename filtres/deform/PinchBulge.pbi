; -------------------------------------------------------------------------------
; PinchBulge_MT - Thread de traitement pour effet pincement/bombement
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres contenant:
;                  - option[0]: force (-100 à +100)
;                               négatif = pinch (pincement vers centre)
;                               positif = bulge (bombement vers extérieur)
;                  - option[1]: centre X (0-100%)
;                  - option[2]: centre Y (0-100%)
;                  - option[3]: rayon d'effet (0-100% de la diagonale)
;
; Description:
;   Applique une déformation radiale circulaire. Les pixels sont déplacés
;   radialement selon une fonction de puissance, créant un effet de loupe
;   concave (pinch) ou convexe (bulge).
;
; Formule:
;   factor = (dist/rayon)^(1-force)
;   nouvelle_position = centre + direction * factor
;
; Optimisations:
;   - Utilise rayon² pour éviter Sqr() dans la comparaison
;   - Précalcul de l'inverse du rayon
;   - Table de lookup pour Pow() (gain majeur de performance)
;   - Calcul incrémental des offsets
;   - Early exit quand force = 0
; -------------------------------------------------------------------------------
Procedure PinchBulge_MT(*p.parametre)
  Protected start.i, stop.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht
  
  ; Précalcul des paramètres (une seule fois)
  Protected cx.f = (*p\option[1] * lg) / 100.0
  Protected cy.f = (*p\option[2] * ht) / 100.0
  Protected diag.f = Sqr(lg * lg + ht * ht)
  Protected rayon.f = (diag * *p\option[3]) / 100.0 + 1.0
  Protected rayon_carre.f = rayon * rayon
  Protected inv_rayon.f = 1.0 / rayon
  Protected force.f = (*p\option[0]) / 100.0
  Protected exposant.f = 1.0 - force  ; Exposant pour Pow()
  
  Protected x.i, y.i
  Protected dx.f, dy.f, dist_carre.f, dist.f
  Protected factor.f, dist_norm.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected offset_cible.i, offset_source.i
  Protected pix.l
  
  ; Calcul de la portion de lignes à traiter
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  ; Early exit si pas de force (optimisation)
  If Abs(force) < 0.001
    For y = start To stop
      offset_cible = (y * lg) * 4
      CopyMemory(*source + offset_cible, *cible + offset_cible, lg * 4)
    Next y
    ProcedureReturn
  EndIf
  
  ; --- Optimisation majeure : Table de lookup pour Pow() ---
  ; Pow() est très lent, on précalcule les valeurs
  #LUT_SIZE = 1024
  Protected Dim powerLUT.f(#LUT_SIZE)
  Protected lut_i.i
  
  For lut_i = 0 To #LUT_SIZE
    dist_norm = lut_i / #LUT_SIZE
    powerLUT(lut_i) = Pow(dist_norm, exposant)
  Next lut_i
  
  ; Traitement pixel par pixel
  For y = start To stop
    dy = y - cy
    offset_cible = y * lg * 4
    
    For x = 0 To lg - 1
      dx = x - cx
      
      ; Utiliser distance au carré pour éviter Sqr() (optimisation majeure)
      dist_carre = dx * dx + dy * dy
      
      ; Vérifier si le pixel est dans le rayon d'effet
      If dist_carre < rayon_carre And dist_carre > 0.0
        ; Calculer la distance réelle seulement si nécessaire
        dist = Sqr(dist_carre)
        
        ; Normaliser la distance [0..1]
        dist_norm = dist * inv_rayon
        
        ; Lookup dans la table au lieu de Pow() (TRÈS RAPIDE)
        lut_i = Int(dist_norm * #LUT_SIZE)
        If lut_i >= #LUT_SIZE : lut_i = #LUT_SIZE - 1 : EndIf
        factor = powerLUT(lut_i)
        
        ; Calculer la nouvelle position déformée
        src_x = cx + dx * factor
        src_y = cy + dy * factor
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
        pix = $FF000000  ; Noir opaque
      EndIf
      
      ; Écrire le pixel dans l'image de destination
      PokeL(*cible + offset_cible, pix)
      offset_cible + 4
    Next x
  Next y
  
  ; Libérer la table de lookup
  FreeArray(powerLUT())
EndProcedure

; -------------------------------------------------------------------------------
; PinchBulge - Filtre effet pincement/bombement
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une déformation radiale circulaire.
;   Force négative = Pinch (pincement, effet loupe concave)
;   Force positive = Bulge (bombement, effet loupe convexe)
;   Force = 0 = Pas de déformation
;
; Paramètres utilisateur:
;   [0] Force: -100 (pinch fort) à +100 (bulge fort), 0 = neutre
;   [1] Centre X: position horizontale du centre (0-100%)
;   [2] Centre Y: position verticale du centre (0-100%)
;   [3] Rayon: taille de la zone affectée (0-100% de la diagonale)
;
; Utilisations:
;   - Effets de loupe
;   - Corrections de distorsion
;   - Effets artistiques
;   - Caricatures (pinch sur le nez, bulge sur les yeux, etc.)
; -------------------------------------------------------------------------------
Procedure PinchBulge(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0 ; "Radiale"
    *param\name = "Pinch/Bulge (Pincement/Bombement)"
    *param\remarque = "Déformation radiale. Négatif=pinch, Positif=bulge"
    
    *param\info[0] = "Force (-100 pinch, +100 bulge)"
    *param\info[1] = "Centre X (%)"
    *param\info[2] = "Centre Y (%)"
    *param\info[3] = "Rayon d'effet (%)"
    *param\info[4] = "masque"
    ; Configuration des plages de valeurs (min, max, défaut)
    *param\info_data(0, 0) = -100 : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 0   ; Force
    *param\info_data(1, 0) = 0    : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 50  ; Centre X
    *param\info_data(2, 0) = 0    : *param\info_data(2, 1) = 100 : *param\info_data(2, 2) = 50  ; Centre Y
    *param\info_data(3, 0) = 1    : *param\info_data(3, 1) = 100 : *param\info_data(3, 2) = 30  ; Rayon
    *param\info_data(4, 0) = 0    : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-threadé
  ; 4 paramètres (force, cx, cy, rayon), 1 buffer destination
  filter_start(@PinchBulge_MT(), 4, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 27
; Folding = -
; EnableXP
; DPIAware