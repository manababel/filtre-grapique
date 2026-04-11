; ==============================================================================
; FILTRE CARTOON / TOON SHADING
; ==============================================================================
; Transforme une image en dessin animé avec détection de contours et 
; quantification des couleurs
; ==============================================================================

Procedure cartoon_MT(*p.parametre)
  ; ============================================================================
  ; DÉCLARATION DES VARIABLES
  ; ============================================================================
  
  ; --- Dimensions de l'image ---
  Protected w = *p\lg
  Protected h = *p\ht
  
  ; --- Coordonnées ---
  Protected x, y
  
  ; --- Composantes ARGB ---
  Protected a, r, g, b
  Protected rC, gC, bC
  Protected r1, g1, b1, r2, g2, b2
  Protected r3, g3, b3, r4, g4, b4
  
  ; --- Détection de contours ---
  Protected.f gx, gy, edge
  
  ; --- Niveaux de gris ---
  Protected.f grayC, gray1, gray2, gray3, gray4
  
  ; --- Quantification ---
  Protected levels, qr, qg, qb
  
  ; --- Pointeurs mémoire ---
  Protected *src.Pixel32, *dst.Pixel32
  
  ; ============================================================================
  ; LECTURE ET VALIDATION DES PARAMÈTRES
  ; ============================================================================
  
  ; Paramètre 0 : Niveaux de couleur (2-32)
  levels = *p\option[0]
  clamp(levels, 2, 32)
  
  ; Paramètre 1 : Sensibilité des contours (0.01-1.0)
  Protected.f edgeStrength = *p\option[1] * 0.01
  clamp(edgeStrength, 0.01, 1.0)
  
  ; Paramètre 2 : Seuil de détection (0.01-1.0)
  Protected.f edgeThreshold = *p\option[2] * 0.01
  clamp(edgeThreshold, 0.01, 1.0)
  
  ; Paramètre 3 : Mode de rendu (0-3)
  Protected renderMode = *p\option[3]
  clamp(renderMode, 0, 3)
  
  ; Paramètre 4 : Couleur des contours (0-2)
  Protected edgeColor = *p\option[4]
  clamp(edgeColor, 0, 2)
  
  ; Paramètre 5 : Lissage (0-3)
  Protected smoothing = *p\option[5]
  clamp(smoothing, 0, 3)
  
  ; ============================================================================
  ; PRÉCALCULS (optimisation)
  ; ============================================================================
  
  Protected.f stepSize = 255.0 / (levels - 1)
  Protected.f invStepSize = 1.0 / stepSize
  Protected.f smoothBlend = smoothing ;* 0.15
  Protected.f invSmoothBlend = 1.0 - smoothBlend
  Protected.f invEdgeThreshold
  If edgeThreshold < 1.0
    invEdgeThreshold = 1.0 / (1.0 - edgeThreshold)
  Else
    invEdgeThreshold = 1.0
  EndIf
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  
  Protected startY = (*p\thread_pos * h) / *p\thread_max
  Protected endY = ((*p\thread_pos + 1) * h) / *p\thread_max
  
  ; Protection des bordures (nécessaire pour Sobel)
  clamp(startY, 1, h - 2)
  clamp(endY, 1, h - 1)
  
  ; ============================================================================
  ; TRAITEMENT PRINCIPAL
  ; ============================================================================
  
  Protected wBytes = w << 2  ; Largeur en bytes (optimisation)
  Protected offset.l
  
  For y = startY To endY - 1
    
    ; Calcul de l'offset de ligne (optimisation)
    offset = y * wBytes
    
    For x = 1 To w - 2
      
      ; ------------------------------------------------------------------------
      ; LECTURE DU PIXEL CENTRAL ET VOISINS
      ; ------------------------------------------------------------------------
      
      *src = *p\addr[0] + offset + (x << 2)
      GetARGB(*src\l, a, rC, gC, bC)
      
      ; Pixel GAUCHE
      *src - 4
      GetARGB(*src\l, a, r1, g1, b1)
      
      ; Pixel DROITE
      *src + 8
      GetARGB(*src\l, a, r2, g2, b2)
      
      ; Pixel HAUT
      *src = *p\addr[0] + offset - wBytes + (x << 2)
      GetARGB(*src\l, a, r3, g3, b3)
      
      ; Pixel BAS
      *src = *p\addr[0] + offset + wBytes + (x << 2)
      GetARGB(*src\l, a, r4, g4, b4)
      
      ; ------------------------------------------------------------------------
      ; CONVERSION EN NIVEAUX DE GRIS (luminance perceptuelle)
      ; ------------------------------------------------------------------------
      
      RGBtoGrayF(grayC, rC, gC, bC)
      RGBtoGrayF(gray1, r1, g1, b1)
      RGBtoGrayF(gray2, r2, g2, b2)
      RGBtoGrayF(gray3, r3, g3, b3)
      RGBtoGrayF(gray4, r4, g4, b4)
      
      ; ------------------------------------------------------------------------
      ; DÉTECTION DE CONTOURS (Sobel simplifié)
      ; ------------------------------------------------------------------------
      
      gx = (gray2 - gray1) * edgeStrength
      gy = (gray4 - gray3) * edgeStrength
      
      ; Magnitude du gradient
      edge = Sqr(gx * gx + gy * gy)
      clamp(edge, 0.0, 255.0)
      edge = edge / 255.0
      
      ; ------------------------------------------------------------------------
      ; QUANTIFICATION DES COULEURS
      ; ------------------------------------------------------------------------
      
      qr = Int(rC * invStepSize + 0.5) * stepSize
      qg = Int(gC * invStepSize + 0.5) * stepSize
      qb = Int(bC * invStepSize + 0.5) * stepSize
      
      ; Lissage optionnel
      If smoothing > 0
        qr = qr * invSmoothBlend + rC * smoothBlend
        qg = qg * invSmoothBlend + gC * smoothBlend
        qb = qb * invSmoothBlend + bC * smoothBlend
      EndIf
      
      ; ------------------------------------------------------------------------
      ; RENDU SELON LE MODE
      ; ------------------------------------------------------------------------
      
      Select renderMode
        
        Case 0  ; CARTOON COMPLET
          
          If edge > edgeThreshold
            ; Définir la couleur de contour
            Select edgeColor
              Case 0 : r = 0 : g = 0 : b = 0          ; Noir
              Case 1 : r = 255 : g = 255 : b = 255    ; Blanc
              Case 2 : r = 255 - qr : g = 255 - qg : b = 255 - qb  ; Inversé
            EndSelect
            
            ; Transition douce contour/couleur
            Protected.f edgeMix = (edge - edgeThreshold) * invEdgeThreshold
            clamp(edgeMix, 0.0, 1.0)
            
            r = qr * (1.0 - edgeMix) + r * edgeMix
            g = qg * (1.0 - edgeMix) + g * edgeMix
            b = qb * (1.0 - edgeMix) + b * edgeMix
          Else
            r = qr : g = qg : b = qb
          EndIf
        
        Case 1  ; CONTOURS SEULS
          
          If edge > edgeThreshold
            Select edgeColor
              Case 0 : r = 0 : g = 0 : b = 0
              Case 1 : r = 255 : g = 255 : b = 255
              Case 2 : r = 255 - rC : g = 255 - gC : b = 255 - bC
            EndSelect
          Else
            r = 255 : g = 255 : b = 255  ; Fond blanc
          EndIf
        
        Case 2  ; COULEURS SEULES
          
          r = qr : g = qg : b = qb
        
        Case 3  ; SKETCH
          
          Protected sketch = Int((1.0 - edge) * 255)
          r = sketch : g = sketch : b = sketch
        
      EndSelect
      
      ; ------------------------------------------------------------------------
      ; CLAMPING ET ÉCRITURE
      ; ------------------------------------------------------------------------
      
      clamp_rgb(r,g,b)
      
      *dst = *p\addr[1] + offset + (x << 2)
      *dst\l = $FF000000 | (r << 16) | (g << 8) | b
      
    Next
  Next
  
