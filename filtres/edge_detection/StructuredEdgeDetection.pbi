; ============================================================================
; Filtre Structured Edge Detection - Détection de contours structurés
; ============================================================================
; Basé sur l'algorithme de Dollar & Zitnick (2013)
; Combine gradient local, texture et contexte spatial pour une meilleure détection

Macro SED_ReadPixel(var)
  Protected pixel = PeekL(*srcPixel)
  getrgb(pixel, r, g, b)
  r3(var) = r : g3(var) = g : b3(var) = b
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Procedure.f SED_ComputeGradient(Array values(1), size)
  ; Calcul du gradient local avec noyau de Sobel
  Protected gx.f, gy.f , v
  Protected center = size >> 1
  
  If size = 3
    ; Noyau 3x3 standard
    v = (values(2) + (values(5) << 1) + values(8)) - (values(0) + (values(3) << 1) + values(6))
    gx = v
    v = (values(6) + (values(7) << 1) + values(8)) - (values(0) + (values(1) << 1) + values(2))
    gy = v
  Else
    ; Noyau 5x5 pour plus de contexte
    v = values(4) - values(0) + (values(9) << 1) - (values(5) << 1) + values(14) - values(10)
    gx = v
    v = values(20) - values(0) + (values(21) << 1) - (values(1) << 1) + values(22) - values(2)
    gx = v
  EndIf
  
  ProcedureReturn Sqr(gx * gx + gy * gy)
EndProcedure

Procedure.f SED_ComputeTexture(Array gray(1), size)
  ; Calcul de la variance locale (mesure de texture)
  Protected i, sum.f, sumSq.f, mean.f, variance.f
  Protected count = size * size
  
  For i = 0 To count - 1
    sum + gray(i)
    sumSq + gray(i) * gray(i)
  Next
  
  mean = sum / count
  variance = (sumSq / count) - (mean * mean)
  
  ProcedureReturn Sqr(variance)
EndProcedure

Procedure.f SED_ComputeColorGradient(Array r3(1), Array g3(1), Array b3(1), size)
  ; Gradient combiné sur les 3 canaux couleur
  Protected rx.f, ry.f, gx.f, gy.f, bx.f, by.f , v
  Protected rMag.f, gMag.f, bMag.f
  
  If size = 3
    v = (r3(2) + (r3(5) << 1) + r3(8)) - (r3(0) + (r3(3) << 1) + r3(6))
    rx  = v
    v = (r3(6) + (r3(7) << 1) + r3(8)) - (r3(0) + (r3(1) << 1) + r3(2))
    ry = v
    v = (g3(2) + (g3(5) << 1) + g3(8)) - (g3(0) + (g3(3) << 1) + g3(6))
    gx = v
    v = (g3(6) + (g3(7) << 1) + g3(8)) - (g3(0) + (g3(1) << 1) + g3(2))
    gy = v
    v = (b3(2) + (b3(5) << 1) + b3(8)) - (b3(0) + (b3(3) << 1) + b3(6))
    bx = v
    v = (b3(6) + (b3(7) << 1) + b3(8)) - (b3(0) + (b3(1) << 1) + b3(2))
    by = v
  EndIf
  
  rMag = Sqr(rx * rx + ry * ry)
  gMag = Sqr(gx * gx + gy * gy)
  bMag = Sqr(bx * bx + by * by)
  
  ; Retourne le maximum des gradients (canal le plus informatif)
  max(v,gMag, bMag)
  max(v,v, rMag)
  ProcedureReturn v
EndProcedure

