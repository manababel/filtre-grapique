
Procedure GuidedFilterColor_Image_Int_To_Float_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[0]
    Protected *source.pixelarray = \addr[0]
    Protected *I_R.pixelarray = \addr[3]
    Protected *I_G.pixelarray = \addr[4]
    Protected *I_B.pixelarray = \addr[5]
    Protected i, r, g, b
    macro_calul_tread(total)
    For i = thread_start To thread_stop - 1
      getrgb(*source\l[i], r, g, b)
      *I_R\l[i] = r
      *I_G\l[i] = g
      *I_B\l[i] = b
    Next
  EndWith
EndProcedure

;--

Macro GuidedFilterColor_ComputeIntegral_sp0_PB()
; 1. Le Pixel (0,0)
  var = *source1\l[0] & $ff
  *source2\f[0] = var
  ; 2. La Première Ligne (y = 0, x > 0)
  For x = 1 To lg - 1
    var  = *source1\l[x] & $ff
    left = *source2\f[x - 1]
    *source2\f[x] = var + left
  Next
  ; 3. La Première Colonne (x = 0, y > 0)
  pos1 = lg ; On commence directement à la ligne y = 1
  For y = 1 To ht - 1
    var = *source1\l[pos1] & $ff
    top = *source2\f[pos1 - lg]
    *source2\f[pos1] = var + top
    pos1 + lg
  Next
  ; 4. Le Cœur de l'image (x > 0, y > 0)
  pos1 = lg ; On commence ici aussi à la ligne y = 1
  For y = 1 To ht - 1
    For x = 1 To lg - 1
      pos2 = pos1 + x 
      var  = *source1\l[pos2] & $ff
      top  = *source2\f[pos2 - lg]
      left = *source2\f[pos2 - 1]
      tf   = *source2\f[pos2 - lg - 1]
      *source2\f[pos2] = var + top + left - tf
    Next
    pos1 + lg
  Next
EndMacro

Procedure GuidedFilterColor_ComputeIntegral_PB(*FilterCtx.FilterParams)
  Protected x, y, pos1 , pos2 , var
  Protected top.f, left.f, tf.f
  Protected lg = *FilterCtx\image_lg[0]
  Protected ht = *FilterCtx\image_ht[0]
  If lg <= 0 Or ht <= 0 : ProcedureReturn : EndIf
  Protected *source1.pixelArray
  Protected *source2.FloatArray
  *source1.pixelArray = *FilterCtx\addr[3]
  *source2.FloatArray = *FilterCtx\addr[6]
  GuidedFilterColor_ComputeIntegral_sp0_PB()
  *source1.pixelArray = *FilterCtx\addr[4]
  *source2.FloatArray = *FilterCtx\addr[7]
  GuidedFilterColor_ComputeIntegral_sp0_PB()
  *source1.pixelArray = *FilterCtx\addr[5]
  *source2.FloatArray = *FilterCtx\addr[8]
  GuidedFilterColor_ComputeIntegral_sp0_PB()
EndProcedure

;--

Procedure GuidedFilterColor_SP2_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected tt = lg * ht
    Protected *I_R.pixelarray  = \addr[3]
    Protected *I_G.pixelarray  = \addr[4]
    Protected *I_B.pixelarray  = \addr[5]
    Protected *tmpR.floatarray = \addr[12]
    Protected *tmpG.floatarray = \addr[13]
    Protected *tmpB.floatarray = \addr[14]
    Protected i , var
    macro_calul_tread(tt)
    For i = thread_start To thread_stop - 1
        var = *I_R\l[i] & $FF  :  *tmpR\f[i] = var * var
        var = *I_G\l[i] & $FF  :  *tmpG\f[i] = var * var
        var = *I_B\l[i] & $ff  :  *tmpB\f[i] = var * var
    Next
  EndWith
EndProcedure

;--

Macro GuidedFilterColor_ComputeIntegralFloat_sp0_PB()
  rowSum = 0.0
  For x = 0 To lg - 1 : rowSum + *source1\f[x] : *source2\f[x] = rowSum : Next
  For y = 1 To ht - 1
    rowSum = 0.0
    For x = 0 To lg - 1
      pos = (y * lg + x)
      rowSum + *source1\f[pos]
      *source2\f[pos] = rowSum + *source2\f[pos - lg]
    Next
  Next
EndMacro

Procedure GuidedFilterColor_ComputeIntegralFloat_PB(*FilterCtx.FilterParams)
  Protected x, y, pos , rowSum.f
  Protected lg = *FilterCtx\image_lg[0]
  Protected ht = *FilterCtx\image_ht[0]
  Protected *source1.floatArray
  Protected *source2.FloatArray
  
  *source1.floatArray = *FilterCtx\addr[12]
  *source2.FloatArray = *FilterCtx\addr[9]
  GuidedFilterColor_ComputeIntegralFloat_sp0_PB()
  *source1.floatArray = *FilterCtx\addr[13]
  *source2.FloatArray = *FilterCtx\addr[10]
  GuidedFilterColor_ComputeIntegralFloat_sp0_PB()
  *source1.floatArray = *FilterCtx\addr[14]
  *source2.FloatArray = *FilterCtx\addr[11]
  GuidedFilterColor_ComputeIntegralFloat_sp0_PB()
EndProcedure

;--


