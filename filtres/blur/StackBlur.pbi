
Procedure StackBlur_Horizontal_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    
    Protected *scr.Pixelarray32 = \addr[0]
    Protected *dst.Pixelarray32 = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radiusX = \option[0]
    Protected x, y, i, pos, ii
    Protected radPlus1 = radiusX + 1
    Protected div = radPlus1 * radPlus1
    Protected wm = lg - 1
    Protected stackSize = (radiusX * 2 + 1) * 16
    Protected *stack = AllocateMemory(stackSize + 16)
    If *stack = 0 : pop_reg_xmm(*FilterCtx) : pop_reg(*FilterCtx) : ProcedureReturn : EndIf
    Protected *queue = (*stack + 15) & -16
    Protected outIdx, pIdx, stackPos
    Protected outputPixel
    Protected.d invDiv = 1.0 / div
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1 
      ; Initialisation des accumulateurs SSE2 (4 flottants: B,G,R,A)
      !pxor xmm0, xmm0              ; Sum
      !pxor xmm1, xmm1              ; InsSum
      !pxor xmm2, xmm2              ; OutSum
      !pxor xmm6, xmm6              ; Zéro constant
      
      ; Charger invDiv dans xmm7 (4 flottants)
      !movsd xmm7, [p.v_invDiv]
      !unpcklpd xmm7, xmm7
      !cvtpd2ps xmm7, xmm7
      
      ; 1. INITIALISATION DE LA PILE
      For i = -radiusX To radiusX
        ii = i
        If ii < 0 : ii = 0 : EndIf
        If ii > wm : ii = wm : EndIf
        pos = (y * lg + ii)
        Protected pixelColor = *scr\pixel[pos]
        
        ; Convertir pixel ARGB en 4 flottants (B,G,R,A)
        !movd xmm3, [p.v_pixelColor]
        !pxor xmm6, xmm6
        !punpcklbw xmm3, xmm6       ; 8-bit -> 16-bit: [B,G,R,A]
        !punpcklwd xmm3, xmm6       ; 16-bit -> 32-bit
        !pshufd xmm3, xmm3, 27      ; 27 = inverse l'ordre -> [A,R,G,B] inversé
        !cvtdq2ps xmm3, xmm3
        
        pIdx = (i + radiusX) * 16
        Protected *stackDest = *queue + pIdx
        !mov rsi, [p.p_stackDest]
        !movaps [rsi], xmm3
        
        If i <= 0
          !addps xmm2, xmm3         ; OutSum + pixel
          Protected weight.d = i + radPlus1
          !movsd xmm4, [p.v_weight]
          !unpcklpd xmm4, xmm4
          !cvtpd2ps xmm4, xmm4
          !mulps xmm4, xmm3
          !addps xmm0, xmm4
        Else
          !addps xmm1, xmm3         ; InsSum + pixel
          weight.d = radPlus1 - i
          !movsd xmm4, [p.v_weight]
          !unpcklpd xmm4, xmm4
          !cvtpd2ps xmm4, xmm4
          !mulps xmm4, xmm3
          !addps xmm0, xmm4
        EndIf
      Next
      
      stackPos = radiusX
      
      ; 2. BOUCLE DE GLISSEMENT HORIZONTAL
      For x = 0 To lg - 1
        pos = (y * lg + x)
        
        ; Division par div: multiplier par invDiv
        !movaps xmm4, xmm0
        !mulps xmm4, xmm7
        !cvtps2dq xmm4, xmm4        ; float -> 32-bit int
        
        ; Reorganiser en format ARGB pour l'écriture
        !pshufd xmm4, xmm4, 27      ; 27 = inverse l'ordre
        
        !packssdw xmm4, xmm6
        !packuswb xmm4, xmm6
        !movd eax, xmm4
        !mov [p.v_outputPixel], eax
        *dst\pixel[pos] = outputPixel
        
        ; Mise à jour de la pile circulaire
        !subps xmm0, xmm2           ; Sum - OutSum
        
        outIdx = (stackPos - radiusX + radiusX * 2 + 1) % (radiusX * 2 + 1)
        Protected *stackOut = *queue + (outIdx * 16)
        !mov rsi, [p.p_stackOut]
        !movaps xmm4, [rsi]
        !subps xmm2, xmm4           ; OutSum - pixel_sortant
        
        ii = x + radiusX + 1
        If ii < 0 : ii = 0 : EndIf
        If ii > wm : ii = wm : EndIf
        pos = (y * lg + ii)
        pixelColor = *scr\pixel[pos]
        
        !movd xmm3, [p.v_pixelColor]
        !pxor xmm6, xmm6
        !punpcklbw xmm3, xmm6
        !punpcklwd xmm3, xmm6
        !pshufd xmm3, xmm3, 27      ; 27 = inverse l'ordre
        !cvtdq2ps xmm3, xmm3
        
        !movaps [rsi], xmm3         ; Remplace dans la pile
        !addps xmm1, xmm3           ; InsSum + pixel_entrant
        !addps xmm0, xmm1           ; Sum + InsSum
        
        stackPos = (stackPos + 1) % (radiusX * 2 + 1)
        Protected *stackCenter = *queue + (stackPos * 16)
        !mov rsi, [p.p_stackCenter]
        !movaps xmm4, [rsi]
        !addps xmm2, xmm4           ; OutSum + pixel_central
        !subps xmm1, xmm4           ; InsSum - pixel_central
      Next
    Next
    
    FreeMemory(*stack)
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
  EndWith
