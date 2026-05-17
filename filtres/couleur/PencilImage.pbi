; ----------------------------------------------------------------------------------
; Procédure thread pour l'effet Pencil Sketch (Dessin au crayon)
; ----------------------------------------------------------------------------------

Procedure Pencil_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, grey, pixel, grey1
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected intensity = \option[0]      ; 0-100
    Protected limit = \option[1]          ; 0-255
    Protected couleur = \option[2]        ; 0-64 (quantification couleur)
    
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected totalPixels = lg * ht
    
    ; Utilisation de la macro avec parenthèses pour l'argument composé
    macro_calul_tread((lg * ht))
    
    ; Précalculs pour optimisation (Respect strict de la logique d'origine)
    Protected intensityScaled = (intensity + 200) >> 1
    Protected thresholdLight = 254 - ((intensity * 16) / 100)
    
    *srcPixel = \addr[0] + (thread_start << 2)
    *dstPixel = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
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
          grey = Random((intensityScaled << 5) / 100)
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
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure PencilImageEx(*FilterCtx.FilterParams)
  Restore PencilImage_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lance le traitement multithread
    Create_MultiThread_MT(@Pencil_MT())
    
    ; Applique le masque si présent
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure PencilImage(source, cible, mask, intensite, limite, quantification)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensite
    \option[1] = limite
    \option[2] = quantification
  EndWith
  PencilImageEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  PencilImage_Data:
  Data.s "Pencil Sketch"                         ; Nom du filtre
  Data.s "Simulation réaliste de dessin au crayon" ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                                       ; Sous-type
  
  Data.s "Intensité (0-100)"                     ; Label option 0
  Data.i 0, 100, 50                              ; Min, Max, Défaut
  
  Data.s "Limite ombres (0-255)"                 ; Label option 1
  Data.i 0, 255, 240                             ; Min, Max, Défaut
  
  Data.s "Quantification (0-64)"                 ; Label option 2
  Data.i 0, 64, 0                                ; Min, Max, Défaut
  
  Data.s "XXX"                                   ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 97
; FirstLine = 79
; Folding = -
; EnableXP
; DPIAware