Macro GuidedFilterColor_SP1_MT_PB(var, source_pixel, source_int1, source_int2)
  ; --- PREMIÈRE IMAGE INTÉGRALE (meanI) ---
  A = 0 : B = 0 : C = 0
  If x0 > 0 And y0 > 0 : a = source_int1\f[(y0 - 1) * lg + (x0 - 1)] : EndIf
  If x0 > 0            : b = source_int1\f[y1 * lg + (x0 - 1)] : EndIf
  If y0 > 0            : c = source_int1\f[(y0 - 1) * lg + x1] : EndIf
  D = source_int1\f[y1 * lg + x1]
  meanI = (D - B - C + A) * invArea
  
  ; --- SECONDE IMAGE INTÉGRALE (meanII) ---
  A = 0 : B = 0 : C = 0
  If x0 > 0 And y0 > 0 : a = source_int2\f[(y0 - 1) * lg + (x0 - 1)] : EndIf
  If x0 > 0            : b = source_int2\f[y1 * lg + (x0 - 1)] : EndIf
  If y0 > 0            : c = source_int2\f[(y0 - 1) * lg + x1] : EndIf
  D = source_int2\f[y1 * lg + x1]
  meanII = (D - B - C + A) * invArea
  
  ; --- CALCUL DU FILTRE ---
  varI = meanII - meanI * meanI
  If varI < 0 : varI = 0 : EndIf
  
  a = varI / (varI + eps) 
  b = meanI - a * meanI
  nval = source_pixel\l[pos] & $FF
  var = a * nval + b
EndMacro

Procedure GuidedFilterColor_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]
    Protected eps.f = \option[1]
    
    Protected x, y, pos, meanI.f, meanII.f, varI.f
    Protected rc, gc, bc, nval, var, lgMinus1 = lg - 1
    
    Protected x0, y0, x1, y1
    Protected.f a, b, c, d, currentArea, invArea
    
    Protected *cible.pixelarray       = \addr[1]
    Protected *sourceIR.pixelarray   = \addr[3]
    Protected *sourceIG.pixelarray   = \addr[4]
    Protected *sourceIB.pixelarray   = \addr[5]
    Protected *sourceINTR.floatarray = \addr[6]
    Protected *sourceINTG.floatarray = \addr[7]
    Protected *sourceINTB.floatarray = \addr[8]
    Protected *sourceINTRR.floatarray = \addr[9]
    Protected *sourceINTGG.floatarray = \addr[10]
    Protected *sourceINTBB.floatarray = \addr[11]
    
    macro_calul_tread(ht)

    For y = thread_start To thread_stop - 1
      y0 = y - radius : If y0 < 0 : y0 = 0 : EndIf
      y1 = y + radius : If y1 >= ht : y1 = ht - 1 : EndIf
      
      ; Précaluler (y0 - 1) * lg fait gagner une multiplication par pixel dans la boucle X !
      Protected y0_lg_minus = (y0 - 1) * lg
      Protected y1_lg = y1 * lg
      
      For x = 0 To lgMinus1
        pos = (y * lg + x)
        x0 = x - radius : If x0 < 0 : x0 = 0 : EndIf
        x1 = x + radius : If x1 >= lg : x1 = lg - 1 : EndIf
        
        currentArea = (x1 - x0 + 1) * (y1 - y0 + 1)
        invArea = 1.0 / currentArea
        
        GuidedFilterColor_SP1_MT_PB(rc, *sourceIR, *sourceINTR, *sourceINTRR)
        GuidedFilterColor_SP1_MT_PB(gc, *sourceIG, *sourceINTG, *sourceINTGG)
        GuidedFilterColor_SP1_MT_PB(bc, *sourceIB, *sourceINTB, *sourceINTBB)
        
        clamp_rgb(rc, gc, bc)
        *cible\l[pos] = (rc << 16) | (gc << 8) | bc
      Next
    Next
  EndWith
EndProcedure

;--
; --- Cycle principal ---
Macro GuidedFilterColorEx_sp(opt)
    Create_MultiThread_MT(@GuidedFilterColor_Image_Int_To_Float_MT_PB())
    GuidedFilterColor_ComputeIntegral_#opt(*FilterCtx)
    Create_MultiThread_MT(@GuidedFilterColor_SP2_MT_#opt())
    GuidedFilterColor_ComputeIntegralFloat_PB(*FilterCtx)
    Create_MultiThread_MT(@GuidedFilterColor_MT_#opt())
EndMacro

Procedure GuidedFilterColorEx(*FilterCtx.FilterParams)
  Restore GuidedFilterColor_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected size = lg * ht * 4
    Protected i, err = 0
    
    For i = 3 To 14
      \addr[i] = AllocateMemory(size)
      If Not \addr[i] : err = 1 : EndIf
    Next
    
    If err
      For i = 3 To 14 : If \addr[i] : FreeMemory(\addr[i]) : EndIf : Next
      ProcedureReturn 0
    EndIf
    
    CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
      GuidedFilterColorEx_sp(PB) ; version pb pour la version 32bits
    CompilerElse
      
      CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
        Select FilterCtx\Asm
          Case 1 : GuidedFilterColorEx_sp(SSE2)
          ;Case 2 : GuidedFilterColorEx_sp(PB)
          ;Case 3 : GuidedFilterColorEx_sp(PB)
          ;Case 4 : GuidedFilterColorEx_sp(PB)
          Default :GuidedFilterColorEx_sp(PB)
        EndSelect
      CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
        Select FilterCtx\Asm
            ;Case 1 : GuidedFilterColorEx_sp(PB)
            ;Case 2 : GuidedFilterColorEx_sp(PB)
            ;Case 3 : GuidedFilterColorEx_sp(PB)
            ;Case 4 : GuidedFilterColorEx_sp(PB)
          Case 100
          Default : GuidedFilterColorEx_sp(PB)
        EndSelect
      CompilerEndIf
    CompilerEndIf
    
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
  Data.i 1, 50, 15
  Data.s "Epsilon"
  Data.i 1, 1000, 1000
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 218
; FirstLine = 189
; Folding = ---
; EnableXP
; DPIAware