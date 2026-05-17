; ----------------------------------------------------------------------------------
; Procédure thread pour l'effet Négatif (Inversion des couleurs)
; ----------------------------------------------------------------------------------

Procedure Negatif_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, pixel.l
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      
      ; On inverse uniquement les bits RGB ($00FFFFFF) 
      ; Le canal Alpha (bits 24-31) est conservé tel quel via le XOR
      ; XOR avec $00FFFFFF inverse r, g, et b sans toucher à l'alpha.
      *dstPixel\l = pixel ! $00FFFFFF
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure NegatifEx(*FilterCtx.FilterParams)
  Restore Negatif_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Negatif_MT())
    
    ; Gestion du masque et de la fusion finale
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Negatif(source, cible, mask)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  NegatifEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Negatif_Data:
  Data.s "Négatif"            ; Nom
  Data.s "Inverse les couleurs de l'image (effet négatif photo)" ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                    ; Sous-type
  
  Data.s "XXX"                ; Pas d'options nécessaires
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 49
; FirstLine = 17
; Folding = -
; EnableXP
; DPIAware