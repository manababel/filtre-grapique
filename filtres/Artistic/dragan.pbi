; ==============================================================================
; FILTRE DRAGAN EFFECT
; ==============================================================================
; Crée l'effet Dragan caractérisé par :
; - Désaturation sélective (teint peau préservé)
; - Contraste extrême avec courbe en S
; - Clarté et netteté accentuées
; - Grain argentique
; - Vignettage subtil
; ==============================================================================

Procedure dragan_MT(*p.parametre)
  ; ============================================================================
  ; DÉCLARATION DES VARIABLES
  ; ============================================================================
  
  ; --- Dimensions de l'image ---
  Protected w = *p\lg
  Protected h = *p\ht
  
  ; --- Coordonnées ---
  Protected x, y, dx, dy
  
  ; --- Composantes ARGB ---
  Protected a, r, g, b
  Protected rC, gC, bC
  
  ; --- Traitement couleur ---
  Protected hue.f, sat.f, val.f
  Protected luminance.f, newLum.f
  Protected skinTone.f
  
  ; --- Détection locale (kernel 3x3) ---
  Protected sumLum.f, avgLum.f
  Protected valR, valG, valB, localLum.f
  
  ; --- Clarté (Local contrast) ---
  Protected clarity.f, deltaLum.f
  
  ; --- Grain ---
  Protected grain.f, grainValue.f
  
  ; --- Vignettage ---
  Protected distX.f, distY.f, vignette.f
  Protected centerX.f, centerY.f, maxDist.f
  
  ; --- Pointeurs mémoire ---
  Protected *src.Pixel32
  Protected *dst.Pixel32
  
  ; ============================================================================
  ; LECTURE DES PARAMÈTRES
  ; ============================================================================
  
  ; --- Intensité globale de l'effet ---
  Protected intensity.f = *p\option[0] * 0.01  ; 1-100 -> 0.01-1.0
  
  ; --- Contraste (courbe en S) ---
  Protected contrast.f = *p\option[1] * 0.01  ; 0-200 -> 0.0-2.0
  
  ; --- Clarté (micro-contraste) ---
  Protected clarityAmount.f = *p\option[2] * 0.01  ; 0-200 -> 0.0-2.0
  
  ; --- Désaturation ---
  Protected desaturation.f = *p\option[3] * 0.01  ; 0-100 -> 0.0-1.0
  
  ; --- Protection des tons chair ---
  Protected skinProtection.f = *p\option[4] * 0.01  ; 0-100 -> 0.0-1.0
  
  ; --- Intensité du grain ---
  Protected grainIntensity.f = *p\option[5] * 0.01  ; 0-100 -> 0.0-1.0
  
  ; --- Force du vignettage ---
  Protected vignetteStrength.f = *p\option[6] * 0.01  ; 0-100 -> 0.0-1.0
  
  ; --- Validation ---
  If intensity <= 0.0 : intensity = 0.01 : EndIf
  
  ; Calcul du centre pour le vignettage
  centerX = w * 0.5
  centerY = h * 0.5
  maxDist = Sqr(centerX * centerX + centerY * centerY)
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  
  Protected startY = (*p\thread_pos * h) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * h) / *p\thread_max
  
  ; Protection bordures (kernel 3x3)
  If startY < 1 : startY = 1 : EndIf
  If endY > h - 1 : endY = h - 1 : EndIf
  
  ; ============================================================================
  ; TRAITEMENT PRINCIPAL
  ; ============================================================================
  
  For y = startY To endY - 1
    For x = 1 To w - 2
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 1 : LECTURE DU PIXEL CENTRAL
      ; ------------------------------------------------------------------------
      *src = *p\addr[0] + ((y * w + x) << 2)
      GetARGB(*src\l, a, rC, gC, bC)
      
      ; Luminance du pixel central (perception humaine)
      luminance = rC * 0.299 + gC * 0.587 + bC * 0.114
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 2 : CALCUL DE LA CLARTÉ (MICRO-CONTRASTE LOCAL)
      ; ------------------------------------------------------------------------
      ; Compare le pixel à la moyenne de son voisinage
      
      sumLum = 0.0
      
      ; Parcours du voisinage 3×3
      For dy = -1 To 1
        For dx = -1 To 1
          *src = *p\addr[0] + (((y + dy) * w + (x + dx)) << 2)
          GetARGB(*src\l, a, valR, valG, valB)
          
          localLum = valR * 0.299 + valG * 0.587 + valB * 0.114
          sumLum + localLum
        Next
      Next
      
      avgLum = sumLum / 9.0
      
      ; Différence entre pixel et moyenne locale
      deltaLum = luminance - avgLum
      
      ; Application de la clarté (renforce les micro-contrastes)
      clarity = deltaLum * clarityAmount
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 3 : COURBE DE CONTRASTE EN S (SIGNATURE DRAGAN)
      ; ------------------------------------------------------------------------
      ; Formule : contraste sigmoïde qui écrase les tons moyens
      ; et accentue les ombres/hautes lumières
      
      newLum = luminance + clarity
      
      ; Normalisation 0-1 pour la courbe
      Protected normLum.f = newLum / 255.0
      If normLum < 0.0 : normLum = 0.0 : EndIf
      If normLum > 1.0 : normLum = 1.0 : EndIf
      
      ; Courbe en S (fonction sigmoïde modifiée)
      ; contrast = 1.0 → courbe linéaire
      ; contrast > 1.0 → courbe en S prononcée
      Protected midpoint.f = 0.5
      Protected curved.f
      
      If contrast > 1.0
        ; Formule sigmoïde : 1 / (1 + e^(-k*(x-0.5)))
        Protected k.f = (contrast - 1.0) * 10.0  ; Raideur de la courbe
        curved = 1.0 / (1.0 + Exp(-k * (normLum - midpoint)))
      Else
        ; Interpolation linéaire si contrast < 1
        curved = normLum * contrast + midpoint * (1.0 - contrast)
      EndIf
      
      newLum = curved * 255.0
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 4 : DÉTECTION DES TONS CHAIR
      ; ------------------------------------------------------------------------
      ; Les tons chair ont typiquement :
      ; - Teinte entre 0-50° (rouge-orange)
      ; - Saturation modérée
      ; - Luminosité moyenne à élevée
      
      ; Conversion RGB → HSV simplifiée pour détection
      Protected maxC.f = rC
      If gC > maxC : maxC = gC : EndIf
      If bC > maxC : maxC = bC : EndIf
      
      Protected minC.f = rC
      If gC < minC : minC = gC : EndIf
      If bC < minC : minC = bC : EndIf
      
      Protected delta.f = maxC - minC
      
      ; Calcul de la saturation
      If maxC > 0.0
        sat = delta / maxC
      Else
        sat = 0.0
      EndIf
      
      ; Calcul de la teinte (simplifié)
      If delta > 0.0
        If maxC = rC
          hue = 60.0 * ((gC - bC) / delta)
        ElseIf maxC = gC
          hue = 60.0 * (2.0 + (bC - rC) / delta)
        Else
          hue = 60.0 * (4.0 + (rC - gC) / delta)
        EndIf
        
        If hue < 0.0 : hue + 360.0 : EndIf
      Else
        hue = 0.0
      EndIf
      
      ; Détection peau : teinte 0-50°, saturation 0.2-0.6, luminosité > 80
      skinTone = 0.0
      
      If (hue >= 0.0 And hue <= 50.0) And (sat >= 0.2 And sat <= 0.6) And (luminance > 80.0)
        ; Score de probabilité de peau (1.0 = très probable)
        Protected hueScore.f = 1.0 - (hue / 50.0)
        Protected satScore.f = 1.0 - Abs(sat - 0.4) / 0.4
        skinTone = (hueScore + satScore) * 0.5
        
        If skinTone > 1.0 : skinTone = 1.0 : EndIf
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 5 : DÉSATURATION SÉLECTIVE
      ; ------------------------------------------------------------------------
      ; Désature tout sauf les tons chair
      
      ; Facteur de désaturation ajusté selon protection peau
      Protected desatFactor.f = desaturation * (1.0 - skinTone * skinProtection)
      
      ; Application du rapport de luminance aux canaux couleur
      Protected ratio.f = newLum / luminance
      If luminance < 1.0 : ratio = 1.0 : EndIf  ; Évite division par zéro
      
      Protected newR.f = rC * ratio
      Protected newG.f = gC * ratio
      Protected newB.f = bC * ratio
      
      ; Interpolation vers gris selon désaturation
      newR = newLum + (newR - newLum) * (1.0 - desatFactor)
      newG = newLum + (newG - newLum) * (1.0 - desatFactor)
      newB = newLum + (newB - newLum) * (1.0 - desatFactor)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 6 : GRAIN ARGENTIQUE
      ; ------------------------------------------------------------------------
      ; Ajoute un grain réaliste qui varie selon la luminosité
      ; (plus visible dans les tons moyens)
      
      If grainIntensity > 0.0
        ; Générateur pseudo-aléatoire basé sur position
        Protected seed.l = (x * 12345 + y * 67890) & $7FFFFFFF
        seed = (seed * 1103515245 + 12345) & $7FFFFFFF
        Protected grainValue2
        grainValue2 = (seed % 1000 - 500) / 500.0  ; -1.0 à +1.0
        grainValue2 = grainValue
        
        ; Le grain est plus visible dans les tons moyens
        Protected grainMask.f = 1.0 - Abs(normLum - 0.5) * 2.0
        grain = grainValue * grainIntensity * grainMask * 15.0
        
        newR + grain
        newG + grain
        newB + grain
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 7 : VIGNETTAGE
      ; ------------------------------------------------------------------------
      ; Assombrit les bords de l'image
      
      If vignetteStrength > 0.0
        distX = (x - centerX)
        distY = (y - centerY)
        Protected dist.f = Sqr(distX * distX + distY * distY)
        
        ; Courbe du vignettage (exponentielle douce)
        vignette = 1.0 - Pow(dist / maxDist, 2.0) * vignetteStrength
        
        If vignette < 0.0 : vignette = 0.0 : EndIf
        
        newR * vignette
        newG * vignette
        newB * vignette
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 8 : MÉLANGE AVEC ORIGINAL (INTENSITY)
      ; ------------------------------------------------------------------------
      
      r = Int(rC + (newR - rC) * intensity)
      g = Int(gC + (newG - gC) * intensity)
      b = Int(bC + (newB - bC) * intensity)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 9 : CLAMPING
      ; ------------------------------------------------------------------------
      
      If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 10 : ÉCRITURE DU RÉSULTAT
      ; ------------------------------------------------------------------------
      
      *dst = *p\addr[1] + ((y * w + x) << 2)
      *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      
    Next
  Next
  