EndProcedure

Procedure StackBlur_Vertical_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    push_reg(*FilterCtx)
    push_reg_xmm(*FilterCtx)
    
    Protected *scr.Pixelarray32 = \addr[0]
    Protected *dst.Pixelarray32 = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radiusY = \option[1]
    
    Protected x, y, i, pos, ii
    Protected radPlus1 = radiusY + 1
    Protected div = radPlus1 * radPlus1
    Protected hm = ht - 1
    
    Protected stackSize = (radiusY * 2 + 1) * 16
    Protected *stack = AllocateMemory(stackSize + 16)
    If *stack = 0 : pop_reg_xmm(*FilterCtx) : pop_reg(*FilterCtx) : ProcedureReturn : EndIf
    
    Protected *queue = (*stack + 15) & -16
    Protected outIdx, pIdx, stackPos
    Protected outputPixel
    Protected.d invDiv = 1.0 / div
    
    macro_calul_tread(lg)
    
    For x = thread_start To thread_stop - 1
      
      !pxor xmm0, xmm0              ; Sum
      !pxor xmm1, xmm1              ; InsSum
      !pxor xmm2, xmm2              ; OutSum
      !pxor xmm6, xmm6              ; Zéro constant
      
      !movsd xmm7, [p.v_invDiv]
      !unpcklpd xmm7, xmm7
      !cvtpd2ps xmm7, xmm7
      
      ; 1. INITIALISATION DE LA PILE VERTICALE
      For i = -radiusY To radiusY
        ii = i
        If ii < 0 : ii = 0 : EndIf
        If ii > hm : ii = hm : EndIf
        pos = (ii * lg + x)
        
        Protected pixelColor = *scr\pixel[pos]
        
        !movd xmm3, [p.v_pixelColor]
        !pxor xmm6, xmm6
        !punpcklbw xmm3, xmm6
        !punpcklwd xmm3, xmm6
        !pshufd xmm3, xmm3, 27      ; 27 = inverse l'ordre
        !cvtdq2ps xmm3, xmm3
        
        pIdx = (i + radiusY) * 16
        Protected *stackDest = *queue + pIdx
        !mov rsi, [p.p_stackDest]
        !movaps [rsi], xmm3
        
        If i <= 0
          !addps xmm2, xmm3
          Protected weight.d = i + radPlus1
          !movsd xmm4, [p.v_weight]
          !unpcklpd xmm4, xmm4
          !cvtpd2ps xmm4, xmm4
          !mulps xmm4, xmm3
          !addps xmm0, xmm4
        Else
          !addps xmm1, xmm3
          weight.d = radPlus1 - i
          !movsd xmm4, [p.v_weight]
          !unpcklpd xmm4, xmm4
          !cvtpd2ps xmm4, xmm4
          !mulps xmm4, xmm3
          !addps xmm0, xmm4
        EndIf
      Next
      
      stackPos = radiusY
      
      ; 2. BOUCLE DE GLISSEMENT VERTICAL
      For y = 0 To ht - 1
        pos = (y * lg + x)
        
        !movaps xmm4, xmm0
        !mulps xmm4, xmm7
        !cvtps2dq xmm4, xmm4
        
        !pshufd xmm4, xmm4, 27      ; 27 = inverse l'ordre
        
        !packssdw xmm4, xmm6
        !packuswb xmm4, xmm6
        !movd eax, xmm4
        !mov [p.v_outputPixel], eax
        *dst\pixel[pos] = outputPixel
        
        !subps xmm0, xmm2
        
        outIdx = (stackPos - radiusY + radiusY * 2 + 1) % (radiusY * 2 + 1)
        Protected *stackOut = *queue + (outIdx * 16)
        !mov rsi, [p.p_stackOut]
        !movaps xmm4, [rsi]
        !subps xmm2, xmm4
        
        ii = y + radiusY + 1
        If ii < 0 : ii = 0 : EndIf
        If ii > hm : ii = hm : EndIf
        pos = (ii * lg + x)
        pixelColor = *scr\pixel[pos]
        
        !movd xmm3, [p.v_pixelColor]
        !pxor xmm6, xmm6
        !punpcklbw xmm3, xmm6
        !punpcklwd xmm3, xmm6
        !pshufd xmm3, xmm3, 27      ; 27 = inverse l'ordre
        !cvtdq2ps xmm3, xmm3
        
        !movaps [rsi], xmm3
        !addps xmm1, xmm3
        !addps xmm0, xmm1
        
        stackPos = (stackPos + 1) % (radiusY * 2 + 1)
        Protected *stackCenter = *queue + (stackPos * 16)
        !mov rsi, [p.p_stackCenter]
        !movaps xmm4, [rsi]
        !addps xmm2, xmm4
        !subps xmm1, xmm4
      Next
    Next
    
    FreeMemory(*stack)
    pop_reg_xmm(*FilterCtx)
    pop_reg(*FilterCtx)
  EndWith
