; ======================================================
; Guided Filter Couleur optimisé (auto-guided, intégrales)
; ======================================================

; --- Integral image pour un canal (entier) ---
Procedure ComputeIntegral(*src, *integral, lg, ht)
  Protected x, y, pos, val
  Protected top.f, left.f, topleft.f
  Protected lgShift2 = lg << 2
  
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      pos = (y * lg + x) << 2
      val = PeekL(*src + pos) & $FF
      top = 0 : left = 0 : topleft = 0
      
      If y > 0 : top = PeekF(*integral + pos - lgShift2) : EndIf
      If x > 0 : left = PeekF(*integral + pos - 4) : EndIf
      If x > 0 And y > 0 : topleft = PeekF(*integral + pos - lgShift2 - 4) : EndIf
      
      PokeF(*integral + pos, val + top + left - topleft)
    Next
  Next
EndProcedure

; --- Somme d'une fenêtre avec intégrale (entier) ---
Procedure.f BoxSum(*integral, lg, ht, x, y, r)
  Protected x0 = x - r
  Protected y0 = y - r
  Protected x1 = x + r
  Protected y1 = y + r
  
  clamp(x0, 0, lg - 1)
  clamp(y0, 0, ht - 1)
  clamp(x1, 0, lg - 1)
  clamp(y1, 0, ht - 1)
  
  Protected A.f = 0.0, B.f = 0.0, C.f = 0.0, D.f
  
  If x0 > 0 And y0 > 0
    A = PeekF(*integral + ((y0 - 1) * lg + (x0 - 1)) << 2)
  EndIf
  If x0 > 0
    B = PeekF(*integral + (y1 * lg + (x0 - 1)) << 2)
  EndIf
  If y0 > 0
    C = PeekF(*integral + ((y0 - 1) * lg + x1) << 2)
  EndIf
  D = PeekF(*integral + (y1 * lg + x1) << 2)
  
  ProcedureReturn D - B - C + A
EndProcedure

; --- Integral float pour I² ---
Procedure ComputeIntegralFloat(*src, *integral, lg, ht)
  Protected x, y, pos
  Protected rowSum.f
  Protected lgShift2 = lg << 2
  
  For y = 0 To ht - 1
    rowSum = 0.0
    For x = 0 To lg - 1
      pos = (y * lg + x) << 2
      rowSum + PeekF(*src + pos)
      
      If y = 0
        PokeF(*integral + pos, rowSum)
      Else
        PokeF(*integral + pos, rowSum + PeekF(*integral + pos - lgShift2))
      EndIf
    Next
  Next
EndProcedure

Procedure.f SumWindowFloat(*integral, lg, ht, x, y, r)
  Protected x0 = x - r - 1
  Protected y0 = y - r - 1
  Protected x1 = x + r
  Protected y1 = y + r
  
  If x0 < 0 : x0 = -1 : EndIf
  If y0 < 0 : y0 = -1 : EndIf
  clamp(x1, 0, lg - 1)
  clamp(y1, 0, ht - 1)
  
  Protected A.f = 0.0, B.f = 0.0, C.f = 0.0, D.f
  
  If x0 >= 0 And y0 >= 0
    A = PeekF(*integral + (y0 * lg + x0) << 2)
  EndIf
  If x0 >= 0
    B = PeekF(*integral + (y1 * lg + x0) << 2)
  EndIf
  If y0 >= 0
    C = PeekF(*integral + (y0 * lg + x1) << 2)
  EndIf
  D = PeekF(*integral + (y1 * lg + x1) << 2)
  
  ProcedureReturn D - B - C + A
EndProcedure

