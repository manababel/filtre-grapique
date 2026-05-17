; ----------------------------------------------------------------------------------
; Procédure thread pour la désaturation sélective par teinte
; ----------------------------------------------------------------------------------

Procedure Color_hue_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected maxVal, minVal, delta, hue, deltaHue
    
    Protected hueTarget = \option[0]  ; 0-255
    Protected tolerance = \option[1]  ; 0-255
    
    Protected i, a, r, g, b, var
    Protected totalPixels = lg * ht
    
    ; Calcul des segments de thread
    Protected startPos = (\thread_pos * totalPixels) / \thread_max
    Protected endPos   = ((\thread_pos + 1) * totalPixels) / \thread_max
    
    Protected *srcPixel.Pixel32 = *source + (startPos << 2)
    Protected *dstPixel.Pixel32 = *cible + (startPos << 2)
    
    For i = startPos To endPos - 1
      var = *srcPixel\l
      getargb(var, a, r, g, b)
      
      ; Calcul HSV/HSL - détermination de la teinte
      max3(maxVal, r, g, b)
      min3(minVal, r, g, b)
      delta = maxVal - minVal
      
      If delta <> 0  ; Pixel coloré (pas gris neutre)
        ; Calcul de la teinte (0-255)
        Select maxVal
          Case r : hue = 0   + 43 * (g - b) / delta
          Case g : hue = 85  + 43 * (b - r) / delta
          Case b : hue = 171 + 43 * (r - g) / delta
        EndSelect
        
        ; Normalisation dans [0, 255]
        While hue < 0    : hue + 256 : Wend
        While hue >= 256 : hue - 256 : Wend
        
        ; Distance circulaire entre hue et hueTarget
        deltaHue = Abs(hue - hueTarget)
        If deltaHue > 128
          deltaHue = 256 - deltaHue
        EndIf
        
        ; Si la teinte correspond, convertir en niveaux de gris
        If deltaHue <= tolerance
          Protected gray = (r * 54 + g * 183 + b * 18) >> 8
          var = (a << 24) | (gray * $010101)  ; Préserve alpha
        EndIf
      EndIf
      
      *dstPixel\l = var
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure Color_hueEx(*FilterCtx.FilterParams)
  Restore Color_hue_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lance le traitement multithread
    Create_MultiThread_MT(@Color_hue_MT())
    
    ; Applique le masque si présent
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Color_hue(source, cible, mask, hue_target, tolerance)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = hue_target
    \option[1] = tolerance
  EndWith
  Color_hueEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Color_hue_Data:
  Data.s "Color_hue"                                     ; Nom du filtre
  Data.s "Désature une plage de teintes spécifique"      ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                                               ; Sous-type
  
  Data.s "Teinte cible"                                  ; Label option 0
  Data.i 0, 255, 0                                       ; Min, Max, Défaut
  
  Data.s "Tolérance"                                     ; Label option 1
  Data.i 0, 128, 20                                      ; Min, Max, Défaut
  
  Data.s "XXX"                                           ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 88
; FirstLine = 66
; Folding = -
; EnableXP
; DPIAware