EndProcedure

Procedure StackBlur_Horizontal_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *scr.Pixelarray32 = \addr[0]
    Protected *dst.Pixelarray32 = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radiusX = \option[0]
    
    Protected x, y, i, r, g, b, pos, ii
    Protected rSum, gSum, bSum
    Protected rInsSum, gInsSum, bInsSum
    Protected rOutSum, gOutSum, bOutSum
    Protected pIdx, outIdx, stackPos
    
    Protected radPlus1 = radiusX + 1
    Protected div = radPlus1 * radPlus1 
    Protected wm = lg - 1
    
    ; Optimisation : Multiplication au lieu de division
    Protected.f invDiv = 1.0 / div
    
    Protected *stack = AllocateMemory((radiusX * 2 + 1) * 3 * SizeOf(Long))
    If *stack = 0 : ProcedureReturn : EndIf
    Protected *queue.array32 = *stack
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      rSum = 0 : gSum = 0 : bSum = 0
      rInsSum = 0 : gInsSum = 0 : bInsSum = 0
      rOutSum = 0 : gOutSum = 0 : bOutSum = 0
      
      ; 1. INITIALISATION DE LA PILE
      For i = -radiusX To radiusX
        ii = i
        Clamp(ii, 0, wm)
        pos = (y * lg + ii)
        getrgb(*scr\pixel[pos], r, g, b)
        
        pIdx = (i + radiusX) * 3
        *queue\l[pIdx]     = r
        *queue\l[pIdx + 1] = g
        *queue\l[pIdx + 2] = b
        
        If i <= 0
          rOutSum + r : gOutSum + g : bOutSum + b
          rSum + r * (i + radPlus1)
          gSum + g * (i + radPlus1)
          bSum + b * (i + radPlus1)
        Else
          rInsSum + r : gInsSum + g : bInsSum + b
          rSum + r * (radPlus1 - i)
          gSum + g * (radPlus1 - i)
          bSum + b * (radPlus1 - i)
        EndIf
      Next
      
      stackPos = radiusX
      
      ; 2. BOUCLE DE GLISSEMENT
      For x = 0 To lg - 1
        pos = (y * lg + x)
        
        ; Application avec invDiv et conservation / injection de l'Alpha (ex: $FF000000)
        *dst\pixel[pos] = $FF000000 | (Int(rSum * invDiv) << 16) | (Int(gSum * invDiv) << 8) | Int(bSum * invDiv)
        
        rSum - rOutSum : gSum - gOutSum : bSum - bOutSum
        
        outIdx = (stackPos - radiusX + radiusX * 2 + 1) % (radiusX * 2 + 1)
        outIdx * 3
        
        rOutSum - *queue\l[outIdx]
        gOutSum - *queue\l[outIdx + 1]
        bOutSum - *queue\l[outIdx + 2]
        
        ii = x + radiusX + 1
        Clamp(ii, 0, wm)
        pos = (y * lg + ii)
        getrgb(*scr\pixel[pos], r, g, b)
        
        *queue\l[outIdx]     = r
        *queue\l[outIdx + 1] = g
        *queue\l[outIdx + 2] = b
        
        rInsSum + r : gInsSum + g : bInsSum + b
        rSum + rInsSum : gSum + gInsSum : bSum + bInsSum
        
        stackPos = (stackPos + 1) % (radiusX * 2 + 1)
        pIdx = stackPos * 3
        
        rOutSum + *queue\l[pIdx]
        gOutSum + *queue\l[pIdx + 1]
        bOutSum + *queue\l[pIdx + 2]
        
        rInsSum - *queue\l[pIdx]
        gInsSum - *queue\l[pIdx + 1]
        bInsSum - *queue\l[pIdx + 2]
      Next
    Next
  EndWith
  FreeMemory(*stack)
