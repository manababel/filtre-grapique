; ----------------------------------------------------------------------------------
; Procédure thread pour la conversion en Niveaux de Gris (Multi-méthodes)
; ----------------------------------------------------------------------------------

Procedure Grayscale_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, gray, t1, t2, pixel.l
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    Protected typ = \option[0]
    
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      a = (pixel >> 24) & $FF
      r = (pixel >> 16) & $FF
      g = (pixel >> 8) & $FF
      b = pixel & $FF
      
      Select typ    
        Case 1 ; Luma BT.601
          gray = (r * 1225 + g * 2405 + b * 466) >> 12
        Case 2 ; Luma BT.709
          gray = (r * 870 + g * 2930 + b * 296) >> 12 
        Case 3 ; Pondération personnalisée (rapide)
          gray = (r * 1293 + g * 2156 + b * 647) >> 12  
        Case 4 ; Maximum (canal dominant)
          gray = r : If g > gray : gray = g : EndIf : If b > gray : gray = b : EndIf  
        Case 5 ; Minimum (canal le plus faible)
          gray = r : If g < gray : gray = g : EndIf : If b < gray : gray = b : EndIf      
        Case 6 ; Médiane
          If r > g : Swap r, g : EndIf
          If g > b : Swap g, b : EndIf
          If r > g : Swap r, g : EndIf
          gray = g    
        Case 7 ; Rouge seul
          gray = r       
        Case 8 ; Vert seul
          gray = g    
        Case 9 ; Bleu seul
          gray = b      
        Case 10 ; Luminosité perceptuelle
          gray = Sqr(r * r * 0.299 + g * g * 0.587 + b * b * 0.114)  
        Case 11 ; Moyenne pondérée gamma-corrected
          gray = Sqr(r * r * 0.2126 + g * g * 0.7152 + b * b * 0.0722)   
        Case 12 ; Moyenne (min + max) / 2
          t1 = r : If g > t1 : t1 = g : EndIf : If b > t1 : t1 = b : EndIf
          t2 = r : If g < t2 : t2 = g : EndIf : If b < t2 : t2 = b : EndIf
          gray = (t1 + t2) >> 1 
        Case 13 ; Valeur (V de HSV)
          gray = r : If g > gray : gray = g : EndIf : If b > gray : gray = b : EndIf 
        Case 14 ; Luma BT.2100 (HDR/WCG)
          gray = (r * 1078 + g * 2775 + b * 243) >> 12
        Default ; Moyenne arithmétique simple
          gray = (r + g + b) / 3
      EndSelect
      
      ; Reconstruction rapide du pixel : aaaa|gray|gray|gray
      *dstPixel\l = (a << 24) | (gray * $010101)
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure GrayscaleEx(*FilterCtx.FilterParams)
  Restore Grayscale_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Grayscale_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Grayscale(source, cible, mask, type_gris)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = type_gris
  EndWith
  GrayscaleEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Grayscale_Data:
  Data.s "Grayscale"          ; Nom
  Data.s "Convertit l'image en niveaux de gris selon 14 méthodes différentes" ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                    ; Sous-type
  
  Data.s "Méthode (0-14)"     ; Label option 0
  Data.i 0, 14, 2             ; Min, Max, Défaut (BT.709 par défaut)
  
  Data.s "XXX"                ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 88
; FirstLine = 62
; Folding = -
; EnableXP
; DPIAware