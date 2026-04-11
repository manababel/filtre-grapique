Procedure Prewitt_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected mul.f = *param\option[0]
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]
  
  ; Normalisation du multiplicateur
  If mul < 0 : mul = 0 : EndIf
  If mul > 100 : mul = 100 : EndIf
  mul = mul * 0.05
  
  ; Arrays pour stocker les valeurs RGB des 9 pixels du noyau 3x3
  Protected Dim r3(8)
  Protected Dim g3(8)
  Protected Dim b3(8)
  
  Protected a, r, g, b
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected x, y, i, dir
  Protected valR, valG, valB
  Protected rMax, gMax, bMax
  
  ; Calcul des limites de traitement pour ce thread
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max + 1
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max
  
  ; Assurer que startPos est au minimum à 1 (éviter les bords)
  If startPos < 1 : startPos = 1 : EndIf
  If endPos > ht - 2 : endPos = ht - 2 : EndIf
  
  ; Masques Prewitt pour 8 directions
  Protected Dim mask(7, 8)
  
  DataSection
    Prewitt_data:
    ; N, NE, E, SE, S, SW, W, NW
    Data.i   1,  1,  1,   0,  0,  0,  -1, -1, -1    ; N
    Data.i   0,  1,  1,  -1,  0,  1,  -1, -1,  0    ; NE
    Data.i  -1,  0,  1,  -1,  0,  1,  -1,  0,  1    ; E
    Data.i  -1, -1,  0,  -1,  0,  1,   0,  1,  1    ; SE
    Data.i  -1, -1, -1,   0,  0,  0,   1,  1,  1    ; S
    Data.i   0, -1, -1,   1,  0, -1,   1,  1,  0    ; SW
    Data.i   1,  0, -1,   1,  0, -1,   1,  0, -1    ; W
    Data.i   1,  1,  0,   1,  0, -1,   0, -1, -1    ; NW
  EndDataSection
  
  ; Chargement des masques
  Restore Prewitt_data
  For dir = 0 To 7
    For i = 0 To 8
      Read.i mask(dir, i)
    Next
  Next
  
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
      
      ; Calcul du gradient maximum parmi les 8 directions
      rMax = 0 : gMax = 0 : bMax = 0
      
      For dir = 0 To 7
        valR = 0 : valG = 0 : valB = 0
        
        ; Convolution avec le masque de direction
        For i = 0 To 8
          valR + r3(i) * mask(dir, i)
          valG + g3(i) * mask(dir, i)
          valB + b3(i) * mask(dir, i)
        Next
        
        ; Valeur absolue
        If valR < 0 : valR = -valR : EndIf
        If valG < 0 : valG = -valG : EndIf
        If valB < 0 : valB = -valB : EndIf
        
        ; Conserver le maximum
        If valR > rMax : rMax = valR : EndIf
        If valG > gMax : gMax = valG : EndIf
        If valB > bMax : bMax = valB : EndIf
      Next
      
      ; Application du multiplicateur
      r = rMax * mul
      g = gMax * mul
      b = bMax * mul
      
      ; Clamping des valeurs
      If r > 255 : r = 255 : EndIf
      If g > 255 : g = 255 : EndIf
      If b > 255 : b = 255 : EndIf
      
      ; Conversion en niveaux de gris si demandé
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

Procedure Prewitt(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Gradient
    *param\name = "Prewitt"
    *param\remarque = "Détection 8 directions"
    *param\info[0] = "Multiplicateur"
    *param\info[1] = "Mathématique"
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
  
  filter_start(@Prewitt_MT(), 4)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 170
; FirstLine = 110
; Folding = -
; EnableXP
; DPIAware