; ----------------------------------------------------------------------------------
; Fonction utilitaire (Non modifiée, respect du typage float)
; ----------------------------------------------------------------------------------

Procedure FalseColour_RGBfromHSL(h.f, s.f, l.f)
  Protected r.f, g.f, b.f
  Protected c.f = (1 - Abs(2 * l - 1)) * s
  Protected x.f = c * (1 - Abs(Mod(h / 60, 2) - 1))
  Protected m.f = l - c / 2
  Select Int(h / 60)
    Case 0 : r=c : g=x : b=0
    Case 1 : r=x : g=c : b=0
    Case 2 : r=0 : g=c : b=x
    Case 3 : r=0 : g=x : b=c
    Case 4 : r=x : g=0 : b=c
    Default: r=c : g=0 : b=x
  EndSelect
  r = (r + m) * 255
  g = (g + m) * 255
  b = (b + m) * 255

  ProcedureReturn $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b)
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure thread pour l'effet False Colour
; ----------------------------------------------------------------------------------

Procedure FalseColour_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected totalPixels = lg * ht
    
    ; Utilisation de la macro avec parenthèses pour l'argument composé
    macro_calul_tread((lg * ht))
    
    *srcPixel = \addr[0] + (thread_start << 2)
    *dstPixel = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      getargb(*srcPixel\l , a , r , g , b)
      
      ; Respect strict des opérations mathématiques d'origine
      Protected grey = ((r * 1225 + g * 2405 + b * 466) >> 12)
      Protected ratio = (grey * 4016) >> 10
      
      ; Utilisation de l'adresse temporaire stockée en addr[2]
      Protected color = PeekL(\addr[2] + (ratio << 2))
      
      getargb(color, a, r, g, b)
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure FalseColourEx(*FilterCtx.FilterParams)
  Restore FalseColour_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected teinte.f = \option[0]
    \addr[2] = AllocateMemory(1001 * 4)
    Protected i
    For i = 0 To 1000 
      PokeL(\addr[2] + (i << 2) , FalseColour_RGBfromHSL(Mod((i/1000.0*360 + teinte) , 360), 1, 0.5))
    Next
    
    ; Lance le traitement multithread
    Create_MultiThread_MT(@FalseColour_MT())
    
    ; Applique le masque si présent
    mask_update(*FilterCtx, last_data)
    
    If \addr[2] : FreeMemory(\addr[2]) : \addr[2] = 0 : EndIf
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure FalseColour(source, cible, mask, mode_couleur)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = mode_couleur
  EndWith
  FalseColourEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  FalseColour_Data:
  Data.s "False Colour"                        ; Nom du filtre
  Data.s "Teinte basée sur l'intensité"        ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                                     ; Sous-type
  
  Data.s "Mode Couleur (0-360)"                ; Label option 0
  Data.i 0, 360, 0                             ; Min, Max, Défaut
  
  Data.s "XXX"                                 ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 93
; FirstLine = 67
; Folding = -
; EnableXP
; DPIAware