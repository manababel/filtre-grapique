; ----------------------------------------------------------------------------------
; Procédure thread pour la Binarisation Noir & Blanc (Seuillage)
; ----------------------------------------------------------------------------------

Procedure BlackAndWhite_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, lum, l1, l2, pixel.l
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    Protected seuil = \option[0]
    Protected mode  = \option[1]
    
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      a = (pixel >> 24) & $FF
      r = (pixel >> 16) & $FF
      g = (pixel >> 8)  & $FF
      b = pixel & $FF
      
      Select mode
        Case 1  ; Rec.601 (Standard TV)
          lum = (r * 77 + g * 150 + b * 29) >> 8
          
        Case 2  ; Rec.709 (Vidéo HD)
          lum = (r * 54 + g * 183 + b * 18) >> 8
          
        Case 3  ; Valeur max
          lum = r : If g > lum : lum = g : EndIf : If b > lum : lum = b : EndIf
          
        Case 4  ; Valeur min
          lum = r : If g < lum : lum = g : EndIf : If b < lum : lum = b : EndIf
          
        Case 5  ; Valeur médiane
          l1 = r : l2 = g : lum = b
          If l1 > l2 : Swap l1, l2 : EndIf
          If l2 > lum : Swap l2, lum : EndIf
          If l1 > l2 : Swap l1, l2 : EndIf
          lum = l2 ; La valeur du milieu
          
        Case 6  ; HSL Lightness - (max + min) / 2
          l1 = r : If g > l1 : l1 = g : EndIf : If b > l1 : l1 = b : EndIf ; Max
          l2 = r : If g < l2 : l2 = g : EndIf : If b < l2 : l2 = b : EndIf ; Min
          lum = (l1 + l2) >> 1
          
        Case 7  ; Canal rouge
          lum = r
          
        Case 8  ; Canal vert
          lum = g
          
        Case 9  ; Canal bleu
          lum = b
          
        Default ; Moyenne simple
          lum = (r + g + b) * 85 >> 8
      EndSelect
      
      ; Seuillage binaire
      If lum > seuil
        *dstPixel\l = (a << 24) | $FFFFFF  ; Blanc (conserve l'alpha)
      Else
        *dstPixel\l = (a << 24)            ; Noir (conserve l'alpha)
      EndIf
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure BlackAndWhiteEx(*FilterCtx.FilterParams)
  Restore BlackAndWhite_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@BlackAndWhite_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure BlackAndWhite(source, cible, mask, seuil, mode)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = seuil
    \option[1] = mode
  EndWith
  BlackAndWhiteEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  BlackAndWhite_Data:
  Data.s "Black & White"      ; Nom
  Data.s "Binarisation de l'image (Noir/Blanc) avec seuil réglable" ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                    ; Sous-type
  
  Data.s "Seuil (0-255)"      ; Label option 0
  Data.i 0, 255, 127          ; Min, Max, Défaut
  
  Data.s "Méthode"            ; Label option 1
  Data.i 1, 9, 2              ; Min, Max, Défaut (Rec.709)
  
  Data.s "XXX"                ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 93
; FirstLine = 71
; Folding = -
; EnableAsm
; EnableThread
; EnableXP