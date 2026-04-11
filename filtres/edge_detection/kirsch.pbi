; ============================================================================
; Filtre Kirsch - Détection de contours 8 directions optimisé
; ============================================================================

Macro Kirsch_ReadGray(var)
  getrgb(PeekL(*srcPixel), r, g, b)
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Macro Kirsch_ReadRGB(var)
  getrgb(PeekL(*srcPixel), r3(var), g3(var), b3(var))
  *srcPixel + 4
EndMacro

Procedure Kirsch_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected mul.f = *param\option[0]
  Protected toGray = *param\option[1]
  Protected inverse = *param\option[2]
  
  ; Normalisation du multiplicateur (0-100 -> 0-5)
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
  Protected valR, valG, valB, valGray, maxVal
  Protected rMax, gMax, bMax
  
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
  
  ; Masques Kirsch (8 directions, 9 positions du noyau 3x3)
  ; Organisation: [direction, position]
  ; Positions: 0=NW, 1=N, 2=NE, 3=W, 4=C, 5=E, 6=SW, 7=S, 8=SE
  Protected Dim mask(7, 8)
  
  DataSection
    kirsch_data:
    ; N (Nord)
    Data.i  5,  5,  5, -3,  0, -3, -3, -3, -3
    ; NE (Nord-Est)
    Data.i  5,  5, -3,  5,  0, -3, -3, -3, -3
    ; E (Est)
    Data.i -3,  5,  5, -3,  0,  5, -3, -3, -3
    ; SE (Sud-Est)
    Data.i -3, -3,  5, -3,  0,  5, -3, -3,  5
    ; S (Sud)
    Data.i -3, -3, -3, -3,  0, -3,  5,  5,  5
    ; SW (Sud-Ouest)
    Data.i -3, -3, -3, -3,  0,  5,  5,  5, -3
    ; W (Ouest)
    Data.i -3, -3, -3,  5,  0,  5,  5, -3, -3
    ; NW (Nord-Ouest)
    Data.i  5, -3, -3,  5,  0, -3,  5, -3, -3
  EndDataSection
  
  ; Charger les masques depuis la DataSection
  Restore kirsch_data
  For dir = 0 To 7
    For i = 0 To 8
      Read.i mask(dir, i)
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
        Kirsch_ReadGray(0) : Kirsch_ReadGray(1) : Kirsch_ReadGray(2)
        
        ; Ligne centrale (y)
        *srcPixel = *source + (y * lg + (x - 1)) * 4
        Kirsch_ReadGray(3) : Kirsch_ReadGray(4) : Kirsch_ReadGray(5)
        
        ; Ligne inférieure (y+1)
        *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
        Kirsch_ReadGray(6) : Kirsch_ReadGray(7) : Kirsch_ReadGray(8)
        
        ; Calcul du maximum sur les 8 directions
        maxVal = 0
        
        For dir = 0 To 7
          valGray = 0
          
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
        Kirsch_ReadRGB(0) : Kirsch_ReadRGB(1) : Kirsch_ReadRGB(2)
        
        ; Ligne centrale (y)
        *srcPixel = *source + (y * lg + (x - 1)) * 4
        Kirsch_ReadRGB(3) : Kirsch_ReadRGB(4) : Kirsch_ReadRGB(5)
        
        ; Ligne inférieure (y+1)
        *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
        Kirsch_ReadRGB(6) : Kirsch_ReadRGB(7) : Kirsch_ReadRGB(8)
        
        ; Calcul des maximums sur les 8 directions pour chaque canal
        rMax = 0 : gMax = 0 : bMax = 0
        
        For dir = 0 To 7
          valR = 0 : valG = 0 : valB = 0
          
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

Procedure Kirsch(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Gradient
    *param\name = "Kirsch"
    *param\remarque = "Détection de contours 8 directions (opérateur de Kirsch)"
    
    ; Description des paramètres
    *param\info[0] = "Multiplicateur"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Inversion"
    *param\info[3] = "masque"
    
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 2   : *param\info_data(3, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@Kirsch_MT(), 3)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; FirstLine = 172
; Folding = -
; EnableXP
; DPIAware