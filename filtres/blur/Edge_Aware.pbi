Procedure Edge_Aware_LoadImageToFloatArrays_MT(*param.parametre)
  Protected *source = *param\source
  Protected total = *param\lg * *param\ht
  Protected r, g, b, i, offset
  Protected rf.f, gf.f, bf.f
  Protected inv255.f = 1.0 / 255.0
  
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * total) / *param\thread_max
  
  For i = start To stop - 1
    offset = i << 2
    getrgb(PeekL(*source + offset), r, g, b)
    rf = r * inv255
    gf = g * inv255
    bf = b * inv255
    PokeF(*param\addr[0] + offset, rf)
    PokeF(*param\addr[1] + offset, gf)
    PokeF(*param\addr[2] + offset, bf)
  Next
EndProcedure

Procedure Edge_Aware_FloatArraysToLoadImage_MT(*param.parametre)
  Protected *cible = *param\cible
  Protected total = *param\lg * *param\ht
  Protected r.f, g.f, b.f
  Protected ri, gi, bi, i, offset
  
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * total) / *param\thread_max
  
  For i = start To stop - 1
    offset = i << 2
    r = (PeekF(*param\addr[0] + offset) * 255.0) + 0.5
    g = (PeekF(*param\addr[1] + offset) * 255.0) + 0.5
    b = (PeekF(*param\addr[2] + offset) * 255.0) + 0.5
    ri = r : gi = g : bi = b
    clamp_rgb(ri, gi, bi)
    PokeL(*cible + offset, (255 << 24) | (ri << 16) | (gi << 8) | bi)
  Next
EndProcedure

Procedure Edge_Aware_RecursiveFilter_H_MT(*param.parametre)
  Protected w = *param\lg
  Protected h = *param\ht
  Protected sigma_s.f = *param\option[5]  ; Sigma spatial pour cette itération
  Protected sigma_r.f = *param\option[6]  ; Sigma range (couleur)
  
  If sigma_s <= 0.0 : sigma_s = 1.0 : EndIf
  If sigma_r <= 0.0 : sigma_r = 0.1 : EndIf
  
  Protected a.f = Exp(-Sqr(2.0) / sigma_s)  ; Coefficient de récursion
  Protected inv_sigma_r.f = 1.0 / sigma_r
  
  Protected start = (*param\thread_pos * h) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * h) / *param\thread_max
  
  Protected x, y, idx, prevIdx, offset, prevOffset
  Protected r0.f, g0.f, b0.f, r1.f, g1.f, b1.f
  Protected diff.f, weight.f
  Protected wMinus1 = w - 1
  
  ; Buffer temporaire pour la ligne
  Protected *tempR = AllocateMemory(w << 2)
  Protected *tempG = AllocateMemory(w << 2)
  Protected *tempB = AllocateMemory(w << 2)
  
  If Not *tempR Or Not *tempG Or Not *tempB
    If *tempR : FreeMemory(*tempR) : EndIf
    If *tempG : FreeMemory(*tempG) : EndIf
    If *tempB : FreeMemory(*tempB) : EndIf
    ProcedureReturn
  EndIf
  
  For y = start To stop - 1
    ; Charger la ligne
    For x = 0 To wMinus1
      idx = y * w + x
      offset = idx << 2
      PokeF(*tempR + (x << 2), PeekF(*param\addr[0] + offset))
      PokeF(*tempG + (x << 2), PeekF(*param\addr[1] + offset))
      PokeF(*tempB + (x << 2), PeekF(*param\addr[2] + offset))
    Next
    
    ; Passe gauche vers droite
    For x = 1 To wMinus1
      offset = x << 2
      prevOffset = (x - 1) << 2
      
      r0 = PeekF(*tempR + offset)
      g0 = PeekF(*tempG + offset)
      b0 = PeekF(*tempB + offset)
      r1 = PeekF(*tempR + prevOffset)
      g1 = PeekF(*tempG + prevOffset)
      b1 = PeekF(*tempB + prevOffset)
      
      ; Différence de couleur
      diff = Sqr((r0 - r1) * (r0 - r1) + (g0 - g1) * (g0 - g1) + (b0 - b1) * (b0 - b1))
      weight = a * Exp(-diff * inv_sigma_r)
      
      PokeF(*tempR + offset, r0 + weight * (r1 - r0))
      PokeF(*tempG + offset, g0 + weight * (g1 - g0))
      PokeF(*tempB + offset, b0 + weight * (b1 - b0))
    Next
    
    ; Passe droite vers gauche
    For x = wMinus1 - 1 To 0 Step -1
      offset = x << 2
      prevOffset = (x + 1) << 2
      
      r0 = PeekF(*tempR + offset)
      g0 = PeekF(*tempG + offset)
      b0 = PeekF(*tempB + offset)
      r1 = PeekF(*tempR + prevOffset)
      g1 = PeekF(*tempG + prevOffset)
      b1 = PeekF(*tempB + prevOffset)
      
      diff = Sqr((r0 - r1) * (r0 - r1) + (g0 - g1) * (g0 - g1) + (b0 - b1) * (b0 - b1))
      weight = a * Exp(-diff * inv_sigma_r)
      
      PokeF(*tempR + offset, r0 + weight * (r1 - r0))
      PokeF(*tempG + offset, g0 + weight * (g1 - g0))
      PokeF(*tempB + offset, b0 + weight * (b1 - b0))
    Next
    
    ; Sauvegarder la ligne filtrée
    For x = 0 To wMinus1
      idx = y * w + x
      offset = idx << 2
      r0 = PeekF(*tempR + (x << 2))
      g0 = PeekF(*tempG + (x << 2))
      b0 = PeekF(*tempB + (x << 2))
      clamp(r0, 0, 1)
      clamp(g0, 0, 1)
      clamp(b0, 0, 1)
      PokeF(*param\addr[0] + offset, r0)
      PokeF(*param\addr[1] + offset, g0)
      PokeF(*param\addr[2] + offset, b0)
    Next
  Next
  
  FreeMemory(*tempR)
  FreeMemory(*tempG)
  FreeMemory(*tempB)