Procedure StructuredEdge_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected sensitivity.f = *param\option[0]  ; Sensibilité (1-100)
  Protected kernelSize = *param\option[1]     ; Taille noyau (0=3x3, 1=5x5)
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  Protected mode = *param\option[4]           ; 0=Standard, 1=Gradient, 2=Texture
  
  ; Normalisation de la sensibilité
  Clamp(sensitivity, 1, 100)
  sensitivity * 0.02  ; 0.02 - 2.0
  
  ; Détermination de la taille du noyau
  Protected kSize = 3
  If kernelSize = 1 : kSize = 5 : EndIf
  Protected kRadius = kSize >> 1
  
  ; Tableaux pour les pixels
  Protected maxPixels = kSize * kSize
  Protected Dim r3(maxPixels)
  Protected Dim g3(maxPixels)
  Protected Dim b3(maxPixels)
  Protected Dim gray(maxPixels)
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected r, g, b
  Protected x, y, i, j, idx
  
  ; Variables de calcul
  Protected gradient.f, texture.f, colorGrad.f
  Protected edgeStrength.f, result.f
  Protected magnitude
  
  ; Limites de traitement pour ce thread
  Protected startPos = (*param\thread_pos * (ht - kSize + 1)) / *param\thread_max + kRadius
  Protected endPos   = ((*param\thread_pos + 1) * (ht - kSize + 1)) / *param\thread_max + kRadius - 1
  
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
      
      ; Lecture du voisinage (noyau kSize x kSize)
      idx = 0
      For j = -kRadius To kRadius
        For i = -kRadius To kRadius
          *srcPixel = *source + ((y + j) * lg + (x + i)) * 4
          SED_ReadPixel(idx)
          idx + 1
        Next
      Next
      
      If toGray
        ; ====================================================================
        ; MODE NIVEAU DE GRIS
        ; ====================================================================
        
        Select mode
          Case 0  ; Mode standard - combinaison gradient + texture
            gradient = SED_ComputeGradient(gray(), kSize)
            texture = SED_ComputeTexture(gray(), kSize)
            
            ; Combinaison pondérée
            edgeStrength = (gradient * 0.7 + texture * 0.3) * sensitivity
            
          Case 1  ; Mode gradient uniquement
            edgeStrength = SED_ComputeGradient(gray(), kSize) * sensitivity
            
          Case 2  ; Mode texture uniquement
            edgeStrength = SED_ComputeTexture(gray(), kSize) * sensitivity * 2.0
        EndSelect
        
        ; Normalisation et clamping
        magnitude = edgeStrength
        Clamp(magnitude, 0, 255)
        If inverse : magnitude = 255 - magnitude : EndIf
        
        ; Écriture du pixel
        *dstPixel = *cible + (y * lg + x) * 4
        PokeL(*dstPixel, $FF000000 | (Int(magnitude) * $010101))
        
      Else
        ; ====================================================================
        ; MODE COULEUR
        ; ====================================================================
        
        Select mode
          Case 0  ; Mode standard - combinaison gradient couleur + texture
            colorGrad = SED_ComputeColorGradient(r3(), g3(), b3(), kSize)
            texture = SED_ComputeTexture(gray(), kSize)
            
            edgeStrength = (colorGrad * 0.7 + texture * 0.3) * sensitivity
            
          Case 1  ; Mode gradient couleur uniquement
            edgeStrength = SED_ComputeColorGradient(r3(), g3(), b3(), kSize) * sensitivity
            
          Case 2  ; Mode texture uniquement
            edgeStrength = SED_ComputeTexture(gray(), kSize) * sensitivity * 2.0
        EndSelect
        
        ; Application sur chaque canal avec légère variation
        r = edgeStrength * 1.0
        g = edgeStrength * 0.95
        b = edgeStrength * 0.90
        
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

Procedure StructuredEdgeDetection(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Advanced
    *param\name = "Structured Edge"
    *param\remarque = "Détection de contours structurés avec contexte spatial"
    
    ; Description des paramètres
    *param\info[0] = "Sensibilité"
    *param\info[1] = "Noyau (0=3x3/1=5x5)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "Mode (0=Std/1=Grad/2=Tex)"
    *param\info[5] = "masque"
    
    ; Paramètres: [min, max, défaut]
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 50
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 2   : *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  filter_start(@StructuredEdge_MT(), 5)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 79
; FirstLine = 58
; Folding = --
; EnableXP
; DPIAware