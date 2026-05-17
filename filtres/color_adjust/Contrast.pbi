; ----------------------------------------------------------------------------------
; Procédure thread pour l'ajustement du Contraste
; ----------------------------------------------------------------------------------

Procedure Contrast_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, contrast.i, pixel.l
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    
    ; Calcul du facteur de contraste (pré-calculé hors de la boucle)
    ; Mappe l'option (0..512) vers un facteur utilisable (base 256)
    ; 255 est le point neutre (pas de changement)
    contrast = ((\option[0] - 255) * 512) / 255 + 256
    
    ; Utilisation de la macro standard pour le découpage multithread
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      
      ; Extraction rapide des composantes
      a = (pixel >> 24) & $FF
      r = (pixel >> 16) & $FF
      g = (pixel >> 8) & $FF
      b = pixel & $FF
      
      ; Application du contraste autour de la valeur médiane (128)
      ; Formule : ((Valeur - 128) * Contraste) / 256 + 128
      r = (((r - 128) * contrast) >> 8) + 128
      g = (((g - 128) * contrast) >> 8) + 128
      b = (((b - 128) * contrast) >> 8) + 128
      
      ; Limitation (Clamp)
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

Procedure ContrastEx(*FilterCtx.FilterParams)
  Restore Contrast_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lance le traitement multithread
    Create_MultiThread_MT(@Contrast_MT())
    
    ; Gestion automatique du masque
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Contrast(source, cible, mask, contrast_factor)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = contrast_factor
  EndWith
  ContrastEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Contrast_Data:
  Data.s "Contrast"           ; Nom
  Data.s "Ajuste le contraste de l'image autour de la valeur moyenne" ; Description
  Data.i #FilterType_ColorAdjustment
  Data.i 0                    ; Sous-type
  
  Data.s "Intensité"          ; Label option 0
  Data.i 0, 512, 255          ; Min, Max, Défaut (255 = Neutre)
  
  Data.s "XXX"                ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 71
; FirstLine = 45
; Folding = -
; EnableXP
; DPIAware