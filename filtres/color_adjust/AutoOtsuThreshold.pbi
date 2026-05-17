; ----------------------------------------------------------------------------------
; Procédure thread pour la Binarisation (Passe 2 : Application du seuil)
; ----------------------------------------------------------------------------------

Procedure AutoOtsuThreshold_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, r, g, b, lum, pixel.l
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    
    ; On récupère le seuil optimal calculé en Passe 1
    Protected threshold = \option[10] 
    
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      
      ; Calcul de luminance rapide (Rec. 709)
      r = (pixel >> 16) & $FF
      g = (pixel >> 8) & $FF
      b = pixel & $FF
      lum = (r * 54 + g * 183 + b * 18) >> 8
      
      ; Binarisation (Seuil d'Otsu)
      If lum > threshold
        *dstPixel\l = $FFFFFFFF ; Blanc (Alpha opaque)
      Else
        *dstPixel\l = $FF000000 ; Noir (Alpha opaque)
      EndIf
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et calcul du seuil d'Otsu (Passe 1)
; ----------------------------------------------------------------------------------

Procedure AutoOtsuThresholdEx(*FilterCtx.FilterParams)
  Restore AutoOtsuThreshold_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected i, r, g, b, lum
    Protected total = \image_lg[0] * \image_ht[1]
    Protected *ptr.Pixel32 = \addr[0]
    Dim histo(255)

    ; --- 1. Calcul de l'histogramme global ---
    For i = 0 To total - 1
      r = (*ptr\l >> 16) & $FF
      g = (*ptr\l >> 8) & $FF
      b = *ptr\l & $FF
      lum = (r * 54 + g * 183 + b * 18) >> 8
      histo(lum) + 1
      *ptr + 4
    Next

    ; --- 2. Algorithme d'Otsu pour trouver le seuil optimal ---
    Protected.q sumAll = 0
    For i = 0 To 255 : sumAll + i * histo(i) : Next

    Protected.q sumB = 0
    Protected.i wB = 0, wF = 0
    Protected.f mB, mF, maxVar = -1.0, varBetween
    Protected threshold = 0

    For i = 0 To 255
      wB + histo(i)               ; Poids de l'arrière-plan
      If wB = 0 : Continue : EndIf
      
      wF = total - wB             ; Poids de l'avant-plan
      If wF = 0 : Break : EndIf

      sumB + i * histo(i)
      mB = sumB / wB              ; Moyenne arrière-plan
      mF = (sumAll - sumB) / wF   ; Moyenne avant-plan

      ; Variance inter-classe
      varBetween = wB * wF * (mB - mF) * (mB - mF)
      
      If varBetween > maxVar
        maxVar = varBetween
        threshold = i
      EndIf
    Next

    ; Stockage du seuil pour les threads
    \option[10] = threshold
    
    ; --- 3. Lancement de la binarisation multithread ---
    Create_MultiThread_MT(@AutoOtsuThreshold_MT())
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure AutoOtsuThreshold(source, cible, mask)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  AutoOtsuThresholdEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  AutoOtsuThreshold_Data:
  Data.s "Auto Otsu Threshold"
  Data.s "Binarisation automatique par calcul de variance inter-classe (Otsu)"
  Data.i #FilterType_ColorAdjustment
  Data.i 0
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 107
; FirstLine = 75
; Folding = -
; EnableXP
; DPIAware