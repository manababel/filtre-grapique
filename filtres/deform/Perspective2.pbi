;-------------------------------------------------------------------------------
; Perspective4Borders_MT - Déformation trapèze indépendante sur 4 bords
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres contenant:
;                  - option[0]: inclinaison bord haut (0-200%, 100=neutre)
;                  - option[1]: inclinaison bord bas
;                  - option[2]: inclinaison bord gauche
;                  - option[3]: inclinaison bord droite
;                  - option[4]: zoom global (0-200%, 100=neutre)
;                  - option[5]: position X (0-200%, 100=centré)
;                  - option[6]: position Y (0-200%, 100=centré)
;                  - option[7]: rotation en degrés (0-360°)
;
; Description:
;   Applique une déformation perspective avec contrôle indépendant de chaque bord.
;   Permet de créer des effets trapèze, rotation, zoom et translation combinés.
;
; Algorithme:
;   1. Calcule les facteurs d'échelle X/Y selon la position du pixel
;   2. Applique le zoom global et les décalages
;   3. Applique la rotation autour du centre
;   4. Échantillonne le pixel source correspondant
;
; Optimisations:
;   - Précalcul de toutes les constantes (centre, inv, cos, sin)
;   - Évite les divisions répétées
;   - Clamping des paramètres en début de fonction
;   - Calcul incrémental des offsets
;-------------------------------------------------------------------------------
Procedure Perspective4Borders_MT(*p.parametre)
  Protected start.i, stop.i
  Protected *source.Long = *p\addr[0]  ; ✅ CORRIGÉ
  Protected *cible.Long  = *p\addr[1]  ; ✅ CORRIGÉ
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht
  
  ; Précalcul des constantes (optimisation majeure)
  Protected half_lg.f = lg / 2.0
  Protected half_ht.f = ht / 2.0
  Protected inv_lg.f = 1.0 / (lg - 1)
  Protected inv_ht.f = 1.0 / (ht - 1)
  
  ; Lecture et normalisation des paramètres
  Protected tiltTop.f    = (*p\option[0] - 100.0) / 100.0
  Protected tiltBottom.f = (*p\option[1] - 100.0) / 100.0
  Protected tiltLeft.f   = (*p\option[2] - 100.0) / 100.0
  Protected tiltRight.f  = (*p\option[3] - 100.0) / 100.0
  Protected scaleGlobal.f = *p\option[4] / 100.0
  Protected shiftX.f = ((*p\option[5] - 100.0) * lg) / 100.0
  Protected shiftY.f = ((*p\option[6] - 100.0) * ht) / 100.0
  Protected angle.f = Radian(*p\option[7])
  
  ; Précalcul des fonctions trigonométriques
  Protected cosA.f = Cos(angle)
  Protected sinA.f = Sin(angle)
  
  ; Clamping des valeurs (✅ CORRIGÉ)
  Clamp(tiltTop, -1.0, 1.0)
  Clamp(tiltBottom, -1.0, 1.0)
  Clamp(tiltLeft, -1.0, 1.0)
  Clamp(tiltRight, -1.0, 1.0)
  Clamp(scaleGlobal, 0.01, 10.0)
  
  ; Variables de travail
  Protected y.i, x.i
  Protected u.f, v.f
  Protected scaleX.f, scaleY.f
  Protected inv_scale.f
  Protected tmp_x.f, tmp_y.f
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected offset_source.i, offset_cible.i
  Protected pix.l
  
  ; Calcul de la portion de lignes à traiter
  start = (*p\thread_pos * ht) / *p\thread_max
  stop  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stop > ht - 1 : stop = ht - 1 : EndIf
  
  ; Traitement pixel par pixel
  For y = start To stop
    ; Normalisation verticale (précalculée pour toute la ligne)
    v = y * inv_ht
    
    ; Calcul du facteur d'échelle X selon la position verticale
    ; Interpolation linéaire entre tiltTop (haut) et tiltBottom (bas)
    scaleX = 1.0 - ((1.0 - v) * tiltTop + v * tiltBottom)
    Clamp(scaleX, 0.01, 10.0)
    
    offset_cible = y * lg * 4
    
    For x = 0 To lg - 1
      ; Normalisation horizontale
      u = x * inv_lg
      
      ; Calcul du facteur d'échelle Y selon la position horizontale
      ; Interpolation linéaire entre tiltLeft (gauche) et tiltRight (droite)
      scaleY = 1.0 - ((1.0 - u) * tiltLeft + u * tiltRight)
      Clamp(scaleY, 0.01, 10.0)
      
      ; Application de l'échelle combinée et décalage
      inv_scale = 1.0 / (scaleX * scaleY * scaleGlobal)
      tmp_x = (x - half_lg) * inv_scale + shiftX
      tmp_y = (y - half_ht) * inv_scale + shiftY
      
      ; Rotation autour du centre
      src_x = tmp_x * cosA - tmp_y * sinA + half_lg
      src_y = tmp_x * sinA + tmp_y * cosA + half_ht
      
      ; Échantillonnage du pixel source
      src_x_int = Int(src_x)
      src_y_int = Int(src_y)
      
      If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
        offset_source = (src_y_int * lg + src_x_int) * 4
        pix = PeekL(*source + offset_source)
      Else
        pix = $FF000000  ; Noir opaque
      EndIf
      
      PokeL(*cible + offset_cible, pix)
      offset_cible + 4
    Next x
  Next y
