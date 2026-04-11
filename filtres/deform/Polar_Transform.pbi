; -------------------------------------------------------------------------------
; PolarTransform_MT - Transformation polaire/cartésienne avec multi-threading
;
; Paramètres:
;   *p.parametre - Pointeur vers la structure de paramètres
;                  - option[0]: mode de transformation (0=cartésien→polaire, 1=polaire→cartésien)
;                  - option[1]: position X du centre (0-100%, 50=centre)
;                  - option[2]: position Y du centre (0-100%, 50=centre)
;                  - option[3]: angle de départ en degrés (0-360°)
;                  - option[4]: mode de remplissage (0=noir, 1=wrap)
;
; Description:
;   Convertit entre coordonnées cartésiennes et polaires.
;   Cartésien→Polaire : "déroule" l'image circulairement (effet tunnel)
;   Polaire→Cartésien : "enroule" l'image (création de mandalas)
;
; Optimisations:
;   - Précalcul du centre et des constantes angulaires
;   - Précalcul de l'inverse du rayon maximum
;   - Utilisation d'offsets directs pour accès mémoire
;   - Précalcul des facteurs de conversion
; -------------------------------------------------------------------------------
Procedure PolarTransform_MT(*p.parametre)
  Protected x.i, y.i
  Protected src_x.f, src_y.f
  Protected src_x_int.i, src_y_int.i
  Protected *source.Long = *p\addr[0]
  Protected *cible.Long  = *p\addr[1]
  Protected lg.i = *p\lg
  Protected ht.i = *p\ht

  ; Mode de transformation
  Protected mode.i = *p\option[0]  ; 0=cart→polar, 1=polar→cart

  ; Précalcul du centre de transformation
  Protected cx.f = (*p\option[1] / 100.0) * lg
  Protected cy.f = (*p\option[2] / 100.0) * ht

  ; Angle de départ en radians
  Protected start_angle.f = (*p\option[3] / 360.0) * 2.0 * #PI

  ; Mode de remplissage (0=noir, 1=wrap)
  Protected wrap_mode.i = *p\option[4]

  ; Précalcul du rayon maximum (demi-diagonale)
  Protected diagonale.f = Sqr(lg * lg + ht * ht)
  Protected max_radius.f = diagonale * 0.5
  Protected inv_max_radius.f = 1.0 / max_radius

  ; Précalcul des facteurs de conversion
  Protected inv_lg.f = 1.0 / lg
  Protected inv_ht.f = 1.0 / ht
  Protected two_pi.f = 2.0 * #PI

  ; Calcul de la portion de lignes à traiter par ce thread
  Protected startY.i = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY.i  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  ; Variables de boucle
  Protected offset_dst.i, offset_src.i
  Protected r.f, theta.f, dx.f, dy.f

  ; Traitement pixel par pixel
  For y = startY To stopY
    offset_dst = y * lg * 4

    For x = 0 To lg - 1
      
      If mode = 0
        ; ===== Mode Cartésien → Polaire =====
        ; L'image circulaire source est "déroulée" horizontalement
        ; X destination = angle, Y destination = rayon
        
        ; Calcul de la position dans l'image source (coordonnées cartésiennes)
        dx = x - cx
        dy = y - cy
        
        ; Conversion en coordonnées polaires
        r = Sqr(dx * dx + dy * dy)
        theta = ATan2(dy, dx) + start_angle
        
        ; Normalisation de l'angle dans [0, 2π]
        While theta < 0
          theta + two_pi
        Wend
        While theta >= two_pi
          theta - two_pi
        Wend
        
        ; Mapping polaire → cartésien dans l'image destination
        ; X = angle normalisé × largeur
        ; Y = rayon normalisé × hauteur
        src_x = (theta / two_pi) * lg
        src_y = (r * inv_max_radius) * ht
        
      Else
        ; ===== Mode Polaire → Cartésien =====
        ; L'image rectangulaire source est "enroulée" circulairement
        ; X source = angle, Y source = rayon
        
        ; Lecture des coordonnées polaires depuis l'image rectangulaire
        theta = (x * inv_lg) * two_pi + start_angle
        r = (y * inv_ht) * max_radius
        
        ; Conversion en coordonnées cartésiennes
        src_x = cx + r * Cos(theta)
        src_y = cy + r * Sin(theta)
        
      EndIf

      ; Conversion en entiers
      src_x_int = Int(src_x)
      src_y_int = Int(src_y)

      ; Gestion des limites
      If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
        ; Échantillonnage du pixel source
        offset_src = (src_y_int * lg + src_x_int) * 4
        PokeL(*cible + offset_dst, PeekL(*source + offset_src))
      Else
        ; Pixel hors limites
        If wrap_mode
          ; Mode wrap : bouclage horizontal pour continuité
          If src_x_int < 0
            src_x_int = (src_x_int % lg) + lg
          ElseIf src_x_int >= lg
            src_x_int = src_x_int % lg
          EndIf
          
          ; Vérification Y après wrap
          If src_y_int >= 0 And src_y_int < ht And src_x_int >= 0 And src_x_int < lg
            offset_src = (src_y_int * lg + src_x_int) * 4
            PokeL(*cible + offset_dst, PeekL(*source + offset_src))
          Else
            PokeL(*cible + offset_dst, $00000000)
          EndIf
        Else
          ; Mode noir transparent
          PokeL(*cible + offset_dst, $00000000)
        EndIf
      EndIf

      offset_dst + 4
    Next x
  Next y
