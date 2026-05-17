; ---------------------------------------------------
; Rolling Guidance Filter - Version Optimisée
; Filtre de lissage avec préservation des bords
; ---------------------------------------------------

; --- Worker Thread : Bilateral Filter Guidé ---
Procedure RollingGuidance_Worker(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0], h = \image_ht[0]
    Protected radius = \option[0], sigmaColor = \option[1]
    Protected x, y, dx, dy, px, py, idx, idx2
    Protected r0, g0, b0, r, g, b
    Protected sumR.d, sumG.d, sumB.d, sumA.d, sumW.d
    Protected dColor.d, wColor.d, wSpace.d, wTot.d
    Protected invSigma2.d = 1.0 / (sigmaColor * sigmaColor)
    Protected invRadiusSq.d = 1.0 / (radius * radius)
    Protected w_minus_1 = w - 1, h_minus_1 = h - 1
    Protected *src = \addr[0], *guide = \addr[2], *dst = \addr[1]

    macro_calul_tread(h)

    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        idx = (y * w + x) * 4
        
        ; Guide pixel (depuis l'itération précédente ou le flou initial)
        r0 = PeekA(*guide + idx + 2)
        g0 = PeekA(*guide + idx + 1)
        b0 = PeekA(*guide + idx)
        
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : sumW = 0.0
        
        For dy = -radius To radius
          py = y + dy
          If py < 0 : py = 0 : ElseIf py > h_minus_1 : py = h_minus_1 : EndIf
          
          For dx = -radius To radius
            px = x + dx
            If px < 0 : px = 0 : ElseIf px > w_minus_1 : px = w_minus_1 : EndIf
            
            idx2 = (py * w + px) * 4
            r = PeekA(*src + idx2 + 2)
            g = PeekA(*src + idx2 + 1)
            b = PeekA(*src + idx2)
            
            ; Distance couleur par rapport au GUIDE
            dColor = (r0-r)*(r0-r) + (g0-g)*(g0-g) + (b0-b)*(b0-b)
            
            wColor = Exp(-dColor * invSigma2)
            wSpace = Exp(-(dx*dx + dy*dy) * invRadiusSq)
            wTot = wColor * wSpace
            
            sumR + r * wTot
            sumG + g * wTot
            sumB + b * wTot
            sumA + PeekA(*src + idx2 + 3) * wTot
            sumW + wTot
          Next
        Next
        
        If sumW > 0.0
          Protected invSumW.d = 1.0 / sumW
          PokeA(*dst + idx + 3, Int(sumA * invSumW + 0.5))
          PokeA(*dst + idx + 2, Int(sumR * invSumW + 0.5))
          PokeA(*dst + idx + 1, Int(sumG * invSumW + 0.5))
          PokeA(*dst + idx,     Int(sumB * invSumW + 0.5))
        Else
          PokeL(*dst + idx, PeekL(*src + idx))
        EndIf
      Next
    Next
  EndWith
EndProcedure

; --- Procédure Ex : Gestion des itérations et de la mémoire ---
Procedure RollingGuidanceFilterEx(*FilterCtx.FilterParams)
  Restore RollingGuidanceFilter_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[0] * 4
    Protected *cur = AllocateMemory(total)
    Protected *guide = AllocateMemory(total)
    
    If *cur And *guide
      ; Initialisation : cur reçoit la source, guide reçoit cur
      CopyMemory(\addr[0], *cur, total)
      CopyMemory(*cur, *guide, total)
      
      ; Initial blur sur le guide (Standard RGF)
      LaplacianPyramidBlur_BlurBuffer(*guide, \image_lg[0], \image_ht[0], \option[0])
      
      Protected tmpSrc = *cur, tmpDst = \addr[1] , i
      
      ; Boucle d'itérations
      For i = 0 To \option[2] - 1
        \addr[0] = tmpSrc     ; Source pour le Bilateral (l'image à lisser)
        \addr[1] = tmpDst     ; Destination
        \addr[2] = *guide     ; Guide (l'image qui dicte les structures)
        
        Create_MultiThread_MT(@RollingGuidance_Worker(), 1)
        
        ; Pour la prochaine itération, le résultat actuel devient le nouveau guide
        CopyMemory(tmpDst, *guide, total)
        ; Si plusieurs itérations, on pourrait swapper source et destination 
        ; mais ici on lisse toujours l'image originale ou la dernière étape
        tmpSrc = tmpDst 
      Next
      
      FreeMemory(*cur) : FreeMemory(*guide)
    EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; --- Appel Simplifié ---
Procedure RollingGuidanceFilter(source, cible, mask, radius, sigmaColor, iterations, mask_type)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius : \option[1] = sigmaColor : \option[2] = iterations : \option[3] = mask_type
  EndWith
  RollingGuidanceFilterEx(FilterCtx)
EndProcedure

DataSection
  RollingGuidanceFilter_data:
  Data.s "Rolling Guidance Filter"
  Data.s "Lissage itératif préservant les détails (Edge-Preserving)"
  Data.i #FilterType_Blur, #Blur_Adaptive
  Data.s "Rayon spatial"
  Data.i 1, 20, 6
  Data.s "Sigma couleur"
  Data.i 5, 100, 30
  Data.s "Itérations"
  Data.i 1, 10, 3
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 93
; FirstLine = 78
; Folding = -
; EnableXP
; DPIAware