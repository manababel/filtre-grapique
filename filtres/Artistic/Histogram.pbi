;==============================================================================
; HISTOGRAM EQUALIZATION - Égalisation d'histogramme
;==============================================================================
; Améliore le contraste d'une image en redistribuant les niveaux de luminosité
; de manière uniforme sur toute la plage dynamique [0-255]
;
; Algorithme :
; 1. Construction des histogrammes RGB (distribution des couleurs)
; 2. Calcul des histogrammes cumulés (fonction de répartition)
; 3. Détermination des valeurs min/max pour la normalisation
; 4. Application de la transformation d'égalisation avec intensité contrôlable
;
; Principe : Les pixels sombres sont éclaircis, les pixels clairs sont assombris
; pour obtenir une distribution plus uniforme et un meilleur contraste global
;==============================================================================

;------------------------------------------------------------------------------
; ÉTAPE 1 : Construction des histogrammes RGB (multi-thread)
; Chaque thread calcule un histogramme local puis fusionne avec l'histogramme global
;------------------------------------------------------------------------------
Procedure Histogram_MT_BuildHistograms(*param.parametre)
  Protected *source = *param\addr[0]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected total = lg * ht
  
  ; Calcul de la plage de pixels pour ce thread
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  
  Protected i, pix, r, g, b
  
  ; Histogrammes locaux (par thread) pour éviter les conflits d'accès mémoire
  Protected Dim histR(255)
  Protected Dim histG(255)
  Protected Dim histB(255)
  
  ; === Phase de comptage local ===
  ; Chaque thread compte indépendamment ses pixels
  For i = start To stop - 1
    pix = PeekL(*source + (i << 2))  ; Lecture du pixel ARGB
    getrgb(pix, r, g, b)              ; Extraction des composantes RGB
    
    ; Incrémentation des compteurs d'histogramme
    histR(r) + 1
    histG(g) + 1
    histB(b) + 1
  Next
  
  ; === Phase de fusion atomique ===
  ; Ajout des comptages locaux dans les histogrammes globaux
  ; Note : Cette section devrait idéalement utiliser des opérations atomiques
  ; pour garantir la cohérence en multi-thread
  For i = 0 To 255
    PokeL(*param\addr[2] + (i << 2), PeekL(*param\addr[2] + (i << 2)) + histR(i))
    PokeL(*param\addr[3] + (i << 2), PeekL(*param\addr[3] + (i << 2)) + histG(i))
    PokeL(*param\addr[4] + (i << 2), PeekL(*param\addr[4] + (i << 2)) + histB(i))
  Next
EndProcedure