EndProcedure


; -------------------------------------------------------------------------------
; PolarTransform - Filtre de transformation polaire
;
; Paramètres:
;   *param.parametre - Structure de paramètres du filtre
;
; Description:
;   Convertit entre coordonnées cartésiennes et polaires, créant des effets
;   spectaculaires de "déroulement" ou "enroulement" circulaire.
;
; Paramètres utilisateur:
;   [0] Mode de transformation (0-1, défaut=0)
;       0 : Cartésien → Polaire (déroule l'image circulairement)
;           - Les cercles deviennent des lignes horizontales
;           - Les rayons deviennent des lignes verticales
;           - Effet "tunnel" ou "vortex déroulé"
;       1 : Polaire → Cartésien (enroule l'image)
;           - Les lignes horizontales deviennent des cercles
;           - Les lignes verticales deviennent des rayons
;           - Création de mandalas, spirales, motifs circulaires
;   [1] Position X du centre (0-100%, défaut=50% = centre)
;   [2] Position Y du centre (0-100%, défaut=50% = centre)
;   [3] Angle de départ (0-360°, défaut=0°)
;       Rotation initiale de la transformation
;   [4] Mode de remplissage (0-1, défaut=1)
;       0 : Noir transparent pour pixels hors limites
;       1 : Wrap (bouclage) pour continuité circulaire
;
; Utilisations:
;   - Création de mandalas à partir d'images simples
;   - Effets de tunnel/vortex
;   - Motifs circulaires et spirales
;   - Transformations de textures cylindriques
;   - Art génératif et motifs radiaux
;   - Visualisations de données polaires
;
; Exemples créatifs:
;   Mode Polaire→Cartésien sur image de dégradé horizontal :
;     → Crée des cercles concentriques parfaits
;   Mode Polaire→Cartésien sur pattern répétitif vertical :
;     → Crée un mandala symétrique radial
;   Mode Cartésien→Polaire sur photo circulaire :
;     → Déroule la photo en panorama rectangulaire
;
; Note mathématique:
;   Cartésien → Polaire : (x,y) → (r,θ) où r=√(x²+y²), θ=atan2(y,x)
;   Polaire → Cartésien : (r,θ) → (x,y) où x=r×cos(θ), y=r×sin(θ)
; -------------------------------------------------------------------------------
Procedure Polar_Transform(*param.parametre)
  Protected i.i

  If *param\info_active
    *param\typ = #FilterType_Deformation
    *param\subtype = 0  ; "Géométrique"
    *param\name = "Polar Transform (Transformation polaire)"
    *param\remarque = "Conversion cartésien↔polaire pour effets de déroulement circulaire"
    
    *param\info[0] = "Mode (0=cart→polar/déroule, 1=polar→cart/enroule)"
    *param\info[1] = "Centre X (% largeur)"
    *param\info[2] = "Centre Y (% hauteur)"
    *param\info[3] = "Angle de départ (degrés)"
    *param\info[4] = "Remplissage (0=noir, 1=wrap)"
    *param\info[5] = "masque"
    
    ; Configuration mode (0-1, défaut 0 = cartésien→polaire)
    *param\info_data(0, 0) = 0
    *param\info_data(0, 1) = 1
    *param\info_data(0, 2) = 0
    
    ; Configuration centre X (0-100%, défaut 50% = centre)
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Configuration centre Y (0-100%, défaut 50% = centre)
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 50
    
    ; Configuration angle de départ (0-360°, défaut 0°)
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 360
    *param\info_data(3, 2) = 0
    
    ; Configuration mode de remplissage (0-1, défaut 1=wrap)
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 1
    *param\info_data(4, 2) = 1
    
    ; Configuration du masque
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 2
    *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-threadé (5 paramètres, 1 buffer destination)
  filter_start(@PolarTransform_MT(), 5, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 197
; FirstLine = 180
; Folding = -
; EnableXP
; DPIAware