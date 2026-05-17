; ----------------------------------------------------------------------------------
; Procédure thread pour Raviver les Couleurs (Saturation Sélective)
; ----------------------------------------------------------------------------------

Procedure ReviveColors_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, gray, pixel.l
    Protected diffR, diffG, diffB, maxDiff
    Protected lightness, saturation, factor, factorInput
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    
    ; Configuration des seuils
    Protected minSaturation = 4
    Protected minLightness  = 32
    
    ; Mode et Intensité
    Protected mode = \option[1]
    factorInput = \option[0]
    If factorInput < 1 : factorInput = 1 : ElseIf factorInput > 512 : factorInput = 512 : EndIf
    
    ; Conversion en base 256 pour calcul en virgule fixe
    ; 100% (valeur 100) devient 512 dans le calcul original
    factorInput = 256 + (factorInput * 256) / 100
    
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      a = (pixel >> 24) & $FF
      r = (pixel >> 16) & $FF
      g = (pixel >> 8)  & $FF
      b = pixel & $FF
      
      ; Calcul de la luminance (moyenne rapide)
      gray = (r + g + b) / 3
      lightness = gray
      
      ; Calcul des écarts par rapport au gris
      diffR = r - gray
      diffG = g - gray
      diffB = b - gray
      
      ; Saturation = écart maximum (Remplacement de max3)
      Protected absR = Abs(diffR), absG = Abs(diffG), absB = Abs(diffB)
      maxDiff = absR
      If absG > maxDiff : maxDiff = absG : EndIf
      If absB > maxDiff : maxDiff = absB : EndIf
      
      ; Traitement uniquement si saturation et luminosité suffisantes
      If maxDiff > minSaturation And lightness > minLightness
        
        Select mode
          Case 0  ; Mode standard : saturation progressive
            saturation = (maxDiff * (256 - maxDiff)) >> 8
            
          Case 1  ; Mode luminosité : saturation inversement proportionnelle
            saturation = (maxDiff << 1)
            saturation = (saturation * (255 - lightness)) >> 8
            
          Case 2  ; Mode double
            saturation = maxDiff << 1 ; Simplification de (maxDiff * 256 / 128)
            
          Case 3  ; Mode quadruple
            saturation = maxDiff << 2
        EndSelect
        
        ; Limitation de la saturation calculée
        If saturation > 255 : saturation = 255 : EndIf
        
        ; Calcul du facteur d'amplification final
        factor = 256 + ((factorInput - 256) * saturation) >> 8
        
        ; Application du facteur aux écarts
        r = gray + ((diffR * factor) >> 8)
        g = gray + ((diffG * factor) >> 8)
        b = gray + ((diffB * factor) >> 8)
        
        ; Clamp local
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
      EndIf
      
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel
; ----------------------------------------------------------------------------------

Procedure ReviveColorsEx(*FilterCtx.FilterParams)
  Restore ReviveColors_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@ReviveColors_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure ReviveColors(source, cible, mask, intensite, mode)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensite
    \option[1] = mode
  EndWith
  ReviveColorsEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  ReviveColors_Data:
  Data.s "Revive Colors"
  Data.s "Renforce sélectivement la saturation des zones colorées et lumineuses"
  Data.i #FilterType_ColorEffect
  Data.i 0
  
  Data.s "Intensité (1-512)"
  Data.i 1, 512, 100
  
  Data.s "Mode (0-3)"
  Data.i 0, 3, 0
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 113
; FirstLine = 91
; Folding = -
; EnableXP
; DPIAware