; ----------------------------------------------------------------------------------
; Procédure thread pour ajuster la luminosité RGB (Offset)
; ----------------------------------------------------------------------------------

Procedure Brightness_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    
    ; Calcul des offsets (0..512 -> -255..255)
    Protected sr = \option[0] - 255
    Protected sg = \option[1] - 255
    Protected sb = \option[2] - 255
    
    ; Utilisation de la macro standard pour le découpage multithread
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      ; Extraction rapide des composantes
      a = (*srcPixel\l >> 24) & $FF
      r = (*srcPixel\l >> 16) & $FF
      g = (*srcPixel\l >> 8) & $FF
      b = *srcPixel\l & $FF
      
      ; Application de l'offset de luminosité
      r + sr
      g + sg
      b + sb
      
      ; Limitation (Clamp)
      If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
      
      ; Reconstruction du pixel
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure BrightnessEx(*FilterCtx.FilterParams)
  Restore Brightness_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lance le traitement multithread (appel de Brightness_MT)
    Create_MultiThread_MT(@Brightness_MT())
    
    ; Gestion du masque et de la fusion
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée pour code externe
; ----------------------------------------------------------------------------------

Procedure Brightness(source, cible, mask, r_adj, g_adj, b_adj)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = r_adj
    \option[1] = g_adj
    \option[2] = b_adj
  EndWith
  BrightnessEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre (DataSection)
; ----------------------------------------------------------------------------------

DataSection
  Brightness_Data:
  Data.s "Brightness"         ; Nom du filtre
  Data.s "Ajuste la luminosité individuelle des canaux RGB" ; Description
  Data.i #FilterType_ColorAdjustment
  Data.i 0                    ; Sous-type
  
  Data.s "Ajustement Rouge"   ; Label option 0
  Data.i 0, 512, 255          ; Min, Max, Défaut (255 = pas de changement)
  
  Data.s "Ajustement Vert"    ; Label option 1
  Data.i 0, 512, 255          
  
  Data.s "Ajustement Bleu"    ; Label option 2
  Data.i 0, 512, 255          
  
  Data.s "XXX"                ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 68
; FirstLine = 50
; Folding = -
; EnableAsm
; EnableThread
; EnableXP