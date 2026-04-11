; ============================================================================
; Filtre Steerable - Détection de contours directionnels
; ============================================================================
; Permet de détecter les contours dans une direction spécifique (angle)
; Basé sur les filtres orientables de Freeman & Adelson (1991)

Macro Steerable_ReadGray(var)
  getrgb(PeekL(*srcPixel), r, g, b)
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Macro Steerable_ReadRGB(var)
  getrgb(PeekL(*srcPixel), r3(var), g3(var), b3(var))
  *srcPixel + 4
EndMacro

Procedure Steerable_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected mul.f = *param\option[0]
  Protected angle.f = *param\option[1]
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected mode = *param\option[4]  ; 0=Directionnel, 1=Magnitude, 2=Orientation
  
  ; Normalisation du multiplicateur (0-100 -> 0-5)
  Clamp(mul, 1, 100)
  mul * 0.05
  
  ; Conversion angle en radians
  Protected angleRad.f = angle * #PI / 180.0
  Protected cosA.f = Cos(angleRad)
  Protected sinA.f = Sin(angleRad)
  
  ; Tableaux pour stocker les valeurs des 9 pixels du noyau 3x3
  Protected Dim r3(8)
  Protected Dim g3(8)
  Protected Dim b3(8)
  Protected Dim gray(8)
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected a, r, g, b
  Protected x, y
  
  ; Variables pour les gradients
  Protected gx.f, gy.f, g0.f, g90.f , v
  Protected magnitude.f, orientation.f, response.f
  Protected rx.f, ry.f, bx.f, by.f
  Protected r_result.f, g_result.f, b_result.f
  
  ; Calcul des limites de traitement pour ce thread
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max + 1
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max
  
  Clamp(startPos, 1, ht - 2)
  Clamp(endPos, 1, ht - 2)
  
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
        
        ; Lecture des 9 pixels du noyau 3x3
        *srcPixel = *source + ((y - 1) * lg + (x - 1)) * 4
        Steerable_ReadGray(0) : Steerable_ReadGray(1) : Steerable_ReadGray(2)
        
        *srcPixel = *source + (y * lg + (x - 1)) * 4
        Steerable_ReadGray(3) : Steerable_ReadGray(4) : Steerable_ReadGray(5)
        
        *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
        Steerable_ReadGray(6) : Steerable_ReadGray(7) : Steerable_ReadGray(8)
        
        ; Calcul des gradients de base (0° et 90°)
        ; G0 (horizontal) - Sobel en X
        v = (gray(2) + (gray(5) << 1) + gray(8)) - (gray(0) + (gray(3) << 1) + gray(6))
        g0 = v
        ; G90 (vertical) - Sobel en Y
        v = (gray(6) + (gray(7) << 1) + gray(8)) - (gray(0) + (gray(1) << 1) + gray(2))
        g90 = v
        Select mode
          Case 0  ; Mode directionnel - filtre orienté selon l'angle
            ; Formule de rotation: G(θ) = G0*cos(θ) + G90*sin(θ)
            response = g0 * cosA + g90 * sinA
            magnitude = Abs(response) * mul
            
          Case 1  ; Mode magnitude - force du gradient total
            magnitude = Sqr(g0 * g0 + g90 * g90) * mul
            
          Case 2  ; Mode orientation - visualisation de la direction
            ; Calcul de l'angle du gradient (-180° à 180°)
            If g0 = 0 And g90 = 0
              orientation = 0
            Else
              orientation = ATan2(g90, g0) * 180.0 / #PI
            EndIf
            ; Normalisation de l'angle en niveau de gris (0-255)
            magnitude = ((orientation + 180.0) / 360.0) * 255.0
        EndSelect
        
        ; Clamping et inversion
        Clamp(magnitude, 0, 255)
        If inverse : magnitude = 255 - magnitude : EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        ; Lecture des 9 pixels du noyau 3x3
        *srcPixel = *source + ((y - 1) * lg + (x - 1)) * 4
        Steerable_ReadRGB(0) : Steerable_ReadRGB(1) : Steerable_ReadRGB(2)
        
        *srcPixel = *source + (y * lg + (x - 1)) * 4
        Steerable_ReadRGB(3) : Steerable_ReadRGB(4) : Steerable_ReadRGB(5)
        
        *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
        Steerable_ReadRGB(6) : Steerable_ReadRGB(7) : Steerable_ReadRGB(8)
        
        ; Calcul des gradients pour chaque canal
        ; Rouge
        v = (r3(2) + (r3(5) << 1) + r3(8)) - (r3(0) + (r3(3) << 1) + r3(6))
        gx = v
        v = (r3(6) + (r3(7) << 1) + r3(8)) - (r3(0) + (r3(1) << 1) + r3(2))
        gy = v
        Select mode
          Case 0
            response = gx * cosA + gy * sinA
            r_result = Abs(response) * mul
          Case 1
            r_result = Sqr(gx * gx + gy * gy) * mul
          Case 2
            If gx = 0 And gy = 0
              orientation = 0
            Else
              orientation = ATan2(gy, gx) * 180.0 / #PI
            EndIf
            r_result = ((orientation + 180.0) / 360.0) * 255.0
        EndSelect
        
        ; Vert
        v = (g3(2) + (g3(5) << 1) + g3(8)) - (g3(0) + (g3(3) << 1) + g3(6))
        gx = v
        v = (g3(6) + (g3(7) << 1) + g3(8)) - (g3(0) + (g3(1) << 1) + g3(2))
        gy = v
        Select mode
          Case 0
            response = gx * cosA + gy * sinA
            g_result = Abs(response) * mul
          Case 1
            g_result = Sqr(gx * gx + gy * gy) * mul
          Case 2
            If gx = 0 And gy = 0
              orientation = 0
            Else
              orientation = ATan2(gy, gx) * 180.0 / #PI
            EndIf
            g_result = ((orientation + 180.0) / 360.0) * 255.0
        EndSelect
        
        ; Bleu
        v = (b3(2) + (b3(5) << 1) + b3(8)) - (b3(0) + (b3(3) << 1) + b3(6))
        gx = v
        v = (b3(6) + (b3(7) << 1) + b3(8)) - (b3(0) + (b3(1) << 1) + b3(2))
        gy = v
        Select mode
          Case 0
            response = gx * cosA + gy * sinA
            b_result = Abs(response) * mul
          Case 1
            b_result = Sqr(gx * gx + gy * gy) * mul
          Case 2
            If gx = 0 And gy = 0
              orientation = 0
            Else
              orientation = ATan2(gy, gx) * 180.0 / #PI
            EndIf
            b_result = ((orientation + 180.0) / 360.0) * 255.0
        EndSelect
        
        ; Clamping
        Clamp(r_result, 0, 255)
        Clamp(g_result, 0, 255)
        Clamp(b_result, 0, 255)
        
        ; Inversion
        If inverse
          r_result = 255 - r_result
          g_result = 255 - g_result
          b_result = 255 - b_result
        EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(r_result) << 16) | (Int(g_result) << 8) | Int(b_result))
      EndIf
      
    Next
  Next
  
  ; Libération des tableaux
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
  FreeArray(gray())
EndProcedure

Procedure Steerable(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Advanced
    *param\name = "Steerable"
    *param\remarque = "Détection de contours directionnels (angle ajustable)"
    
    ; Description des paramètres
    *param\info[0] = "Multiplicateur"
    *param\info[1] = "Angle (0-360°)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "Mode (0=Dir/1=Mag/2=Orient)"
    *param\info[5] = "masque"
    
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 360 : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 2   : *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@Steerable_MT(), 5)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 181
; FirstLine = 168
; Folding = -
; EnableXP
; DPIAware