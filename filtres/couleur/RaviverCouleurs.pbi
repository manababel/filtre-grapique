; ────────────────────────────────────────────────────────────────
; Procédure thread pour raviver les couleurs d'une image ARGB 32 bits
;
; Renforce la saturation locale dans les zones suffisamment
; lumineuses et colorées, en arithmétique entière pure.
; ────────────────────────────────────────────────────────────────
Procedure RaviverCouleurs_MT(*p.parametre)
  Protected i, a, r, g, b, gray
  Protected diffR, diffG, diffB, maxDiff
  Protected lightness, saturation, factor, factorInput
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  
  ; Seuils de saturation et luminosité minimales
  Protected minSaturation = 4
  Protected minLightness = 32
  
  ; Clamp et conversion du facteur en base 256 pour calcul fixe
  factorInput = *p\option[0]  ; 1-512
  Clamp(factorInput, 1, 512)
  factorInput = 256 + (factorInput * 256) / 100  ; ex: 100% → 512
  
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  
  *srcPixel = *p\addr[0] + (startPos << 2)
  *dstPixel = *p\addr[1] + (startPos << 2)
  
  For i = startPos To endPos - 1
    getargb(*srcPixel\l, a, r, g, b)
    
    ; Calcul du niveau de gris (moyenne simple pour performance)
    gray = (r + g + b) / 3
    lightness = gray
    
    ; Calcul des écarts par rapport au gris
    diffR = r - gray
    diffG = g - gray
    diffB = b - gray
    
    ; Saturation = écart maximum
    max3(maxDiff, Abs(diffR), Abs(diffG), Abs(diffB))
    
    ; Traitement uniquement si saturation et luminosité suffisantes
    If maxDiff > minSaturation And lightness > minLightness
      ; Calcul de la saturation modulée selon le mode
      Select *p\option[1]
        Case 0  ; Mode standard : saturation progressive
          saturation = maxDiff
          saturation = (saturation * (256 - saturation)) >> 8
          
        Case 1  ; Mode luminosité : saturation inversement proportionnelle
          saturation = maxDiff << 1
          saturation = (saturation * (255 - lightness)) >> 8
          
        Case 2  ; Mode double : saturation x2
          saturation = (maxDiff << 8) / 128  ; ≈ maxDiff * 2
          
        Case 3  ; Mode quadruple : saturation x4
          saturation = maxDiff << 2
          If saturation > 255 : saturation = 255 : EndIf
      EndSelect
      
      ; Calcul du facteur d'amplification final
      factor = 256 + ((factorInput - 256) * saturation) >> 8
      
      ; Application du facteur aux écarts
      r = gray + ((diffR * factor) >> 8)
      g = gray + ((diffG * factor) >> 8)
      b = gray + ((diffB * factor) >> 8)
    EndIf
    
    Clamp_RGB(r, g, b)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

; ────────────────────────────────────────────────────────────────
; Procédure principale pour Raviver les Couleurs avec masque optionnel
Procedure RaviverCouleurs(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Revive Colors"
    param\remarque = "Renforce la saturation des couleurs de manière sélective"
    param\info[0] = "Intensité"
    param\info[1] = "Mode"
    param\info[2] = "Masque"
    param\info_data(0,0) = 1   : param\info_data(0,1) = 512 : param\info_data(0,2) = 100
    param\info_data(1,0) = 0   : param\info_data(1,1) = 3   : param\info_data(1,2) = 0
    param\info_data(2,0) = 0   : param\info_data(2,1) = 2   : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@RaviverCouleurs_MT(), 1, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 98
; FirstLine = 29
; Folding = -
; EnableXP
; DPIAware