EndProcedure

Procedure Edge_Aware_RecursiveFilter_V_MT(*param.parametre)
  Protected w = *param\lg
  Protected h = *param\ht
  Protected sigma_s.f = *param\option[5]
  Protected sigma_r.f = *param\option[6]
  
  If sigma_s <= 0.0 : sigma_s = 1.0 : EndIf
  If sigma_r <= 0.0 : sigma_r = 0.1 : EndIf
  
  Protected a.f = Exp(-Sqr(2.0) / sigma_s)
  Protected inv_sigma_r.f = 1.0 / sigma_r
  
  Protected start = (*param\thread_pos * w) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * w) / *param\thread_max
  
  Protected x, y, idx, prevIdx, offset, prevOffset
  Protected r0.f, g0.f, b0.f, r1.f, g1.f, b1.f
  Protected diff.f, weight.f
  Protected hMinus1 = h - 1
  
  ; Buffer temporaire pour la colonne
  Protected *tempR = AllocateMemory(h << 2)
  Protected *tempG = AllocateMemory(h << 2)
  Protected *tempB = AllocateMemory(h << 2)
  
  If Not *tempR Or Not *tempG Or Not *tempB
    If *tempR : FreeMemory(*tempR) : EndIf
    If *tempG : FreeMemory(*tempG) : EndIf
    If *tempB : FreeMemory(*tempB) : EndIf
    ProcedureReturn
  EndIf
  
  For x = start To stop - 1
    ; Charger la colonne
    For y = 0 To hMinus1
      idx = y * w + x
      offset = idx << 2
      PokeF(*tempR + (y << 2), PeekF(*param\addr[0] + offset))
      PokeF(*tempG + (y << 2), PeekF(*param\addr[1] + offset))
      PokeF(*tempB + (y << 2), PeekF(*param\addr[2] + offset))
    Next
    
    ; Passe haut vers bas
    For y = 1 To hMinus1
      offset = y << 2
      prevOffset = (y - 1) << 2
      
      r0 = PeekF(*tempR + offset)
      g0 = PeekF(*tempG + offset)
      b0 = PeekF(*tempB + offset)
      r1 = PeekF(*tempR + prevOffset)
      g1 = PeekF(*tempG + prevOffset)
      b1 = PeekF(*tempB + prevOffset)
      
      diff = Sqr((r0 - r1) * (r0 - r1) + (g0 - g1) * (g0 - g1) + (b0 - b1) * (b0 - b1))
      weight = a * Exp(-diff * inv_sigma_r)
      
      PokeF(*tempR + offset, r0 + weight * (r1 - r0))
      PokeF(*tempG + offset, g0 + weight * (g1 - g0))
      PokeF(*tempB + offset, b0 + weight * (b1 - b0))
    Next
    
    ; Passe bas vers haut
    For y = hMinus1 - 1 To 0 Step -1
      offset = y << 2
      prevOffset = (y + 1) << 2
      
      r0 = PeekF(*tempR + offset)
      g0 = PeekF(*tempG + offset)
      b0 = PeekF(*tempB + offset)
      r1 = PeekF(*tempR + prevOffset)
      g1 = PeekF(*tempG + prevOffset)
      b1 = PeekF(*tempB + prevOffset)
      
      diff = Sqr((r0 - r1) * (r0 - r1) + (g0 - g1) * (g0 - g1) + (b0 - b1) * (b0 - b1))
      weight = a * Exp(-diff * inv_sigma_r)
      
      PokeF(*tempR + offset, r0 + weight * (r1 - r0))
      PokeF(*tempG + offset, g0 + weight * (g1 - g0))
      PokeF(*tempB + offset, b0 + weight * (b1 - b0))
    Next
    
    ; Sauvegarder la colonne filtrée
    For y = 0 To hMinus1
      idx = y * w + x
      offset = idx << 2
      r0 = PeekF(*tempR + (y << 2))
      g0 = PeekF(*tempG + (y << 2))
      b0 = PeekF(*tempB + (y << 2))
      clamp(r0, 0, 1)
      clamp(g0, 0, 1)
      clamp(b0, 0, 1)
      PokeF(*param\addr[0] + offset, r0)
      PokeF(*param\addr[1] + offset, g0)
      PokeF(*param\addr[2] + offset, b0)
    Next
  Next
  
  FreeMemory(*tempR)
  FreeMemory(*tempG)
  FreeMemory(*tempB)
