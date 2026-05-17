; ---------------------------------------------------
; KuwaharaBlur - Version optimisée (Image Intégrale)
; Flou adaptatif préservant les bords
; ---------------------------------------------------

; --- Macros pour l'image intégrale ---
Macro macro_KuwaharaBlur_poke_sp0()
  PokeL(*FilterCtx\addr[3] + pos, PeekL(*FilterCtx\addr[3] + pos1) + r1)
  PokeL(*FilterCtx\addr[4] + pos, PeekL(*FilterCtx\addr[4] + pos1) + g1)
  PokeL(*FilterCtx\addr[5] + pos, PeekL(*FilterCtx\addr[5] + pos1) + b1)
  PokeQ(*FilterCtx\addr[6] + (pos << 1), PeekQ(*FilterCtx\addr[6] + (pos1 << 1)) + r1 * r1 + g1 * g1 + b1 * b1)
EndMacro

Macro macro_KuwaharaBlur_peek4(a, b, c, d)
  a = PeekL(*FilterCtx\addr[3] + pos)
  b = PeekL(*FilterCtx\addr[4] + pos)
  c = PeekL(*FilterCtx\addr[5] + pos)
  d = PeekQ(*FilterCtx\addr[6] + (pos << 1))
EndMacro

; --- Étape 1 : Génération des images intégrales (Mono-thread car séquentiel) ---
Procedure KuwaharaBlur_sp0(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected pos, pos1, pos2, pos3, x, y, r1, g1, b1
    Protected.q sq
    
    ; Coin haut-gauche (0,0)
    pos = 0
    r1 = PeekA(\addr[0] + pos + 2) : g1 = PeekA(\addr[0] + pos + 1) : b1 = PeekA(\addr[0] + pos)
    PokeL(\addr[3] + pos, r1) : PokeL(\addr[4] + pos, g1) : PokeL(\addr[5] + pos, b1)
    PokeQ(\addr[6] + (pos << 1), r1 * r1 + g1 * g1 + b1 * b1)
    
    ; Première colonne (x = 0)
    For y = 1 To ht - 1
      pos = (y * lg) << 2 : pos1 = ((y - 1) * lg) << 2
      r1 = PeekA(\addr[0] + pos + 2) : g1 = PeekA(\addr[0] + pos + 1) : b1 = PeekA(\addr[0] + pos)
      macro_KuwaharaBlur_poke_sp0()
    Next
    
    ; Première ligne (y = 0)
    For x = 1 To lg - 1
      pos = x << 2 : pos1 = (x - 1) << 2
      r1 = PeekA(\addr[0] + pos + 2) : g1 = PeekA(\addr[0] + pos + 1) : b1 = PeekA(\addr[0] + pos)
      macro_KuwaharaBlur_poke_sp0()
    Next
    
    ; Reste de l'image
    For y = 1 To ht - 1
      For x = 1 To lg - 1
        pos = (y * lg + x) << 2 : pos1 = (y * lg + x - 1) << 2
        pos2 = ((y - 1) * lg + x) << 2 : pos3 = ((y - 1) * lg + x - 1) << 2
        r1 = PeekA(\addr[0] + pos + 2) : g1 = PeekA(\addr[0] + pos + 1) : b1 = PeekA(\addr[0] + pos)
        PokeL(\addr[3] + pos, PeekL(\addr[3] + pos1) + PeekL(\addr[3] + pos2) - PeekL(\addr[3] + pos3) + r1)
        PokeL(\addr[4] + pos, PeekL(\addr[4] + pos1) + PeekL(\addr[4] + pos2) - PeekL(\addr[4] + pos3) + g1)
        PokeL(\addr[5] + pos, PeekL(\addr[5] + pos1) + PeekL(\addr[5] + pos2) - PeekL(\addr[5] + pos3) + b1)
        sq = r1 * r1 + g1 * g1 + b1 * b1
        PokeQ(\addr[6] + (pos << 1), PeekQ(\addr[6] + (pos1 << 1)) + PeekQ(\addr[6] + (pos2 << 1)) - PeekQ(\addr[6] + (pos3 << 1)) + sq)
      Next
    Next
  EndWith
EndProcedure

; --- Étape 2 : Filtrage Kuwahara (Multi-thread) ---
Procedure KuwaharaBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0], h = \image_ht[0]
    Protected radius = \option[0], sharpness.f = \option[1] / 100.0
    Protected x, y, k, minIndex, pos, r1, g1, b1
    Protected r.f, g.f, b.f, v.f, minVar.f
    Protected inv_sharpness.f = 1.0 - sharpness
    Protected w_minus_1 = w - 1, h_minus_1 = h - 1
    Dim quadrant.d(19) ; 4 quadrants * 5 valeurs
    
    macro_calul_tread(h)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        For k = 0 To 3
          Protected x0, y0, x1, y1, count.d
          Protected.q sR0, sR1, sR2, sR3, sG0, sG1, sG2, sG3, sB0, sB1, sB2, sB3, sS0, sS1, sS2, sS3
          Select k
            Case 0 : x0 = x - radius : y0 = y - radius : x1 = x : y1 = y
            Case 1 : x0 = x : y0 = y - radius : x1 = x + radius : y1 = y
            Case 2 : x0 = x - radius : y0 = y : x1 = x : y1 = y + radius
            Case 3 : x0 = x : y0 = y : x1 = x + radius : y1 = y + radius
          EndSelect
          If x0 < 0 : x0 = 0 : EndIf : If y0 < 0 : y0 = 0 : EndIf
          If x1 > w_minus_1 : x1 = w_minus_1 : EndIf : If y1 > h_minus_1 : y1 = h_minus_1 : EndIf
          count = (x1 - x0 + 1) * (y1 - y0 + 1)
          pos = (y1 * w + x1) << 2 : macro_KuwaharaBlur_peek4(sR0, sG0, sB0, sS0)
          sR1 = 0 : sG1 = 0 : sB1 = 0 : sS1 = 0 : sR2 = 0 : sG2 = 0 : sB2 = 0 : sS2 = 0 : sR3 = 0 : sG3 = 0 : sB3 = 0 : sS3 = 0
          If y0 > 0 : pos = ((y0 - 1) * w + x1) << 2 : macro_KuwaharaBlur_peek4(sR1, sG1, sB1, sS1) : EndIf
          If x0 > 0 : pos = (y1 * w + (x0 - 1)) << 2 : macro_KuwaharaBlur_peek4(sR2, sG2, sB2, sS2) : EndIf
          If x0 > 0 And y0 > 0 : pos = ((y0 - 1) * w + (x0 - 1)) << 2 : macro_KuwaharaBlur_peek4(sR3, sG3, sB3, sS3) : EndIf
          quadrant(k * 5 + 0) = sR0 - sR1 - sR2 + sR3
          quadrant(k * 5 + 1) = sG0 - sG1 - sG2 + sG3
          quadrant(k * 5 + 2) = sB0 - sB1 - sB2 + sB3
          quadrant(k * 5 + 3) = sS0 - sS1 - sS2 + sS3
          quadrant(k * 5 + 4) = count
        Next
        
        minIndex = 0 : Protected sum0.d = quadrant(0) + quadrant(1) + quadrant(2)
        minVar = quadrant(3) / quadrant(4) - (sum0 / quadrant(4)) * (sum0 / quadrant(4))
        For k = 1 To 3
          Protected kO = k * 5
          Protected sumK.d = quadrant(kO) + quadrant(kO + 1) + quadrant(kO + 2)
          v = quadrant(kO + 3) / quadrant(kO + 4) - (sumK / quadrant(kO + 4)) * (sumK / quadrant(kO + 4))
          If v < minVar : minVar = v : minIndex = k : EndIf
        Next
        
        pos = (y * w + x) << 2
        r1 = PeekA(\addr[0] + pos + 2) : g1 = PeekA(\addr[0] + pos + 1) : b1 = PeekA(\addr[0] + pos)
        Protected mO = minIndex * 5 : Protected invC.d = 1.0 / quadrant(mO + 4)
        r = (quadrant(mO) * invC) * sharpness + r1 * inv_sharpness
        g = (quadrant(mO + 1) * invC) * sharpness + g1 * inv_sharpness
        b = (quadrant(mO + 2) * invC) * sharpness + b1 * inv_sharpness
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        PokeL(\addr[1] + pos, (PeekA(\addr[0] + pos + 3) << 24) | (Int(r) << 16) | (Int(g) << 8) | Int(b))
      Next
    Next
    FreeArray(quadrant())
  EndWith
