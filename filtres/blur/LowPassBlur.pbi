; ============================================================================
; PASSE 1 : Flou Passe-Bas Horizontal (Accumulateur Glissant O(1))
; ============================================================================
Procedure LowPassBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected kernelSize = \option[0]
    If kernelSize < 1 : kernelSize = 1 : EndIf
    
    Protected half = kernelSize
    Protected windowLen = half * 2 + 1
    Protected invWindow.f = 1.0 / windowLen
    
    Protected i, j, dx, px, oldX, newX, y_offset.i
    Protected a.l, r.l, g.l, b.l
    Protected sumA.l, sumR.l, sumG.l, sumB.l
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    
    macro_calul_tread(ht)
    
    For j = thread_start To thread_stop - 1
      y_offset = j * lg
      
      ; --- 1. Initialisation de la fenêtre pour x = 0 ---
      sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
      For dx = -half To half
        px = dx
        If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
        getargb(*src\l[y_offset + px], a, r, g, b)
        sumA + a : sumR + r : sumG + g : sumB + b
      Next
      
      ; --- 2. Fenêtre glissante O(1) le long de la ligne ---
      For i = 0 To lg - 1
        ; Écriture de la moyenne courante
        *tmp\l[y_offset + i] = (Int(sumA * invWindow) << 24) | (Int(sumR * invWindow) << 16) | (Int(sumG * invWindow) << 8) | Int(sumB * invWindow)
        
        ; Mise à jour O(1) : Retirer le pixel entrant à gauche, ajouter le pixel sortant à droite
        oldX = i - half
        If oldX < 0 : oldX = 0 : EndIf
        
        newX = i + half + 1
        If newX >= lg : newX = lg - 1 : EndIf
        
        getargb(*src\l[y_offset + oldX], a, r, g, b)
        sumA - a : sumR - r : sumG - g : sumB - b
        
        getargb(*src\l[y_offset + newX], a, r, g, b)
        sumA + a : sumR + r : sumG + g : sumB + b
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PASSE 2 : Flou Passe-Bas Vertical (Accumulateur Glissant O(1))
; ============================================================================
Procedure LowPassBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected kernelSize = \option[0]
    If kernelSize < 1 : kernelSize = 1 : EndIf
    
    Protected half = kernelSize
    Protected windowLen = half * 2 + 1
    Protected invWindow.f = 1.0 / windowLen
    
    Protected i, j, dy, py, oldY, newY
    Protected a.l, r.l, g.l, b.l
    Protected sumA.l, sumR.l, sumG.l, sumB.l
    
    Protected *tmp.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(lg) ; Multi-threading appliqué sur les colonnes
    
    For i = thread_start To thread_stop - 1
      ; --- 1. Initialisation de la fenêtre pour y = 0 ---
      sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
      For dy = -half To half
        py = dy
        If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
        getargb(*tmp\l[py * lg + i], a, r, g, b)
        sumA + a : sumR + r : sumG + g : sumB + b
      Next
      
      ; --- 2. Fenêtre glissante O(1) le long de la colonne ---
      For j = 0 To ht - 1
        ; Écriture du pixel final
        *dst\l[j * lg + i] = (Int(sumA * invWindow) << 24) | (Int(sumR * invWindow) << 16) | (Int(sumG * invWindow) << 8) | Int(sumB * invWindow)
        
        ; Mise à jour O(1)
        oldY = j - half
        If oldY < 0 : oldY = 0 : EndIf
        
        newY = j + half + 1
        If newY >= ht : newY = ht - 1 : EndIf
        
        getargb(*tmp\l[oldY * lg + i], a, r, g, b)
        sumA - a : sumR - r : sumG - g : sumB - b
        
        getargb(*tmp\l[newY * lg + i], a, r, g, b)
        sumA + a : sumR + r : sumG + g : sumB + b
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; LANCEUR PRINCIPAL ET ENVELOPPE PUBLIQUE
; ============================================================================
Procedure LowPassBlurEx(*FilterCtx.FilterParams)
  Restore LowPassBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  With *FilterCtx
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation du tampon temporaire \addr[2]
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@LowPassBlur_H_MT())
      Create_MultiThread_MT(@LowPassBlur_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure LowPassBlur(source, cible, mask, rayon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
  EndWith
  LowPassBlurEx(FilterCtx.FilterParams)
EndProcedure


DataSection
  LowPassBlur_data:
  Data.s "LowPassBlur"
  Data.s "Flou passe-bas optimisé par histogramme glissant"
  Data.i #FilterType_Blur
  Data.i #Blur_Gaussian
  
  Data.s "Rayon"
  Data.i 1, 100, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 144
; FirstLine = 101
; Folding = -
; EnableXP
; DPIAware