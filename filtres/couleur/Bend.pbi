; ----------------------------------------------------------------------------------
; Procédure thread pour l'effet "Bend" (distorsion colorimétrique par sinus)
; ----------------------------------------------------------------------------------

Procedure Bend_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, pixel.l, a, r, g, b
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32

    Protected tabr = \addr[3]
    Protected tabg = \addr[4]
    Protected tabb = \addr[5]
    
    ; Utilisation de la macro avec parenthèses pour l'argument composé
    macro_calul_tread((\image_lg[0] * \image_ht[1]))
    
    *srcPixel = \addr[0] + (thread_start << 2)
    *dstPixel = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      GetARGB(pixel, a, r, g, b)
      
      ; Application des LUTs par canal
      r = PeekA(tabr + r) 
      g = PeekA(tabg + g) 
      b = PeekA(tabb + b) 
      
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure BendEx(*FilterCtx.FilterParams)
  Restore Bend_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    \addr[3] = AllocateMemory(256)
    \addr[4] = AllocateMemory(256)
    \addr[5] = AllocateMemory(256)
    
    ; Conversion des angles en radians (Respect strict de la logique d'origine)
    Protected r1.f = (\option[0] - 180) / 255.0 * #PI / 180.0
    Protected g1.f = (\option[1] - 180) / 255.0 * #PI / 180.0
    Protected b1.f = (\option[2] - 180) / 255.0 * #PI / 180.0

    Protected r, g, b, i
    For i = 0 To 255
      r = Sin(i * r1) * 127 + i
      g = Sin(i * g1) * 127 + i
      b = Sin(i * b1) * 127 + i
      Clamp_RGB(r, g, b)
      PokeA(\addr[3] + i, r)
      PokeA(\addr[4] + i, g)
      PokeA(\addr[5] + i, b)
    Next

    ; Lance le traitement multithread
    Create_MultiThread_MT(@Bend_MT())
    
    ; Applique le masque si présent
    mask_update(*FilterCtx, last_data)
    
    ; Libération de la mémoire
    If \addr[3] : FreeMemory(\addr[3]) : \addr[3] = 0 : EndIf
    If \addr[4] : FreeMemory(\addr[4]) : \addr[4] = 0 : EndIf
    If \addr[5] : FreeMemory(\addr[5]) : \addr[5] = 0 : EndIf
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Bend(source, cible, mask, angle_r, angle_g, angle_b)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = angle_r
    \option[1] = angle_g
    \option[2] = angle_b
  EndWith
  BendEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Bend_Data:
  Data.s "Bend"                                 ; Nom du filtre
  Data.s "Distorsion colorimétrique RGB"        ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                                      ; Sous-type
  
  Data.s "Angle Rouge (1-512)"                  ; Label option 0
  Data.i 1, 512, 255                            ; Min, Max, Défaut
  
  Data.s "Angle Vert (1-512)"                   ; Label option 1
  Data.i 1, 512, 255                            ; Min, Max, Défaut
  
  Data.s "Angle Bleu (1-512)"                   ; Label option 2
  Data.i 1, 512, 255                            ; Min, Max, Défaut
  
  Data.s "XXX"                                  ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 84
; FirstLine = 66
; Folding = -
; EnableXP
; DPIAware