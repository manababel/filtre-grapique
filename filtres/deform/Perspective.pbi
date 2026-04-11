
; -------------------------------------------------------------------------------
; Area2D - Calcule l'aire d'un triangle défini par 3 points
;
; Description:
;   Utilise la formule du déterminant pour calculer l'aire d'un triangle.
;   Utilisé pour déterminer si un point est à l'intérieur d'un quadrilatère.
; -------------------------------------------------------------------------------
Procedure.f Area2D(x1.f, y1.f, x2.f, y2.f, x3.f, y3.f)
  ProcedureReturn Abs((x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1)) / 2.0
EndProcedure

; -------------------------------------------------------------------------------
; PointInQuad - Teste si un point est à l'intérieur d'un quadrilatère
;
; Paramètres:
;   x, y - Coordonnées du point à tester
;   Array pts.f(1) - Tableau des 8 coordonnées du quadrilatère
;                    Format: [A_x, A_y, B_x, B_y, D_x, D_y, C_x, C_y]
;
; Retour:
;   #True si le point est à l'intérieur, #False sinon
;
; Méthode:
;   Compare la somme des aires des 4 triangles formés par le point
;   avec l'aire totale du quadrilatère. Si elles sont égales (à epsilon près),
;   le point est à l'intérieur.
; -------------------------------------------------------------------------------
Procedure.b PointInQuad(x.f, y.f, Array pts.f(1))
  ; Quadrilatère : A(0,1) B(2,3) C(6,7) D(4,5)
  Protected A_x.f = pts(0), A_y.f = pts(1)
  Protected B_x.f = pts(2), B_y.f = pts(3)
  Protected C_x.f = pts(6), C_y.f = pts(7)
  Protected D_x.f = pts(4), D_y.f = pts(5)

  ; Aire du quadrilatère (somme de 2 triangles)
  Protected areaQuad.f = Area2D(A_x, A_y, B_x, B_y, C_x, C_y) + Area2D(A_x, A_y, C_x, C_y, D_x, D_y)
  
  ; Somme des aires des 4 triangles formés avec le point (x, y)
  Protected areaSum.f = 0.0
  areaSum + Area2D(x, y, A_x, A_y, B_x, B_y)
  areaSum + Area2D(x, y, B_x, B_y, C_x, C_y)
  areaSum + Area2D(x, y, C_x, C_y, D_x, D_y)
  areaSum + Area2D(x, y, D_x, D_y, A_x, A_y)

  ; Si les aires sont proches, le point est dedans (✅ CORRIGÉ)
  If Abs(areaQuad - areaSum) < 0.5
    ProcedureReturn #True
  Else
    ProcedureReturn #False
  EndIf
EndProcedure

