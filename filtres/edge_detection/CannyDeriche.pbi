; ============================================================================
; Filtre Canny-Deriche - Détection de contours optimale avec filtres IIR
; ============================================================================

; ============================================================================
; Fonction de lissage récursif Deriche (filtre IIR optimal)
; ============================================================================
Procedure Deriche_Smooth(Array vinput.f(1), Array voutput.f(1), size, alpha.f)
  If size < 3 : ProcedureReturn : EndIf
  
  Protected Dim y1.f(size - 1)
  Protected Dim y2.f(size - 1)
  Protected i
  Protected k.f, a0.f, a1.f, a2.f, a3.f, b1.f, b2.f
  
  ; Calcul des coefficients du filtre de lissage
  Protected exp_alpha.f = Exp(-alpha)
  Protected exp_2alpha.f = Exp(-2.0 * alpha)
  
  k = (1.0 - exp_alpha) * (1.0 - exp_alpha) / (1.0 + 2.0 * alpha * exp_alpha - exp_2alpha)
  a0 = k
  a1 = k * exp_alpha * (alpha - 1.0)
  a2 = k * exp_alpha * (alpha + 1.0)
  a3 = -k * exp_2alpha
  b1 = 2.0 * exp_alpha
  b2 = -exp_2alpha
  
  ; Passe avant (causal)
  y1(0) = a0 * vInput(0)
  If size > 1
    y1(1) = a0 * vInput(1) + a1 * vInput(0) + b1 * y1(0)
  EndIf
  For i = 2 To size - 1
    y1(i) = a0 * vInput(i) + a1 * vInput(i - 1) + b1 * y1(i - 1) + b2 * y1(i - 2)
  Next
  
  ; Passe arrière (anti-causal)
  y2(size - 1) = 0
  If size > 1
    y2(size - 2) = a2 * vInput(size - 1)
  EndIf
  For i = size - 3 To 0 Step -1
    y2(i) = a2 * vInput(i + 1) + a3 * vInput(i + 2) + b1 * y2(i + 1) + b2 * y2(i + 2)
  Next
  
  ; Combinaison des deux passes
  For i = 0 To size - 1
    voutput(i) = y1(i) + y2(i)
  Next
  
  FreeArray(y1())
  FreeArray(y2())
EndProcedure

; ============================================================================
; Fonction de dérivée première récursive Deriche
; ============================================================================
Procedure Deriche_Derivative(Array vinput.f(1), Array voutput.f(1), size, alpha.f)
  If size < 3 : ProcedureReturn : EndIf
  
  Protected Dim y1.f(size - 1)
  Protected Dim y2.f(size - 1)
  Protected i
  Protected k.f, a0.f, a1.f, a2.f, a3.f, b1.f, b2.f
  
  ; Calcul des coefficients du filtre dérivateur
  Protected exp_alpha.f = Exp(-alpha)
  Protected exp_2alpha.f = Exp(-2.0 * alpha)
  
  k = -(1.0 - exp_alpha) * (1.0 - exp_alpha) / (2.0 * exp_alpha)
  a0 = 0
  a1 = k * exp_alpha
  a2 = -a1
  a3 = 0
  b1 = 2.0 * exp_alpha
  b2 = -exp_2alpha
  
  ; Passe avant (causal)
  y1(0) = 0
  If size > 1
    y1(1) = a1 * vInput(0) + b1 * y1(0)
  EndIf
  For i = 2 To size - 1
    y1(i) = a1 * vInput(i - 1) + b1 * y1(i - 1) + b2 * y1(i - 2)
  Next
  
  ; Passe arrière (anti-causal)
  y2(size - 1) = 0
  If size > 1
    y2(size - 2) = a2 * vInput(size - 1)
  EndIf
  For i = size - 3 To 0 Step -1
    y2(i) = a2 * vInput(i + 1) + b1 * y2(i + 1) + b2 * y2(i + 2)
  Next
  
  ; Combinaison des deux passes
  For i = 0 To size - 1
    voutput(i) = y1(i) + y2(i)
  Next
  
  FreeArray(y1())
  FreeArray(y2())
EndProcedure

