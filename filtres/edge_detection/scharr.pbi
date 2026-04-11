Procedure Scharr_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected mul.f = *param\option[0]
  Protected mat = *param\option[1]
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  
  ; Normalisation du multiplicateur
  If mul < 0 : mul = 0 : EndIf
  If mul > 100 : mul = 100 : EndIf
  mul = mul * 0.05
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  
  ; Arrays pour stocker les valeurs RGB des 9 pixels du noyau 3x3
  Protected Dim r3(8)
  Protected Dim g3(8)
  Protected Dim b3(8)
  
  Protected a, r, g, b
  Protected x, y
  Protected rx, gx, bx, ry, gy, by
  
  ; Calcul des limites de traitement pour ce thread
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max + 1
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max
  
  ; Assurer que startPos est au minimum à 1 (éviter les bords)
  If startPos < 1 : startPos = 1 : EndIf
  If endPos > ht - 2 : endPos = ht - 2 : EndIf
  
  ; Traitement des pixels
  For y = startPos To endPos
    For x = 1 To lg - 2
      
      ; Lecture des 9 pixels du noyau 3x3
      ; Ligne supérieure (y-1)
      *srcPixel = *source + ((y - 1) * lg + (x - 1)) * 4
      getrgb(PeekL(*srcPixel), r3(0), g3(0), b3(0))
      *srcPixel + 4
      getrgb(PeekL(*srcPixel), r3(1), g3(1), b3(1))
      *srcPixel + 4
      getrgb(PeekL(*srcPixel), r3(2), g3(2), b3(2))
      
      ; Ligne centrale (y)
      *srcPixel = *source + (y * lg + (x - 1)) * 4
      getrgb(PeekL(*srcPixel), r3(3), g3(3), b3(3))
      *srcPixel + 4
      getargb(PeekL(*srcPixel), a, r3(4), g3(4), b3(4))
      *srcPixel + 4
      getrgb(PeekL(*srcPixel), r3(5), g3(5), b3(5))
      
      ; Ligne inférieure (y+1)
      *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
      getrgb(PeekL(*srcPixel), r3(6), g3(6), b3(6))
      *srcPixel + 4
      getrgb(PeekL(*srcPixel), r3(7), g3(7), b3(7))
      *srcPixel + 4
      getrgb(PeekL(*srcPixel), r3(8), g3(8), b3(8))
      
      ; Masque Scharr Gx (gradient horizontal)
      ; Gx = [-3   0   3]
      ;      [-10  0  10]
      ;      [-3   0   3]
      rx = (r3(2) * 3 + r3(5) * 10 + r3(8) * 3) - (r3(0) * 3 + r3(3) * 10 + r3(6) * 3)
      gx = (g3(2) * 3 + g3(5) * 10 + g3(8) * 3) - (g3(0) * 3 + g3(3) * 10 + g3(6) * 3)
      bx = (b3(2) * 3 + b3(5) * 10 + b3(8) * 3) - (b3(0) * 3 + b3(3) * 10 + b3(6) * 3)
      
      ; Masque Scharr Gy (gradient vertical)
      ; Gy = [-3  -10  -3]
      ;      [ 0    0   0]
      ;      [ 3   10   3]
      ry = (r3(6) * 3 + r3(7) * 10 + r3(8) * 3) - (r3(0) * 3 + r3(1) * 10 + r3(2) * 3)
      gy = (g3(6) * 3 + g3(7) * 10 + g3(8) * 3) - (g3(0) * 3 + g3(1) * 10 + g3(2) * 3)
      by = (b3(6) * 3 + b3(7) * 10 + b3(8) * 3) - (b3(0) * 3 + b3(1) * 10 + b3(2) * 3)
      
      ; Calcul de la magnitude du gradient
      If mat = 0
        ; Méthode euclidienne: sqrt(Gx² + Gy²)
        r = Sqr(rx * rx + ry * ry) * mul
        g = Sqr(gx * gx + gy * gy) * mul
        b = Sqr(bx * bx + by * by) * mul
      Else
        ; Méthode Manhattan: |Gx| + |Gy|
        If rx < 0 : rx = -rx : EndIf
        If gx < 0 : gx = -gx : EndIf
        If bx < 0 : bx = -bx : EndIf
        If ry < 0 : ry = -ry : EndIf
        If gy < 0 : gy = -gy : EndIf
        If by < 0 : by = -by : EndIf
        
        r = (rx + ry) * mul
        g = (gx + gy) * mul
        b = (bx + by) * mul
      EndIf
      
      ; Clamping des valeurs RGB
      If r > 255 : r = 255 : ElseIf r < 0 : r = 0 : EndIf
      If g > 255 : g = 255 : ElseIf g < 0 : g = 0 : EndIf
      If b > 255 : b = 255 : ElseIf b < 0 : b = 0 : EndIf
      
      ; Conversion en niveaux de gris si demandé (formule standard)
      If toGray
        r = (r * 77 + g * 150 + b * 29) >> 8
        g = r : b = r
      EndIf
      
      ; Inversion si demandée
      If inverse
        r = 255 - r
        g = 255 - g
        b = 255 - b
      EndIf
      
      ; Écriture du pixel résultat
      *dstPixel = *cible + (y * lg + x) * 4
      PokeL(*dstPixel, (a << 24) | (r << 16) | (g << 8) | b)
      
    Next
  Next
  
  ; Libération des tableaux
  FreeArray(r3())
  FreeArray(g3())
  FreeArray(b3())
EndProcedure

Procedure Scharr(*param.parametre)
  ; Affichage des informations de configuration si demandé
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Gradient
    *param\name = "Scharr"
    *param\remarque = "Détection de contours optimisée"
    *param\info[0] = "Multiplicateur"
    *param\info[1] = "Méthode (ABS/SQR)"
    *param\info[2] = "Noir et blanc"
    *param\info[3] = "Inversion"
    *param\info[4] = "Masque binaire"
    
    ; Paramètres: min, max, défaut
    *param\info_data(0, 0) = 0   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 1   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    
    ProcedureReturn
  EndIf
  
  filter_start(@Scharr_MT(), 4)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 156
; FirstLine = 96
; Folding = -
; EnableXP
; DPIAware