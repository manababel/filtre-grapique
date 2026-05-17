; ----------------------------------------------------------------------------------
; Procédure thread pour l'effet Dichromatic (Binarisation)
; ----------------------------------------------------------------------------------

Procedure Dichromatic_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    
    ; Respect strict du typage float pour le calcul du seuil
    Protected threshold = (\option[0] / 100.0) * 255
    
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected totalPixels = lg * ht
    
    ; Utilisation de la macro avec parenthèses pour l'argument composé
    macro_calul_tread((lg * ht))
    
    *srcPixel = \addr[0] + (thread_start << 2)
    *dstPixel = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      getargb(*srcPixel\l , a, r , g , b)
      
      ; Calcul de la luminance (Respect strict de l'origine)
      Protected grey = ((r * 1225 + g * 2405 + b * 466) >> 12)
      
      ; Reconstruction du pixel (Conservation de l'opération logique d'origine)
      *dstPixel\l = Bool(grey >= threshold) * $FFFFFF | (a << 24)
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure DichromaticEx(*FilterCtx.FilterParams)
  Restore Dichromatic_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lance le traitement multithread
    Create_MultiThread_MT(@Dichromatic_MT())
    
    ; Applique le masque si présent
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Dichromatic(source, cible, mask, intensite)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensite
  EndWith
  DichromaticEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Dichromatic_Data:
  Data.s "Dichromatic"                      ; Nom du filtre
  Data.s "Binarisation de l'image"          ; Description (Remarque vide à l'origine)
  Data.i #FilterType_ColorEffect
  Data.i 0                                  ; Sous-type
  
  Data.s "Intensité (25-75)"                ; Label option 0
  Data.i 25, 75, 50                         ; Min, Max, Défaut
  
  Data.s "XXX"                              ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 60
; FirstLine = 34
; Folding = -
; EnableXP
; DPIAware