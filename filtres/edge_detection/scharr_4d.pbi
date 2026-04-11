; Macros pour le calcul des gradients Scharr
Macro Scharr_4d_sp1(v0, v1, v2, v3, v4, v5, v6)
  rx#v0 = r3(v1) * 3 + r3(v2) * 10 + r3(v3) * 3 - (r3(v4) * 3 + r3(v5) * 10 + r3(v6) * 3)
  gx#v0 = g3(v1) * 3 + g3(v2) * 10 + g3(v3) * 3 - (g3(v4) * 3 + g3(v5) * 10 + g3(v6) * 3)
  bx#v0 = b3(v1) * 3 + b3(v2) * 10 + b3(v3) * 3 - (b3(v4) * 3 + b3(v5) * 10 + b3(v6) * 3)
  ry#v0 = r3(v4) * 3 + r3(v5) * 10 + r3(v6) * 3 - (r3(v1) * 3 + r3(v2) * 10 + r3(v3) * 3)
  gy#v0 = g3(v4) * 3 + g3(v5) * 10 + g3(v6) * 3 - (g3(v1) * 3 + g3(v2) * 10 + g3(v3) * 3)
  by#v0 = b3(v4) * 3 + b3(v5) * 10 + b3(v6) * 3 - (b3(v1) * 3 + b3(v2) * 10 + b3(v3) * 3)
EndMacro

Macro Scharr_4d_sp2(v0)
  If rx#v0 < 0 : rx#v0 = -rx#v0 : EndIf
  If gx#v0 < 0 : gx#v0 = -gx#v0 : EndIf
  If bx#v0 < 0 : bx#v0 = -bx#v0 : EndIf
  If ry#v0 < 0 : ry#v0 = -ry#v0 : EndIf
  If gy#v0 < 0 : gy#v0 = -gy#v0 : EndIf
  If by#v0 < 0 : by#v0 = -by#v0 : EndIf
  r#v0 = rx#v0 + ry#v0
  g#v0 = gx#v0 + gy#v0
  b#v0 = bx#v0 + by#v0
EndMacro

Macro Scharr_4d_sp3(v0)
  r#v0 = Sqr(rx#v0 * rx#v0 + ry#v0 * ry#v0)
  g#v0 = Sqr(gx#v0 * gx#v0 + gy#v0 * gy#v0)
  b#v0 = Sqr(bx#v0 * bx#v0 + by#v0 * by#v0)
EndMacro

Procedure Scharr_4d_MT(*param.parametre)
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
  mul = mul * 0.1
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  
  ; Variables pour les 4 directions (0°, 45°, 90°, 135°)
  Protected rx0, ry0, gx0, gy0, bx0, by0, r0, g0, b0
  Protected rx45, ry45, gx45, gy45, bx45, by45, r45, g45, b45
  Protected rx90, ry90, gx90, gy90, bx90, by90, r90, g90, b90
  Protected rx135, ry135, gx135, gy135, bx135, by135, r135, g135, b135
  
  Protected x, y
  Protected a, r, g, b
  
  ; Arrays pour stocker les valeurs RGB des 9 pixels du noyau 3x3
  Protected Dim r3(8)
  Protected Dim g3(8)
  Protected Dim b3(8)
  
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
      ; Disposition des pixels:
      ; 0 1 2
      ; 3 4 5
      ; 6 7 8
      
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
      
      ; Calcul des gradients dans les 4 directions
      ; Direction 0° (horizontal: gauche vs droite)
      ; Gx: colonne droite (2,5,8) - colonne gauche (0,3,6)
      Scharr_4d_sp1(0, 2, 5, 8, 0, 3, 6)
      
      ; Direction 45° (diagonal \ : haut-droite vs bas-gauche)
      ; Gx: diagonale haut-droite (0,1,2) - diagonale bas-gauche (6,7,8)
      Scharr_4d_sp1(45, 0, 1, 2, 6, 7, 8)
      
      ; Direction 90° (vertical: haut vs bas)
      ; Gx: ligne bas (6,7,8) - ligne haut (0,1,2)
      Scharr_4d_sp1(90, 6, 7, 8, 0, 1, 2)
      
      ; Direction 135° (diagonal / : bas-droite vs haut-gauche)
      ; Gx: diagonale bas-droite (8,5,2) - diagonale haut-gauche (0,3,6)
      Scharr_4d_sp1(135, 8, 5, 2, 0, 3, 6)
      
      ; Calcul des magnitudes
      If mat
        ; Méthode Manhattan: |Gx| + |Gy|
        Scharr_4d_sp2(0)
        Scharr_4d_sp2(45)
        Scharr_4d_sp2(90)
        Scharr_4d_sp2(135)
      Else
        ; Méthode euclidienne: sqrt(Gx² + Gy²)
        Scharr_4d_sp3(0)
        Scharr_4d_sp3(45)
        Scharr_4d_sp3(90)
        Scharr_4d_sp3(135)
      EndIf
      
      ; Prendre le maximum des 4 directions pour chaque canal
      r = r0
      If r45 > r : r = r45 : EndIf
      If r90 > r : r = r90 : EndIf
      If r135 > r : r = r135 : EndIf
      
      g = g0
      If g45 > g : g = g45 : EndIf
      If g90 > g : g = g90 : EndIf
      If g135 > g : g = g135 : EndIf
      
      b = b0
      If b45 > b : b = b45 : EndIf
      If b90 > b : b = b90 : EndIf
      If b135 > b : b = b135 : EndIf
      
      ; Application du multiplicateur
      r = r * mul
      g = g * mul
      b = b * mul
      
      ; Clamping des valeurs RGB
      If r > 255 : r = 255 : ElseIf r < 0 : r = 0 : EndIf
      If g > 255 : g = 255 : ElseIf g < 0 : g = 0 : EndIf
      If b > 255 : b = 255 : ElseIf b < 0 : b = 0 : EndIf
      
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

Procedure Scharr_4d(*param.parametre)
  ; Affichage des informations de configuration si demandé
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Gradient
    *param\name = "Scharr 4 directions"
    *param\remarque = "Détection de contours dans 4 directions (0°, 45°, 90°, 135°)"
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
  
  filter_start(@Scharr_4d_MT(), 4)
EndProcedure



; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 212
; FirstLine = 154
; Folding = -
; EnableXP
; DPIAware