Procedure DepthAwareBlur_grayscale_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected total = lg * ht
  Protected *scr.Long
  Protected value, r, g, b, gray, i
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  
  For i = start To stop - 1
    *scr = *source + (i << 2)
    value = *scr\l
    
    ; Extraction rapide RGB
    r = (value >> 16) & 255
    g = (value >> 8) & 255
    b = value & 255
    
    ; Conversion en niveaux de gris (formule optimisée)
    gray = (r * 1225 + g * 2405 + b * 466) >> 12
    
    PokeA(*cible + i, gray)
  Next
EndProcedure

Procedure DepthAwareBlur_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *output = *param\addr[1]
  Protected *depthMap = *param\addr[2]
  Protected width   = *param\lg
  Protected height  = *param\ht
  
  Protected depthThreshold = *param\option[0]
  Protected radius         = *param\option[1]
  
  Protected x, y, dx, dy, sx, sy
  Protected r, g, b, count, col
  Protected r1, g1, b1
  Protected centerDepth, sampleDepth, dr
  Protected offset
  
  Protected start = (*param\thread_pos * height) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * height) / *param\thread_max
  
  ; Précalcul des limites
  Protected radiusNeg = -radius
  Protected heightLimit = height - 1
  Protected widthLimit = width - 1
  
  For y = start To stop - 1
    For x = 0 To widthLimit
      r = 0 : g = 0 : b = 0 : count = 0
      
      ; Profondeur du pixel central
      centerDepth = PeekA(*depthMap + (y * width + x))
      
      ; Balayage du voisinage
      For dy = radiusNeg To radius
        sy = y + dy
        If sy < 0 Or sy > heightLimit : Continue : EndIf
        
        For dx = radiusNeg To radius
          sx = x + dx
          If sx < 0 Or sx > widthLimit : Continue : EndIf
          
          ; Vérification de la différence de profondeur
          sampleDepth = PeekA(*depthMap + (sy * width + sx))
          dr = Abs(sampleDepth - centerDepth)
          If dr > depthThreshold : Continue : EndIf
          
          ; Lecture de la couleur source
          offset = (sy * width + sx) << 2
          col = PeekL(*source + offset)
          
          ; Extraction RGB
          r1 = (col >> 16) & 255
          g1 = (col >> 8) & 255
          b1 = col & 255
          
          r + r1
          g + g1
          b + b1
          count + 1
        Next
      Next
      
      ; Calcul de la moyenne et écriture du résultat
      If count > 0
        r / count
        g / count
        b / count
      Else
        ; Fallback: pixel original si aucun échantillon
        col = PeekL(*source + (y * width + x) << 2)
        r = (col >> 16) & 255
        g = (col >> 8) & 255
        b = col & 255
      EndIf
      
      ; Alpha à 255 (opaque)
      PokeL(*output + (y * width + x) << 2, $FF000000 | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure DepthAwareBlur(*param.parametre)
  If *param\info_active
    *param\name = "DepthAwareBlur"
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Optical
    *param\remarque = "Adoucit tout en conservant les contours nets"
    *param\info[0] = "Seuil de profondeur"
    *param\info[1] = "Rayon"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 255 : *param\info_data(0, 2) = 30
    *param\info_data(1, 0) = 1   : *param\info_data(1, 1) = 10  : *param\info_data(1, 2) = 3
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  ; Validation des paramètres
  Clamp(*param\option[0], 1, 255)
  Clamp(*param\option[1], 1, 10)
  
  ; Allocation de la carte de profondeur
  Protected *depthMap = AllocateMemory(*param\lg * *param\ht)
  If Not *depthMap : ProcedureReturn : EndIf
  
  ; Génération de la carte de profondeur (grayscale)
  *param\addr[0] = *param\source
  *param\addr[1] = *depthMap
  MultiThread_MT(@DepthAwareBlur_grayscale_MT())
  
  ; Application du flou conscient de la profondeur
  *param\addr[0] = *param\source
  *param\addr[1] = *param\cible
  *param\addr[2] = *depthMap
  MultiThread_MT(@DepthAwareBlur_MT())
  
  ; Application du masque si nécessaire
  If *param\mask And *param\option[2]
    *param\mask_type = *param\option[2] - 1
    MultiThread_MT(@_mask())
  EndIf
  
  ; Libération de la mémoire
  FreeMemory(*depthMap)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 151
; FirstLine = 82
; Folding = -
; EnableXP
; DPIAware