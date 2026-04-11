;==============================================================================
; GLOWEFFECT_IIR - Filtre d'effet de luminosité avec flou IIR
;==============================================================================
; Crée un effet de halo lumineux autour des zones brillantes de l'image
; Utilise un filtre IIR (Infinite Impulse Response) pour un flou rapide
; 
; Algorithme :
; 1. Extraction des zones lumineuses (au-dessus d'un seuil)
; 2. Flou IIR horizontal bidirectionnel (gauche→droite puis droite→gauche)
; 3. Flou IIR vertical bidirectionnel (haut→bas puis bas→haut)
; 4. Addition du glow à l'image originale avec intensité contrôlée
;==============================================================================

;------------------------------------------------------------------------------
; Macro de déclaration des variables communes à tous les threads
; Centralise l'initialisation pour éviter la duplication de code
;------------------------------------------------------------------------------
Macro GlowEffect_IIR_DeclareVars()
  ; Pointeurs vers les buffers image
  Protected *source = *param\addr[0]  ; Image source
  Protected *cible  = *param\addr[1]  ; Image destination
  
  ; Dimensions de l'image
  Protected w = *param\lg
  Protected h = *param\ht
  
  ; Calcul de la plage de lignes/colonnes pour ce thread
  Protected start = (*param\thread_pos * h) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * h) / *param\thread_max
  
  ; Variables de travail
  Protected x, y        ; Coordonnées de pixel
  Protected pos         ; Offset mémoire du pixel courant
  Protected col         ; Couleur ARGB complète
  Protected a, r, g, b  ; Composantes de couleur
  Protected lum         ; Luminosité calculée
  
  ; Paramètres du filtre
  Protected GlowStrength = *param\option[0]  ; Intensité du glow (0-100)
  Protected Radius = 50 - *param\option[1]   ; Rayon du flou (inversé pour UI)
  Protected seuil = *param\option[2]         ; Seuil de luminosité (0-255)
  
  ; Calcul des coefficients IIR (filtre exponentiel)
  Protected mul = 256  ; Facteur de multiplication pour arithmétique entière
  Protected Alpha = (Exp(-2.3 / (Radius + 1.0))) * mul
  Protected inv_Alpha = mul - Alpha
  
  ; Pointeurs vers les buffers de travail RGB séparés
  Protected glowR = *param\addr[2]  ; Canal rouge du glow
  Protected glowG = *param\addr[3]  ; Canal vert du glow
  Protected glowB = *param\addr[4]  ; Canal bleu du glow
  
  ; Variables temporaires pour optimiser les accès mémoire
  Protected.l rVal, gVal, bVal
EndMacro

;------------------------------------------------------------------------------
; Macro d'application du filtre IIR sur un pixel
; Filtre récursif : nouvelle_valeur = Alpha * ancienne + (1-Alpha) * source
; Utilise l'arithmétique entière pour la performance
;------------------------------------------------------------------------------
Macro GlowEffect_IIR_ApplyFilter()
  ; Lecture des valeurs depuis les buffers de glow
  rVal = PeekL(glowR + pos)
  gVal = PeekL(glowG + pos)
  bVal = PeekL(glowB + pos)
  
  ; Application du filtre IIR avec arithmétique entière (division par 256 = >> 8)
  r = (Alpha * r + inv_Alpha * rVal) >> 8
  g = (Alpha * g + inv_Alpha * gVal) >> 8
  b = (Alpha * b + inv_Alpha * bVal) >> 8
  
  ; Écriture des résultats filtrés
  PokeL(glowR + pos, r)
  PokeL(glowG + pos, g)
  PokeL(glowB + pos, b)
EndMacro