Macro GuidedFilterColor_SP1_MT(col1, col2, var)
  meanI = BoxSum(*int#col1, lg, ht, x, y, radius) * invArea
  meanII = SumWindowFloat(*int#col2, lg, ht, x, y, radius) * invArea
  varI = meanII - meanI * meanI
  If varI < 0 : varI = 0 : EndIf
  a = varI / (varI + eps)
  b = meanI - a * meanI
  val = PeekL(*I_#col1 + pos) & $FF
  var = a * val + b
EndMacro

Procedure GuidedFilterColor_SP2_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected thread_start = (*param\thread_pos * ht) / *param\thread_max
  Protected thread_stop = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  If thread_stop >= ht : thread_stop = ht - 1 : EndIf
  
  Protected *I_R = *param\addr[3]
  Protected *I_G = *param\addr[4]
  Protected *I_B = *param\addr[5]
  Protected *tmpR = *param\addr[12]
  Protected *tmpG = *param\addr[13]
  Protected *tmpB = *param\addr[14]
  
  Protected x, y, pos, var, lgMinus1 = lg - 1
  
  For y = thread_start To thread_stop
    For x = 0 To lgMinus1
      pos = (y * lg + x) << 2
      
      var = PeekL(*I_R + pos) & $FF
      PokeF(*tmpR + pos, var * var)
      
      var = PeekL(*I_G + pos) & $FF
      PokeF(*tmpG + pos, var * var)
      
      var = PeekL(*I_B + pos) & $FF
      PokeF(*tmpB + pos, var * var)
    Next
  Next
EndProcedure

; --- Guided Filter couleur ---
Procedure GuidedFilterColor_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]
  Protected eps.f = *param\option[1]
  Protected area = (2 * radius + 1) * (2 * radius + 1)
  Protected invArea.f = 1.0 / area
  
  Protected x, y, pos
  Protected meanI.f, meanII.f, varI.f, a.f, b.f
  Protected rc, gc, bc
  Protected val, var
  Protected lgMinus1 = lg - 1
  
  ; Pointeurs
  Protected *I_R = *param\addr[3]
  Protected *I_G = *param\addr[4]
  Protected *I_B = *param\addr[5]
  Protected *intR = *param\addr[6]
  Protected *intG = *param\addr[7]
  Protected *intB = *param\addr[8]
  Protected *intRR = *param\addr[9]
  Protected *intGG = *param\addr[10]
  Protected *intBB = *param\addr[11]
  
  Protected thread_start = (*param\thread_pos * ht) / *param\thread_max
  Protected thread_stop = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  If thread_stop >= ht : thread_stop = ht - 1 : EndIf
  
  ; Calcul final q = a*I + b (auto-guided)
  For y = thread_start To thread_stop
    For x = 0 To lgMinus1
      pos = (y * lg + x) << 2
      
      GuidedFilterColor_SP1_MT(R, RR, rc)
      GuidedFilterColor_SP1_MT(G, GG, gc)
      GuidedFilterColor_SP1_MT(B, BB, bc)
      
      clamp_rgb(rc, gc, bc)
      PokeL(*param\addr[1] + pos, (rc << 16) | (gc << 8) | bc)
    Next
  Next
EndProcedure

; --- Split canaux ---
Procedure GuidedFilterColor_SP0_MT(*param.parametre)
  Protected total = *param\lg * *param\ht
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * total) / *param\thread_max - 1
  
  Protected *source = *param\addr[0]
  Protected *I_R = *param\addr[3]
  Protected *I_G = *param\addr[4]
  Protected *I_B = *param\addr[5]
  
  Protected i, pos, r, g, b
  
  For i = start To stop
    pos = i << 2
    getrgb(PeekL(*source + pos), r, g, b)
    PokeL(*I_R + pos, r)
    PokeL(*I_G + pos, g)
    PokeL(*I_B + pos, b)
  Next
EndProcedure

; --- Wrapper ---
Procedure GuidedFilterColor(*param.parametre)
  If *param\info_active
    *param\name = "GuidedFilterColor"
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_EdgeAware
    *param\remarque = "Guided Filter couleur (optimisé)"
    *param\info[0] = "Radius"
    *param\info[1] = "Epsilon"
    *param\info[2] = "Masque"
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 50   : *param\info_data(0,2) = 4
    *param\info_data(1,0) = 1 : *param\info_data(1,1) = 1000 : *param\info_data(1,2) = 50
    *param\info_data(2,0) = 0 : *param\info_data(2,1) = 2    : *param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected size = lg * ht << 2
  Protected i, err = 0
  
  ; Allocation mémoire (3 à 14)
  For i = 3 To 14
    *param\addr[i] = AllocateMemory(size)
    If Not *param\addr[i] : err = 1 : EndIf
  Next
  
  If err
    For i = 3 To 14
      If *param\addr[i] : FreeMemory(*param\addr[i]) : EndIf
    Next
    ProcedureReturn
  EndIf
  
  ; Split canaux RGB
  *param\addr[0] = *param\source
  MultiThread_MT(@GuidedFilterColor_SP0_MT())
  
  ; Pointeurs
  Protected *I_R = *param\addr[3]
  Protected *I_G = *param\addr[4]
  Protected *I_B = *param\addr[5]
  Protected *intR = *param\addr[6]
  Protected *intG = *param\addr[7]
  Protected *intB = *param\addr[8]
  Protected *intRR = *param\addr[9]
  Protected *intGG = *param\addr[10]
  Protected *intBB = *param\addr[11]
  
  ; 1) Intégrales I
  ComputeIntegral(*I_R, *intR, lg, ht)
  ComputeIntegral(*I_G, *intG, lg, ht)
  ComputeIntegral(*I_B, *intB, lg, ht)
  
  ; 2) Calcul I² puis intégrales float
  MultiThread_MT(@GuidedFilterColor_SP2_MT())
  
  ComputeIntegralFloat(*param\addr[12], *intRR, lg, ht)
  ComputeIntegralFloat(*param\addr[13], *intGG, lg, ht)
  ComputeIntegralFloat(*param\addr[14], *intBB, lg, ht)
  
  ; 3) Filtrage guidé
  *param\addr[1] = *param\cible
  MultiThread_MT(@GuidedFilterColor_MT())
  
  ; Appliquer le masque si nécessaire
  If *param\mask And *param\option[2]
    *param\mask_type = *param\option[2] - 1
    MultiThread_MT(@_mask())
  EndIf
  
  ; Libération mémoire
  For i = 3 To 14
    FreeMemory(*param\addr[i])
  Next
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 288
; FirstLine = 219
; Folding = --
; EnableXP
; DPIAware