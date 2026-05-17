; ----------------------------------------------------------------------------------
; Procédure thread pour l'effet Hollow / Ledge
; ----------------------------------------------------------------------------------

Procedure Hollow_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, var
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32

    ; Utilisation de la macro avec parenthèses pour l'argument composé
    macro_calul_tread((\image_lg[0] * \image_ht[1]))
    
    *srcPixel = \addr[0] + (thread_start << 2)
    *dstPixel = \addr[1] + (thread_start << 2)

    ; Application de la transformation sur chaque pixel
    For i = thread_start To thread_stop - 1
      var = *srcPixel\l
      getargb(var, a, r, g, b)
      
      ; Application de la LUT sur chaque canal couleur
      r = PeekA(\addr[2] + r)
      g = PeekA(\addr[2] + g)
      b = PeekA(\addr[2] + b)
      
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

Procedure HollowEx(*FilterCtx.FilterParams)
  Restore Hollow_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected opt = \option[0]
    Protected i, v.f, v1.f

    ; Clamp de l'angle
    Clamp(opt, 0, 360)
    
    ; Conversion (Respect strict des calculs d'origine)
    v = opt / 255.0 * #PI / 180.0
    
    ; Génération de la LUT
    \addr[2] = AllocateMemory(256)
    For i = 0 To 255
      If Not \option[1]
        v1 = 255 * (1 - Sin(i * v))
      Else
        v1 = 255 * (Sin(i * v))
      EndIf
      Clamp(v1, 0, 255)
      PokeA(\addr[2] + i, v1)
    Next
    
    ; Lance le traitement multithread
    Create_MultiThread_MT(@Hollow_MT())
    
    ; Applique le masque si présent
    mask_update(*FilterCtx, last_data)
    
    ; Libération de la mémoire
    If \addr[2] : FreeMemory(\addr[2]) : \addr[2] = 0 : EndIf
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Hollow(source, cible, mask, angle, mode_hollow)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = angle
    \option[1] = mode_hollow
  EndWith
  HollowEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Hollow_Data:
  Data.s "Hollow"                                       ; Nom du filtre
  Data.s "Transformation sinusoïdale des canaux"        ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                                              ; Sous-type
  
  Data.s "Angle (0-360)"                                ; Label option 0
  Data.i 0, 360, 180                                    ; Min, Max, Défaut
  
  Data.s "Hollow/Ledge (0-1)"                           ; Label option 1
  Data.i 0, 1, 0                                        ; Min, Max, Défaut
  
  Data.s "XXX"                                          ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 82
; FirstLine = 60
; Folding = -
; EnableXP
; DPIAware