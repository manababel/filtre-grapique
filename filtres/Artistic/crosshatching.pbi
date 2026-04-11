; ==============================================================================
; FILTRE CROSSHATCHING ARTISTIC EFFECT
; ==============================================================================
; Crée un effet de dessin aux hachures croisées caractérisé par :
; - Détection de luminosité pour densité des hachures
; - Hachures multidirectionnelles selon luminance
; - Renforcement des contours
; - Simulation de traits au crayon/encre
; - Préservation optionnelle de la couleur
; ==============================================================================

Procedure crosshatching_MT(*p.parametre)
  ; ============================================================================
  ; DÉCLARATION DES VARIABLES
  ; ============================================================================
  
  ; --- Dimensions de l'image ---
  Protected w = *p\lg
  Protected h = *p\ht
  
  ; --- Coordonnées ---
  Protected x, y, dx, dy
  Protected i, j
  
  ; --- Composantes ARGB ---
  Protected a, r, g, b
  Protected rC, gC, bC
  Protected valR, valG, valB
  
  ; --- Luminance et analyse ---
  Protected luminance.f, avgLum.f
  Protected localLum.f, sumLum.f
  Protected minLum.f, maxLum.f
  
  ; --- Détection de contours ---
  Protected sobelX.f, sobelY.f
  Protected edgeMagnitude.f
  Protected edgeStrength.f
  
  ; --- Matrices Sobel ---
  Dim kernelX.f(2, 2)
  kernelX(0, 0) = -1 : kernelX(1, 0) = 0 : kernelX(2, 0) = 1
  kernelX(0, 1) = -2 : kernelX(1, 1) = 0 : kernelX(2, 1) = 2
  kernelX(0, 2) = -1 : kernelX(1, 2) = 0 : kernelX(2, 2) = 1
  
  Dim kernelY.f(2, 2)
  kernelY(0, 0) = -1 : kernelY(1, 0) = -2 : kernelY(2, 0) = -1
  kernelY(0, 1) =  0 : kernelY(1, 1) =  0 : kernelY(2, 1) =  0
  kernelY(0, 2) =  1 : kernelY(1, 2) =  2 : kernelY(2, 2) =  1
  
  ; --- Hachures ---
  Protected hatchValue.f
  Protected hatch0.f, hatch45.f, hatch90.f, hatch135.f
  Protected finalHatch.f
  Protected hatchIntensity.f
  
  ; --- Angles et directions ---
  Protected angle.f
  Protected distance.f
  Protected pattern.f
  
  ; --- Couleur ---
  Protected hue.f, sat.f, val.f
  Protected colorBlend.f
  
  ; --- Pointeurs mémoire ---
  Protected *src.Pixel32
  Protected *dst.Pixel32
  
  ; ============================================================================
  ; LECTURE DES PARAMÈTRES
  ; ============================================================================
  
  ; --- Intensité globale ---
  Protected strength.f = *p\option[0] * 0.01  ; 1-100 -> 0.01-1.0
  
  ; --- Densité des hachures ---
  Protected hatchDensity.f = *p\option[1] * 0.1  ; 1-100 -> 0.1-10.0
  
  ; --- Épaisseur des traits ---
  Protected lineThickness.f = *p\option[2] * 0.1  ; 1-50 -> 0.1-5.0
  
  ; --- Nombre de directions de hachures ---
  Protected numDirections = *p\option[3]  ; 1-4 directions
  
  ; --- Contraste des hachures ---
  Protected hatchContrast.f = *p\option[4] * 0.01  ; 0-200 -> 0.0-2.0
  
  ; --- Préservation de la couleur ---
  Protected colorPreserve.f = *p\option[5] * 0.01  ; 0-100 -> 0.0-1.0
  
  ; --- Renforcement des contours ---
  Protected edgeBoost.f = *p\option[6] * 0.01  ; 0-200 -> 0.0-2.0
  
  ; --- Validation ---
  If strength <= 0.0 : strength = 0.01 : EndIf
  If hatchDensity < 0.1 : hatchDensity = 0.1 : EndIf
  If numDirections < 1 : numDirections = 1 : EndIf
  If numDirections > 4 : numDirections = 4 : EndIf
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  
  Protected startY = (*p\thread_pos * h) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * h) / *p\thread_max
  
  ; Protection bordures pour Sobel
  Protected margin = 2
  If startY < margin : startY = margin : EndIf
  If endY > h - margin : endY = h - margin : EndIf
  
  ; ============================================================================
  ; CONSTANTES POUR LES HACHURES
  ; ============================================================================
  
  ; Fréquences des motifs de hachures (en pixels)
  Protected freq0.f = hatchDensity * 2.0    ; Hachures horizontales (0°)
  Protected freq45.f = hatchDensity * 1.414  ; Hachures diagonales (45°)
  Protected freq90.f = hatchDensity * 2.0    ; Hachures verticales (90°)
  Protected freq135.f = hatchDensity * 1.414 ; Hachures diagonales (135°)
  
  ; ============================================================================
  ; TRAITEMENT PRINCIPAL
  ; ============================================================================
  
  For y = startY To endY - 1
    For x = margin To w - margin - 1
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 1 : LECTURE DU PIXEL CENTRAL
      ; ------------------------------------------------------------------------
      *src = *p\addr[0] + ((y * w + x) << 2)
      GetARGB(*src\l, a, rC, gC, bC)
      
      ; Calcul de la luminance
      luminance = rC * 0.299 + gC * 0.587 + bC * 0.114
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 2 : ANALYSE DU VOISINAGE LOCAL
      ; ------------------------------------------------------------------------
      
      sumLum = 0.0
      minLum = 255.0
      maxLum = 0.0
      Protected count = 0
      
      ; Analyse 5x5
      For dy = -2 To 2
        For dx = -2 To 2
          *src = *p\addr[0] + (((y + dy) * w + (x + dx)) << 2)
          GetARGB(*src\l, a, valR, valG, valB)
          
          localLum = valR * 0.299 + valG * 0.587 + valB * 0.114
          
          sumLum + localLum
          If localLum < minLum : minLum = localLum : EndIf
          If localLum > maxLum : maxLum = localLum : EndIf
          count + 1
        Next
      Next
      
      avgLum = sumLum / count
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 3 : DÉTECTION DE CONTOURS (SOBEL)
      ; ------------------------------------------------------------------------
      
      sobelX = 0.0
      sobelY = 0.0
      
      For dy = -1 To 1
        For dx = -1 To 1
          *src = *p\addr[0] + (((y + dy) * w + (x + dx)) << 2)
          GetARGB(*src\l, a, valR, valG, valB)
          
          localLum = valR * 0.299 + valG * 0.587 + valB * 0.114
          
          sobelX + localLum * kernelX(dx + 1, dy + 1)
          sobelY + localLum * kernelY(dx + 1, dy + 1)
        Next
      Next
      
      edgeMagnitude = Sqr(sobelX * sobelX + sobelY * sobelY)
      edgeStrength = edgeMagnitude / 1000.0
      If edgeStrength > 1.0 : edgeStrength = 1.0 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 4 : CALCUL DES HACHURES MULTIDIRECTIONNELLES
      ; ------------------------------------------------------------------------
      
      ; Normalisation de la luminance (0.0 = noir = dense, 1.0 = blanc = peu de hachures)
      Protected normLum.f = luminance / 255.0
      
      ; Inversion pour que les zones sombres aient plus de hachures
      Protected darkness.f = 1.0 - normLum
      
      ; --- Hachures à 0° (horizontales) ---
      hatch0 = 0.0
      If numDirections >= 1
        pattern = Sin(y * #PI / freq0) * 0.5 + 0.5
        ; Modulation par épaisseur de ligne
        If pattern < lineThickness * 0.1
          hatch0 = 1.0
        EndIf
      EndIf
      
      ; --- Hachures à 90° (verticales) ---
      hatch90 = 0.0
      If numDirections >= 2
        pattern = Sin(x * #PI / freq90) * 0.5 + 0.5
        If pattern < lineThickness * 0.1
          hatch90 = 1.0
        EndIf
        ; N'applique qu'aux zones plus sombres
        If darkness < 0.5
          hatch90 = 0.0
        EndIf
      EndIf
      
      ; --- Hachures à 45° (diagonale \) ---
      hatch45 = 0.0
      If numDirections >= 3
        distance = (x + y) / Sqr(2.0)
        pattern = Sin(distance * #PI / freq45) * 0.5 + 0.5
        If pattern < lineThickness * 0.1
          hatch45 = 1.0
        EndIf
        ; N'applique qu'aux zones encore plus sombres
        If darkness < 0.66
          hatch45 = 0.0
        EndIf
      EndIf
      
      ; --- Hachures à 135° (diagonale /) ---
      hatch135 = 0.0
      If numDirections >= 4
        distance = (x - y) / Sqr(2.0)
        pattern = Sin(distance * #PI / freq135) * 0.5 + 0.5
        If pattern < lineThickness * 0.1
          hatch135 = 1.0
        EndIf
        ; N'applique qu'aux zones les plus sombres
        If darkness < 0.8
          hatch135 = 0.0
        EndIf
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 5 : COMBINAISON DES HACHURES
      ; ------------------------------------------------------------------------
      
      ; Superposition des hachures (OR logique visuel)
      finalHatch = hatch0
      If hatch90 > finalHatch : finalHatch = hatch90 : EndIf
      If hatch45 > finalHatch : finalHatch = hatch45 : EndIf
      If hatch135 > finalHatch : finalHatch = hatch135 : EndIf
      
      ; Application du contraste des hachures
      finalHatch = Pow(finalHatch, 1.0 / hatchContrast)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 6 : CALCUL DE L'INTENSITÉ DES HACHURES
      ; ------------------------------------------------------------------------
      
      ; Les zones claires ont peu de hachures, les zones sombres beaucoup
      hatchIntensity = darkness * finalHatch
      
      ; Renforcement sur les contours
      If edgeBoost > 0.0
        hatchIntensity = hatchIntensity + edgeStrength * edgeBoost * 0.3
        If hatchIntensity > 1.0 : hatchIntensity = 1.0 : EndIf
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 7 : APPLICATION DES HACHURES
      ; ------------------------------------------------------------------------
      
      ; Valeur de base (blanc) assombrie par les hachures
      Protected baseValue.f = 255.0 * (1.0 - hatchIntensity)
      
      ; Mélange avec la luminance originale pour préserver les nuances
      Protected finalValue.f = baseValue * 0.7 + luminance * 0.3
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 8 : PRÉSERVATION DE LA COULEUR (OPTIONNEL)
      ; ------------------------------------------------------------------------
      
      Protected newR.f, newG.f, newB.f
      
      If colorPreserve > 0.0 And luminance > 1.0
        ; Préserve la teinte et saturation, applique la nouvelle valeur
        Protected ratio.f = finalValue / luminance
        
        newR = rC * ratio
        newG = gC * ratio
        newB = bC * ratio
        
        ; Mélange entre couleur et noir & blanc
        newR = finalValue + (newR - finalValue) * colorPreserve
        newG = finalValue + (newG - finalValue) * colorPreserve
        newB = finalValue + (newB - finalValue) * colorPreserve
      Else
        ; Mode noir & blanc pur
        newR = finalValue
        newG = finalValue
        newB = finalValue
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 9 : MÉLANGE AVEC ORIGINAL (STRENGTH)
      ; ------------------------------------------------------------------------
      
      r = Int(rC + (newR - rC) * strength)
      g = Int(gC + (newG - gC) * strength)
      b = Int(bC + (newB - bC) * strength)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 10 : CLAMPING
      ; ------------------------------------------------------------------------
      
      If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 11 : ÉCRITURE DU RÉSULTAT
      ; ------------------------------------------------------------------------
      
      *dst = *p\addr[1] + ((y * w + x) << 2)
      *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      
    Next
  Next
  
EndProcedure

; ==============================================================================
; PROCÉDURE D'INITIALISATION
; ==============================================================================

Procedure crosshatching(*param.parametre)
  
  If *param\info_active
    
    ; --- Métadonnées ---
    *param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Other ; #Artistic_Drawing
    *param\name = "Crosshatching"
    *param\remarque = "Effet de hachures croisées type dessin au crayon ou à l'encre"
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 0 : INTENSITÉ GLOBALE
    ; --------------------------------------------------------------------------
    *param\info[0] = "Intensité"
    *param\info_data(0, 0) = 1      ; Min
    *param\info_data(0, 1) = 100    ; Max
    *param\info_data(0, 2) = 100    ; Défaut
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 1 : DENSITÉ DES HACHURES
    ; --------------------------------------------------------------------------
    *param\info[1] = "Densité hachures"
    *param\info_data(1, 0) = 1      ; Très espacé
    *param\info_data(1, 1) = 100    ; Très dense
    *param\info_data(1, 2) = 30     ; Densité moyenne
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 2 : ÉPAISSEUR DES TRAITS
    ; --------------------------------------------------------------------------
    *param\info[2] = "Épaisseur traits"
    *param\info_data(2, 0) = 1      ; Traits fins
    *param\info_data(2, 1) = 50     ; Traits épais
    *param\info_data(2, 2) = 15     ; Épaisseur moyenne
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 3 : NOMBRE DE DIRECTIONS
    ; --------------------------------------------------------------------------
    *param\info[3] = "Directions (1-4)"
    *param\info_data(3, 0) = 1      ; Une seule direction
    *param\info_data(3, 1) = 4      ; Quatre directions
    *param\info_data(3, 2) = 3      ; Trois directions
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 4 : CONTRASTE
    ; --------------------------------------------------------------------------
    *param\info[4] = "Contraste hachures"
    *param\info_data(4, 0) = 0      ; Doux
    *param\info_data(4, 1) = 200    ; Très contrasté
    *param\info_data(4, 2) = 100    ; Normal
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 5 : PRÉSERVATION COULEUR
    ; --------------------------------------------------------------------------
    *param\info[5] = "Couleur"
    *param\info_data(5, 0) = 0      ; Noir & blanc
    *param\info_data(5, 1) = 100    ; Couleurs préservées
    *param\info_data(5, 2) = 0      ; Noir & blanc par défaut
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 6 : RENFORCEMENT CONTOURS
    ; --------------------------------------------------------------------------
    *param\info[6] = "Contours"
    *param\info_data(6, 0) = 0      ; Pas de renforcement
    *param\info_data(6, 1) = 200    ; Contours très marqués
    *param\info_data(6, 2) = 80     ; Contours modérés
    
    *param\info[7] = "masque"
    *param\info_data(7, 0) = 0
    *param\info_data(7, 1) = 2
    *param\info_data(7, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multithreadé
  filter_start(@crosshatching_MT(), 3, 1)
  
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 347
; FirstLine = 343
; Folding = -
; EnableXP
; DPIAware