EndProcedure

; ==============================================================================
; PROCÉDURE D'INITIALISATION
; ==============================================================================

Procedure dragan(*param.parametre)
  
  If *param\info_active
    
    ; --- Métadonnées ---
    *param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Light
    *param\name = "Dragan Effect"
    *param\remarque = "Effet dramatique avec contraste extrême et désaturation sélective"
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 0 : INTENSITÉ GLOBALE
    ; --------------------------------------------------------------------------
    *param\info[0] = "Intensité"
    *param\info_data(0, 0) = 1      ; Min
    *param\info_data(0, 1) = 100    ; Max
    *param\info_data(0, 2) = 80     ; Défaut
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 1 : CONTRASTE (COURBE EN S)
    ; --------------------------------------------------------------------------
    *param\info[1] = "Contraste"
    *param\info_data(1, 0) = 50     ; Réduit
    *param\info_data(1, 1) = 200    ; Extrême
    *param\info_data(1, 2) = 150    ; Fort (signature Dragan)
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 2 : CLARTÉ (MICRO-CONTRASTE)
    ; --------------------------------------------------------------------------
    *param\info[2] = "Clarté"
    *param\info_data(2, 0) = 0
    *param\info_data(2, 1) = 200
    *param\info_data(2, 2) = 120    ; Accentué
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 3 : DÉSATURATION
    ; --------------------------------------------------------------------------
    *param\info[3] = "Désaturation"
    *param\info_data(3, 0) = 0      ; Couleur normale
    *param\info_data(3, 1) = 100    ; Noir et blanc complet
    *param\info_data(3, 2) = 60     ; Partiellement désaturé
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 4 : PROTECTION TONS CHAIR
    ; --------------------------------------------------------------------------
    *param\info[4] = "Protection peau"
    *param\info_data(4, 0) = 0      ; Pas de protection
    *param\info_data(4, 1) = 100    ; Protection maximale
    *param\info_data(4, 2) = 70     ; Protection forte
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 5 : GRAIN ARGENTIQUE
    ; --------------------------------------------------------------------------
    *param\info[5] = "Grain"
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 100
    *param\info_data(5, 2) = 30
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 6 : VIGNETTAGE
    ; --------------------------------------------------------------------------
    *param\info[6] = "Vignettage"
    *param\info_data(6, 0) = 0
    *param\info_data(6, 1) = 100
    *param\info_data(6, 2) = 40
    
    *param\info[7] = "masque"
    *param\info_data(7, 0) = 0
    *param\info_data(7, 1) = 2
    *param\info_data(7, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multithreadé
  filter_start(@dragan_MT(), 3, 1)
  
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 320
; FirstLine = 301
; Folding = -
; EnableXP
; DPIAware