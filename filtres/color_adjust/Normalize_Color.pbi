; ----------------------------------------------------------------------------------
; Procédure thread pour la Normalisation des couleurs (Étirement de contraste)
; ----------------------------------------------------------------------------------

Procedure Normalize_Color_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b, pixel.l
    Protected totalPixels = \image_lg[0] * \image_ht[1]
    
    ; Récupération des min/max globaux calculés dans la procédure parente
    ; On utilise les options temporaires ou pData pour passer ces valeurs
    Protected rmin = \option[10], rmax = \option[11]
    Protected gmin = \option[12], gmax = \option[13]
    Protected bmin = \option[14], bmax = \option[15]
    
    ; Calcul des plages (range) avec protection division par zéro
    Protected rangeR = rmax - rmin : If rangeR <= 0 : rangeR = 1 : EndIf
    Protected rangeG = gmax - gmin : If rangeG <= 0 : rangeG = 1 : EndIf
    Protected rangeB = bmax - bmin : If rangeB <= 0 : rangeB = 1 : EndIf
    
    ; Utilisation de la macro standard pour le découpage multithread
    macro_calul_tread(totalPixels)
    
    Protected *srcPixel.Pixel32 = \addr[0] + (thread_start << 2)
    Protected *dstPixel.Pixel32 = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      pixel = *srcPixel\l
      
      ; Extraction
      a = (pixel >> 24) & $FF
      r = (pixel >> 16) & $FF
      g = (pixel >> 8) & $FF
      b = pixel & $FF
      
      ; Normalisation : (Valeur - Min) * 255 / Plage
      r = ((r - rmin) * 255) / rangeR
      g = ((g - gmin) * 255) / rangeG
      b = ((b - bmin) * 255) / rangeB
      
      ; Limitation
      If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
      
      ; Reconstruction
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure Normalize_ColorEx(*FilterCtx.FilterParams)
  Restore Normalize_Color_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; --- Passe 1 : Recherche des Min/Max Globaux (nécessaire avant le MT) ---
    Protected rmin = 255, rmax = 0
    Protected gmin = 255, gmax = 0
    Protected bmin = 255, bmax = 0
    Protected *ptr.Pixel32 = \addr[0]
    Protected total = \image_lg[0] * \image_ht[1]
    Protected r, g, b ,i
    
    For i = 0 To total - 1
      r = (*ptr\l >> 16) & $FF
      g = (*ptr\l >> 8) & $FF
      b = *ptr\l & $FF
      
      If r < rmin : rmin = r : EndIf : If r > rmax : rmax = r : EndIf
      If g < gmin : gmin = g : EndIf : If g > gmax : gmax = g : EndIf
      If b < bmin : bmin = b : EndIf : If b > bmax : bmax = b : EndIf
      *ptr + 4
    Next
    
    ; Stockage temporaire pour les threads
    \option[10] = rmin : \option[11] = rmax
    \option[12] = gmin : \option[13] = gmax
    \option[14] = bmin : \option[15] = bmax
    
    ; --- Passe 2 : Traitement Multithread ---
    Create_MultiThread_MT(@Normalize_Color_MT())
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Normalize_Color(source, cible, mask)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  Normalize_ColorEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Normalize_Color_Data:
  Data.s "Normalize Color"    ; Nom
  Data.s "Étend les composantes RGB pour occuper toute la plage 0-255" ; Description
  Data.i #FilterType_ColorAdjustment
  Data.i 0                    ; Sous-type
  
  Data.s "XXX"                ; Pas d'options utilisateur nécessaires
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 70
; FirstLine = 58
; Folding = -
; EnableXP
; DPIAware