EndProcedure

Procedure Edge_Aware(*param.parametre)
  If *param\info_active
    *param\name = "Edge_Aware"
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_EdgeAware
    *param\remarque = "Lisse sans détruire les contours"
    *param\info[0] = "Rayon spatial"
    *param\info[1] = "Préservation contours"
    *param\info[2] = "Nombre de passes"
    *param\info[3] = "Masque"
    *param\info_data(0,0) = 1   : *param\info_data(0,1) = 100  : *param\info_data(0,2) = 20
    *param\info_data(1,0) = 1   : *param\info_data(1,1) = 100  : *param\info_data(1,2) = 20
    *param\info_data(2,0) = 1   : *param\info_data(2,1) = 10   : *param\info_data(2,2) = 3
    *param\info_data(3,0) = 0   : *param\info_data(3,1) = 2    : *param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected size = lg * ht << 2
  
  *param\addr[0] = AllocateMemory(size)
  *param\addr[1] = AllocateMemory(size)
  *param\addr[2] = AllocateMemory(size)
  
  If Not *param\addr[0] Or Not *param\addr[1] Or Not *param\addr[2]
    Debug "Erreur allocation mémoire Edge_Aware"
    If *param\addr[0] : FreeMemory(*param\addr[0]) : EndIf
    If *param\addr[1] : FreeMemory(*param\addr[1]) : EndIf
    If *param\addr[2] : FreeMemory(*param\addr[2]) : EndIf
    ProcedureReturn
  EndIf
  
  ; Charger l'image en floats normalisés
  MultiThread_MT(@Edge_Aware_LoadImageToFloatArrays_MT())
  
  ; Paramètres
  Protected iterations = *param\option[2]
  Protected sigma_s.f = *param\option[0]  ; Rayon spatial (1-100)
  Protected sigma_r.f = *param\option[1] * 0.01  ; Préservation contours (0.01-1.0)
  
  Clamp(iterations, 1, 10)
  Clamp(sigma_s, 1.0, 100.0)
  Clamp(sigma_r, 0.01, 1.0)
  
  Protected i
  For i = 1 To iterations
    ; Calculer sigma_s pour cette itération (décroissance progressive)
    *param\option[5] = sigma_s * Pow(0.5, i - 1)
    *param\option[6] = sigma_r
    
    ; Filtrage horizontal puis vertical
    MultiThread_MT(@Edge_Aware_RecursiveFilter_H_MT())
    MultiThread_MT(@Edge_Aware_RecursiveFilter_V_MT())
  Next
  
  ; Convertir les floats en image
  MultiThread_MT(@Edge_Aware_FloatArraysToLoadImage_MT())
  
  ; Appliquer le masque si nécessaire
  If *param\mask And *param\option[3]
    *param\mask_type = *param\option[3] - 1
    MultiThread_MT(@_mask())
  EndIf
  
  FreeMemory(*param\addr[0])
  FreeMemory(*param\addr[1])
  FreeMemory(*param\addr[2])
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 319
; FirstLine = 250
; Folding = -
; EnableXP
; DPIAware