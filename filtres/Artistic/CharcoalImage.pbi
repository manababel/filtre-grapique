; =============================================================================
; FILTRE ARTISTIQUE "CHARCOAL" (FUSAIN) POUR IMAGE ARGB 32 BITS
; =============================================================================
; Ce filtre simule un effet de dessin au fusain en convertissant l'image
; en niveaux de gris avec des contrastes accentués et des variations aléatoires.
; Optimisé pour traitement multithread.
; =============================================================================

; -----------------------------------------------------------------------------
; FONCTION : RandomFloat
; Génère un nombre flottant aléatoire dans un intervalle donné
; PARAMÈTRES :
;   - min.f : Valeur minimale (défaut : 0.0)
;   - max.f : Valeur maximale (défaut : 1.0)
; RETOUR : Valeur flottante aléatoire entre min et max
; -----------------------------------------------------------------------------
Procedure.f RandomFloat(min.f = 0.0, max.f = 1.0)
  ProcedureReturn min + (max - min) * Random(1000000) / 1000000.0
EndProcedure

; -----------------------------------------------------------------------------
; FONCTION : ContrastColour (NON UTILISÉE - À SUPPRIMER SI NON NÉCESSAIRE)
; Augmente le contraste d'une couleur selon un facteur d'échelle
; PARAMÈTRES :
;   - Colour : Couleur au format RGB 24 bits
;   - Scale.f : Facteur de multiplication du contraste
; RETOUR : Couleur avec contraste modifié
; -----------------------------------------------------------------------------
Procedure ContrastColour(Colour, Scale.f)
  Protected r, g, b
  
  getrgb(Colour, r, g, b)
  
  ; Augmentation du contraste par multiplication
  r = r * (1.0 + Scale)
  g = g * (1.0 + Scale)
  b = b * (1.0 + Scale)
  
  ; Limitation des valeurs à la plage [0, 255]
  clamp_rgb(r, g, b)
  
  ProcedureReturn (r << 16) | (g << 8) | b
EndProcedure