EndProcedure

;-------------------------------------------------------------------------------
; Perspective2 - Filtre de déformation trapèze 4 bords
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une déformation perspective avec contrôle indépendant de chaque bord.
;   Combine trapèze, zoom, translation et rotation pour des effets complexes.
;
; Paramètres utilisateur:
;   [0] Inclinaison bord haut (0-200%, 100=neutre)
;   [1] Inclinaison bord bas (0-200%, 100=neutre)
;   [2] Inclinaison bord gauche (0-200%, 100=neutre)
;   [3] Inclinaison bord droite (0-200%, 100=neutre)
;   [4] Zoom global (0-200%, 100=normal)
;   [5] Position X (0-200%, 100=centré)
;   [6] Position Y (0-200%, 100=centré)
;   [7] Rotation (0-360°)
;
; Utilisations typiques:
;   - Correction de perspective (photos de documents)
;   - Effets 3D et rotation
;   - Déformations artistiques
;-------------------------------------------------------------------------------
Procedure Perspective2(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0 ; "Géométrique avancée"
    *param\name = "Perspective 4 bords (Trapèze)"
    *param\remarque = "Déformation trapèze + rotation + zoom + translation"
    
    *param\info[0] = "Inclinaison haut (%)"
    *param\info[1] = "Inclinaison bas (%)"
    *param\info[2] = "Inclinaison gauche (%)"
    *param\info[3] = "Inclinaison droite (%)"
    *param\info[4] = "Zoom global (%)"
    *param\info[5] = "Position X (%)"
    *param\info[6] = "Position Y (%)"
    *param\info[7] = "Rotation (degrés)"
    *param\info[8] = "masque"
    
    ; Configuration des plages (min, max, défaut)
    *param\info_data(0, 0) = 0   : *param\info_data(0, 1) = 200 : *param\info_data(0, 2) = 100  ; Haut
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 200 : *param\info_data(1, 2) = 100  ; Bas
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 200 : *param\info_data(2, 2) = 100  ; Gauche
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 200 : *param\info_data(3, 2) = 100  ; Droite
    *param\info_data(4, 0) = 1   : *param\info_data(4, 1) = 200 : *param\info_data(4, 2) = 100  ; Zoom
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 200 : *param\info_data(5, 2) = 100  ; Pos X
    *param\info_data(6, 0) = 0   : *param\info_data(6, 1) = 200 : *param\info_data(6, 2) = 100  ; Pos Y
    *param\info_data(7, 0) = 0   : *param\info_data(7, 1) = 360 : *param\info_data(7, 2) = 0    ; Rotation
    *param\info_data(8, 0) = 0   : *param\info_data(8, 1) = 2   : *param\info_data(8, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-threadé (8 paramètres, 1 buffer destination)
  filter_start(@Perspective4Borders_MT(), 8, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 99
; FirstLine = 116
; Folding = -
; EnableXP
; DPIAware