EndProcedure

; ==============================================================================
; INITIALISATION DU FILTRE
; ==============================================================================

Procedure cartoon(*param.parametre)
  
  If *param\info_active
    
    ; Métadonnées
    *param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Other
    *param\name = "Cartoon / Toon Shading"
    *param\remarque = "Transforme l'image en dessin animé avec contours et couleurs quantifiées"
    
    ; Paramètre 0 : Niveaux de couleur
    *param\info[0] = "Niveaux de couleur"
    *param\info_data(0, 0) = 2
    *param\info_data(0, 1) = 32
    *param\info_data(0, 2) = 6
    
    ; Paramètre 1 : Sensibilité contours
    *param\info[1] = "Sensibilité contours"
    *param\info_data(1, 0) = 1
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50
    
    ; Paramètre 2 : Épaisseur contours
    *param\info[2] = "Épaisseur contours"
    *param\info_data(2, 0) = 1
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 30
    
    ; Paramètre 3 : Mode de rendu
    *param\info[3] = "Mode"; (0=Cartoon/1=Contours/2=Couleurs/3=Sketch)"
    *param\info_data(3, 0) = 0
    *param\info_data(3, 1) = 3
    *param\info_data(3, 2) = 0
    
    ; Paramètre 4 : Couleur contours
    *param\info[4] = "Couleur contours"; (0=Noir/1=Blanc/2=Inversé)"
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 2
    *param\info_data(4, 2) = 0
    
    ; Paramètre 5 : Lissage
    *param\info[5] = "Lissage"; (0=Aucun/1=Léger/2=Moyen/3=Fort)"
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 3
    *param\info_data(5, 2) = 1
    
    ; Paramètre 6 : Masque
    *param\info[6] = "masque"
    *param\info_data(6, 0) = 0
    *param\info_data(6, 1) = 2
    *param\info_data(6, 2) = 0
    
    ProcedureReturn
  EndIf
  
  filter_start(@cartoon_MT(), 3, 1)
  
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 71
; FirstLine = 31
; Folding = -
; EnableXP
; DPIAware