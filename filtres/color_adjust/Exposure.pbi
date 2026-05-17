; ----------------------------------------------------------------------------------
; Procédure thread pour la Correction d'Exposition (Courbe exponentielle)
; ----------------------------------------------------------------------------------

Procedure Exposure_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, pixel.l
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    
    ; On récupère la LUT pré-calculée stockée dans l'adresse temporaire du contexte
    Protected *lut = \addr[2] 
    
    ; Utilisation de la macro standard pour le découpage multithread
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      
      ; Extraction des composantes
      a = (pixel >> 24) & $FF
      r = (pixel >> 16) & $FF
      g = (pixel >> 8) & $FF
      b = pixel & $FF
      
      ; Transformation par la LUT
      r = PeekA(*lut + r)
      g = PeekA(*lut + g)
      b = PeekA(*lut + b)
      
      ; Reconstruction du pixel (Le clamp est déjà géré par la LUT)
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure ExposureEx(*FilterCtx.FilterParams)
  Restore Exposure_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; --- Pré-calcul de la LUT (Lookup Table) ---
    Protected *lut = AllocateMemory(256)
    Protected exposure.f = \option[0] * 0.1
    Protected i
    If exposure < 0.1 : exposure = 0.1 : EndIf
    
    For i = 0 To 255
      Protected val.f = 255 * (1.0 - Exp(-i * exposure / 255.0))
      If val > 255 : val = 255 : EndIf
      PokeA(*lut + i, Int(val))
    Next
    
    ; On transmet la LUT aux threads via le pointeur pData
    \addr[2] = *lut
    
    ; Traitement multithread
    Create_MultiThread_MT(@Exposure_MT())
    
    ; Libération de la LUT et mise à jour du masque
    FreeMemory(*lut)
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Exposure(source, cible, mask, exposure_val)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = exposure_val
  EndWith
  ExposureEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Exposure_Data:
  Data.s "Exposure"           ; Nom
  Data.s "Correction d'exposition photographique (courbe exponentielle)" ; Description
  Data.i #FilterType_ColorAdjustment
  Data.i 0                    ; Sous-type
  
  Data.s "Exposition"         ; Label option 0
  Data.i 1, 255, 15           ; Min, Max, Défaut
  
  Data.s "XXX"                ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 54
; FirstLine = 31
; Folding = -
; EnableXP
; DPIAware