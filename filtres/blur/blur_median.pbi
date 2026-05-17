; ---------------------------------------------------
; MedianBlur - Version optimisée
; Filtre médian avec fenêtre glissante
; ---------------------------------------------------

; --- Macro pour ajouter/retirer un pixel de l'histogramme ---
Macro MedianBlur_UpdateHist(op)
  value = PeekL(*FilterCtx\addr[0] + index)
  a = (value >> 24) & $FF
  r = (value >> 16) & $FF
  g = (value >> 8) & $FF
  b = value & $FF
  histA(a) op 1
  yl = (77 * r + 150 * g + 29 * b) >> 8
  histY(yl) op 1
EndMacro

; --- Macro pour trouver la médiane ---
Macro MedianBlur_FindMedian(hist, result)
  sum = 0
  result = 0
  For i = 0 To 255
    sum + hist(i)
    If sum >= medianThreshold
      result = i
      Break
    EndIf
  Next
EndMacro

; --- Procédure principale (multithreadée) ---
Procedure MedianBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected kernelSize = \option[0]
    
    If kernelSize < 1 : kernelSize = 1 : EndIf
    kernelSize = (kernelSize << 1) + 1
    
    Protected half = kernelSize >> 1
    Protected kernelArea = kernelSize * kernelSize
    Protected medianThreshold = (kernelArea >> 1) + 1
    
    ; Histogrammes locaux pour ce thread
    Dim histA.l(255)
    Dim histY.l(255)
    
    Protected x, y, dx, dy, px, py, index
    Protected value, r, g, b, a, i, sum, yl
    Protected medianA, medianY
    Protected oldX, newX
    Protected cb, cr
    Protected lgMinus1 = lg - 1
    Protected htMinus1 = ht - 1
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      ; Réinitialiser les histogrammes
      FillMemory(@histA(), 1024, 0)
      FillMemory(@histY(), 1024, 0)
      
      ; Initialisation de la fenêtre pour x = 0
      For dy = -half To half
        py = y + dy
        If py < 0 : py = 0 : ElseIf py > htMinus1 : py = htMinus1 : EndIf
        
        For dx = -half To half
          px = dx
          If px < 0 : px = 0 : ElseIf px > lgMinus1 : px = lgMinus1 : EndIf
          
          index = (py * lg + px) << 2
          MedianBlur_UpdateHist(+)
        Next
      Next
      
      ; Parcours horizontal avec fenêtre glissante
      For x = 0 To lgMinus1
        ; Trouver les médianes
        MedianBlur_FindMedian(histA, medianA)
        MedianBlur_FindMedian(histY, medianY)
        
        ; Récupérer la chrominance du pixel original
        index = (y * lg + x) << 2
        value = PeekL(\addr[0] + index)
        r = (value >> 16) & $FF
        g = (value >> 8) & $FF
        b = value & $FF
        
        ; Convertir en YCbCr
        cb = ((-43 * r - 85 * g + 128 * b) >> 8)
        cr = ((128 * r - 107 * g - 21 * b) >> 8)
        
        ; Reconstruire RGB avec luminance médiane
        r = medianY + ((358 * cr) >> 8)
        g = medianY - ((88 * cb + 183 * cr) >> 8)
        b = medianY + ((454 * cb) >> 8)
        
        ; Clamping
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        
        ; Écrire le résultat
        PokeL(\addr[1] + index, (medianA << 24) | (r << 16) | (g << 8) | b)
        
        ; Mise à jour glissante de la fenêtre
        If x < lgMinus1
          oldX = x - half
          If oldX < 0 : oldX = 0 : EndIf
          
          newX = x + half + 1
          If newX > lgMinus1 : newX = lgMinus1 : EndIf
          
          For dy = -half To half
            py = y + dy
            If py < 0 : py = 0 : ElseIf py > htMinus1 : py = htMinus1 : EndIf
            
            ; Retirer l'ancienne colonne
            index = (py * lg + oldX) << 2
            MedianBlur_UpdateHist(-)
            
            ; Ajouter la nouvelle colonne
            index = (py * lg + newX) << 2
            MedianBlur_UpdateHist(+)
          Next
        EndIf
      Next
    Next
    
    FreeArray(histA())
    FreeArray(histY())
  EndWith
EndProcedure

Procedure MedianBlurEx(*FilterCtx.FilterParams)
  Restore MedianBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@MedianBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure MedianBlur(source, cible, mask, radius, mask_type)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = mask_type
  EndWith
  MedianBlurEx(FilterCtx)
EndProcedure

DataSection
  MedianBlur_data:
  Data.s "MedianBlur"
  Data.s "Filtre médian préservant les contours"
  Data.i #FilterType_Blur, #Blur_Adaptive
  Data.s "Rayon"
  Data.i 1, 50, 3    ; Rayon
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 7
; Folding = -
; EnableXP
; DPIAware