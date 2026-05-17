; ----------------------------------------------------------------------------------
; Procédure thread pour l'effet Sépia Vintage
; ----------------------------------------------------------------------------------

Procedure Sepia_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, r2, g2, b2, pixel.l
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    
    ; Facteur de température : 100 = neutre. 
    ; Calcul de l'offset en dehors de la boucle pour la performance.
    Protected offset = (\option[0] - 100) * 0.4 ; On simplifie le (tempOffset * 40 / 100)
    
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
      
      ; Transformation Sépia (Coefficients entiers / 256)
      ; R' = 0.393R + 0.769G + 0.189B
      ; G' = 0.349R + 0.686G + 0.168B
      ; B' = 0.272R + 0.534G + 0.131B
      r2 = (r * 101 + g * 197 + b * 48) >> 8
      g2 = (r * 89  + g * 175 + b * 43) >> 8
      b2 = (r * 70  + g * 137 + b * 33) >> 8
      
      ; Application de la température (Chaud = Rouge+, Bleu- | Froid = Rouge-, Bleu+)
      r2 + offset
      b2 - offset
      
      ; Clamp intégré pour la rapidité
      If r2 < 0 : r2 = 0 : ElseIf r2 > 255 : r2 = 255 : EndIf
      If g2 < 0 : g2 = 0 : ElseIf g2 > 255 : g2 = 255 : EndIf
      If b2 < 0 : b2 = 0 : ElseIf b2 > 255 : b2 = 255 : EndIf
      
      ; Reconstruction
      *dstPixel\l = (a << 24) | (r2 << 16) | (g2 << 8) | b2
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure SepiaEx(*FilterCtx.FilterParams)
  Restore Sepia_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Sepia_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Sepia(source, cible, mask, temperature)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = temperature
  EndWith
  SepiaEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Sepia_Data:
  Data.s "Sepia Tone"         ; Nom
  Data.s "Effet photo vintage avec ajustement de température (froid à chaud)" ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                    ; Sous-type
  
  Data.s "Température"        ; Label option 0
  Data.i 0, 200, 100          ; Min, Max, Défaut (100 = Sépia classique)
  
  Data.s "XXX"                ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 72
; FirstLine = 46
; Folding = -
; EnableXP
; DPIAware