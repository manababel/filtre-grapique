; --- Procédures de support (conservées sans modification de logique) ---

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

Procedure.f BoxSum(*integral, lg, ht, x, y, r)
  Protected x0 = x - r : Protected y0 = y - r
  Protected x1 = x + r : Protected y1 = y + r
  If x0 < 0 : x0 = 0 : EndIf : If y0 < 0 : y0 = 0 : EndIf
  If x1 >= lg : x1 = lg - 1 : EndIf : If y1 >= ht : y1 = ht - 1 : EndIf
  Protected A.f = 0.0, B.f = 0.0, C.f = 0.0, D.f
  If x0 > 0 And y0 > 0 : A = PeekF(*integral + ((y0 - 1) * lg + (x0 - 1)) << 2) : EndIf
  If x0 > 0 : B = PeekF(*integral + (y1 * lg + (x0 - 1)) << 2) : EndIf
  If y0 > 0 : C = PeekF(*integral + ((y0 - 1) * lg + x1) << 2) : EndIf
  D = PeekF(*integral + (y1 * lg + x1) << 2)
  ProcedureReturn D - B - C + A
EndProcedure

Procedure ComputeIntegralFloat(*src, *integral, lg, ht)
  Protected x, y, pos, rowSum.f
  Protected lgShift2 = lg << 2
  For y = 0 To ht - 1
    rowSum = 0.0
    For x = 0 To lg - 1
      pos = (y * lg + x) << 2
      rowSum + PeekF(*src + pos)
      If y = 0 : PokeF(*integral + pos, rowSum)
      Else : PokeF(*integral + pos, rowSum + PeekF(*integral + pos - lgShift2)) : EndIf
    Next
  Next
EndProcedure

Procedure.f SumWindowFloat(*integral, lg, ht, x, y, r)
  Protected x0 = x - r - 1 : Protected y0 = y - r - 1
  Protected x1 = x + r : Protected y1 = y + r
  If x0 < 0 : x0 = -1 : EndIf : If y0 < 0 : y0 = -1 : EndIf
  If x1 >= lg : x1 = lg - 1 : EndIf : If y1 >= ht : y1 = ht - 1 : EndIf
  Protected A.f = 0.0, B.f = 0.0, C.f = 0.0, D.f
  If x0 >= 0 And y0 >= 0 : A = PeekF(*integral + (y0 * lg + x0) << 2) : EndIf
  If x0 >= 0 : B = PeekF(*integral + (y1 * lg + x0) << 2) : EndIf
  If y0 >= 0 : C = PeekF(*integral + (y0 * lg + x1) << 2) : EndIf
  D = PeekF(*integral + (y1 * lg + x1) << 2)
  ProcedureReturn D - B - C + A
EndProcedure

; --- Macros MT ---

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

; --- Procédures MT ---

Procedure GuidedFilterColor_SP0_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[0]
    Protected *source = \addr[0]
    Protected *I_R = \addr[3], *I_G = \addr[4], *I_B = \addr[5]
    Protected i, pos, r, g, b
    
    macro_calul_tread(total)
    
    For i = thread_start To thread_stop - 1
      pos = i << 2
      getrgb(PeekL(*source + pos), r, g, b)
      PokeL(*I_R + pos, r) : PokeL(*I_G + pos, g) : PokeL(*I_B + pos, b)
    Next
  EndWith
EndProcedure

Procedure GuidedFilterColor_SP2_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected *I_R = \addr[3], *I_G = \addr[4], *I_B = \addr[5]
    Protected *tmpR = \addr[12], *tmpG = \addr[13], *tmpB = \addr[14]
    Protected x, y, pos, var, lgMinus1 = lg - 1
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lgMinus1
        pos = (y * lg + x) << 2
        var = PeekL(*I_R + pos) & $FF : PokeF(*tmpR + pos, var * var)
        var = PeekL(*I_G + pos) & $FF : PokeF(*tmpG + pos, var * var)
        var = PeekL(*I_B + pos) & $FF : PokeF(*tmpB + pos, var * var)
      Next
    Next
  EndWith
EndProcedure

Procedure GuidedFilterColor_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]
    Protected eps.f = \option[1]
    Protected area = (2 * radius + 1) * (2 * radius + 1)
    Protected invArea.f = 1.0 / area
    Protected x, y, pos, meanI.f, meanII.f, varI.f, a.f, b.f
    Protected rc, gc, bc, val, var, lgMinus1 = lg - 1
    
    Protected *I_R = \addr[3], *I_G = \addr[4], *I_B = \addr[5]
    Protected *intR = \addr[6], *intG = \addr[7], *intB = \addr[8]
    Protected *intRR = \addr[9], *intGG = \addr[10], *intBB = \addr[11]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lgMinus1
        pos = (y * lg + x) << 2
        GuidedFilterColor_SP1_MT(R, RR, rc)
        GuidedFilterColor_SP1_MT(G, GG, gc)
        GuidedFilterColor_SP1_MT(B, BB, bc)
        clamp_rgb(rc, gc, bc)
        PokeL(\addr[1] + pos, (rc << 16) | (gc << 8) | bc)
      Next
    Next
  EndWith
EndProcedure

; --- Cycle principal ---

Procedure GuidedFilterColorEx(*FilterCtx.FilterParams)
  Restore GuidedFilterColor_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected size = lg * ht << 2
    Protected i, err = 0
    
    For i = 3 To 14
      \addr[i] = AllocateMemory(size)
      If Not \addr[i] : err = 1 : EndIf
    Next
    
    If err
      For i = 3 To 14 : If \addr[i] : FreeMemory(\addr[i]) : EndIf : Next
      ProcedureReturn 0
    EndIf
    
    Create_MultiThread_MT(@GuidedFilterColor_SP0_MT())
    
    ComputeIntegral(\addr[3], \addr[6], lg, ht)
    ComputeIntegral(\addr[4], \addr[7], lg, ht)
    ComputeIntegral(\addr[5], \addr[8], lg, ht)
    
    Create_MultiThread_MT(@GuidedFilterColor_SP2_MT())
    
    ComputeIntegralFloat(\addr[12], \addr[9], lg, ht)
    ComputeIntegralFloat(\addr[13], \addr[10], lg, ht)
    ComputeIntegralFloat(\addr[14], \addr[11], lg, ht)
    
    Create_MultiThread_MT(@GuidedFilterColor_MT())
    
    For i = 3 To 14 : FreeMemory(\addr[i]) : \addr[i] = 0 : Next
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure GuidedFilterColor(source, cible, mask, radius, epsilon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = epsilon
  EndWith
  GuidedFilterColorEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  GuidedFilterColor_data:
  Data.s "GuidedFilterColor"
  Data.s "Guided Filter Couleur (Auto-guidage)"
  Data.i #FilterType_Blur
  Data.i #Blur_EdgeAware
  Data.s "Radius"
  Data.i 1, 50, 4
  Data.s "Epsilon"
  Data.i 1, 1000, 50
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 205
; FirstLine = 154
; Folding = --
; EnableXP
; DPIAware