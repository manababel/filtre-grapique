; ----------------------------------------------------------------------------------
; Procédure thread pour la correction Gamma
; ----------------------------------------------------------------------------------

Procedure Gamma_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, pixel.l
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    
    ; Récupération de la LUT pré-calculée passée via pData
    Protected *lut = \addr[2]
    
    ; Utilisation de la macro standard pour le découpage multithread
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      
      ; Extraction rapide des composantes
      a = (pixel >> 24) & $FF
      r = (pixel >> 16) & $FF
      g = (pixel >> 8) & $FF
      b = pixel & $FF
      
      ; Transformation via la LUT (Gamma)
      r = PeekA(*lut + r)
      g = PeekA(*lut + g)
      b = PeekA(*lut + b)
      
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

Procedure GammaEx(*FilterCtx.FilterParams)
  Restore Gamma_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; --- Pré-calcul de la LUT Gamma ---
    Protected *lut = AllocateMemory(256)
    If Not *lut : ProcedureReturn 0 : EndIf
    
    ; On inverse l'option pour que le curseur soit intuitif (plus on monte, plus c'est clair)
    ; Ou on garde votre logique de raw/100
    Protected gamma_f.f = (255 - \option[0]) / 100.0
    If gamma_f < 0.01 : gamma_f = 0.01 : EndIf
    
    Protected i
    For i = 0 To 255
      Protected var = Pow(i / 255.0, gamma_f) * 255.0
      If var > 255 : var = 255 : ElseIf var < 0 : var = 0 : EndIf
      PokeA(*lut + i, var)
    Next
    
    ; Passage de la LUT aux threads
    \addr[2] = *lut
    
    ; Lancement du traitement
    Create_MultiThread_MT(@Gamma_MT())
    
    ; Nettoyage
    FreeMemory(*lut)
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Gamma(source, cible, mask, gamma_val)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = gamma_val
  EndWith
  GammaEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre (DataSection)
; ----------------------------------------------------------------------------------

DataSection
  Gamma_Data:
  Data.s "Gamma"              ; Nom
  Data.s "Ajuste la courbe gamma (luminosité non-linéaire)" ; Description
  Data.i #FilterType_ColorAdjustment
  Data.i 0                    ; Sous-type
  
  Data.s "Gamma (x100)"       ; Label option 0
  Data.i 1, 255, 127          ; Min, Max, Défaut
  
  Data.s "XXX"                ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 60
; FirstLine = 38
; Folding = -
; EnableXP
; DPIAware