;------------------------------------------------------------------------------
; ÉTAPE 1 : Extraction des zones lumineuses
; Sélectionne uniquement les pixels au-dessus du seuil de luminosité
;------------------------------------------------------------------------------
Procedure GlowEffect_IIR_MT_ExtractBright(*param.parametre)
  GlowEffect_IIR_DeclareVars()
  
  For y = start To stop - 1
    For x = 0 To w - 1
      pos = (y * w + x) << 2  ; Offset = (y*width + x) * 4 octets
      col = PeekL(*source + pos)
      
      ; Extraction des composantes RGB (pas besoin d'Alpha ici)
      r = (col >> 16) & $FF
      g = (col >> 8) & $FF
      b = col & $FF
      
      ; Calcul de luminosité perceptuelle (formule ITU-R BT.601)
      ; Approximation rapide : Y = 0.299*R + 0.587*G + 0.114*B
      ; En entiers : Y = (77*R + 151*G + 28*B) / 256
      lum = (r * 77 + g * 151 + b * 28) >> 8
      
      ; Sélection des zones lumineuses (au-dessus du seuil)
      If lum > seuil
        PokeL(glowR + pos, r)
        PokeL(glowG + pos, g)
        PokeL(glowB + pos, b)
      Else
        ; Zones sombres = pas de glow
        PokeL(glowR + pos, 0)
        PokeL(glowG + pos, 0)
        PokeL(glowB + pos, 0)
      EndIf
    Next
  Next
EndProcedure

;------------------------------------------------------------------------------
; ÉTAPE 2 : Flou IIR horizontal bidirectionnel
; Passe de gauche à droite puis de droite à gauche pour éviter les biais
;------------------------------------------------------------------------------
Procedure GlowEffect_IIR_MT_BlurHorizontal(*param.parametre)
  GlowEffect_IIR_DeclareVars()
  
  For y = start To stop - 1
    ; === Passe gauche → droite ===
    pos = (y * w) << 2
    
    ; Initialisation avec le premier pixel de la ligne
    r = PeekL(glowR + pos)
    g = PeekL(glowG + pos)
    b = PeekL(glowB + pos)
    
    ; Application du filtre IIR de gauche à droite
    For x = 1 To w - 1
      pos = (y * w + x) << 2
      GlowEffect_IIR_ApplyFilter()
    Next
    
    ; === Passe droite → gauche ===
    pos = (y * w + (w - 1)) << 2
    
    ; Initialisation avec le dernier pixel de la ligne
    r = PeekL(glowR + pos)
    g = PeekL(glowG + pos)
    b = PeekL(glowB + pos)
    
    ; Application du filtre IIR de droite à gauche
    For x = w - 2 To 0 Step -1
      pos = (y * w + x) << 2
      GlowEffect_IIR_ApplyFilter()
    Next
  Next
EndProcedure

;------------------------------------------------------------------------------
; ÉTAPE 3 : Flou IIR vertical bidirectionnel
; Passe de haut en bas puis de bas en haut pour éviter les biais
; Note : Traite les colonnes au lieu des lignes (start/stop redéfinis)
;------------------------------------------------------------------------------
Procedure GlowEffect_IIR_MT_BlurVertical(*param.parametre)
  GlowEffect_IIR_DeclareVars()
  
  ; Pour le flou vertical, on divise par colonnes au lieu de lignes
  start = (*param\thread_pos * w) / *param\thread_max
  stop  = ((*param\thread_pos + 1) * w) / *param\thread_max
  
  For x = start To stop - 1
    ; === Passe haut → bas ===
    pos = x << 2
    
    ; Initialisation avec le premier pixel de la colonne
    r = PeekL(glowR + pos)
    g = PeekL(glowG + pos)
    b = PeekL(glowB + pos)
    
    ; Application du filtre IIR de haut en bas
    For y = 1 To h - 1
      pos = (y * w + x) << 2
      GlowEffect_IIR_ApplyFilter()
    Next
    
    ; === Passe bas → haut ===
    pos = ((h - 1) * w + x) << 2
    
    ; Initialisation avec le dernier pixel de la colonne
    r = PeekL(glowR + pos)
    g = PeekL(glowG + pos)
    b = PeekL(glowB + pos)
    
    ; Application du filtre IIR de bas en haut
    For y = h - 2 To 0 Step -1
      pos = (y * w + x) << 2
      GlowEffect_IIR_ApplyFilter()
    Next
  Next
EndProcedure

;------------------------------------------------------------------------------
; ÉTAPE 4 : Composition finale - Addition du glow à l'image originale
; Combine l'image source avec le glow flouté selon l'intensité choisie
;------------------------------------------------------------------------------
Procedure GlowEffect_IIR_MT_Composite(*param.parametre)
  GlowEffect_IIR_DeclareVars()
  
  For y = start To stop - 1
    For x = 0 To w - 1
      pos = (y * w + x) << 2
      col = PeekL(*cible + pos)
      
      ; Extraction des composantes RGB de l'image originale
      Protected colR = (col >> 16) & $FF
      Protected colG = (col >> 8) & $FF
      Protected colB = col & $FF
      
      ; Addition du glow avec facteur d'intensité
      ; Division par 16 (>> 4) pour normaliser GlowStrength (0-100 → 0-6.25x)
      r = colR + ((PeekL(glowR + pos) * GlowStrength) >> 4)
      g = colG + ((PeekL(glowG + pos) * GlowStrength) >> 4)
      b = colB + ((PeekL(glowB + pos) * GlowStrength) >> 4)
      
      ; Clamping des valeurs RGB dans [0, 255]
      clamp_rgb(r, g, b)
      
      ; Reconstruction de la couleur ARGB (Alpha = 255 implicite)
      PokeL(*cible + pos, $FF000000 | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

;------------------------------------------------------------------------------
; Procédure principale du filtre GlowEffect_IIR
; Gère l'allocation mémoire, l'orchestration des threads et le nettoyage
;------------------------------------------------------------------------------
Procedure GlowEffect_IIR(*param.parametre)
  ; === MODE INFORMATION : Définition des paramètres du filtre ===
  If *param\info_active
    *param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Light
    *param\name = "GlowEffect_IIR"
    *param\remarque = "Effet de halo lumineux avec filtre IIR (rapide et efficace)"
    
    ; Définition des contrôles utilisateur
    *param\info[0] = "Intensité glow"    ; Force de l'effet (0-100)
    *param\info[1] = "Rayon flou"        ; Taille du halo (0-50)
    *param\info[2] = "Seuil luminosité"  ; Sensibilité (0-255)
    *param\info[3] = "Masque binaire"    ; Application du masque alpha
    
    ; Plages de valeurs : [min, max, valeur_défaut]
    *param\info_data(0, 0) = 0   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 50  : *param\info_data(1, 2) = 10
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 255 : *param\info_data(2, 2) = 127
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; === VÉRIFICATIONS DE SÉCURITÉ ===
  If *param\source = 0 Or *param\cible = 0
    Debug "Erreur: Pointeurs source ou cible invalides"
    ProcedureReturn
  EndIf
  
  ; === GESTION DE LA MÉMOIRE TEMPORAIRE ===
  Protected t = *param\lg * *param\ht * 4  ; Taille totale en octets (4 = ARGB)
  Protected *tempo = 0
  
  ; Si source = destination, créer une copie temporaire pour éviter l'écrasement
  If *param\source = *param\cible
    *tempo = AllocateMemory(t)
    If Not *tempo
      Debug "Erreur: Échec d'allocation de la mémoire temporaire"
      ProcedureReturn
    EndIf
    CopyMemory(*param\source, *tempo, t)
    *param\addr[0] = *tempo
  Else
    *param\addr[0] = *param\source
  EndIf
  
  *param\addr[1] = *param\cible
  
  ; === ALLOCATION DES BUFFERS DE TRAVAIL (canaux RGB séparés) ===
  Protected *glowR = AllocateMemory(t)
  Protected *glowG = AllocateMemory(t)
  Protected *glowB = AllocateMemory(t)
  
  ; Vérification critique : échec d'allocation = libération et sortie
  If Not *glowR Or Not *glowG Or Not *glowB
    If *glowR : FreeMemory(*glowR) : EndIf
    If *glowG : FreeMemory(*glowG) : EndIf
    If *glowB : FreeMemory(*glowB) : EndIf
    If *tempo : FreeMemory(*tempo) : EndIf
    Debug "Erreur: Échec d'allocation mémoire pour les buffers de glow"
    ProcedureReturn
  EndIf
  
  ; Enregistrement des pointeurs pour accès par les threads
  *param\addr[2] = *glowR
  *param\addr[3] = *glowG
  *param\addr[4] = *glowB
  
  ; === PIPELINE DE TRAITEMENT MULTI-THREAD ===
  ; Chaque étape est exécutée en parallèle sur plusieurs threads
  
  ; Étape 1 : Extraction des zones lumineuses
  MultiThread_MT(@GlowEffect_IIR_MT_ExtractBright(), 1)
  
  ; Étape 2 : Flou horizontal bidirectionnel
  MultiThread_MT(@GlowEffect_IIR_MT_BlurHorizontal(), 1)
  
  ; Étape 3 : Flou vertical bidirectionnel
  MultiThread_MT(@GlowEffect_IIR_MT_BlurVertical(), 1)
  
  ; Étape 4 : Composition finale (addition du glow)
  MultiThread_MT(@GlowEffect_IIR_MT_Composite(), 1)
  
  ; === APPLICATION DU MASQUE ALPHA (optionnel) ===
  If *param\mask And *param\option[3]
    *param\mask_type = *param\option[3] - 1
    MultiThread_MT(@_mask())
  EndIf
  
  ; === LIBÉRATION DE LA MÉMOIRE ===
  FreeMemory(*glowR)
  FreeMemory(*glowG)
  FreeMemory(*glowB)
  If *tempo : FreeMemory(*tempo) : EndIf
EndProcedure

;==============================================================================
; FIN DU MODULE GLOWEFFECT_IIR
;==============================================================================
;
; NOTES TECHNIQUES :
; ─────────────────
; • Le filtre IIR est beaucoup plus rapide qu'un flou gaussien classique
; • La complexité est O(n) au lieu de O(n*r²) pour un flou par convolution
; • Les passes bidirectionnelles éliminent les artefacts directionnels
; • L'utilisation de canaux RGB séparés permet un meilleur contrôle
; • L'arithmétique entière (>> 8) est plus rapide que les divisions flottantes
;
; AMÉLIORATIONS POSSIBLES :
; ─────────────────────────
; • Vectorisation SIMD pour traiter 4 pixels simultanément
; • Cache-blocking pour améliorer la localité mémoire
; • Support du canal alpha pour des effets plus subtils
; • Mode additif/multiplicatif pour différents styles de glow
;==============================================================================
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 235
; FirstLine = 210
; Folding = --
; EnableXP
; DPIAware
; DisableDebugger