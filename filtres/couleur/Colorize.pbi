; ----------------------------------------------------------------------------------
; Procédure thread pour la Colorisation (Balance Saturation/Gris)
; ----------------------------------------------------------------------------------

Procedure Colorize_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, gray, pixel.l
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    
    ; On récupère l'intensité (0-512). 128 est le pivot.
    Protected intensity.i = \option[0]
    Protected invIntensity.i = 128 - intensity
    
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      
      ; Extraction ARGB
      a = (pixel >> 24) & $FF
      r = (pixel >> 16) & $FF
      g = (pixel >> 8)  & $FF
      b = pixel & $FF
      
      ; Calcul de la luminance (Gris Rec.709)
      gray = (r * 54 + g * 183 + b * 18) >> 8
      
      ; Mélange linéaire optimisé : (Couleur * Sat + Gris * (1 - Sat))
      ; Le décalage >> 7 correspond à la division par 128
      r = (r * intensity + gray * invIntensity) >> 7
      g = (g * intensity + gray * invIntensity) >> 7
      b = (b * intensity + gray * invIntensity) >> 7
      
      ; Clamp indispensable (surtout si intensity > 128)
      If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
      
      ; Reconstruction du pixel
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure ColorizeEx(*FilterCtx.FilterParams)
  Restore Colorize_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Colorize_MT())
    
    ; Application du masque et mélange final
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Colorize(source, cible, mask, intensity)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensity
  EndWith
  ColorizeEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Colorize_Data:
  Data.s "Colorize"           ; Nom
  Data.s "Ajuste la saturation : 0=Gris, 128=Original, 512=Saturé" ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                    ; Sous-type
  
  Data.s "Intensité"          ; Label option 0
  Data.i 0, 512, 128          ; Min, Max, Défaut
  
  Data.s "XXX"                ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 71
; FirstLine = 45
; Folding = -
; EnableXP
; DPIAware