; -------------------------------------------------------------------------------
; Perspective_MT - Thread de traitement pour la déformation perspective
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;
; Description:
;   Applique une transformation perspective en utilisant une interpolation
;   bilinéaire. Les 4 coins de l'image sont mappés vers de nouvelles positions
;   définies par les paramètres option[0..7].
;
; Algorithme:
;   1. Calcule les positions des 4 coins destination en fonction des options
;   2. Pour chaque pixel destination (x,y):
;      - Calcule les coordonnées normalisées (u,v) dans [0,1]
;      - Applique l'interpolation bilinéaire pour trouver (sx,sy) source
;      - Copie le pixel source vers la destination
;
; Optimisations:
;   - Précalcul des facteurs de normalisation (inv_lg, inv_ht)
;   - Précalcul des coefficients d'interpolation
;   - Calcul incrémental de l'offset destination
;   - Multi-threading sur les lignes
; -------------------------------------------------------------------------------
Procedure Perspective_MT(*p.parametre)
  Protected x.i, y.i
  Protected sx.f, sy.f, u.f, v.f
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Précalcul des facteurs de normalisation (optimisation)
  Protected inv_lg.f = 1.0 / lg
  Protected inv_ht.f = 1.0 / ht

  ; Calcul des deltas pour les offsets des coins
  Protected deltaX.f = lg / 2.0
  Protected deltaY.f = ht / 2.0

  ; Calcul des positions des 4 coins destination
  ; Format: option[0-1] = coin haut-gauche, [2-3] = haut-droit, etc.
  Protected x00.f = deltaX * ((*p\option[0] - 50.0) / 50.0) + 0.0   ; Haut gauche X
  Protected y00.f = deltaY * ((*p\option[1] - 50.0) / 50.0) + 0.0   ; Haut gauche Y
  Protected x10.f = deltaX * ((*p\option[2] - 50.0) / 50.0) + lg    ; Haut droite X
  Protected y10.f = deltaY * ((*p\option[3] - 50.0) / 50.0) + 0.0   ; Haut droite Y
  Protected x01.f = deltaX * ((*p\option[4] - 50.0) / 50.0) + 0.0   ; Bas gauche X
  Protected y01.f = deltaY * ((*p\option[5] - 50.0) / 50.0) + ht    ; Bas gauche Y
  Protected x11.f = deltaX * ((*p\option[6] - 50.0) / 50.0) + lg    ; Bas droite X
  Protected y11.f = deltaY * ((*p\option[7] - 50.0) / 50.0) + ht    ; Bas droite Y

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Précalcul des coefficients pour l'interpolation (optimisation)
  Protected coef_1mu_1mv.f, coef_u_1mv.f, coef_1mu_v.f, coef_u_v.f
  Protected mu.f, mv.f  ; 1-u et 1-v
  Protected offset_dst.i, offset_src.i
  Protected sx_int.i, sy_int.i

  ; Traitement pixel par pixel
  For y = startY To stopY
    ; Normalisation de y (précalculée pour toute la ligne)
    v = y * inv_ht
    mv = 1.0 - v
    
    offset_dst = y * lg * 4  ; Début de ligne destination
    
    For x = 0 To lg - 1
      ; Normalisation de x
      u = x * inv_lg
      mu = 1.0 - u

      ; Interpolation bilinéaire des coordonnées source
      ; Formule: P = (1-u)(1-v)P00 + u(1-v)P10 + (1-u)vP01 + uvP11
      coef_1mu_1mv = mu * mv
      coef_u_1mv   = u * mv
      coef_1mu_v   = mu * v
      coef_u_v     = u * v
      
      sx = coef_1mu_1mv * x00 + coef_u_1mv * x10 + coef_1mu_v * x01 + coef_u_v * x11
      sy = coef_1mu_1mv * y00 + coef_u_1mv * y10 + coef_1mu_v * y01 + coef_u_v * y11

      ; Vérifier si le pixel source est dans les limites
      sx_int = Int(sx)
      sy_int = Int(sy)
      
      If sx_int >= 0 And sx_int < lg And sy_int >= 0 And sy_int < ht
        offset_src = (sy_int * lg + sx_int) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))
      Else
        PokeL(*cible + offset_dst, $FF000000)  ; Noir opaque
      EndIf
      
      offset_dst + 4  ; Prochain pixel
    Next x
  Next y
EndProcedure

; -------------------------------------------------------------------------------
; Perspective - Filtre de déformation perspective
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Applique une transformation perspective en déplaçant les 4 coins de l'image.
;   Chaque coin peut être déplacé indépendamment pour créer des effets de
;   perspective, rotation 3D, trapèze, etc.
;
; Paramètres utilisateur (en % de l'image):
;   [0-1] Position du coin haut-gauche (X, Y)
;   [2-3] Position du coin haut-droit (X, Y)
;   [4-5] Position du coin bas-gauche (X, Y)
;   [6-7] Position du coin bas-droit (X, Y)
;
;   Valeur 50% = position d'origine (pas de déformation)
;   0-100% permet de déplacer les coins dans toutes les directions
;
; Note:
;   Utilise une interpolation bilinéaire simple. Pour une vraie perspective
;   homographique, voir la fonction DrawTextureInQuad_MT (plus complexe).
; -------------------------------------------------------------------------------
Procedure Perspective(*param.parametre)
  Protected i.i
  
  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0 ; "Géométrique"
    *param\name = "Perspective (déformation 4 coins)"
    *param\remarque = "Déplace les 4 coins pour créer un effet de perspective"
    
    *param\info[0] = "Coin haut-gauche X (%)"
    *param\info[1] = "Coin haut-gauche Y (%)"
    *param\info[2] = "Coin haut-droit X (%)"
    *param\info[3] = "Coin haut-droit Y (%)"
    *param\info[4] = "Coin bas-gauche X (%)"
    *param\info[5] = "Coin bas-gauche Y (%)"
    *param\info[6] = "Coin bas-droit X (%)"
    *param\info[7] = "Coin bas-droit Y (%)"
    *param\info[8] = "masque"
    
    ; Configuration: 0-100%, défaut 50% (pas de déformation)
    For i = 0 To 7
      *param\info_data(i, 0) = 0
      *param\info_data(i, 1) = 100
      *param\info_data(i, 2) = 50
    Next i
    *param\info_data(8, 0) = 0 : *param\info_data(8, 1) = 2 : *param\info_data(8, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-threadé (8 paramètres, 1 buffer destination)
  filter_start(@Perspective_MT(), 8, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 195
; FirstLine = 140
; Folding = -
; EnableXP
; DPIAware