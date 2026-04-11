Procedure emboss_MT(*p.parametre)
  ; ============================================================================
  ; DÉCLARATION DES VARIABLES
  ; ============================================================================
  
  ; --- Dimensions de l'image ---
  Protected w = *p\lg  ; Largeur de l'image en pixels
  Protected h = *p\ht  ; Hauteur de l'image en pixels
  
  ; --- Coordonnées ---
  Protected x, y       ; Position actuelle du pixel traité
  
  ; --- Composantes ARGB ---
  Protected a, r, g, b              ; Alpha, Rouge, Vert, Bleu du pixel de sortie
  Protected rL, gL, bL, rR, gR, bR  ; RGB des pixels gauche (Left) et droite (Right)
  Protected rU, gU, bU, rD, gD, bD  ; RGB des pixels haut (Up) et bas (Down)
  Protected rC, gC, bC              ; RGB du pixel central (Center)
  
  ; --- Niveaux de gris ---
  Protected grayL.f, grayR.f        ; Intensité lumineuse des pixels gauche/droite
  Protected grayU.f, grayD.f        ; Intensité lumineuse des pixels haut/bas
  
  ; --- Gradients ---
  Protected dx.f, dy.f              ; Différence de hauteur selon X et Y
  
  ; --- Vecteur normale ---
  Protected nx.f, ny.f, nz.f        ; Composantes du vecteur normal à la surface
  Protected len.f                   ; Longueur du vecteur (pour normalisation)
  
  ; --- Pointeurs mémoire ---
  Protected *src.Pixel32            ; Pointeur vers pixel source (lecture)
  Protected *dst.Pixel32            ; Pointeur vers pixel destination (écriture)
  
  ; ============================================================================
  ; LECTURE DES PARAMÈTRES
  ; ============================================================================
  
  ; --- Force de l'effet ---
  Protected strength.f = *p\option[0] * 0.01  ; Hauteur du relief (1-100 -> 0.01-1.0)
  
  ; --- Options booléennes ---
  Protected invertY    = *p\option[1]  ; Inverser l'axe Y (1=oui, 0=non)
  Protected renforcer  = *p\option[2]  ; Quadrupler la force (1=oui, 0=non)
  
  ; --- Mode de rendu ---
  Protected lightMode  = *p\option[3]  ; 0=Normal map, 1=Emboss couleur, 2=Relief N&B
  
  ; --- Direction de la lumière ---
  ; Convertit les degrés (0-359°) en radians pour les calculs trigonométriques
  Protected lightAngle.f = *p\option[4] * #PI / 180.0      ; Rotation horizontale
  Protected lightElevation.f = *p\option[5] * #PI / 180.0  ; Hauteur (0°=ras, 90°=zénith)
  
  ; --- Calcul du vecteur lumière 3D ---
  ; Utilise les coordonnées sphériques pour créer un vecteur directionnel
  Protected lx.f = Cos(lightAngle) * Cos(lightElevation)  ; Composante X
  Protected ly.f = Sin(lightAngle) * Cos(lightElevation)  ; Composante Y
  Protected lz.f = Sin(lightElevation)                     ; Composante Z (hauteur)
  
  ; --- Validation de la force ---
  If strength <= 0.0 : strength = 0.01 : EndIf  ; Évite division par zéro
  If renforcer : strength * 4.0 : EndIf         ; Multiplie par 4 si demandé
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  ; Divise l'image en bandes horizontales pour traitement parallèle
  
  Protected startY = (*p\thread_pos * h) / *p\thread_max      ; Ligne de début
  Protected endY   = ((*p\thread_pos + 1) * h) / *p\thread_max ; Ligne de fin
  
  ; --- Protection des bordures ---
  ; On évite la première et dernière ligne car on a besoin des pixels voisins
  If startY < 1 : startY = 1 : EndIf        ; Commence à la ligne 1 minimum
  If endY > h - 1 : endY = h - 1 : EndIf    ; Termine à l'avant-dernière ligne
  
  ; ============================================================================
  ; TRAITEMENT PRINCIPAL - BOUCLE SUR CHAQUE PIXEL
  ; ============================================================================
  
  For y = startY To endY - 1
    For x = 1 To w - 2  ; On évite les colonnes extrêmes (besoin de voisins)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 1 : LECTURE DU PIXEL CENTRAL
      ; ------------------------------------------------------------------------
      *src = *p\addr[0] + ((y * w + x) << 2)  ; Calcul adresse mémoire
      ; Formule : (ligne × largeur + colonne) × 4 bytes par pixel
      GetARGB(*src\l, a, rC, gC, bC)          ; Extraction des composantes ARGB
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 2 : LECTURE DES 4 PIXELS VOISINS
      ; ------------------------------------------------------------------------
      ; Ces pixels servent à calculer le gradient (variation de hauteur)
      
      ; Pixel GAUCHE (x-1)
      *src = *p\addr[0] + ((y * w + (x - 1)) << 2)
      GetARGB(*src\l, a, rL, gL, bL)
      
      ; Pixel DROITE (x+1)
      *src = *p\addr[0] + ((y * w + (x + 1)) << 2)
      GetARGB(*src\l, a, rR, gR, bR)
      
      ; Pixel HAUT (y-1)
      *src = *p\addr[0] + (((y - 1) * w + x) << 2)
      GetARGB(*src\l, a, rU, gU, bU)
      
      ; Pixel BAS (y+1)
      *src = *p\addr[0] + (((y + 1) * w + x) << 2)
      GetARGB(*src\l, a, rD, gD, bD)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 3 : CONVERSION EN NIVEAUX DE GRIS (HEIGHT MAP)
      ; ------------------------------------------------------------------------
      ; On transforme chaque pixel en valeur de hauteur (0-255)
      ; Formule simple : moyenne des 3 canaux RGB
      
      grayL = (rL + gL + bL) * 0.333333  ; ≈ (rL + gL + bL) / 3
      grayR = (rR + gR + bR) * 0.333333
      grayU = (rU + gU + bU) * 0.333333
      grayD = (rD + gD + bD) * 0.333333
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 4 : CALCUL DU GRADIENT (PENTE)
      ; ------------------------------------------------------------------------
      ; Le gradient mesure la variation de hauteur selon X et Y
      ; C'est la différence entre pixels opposés
      
      dx = (grayR - grayL) * strength  ; Pente horizontale (positif = monte vers droite)
      dy = (grayD - grayU) * strength  ; Pente verticale (positif = monte vers bas)
      
      If invertY : dy = -dy : EndIf    ; Inverse la direction Y si demandé
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 5 : CALCUL DU VECTEUR NORMAL
      ; ------------------------------------------------------------------------
      ; La normale est perpendiculaire à la surface
      ; Elle indique "vers où pointe" la surface en ce point
      
      nx = -dx  ; Composante X (inversée car normale ⊥ gradient)
      ny = -dy  ; Composante Y
      nz = 1.0  ; Composante Z (toujours vers le haut)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 6 : NORMALISATION DU VECTEUR
      ; ------------------------------------------------------------------------
      ; On ramène le vecteur à une longueur de 1 (vecteur unitaire)
      ; Ceci est nécessaire pour les calculs d'éclairage corrects
      
      len = Sqr(nx*nx + ny*ny + nz*nz)  ; Longueur = √(x² + y² + z²)
      
      If len > 0.0001  ; Évite division par zéro
        nx / len       ; nx = nx / longueur
        ny / len
        nz / len
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 7 : RENDU SELON LE MODE CHOISI
      ; ------------------------------------------------------------------------
      
      Select lightMode
        
        ; ......................................................................
        Case 0  ; MODE NORMAL MAP
        ; ......................................................................
        ; Encode le vecteur normal en RGB pour utilisation en 3D
        ; Vecteur (-1 à +1) → Couleur (0 à 255)
        
        r = Int((nx * 0.5 + 0.5) * 255)  ; -1→0, 0→128, +1→255
        g = Int((ny * 0.5 + 0.5) * 255)
        b = Int((nz * 0.5 + 0.5) * 255)  ; Toujours bleuté (nz≈1)
        
        ; ......................................................................
        Case 1  ; MODE EMBOSS AVEC COULEUR
        ; ......................................................................
        ; Applique un éclairage directionnel sur les couleurs originales
        
        ; Produit scalaire : mesure l'alignement entre normale et lumière
        ; dot = 1  → surface face à la lumière (très éclairée)
        ; dot = 0  → surface perpendiculaire (ombre)
        ; dot = -1 → surface dos à la lumière (très sombre)
        Protected dot.f = nx * lx + ny * ly + nz * lz
        
        If dot < 0.0 : dot = 0.0 : EndIf  ; Pas d'éclairage négatif
        
        ; Formule d'éclairage : couleur × (lumière ambiante + lumière directionnelle)
        ; 0.3 = 30% de lumière ambiante (toujours présente)
        ; 0.7 = 70% de lumière directionnelle (selon orientation)
        r = Int(rC * (0.3 + 0.7 * dot))
        g = Int(gC * (0.3 + 0.7 * dot))
        b = Int(bC * (0.3 + 0.7 * dot))
        
        ; ......................................................................
        Case 2  ; MODE EMBOSS RELIEF (NOIR & BLANC)
        ; ......................................................................
        ; Crée un effet de relief en niveaux de gris
        
        Protected dot2.f = nx * lx + ny * ly + nz * lz
        
        ; Convertit (-1 à +1) en (0 à 255)
        ; dot2 = -1 → intensity = 1 (noir)
        ; dot2 = 0  → intensity = 128 (gris)
        ; dot2 = +1 → intensity = 255 (blanc)
        Protected intensity.f = 128 + dot2 * 127
        
        If intensity < 0 : intensity = 0 : EndIf
        If intensity > 255 : intensity = 255 : EndIf
        
        r = Int(intensity)  ; Même valeur pour R, G, B = gris
        g = Int(intensity)
        b = Int(intensity)
        
      EndSelect
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 8 : CLAMPING (LIMITATION DES VALEURS)
      ; ------------------------------------------------------------------------
      ; S'assure que les valeurs RGB restent dans [0, 255]
      
      If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 9 : ÉCRITURE DU PIXEL RÉSULTAT
      ; ------------------------------------------------------------------------
      
      *dst = *p\addr[1] + ((y * w + x) << 2)  ; Adresse dans buffer destination
      
      ; Assemblage du pixel au format ARGB 32 bits :
      ; Bit 24-31 : Alpha (255 = opaque)
      ; Bit 16-23 : Rouge
      ; Bit 8-15  : Vert
      ; Bit 0-7   : Bleu
      *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      
    Next  ; Pixel suivant (x)
  Next    ; Ligne suivante (y)
  
