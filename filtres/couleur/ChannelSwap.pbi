; ----------------------------------------------------------------------------------
; Procédure thread pour la permutation des canaux RGB
; ----------------------------------------------------------------------------------

Procedure ChannelSwap_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected opt = \option[0]
    
    Clamp(opt, 0, 5)
    
    Protected i, var, a, r, g, b, rgb
    Protected totalPixels = lg * ht
    
    ; Utilisation de la macro avec parenthèses pour l'argument composé
    macro_calul_tread((lg * ht))
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      var = *srcPixel\l
      getargb(var, a, r, g, b)
      
      ; Permutations directes des canaux (6 combinaisons possibles)
      Select opt
        Case 0 : rgb = (r << 16) | (g << 8) | b  ; RGB (original)
        Case 1 : rgb = (r << 16) | (b << 8) | g  ; RBG
        Case 2 : rgb = (g << 16) | (r << 8) | b  ; GRB
        Case 3 : rgb = (g << 16) | (b << 8) | r  ; GBR
        Case 4 : rgb = (b << 16) | (r << 8) | g  ; BRG
        Case 5 : rgb = (b << 16) | (g << 8) | r  ; BGR
      EndSelect
      
      *dstPixel\l = (a << 24) | rgb
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure ChannelSwapEx(*FilterCtx.FilterParams)
  Restore ChannelSwap_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lance le traitement multithread
    Create_MultiThread_MT(@ChannelSwap_MT())
    
    ; Applique le masque si présent
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure ChannelSwap(source, cible, mask, mode)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = mode
  EndWith
  ChannelSwapEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  ChannelSwap_Data:
  Data.s "Channel Swap"                     ; Nom du filtre
  Data.s "Permutation pure des canaux RGB"  ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                                  ; Sous-type
  
  Data.s "Mode (0-5)"                       ; Label option 0
  Data.i 0, 5, 0                            ; Min, Max, Défaut
  
  Data.s "XXX"                              ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 66
; FirstLine = 40
; Folding = -
; EnableXP
; DPIAware