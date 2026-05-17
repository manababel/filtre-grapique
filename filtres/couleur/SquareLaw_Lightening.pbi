; ----------------------------------------------------------------------------------
; Procédure thread pour l'effet d'éclaircissement par loi quadratique
; ----------------------------------------------------------------------------------

Procedure SquareLaw_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, var
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    
    ; Utilisation de la macro avec parenthèses pour l'argument composé
    macro_calul_tread((\image_lg[0] * \image_ht[1]))
    
    ; Récupération de la LUT précalculée
    Protected *lut = \addr[2]
    
    *srcPixel = \addr[0] + (thread_start << 2)
    *dstPixel = \addr[1] + (thread_start << 2)
    
    ; Traitement pixel par pixel
    For i = thread_start To thread_stop - 1
      var = *srcPixel\l
      getargb(var, a, r, g, b)
      
      ; Application de la LUT
      r = PeekA(*lut + r)
      g = PeekA(*lut + g)
      b = PeekA(*lut + b)
      
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure SquareLaw_LighteningEx(*FilterCtx.FilterParams)
  Restore SquareLaw_Lightening_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Clamp de l'intensité
    Protected intensity = \option[0]
    Clamp(intensity, 1, 255)
    
    ; Calcul de la valeur carrée (puissance max)
    Protected sqrval = intensity * intensity
    
    ; Allocation et génération de la LUT quadratique inversée
    \addr[2] = AllocateMemory(256)
    
    Protected i, inv, val
    For i = 0 To 255
      inv = 255 - i
      val = sqrval - inv * inv
      If val < 0 : val = 0 : EndIf
      PokeA(\addr[2] + i, Int(Sqr(val)))
    Next
    
    ; Lance le traitement multithread
    Create_MultiThread_MT(@SquareLaw_MT())
    
    ; Applique le masque si présent
    mask_update(*FilterCtx, last_data)
    
    ; Libération de la mémoire
    If \addr[2] : FreeMemory(\addr[2]) : \addr[2] = 0 : EndIf
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure SquareLaw_Lightening(source, cible, mask, intensite)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensite
  EndWith
  SquareLaw_LighteningEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  SquareLaw_Lightening_Data:
  Data.s "Square Law Lightening"                            ; Nom du filtre
  Data.s "Éclaircissement progressif par loi quadratique"   ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                                                  ; Sous-type
  
  Data.s "Intensité (1-255)"                                ; Label option 0
  Data.i 1, 255, 127                                        ; Min, Max, Défaut
  
  Data.s "XXX"                                              ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 81
; FirstLine = 55
; Folding = -
; EnableXP
; DPIAware