
; -------------------------------------------------------------------------------
; PerspectiveTrapezeLin_MT - Déformation trapèze avec interpolation linéaire
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: décalage vertical gauche (0-100%, 50=neutre)
;                  - option[1]: décalage vertical droite (0-100%, 50=neutre)
;                  - option[2]: décalage horizontal haut (0-100%, 50=neutre)
;                  - option[3]: décalage horizontal bas (0-100%, 50=neutre)
;
; Description:
;   Applique une déformation trapèze symétrique en déplaçant les bords.
;   Utilise une interpolation bilinéaire simple pour mapper les pixels.
;
; Optimisations:
;   - Précalcul de tous les offsets et coins
;   - Précalcul des facteurs de normalisation
;   - Précalcul des différentielles des bords
;   - Calcul incrémental des offsets
; -------------------------------------------------------------------------------
Procedure PerspectiveTrapezeLin_MT(*p.parametre)
  Protected x.i, y.i
  Protected sx.f, sy.f, u.f, v.f
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul des facteurs de normalisation (évite division par zéro)
  Protected inv_lg.f = 1.0 / (lg - 1)
  Protected inv_ht.f = 1.0 / (ht - 1)
  Protected half_lg.f = lg * 0.5
  Protected half_ht.f = ht * 0.5

  ; Calcul des offsets symétriques
  Protected offsetY_Gauche.f = ((50.0 - *p\option[0]) / 50.0) * half_ht
  Protected offsetY_Droite.f = ((50.0 - *p\option[1]) / 50.0) * half_ht
  Protected offsetX_HautGauche.f = ((50.0 - *p\option[2]) / 50.0) * half_lg
  Protected offsetX_BasGauche.f  = ((50.0 - *p\option[3]) / 50.0) * half_lg

  ; Calcul des positions des 4 coins déformés
  Protected x00.f = 0.0 + offsetX_HautGauche
  Protected y00.f = 0.0 - offsetY_Gauche
  Protected x10.f = (lg - 1) - offsetX_HautGauche  ; Symétrique
  Protected y10.f = 0.0 - offsetY_Droite
  Protected x01.f = 0.0 + offsetX_BasGauche
  Protected y01.f = (ht - 1) + offsetY_Gauche
  Protected x11.f = (lg - 1) - offsetX_BasGauche   ; Symétrique
  Protected y11.f = (ht - 1) + offsetY_Droite

  ; Précalcul des différentielles des bords (optimisation majeure)
  Protected deltaY_Left.f  = y01 - y00  ; Variation Y sur bord gauche
  Protected deltaY_Right.f = y11 - y10  ; Variation Y sur bord droit
  Protected deltaX.f = x10 - x00        ; Variation X entre gauche et droite (ligne haut)

  ; Calcul de la portion de lignes à traiter
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected borderLeftY.f, borderRightY.f
  Protected borderLeftX.f, borderRightX.f
  Protected deltaBorderX.f, deltaBorderY.f
  Protected offset_dst.i, offset_src.i
  Protected sx_int.i, sy_int.i

  ; Traitement pixel par pixel
  For y = startY To stopY
    ; Normalisation verticale
    v = y * inv_ht

    ; Calcul des coordonnées Y des bords gauche et droit pour cette ligne
    borderLeftY  = y00 + v * deltaY_Left
    borderRightY = y10 + v * deltaY_Right
    
    ; X reste constant sur chaque bord vertical
    borderLeftX  = x00
    borderRightX = x10

    ; Précalcul des variations horizontales pour cette ligne
    deltaBorderX = borderRightX - borderLeftX
    deltaBorderY = borderRightY - borderLeftY

    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      ; Normalisation horizontale
      u = x * inv_lg

      ; Interpolation linéaire horizontale entre les deux bords
      sx = borderLeftX + u * deltaBorderX
      sy = borderLeftY + u * deltaBorderY

      ; Vérification des limites et échantillonnage
      sx_int = Int(sx)
      sy_int = Int(sy)

      If sx_int >= 0 And sx_int < lg And sy_int >= 0 And sy_int < ht
        offset_src = (sy_int * lg + sx_int) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))
      Else
        PokeL(*cible + offset_dst, $FF000000)  ; Noir opaque
      EndIf

      offset_dst + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; PerspectiveSimple - Filtre de déformation trapèze simple
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une déformation trapèze en déplaçant symétriquement les bords.
;   Plus simple et rapide que la perspective homographique complète.
;
; Paramètres utilisateur:
;   [0] Décalage vertical bord gauche (0-100%, 50=neutre)
;   [1] Décalage vertical bord droit (0-100%, 50=neutre)
;   [2] Décalage horizontal bord haut (0-100%, 50=neutre)
;   [3] Décalage horizontal bord bas (0-100%, 50=neutre)
;
; Utilisations:
;   - Correction de perspective simple
;   - Effets trapèze
;   - Déformations géométriques basiques
; -------------------------------------------------------------------------------
Procedure PerspectiveSimple(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0;"Géométrique"
    *param\name = "Perspective Simple (Trapèze)"
    *param\remarque = "Déformation trapèze avec décalage symétrique des bords"
    
    *param\info[0] = "Décalage vertical gauche (%)"
    *param\info[1] = "Décalage vertical droite (%)"
    *param\info[2] = "Décalage horizontal haut (%)"
    *param\info[3] = "Décalage horizontal bas (%)"
    *param\info[4] = "masque"
    
    ; Configuration: 0-100%, défaut 50% (pas de décalage)
    For i = 0 To 3
      *param\info_data(i, 0) = 0
      *param\info_data(i, 1) = 100
      *param\info_data(i, 2) = 50
    Next i
    *param\info_data(4, 0) = 0 : *param\info_data(4, 1) = 2 : *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (4 paramètres, 1 buffer destination)
  filter_start(@PerspectiveTrapezeLin_MT(), 4, 1)
EndProcedure



; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 110
; Folding = -
; EnableXP
; DPIAware