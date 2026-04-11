Macro macro_KuwaharaBlur_poke_sp0()
  PokeL(*param\addr[3] + pos, PeekL(*param\addr[3] + pos1) + r1)
  PokeL(*param\addr[4] + pos, PeekL(*param\addr[4] + pos1) + g1)
  PokeL(*param\addr[5] + pos, PeekL(*param\addr[5] + pos1) + b1)
  PokeQ(*param\addr[6] + (pos << 1), PeekQ(*param\addr[6] + (pos1 << 1)) + r1 * r1 + g1 * g1 + b1 * b1)
EndMacro

Macro macro_KuwaharaBlur_peek4(a, b, c, d)
  a = PeekL(*param\addr[3] + pos)
  b = PeekL(*param\addr[4] + pos)
  c = PeekL(*param\addr[5] + pos)
  d = PeekQ(*param\addr[6] + (pos << 1))
EndMacro


Procedure KuwaharaBlur_sp0(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected pos, pos1, pos2, pos3
  Protected x, y
  Protected *srcPix.Pixel32
  Protected r1, g1, b1
  Protected.q sq  ; Type Quad pour les sommes de carrés
  
  ; x = 0 : y = 0
  pos = 0
  *srcPix = *param\addr[0] + pos
  getrgb(*srcPix\l, r1, g1, b1)
  PokeL(*param\addr[3] + pos, r1)
  PokeL(*param\addr[4] + pos, g1)
  PokeL(*param\addr[5] + pos, b1)
  sq = r1 * r1 + g1 * g1 + b1 * b1
  PokeQ(*param\addr[6] + (pos << 1), sq)
  
  ; x = 0
  For y = 1 To ht - 1
    pos = (y * lg) << 2
    *srcPix = *param\addr[0] + pos
    getrgb(*srcPix\l, r1, g1, b1)
    pos1 = ((y - 1) * lg) << 2
    macro_KuwaharaBlur_poke_sp0()
  Next
  
  ; y = 0
  For x = 1 To lg - 1
    pos = x << 2
    *srcPix = *param\addr[0] + pos
    getrgb(*srcPix\l, r1, g1, b1)
    pos1 = (x - 1) << 2
    macro_KuwaharaBlur_poke_sp0()
  Next
  
  For y = 1 To ht - 1
    For x = 1 To lg - 1
      pos = (y * lg + x) << 2
      *srcPix = *param\addr[0] + pos
      getrgb(*srcPix\l, r1, g1, b1)
      pos1 = (y * lg + x - 1) << 2
      pos2 = ((y - 1) * lg + x) << 2
      pos3 = ((y - 1) * lg + x - 1) << 2
      
      PokeL(*param\addr[3] + pos, PeekL(*param\addr[3] + pos1) + PeekL(*param\addr[3] + pos2) - PeekL(*param\addr[3] + pos3) + r1)
      PokeL(*param\addr[4] + pos, PeekL(*param\addr[4] + pos1) + PeekL(*param\addr[4] + pos2) - PeekL(*param\addr[4] + pos3) + g1)
      PokeL(*param\addr[5] + pos, PeekL(*param\addr[5] + pos1) + PeekL(*param\addr[5] + pos2) - PeekL(*param\addr[5] + pos3) + b1)
      
      sq = r1 * r1 + g1 * g1 + b1 * b1
      PokeQ(*param\addr[6] + (pos << 1), PeekQ(*param\addr[6] + (pos1 << 1)) + PeekQ(*param\addr[6] + (pos2 << 1)) - PeekQ(*param\addr[6] + (pos3 << 1)) + sq)
    Next
  Next
EndProcedure


Procedure KuwaharaBlur_MT(*param.parametre)
  Protected w = *param\lg
  Protected h = *param\ht
  Protected radius = *param\option[0]
  Protected sharpness.f = *param\option[1] / 100.0
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected yStart = (thread_pos * h) / thread_max
  Protected yEnd = ((thread_pos + 1) * h) / thread_max - 1

  Protected pos, x, y, k, minIndex
  Protected r.f, g.f, b.f, v.f, minVar.f
  Protected r1, g1, b1
  Protected w_minus_1 = w - 1
  Protected h_minus_1 = h - 1
  Protected inv_sharpness.f = 1.0 - sharpness
  
  Dim quadrant.d(4 * 5 - 1)  ; Utiliser Double pour éviter les débordements
  Protected *srcPix.Pixel32
  Protected *dstPix.Pixel32

  ; --- Traitement pixel par pixel ---
  For y = yStart To yEnd
    For x = 0 To w - 1
      ; Initialisation du tableau quadrant
      FillMemory(@quadrant(0), 4 * 5 * SizeOf(Double), 0)

      For k = 0 To 3
        Protected x0, y0, x1, y1
        Protected count.d
        Protected.q sR0, sR1, sR2, sR3, sG0, sG1, sG2, sG3, sB0, sB1, sB2, sB3
        Protected.q sS0, sS1, sS2, sS3

        Select k
          Case 0
            x0 = Max_2(x - radius, 0)
            y0 = Max_2(y - radius, 0)
            x1 = x
            y1 = y
          Case 1
            x0 = x
            y0 = Max_2(y - radius, 0)
            x1 = Min_2(x + radius, w_minus_1)
            y1 = y
          Case 2
            x0 = Max_2(x - radius, 0)
            y0 = y
            x1 = x
            y1 = Min_2(y + radius, h_minus_1)
          Case 3
            x0 = x
            y0 = y
            x1 = Min_2(x + radius, w_minus_1)
            y1 = Min_2(y + radius, h_minus_1)
        EndSelect

        count = (x1 - x0 + 1) * (y1 - y0 + 1)
        
        pos = (y1 * w + x1) << 2
        macro_KuwaharaBlur_peek4(sR0, sG0, sB0, sS0)
        sR1 = 0 : sG1 = 0 : sB1 = 0 : sS1 = 0
        sR2 = 0 : sG2 = 0 : sB2 = 0 : sS2 = 0
        sR3 = 0 : sG3 = 0 : sB3 = 0 : sS3 = 0
        
        If y0 > 0
          pos = ((y0 - 1) * w + x1) << 2
          macro_KuwaharaBlur_peek4(sR1, sG1, sB1, sS1)
        EndIf
        
        If x0 > 0
          pos = (y1 * w + (x0 - 1)) << 2
          macro_KuwaharaBlur_peek4(sR2, sG2, sB2, sS2)
        EndIf
        
        If x0 > 0 And y0 > 0
          pos = ((y0 - 1) * w + (x0 - 1)) << 2
          macro_KuwaharaBlur_peek4(sR3, sG3, sB3, sS3)
        EndIf

        quadrant(k * 5 + 0) = sR0 - sR1 - sR2 + sR3
        quadrant(k * 5 + 1) = sG0 - sG1 - sG2 + sG3
        quadrant(k * 5 + 2) = sB0 - sB1 - sB2 + sB3
        quadrant(k * 5 + 3) = sS0 - sS1 - sS2 + sS3
        quadrant(k * 5 + 4) = count
      Next

      ; Calcul variance et choix du quadrant
      minIndex = 0
      Protected sum0.d = quadrant(0) + quadrant(1) + quadrant(2)
      minVar = quadrant(3) / quadrant(4) - (sum0 / quadrant(4)) * (sum0 / quadrant(4))
      
      For k = 1 To 3
        Protected kOffset = k * 5
        Protected sumK.d = quadrant(kOffset + 0) + quadrant(kOffset + 1) + quadrant(kOffset + 2)
        Protected meanK.d = sumK / quadrant(kOffset + 4)
        v = quadrant(kOffset + 3) / quadrant(kOffset + 4) - meanK * meanK
        
        If v < minVar
          minVar = v
          minIndex = k
        EndIf
      Next

      ; Interpolation sharpness
      *srcPix = *param\addr[0] + ((y * w + x) << 2)
      getrgb(*srcPix\l, r1, g1, b1)
      
      Protected minOffset = minIndex * 5
      Protected invCount.d = 1.0 / quadrant(minOffset + 4)
      
      r = (quadrant(minOffset + 0) * invCount) * sharpness + r1 * inv_sharpness
      g = (quadrant(minOffset + 1) * invCount) * sharpness + g1 * inv_sharpness
      b = (quadrant(minOffset + 2) * invCount) * sharpness + b1 * inv_sharpness
      
      clamp_rgb(r, g, b)
      
      *dstPix = *param\addr[1] + ((y * w + x) << 2)
      *dstPix\l = (Int(r) << 16) | (Int(g) << 8) | Int(b)
    Next
  Next
  
  FreeArray(quadrant())
EndProcedure


Procedure KuwaharaBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Adaptive
    *param\name = "KuwaharaBlurFast"
    *param\remarque = "Kuwahara blur non linéaire optimisé"

    ; --- Paramètres ---
    *param\info[0] = "Rayon"
    *param\info[1] = "Netteté des bords"
    *param\info[2] = "Itérations"
    *param\info[3] = "Masque binaire"
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 50  : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 70
    *param\info_data(2, 0) = 1   : *param\info_data(2, 1) = 5   : *param\info_data(2, 2) = 3
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 2   : *param\info_data(3, 2) = 0
    ProcedureReturn
  EndIf

  If *param\source = 0 Or *param\cible = 0
    ProcedureReturn
  EndIf
  
  Protected iterations = *param\option[2]
  Protected err = 0
  Protected total = *param\lg * *param\ht * 4
  Protected total_quad = *param\lg * *param\ht * 8  ; Double taille pour Quad
  Protected *tempo, tmpSrc, tmpDst, i
  
  tmpDst = *param\cible
  
  If *param\source = *param\cible
    *tempo = AllocateMemory(total)
    If Not *tempo
      ProcedureReturn
    EndIf
    CopyMemory(*param\source, *tempo, total)
    tmpSrc = *tempo 
  Else
    tmpSrc = *param\source
  EndIf
  
  ; Allocation des buffers
  *param\addr[3] = AllocateMemory(total)      ; r
  If Not *param\addr[3] : err = 1 : EndIf
  *param\addr[4] = AllocateMemory(total)      ; g
  If Not *param\addr[4] : err = 1 : EndIf
  *param\addr[5] = AllocateMemory(total)      ; b
  If Not *param\addr[5] : err = 1 : EndIf
  *param\addr[6] = AllocateMemory(total_quad) ; sq (Quad = 8 octets)
  If Not *param\addr[6] : err = 1 : EndIf
  
  ; Gestion des erreurs d'allocation
  If err = 1
    If *param\addr[3] : FreeMemory(*param\addr[3]) : EndIf
    If *param\addr[4] : FreeMemory(*param\addr[4]) : EndIf
    If *param\addr[5] : FreeMemory(*param\addr[5]) : EndIf
    If *param\addr[6] : FreeMemory(*param\addr[6]) : EndIf
    If *tempo : FreeMemory(*tempo) : EndIf
    ProcedureReturn
  EndIf
  
  ; Boucle d'itérations
  For i = 1 To iterations
    *param\addr[0] = tmpSrc
    *param\addr[1] = tmpDst
    KuwaharaBlur_sp0(*param)
    MultiThread_MT(@KuwaharaBlur_MT())
    
    ; Swap pour la prochaine itération
    If i < iterations
      Swap tmpSrc, tmpDst
    EndIf
  Next
  
  ; Application du masque si nécessaire
  If *param\mask And *param\option[3]
    *param\mask_type = *param\option[3] - 1
    MultiThread_MT(@_mask())
  EndIf
  
  ; Libération de la mémoire
  If *tempo : FreeMemory(*tempo) : EndIf
  FreeMemory(*param\addr[3])
  FreeMemory(*param\addr[4])
  FreeMemory(*param\addr[5])
  FreeMemory(*param\addr[6])
  
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 285
; FirstLine = 216
; Folding = -
; EnableXP
; DPIAware