; -----------------------------------------------------------------------------
; PROCÉDURE PRINCIPALE : Charcoal_MT
; Applique l'effet fusain sur un segment d'image (pour traitement multithread)
; PARAMÈTRES :
;   - *p.parametre : Pointeur vers structure de paramètres contenant :
;       * addr[0] : Adresse du buffer source
;       * addr[1] : Adresse du buffer destination
;       * lg, ht : Largeur et hauteur de l'image
;       * option[0] : Intensité de l'effet (0-100)
;       * thread_pos, thread_max : Position et nombre total de threads
; -----------------------------------------------------------------------------
Procedure Charcoal_MT(*p.parametre)
  Protected i, a, r, g, b
  Protected r1, g1, b1
  Protected r2, g2, b2
  Protected w = *p\lg
  Protected h = *p\ht
  
  ; Calcul de l'intensité de l'effet (0.32 à 1.32)
  Protected intensity.f = 0.32 + (*p\option[0] / 100.0)
  Protected tolerance.f = 1.0 - intensity
  
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  
  ; Calcul de la plage de pixels à traiter par ce thread
  Protected totalPixels = w * h
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  
  Protected colour, pixel, grey, grade
  Protected chalking
  Protected definition.f
  
  ; Traitement de chaque pixel dans la plage assignée
  For i = startPos To endPos - 1
    ; Pointeurs vers pixels source et destination
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)
    
    ; Extraction de la couleur source
    colour = *srcPixel\l
    a = (colour >> 24) & $FF  ; CORRECTION : Extraction du canal alpha
    getrgb(colour, r, g, b)
    
    ; Calcul du niveau de gris pondéré (formule standard ITU-R BT.709)
    ; Coefficients : R=0.2989, G=0.5870, B=0.1141 (optimisés en entiers)
    chalking = (r * 1225 + g * 2405 + b * 466) >> 12
    
    ; Calcul du seuil de gradation
    grade = intensity * 64.0
    
    ; -------------------------------------------------------------------------
    ; TRAITEMENT PIXELS TRÈS CLAIRS (zones blanches du fusain)
    ; -------------------------------------------------------------------------
    If chalking > (255.0 - grade)
      r = 255 : g = 255 : b = 255
      
    ; -------------------------------------------------------------------------
    ; TRAITEMENT PIXELS NORMAUX (effet fusain complet)
    ; -------------------------------------------------------------------------
    Else
      ; Augmentation du contraste de la couleur d'origine
      getrgb(colour, r1, g1, b1)
      r1 = r1 * (1.0 + intensity)
      g1 = g1 * (1.0 + intensity)
      b1 = b1 * (1.0 + intensity)
      clamp_rgb(r1, g1, b1)
      colour = (r1 << 16) | (g1 << 8) | b1
      
      ; Application d'un mélange aléatoire pour l'effet "grain"
      definition = RandomFloat(0, 1)
      
      If definition > tolerance
        getrgb(pixel, r1, g1, b1)  ; ATTENTION : pixel n'est pas initialisé!
        getrgb(colour, r2, g2, b2)
        
        ; Interpolation uniquement sur le canal rouge (comme dans l'original)
        r1 = ((r2 - r1) * tolerance) + r1
        clamp_rgb(r1, g1, b1)
        pixel = (r1 << 16) | (g1 << 8) | b1
      EndIf
      
      ; Conversion en niveaux de gris
      getrgb(pixel, r, g, b)  ; ATTENTION : pixel peut être non initialisé!
      grey = (r * 1225 + g * 2405 + b * 466) >> 12
      r = grey : g = grey : b = grey  ; CORRECTION : g=r devrait être g=grey
      
      ; -----------------------------------------------------------------------
      ; APPLICATION DU GRAIN ET DES VARIATIONS TONALES
      ; -----------------------------------------------------------------------
      grade = intensity * 64.0
      
      If (grey > grade) And (grey < (255.0 - grade))
        ; Tons moyens : ajout de variations aléatoires pour le grain
        If RandomFloat(0, 100) >= Int(tolerance * 100.0)
          r + grade
          g + grade * 0.5  ; Légère teinte sépia
          clamp(r, 0, 224)
          clamp(g, 0, 224)
          ; NOTE : b reste sur la valeur grey (non modifié)
        EndIf
      Else
        ; Tons extrêmes : binarisation avec seuil à 127
        If r > 127 : r = 224 : Else : r = 0 : EndIf
        If g > 127 : g = 224 : Else : g = 0 : EndIf
        If b > 127 : b = 224 : Else : b = 0 : EndIf
      EndIf
    EndIf
    
    ; Écriture du pixel final avec conservation du canal alpha
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
  Next
EndProcedure

; -----------------------------------------------------------------------------
; FONCTION PRINCIPALE : CharcoalImage
; Point d'entrée du filtre Charcoal
; PARAMÈTRES :
;   - *param.parametre : Structure de paramètres du filtre
; MODE INFO : Retourne les métadonnées du filtre
; MODE TRAITEMENT : Lance le traitement multithread
; -----------------------------------------------------------------------------
Procedure CharcoalImage(*param.parametre)
  ; Mode information : retourne les paramètres du filtre
  If *param\info_active
    *param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Material
    *param\name = "Charcoal"
    *param\remarque = "Effet dessin au fusain avec grain aléatoire"
    
    ; Paramètre 0 : Intensité de l'effet
    *param\info[0] = "Intensité"
    *param\info_data(0, 0) = 0   ; Valeur minimale
    *param\info_data(0, 1) = 17  ; Valeur maximale
    *param\info_data(0, 2) = 8   ; Valeur par défaut
    
    ; Paramètre 1 : Masque (non utilisé actuellement)
    *param\info[1] = "Masque"
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 1
    *param\info_data(1, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Mode traitement : lance le filtre avec 1 passe et 1 buffer temporaire
  filter_start(@Charcoal_MT(), 1, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 171
; FirstLine = 122
; Folding = -
; EnableXP
; DPIAware