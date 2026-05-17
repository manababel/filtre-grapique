; ----------------------------------------------------------------------------------
; Procédure thread pour l'effet de mélange de couleurs
; ----------------------------------------------------------------------------------

Procedure color_effect_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected opt = \option[0]
    
    Clamp(opt, 0, 3)
    
    Protected i, var, a, r, g, b, r2, g2, b2, rgb
    Protected totalPixels = lg * ht
    
    ; Utilisation de la macro avec parenthèses pour l'argument composé
    macro_calul_tread((lg * ht))
    
    Protected *srcPixel.Pixel32 = *source + (thread_start << 2)
    Protected *dstPixel.Pixel32 = *cible + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      var = *srcPixel\l
      getargb(var, a, r, g, b)
      
      ; Calcul des moyennes de canaux (Respect strict de l'origine)
      r2 = (g + b) >> 1
      g2 = (r + b) >> 1
      b2 = (r + g) >> 1
      
      ; Permutations de canaux selon l'option
      Select opt
        Case 0 : rgb = (b2 << 16) | (g2 << 8) | r2  ; BGR (cyan-like)
        Case 1 : rgb = (r2 << 16) | (g2 << 8) | b2  ; RGB (magenta-like)
        Case 2 : rgb = (g2 << 16) | (b2 << 8) | r2  ; GBR (yellow-like)
        Case 3 : rgb = (b2 << 16) | (r2 << 8) | g2  ; BRG (custom)
      EndSelect
      
      *dstPixel\l = (a << 24) | rgb
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure color_effectEx(*FilterCtx.FilterParams)
  Restore color_effect_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lance le traitement multithread
    Create_MultiThread_MT(@color_effect_MT())
    
    ; Applique le masque si présent
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure color_effect(source, cible, mask, mode)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = mode
  EndWith
  color_effectEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  color_effect_Data:
  Data.s "color_effect"                                     ; Nom du filtre
  Data.s "Mélange créatif des canaux de couleur"            ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                                                  ; Sous-type
  
  Data.s "Mode (0-3)"                                       ; Label option 0
  Data.i 0, 3, 0                                            ; Min, Max, Défaut
  
  Data.s "XXX"                                              ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 69
; FirstLine = 43
; Folding = -
; EnableXP
; DPIAware