EndProcedure

; --- Procédure Ex ---
Procedure KuwaharaBlurEx(*FilterCtx.FilterParams)
  Restore KuwaharaBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[0] * 4
    Protected totalQ = \image_lg[0] * \image_ht[0] * 8
    \addr[3] = AllocateMemory(total) : \addr[4] = AllocateMemory(total)
    \addr[5] = AllocateMemory(total) : \addr[6] = AllocateMemory(totalQ)
    
    Protected tmpSrc = \addr[0], tmpDst = \addr[1] , i
    For i = 1 To \option[2]
      \addr[0] = tmpSrc : \addr[1] = tmpDst
      KuwaharaBlur_sp0(*FilterCtx) ; Calcul SAT
      Create_MultiThread_MT(@KuwaharaBlur_sp(), 1)
      If i < \option[2] : Swap tmpSrc, tmpDst : EndIf
    Next
    
    FreeMemory(\addr[3]) : FreeMemory(\addr[4]) : FreeMemory(\addr[5]) : FreeMemory(\addr[6])
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; --- Appel simplifiée ---
Procedure KuwaharaBlur(source, cible, mask, radius, sharpness, iterations, mask_type)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius : \option[1] = sharpness : \option[2] = iterations : \option[3] = mask_type
  EndWith
  KuwaharaBlurEx(FilterCtx)
EndProcedure

DataSection
  KuwaharaBlur_data:
  Data.s "KuwaharaBlur"
  Data.s "Flou adaptatif préservant les bords (Kuwahara)"
  Data.i #FilterType_Blur, #Blur_Adaptive
  Data.s "Rayon"
  Data.i 1, 50, 10    ; Rayon
  Data.s "Netteté"
  Data.i 0, 100, 70   ; Netteté
  Data.s "Itérations"
  Data.i 1, 5, 3      ; Itérations
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 139
; FirstLine = 122
; Folding = --
; EnableXP
; DPIAware