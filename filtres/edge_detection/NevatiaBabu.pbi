; ============================================================================
; Filtre Nevatia-Babu - Détection de contours 5x5 optimisé
; ============================================================================

Macro NevatiaBabu_ReadGray(var)
  getrgb(PeekL(*srcPixel), r, g, b)
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Macro NevatiaBabu_ReadRGB(var)
  getrgb(PeekL(*srcPixel), r3(var), g3(var), b3(var))
  *srcPixel + 4
EndMacro

Procedure NevatiaBabu_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected mul.f = *param\option[0]
  Protected toGray = *param\option[1]
  Protected inverse = *param\option[2]
  
  ; Normalisation du multiplicateur (1-100 -> 0.0025-0.25)
  Clamp(mul, 1, 100)
  mul * 0.000025
  
  ; Tableaux pour stocker les valeurs RGB/Gray des 25 pixels du noyau 5x5
  Protected Dim r3(24)
  Protected Dim g3(24)
  Protected Dim b3(24)
  Protected Dim gray(24)
  
  Protected *srcPixel.Long
  Protected *dstPixel.Long
  Protected a, r, g, b
  Protected x, y, i, j, m
  Protected.q rx, gx, bx, ry, gy, by
  Protected.q val, maxval
  
  ; Calcul des limites de traitement pour ce thread
  ; Noyau 5x5 nécessite une marge de 2 pixels
  Protected startPos = (*param\thread_pos * (ht - 4)) / *param\thread_max + 2
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 4)) / *param\thread_max + 1
  
  ; Validation des limites (éviter les bords)
  Clamp(startPos, 2, ht - 3)
  Clamp(endPos, 2, ht - 3)
  
  ; Vérification que la zone de traitement est valide
  If startPos > endPos
    ProcedureReturn
  EndIf
  
  ; Masques Nevatia-Babu (6 masques de 5x5 = 25 valeurs)
  Protected Dim NBmask.l(5, 24)
  
  ; ========================================================================
  ; Traitement des pixels
  ; ========================================================================
  For y = startPos To endPos
    For x = 2 To lg - 3
      
      If toGray
        ; ====================================================================
        ; MODE NIVEAU DE GRIS
        ; ====================================================================
        
        ; Lecture des 25 pixels du noyau 5x5 en niveaux de gris
        i = 0
        For j = -2 To 2
          *srcPixel = *source + ((y + j) * lg + (x - 2)) * 4
          NevatiaBabu_ReadGray(i) : NevatiaBabu_ReadGray(i + 1) : NevatiaBabu_ReadGray(i + 2)
          NevatiaBabu_ReadGray(i + 3) : NevatiaBabu_ReadGray(i + 4)
          i + 5
        Next
        
        ; M0 - Horizontal (0°)
        NBmask(0, 0)=100  : NBmask(0, 1)=100  : NBmask(0, 2)=100  : NBmask(0, 3)=100  : NBmask(0, 4)=100
        NBmask(0, 5)=100  : NBmask(0, 6)=100  : NBmask(0, 7)=100  : NBmask(0, 8)=100  : NBmask(0, 9)=100
        NBmask(0, 10)=0   : NBmask(0, 11)=0   : NBmask(0, 12)=0   : NBmask(0, 13)=0   : NBmask(0, 14)=0
        NBmask(0, 15)=-100: NBmask(0, 16)=-100: NBmask(0, 17)=-100: NBmask(0, 18)=-100: NBmask(0, 19)=-100
        NBmask(0, 20)=-100: NBmask(0, 21)=-100: NBmask(0, 22)=-100: NBmask(0, 23)=-100: NBmask(0, 24)=-100
        
        ; M1 - Diagonal 30°
        NBmask(1, 0)=100  : NBmask(1, 1)=100  : NBmask(1, 2)=100  : NBmask(1, 3)=100  : NBmask(1, 4)=0
        NBmask(1, 5)=100  : NBmask(1, 6)=100  : NBmask(1, 7)=100  : NBmask(1, 8)=0    : NBmask(1, 9)=-100
        NBmask(1, 10)=100 : NBmask(1, 11)=100 : NBmask(1, 12)=0   : NBmask(1, 13)=-100: NBmask(1, 14)=-100
        NBmask(1, 15)=100 : NBmask(1, 16)=0   : NBmask(1, 17)=-100: NBmask(1, 18)=-100: NBmask(1, 19)=-100
        NBmask(1, 20)=0   : NBmask(1, 21)=-100: NBmask(1, 22)=-100: NBmask(1, 23)=-100: NBmask(1, 24)=-100
        
        ; M2 - Diagonal 60°
        NBmask(2, 0)=100  : NBmask(2, 1)=100  : NBmask(2, 2)=100  : NBmask(2, 3)=0    : NBmask(2, 4)=-100
        NBmask(2, 5)=100  : NBmask(2, 6)=100  : NBmask(2, 7)=0    : NBmask(2, 8)=-100 : NBmask(2, 9)=-100
        NBmask(2, 10)=100 : NBmask(2, 11)=0   : NBmask(2, 12)=-100: NBmask(2, 13)=-100: NBmask(2, 14)=-100
        NBmask(2, 15)=0   : NBmask(2, 16)=-100: NBmask(2, 17)=-100: NBmask(2, 18)=-100: NBmask(2, 19)=-100
        NBmask(2, 20)=-100: NBmask(2, 21)=-100: NBmask(2, 22)=-100: NBmask(2, 23)=-100: NBmask(2, 24)=-100
        
        ; M3 - Vertical (90°)
        NBmask(3, 0)=0    : NBmask(3, 1)=100  : NBmask(3, 2)=100  : NBmask(3, 3)=100  : NBmask(3, 4)=0
        NBmask(3, 5)=0    : NBmask(3, 6)=100  : NBmask(3, 7)=100  : NBmask(3, 8)=100  : NBmask(3, 9)=0
        NBmask(3, 10)=0   : NBmask(3, 11)=0   : NBmask(3, 12)=0   : NBmask(3, 13)=0   : NBmask(3, 14)=0
        NBmask(3, 15)=0   : NBmask(3, 16)=-100: NBmask(3, 17)=-100: NBmask(3, 18)=-100: NBmask(3, 19)=0
        NBmask(3, 20)=0   : NBmask(3, 21)=-100: NBmask(3, 22)=-100: NBmask(3, 23)=-100: NBmask(3, 24)=0
        
        ; M4 - Diagonal 120°
        NBmask(4, 0)=-100 : NBmask(4, 1)=0    : NBmask(4, 2)=100  : NBmask(4, 3)=100  : NBmask(4, 4)=100
        NBmask(4, 5)=-100 : NBmask(4, 6)=-100 : NBmask(4, 7)=0    : NBmask(4, 8)=100  : NBmask(4, 9)=100
        NBmask(4, 10)=-100: NBmask(4, 11)=-100: NBmask(4, 12)=-100: NBmask(4, 13)=0   : NBmask(4, 14)=100
        NBmask(4, 15)=-100: NBmask(4, 16)=-100: NBmask(4, 17)=-100: NBmask(4, 18)=-100: NBmask(4, 19)=0
        NBmask(4, 20)=-100: NBmask(4, 21)=-100: NBmask(4, 22)=-100: NBmask(4, 23)=-100: NBmask(4, 24)=-100
        
        ; M5 - Diagonal 150°
        NBmask(5, 0)=0    : NBmask(5, 1)=-100 : NBmask(5, 2)=-100 : NBmask(5, 3)=-100 : NBmask(5, 4)=-100
        NBmask(5, 5)=100  : NBmask(5, 6)=0    : NBmask(5, 7)=-100 : NBmask(5, 8)=-100 : NBmask(5, 9)=-100
        NBmask(5, 10)=100 : NBmask(5, 11)=100 : NBmask(5, 12)=0   : NBmask(5, 13)=-100: NBmask(5, 14)=-100
        NBmask(5, 15)=100 : NBmask(5, 16)=100 : NBmask(5, 17)=100 : NBmask(5, 18)=0   : NBmask(5, 19)=-100
        NBmask(5, 20)=100 : NBmask(5, 21)=100 : NBmask(5, 22)=100 : NBmask(5, 23)=100 : NBmask(5, 24)=0
        
        ; Convolution avec les 6 masques - recherche du maximum
        maxval = 0
        For m = 0 To 5
          val = 0
          For i = 0 To 24
            val + gray(i) * NBmask(m, i)
          Next
          val = Abs(val)
          If val > maxval : maxval = val : EndIf
        Next
        
        r = maxval * mul
        
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
        
        ; Lecture des 25 pixels du noyau 5x5 en couleur
        i = 0
        For j = -2 To 2
          *srcPixel = *source + ((y + j) * lg + (x - 2)) * 4
          NevatiaBabu_ReadRGB(i) : NevatiaBabu_ReadRGB(i + 1) : NevatiaBabu_ReadRGB(i + 2)
          NevatiaBabu_ReadRGB(i + 3) : NevatiaBabu_ReadRGB(i + 4)
          i + 5
        Next
        
        ; Initialisation des masques (identique au mode gris)
        NBmask(0, 0)=100  : NBmask(0, 1)=100  : NBmask(0, 2)=100  : NBmask(0, 3)=100  : NBmask(0, 4)=100
        NBmask(0, 5)=100  : NBmask(0, 6)=100  : NBmask(0, 7)=100  : NBmask(0, 8)=100  : NBmask(0, 9)=100
        NBmask(0, 10)=0   : NBmask(0, 11)=0   : NBmask(0, 12)=0   : NBmask(0, 13)=0   : NBmask(0, 14)=0
        NBmask(0, 15)=-100: NBmask(0, 16)=-100: NBmask(0, 17)=-100: NBmask(0, 18)=-100: NBmask(0, 19)=-100
        NBmask(0, 20)=-100: NBmask(0, 21)=-100: NBmask(0, 22)=-100: NBmask(0, 23)=-100: NBmask(0, 24)=-100
        
        NBmask(1, 0)=100  : NBmask(1, 1)=100  : NBmask(1, 2)=100  : NBmask(1, 3)=100  : NBmask(1, 4)=0
        NBmask(1, 5)=100  : NBmask(1, 6)=100  : NBmask(1, 7)=100  : NBmask(1, 8)=0    : NBmask(1, 9)=-100
        NBmask(1, 10)=100 : NBmask(1, 11)=100 : NBmask(1, 12)=0   : NBmask(1, 13)=-100: NBmask(1, 14)=-100
        NBmask(1, 15)=100 : NBmask(1, 16)=0   : NBmask(1, 17)=-100: NBmask(1, 18)=-100: NBmask(1, 19)=-100
        NBmask(1, 20)=0   : NBmask(1, 21)=-100: NBmask(1, 22)=-100: NBmask(1, 23)=-100: NBmask(1, 24)=-100
        
        NBmask(2, 0)=100  : NBmask(2, 1)=100  : NBmask(2, 2)=100  : NBmask(2, 3)=0    : NBmask(2, 4)=-100
        NBmask(2, 5)=100  : NBmask(2, 6)=100  : NBmask(2, 7)=0    : NBmask(2, 8)=-100 : NBmask(2, 9)=-100
        NBmask(2, 10)=100 : NBmask(2, 11)=0   : NBmask(2, 12)=-100: NBmask(2, 13)=-100: NBmask(2, 14)=-100
        NBmask(2, 15)=0   : NBmask(2, 16)=-100: NBmask(2, 17)=-100: NBmask(2, 18)=-100: NBmask(2, 19)=-100
        NBmask(2, 20)=-100: NBmask(2, 21)=-100: NBmask(2, 22)=-100: NBmask(2, 23)=-100: NBmask(2, 24)=-100
        
        NBmask(3, 0)=0    : NBmask(3, 1)=100  : NBmask(3, 2)=100  : NBmask(3, 3)=100  : NBmask(3, 4)=0
        NBmask(3, 5)=0    : NBmask(3, 6)=100  : NBmask(3, 7)=100  : NBmask(3, 8)=100  : NBmask(3, 9)=0
        NBmask(3, 10)=0   : NBmask(3, 11)=0   : NBmask(3, 12)=0   : NBmask(3, 13)=0   : NBmask(3, 14)=0
        NBmask(3, 15)=0   : NBmask(3, 16)=-100: NBmask(3, 17)=-100: NBmask(3, 18)=-100: NBmask(3, 19)=0
        NBmask(3, 20)=0   : NBmask(3, 21)=-100: NBmask(3, 22)=-100: NBmask(3, 23)=-100: NBmask(3, 24)=0
        
        NBmask(4, 0)=-100 : NBmask(4, 1)=0    : NBmask(4, 2)=100  : NBmask(4, 3)=100  : NBmask(4, 4)=100
        NBmask(4, 5)=-100 : NBmask(4, 6)=-100 : NBmask(4, 7)=0    : NBmask(4, 8)=100  : NBmask(4, 9)=100
        NBmask(4, 10)=-100: NBmask(4, 11)=-100: NBmask(4, 12)=-100: NBmask(4, 13)=0   : NBmask(4, 14)=100
        NBmask(4, 15)=-100: NBmask(4, 16)=-100: NBmask(4, 17)=-100: NBmask(4, 18)=-100: NBmask(4, 19)=0
        NBmask(4, 20)=-100: NBmask(4, 21)=-100: NBmask(4, 22)=-100: NBmask(4, 23)=-100: NBmask(4, 24)=-100
        
        NBmask(5, 0)=0    : NBmask(5, 1)=-100 : NBmask(5, 2)=-100 : NBmask(5, 3)=-100 : NBmask(5, 4)=-100
        NBmask(5, 5)=100  : NBmask(5, 6)=0    : NBmask(5, 7)=-100 : NBmask(5, 8)=-100 : NBmask(5, 9)=-100
        NBmask(5, 10)=100 : NBmask(5, 11)=100 : NBmask(5, 12)=0   : NBmask(5, 13)=-100: NBmask(5, 14)=-100
        NBmask(5, 15)=100 : NBmask(5, 16)=100 : NBmask(5, 17)=100 : NBmask(5, 18)=0   : NBmask(5, 19)=-100
        NBmask(5, 20)=100 : NBmask(5, 21)=100 : NBmask(5, 22)=100 : NBmask(5, 23)=100 : NBmask(5, 24)=0
        
        ; Convolution sur les 3 canaux RGB
        rx = 0 : gx = 0 : bx = 0
        For m = 0 To 5
          Protected.q valR = 0, valG = 0, valB = 0
          For i = 0 To 24
            valR + r3(i) * NBmask(m, i)
            valG + g3(i) * NBmask(m, i)
            valB + b3(i) * NBmask(m, i)
          Next
          valR = Abs(valR) : valG = Abs(valG) : valB = Abs(valB)
          If valR > rx : rx = valR : EndIf
          If valG > gx : gx = valG : EndIf
          If valB > bx : bx = valB : EndIf
        Next
       
          r = rx * mul
          g = gx * mul
          b = bx * mul
        
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
  FreeArray(NBmask())
EndProcedure

Procedure NevatiaBabu(*param.parametre)
  ; Configuration du filtre (métadonnées)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Gradient
    *param\name = "Nevatia-Babu"
    *param\remarque = "Détection de contours 5x5 (Nevatia-Babu operator)"
    
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
  filter_start(@NevatiaBabu_MT(), 3)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 27
; Folding = -
; EnableXP
; DPIAware