; -------------------------------------------------------------------------------
; Rotation_MT - Rotation d'image avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: angle de rotation en degrés (0-360°)
;                  - option[1]: position X du centre de rotation (0-100%, 50=centre)
;                  - option[2]: position Y du centre de rotation (0-100%, 50=centre)
;
; Description:
;   Applique une rotation d'image autour d'un point de pivot configurable.
;   Utilise une transformation inverse (backward mapping) pour éviter les trous.
;
; Optimisations:
;   - Précalcul des valeurs trigonométriques (cos, sin)
;   - Précalcul du centre de rotation
;   - Utilisation d'offsets directs pour accès mémoire
;   - Calcul incrémental des offsets destination
; -------------------------------------------------------------------------------
Procedure Rotation_MT(*p.parametre)
  Protected x.i, y.i
  Protected sx.i, sy.i
  Protected dx.f, dy.f
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul de l'angle en radians et des fonctions trigonométriques
  Protected angle.f = *p\option[0] * #PI / 180.0
  Protected cosA.f = Cos(angle)
  Protected sinA.f = Sin(angle)

  ; Précalcul du centre de rotation
  Protected cx.f = (*p\option[1] / 100.0) * lg
  Protected cy.f = (*p\option[2] / 100.0) * ht

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

      ; Application de la rotation inverse (backward mapping)
      ; Pour obtenir la position dans l'image source
      sx = Round(cosA * dx + sinA * dy + cx, #PB_Round_Nearest)
      sy = Round(-sinA * dx + cosA * dy + cy, #PB_Round_Nearest)

      ; Vérification des limites et échantillonnage
      If sx >= 0 And sx < lg And sy >= 0 And sy < ht
        ; Échantillonnage du pixel source
        offset_src = (sy * lg + sx) * 4
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
; Rotate - Filtre de rotation d'image
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une rotation d'image autour d'un point pivot configurable.
;   La rotation utilise une transformation inverse pour garantir un résultat
;   sans trous et avec une qualité optimale.
;
; Paramètres utilisateur:
;   [0] Angle de rotation en degrés (0-360°, défaut=0°)
;   [1] Position X du centre de rotation (0-100%, défaut=50% = centre)
;   [2] Position Y du centre de rotation (0-100%, défaut=50% = centre)
;
; Utilisations:
;   - Correction d'orientation photo
;   - Effets artistiques de rotation
;   - Redressement d'horizon
;   - Composition graphique
; -------------------------------------------------------------------------------
Procedure Rotate(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Rotation"
    *param\remarque = "Rotation d'image autour d'un point pivot configurable"
    
    *param\info[0] = "Angle (degrés)"
    *param\info[1] = "Centre X (% largeur)"
    *param\info[2] = "Centre Y (% hauteur)"
    *param\info[3] = "masque"
    
    ; Configuration angle (0-360°, défaut 0°)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 360
    *param\info_data(0, 2) = 0
    
    ; Configuration centre X (0-100%, défaut 50% = centre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Configuration centre Y (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration du masque
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 2
    *param\info_data(3, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (3 paramètres, 1 buffer destination)
  filter_start(@Rotation_MT(), 3, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 136
; FirstLine = 67
; Folding = -
; EnableXP
; DPIAware