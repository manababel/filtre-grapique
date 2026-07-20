; ============================================================================
; PASSE 1 : Direction Horizontale Glissante (*src -> *tmp)
; ============================================================================
Procedure OilPaintBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected intensityLevels = \option[1]
    
    If radius < 1 : radius = 1 : EndIf
    If intensityLevels < 2 : intensityLevels = 2 : ElseIf intensityLevels > 64 : intensityLevels = 64 : EndIf
    
    Protected x, y, dx, px, px_add, px_remove
    Protected r, g, b, a, intensity, intensityBin, binOffset
    Protected i, y_offset.i, maxCount, maxBin
    
    Protected Dim hist.l(324)
    Protected histBytes = intensityLevels * 5 * 4
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      y_offset = y * lg
      
      ; --- 1. Initialiser la fenêtre glissante au début de la ligne (x = 0) ---
      FillMemory(@hist(0), histBytes, 0)
      
      For dx = -radius To radius
        px = dx
        If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
        
        getargb(*src\l[y_offset + px], a, r, g, b)
        intensityBin = (((r * 77 + g * 150 + b * 29) >> 8) * intensityLevels) >> 8
        If intensityBin >= intensityLevels : intensityBin = intensityLevels - 1 : EndIf
        
        binOffset = intensityBin * 5
        hist(binOffset) + 1     ; Count
        hist(binOffset + 1) + r ; R
        hist(binOffset + 2) + g ; G
        hist(binOffset + 3) + b ; B
        hist(binOffset + 4) + a ; A
      Next
      
      ; --- 2. Parcourir la ligne avec la fenêtre glissante ---
      For x = 0 To lg - 1
        ; Si on n'est pas au tout premier pixel, mettre à jour l'histogramme de manière delta (O(1))
        If x > 0
          ; Pixel sortant (à gauche)
          px_remove = x - 1 - radius
          If px_remove < 0 : px_remove = 0 : EndIf
          
          getargb(*src\l[y_offset + px_remove], a, r, g, b)
          intensityBin = (((r * 77 + g * 150 + b * 29) >> 8) * intensityLevels) >> 8
          If intensityBin >= intensityLevels : intensityBin = intensityLevels - 1 : EndIf
          
          binOffset = intensityBin * 5
          hist(binOffset) - 1
          hist(binOffset + 1) - r
          hist(binOffset + 2) - g
          hist(binOffset + 3) - b
          hist(binOffset + 4) - a
          
          ; Pixel entrant (à droite)
          px_add = x + radius
          If px_add >= lg : px_add = lg - 1 : EndIf
          
          getargb(*src\l[y_offset + px_add], a, r, g, b)
          intensityBin = (((r * 77 + g * 150 + b * 29) >> 8) * intensityLevels) >> 8
          If intensityBin >= intensityLevels : intensityBin = intensityLevels - 1 : EndIf
          
          binOffset = intensityBin * 5
          hist(binOffset) + 1
          hist(binOffset + 1) + r
          hist(binOffset + 2) + g
          hist(binOffset + 3) + b
          hist(binOffset + 4) + a
        EndIf
        
        ; Trouver le bin le plus fréquent
        maxCount = 0 : maxBin = 0
        For i = 0 To intensityLevels - 1
          binOffset = i * 5
          If hist(binOffset) > maxCount
            maxCount = hist(binOffset)
            maxBin = i
          EndIf
        Next
        
        If maxCount > 0
          binOffset = maxBin * 5
          r = hist(binOffset + 1) / maxCount
          g = hist(binOffset + 2) / maxCount
          b = hist(binOffset + 3) / maxCount
          a = hist(binOffset + 4) / maxCount
          *tmp\l[y_offset + x] = (a << 24) | (r << 16) | (g << 8) | b
        Else
          *tmp\l[y_offset + x] = *src\l[y_offset + x]
        EndIf
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PASSE 2 : Direction Verticale Glissante (*tmp -> *dst)
; ============================================================================
Procedure OilPaintBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected intensityLevels = \option[1]
    
    If radius < 1 : radius = 1 : EndIf
    If intensityLevels < 2 : intensityLevels = 2 : ElseIf intensityLevels > 64 : intensityLevels = 64 : EndIf
    
    Protected x, y, dy, py, py_add, py_remove
    Protected r, g, b, a, intensityBin, binOffset
    Protected i, maxCount, maxBin
    
    Protected Dim hist.l(324)
    Protected histBytes = intensityLevels * 5 * 4
    
    Protected *tmp.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(ht)
    
    ; Traitement colonne par colonne par thread pour glisser verticalement
    For x = 0 To lg - 1
      ; --- 1. Initialiser la fenêtre glissante en haut de la colonne (y = thread_start) ---
      FillMemory(@hist(0), histBytes, 0)
      
      For dy = -radius To radius
        py = thread_start + dy
        If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
        
        getargb(*tmp\l[py * lg + x], a, r, g, b)
        intensityBin = (((r * 77 + g * 150 + b * 29) >> 8) * intensityLevels) >> 8
        If intensityBin >= intensityLevels : intensityBin = intensityLevels - 1 : EndIf
        
        binOffset = intensityBin * 5
        hist(binOffset) + 1     ; Count
        hist(binOffset + 1) + r ; R
        hist(binOffset + 2) + g ; G
        hist(binOffset + 3) + b ; B
        hist(binOffset + 4) + a ; A
      Next
      
      ; --- 2. Parcourir la colonne de thread_start à thread_stop - 1 ---
      For y = thread_start To thread_stop - 1
        If y > thread_start
          ; Pixel sortant (en haut)
          py_remove = y - 1 - radius
          If py_remove < 0 : py_remove = 0 : EndIf
          
          getargb(*tmp\l[py_remove * lg + x], a, r, g, b)
          intensityBin = (((r * 77 + g * 150 + b * 29) >> 8) * intensityLevels) >> 8
          If intensityBin >= intensityLevels : intensityBin = intensityLevels - 1 : EndIf
          
          binOffset = intensityBin * 5
          hist(binOffset) - 1
          hist(binOffset + 1) - r
          hist(binOffset + 2) - g
          hist(binOffset + 3) - b
          hist(binOffset + 4) - a
          
          ; Pixel entrant (en bas)
          py_add = y + radius
          If py_add >= ht : py_add = ht - 1 : EndIf
          
          getargb(*tmp\l[py_add * lg + x], a, r, g, b)
          intensityBin = (((r * 77 + g * 150 + b * 29) >> 8) * intensityLevels) >> 8
          If intensityBin >= intensityLevels : intensityBin = intensityLevels - 1 : EndIf
          
          binOffset = intensityBin * 5
          hist(binOffset) + 1
          hist(binOffset + 1) + r
          hist(binOffset + 2) + g
          hist(binOffset + 3) + b
          hist(binOffset + 4) + a
        EndIf
        
        ; Trouver le bin le plus fréquent
        maxCount = 0 : maxBin = 0
        For i = 0 To intensityLevels - 1
          binOffset = i * 5
          If hist(binOffset) > maxCount
            maxCount = hist(binOffset)
            maxBin = i
          EndIf
        Next
        
        If maxCount > 0
          binOffset = maxBin * 5
          r = hist(binOffset + 1) / maxCount
          g = hist(binOffset + 2) / maxCount
          b = hist(binOffset + 3) / maxCount
          a = hist(binOffset + 4) / maxCount
          *dst\l[y * lg + x] = (a << 24) | (r << 16) | (g << 8) | b
        Else
          *dst\l[y * lg + x] = *tmp\l[y * lg + x]
        EndIf
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; EXÉCUTION DU FILTRE (GESTION MULTITHREAD & TAMPON)
; ============================================================================
Procedure OilPaintBlurEx(*FilterCtx.FilterParams)
  Restore OilPaintBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    If \option[0] < 1 : \option[0] = 1 : ElseIf \option[0] > 15 : \option[0] = 15 : EndIf
    If \option[1] < 2 : \option[1] = 2 : ElseIf \option[1] > 64 : \option[1] = 64 : EndIf
    
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation du tampon temporaire \addr[2]
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@OilPaintBlur_H_MT())
      Create_MultiThread_MT(@OilPaintBlur_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure OilPaintBlur(source, cible, mask, rayon, intensite)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = intensite
  EndWith
  OilPaintBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  OilPaintBlur_data:
  Data.s "OilPaintBlur"
  Data.s "Effet peinture à l'huile"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Rayon"
  Data.i 1, 15, 5
  Data.s "Niveaux d'intensité"
  Data.i 2, 64, 20
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 208
; FirstLine = 153
; Folding = -
; EnableXP
; DPIAware