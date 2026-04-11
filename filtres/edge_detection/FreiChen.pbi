; ============================================================================
; Filtre Frei-Chen - Détection de contours avec masques normalisés optimisé
; ============================================================================

Macro FreiChen_ReadGray(var)
  getrgb(PeekL(*srcPixel), r, g, b)
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Macro FreiChen_ReadRGB(var)
  getrgb(PeekL(*srcPixel), r3(var), g3(var), b3(var))
  *srcPixel + 4
EndMacro

Procedure FreiChen_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected mul.f = *param\option[0]
  Protected toGray = *param\option[1]
  Protected inverse = *param\option[2]
  Protected mask_type = *param\option[3]  ; Paramètre masque (pour une autre procédure)
  
  ; Normalisation du multiplicateur (1-100 -> 0.05-5)
  Clamp(mul, 1, 100)
  mul * 0.05
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  
  ; Tableaux pour stocker les valeurs RGB ou niveaux de gris des 9 pixels du noyau 3x3
  Protected Dim r3(8)
  Protected Dim g3(8)
  Protected Dim b3(8)
  Protected Dim gray(8)
  
  Protected a, r, g, b
  Protected x, y, i, dir
  Protected.f valR, valG, valB, valGray, maxVal
  Protected.f rMax, gMax, bMax
  
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
  
  ; Masques Frei-Chen (8 directions, 9 positions du noyau 3x3)
  ; Organisation: [direction, position]
  ; Positions: 0=NW, 1=N, 2=NE, 3=W, 4=C, 5=E, 6=SW, 7=S, 8=SE
  ; Note : Frei-Chen utilise sqrt(2) ~ 1.4142 pour normalisation
  Protected Dim mask.f(7, 8)
  
  DataSection
    FreiChen_data:
    ; M1 (Nord)
    Data.f  1,  1.4142,  1,      0,   0,   0,     -1, -1.4142, -1
    ; M2 (Nord-Est)
    Data.f  0,  1,       1.4142, -1,  0,   1.4142, -1, -1,      0
    ; M3 (Est)
    Data.f -1,  0,       1,      -1,  0,   1,      -1,  0,      1
    ; M4 (Sud-Est)
    Data.f -1, -1.4142,  0,      -1,  0,   1.4142,  0,  1.4142, 1
    ; M5 (Sud)
    Data.f -1, -1.4142, -1,       0,  0,   0,       1,  1.4142, 1
    ; M6 (Sud-Ouest)
    Data.f  0, -1,      -1.4142,  1,  0,  -1.4142,  1,  1,      0
    ; M7 (Ouest)
    Data.f  1,  0,      -1,       1,  0,  -1,       1,  0,     -1
    ; M8 (Nord-Ouest)
    Data.f  1,  1.4142,  0,       1,  0,  -1.4142,  0, -1.4142,-1
  EndDataSection
  
  ; Charger les masques depuis la DataSection
  Restore FreiChen_data
  For dir = 0 To 7
    For i = 0 To 8
      Read.f mask(dir, i)
    Next
  Next
  
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
        FreiChen_ReadGray(0) : FreiChen_ReadGray(1) : FreiChen_ReadGray(2)
        
        ; Ligne centrale (y)
        *srcPixel = *source + (y * lg + (x - 1)) * 4
        FreiChen_ReadGray(3) : FreiChen_ReadGray(4) : FreiChen_ReadGray(5)
        
        ; Ligne inférieure (y+1)
        *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
        FreiChen_ReadGray(6) : FreiChen_ReadGray(7) : FreiChen_ReadGray(8)
        
        ; Calcul du maximum sur les 8 directions
        maxVal = 0.0
        
        For dir = 0 To 7
          valGray = 0.0
          
          ; Convolution avec le masque de direction
          For i = 0 To 8
            valGray + gray(i) * mask(dir, i)
          Next
          
          ; Prendre la valeur absolue
          valGray = Abs(valGray)
          
          ; Garder le maximum
          If valGray > maxVal
            maxVal = valGray
          EndIf
        Next
        
        ; Application du multiplicateur
        r = maxVal * mul
        
        ; Clamping et inversion
        Clamp(r, 0, 255)
        If inverse : r = 255 - r : EndIf
        
        ; Écriture du pixel résultat (alpha = 255)
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (r * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        ; Lecture des 9 pixels du noyau 3x3 en couleur
        ; Ligne supérieure (y-1)
        *srcPixel = *source + ((y - 1) * lg + (x - 1)) * 4
        FreiChen_ReadRGB(0) : FreiChen_ReadRGB(1) : FreiChen_ReadRGB(2)
        
        ; Ligne centrale (y)
        *srcPixel = *source + (y * lg + (x - 1)) * 4
        FreiChen_ReadRGB(3) : FreiChen_ReadRGB(4) : FreiChen_ReadRGB(5)
        
        ; Ligne inférieure (y+1)
        *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
        FreiChen_ReadRGB(6) : FreiChen_ReadRGB(7) : FreiChen_ReadRGB(8)
        
        ; Calcul des maximums sur les 8 directions pour chaque canal
        rMax = 0.0 : gMax = 0.0 : bMax = 0.0
        
        For dir = 0 To 7
          valR = 0.0 : valG = 0.0 : valB = 0.0
          
          ; Convolution avec le masque de direction
          For i = 0 To 8
            valR + r3(i) * mask(dir, i)
            valG + g3(i) * mask(dir, i)
            valB + b3(i) * mask(dir, i)
          Next
          
          ; Prendre la valeur absolue
          valR = Abs(valR)
          valG = Abs(valG)
          valB = Abs(valB)
          
          ; Garder le maximum pour chaque canal
          If valR > rMax : rMax = valR : EndIf
          If valG > gMax : gMax = valG : EndIf
          If valB > bMax : bMax = valB : EndIf
        Next
        
        ; Application du multiplicateur
        r = rMax * mul
        g = gMax * mul
        b = bMax * mul
        
        ; Clamping et inversion
        clamp_rgb(r, g, b)
        If inverse
          r = 255 - r
          g = 255 - g
          b = 255 - b
        EndIf
        
        ; Écriture du pixel résultat (alpha = 255)
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (r << 16) | (g << 8) | b)
      EndIf
      
    Next
  Next
  
  ; Libération des tableaux
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
  FreeArray(gray())
  FreeArray(mask())
EndProcedure

Procedure FreiChen(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Gradient
    *param\name = "Frei-Chen"
    *param\remarque = "Détection de contours avec masques normalisés (opérateur de Frei-Chen)"
    
    ; Description des paramètres
    *param\info[0] = "Multiplicateur"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Inversion"
    *param\info[3] = "Masque"
    
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 2   : *param\info_data(3, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@FreiChen_MT(), 3)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 241
; FirstLine = 173
; Folding = -
; EnableXP
; DPIAware