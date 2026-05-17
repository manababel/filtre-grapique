; ----------------------------------------------------------------------------------
; Procédure thread pour l'ajustement du balance des couleurs RGB
; ----------------------------------------------------------------------------------

Procedure Balance_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, pixel.l, a.l, r.l, g.l, b.l
    
    ; Les facteurs sont normalisés par rapport à 255 (décalage de 8 bits)
    Protected factorR.i = \option[0]
    Protected factorG.i = \option[1]
    Protected factorB.i = \option[2]
    
    Protected totalPixels = \image_lg[0] * \image_ht[0]
    
    ; Utilisation de la macro standard pour le découpage multithread
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    
    ; On pointe sur le début du segment assigné à ce thread
    *srcPixel = \addr[0] + (thread_start << 2)
    *dstPixel = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      
      ; Extraction des composantes
      a = (pixel >> 24) & $FF
      r = (pixel >> 16) & $FF
      g = (pixel >> 8) & $FF
      b = pixel & $FF
      
      ; Application du gain
      r = (factorR * r) >> 8
      g = (factorG * g) >> 8
      b = (factorB * b) >> 8
      
      ; Limitation (Clamp)
      If r > 255 : r = 255 : EndIf
      If g > 255 : g = 255 : EndIf
      If b > 255 : b = 255 : EndIf
      
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

Procedure BalanceEx(*FilterCtx.FilterParams)
  Restore Balance_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lance le traitement multithread
    Create_MultiThread_MT(@Balance_MT())
    
    ; Applique le masque si présent (géré par le moteur)
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Balance(source, cible, mask, r_factor, g_factor, b_factor)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = r_factor
    \option[1] = g_factor
    \option[2] = b_factor
  EndWith
  BalanceEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Balance_Data:
  Data.s "Balance"            ; Nom du filtre
  Data.s "Ajuste les gains par canal RGB (Balance des blancs)" ; Description
  Data.i #FilterType_ColorAdjustment
  Data.i 0                    ; Sous-type (si applicable)
  
  Data.s "Rouge (0-255)"      ; Label option 0
  Data.i 0, 512, 255          ; Min, Max, Défaut
  
  Data.s "Vert (0-255)"       ; Label option 1
  Data.i 0, 512, 255          ; Min, Max, Défaut
  
  Data.s "Bleu (0-255)"       ; Label option 2
  Data.i 0, 512, 255          ; Min, Max, Défaut
  
  Data.s "XXX"                ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 13
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger