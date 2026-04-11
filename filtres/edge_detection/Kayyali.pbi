; ============================================================================
; Filtre Kayyali - Détection de contours rapide optimisé
; ============================================================================

Macro Kayyali_ReadGray(var)
  getrgb(PeekL(*srcPixel), r, g, b)
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Macro Kayyali_ReadRGB(var)
  getrgb(PeekL(*srcPixel), r3(var), g3(var), b3(var))
  *srcPixel + 4
EndMacro

Procedure Kayyali_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht

  Protected mul.f = *param\option[0]
  Protected mat = *param\option[1]
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]

  ; Normalisation du multiplicateur (1-100 -> 0.1-10)
  ; Kayyali est moins énergique que Sobel, donc facteur x2
  Clamp(mul, 1, 100)
  mul * 0.1

  Protected Dim r3(8)
  Protected Dim g3(8)
  Protected Dim b3(8)
  Protected Dim gray(8)

  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected a, r, g, b
  Protected x, y
  Protected rx, gx, bx, ry, gy, by
  Protected magnitude

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
        Kayyali_ReadGray(0) : Kayyali_ReadGray(1) : Kayyali_ReadGray(2)

        ; Ligne centrale (y)
        *srcPixel = *source + (y * lg + (x - 1)) * 4
        Kayyali_ReadGray(3) : Kayyali_ReadGray(4) : Kayyali_ReadGray(5)

        ; Ligne inférieure (y+1)
        *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
        Kayyali_ReadGray(6) : Kayyali_ReadGray(7) : Kayyali_ReadGray(8)

        ; Masque Kayyali Gx (gradient horizontal simplifié)
        ; Gx = [-1  0  1]
        ;      [-1  0  1]
        ;      [-1  0  1]
        rx = (gray(2) + gray(5) + gray(8)) - (gray(0) + gray(3) + gray(6))

        ; Masque Kayyali Gy (gradient vertical simplifié)
        ; Gy = [-1 -1 -1]
        ;      [ 0  0  0]
        ;      [ 1  1  1]
        ry = (gray(6) + gray(7) + gray(8)) - (gray(0) + gray(1) + gray(2))

        ; Calcul de la magnitude du gradient
        If mat = 0
          ; Méthode euclidienne: sqrt(Gx² + Gy²)
          magnitude = Sqr(rx * rx + ry * ry) * mul
        Else
          ; Méthode Manhattan: |Gx| + |Gy|
          rx = Abs(rx)
          ry = Abs(ry)
          magnitude = (rx + ry) * mul
        EndIf

        ; Clamping et inversion
        Clamp(magnitude, 0, 255)
        If inverse : magnitude = 255 - magnitude : EndIf

        ; Écriture du pixel résultat (alpha = 255)
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (magnitude * $010101))

      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        ; Lecture des 9 pixels du noyau 3x3 en couleur
        ; Ligne supérieure (y-1)
        *srcPixel = *source + ((y - 1) * lg + (x - 1)) * 4
        Kayyali_ReadRGB(0) : Kayyali_ReadRGB(1) : Kayyali_ReadRGB(2)

        ; Ligne centrale (y)
        *srcPixel = *source + (y * lg + (x - 1)) * 4
        Kayyali_ReadRGB(3) : Kayyali_ReadRGB(4) : Kayyali_ReadRGB(5)

        ; Ligne inférieure (y+1)
        *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
        Kayyali_ReadRGB(6) : Kayyali_ReadRGB(7) : Kayyali_ReadRGB(8)

        ; Masque Kayyali Gx (gradient horizontal)
        rx = (r3(2) + r3(5) + r3(8)) - (r3(0) + r3(3) + r3(6))
        gx = (g3(2) + g3(5) + g3(8)) - (g3(0) + g3(3) + g3(6))
        bx = (b3(2) + b3(5) + b3(8)) - (b3(0) + b3(3) + b3(6))

        ; Masque Kayyali Gy (gradient vertical)
        ry = (r3(6) + r3(7) + r3(8)) - (r3(0) + r3(1) + r3(2))
        gy = (g3(6) + g3(7) + g3(8)) - (g3(0) + g3(1) + g3(2))
        by = (b3(6) + b3(7) + b3(8)) - (b3(0) + b3(1) + b3(2))

        ; Calcul de la magnitude du gradient pour chaque canal
        If mat = 0
          ; Méthode euclidienne: sqrt(Gx² + Gy²)
          r = Sqr(rx * rx + ry * ry) * mul
          g = Sqr(gx * gx + gy * gy) * mul
          b = Sqr(bx * bx + by * by) * mul
        Else
          ; Méthode Manhattan: |Gx| + |Gy|
          rx = Abs(rx) : gx = Abs(gx) : bx = Abs(bx)
          ry = Abs(ry) : gy = Abs(gy) : by = Abs(by)
          r = (rx + ry) * mul
          g = (gx + gy) * mul
          b = (bx + by) * mul
        EndIf

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
EndProcedure

Procedure Kayyali(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Gradient
    *param\name = "Kayyali"
    *param\remarque = "Détection de contours rapide (opérateur de Kayyali)"

    ; Description des paramètres
    *param\info[0] = "Multiplicateur"
    *param\info[1] = "Méthode (0=Euclidienne/1=Manhattan)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "masque"
    
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 1
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf

  ; Lancement du traitement multi-thread
  filter_start(@Kayyali_MT(), 4)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 197
; FirstLine = 133
; Folding = -
; EnableXP
; DPIAware