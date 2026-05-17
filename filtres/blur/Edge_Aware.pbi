; --- Procédures MT de conversion ---

Procedure Edge_Aware_LoadImageToFloatArrays_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0] ; On utilise l'adresse source passée par le cycle
    Protected total = \image_lg[0] * \image_ht[0]
    Protected r, g, b, i, offset
    Protected inv255.f = 1.0 / 255.0
    
    macro_calul_tread(total)
    
    For i = thread_start To thread_stop - 1
      offset = i << 2
      getrgb(PeekL(*source + offset), r, g, b)
      PokeF(\addr[3] + offset, r * inv255)
      PokeF(\addr[4] + offset, g * inv255)
      PokeF(\addr[5] + offset, b * inv255)
    Next
  EndWith
EndProcedure

Procedure Edge_Aware_FloatArraysToLoadImage_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *cible = \addr[1]
    Protected total = \image_lg[0] * \image_ht[0]
    Protected r.f, g.f, b.f
    Protected ri, gi, bi, i, offset
    
    macro_calul_tread(total)
    
    For i = thread_start To thread_stop - 1
      offset = i << 2
      ri = (PeekF(\addr[3] + offset) * 255.0) + 0.5
      gi = (PeekF(\addr[4] + offset) * 255.0) + 0.5
      bi = (PeekF(\addr[5] + offset) * 255.0) + 0.5
      clamp_rgb(ri, gi, bi)
      PokeL(*cible + offset, (255 << 24) | (ri << 16) | (gi << 8) | bi)
    Next
  EndWith
EndProcedure

; --- Procédures MT de Filtrage ---

Procedure Edge_Aware_RecursiveFilter_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected sigma_s.f = \option[5]
    Protected sigma_r.f = \option[6]
    Protected a.f = Exp(-Sqr(2.0) / sigma_s)
    Protected inv_sigma_r.f = 1.0 / sigma_r
    Protected wMinus1 = w - 1
    Protected x, y, idx, prevIdx, offset, prevOffset
    Protected r0.f, g0.f, b0.f, r1.f, g1.f, b1.f
    Protected diff.f, weight.f
    
    macro_calul_tread(h)
    
    Protected *tempR = AllocateMemory(w << 2)
    Protected *tempG = AllocateMemory(w << 2)
    Protected *tempB = AllocateMemory(w << 2)
    
    For y = thread_start To thread_stop - 1
      ; Charger ligne
      For x = 0 To wMinus1
        idx = y * w + x : offset = idx << 2
        PokeF(*tempR + (x << 2), PeekF(\addr[3] + offset))
        PokeF(*tempG + (x << 2), PeekF(\addr[4] + offset))
        PokeF(*tempB + (x << 2), PeekF(\addr[5] + offset))
      Next
      
      ; Gauche -> Droite
      For x = 1 To wMinus1
        offset = x << 2 : prevOffset = (x - 1) << 2
        r0 = PeekF(*tempR + offset) : g0 = PeekF(*tempG + offset) : b0 = PeekF(*tempB + offset)
        r1 = PeekF(*tempR + prevOffset) : g1 = PeekF(*tempG + prevOffset) : b1 = PeekF(*tempB + prevOffset)
        diff = Sqr((r0-r1)*(r0-r1) + (g0-g1)*(g0-g1) + (b0-b1)*(b0-b1))
        weight = a * Exp(-diff * inv_sigma_r)
        PokeF(*tempR + offset, r0 + weight * (r1 - r0))
        PokeF(*tempG + offset, g0 + weight * (g1 - g0))
        PokeF(*tempB + offset, b0 + weight * (b1 - b0))
      Next
      
      ; Droite -> Gauche
      For x = wMinus1 - 1 To 0 Step -1
        offset = x << 2 : prevOffset = (x + 1) << 2
        r0 = PeekF(*tempR + offset) : g0 = PeekF(*tempG + offset) : b0 = PeekF(*tempB + offset)
        r1 = PeekF(*tempR + prevOffset) : g1 = PeekF(*tempG + prevOffset) : b1 = PeekF(*tempB + prevOffset)
        diff = Sqr((r0-r1)*(r0-r1) + (g0-g1)*(g0-g1) + (b0-b1)*(b0-b1))
        weight = a * Exp(-diff * inv_sigma_r)
        PokeF(*tempR + offset, r0 + weight * (r1 - r0))
        PokeF(*tempG + offset, g0 + weight * (g1 - g0))
        PokeF(*tempB + offset, b0 + weight * (b1 - b0))
      Next
      
      ; Sauvegarder
      For x = 0 To wMinus1
        idx = y * w + x : offset = idx << 2
        PokeF(\addr[3] + offset, PeekF(*tempR + (x << 2)))
        PokeF(\addr[4] + offset, PeekF(*tempG + (x << 2)))
        PokeF(\addr[5] + offset, PeekF(*tempB + (x << 2)))
      Next
    Next
    FreeMemory(*tempR) : FreeMemory(*tempG) : FreeMemory(*tempB)
  EndWith
EndProcedure

