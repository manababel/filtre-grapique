; ============================================================================
; Filtre Zero Crossing - Détection de passages par zéro (Laplacien)
; ============================================================================

Macro ZeroCrossing_ReadGray(var)
  getrgb(PeekL(*srcPixel), r, g, b)
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Macro ZeroCrossing_ReadRGB(var)
  getrgb(PeekL(*srcPixel), r3(var), g3(var), b3(var))
  *srcPixel + 4
EndMacro

Procedure ZeroCrossing_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected threshold = *param\option[0]
  Protected kernelType = *param\option[1]
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  
  ; Normalisation du seuil (0-100 -> 0-50)
  Clamp(threshold, 0, 100)
  threshold = threshold * 0.5
  
  ; Tableaux pour stocker les valeurs RGB/Gray des 9 pixels du noyau 3x3
  Protected Dim r3(8)
  Protected Dim g3(8)
  Protected Dim b3(8)
  Protected Dim gray(8)
  
  ; Tableaux pour les coefficients du noyau Laplacien
  Protected Dim kernel(8)
  
  ; Sélection du type de noyau Laplacien
  Select kernelType
    Case 0  ; Laplacien 4-connecté (croix)
      ; [ 0  1  0]
      ; [ 1 -4  1]
      ; [ 0  1  0]
      kernel(0) = 0  : kernel(1) = 1  : kernel(2) = 0
      kernel(3) = 1  : kernel(4) = -4 : kernel(5) = 1
      kernel(6) = 0  : kernel(7) = 1  : kernel(8) = 0
      
    Case 1  ; Laplacien 8-connecté (complet)
      ; [ 1  1  1]
      ; [ 1 -8  1]
      ; [ 1  1  1]
      kernel(0) = 1  : kernel(1) = 1  : kernel(2) = 1
      kernel(3) = 1  : kernel(4) = -8 : kernel(5) = 1
      kernel(6) = 1  : kernel(7) = 1  : kernel(8) = 1
      
    Case 2  ; Laplacien diagonal
      ; [ 1  2  1]
      ; [ 2 -12 2]
      ; [ 1  2  1]
      kernel(0) = 1  : kernel(1) = 2  : kernel(2) = 1
      kernel(3) = 2  : kernel(4) = -12 : kernel(5) = 2
      kernel(6) = 1  : kernel(7) = 2  : kernel(8) = 1
  EndSelect
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected a, r, g, b
  Protected x, y, i ,j
  Protected laplacian_r.f, laplacian_g.f, laplacian_b.f, laplacian_gray.f
  Protected zc_r, zc_g, zc_b, zc_gray
  Protected neighbor_r.f, neighbor_g.f, neighbor_b.f, neighbor_gray.f
  Protected sign_change
  
  ; Calcul des limites de traitement pour ce thread
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max + 1
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max
  
  ; Validation des limites (éviter les bords)
  Clamp(startPos, 1, ht - 2)
  Clamp(endPos, 1, ht - 2)
  
  ; Vérification que la zone de traitement est valide
  If startPos > endPos
    ProcedureReturn
  EndIf
  
  ; ========================================================================
  ; Traitement des pixels
  ; ========================================================================
  For y = startPos To endPos
    For x = 1 To lg - 2
      
      If toGray
        ; ====================================================================
        ; MODE NIVEAU DE GRIS
        ; ====================================================================
        
        ; Lecture des 9 pixels du noyau 3x3 en niveaux de gris
        ; Ligne supérieure (y-1)
        *srcPixel = *source + ((y - 1) * lg + (x - 1)) * 4
        ZeroCrossing_ReadGray(0) : ZeroCrossing_ReadGray(1) : ZeroCrossing_ReadGray(2)
        
        ; Ligne centrale (y)
        *srcPixel = *source + (y * lg + (x - 1)) * 4
        ZeroCrossing_ReadGray(3) : ZeroCrossing_ReadGray(4) : ZeroCrossing_ReadGray(5)
        
        ; Ligne inférieure (y+1)
        *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
        ZeroCrossing_ReadGray(6) : ZeroCrossing_ReadGray(7) : ZeroCrossing_ReadGray(8)
        
        ; Calcul du Laplacien (convolution avec le noyau)
        laplacian_gray = 0
        For i = 0 To 8
          laplacian_gray + gray(i) * kernel(i)
        Next
        
        ; Détection du passage par zéro
        zc_gray = 0
        sign_change = #False
        
        ; Vérification si le Laplacien change de signe avec les voisins
        For i = 0 To 8
          If i = 4 : Continue : EndIf  ; Ignore le pixel central
          
          neighbor_gray = 0
          For j = 0 To 8
            neighbor_gray + gray(j) * kernel((i + j) % 9)
          Next
          
          ; Détection du changement de signe
          If (laplacian_gray * neighbor_gray < 0) And (Abs(laplacian_gray - neighbor_gray) > threshold)
            sign_change = #True
            Break
          EndIf
        Next
        
        ; Si passage par zéro détecté, marquer le contour
        If sign_change
          zc_gray = 255
        Else
          zc_gray = 0
        EndIf
        
        ; Inversion
        If inverse : zc_gray = 255 - zc_gray : EndIf
        
        ; Écriture du pixel résultat (alpha = 255)
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (zc_gray * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        ; Lecture des 9 pixels du noyau 3x3 en couleur
        ; Ligne supérieure (y-1)
        *srcPixel = *source + ((y - 1) * lg + (x - 1)) * 4
        ZeroCrossing_ReadRGB(0) : ZeroCrossing_ReadRGB(1) : ZeroCrossing_ReadRGB(2)
        
        ; Ligne centrale (y)
        *srcPixel = *source + (y * lg + (x - 1)) * 4
        ZeroCrossing_ReadRGB(3) : ZeroCrossing_ReadRGB(4) : ZeroCrossing_ReadRGB(5)
        
        ; Ligne inférieure (y+1)
        *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
        ZeroCrossing_ReadRGB(6) : ZeroCrossing_ReadRGB(7) : ZeroCrossing_ReadRGB(8)
        
        ; Calcul du Laplacien pour chaque canal
        laplacian_r = 0 : laplacian_g = 0 : laplacian_b = 0
        For i = 0 To 8
          laplacian_r + r3(i) * kernel(i)
          laplacian_g + g3(i) * kernel(i)
          laplacian_b + b3(i) * kernel(i)
        Next
        
        ; Détection du passage par zéro pour chaque canal
        zc_r = 0 : zc_g = 0 : zc_b = 0
        
        ; Canal Rouge
        sign_change = #False
        For i = 0 To 8
          If i = 4 : Continue : EndIf
          neighbor_r = 0
          For j = 0 To 8
            neighbor_r + r3(j) * kernel((i + j) % 9)
          Next
          If (laplacian_r * neighbor_r < 0) And (Abs(laplacian_r - neighbor_r) > threshold)
            sign_change = #True
            Break
          EndIf
        Next
        If sign_change : zc_r = 255 : EndIf
        
        ; Canal Vert
        sign_change = #False
        For i = 0 To 8
          If i = 4 : Continue : EndIf
          neighbor_g = 0
          For j = 0 To 8
            neighbor_g + g3(j) * kernel((i + j) % 9)
          Next
          If (laplacian_g * neighbor_g < 0) And (Abs(laplacian_g - neighbor_g) > threshold)
            sign_change = #True
            Break
          EndIf
        Next
        If sign_change : zc_g = 255 : EndIf
        
        ; Canal Bleu
        sign_change = #False
        For i = 0 To 8
          If i = 4 : Continue : EndIf
          neighbor_b = 0
          For j = 0 To 8
            neighbor_b + b3(j) * kernel((i + j) % 9)
          Next
          If (laplacian_b * neighbor_b < 0) And (Abs(laplacian_b - neighbor_b) > threshold)
            sign_change = #True
            Break
          EndIf
        Next
        If sign_change : zc_b = 255 : EndIf
        
        ; Inversion
        If inverse
          zc_r = 255 - zc_r
          zc_g = 255 - zc_g
          zc_b = 255 - zc_b
        EndIf
        
        ; Écriture du pixel résultat (alpha = 255)
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (zc_r << 16) | (zc_g << 8) | zc_b)
      EndIf
      
    Next
  Next
  
  ; Libération des tableaux
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
  FreeArray(gray())
  FreeArray(kernel())
EndProcedure

Procedure ZeroCrossing(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Laplacian
    *param\name = "Zero Crossing"
    *param\remarque = "Détection de contours par passages par zéro du Laplacien"
    
    ; Description des paramètres
    *param\info[0] = "Seuil"
    *param\info[1] = "Type noyau (0=4-conn/1=8-conn/2=Diag)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "masque"
    
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 0   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 2   : *param\info_data(1, 2) = 1
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 1
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@ZeroCrossing_MT(), 4)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 216
; FirstLine = 182
; Folding = -
; EnableXP
; DPIAware