EndProcedure

Procedure StackBlur_Vertical_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *scr.Pixelarray32 = \addr[0]
    Protected *dst.Pixelarray32 = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radiusY = \option[1]
    
    Protected x, y, i, r, g, b, pos, ii
    Protected rSum, gSum, bSum
    Protected rInsSum, gInsSum, bInsSum
    Protected rOutSum, gOutSum, bOutSum
    Protected pIdx, outIdx, stackPos
    
    Protected radPlus1 = radiusY + 1
    Protected div = radPlus1 * radPlus1 
    Protected hm = ht - 1
    
    Protected.f invDiv = 1.0 / div
    
    Protected *stack = AllocateMemory((radiusY * 2 + 1) * 3 * SizeOf(Long))
    If *stack = 0 : ProcedureReturn : EndIf
    Protected *queue.array32 = *stack
    
    macro_calul_tread(lg)
    
    For x = thread_start To thread_stop - 1
      rSum = 0 : gSum = 0 : bSum = 0
      rInsSum = 0 : gInsSum = 0 : bInsSum = 0
      rOutSum = 0 : gOutSum = 0 : bOutSum = 0
      
      ; 1. INITIALISATION DE LA PILE VERTICALE
      For i = -radiusY To radiusY
        ii = i
        Clamp(ii, 0, hm)
        pos = (ii * lg + x)
        getrgb(*scr\pixel[pos], r, g, b)
        
        pIdx = (i + radiusY) * 3
        *queue\l[pIdx]     = r
        *queue\l[pIdx + 1] = g
        *queue\l[pIdx + 2] = b
        
        If i <= 0
          rOutSum + r : gOutSum + g : bOutSum + b
          rSum + r * (i + radPlus1)
          gSum + g * (i + radPlus1)
          bSum + b * (i + radPlus1)
        Else
          rInsSum + r : gInsSum + g : bInsSum + b
          rSum + r * (radPlus1 - i)
          gSum + g * (radPlus1 - i)
          bSum + b * (radPlus1 - i)
        EndIf
      Next
      
      stackPos = radiusY
      
      ; 2. GLISSEMENT VERTICAL
      For y = 0 To ht - 1
        pos = (y * lg + x)
        
        *dst\pixel[pos] = $FF000000 | (Int(rSum * invDiv) << 16) | (Int(gSum * invDiv) << 8) | Int(bSum * invDiv)
        
        rSum - rOutSum : gSum - gOutSum : bSum - bOutSum
        
        outIdx = (stackPos - radiusY + radiusY * 2 + 1) % (radiusY * 2 + 1)
        outIdx * 3
        
        rOutSum - *queue\l[outIdx]
        gOutSum - *queue\l[outIdx + 1]
        bOutSum - *queue\l[outIdx + 2]
        
        ii = y + radiusY + 1
        Clamp(ii, 0, hm)
        pos = (ii * lg + x)
        getrgb(*scr\pixel[pos], r, g, b)
        
        *queue\l[outIdx]     = r
        *queue\l[outIdx + 1] = g
        *queue\l[outIdx + 2] = b
        
        rInsSum + r : gInsSum + g : bInsSum + b
        rSum + rInsSum : gSum + gInsSum : bSum + bInsSum
        
        stackPos = (stackPos + 1) % (radiusY * 2 + 1)
        pIdx = stackPos * 3
        
        rOutSum + *queue\l[pIdx]
        gOutSum + *queue\l[pIdx + 1]
        bOutSum + *queue\l[pIdx + 2]
        
        rInsSum - *queue\l[pIdx]
        gInsSum - *queue\l[pIdx + 1]
        bInsSum - *queue\l[pIdx + 2]
      Next
    Next
  EndWith
  FreeMemory(*stack)
