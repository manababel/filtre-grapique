; -------------------------------------------------------------------------------
; Spiralize_MT - Déformation en spirale avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: angle de rotation (0-2000, 1000=neutre, échelle ±180°)
;                  - option[1]: position X du centre (0-100%, 50=centre)
;                  - option[2]: position Y du centre (0-100%, 50=centre)
;                  - option[3]: rayon d'effet (0-100% de la diagonale)
;                  - option[4]: sens de rotation (0=horaire, 1=anti-horaire)
;
; Description:
;   Applique une déformation en spirale autour d'un point central.
;   La rotation est maximale au centre et diminue progressivement vers les bords.
;   Valeur 1000 = pas de rotation, <1000 = rotation inverse, >1000 = rotation directe.
;
; Optimisations:
;   - Précalcul du centre et du rayon
;   - Précalcul de l'inverse du rayon pour normalisation
;   - Précalcul de l'angle maximum en radians
;   - Utilisation d'offsets directs pour accès mémoire
;   - Test précoce pour pixels hors zone d'effet
; -------------------------------------------------------------------------------
Procedure Spiralize_MT(*p.parametre)
  Protected x.i, y.i
  Protected dx.f, dy.f, r.f
  Protected a.f, new_a.f, rotation_angle.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul du centre de l'effet
  Protected cx.f = (*p\option[1] / 100.0) * lg
  Protected cy.f = (*p\option[2] / 100.0) * ht

  ; Précalcul du rayon d'effet (en pixels, basé sur la diagonale)
  Protected diagonale.f = Sqr(lg * lg + ht * ht)
  Protected rayon.f = (diagonale * *p\option[3] / 100.0) + 1.0
  Protected inv_rayon.f = 1.0 / rayon  ; Précalcul pour éviter divisions

  ; Précalcul de l'angle maximum de rotation en radians
  ; Plage : 0-2000, avec 1000 = neutre (0°)
  ; Résultat : -180° à +180° (-π à +π)
  Protected angle_max.f = (*p\option[0] - 1000.0) * #PI / 180.0

  ; Sens de rotation (0 = horaire, 1 = anti-horaire)
  Protected sens.i = *p\option[4]

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Calcul de la position relative au centre
      dx = x - cx
      dy = y - cy

      ; Distance au centre
      r = Sqr(dx * dx + dy * dy)

      ; Application de la spirale seulement dans le rayon d'effet
      If r <= rayon
        ; Angle polaire actuel du pixel
        a = ATan2(dy, dx)

        ; Calcul de l'angle de rotation (diminue du centre vers les bords)
        ; Au centre (r=0) : rotation maximale = angle_max
        ; Au bord (r=rayon) : rotation nulle
        rotation_angle = angle_max * (1.0 - r * inv_rayon)

        ; Application du sens de rotation
        If sens
          new_a = a + rotation_angle  ; Anti-horaire
        Else
          new_a = a - rotation_angle  ; Horaire
        EndIf

        ; Conversion polaire → cartésienne
        src_x = cx + r * Cos(new_a)
        src_y = cy + r * Sin(new_a)
      Else
        ; Hors zone d'effet : pas de déformation
        src_x = x
        src_y = y
      EndIf

      ; Conversion en entiers et vérification des limites
      src_x_int = Int(src_x)
      src_y_int = Int(src_y)

      If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
        ; Échantillonnage du pixel source
        offset_src = (src_y_int * lg + src_x_int) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))
      Else
        ; Pixel hors limites = noir transparent
        PokeL(*cible + offset_dst, $00000000)
      EndIf

      offset_dst + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; Spiralize - Filtre de déformation en spirale
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une déformation en spirale autour d'un point central.
;   La rotation est maximale au centre et s'atténue progressivement vers les bords,
;   créant un effet de tourbillon ou vortex.
;
; Paramètres utilisateur:
;   [0] Angle de rotation (0-2000, défaut=1000)
;       0-999  : rotation inverse (maximum -180°)
;       1000   : pas de rotation
;       1001-2000: rotation directe (maximum +180°)
;   [1] Position X du centre (0-100%, défaut=50% = centre)
;   [2] Position Y du centre (0-100%, défaut=50% = centre)
;   [3] Rayon d'effet (0-100% de la diagonale, défaut=50%)
;   [4] Sens de rotation (0=horaire, 1=anti-horaire, défaut=0)
;
; Utilisations:
;   - Effet tourbillon/vortex
;   - Effets artistiques de distorsion
;   - Simulation de rotation fluide
;   - Transitions dynamiques
; -------------------------------------------------------------------------------
Procedure Spiralize(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Spiralize (Spirale)"
    *param\remarque = "Déformation en spirale avec rotation progressive du centre vers les bords"
    
    *param\info[0] = "Rotation (0-999=inverse, 1000=neutre, 1001-2000=directe)"
    *param\info[1] = "Centre X (% largeur)"
    *param\info[2] = "Centre Y (% hauteur)"
    *param\info[3] = "Rayon (% diagonale)"
    *param\info[4] = "Sens (0=horaire, 1=anti-horaire)"
    *param\info[5] = "masque"
    
    ; Configuration rotation (0-2000, défaut 1000 = neutre)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 2000
    *param\info_data(0, 2) = 1000
    
    ; Configuration centre X (0-100%, défaut 50% = centre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Configuration centre Y (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration rayon (0-100% de la diagonale, défaut 50%)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 100
    *param\info_data(3, 2) = 50
    
    ; Configuration sens (0=horaire, 1=anti-horaire)
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 1
    *param\info_data(4, 2) = 0
    
    ; Configuration du masque
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 2
    *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (5 paramètres, 1 buffer destination)
  filter_start(@Spiralize_MT(), 5, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 194
; FirstLine = 125
; Folding = -
; EnableXP
; DPIAware