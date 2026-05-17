; ----------------------------------------------------------------------------------
; Procédure thread pour l'ajustement de la Saturation
; ----------------------------------------------------------------------------------

Procedure Saturation_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, gray, pixel.l
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    
    ; Récupération du facteur (0..512). 255 est le point neutre.
    ; On utilise une base 256 pour des calculs rapides via décalage (>> 8)
    Protected intensity.i = \option[0]
    Protected invIntensity.i = 256 - intensity
    
    ; Utilisation de la macro standard pour le découpage multithread
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      
      ; Extraction ARGB rapide
      a = (pixel >> 24) & $FF
      r = (pixel >> 16) & $FF
      g = (pixel >> 8) & $FF
      b = pixel & $FF
      
      ; Calcul de la luminance (Gris pondéré)
      gray = (r * 77 + g * 151 + b * 28) >> 8
      
      ; Interpolation linéaire : Couleur + (Gris - Couleur) * Facteur_Saturation
      ; Ici optimisé en (Couleur * Intensité + Gris * InvIntensité) / 256
      r = (r * intensity + gray * invIntensity) >> 8
      g = (g * intensity + gray * invIntensity) >> 8
      b = (b * intensity + gray * invIntensity) >> 8
      
      ; Limitation (Clamp)
      If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
      
      ; Reconstruction du pixel final
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure SaturationEx(*FilterCtx.FilterParams)
  Restore Saturation_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lance le traitement multithread
    Create_MultiThread_MT(@Saturation_MT())
    
    ; Gestion automatique du masque et de la fusion
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Saturation(source, cible, mask, saturation_val)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = saturation_val
  EndWith
  SaturationEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Saturation_Data:
  Data.s "Saturation"         ; Nom
  Data.s "Ajuste l'intensité des couleurs (0=Gris, 255=Normal, 512=Vif)" ; Description
  Data.i #FilterType_ColorAdjustment
  Data.i 0                    ; Sous-type
  
  Data.s "Intensité"          ; Label option 0
  Data.i 0, 512, 255          ; Min, Max, Défaut
  
  Data.s "XXX"                ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 74
; FirstLine = 48
; Folding = -
; EnableXP
; DPIAware