EndProcedure




Macro StackBlurEx_select(var)

    For i = 1 To *FilterCtx\option[2]
      Create_MultiThread_MT(@StackBlur_Horizontal_MT_#var()) 
      Swap *FilterCtx\addr[0], *FilterCtx\addr[1] 
      If i = *FilterCtx\option[2]
        *FilterCtx\addr[1] = *FilterCtx\image[1]
      EndIf
      Create_MultiThread_MT(@StackBlur_Vertical_MT_#var())
      If i < *FilterCtx\option[2]
        Swap *FilterCtx\addr[0], *FilterCtx\addr[1]
      EndIf
    Next

EndMacro


Procedure StackBlurEx(*FilterCtx.FilterParams)
  With *FilterCtx
    Restore StackBlur_data
    Protected last_data = Filter_InitAndValidate()
    *FilterCtx\asm_dispo = 1
    If last_data < 0 : ProcedureReturn 0 : EndIf
    
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]
    Protected i
    Protected *tmpBuffer = AllocateMemory(lg * ht * 4) 
    If *tmpBuffer = 0 : ProcedureReturn : EndIf
    ;\addr[0] = \image[0]
    \addr[1] = *tmpBuffer
    

   CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
     StackBlurEx_select(PB)
  CompilerElse
    
    CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
      Select FilterCtx\Asm
        Case 1 : StackBlurEx_select(SSE2)
        ;Case 2 : StackBlurEx_select(SSE4)
        ;Case 3 : StackBlurEx_select(AVX2)
        ;Case 4 : StackBlurEx_select(AVX512)
        Default :StackBlurEx_select(PB)
      EndSelect
      
    CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
      
      Select FilterCtx\Asm
        Case 100
        Default : StackBlurEx_select(PB)
      EndSelect
      
    CompilerEndIf
    
  CompilerEndIf
  
  
    mask_update(*FilterCtx, last_data)
    FreeMemory(*tmpBuffer)
  EndWith
EndProcedure

Procedure StackBlur(source , cible , mask , rx , ry , ndp = 1)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rx
    \option[1] = ry
    \option[2] = ndp
  EndWith
  StackBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  StackBlur_data:
  Data.s "StackBlur"
  Data.s "Flou rapide par empilement"
  Data.i #FilterType_Blur
  Data.i #Blur_Classic
  
  Data.s "Rayon X"           ; Rayon horizontal
  Data.i 1,100,1
  Data.s "Rayon Y"           ; Rayon vertical
  Data.i 1,100,1
  Data.s "Nombre de passe"   ; Nombre d'itérations du filtre
  Data.i 1,3,1
  Data.s "XXX"
EndDataSection


; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 271
; FirstLine = 216
; Folding = --
; EnableXP
; DPIAware