Procedure Edge_Aware_RecursiveFilter_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected sigma_s.f = \option[5]
    Protected sigma_r.f = \option[6]
    Protected a.f = Exp(-Sqr(2.0) / sigma_s)
    Protected inv_sigma_r.f = 1.0 / sigma_r

  Protected x, y, idx, prevIdx, offset, prevOffset
  Protected r0.f, g0.f, b0.f, r1.f, g1.f, b1.f
  Protected diff.f, weight.f
  Protected hMinus1 = h - 1
    macro_calul_tread(w)
    
    Protected *tempR = AllocateMemory(h << 2)
    Protected *tempG = AllocateMemory(h << 2)
    Protected *tempB = AllocateMemory(h << 2)
    
    For x = thread_start To thread_stop - 1
      ; Charger colonne
      For y = 0 To hMinus1
        idx = y * w + x : offset = idx << 2
        PokeF(*tempR + (y << 2), PeekF(\addr[3] + offset))
        PokeF(*tempG + (y << 2), PeekF(\addr[4] + offset))
        PokeF(*tempB + (y << 2), PeekF(\addr[5] + offset))
      Next
      
      ; Haut -> Bas
      For y = 1 To hMinus1
        offset = y << 2 : prevOffset = (y - 1) << 2
        r0 = PeekF(*tempR + offset) : g0 = PeekF(*tempG + offset) : b0 = PeekF(*tempB + offset)
        r1 = PeekF(*tempR + prevOffset) : g1 = PeekF(*tempG + prevOffset) : b1 = PeekF(*tempB + prevOffset)
        diff = Sqr((r0-r1)*(r0-r1) + (g0-g1)*(g0-g1) + (b0-b1)*(b0-b1))
        weight = a * Exp(-diff * inv_sigma_r)
        PokeF(*tempR + offset, r0 + weight * (r1 - r0))
        PokeF(*tempG + offset, g0 + weight * (g1 - g0))
        PokeF(*tempB + offset, b0 + weight * (b1 - b0))
      Next
      
      ; Bas -> Haut
      For y = hMinus1 - 1 To 0 Step -1
        offset = y << 2 : prevOffset = (y + 1) << 2
        r0 = PeekF(*tempR + offset) : g0 = PeekF(*tempG + offset) : b0 = PeekF(*tempB + offset)
        r1 = PeekF(*tempR + prevOffset) : g1 = PeekF(*tempG + prevOffset) : b1 = PeekF(*tempB + prevOffset)
        diff = Sqr((r0-r1)*(r0-r1) + (g0-g1)*(g0-g1) + (b0-b1)*(b0-b1))
        weight = a * Exp(-diff * inv_sigma_r)
        PokeF(*tempR + offset, r0 + weight * (r1 - r0))
        PokeF(*tempG + offset, g0 + weight * (g1 - g0))
        PokeF(*tempB + offset, b0 + weight * (b1 - b0))
      Next
      
      ; Sauvegarder
      For y = 0 To hMinus1
        idx = y * w + x : offset = idx << 2
        PokeF(\addr[3] + offset, PeekF(*tempR + (y << 2)))
        PokeF(\addr[4] + offset, PeekF(*tempG + (y << 2)))
        PokeF(\addr[5] + offset, PeekF(*tempB + (y << 2)))
      Next
    Next
    FreeMemory(*tempR) : FreeMemory(*tempG) : FreeMemory(*tempB)
  EndWith
EndProcedure

; --- Cycle principal ---

Procedure Edge_AwareEx(*FilterCtx.FilterParams)
  Restore Edge_Aware_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected size = \image_lg[0] * \image_ht[0] << 2
    \addr[3] = AllocateMemory(size) ; Buffer R float
    \addr[4] = AllocateMemory(size) ; Buffer G float
    \addr[5] = AllocateMemory(size) ; Buffer B float
    
    If Not \addr[3] Or Not \addr[4] Or Not \addr[5]
      If \addr[3] : FreeMemory(\addr[3]) : EndIf
      If \addr[4] : FreeMemory(\addr[4]) : EndIf
      If \addr[5] : FreeMemory(\addr[5]) : EndIf
      ProcedureReturn 0
    EndIf
    
    ; 1. Vers Float
    Create_MultiThread_MT(@Edge_Aware_LoadImageToFloatArrays_MT())
    
    ; 2. Filtrage
    Protected i, iterations = \option[2]
    Protected sigma_s.f = \option[0]
    Protected sigma_r.f = \option[1] * 0.01
    
    For i = 1 To iterations
      \option[5] = sigma_s * Pow(0.5, i - 1)
      \option[6] = sigma_r
      Create_MultiThread_MT(@Edge_Aware_RecursiveFilter_H_MT())
      Create_MultiThread_MT(@Edge_Aware_RecursiveFilter_V_MT())
    Next
    
    ; 3. Retour vers Image
    Create_MultiThread_MT(@Edge_Aware_FloatArraysToLoadImage_MT())
    
    ; Nettoyage
    FreeMemory(\addr[3]) : FreeMemory(\addr[4]) : FreeMemory(\addr[5])
    \addr[3] = 0 : \addr[4] = 0 : \addr[5] = 0
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Edge_Aware(source, cible, mask, sigma_s, sigma_r, iterations)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = sigma_s
    \option[1] = sigma_r
    \option[2] = iterations
  EndWith
  Edge_AwareEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Edge_Aware_data:
  Data.s "Edge_Aware"
  Data.s "Lissage récursif avec préservation des contours"
  Data.i #FilterType_Blur
  Data.i #Blur_EdgeAware
  Data.s "Rayon spatial"
  Data.i 1, 100, 20
  Data.s "Contraste (%)"
  Data.i 1, 100, 20
  Data.s "Passes"
  Data.i 1, 10, 3
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 115
; FirstLine = 98
; Folding = --
; EnableXP
; DPIAware