EndProcedure

; ==============================================================================
; PROCÉDURE D'INITIALISATION DU FILTRE
; ==============================================================================

Procedure emboss(*param.parametre)
  
  ; Si appelé en mode "info", on configure les paramètres de l'interface
  If *param\info_active
    
    ; --- Métadonnées du filtre ---
    *param\typ = #FilterType_Artistic         ; Catégorie : artistique
    *param\subtype = #Artistic_Other
    *param\name = "Emboss avec Lumière"       ; Nom affiché
    *param\remarque = "Effet emboss avec contrôle directionnel de la lumière"
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 0 : HAUTEUR DU RELIEF
    ; --------------------------------------------------------------------------
    *param\info[0] = "Hauteur"
    *param\info_data(0, 0) = 1     ; Valeur minimale
    *param\info_data(0, 1) = 100   ; Valeur maximale
    *param\info_data(0, 2) = 30    ; Valeur par défaut
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 1 : INVERSER L'AXE Y
    ; --------------------------------------------------------------------------
    *param\info[1] = "Inverser Y"
    *param\info_data(1, 0) = 0     ; Min = 0 (désactivé)
    *param\info_data(1, 1) = 1     ; Max = 1 (activé)
    *param\info_data(1, 2) = 0     ; Défaut = désactivé
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 2 : RENFORCER L'EFFET (×4)
    ; --------------------------------------------------------------------------
    *param\info[2] = "Renforcer (×4)"
    *param\info_data(2, 0) = 0     ; Désactivé
    *param\info_data(2, 1) = 1     ; Activé
    *param\info_data(2, 2) = 0     ; Défaut = désactivé
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 3 : MODE DE RENDU
    ; --------------------------------------------------------------------------
    *param\info[3] = "Mode (0=Normal/1=Couleur/2=Relief)"
    *param\info_data(3, 0) = 0     ; 0 = Normal map
    *param\info_data(3, 1) = 2     ; 2 = Relief N&B
    *param\info_data(3, 2) = 1     ; Défaut = Emboss couleur
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 4 : ANGLE DE LA LUMIÈRE (ROTATION)
    ; --------------------------------------------------------------------------
    *param\info[4] = "Angle lumière (0-359°)"
    *param\info_data(4, 0) = 0     ; 0° = lumière vient de l'est
    *param\info_data(4, 1) = 359   ; 359° = presque un tour complet
    *param\info_data(4, 2) = 135   ; 135° = nord-ouest (classique emboss)
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 5 : ÉLÉVATION DE LA LUMIÈRE
    ; --------------------------------------------------------------------------
    *param\info[5] = "Élévation lumière (0-89°)"
    *param\info_data(5, 0) = 0     ; 0° = lumière rasante (horizontale)
    *param\info_data(5, 1) = 89    ; 89° = presque au zénith
    *param\info_data(5, 2) = 45    ; 45° = hauteur moyenne
    
    *param\info[6] = "masque"
    *param\info_data(6, 0) = 0 
    *param\info_data(6, 1) = 2
    *param\info_data(6, 2) = 0
    ProcedureReturn  ; Sort sans lancer le traitement
  EndIf
  
  ; Si pas en mode "info", on lance le traitement multithreadé
  ; Paramètres : fonction worker, nombre de passes, nombre de buffers
  filter_start(@emboss_MT(), 3, 1)
  
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 251
; FirstLine = 242
; Folding = -
; EnableXP
; DPIAware