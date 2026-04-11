; ============================================================================
; Filtre Gabor - Analyse de texture et détection de contours orientés
; Nommé d'après Dennis Gabor, modélise les cellules simples du cortex visuel
; ============================================================================

; Structure pour stocker le noyau Gabor pré-calculé
Structure GaborKernel
  size.i          ; Taille du noyau (ex: 31x31)
  *real.Float     ; Partie réelle du filtre
  *imag.Float     ; Partie imaginaire du filtre
EndStructure

; Macro pour calculer le noyau Gabor
Procedure CreateGaborKernel(*kernel.GaborKernel, wavelength, orientation, sigma, gamma, psi)
  Protected ksize, halfsize, x, y, x_theta.f, y_theta.f, angle.f, sigma_x.f, sigma_y.f
  Protected gaussian.f, sinusoid_real.f, sinusoid_imag.f
  
  ; Calcul de la taille du noyau (3 déviations standard)
  ksize = Int(sigma * 6) | 1  ; Impair
  If ksize < 3 : ksize = 3 : EndIf
  If ksize > 63 : ksize = 63 : EndIf
  
  halfsize = ksize >> 1
  *kernel\size = ksize
  
  ; Allocation mémoire pour le noyau
  *kernel\real = AllocateMemory(ksize * ksize * SizeOf(Float))
  *kernel\imag = AllocateMemory(ksize * ksize * SizeOf(Float))
  
  If Not *kernel\real Or Not *kernel\imag
    If *kernel\real : FreeMemory(*kernel\real) : EndIf
    If *kernel\imag : FreeMemory(*kernel\imag) : EndIf
    ProcedureReturn #False
  EndIf
  
  ; Conversion de l'angle en radians
  angle = orientation * #PI / 180.0
  
  ; Paramètres du noyau Gabor
  sigma_x = sigma
  sigma_y = sigma / gamma
  
  ; Construction du noyau Gabor
  For y = 0 To ksize - 1
    For x = 0 To ksize - 1
      ; Coordonnées centrées
      x_theta = (x - halfsize) * Cos(angle) + (y - halfsize) * Sin(angle)
      y_theta = -(x - halfsize) * Sin(angle) + (y - halfsize) * Cos(angle)
      
      ; Enveloppe gaussienne
      gaussian = Exp(-0.5 * ((x_theta * x_theta) / (sigma_x * sigma_x) + 
                              (y_theta * y_theta) / (sigma_y * sigma_y)))
      
      ; Onde sinusoïdale
      sinusoid_real = Cos(2.0 * #PI * x_theta / wavelength + psi)
      sinusoid_imag = Sin(2.0 * #PI * x_theta / wavelength + psi)
      
      ; Filtre Gabor = Gaussienne × Sinusoïde
      PokeF(*kernel\real + (y * ksize + x) * SizeOf(Float), gaussian * sinusoid_real)
      PokeF(*kernel\imag + (y * ksize + x) * SizeOf(Float), gaussian * sinusoid_imag)
    Next
  Next
  
  ProcedureReturn #True
EndProcedure

; Macro pour libérer le noyau
Macro FreeGaborKernel(kernel)
  If kernel\real : FreeMemory(kernel\real) : kernel\real = 0 : EndIf
  If kernel\imag : FreeMemory(kernel\imag) : kernel\imag = 0 : EndIf
EndMacro

Procedure Gabor_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  ; Paramètres du filtre Gabor
  Protected wavelength.f = *param\option[0]  ; Longueur d'onde (pixels/cycle)
  Protected orientation.f = *param\option[1]  ; Orientation (degrés)
  Protected sigma.f = *param\option[2]       ; Écart-type de la gaussienne
  Protected gamma.f = *param\option[3]       ; Rapport d'aspect spatial
  Protected psi.f = *param\option[4]         ; Décalage de phase (degrés)
  Protected outputMode = *param\option[5]    ; 0=Magnitude, 1=Real, 2=Imag, 3=Phase
  Protected toGray = *param\option[6]
  Protected normalize = *param\option[7]     ; Normalisation de la sortie
  
  ; Validation des paramètres
  Clamp(wavelength, 2, 100)
  Clamp(orientation, 0, 180)
  Clamp(sigma, 1, 20)
  Clamp(gamma, 0.23, 0.92)
  Clamp(outputMode, 0, 3)
  
  ; Conversion psi en radians
  psi * #PI / 180.0
  
  ; Création du noyau Gabor
  Protected kernel.GaborKernel
  If Not CreateGaborKernel(@kernel, wavelength, orientation, sigma, gamma, psi)
    ProcedureReturn
  EndIf
  
  ; Calcul des limites de traitement pour ce thread
  Protected startY = (*param\thread_pos * ht) / *param\thread_max
  Protected endY   = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  
  ; Variables de travail
  Protected *srcPixel.Long, *dstPixel.Long
  Protected x, y, kx, ky, sx, sy, idx
  Protected r, g, b, gray, pixelValue
  Protected real_sum.f, imag_sum.f, magnitude.f, phase.f
  Protected kernel_val_real.f, kernel_val_imag.f
  Protected halfsize = kernel\size >> 1
  Protected result, output
  Protected minVal.f, maxVal.f, range.f
  
  ; Tableaux pour normalisation (si nécessaire)
  Dim tempResults.f(lg * ht)
  Protected needNormalize
  
  ; Pas de normalisation pour la phase
  If normalize And outputMode <> 3
    needNormalize = #True
  Else
    needNormalize = #False
  EndIf
  
  ; ========================================================================
  ; Convolution avec le noyau Gabor
  ; ========================================================================
  For y = startY To endY
    For x = 0 To lg - 1
      
      real_sum = 0
      imag_sum = 0
      
      ; Convolution avec le noyau
      For ky = 0 To kernel\size - 1
        sy = y + ky - halfsize
        
        ; Gestion des bords (réplication)
        If sy < 0 : sy = 0 : EndIf
        If sy >= ht : sy = ht - 1 : EndIf
        
        For kx = 0 To kernel\size - 1
          sx = x + kx - halfsize
          
          ; Gestion des bords (réplication)
          If sx < 0 : sx = 0 : EndIf
          If sx >= lg : sx = lg - 1 : EndIf
          
          ; Lecture du pixel source
          *srcPixel = *source + (sy * lg + sx) * 4
          GetRGB(PeekL(*srcPixel), r, g, b)
          
          If toGray
            pixelValue = (r * 77 + g * 150 + b * 29) >> 8
          Else
            pixelValue = (r + g + b) / 3
          EndIf
          
          ; Lecture des coefficients du noyau
          idx = ky * kernel\size + kx
          kernel_val_real = PeekF(kernel\real + idx * SizeOf(Float))
          kernel_val_imag = PeekF(kernel\imag + idx * SizeOf(Float))
          
          ; Accumulation (convolution)
          real_sum + pixelValue * kernel_val_real
          imag_sum + pixelValue * kernel_val_imag
        Next
      Next
      
      ; Calcul de la sortie selon le mode
      Select outputMode
        Case 0  ; Magnitude (énergie)
          output = Sqr(real_sum * real_sum + imag_sum * imag_sum)
          
        Case 1  ; Partie réelle
          output = real_sum
          
        Case 2  ; Partie imaginaire
          output = imag_sum
          
        Case 3  ; Phase
          output = ATan2(imag_sum, real_sum) * 180.0 / #PI
          If output < 0 : output + 360 : EndIf
          
      EndSelect
      
      ; Stockage temporaire pour normalisation
      If needNormalize
        idx = y * lg + x
        tempResults(idx) = output
        
        ; Mise à jour min/max
        If y = startY And x = 0
          minVal = output
          maxVal = output
        Else
          If output < minVal : minVal = output : EndIf
          If output > maxVal : maxVal = output : EndIf
        EndIf
      Else
        ; Écriture directe
        If outputMode = 3  ; Phase [0-360] -> [0-255]
          result = output * 255.0 / 360.0
        Else
          result = Abs(output)
        EndIf
        
        Clamp(result, 0, 255)
        
        *dstPixel = *cible + (y * lg + x) * 4
        If toGray
          PokeL(*dstPixel, $FF000000 | (result * $010101))
        Else
          ; Préserver la couleur d'origine modulée par la réponse
          *srcPixel = *source + (y * lg + x) * 4
          GetRGB(PeekL(*srcPixel), r, g, b)
          r = (r * result) / 255
          g = (g * result) / 255
          b = (b * result) / 255
          Clamp_RGB(r, g, b)
          PokeL(*dstPixel, $FF000000 | (r << 16) | (g << 8) | b)
        EndIf
      EndIf
      
    Next
  Next
  
  ; ========================================================================
  ; Normalisation (si activée)
  ; ========================================================================
  If needNormalize
    range = maxVal - minVal
    If range < 0.001 : range = 1.0 : EndIf
    
    For y = startY To endY
      For x = 0 To lg - 1
        idx = y * lg + x
        
        ; Normalisation [minVal, maxVal] -> [0, 255]
        result = (tempResults(idx) - minVal) * 255.0 / range
        Clamp(result, 0, 255)
        
        *dstPixel = *cible + idx * 4
        If toGray
          PokeL(*dstPixel, $FF000000 | (result * $010101))
        Else
          *srcPixel = *source + idx * 4
          GetRGB(PeekL(*srcPixel), r, g, b)
          r = (r * result) / 255
          g = (g * result) / 255
          b = (b * result) / 255
          Clamp_RGB(r, g, b)
          PokeL(*dstPixel, $FF000000 | (r << 16) | (g << 8) | b)
        EndIf
      Next
    Next
  EndIf
  
  ; Libération
  FreeGaborKernel(kernel)
  FreeArray(tempResults())
EndProcedure

Procedure Gabor(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Advanced
    *param\name = "Gabor"
    *param\remarque = "Analyse de texture et détection orientée (Dennis Gabor)"
    
    ; Description des paramètres
    *param\info[0] = "Longueur d'onde (wavelength)"
    *param\info[1] = "Orientation (degrés)"
    *param\info[2] = "Sigma (écart-type)"
    *param\info[3] = "Gamma (aspect ratio)"
    *param\info[4] = "Psi (phase, degrés)"
    *param\info[5] = "Mode sortie (0=Mag/1=Real/2=Imag/3=Phase)"
    *param\info[6] = "Noir et blanc"
    *param\info[7] = "Normalisation"
    *param\info[8] = "masque"
    
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 180 : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 1   : *param\info_data(2, 1) = 20  : *param\info_data(2, 2) = 5
    *param\info_data(3, 0) = 23  : *param\info_data(3, 1) = 92  : *param\info_data(3, 2) = 50
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 360 : *param\info_data(4, 2) = 0
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 3   : *param\info_data(5, 2) = 0
    *param\info_data(6, 0) = 0   : *param\info_data(6, 1) = 1   : *param\info_data(6, 2) = 1
    *param\info_data(7, 0) = 0   : *param\info_data(7, 1) = 1   : *param\info_data(7, 2) = 1
    *param\info_data(8, 0) = 0   : *param\info_data(8, 1) = 2   : *param\info_data(8, 2) = 1
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@Gabor_MT(), 8)
EndProcedure

; ============================================================================
; NOTES TECHNIQUES - FILTRE GABOR
; ============================================================================
;
; Le filtre Gabor est un filtre linéaire défini par:
;   g(x,y) = exp(-[(x'²+γ²y'²)/(2σ²)]) × cos(2π×x'/λ + ψ)
;
; Où:
;   - (x', y') sont les coordonnées après rotation par θ
;   - λ (wavelength) = longueur d'onde de l'onde sinusoïdale (pixels/cycle)
;   - θ (orientation) = orientation du filtre (0-180°)
;   - σ (sigma) = écart-type de l'enveloppe gaussienne
;   - γ (gamma) = rapport d'aspect spatial (ellipticité)
;   - ψ (psi) = décalage de phase (0-360°)
;
; PARAMÈTRES TYPIQUES:
;   - Wavelength: 2 jusqu'à la diagonale de l'image
;   - Orientation: 0-180° (multiples de 45° pour banque de filtres)
;   - Sigma: proportionnel à wavelength (typiquement λ/2 à λ)
;   - Gamma: 0.23 - 0.92 (0.5 = bon compromis)
;   - Psi: 0° (cosine phase) ou 90° (sine phase)
;
; MODES DE SORTIE:
;   0 = Magnitude: √(Real² + Imag²) - Énergie du filtre
;   1 = Real: Partie réelle (symétrique)
;   2 = Imag: Partie imaginaire (anti-symétrique)
;   3 = Phase: atan2(Imag, Real) - Information d'orientation
;
; APPLICATIONS:
;   - Analyse de texture (tissus, matériaux)
;   - Détection de contours orientés
;   - Reconnaissance de caractères
;   - Segmentation d'images
;   - Extraction de caractéristiques pour ML
;   - Modélisation du système visuel humain
;
; BANQUE DE FILTRES GABOR:
;   Pour une analyse complète, utiliser plusieurs filtres avec:
;   - Différentes orientations: 0°, 45°, 90°, 135° (minimum)
;   - Différentes échelles (wavelength): 4, 8, 16, 32 pixels
;   - Combiner les réponses pour extraction de features robustes
;
; ============================================================================
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 272
; FirstLine = 267
; Folding = -
; EnableXP
; DPIAware