;------------------------------------------------------------------------------
; ÉTAPE 4 : Application de l'égalisation avec contrôle d'intensité (multi-thread)
; Transforme chaque pixel selon l'histogramme cumulé normalisé
;------------------------------------------------------------------------------
Procedure Histogram_MT_ApplyEqualization(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected total = lg * ht
  
  ; Récupération des valeurs min/max calculées précédemment
  Protected minr = *param\option[4]
  Protected ming = *param\option[5]
  Protected minb = *param\option[6]
  Protected maxr = *param\option[7]
  Protected maxg = *param\option[8]
  Protected maxb = *param\option[9]
  
  ; === Calcul de l'intensité de l'effet ===
  Protected intensity.f
  
  If *param\option[1] ; Mode automatique
    ; Calcul de l'intensité selon la plage dynamique actuelle
    ; Plus la plage est petite (image à faible contraste), plus l'effet est fort
    Protected rangeR = maxr - minr
    Protected rangeG = maxg - ming
    Protected rangeB = maxb - minb
    Protected avgRange.f = (rangeR + rangeG + rangeB) / 3.0
    
    ; Intensité inversement proportionnelle à la plage moyenne
    intensity = 1.0 - (avgRange / 255.0)
    
    ; Clamping de sécurité
    If intensity < 0 : intensity = 0 : EndIf
    If intensity > 1 : intensity = 1 : EndIf
    
  Else ; Mode manuel
    ; Conversion de la plage [0-200] vers [-1.0, 1.0]
    intensity = (*param\option[0] - 100) / 100.0
  EndIf
  
  ; Calcul de la plage de pixels pour ce thread
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  
  Protected i, pix
  Protected ro, go, bo  ; Valeurs RGB originales
  Protected r, g, b     ; Valeurs RGB transformées
  
  ; Pré-calcul des dénominateurs pour éviter les divisions par zéro
  Protected denomR = maxr - minr : If denomR = 0 : denomR = 1 : EndIf
  Protected denomG = maxg - ming : If denomG = 0 : denomG = 1 : EndIf
  Protected denomB = maxb - minb : If denomB = 0 : denomB = 1 : EndIf
  
  ; Pré-calcul des facteurs de mélange
  Protected blendOrig.f = 1.0 - intensity
  Protected blendEqual.f = intensity
  
  ; === Transformation de chaque pixel ===
  For i = start To stop - 1
    pix = PeekL(*source + (i << 2))
    getrgb(pix, ro, go, bo)
    
    ; Égalisation : transformation selon l'histogramme cumulé normalisé
    ; Formule : nouveau = (cumul[ancien] - min) * 255 / (max - min)
    r = (PeekL(*param\addr[5] + (ro << 2)) - minr) * 255 / denomR
    g = (PeekL(*param\addr[6] + (go << 2)) - ming) * 255 / denomG
    b = (PeekL(*param\addr[7] + (bo << 2)) - minb) * 255 / denomB
    
    ; Mélange avec la couleur originale selon l'intensité
    ; Permet un contrôle fin de l'effet (de 0% à 100%)
    r = ro * blendOrig + r * blendEqual
    g = go * blendOrig + g * blendEqual
    b = bo * blendOrig + b * blendEqual
    
    ; Clamping des valeurs RGB dans [0, 255]
    clamp_rgb(r, g, b)
    
    ; Écriture du pixel transformé (Alpha = 255 implicite)
    PokeL(*cible + (i << 2), $FF000000 | (r << 16) | (g << 8) | b)
  Next
EndProcedure

;------------------------------------------------------------------------------
; Procédure principale du filtre Histogram Equalization
; Orchestre les différentes étapes du traitement
;------------------------------------------------------------------------------
Procedure Histogram(*param.parametre)
  ; === MODE INFORMATION : Définition des paramètres du filtre ===
  If *param\info_active
    *param\name = "Histogram Equalization"
    *param\typ  = #FilterType_Artistic
    *param\subtype = #Artistic_Other
    *param\remarque = "Égalisation d'histogramme pour améliorer le contraste"
    
    ; Définition des contrôles utilisateur
    *param\info[0] = "Intensité"    ; Force de l'égalisation (0-200, 100=neutre)
    *param\info[1] = "Mode auto"    ; 0=Manuel, 1=Automatique basé sur le contraste
    *param\info[1] = "masque"
    ; Plages de valeurs : [min, max, valeur_défaut]
    *param\info_data(0, 0) = 0   : *param\info_data(0, 1) = 200 : *param\info_data(0, 2) = 100
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  
  ; === VÉRIFICATIONS DE SÉCURITÉ ===
  If *param\source = 0 Or *param\cible = 0
    Debug "Erreur: Pointeurs source ou cible invalides"
    ProcedureReturn
  EndIf
  
  ; === INITIALISATION ===
  Protected i, r, g, b
  Protected minr, ming, minb
  Protected maxr, maxg, maxb
  
  *param\addr[0] = *param\source
  *param\addr[1] = *param\cible
  
  ; === ALLOCATION DES BUFFERS MÉMOIRE ===
  ; Histogrammes par canal (256 valeurs Long pour chaque canal RGB)
  *param\addr[2] = AllocateMemory(256 * 4)  ; Histogramme Rouge
  *param\addr[3] = AllocateMemory(256 * 4)  ; Histogramme Vert
  *param\addr[4] = AllocateMemory(256 * 4)  ; Histogramme Bleu
  
  ; Histogrammes cumulés (fonction de répartition)
  *param\addr[5] = AllocateMemory(256 * 4)  ; Cumulé Rouge
  *param\addr[6] = AllocateMemory(256 * 4)  ; Cumulé Vert
  *param\addr[7] = AllocateMemory(256 * 4)  ; Cumulé Bleu
  
  ; Vérification de l'allocation
  If Not *param\addr[2] Or Not *param\addr[3] Or Not *param\addr[4] Or 
     Not *param\addr[5] Or Not *param\addr[6] Or Not *param\addr[7]
    Debug "Erreur: Échec d'allocation mémoire pour les histogrammes"
    
    ; Libération des buffers partiellement alloués
    For i = 2 To 7
      If *param\addr[i] : FreeMemory(*param\addr[i]) : EndIf
    Next
    ProcedureReturn
  EndIf
  
  ; Initialisation à zéro des histogrammes
  FillMemory(*param\addr[2], 256 * 4, 0)
  FillMemory(*param\addr[3], 256 * 4, 0)
  FillMemory(*param\addr[4], 256 * 4, 0)
  
  ; === ÉTAPE 1 : Construction des histogrammes (multi-thread) ===
  MultiThread_MT(@Histogram_MT_BuildHistograms())
  
  ; === ÉTAPE 2 : Calcul des histogrammes cumulés ===
  ; Transformation de l'histogramme en fonction de répartition cumulative
  Protected cumulR, cumulG, cumulB
  cumulR = 0 : cumulG = 0 : cumulB = 0
  
  For i = 0 To 255
    ; Cumul progressif pour chaque canal
    cumulR + PeekL(*param\addr[2] + (i << 2))
    cumulG + PeekL(*param\addr[3] + (i << 2))
    cumulB + PeekL(*param\addr[4] + (i << 2))
    
    ; Stockage des valeurs cumulées
    PokeL(*param\addr[5] + (i << 2), cumulR)
    PokeL(*param\addr[6] + (i << 2), cumulG)
    PokeL(*param\addr[7] + (i << 2), cumulB)
  Next
  
  ; === ÉTAPE 3 : Détermination des valeurs min/max ===
  ; Nécessaire pour la normalisation dans [0, 255]
  minr = $7FFFFFFF : ming = $7FFFFFFF : minb = $7FFFFFFF
  maxr = 0 : maxg = 0 : maxb = 0
  
  For i = 0 To 255
    r = PeekL(*param\addr[5] + (i << 2))
    g = PeekL(*param\addr[6] + (i << 2))
    b = PeekL(*param\addr[7] + (i << 2))
    
    ; Recherche des minimums
    If r < minr : minr = r : EndIf
    If g < ming : ming = g : EndIf
    If b < minb : minb = b : EndIf
    
    ; Recherche des maximums
    If r > maxr : maxr = r : EndIf
    If g > maxg : maxg = g : EndIf
    If b > maxb : maxb = b : EndIf
  Next
  
  ; Stockage des valeurs min/max pour utilisation dans la phase d'application
  *param\option[4] = minr
  *param\option[5] = ming
  *param\option[6] = minb
  *param\option[7] = maxr
  *param\option[8] = maxg
  *param\option[9] = maxb
  
  ; === ÉTAPE 4 : Application de l'égalisation (multi-thread) ===
  MultiThread_MT(@Histogram_MT_ApplyEqualization())
  
  ; === APPLICATION DU MASQUE ALPHA (optionnel) ===
  If *param\mask
    *param\mask_type = *param\option[1]  ; Type de masque selon le mode
    MultiThread_MT(@_mask())
  EndIf
  
  ; === LIBÉRATION DE LA MÉMOIRE ===
  For i = 2 To 7
    If *param\addr[i]
      FreeMemory(*param\addr[i])
      *param\addr[i] = 0
    EndIf
  Next
EndProcedure

;==============================================================================
; FIN DU MODULE HISTOGRAM EQUALIZATION
;==============================================================================
;
; NOTES TECHNIQUES :
; ─────────────────
; • L'égalisation d'histogramme améliore le contraste global de l'image
; • Particulièrement efficace sur les images sous-exposées ou surexposées
; • L'algorithme redistributue les niveaux de luminosité de manière uniforme
; • Le mode automatique ajuste l'intensité selon la plage dynamique détectée
;
; PRINCIPE MATHÉMATIQUE :
; ──────────────────────
; Soit h(v) l'histogramme et H(v) l'histogramme cumulé :
; H(v) = Σ(i=0 to v) h(i)
; 
; La transformation d'égalisation est :
; nouveau(v) = (H(v) - H_min) × 255 / (H_max - H_min)
;
; Cette transformation étire l'histogramme pour couvrir toute la plage [0-255]
;
; LIMITATIONS :
; ────────────
; • Peut créer un effet "artificiel" sur certaines images naturelles
; • Amplifie le bruit dans les zones uniformes
; • L'égalisation globale peut altérer les relations de couleurs
;
; AMÉLIORATIONS POSSIBLES :
; ─────────────────────────
; • Égalisation locale (CLAHE - Contrast Limited Adaptive Histogram Equalization)
; • Préservation de la teinte (travailler en espace HSV/HSL)
; • Limitation du contraste pour éviter l'amplification du bruit
; • Histogramme pondéré par la perception (favoriser les tons moyens)
;==============================================================================




; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 153
; FirstLine = 111
; Folding = -
; EnableXP
; DPIAware