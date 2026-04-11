Procedure Pencil_MT(*p.parametre)
  Protected i, a, r, g, b, grey, pixel, grey1
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected intensity = *p\option[0]      ; 0-100
  Protected limit = *p\option[1]          ; 0-255
  Protected couleur = *p\option[2]        ; 0-64 (quantification couleur)
  
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected totalPixels = lg * ht
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  
  ; Précalculs pour optimisation
  Protected intensityScaled = (intensity + 200) >> 1  ; (intensity/5 + 40) optimisé
  Protected thresholdLight = 254 - ((intensity * 16) / 100)
  
  *srcPixel = *p\addr[0] + (startPos << 2)
  *dstPixel = *p\addr[1] + (startPos << 2)
  
  For i = startPos To endPos - 1
    getargb(*srcPixel\l, a, r, g, b)
    
    ; Conversion en niveau de gris (Rec.709)
    grey = (r * 1225 + g * 2405 + b * 466) >> 12
    grey1 = grey
    
    ; Quantification couleur (posterisation)
    If couleur > 0
      grey = (grey / couleur) * couleur
    EndIf
    
    ; Calcul du seuil dynamique
    Protected threshold = (limit * intensityScaled) / 100
    
    ; Application effet crayon
    If grey1 < threshold
      If grey > 0
        ; Traits de crayon (strokes) - motif directionnel
        grey - ((i % 4) << 2) * intensityScaled / 100
        grey + (((i / lg) % 8) << 1) * intensityScaled / 100
        
        ; Grain graphite (texture aléatoire)
        pixel = Random(grey)
        If pixel < (grey * intensityScaled) / 100
          grey = pixel
        EndIf
      Else
        ; Zones très sombres - grain plus prononcé
        grey = Random((intensityScaled << 5) / 100)  ; 32 * intensity
      EndIf
    Else
      ; Papier blanc (highlights)
      If grey > thresholdLight : grey = 255 : EndIf
    EndIf
    
    ; Clamp pour sécurité
    Clamp(grey, 0, 255)
    
    ; Réécriture du pixel en niveaux de gris
    *dstPixel\l = (a << 24) | (grey * $010101)
    
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

Procedure PencilImage(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Pencil Sketch"
    param\remarque = "Simulation réaliste de dessin au crayon"
    param\info[0] = "Intensité"
    param\info[1] = "Limite ombres"
    param\info[2] = "Quantification"
    param\info[3] = "Masque"
    param\info_data(0,0) = 0   : param\info_data(0,1) = 100 : param\info_data(0,2) = 50
    param\info_data(1,0) = 0   : param\info_data(1,1) = 255 : param\info_data(1,2) = 240
    param\info_data(2,0) = 0   : param\info_data(2,1) = 64  : param\info_data(2,2) = 0
    param\info_data(3,0) = 0   : param\info_data(3,1) = 2   : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Pencil_MT(), 1, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 85
; FirstLine = 16
; Folding = -
; EnableXP
; DPIAware