Procedure CannyDeriche_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  ; Vérification des dimensions minimales
  If lg < 4 Or ht < 4
    ProcedureReturn
  EndIf
  
  Protected alpha.f = *param\option[0]
  Protected lowThreshold.f = *param\option[1]
  Protected highThreshold.f = *param\option[2]
  
  ; Normalisation de alpha (1-100 -> 0.5-3.0)
  Clamp(alpha, 1, 100)
  alpha = 0.5 + (alpha - 1) * 0.025
  
  ; Normalisation des seuils (0-100 -> 0-255)
  Clamp(lowThreshold, 0, 100)
  Clamp(highThreshold, 0, 100)
  lowThreshold = lowThreshold * 2.55
  highThreshold = highThreshold * 2.55
  
  ; S'assurer que highThreshold >= lowThreshold
  If highThreshold < lowThreshold
    Protected temp.f = lowThreshold
    lowThreshold = highThreshold
    highThreshold = temp
  EndIf
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected r, g, b
  Protected x, y, i
  Protected var
  
  ; Tableaux de travail
  Protected Dim gray.f(lg - 1, ht - 1)
  Protected Dim smoothed.f(lg - 1, ht - 1)
  Protected Dim gradX.f(lg - 1, ht - 1)
  Protected Dim gradY.f(lg - 1, ht - 1)
  Protected Dim magnitude.f(lg - 1, ht - 1)
  Protected Dim direction.f(lg - 1, ht - 1)
  Protected Dim suppressed.f(lg - 1, ht - 1)
  Protected Dim edges.a(lg - 1, ht - 1)
  
  ; Tableaux temporaires pour le filtrage récursif
  Protected Dim tempLine.f(lg - 1)
  Protected Dim tempCol.f(ht - 1)
  Protected Dim outLine.f(lg - 1)
  Protected Dim outCol.f(ht - 1)
  
  ; ========================================================================
  ; Étape 1: Conversion en niveaux de gris
  ; ========================================================================
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      *srcPixel = *source + (y * lg + x) * 4
      getrgb(PeekL(*srcPixel), r, g, b)
      var = (r * 77 + g * 150 + b * 29) >> 8
      gray(x, y) = var
    Next
  Next
  
  ; ========================================================================
  ; Étape 2: Lissage Deriche (filtrage horizontal puis vertical)
  ; ========================================================================
  
  ; Lissage horizontal
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      tempLine(x) = gray(x, y)
    Next
    Deriche_Smooth(tempLine(), outLine(), lg, alpha)
    For x = 0 To lg - 1
      smoothed(x, y) = outLine(x)
    Next
  Next
  
  ; Lissage vertical
  For x = 0 To lg - 1
    For y = 0 To ht - 1
      tempCol(y) = smoothed(x, y)
    Next
    Deriche_Smooth(tempCol(), outCol(), ht, alpha)
    For y = 0 To ht - 1
      smoothed(x, y) = outCol(y)
    Next
  Next
  
  ; ========================================================================
  ; Étape 3: Calcul des gradients (dérivée horizontale et verticale)
  ; ========================================================================
  
  ; Gradient horizontal (dérivée en X, lissage en Y)
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      tempLine(x) = smoothed(x, y)
    Next
    Deriche_Derivative(tempLine(), outLine(), lg, alpha)
    For x = 0 To lg - 1
      gradX(x, y) = outLine(x)
    Next
  Next
  
  ; Gradient vertical (dérivée en Y, lissage en X)
  For x = 0 To lg - 1
    For y = 0 To ht - 1
      tempCol(y) = smoothed(x, y)
    Next
    Deriche_Derivative(tempCol(), outCol(), ht, alpha)
    For y = 0 To ht - 1
      gradY(x, y) = outCol(y)
    Next
  Next
  
  ; ========================================================================
  ; Étape 4: Calcul de la magnitude et de la direction du gradient
  ; ========================================================================
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      magnitude(x, y) = Sqr(gradX(x, y) * gradX(x, y) + gradY(x, y) * gradY(x, y))
      direction(x, y) = ATan2(gradY(x, y), gradX(x, y))
    Next
  Next
  
  ; ========================================================================
  ; Étape 5: Suppression des non-maxima
  ; ========================================================================
  For y = 1 To ht - 2
    For x = 1 To lg - 2
      Protected angle.f = direction(x, y)
      Protected mag.f = magnitude(x, y)
      Protected mag1.f, mag2.f
      
      ; Quantification de la direction en 4 secteurs (0°, 45°, 90°, 135°)
      angle = angle * 180.0 / 3.14159265
      If angle < 0 : angle + 180.0 : EndIf
      
      If (angle >= 0 And angle < 22.5) Or (angle >= 157.5 And angle <= 180)
        ; Direction horizontale (0°)
        mag1 = magnitude(x - 1, y)
        mag2 = magnitude(x + 1, y)
      ElseIf angle >= 22.5 And angle < 67.5
        ; Direction diagonale (45°)
        mag1 = magnitude(x - 1, y - 1)
        mag2 = magnitude(x + 1, y + 1)
      ElseIf angle >= 67.5 And angle < 112.5
        ; Direction verticale (90°)
        mag1 = magnitude(x, y - 1)
        mag2 = magnitude(x, y + 1)
      Else
        ; Direction diagonale (135°)
        mag1 = magnitude(x + 1, y - 1)
        mag2 = magnitude(x - 1, y + 1)
      EndIf
      
      ; Conserver uniquement les maxima locaux
      If mag >= mag1 And mag >= mag2
        suppressed(x, y) = mag
      Else
        suppressed(x, y) = 0
      EndIf
    Next
  Next
  
  ; ========================================================================
  ; Étape 6: Seuillage par hystérésis (double seuil + suivi de contours)
  ; ========================================================================
  
  ; Marquage initial avec double seuil
  For y = 1 To ht - 2
    For x = 1 To lg - 2
      If suppressed(x, y) >= highThreshold
        edges(x, y) = 255  ; Contour fort
      ElseIf suppressed(x, y) >= lowThreshold
        edges(x, y) = 128  ; Contour faible (candidat)
      Else
        edges(x, y) = 0    ; Pas de contour
      EndIf
    Next
  Next
  
  ; Suivi des contours (connexion des contours faibles aux contours forts)
  Protected changed = #True
  Protected iterations = 0
  While changed And iterations < 100  ; Limite pour éviter boucle infinie
    changed = #False
    iterations + 1
    For y = 1 To ht - 2
      For x = 1 To lg - 2
        If edges(x, y) = 128
          ; Vérifier si un voisin est un contour fort
          If edges(x - 1, y - 1) = 255 Or edges(x, y - 1) = 255 Or edges(x + 1, y - 1) = 255 Or
             edges(x - 1, y) = 255 Or edges(x + 1, y) = 255 Or
             edges(x - 1, y + 1) = 255 Or edges(x, y + 1) = 255 Or edges(x + 1, y + 1) = 255
            edges(x, y) = 255
            changed = #True
          EndIf
        EndIf
      Next
    Next
  Wend
  
  ; Suppression des contours faibles non connectés
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      If edges(x, y) = 128
        edges(x, y) = 0
      EndIf
    Next
  Next
  
  ; ========================================================================
  ; Étape 7: Écriture du résultat
  ; ========================================================================
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      *dstPixel = *cible + (y * lg + x) * 4
      Protected edge_value.a = edges(x, y)
      PokeL(*dstPixel, $FF000000 | (edge_value * $010101))
    Next
  Next
  
  ; Libération des tableaux
  FreeArray(gray())
  FreeArray(smoothed())
  FreeArray(gradX())
  FreeArray(gradY())
  FreeArray(magnitude())
  FreeArray(direction())
  FreeArray(suppressed())
  FreeArray(edges())
  FreeArray(tempLine())
  FreeArray(tempCol())
  FreeArray(outLine())
  FreeArray(outCol())
EndProcedure

Procedure CannyDeriche(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Advanced
    *param\name = "Canny-Deriche"
    *param\remarque = "Détection de contours optimale avec filtres IIR récursifs"
    
    ; Description des paramètres
    *param\info[0] = "Alpha (échelle de lissage)"
    *param\info[1] = "Seuil bas"
    *param\info[2] = "Seuil haut"
    *param\info[3] = "Noir et blanc"
    *param\info[4] = "masque"
    
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 50
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 10
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 100 : *param\info_data(2, 2) = 30
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 1
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Note: Ce filtre traite toute l'image d'un coup (pas de multi-threading)
  ; car les étapes sont séquentielles et interdépendantes
  filter_start(@CannyDeriche_MT(), 4)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 372
; FirstLine = 313
; Folding = -
; EnableXP
; DPIAware