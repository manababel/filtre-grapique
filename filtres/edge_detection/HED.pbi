; ============================================================================
; Filtre HED - Holistically-Nested Edge Detection
; ============================================================================
; Inspiré de l'algorithme de Xie & Tu (2015)
; Détection de contours multi-échelle avec fusion hiérarchique
; Simule une approche deep learning avec des échelles multiples

Macro HED_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Procedure.f HED_GradientScale1(Array values(1))
  ; Échelle 1: gradient local 3x3 (détails fins)
  Protected gx.f, gy.f , v
  
  v = (values(2) + (values(5) << 1) + values(8)) - (values(0) + (values(3) << 1) + values(6))
  gx = v
  v = (values(6) + (values(7) << 1) + values(8)) - (values(0) + (values(1) << 1) + values(2))
  gy = v
  
  ProcedureReturn Sqr(gx * gx + gy * gy)
EndProcedure

Procedure.f HED_GradientScale2(Array values(1))
  ; Échelle 2: gradient 5x5 (contours moyens)
  Protected gx.f, gy.f , v
  
  ; Approximation avec échantillonnage sparse
  v = (values(4) - values(0)) + ((values(9) - values(5)) << 1) + (values(14) - values(10))
  gx = v
  v = (values(20) - values(0)) + ((values(21) - values(1)) << 1) + (values(22) - values(2))
  gy = v
  ProcedureReturn Sqr(gx * gx + gy * gy) * 0.7
EndProcedure

Procedure.f HED_GradientScale3(Array values(1))
  ; Échelle 3: gradient large échelle (structures globales)
  Protected gx.f, gy.f
  
  ; Gradient sur les coins du noyau 5x5
  gx = values(24) - values(0)
  gy = values(20) - values(4)
  
  ProcedureReturn Sqr(gx * gx + gy * gy) * 0.5
EndProcedure

Procedure.f HED_LocalVariance(Array values(1), size)
  ; Calcul de la variance locale (cohérence)
  Protected i, sum.f, sumSq.f, mean.f, variance.f
  Protected count = size * size
  
  For i = 0 To count - 1
    sum + values(i)
    sumSq + values(i) * values(i)
  Next
  
  mean = sum / count
  variance = (sumSq / count) - (mean * mean)
  
  ProcedureReturn Sqr(variance) * 0.3
EndProcedure

Procedure.f HED_EdgeOrientation(Array values(1))
  ; Calcul de la cohérence d'orientation (suppression non-maximum simplifiée)
  Protected gx.f, gy.f, orientation.f, strength.f , v
  
  v = (values(2) + (values(5) << 1) + values(8)) - (values(0) + (values(3) << 1) + values(6))
  gx = v
  v = (values(6) + (values(7) << 1) + values(8)) - (values(0) + (values(1) << 1) + values(2))
  gy = v
  
  strength = Sqr(gx * gx + gy * gy)
  
  If strength > 1.0
    ; Vérification de cohérence directionnelle
    orientation = ATan2(gy, gx)
    ProcedureReturn strength
  Else
    ProcedureReturn 0
  EndIf
EndProcedure

Procedure.f HED_ColorGradientMultiScale(Array r3(1), Array g3(1), Array b3(1))
  ; Gradient couleur multi-échelle
  Protected rx.f, ry.f, gx.f, gy.f, bx.f, by.f , v
  Protected rMag.f, gMag.f, bMag.f
  
  ; Gradient 3x3
  v = (r3(2) + (r3(5) << 1) + r3(8)) - (r3(0) + (r3(3) << 1) + r3(6))
  rx = v
  v = (r3(6) + (r3(7) << 1) + r3(8)) - (r3(0) + (r3(1) << 1) + r3(2))
  ry=v
  v = (g3(2) + (g3(5) << 1) + g3(8)) - (g3(0) + (g3(3) << 1) + g3(6))
  gx = v
  v = (g3(6) + (g3(7) << 1) + g3(8)) - (g3(0) + (g3(1) << 1) + g3(2))
  gy = v
  v = (b3(2) + (b3(5) << 1) + b3(8)) - (b3(0) + (b3(3) << 1) + b3(6))
  bx = v
  v = (b3(6) + (b3(7) << 1) + b3(8)) - (b3(0) + (b3(1) << 1) + b3(2))
  by = v
  rMag = Sqr(rx * rx + ry * ry)
  gMag = Sqr(gx * gx + gy * gy)
  bMag = Sqr(bx * bx + by * by)
  
  ; Combinaison des canaux (max pour robustesse)
  max(v,gMag, bMag)
  max(v,v, rMag)
  ProcedureReturn v
EndProcedure

Procedure HED_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected threshold.f = *param\option[0]   ; Seuil de détection (1-100)
  Protected scales = *param\option[1]        ; Nombre d'échelles (1-3)
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected fusion = *param\option[4]        ; Mode fusion (0=Max, 1=Moyenne, 2=Pondéré)
  
  ; Normalisation du seuil
  Clamp(threshold, 1, 100)
  threshold * 0.01  ; 0.01 - 1.0
  
  Clamp(scales, 1, 3)
  
  ; Tableaux pour noyau 5x5 (25 pixels)
  Protected Dim r3(24)
  Protected Dim g3(24)
  Protected Dim b3(24)
  Protected Dim gray(24)
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected r, g, b
  Protected x, y, i, j, idx
  
  ; Variables de calcul multi-échelle
  Protected scale1.f, scale2.f, scale3.f
  Protected variance.f, orientation.f
  Protected edgeStrength.f, fusedEdge.f
  Protected magnitude
  
  ; Poids de fusion hiérarchique
  Protected w1.f = 0.5  ; Détails fins
  Protected w2.f = 0.3  ; Structures moyennes
  Protected w3.f = 0.2  ; Contexte global
  
  ; Limites de traitement pour ce thread
  Protected kRadius = 2  ; Rayon du noyau 5x5
  Protected startPos = (*param\thread_pos * (ht - 4)) / *param\thread_max + kRadius
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 4)) / *param\thread_max + kRadius - 1
  
  Clamp(startPos, kRadius, ht - kRadius - 1)
  Clamp(endPos, kRadius, ht - kRadius - 1)
  
  If startPos > endPos
    ProcedureReturn
  EndIf
  
  ; ========================================================================
  ; Traitement des pixels
  ; ========================================================================
  For y = startPos To endPos
    For x = kRadius To lg - kRadius - 1
      
      ; Lecture du voisinage 5x5
      idx = 0
      For j = -kRadius To kRadius
        For i = -kRadius To kRadius
          *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
          HED_ReadPixel(idx)
          idx + 1
        Next
      Next
      
      If toGray
        ; ====================================================================
        ; MODE NIVEAU DE GRIS
        ; ====================================================================
        
        ; Calcul multi-échelle
        scale1 = HED_GradientScale1(gray())  ; Fins détails
        
        If scales >= 2
          scale2 = HED_GradientScale2(gray())  ; Structures moyennes
        Else
          scale2 = 0
        EndIf
        
        If scales >= 3
          scale3 = HED_GradientScale3(gray())  ; Contexte global
          variance = HED_LocalVariance(gray(), 5)
        Else
          scale3 = 0
          variance = 0
        EndIf
        
        ; Fusion hiérarchique des échelles
        Select fusion
          Case 0  ; Maximum (contours les plus forts)
              Max(fusedEdge , scale2 , scale3)
              Max(fusedEdge , fusedEdge, scale1)
            
          Case 1  ; Moyenne (équilibrée)
            If scales = 1
              fusedEdge = scale1
            ElseIf scales = 2
              fusedEdge = (scale1 + scale2) * 0.5
            Else
              fusedEdge = (scale1 + scale2 + scale3) / 3.0
            EndIf
            
          Case 2  ; Pondérée (hiérarchique - méthode HED originale)
            fusedEdge = scale1 * w1 + scale2 * w2 + scale3 * w3 + variance
        EndSelect
        
        ; Application du seuil et normalisation
        edgeStrength = fusedEdge * threshold
        magnitude = edgeStrength * 10.0
        
        Clamp(magnitude, 0, 255)
        If inverse : magnitude = 255 - magnitude : EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        ; Calcul multi-échelle sur les canaux couleur
        scale1 = HED_ColorGradientMultiScale(r3(), g3(), b3())
        
        If scales >= 2
          ; Échelle 2: gradient moyen (sous-échantillonnage)
          scale2 = (Abs(r3(24) - r3(0)) + Abs(g3(24) - g3(0)) + Abs(b3(24) - b3(0))) * 0.5
        Else
          scale2 = 0
        EndIf
        
        If scales >= 3
          ; Échelle 3: contexte couleur
          scale3 = HED_LocalVariance(gray(), 5)
        Else
          scale3 = 0
        EndIf
        
        ; Fusion hiérarchique
        Select fusion
          Case 0
            Max(fusedEdge , scale2 , scale3)
            Max(fusedEdge , fusedEdge, scale1)
          Case 1
            If scales = 1
              fusedEdge = scale1
            ElseIf scales = 2
              fusedEdge = (scale1 + scale2) * 0.5
            Else
              fusedEdge = (scale1 + scale2 + scale3) / 3.0
            EndIf
          Case 2
            fusedEdge = scale1 * w1 + scale2 * w2 + scale3 * w3
        EndSelect
        
        ; Application sur chaque canal avec légère variation
        edgeStrength = fusedEdge * threshold * 10.0
        
        r = edgeStrength * 1.0
        g = edgeStrength * 0.97
        b = edgeStrength * 0.94
        
        Clamp(r, 0, 255)
        Clamp(g, 0, 255)
        Clamp(b, 0, 255)
        
        If inverse
          r = 255 - r
          g = 255 - g
          b = 255 - b
        EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b))
      EndIf
      
    Next
  Next
  
  ; Libération des tableaux
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
  FreeArray(gray())
EndProcedure

Procedure HED(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Advanced
    *param\name = "HED (Holistically-Nested)"
    *param\remarque = "Détection multi-échelle avec fusion hiérarchique"
    
    ; Description des paramètres
    *param\info[0] = "Seuil de détection"
    *param\info[1] = "Nombre d'échelles (1-3)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "Fusion (0=Max/1=Moy/2=Pond)"
    *param\info[5] = "masque"
    
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 30
    *param\info_data(1, 0) = 1   : *param\info_data(1, 1) = 3   : *param\info_data(1, 2) = 3
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 2
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 2   : *param\info_data(5, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@HED_MT(), 5)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 258
; FirstLine = 234
; Folding = --
; EnableXP
; DPIAware