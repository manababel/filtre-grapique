; --- Procédures Multi-Thread (Jacobi) ---

Procedure WLSBlur_ComputeWeights_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected alpha.f = \option[1]
    Protected x, y, idx, offset
    Protected L_here.f, L_right.f, L_down.f
    Protected grad_x.f, grad_y.f, wx.f, wy.f
    Protected lgMinus1 = lg - 1
    Protected htMinus1 = ht - 1
    Protected lgShift2 = lg << 2
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lgMinus1
        idx = y * lg + x
        offset = idx << 2
        L_here = PeekF(\addr[2] + offset)
        
        ; Poids horizontal
        If x < lgMinus1
          L_right = PeekF(\addr[2] + offset + 4)
          grad_x = Abs(L_right - L_here)
          wx = 1.0 / (Pow(grad_x + 0.001, alpha))
        Else
          wx = 0.0
        EndIf
        PokeF(\addr[3] + offset, wx)
        
        ; Poids vertical
        If y < htMinus1
          L_down = PeekF(\addr[2] + offset + lgShift2)
          grad_y = Abs(L_down - L_here)
          wy = 1.0 / (Pow(grad_y + 0.001, alpha))
        Else
          wy = 0.0
        EndIf
        PokeF(\addr[4] + offset, wy)
      Next
    Next
  EndWith
EndProcedure

Procedure WLSBlur_Jacobi_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected lambda.f = \option[0]
    Protected channel = \option[5]
    Protected x, y, idx, offset
    Protected val.f, sum.f, diag.f
    Protected wx_here.f, wx_left.f, wy_here.f, wy_up.f
    Protected left.f, right.f, up.f, down.f
    Protected lgMinus1 = lg - 1
    Protected htMinus1 = ht - 1
    Protected lgShift2 = lg << 2
    
    Protected *input = \addr[5 + channel]      ; valeurs originales
    Protected *current = \addr[8 + channel]    ; buffer de lecture
    Protected *next = \addr[11 + channel]      ; buffer d'écriture
    Protected *wx = \addr[3]
    Protected *wy = \addr[4]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lgMinus1
        idx = y * lg + x
        offset = idx << 2
        val = PeekF(*input + offset)
        sum = val
        diag = 1.0
        
        If x > 0
          wx_left = PeekF(*wx + offset - 4)
          left = PeekF(*current + offset - 4)
          sum + lambda * wx_left * left
          diag + lambda * wx_left
        EndIf
        If x < lgMinus1
          wx_here = PeekF(*wx + offset)
          right = PeekF(*current + offset + 4)
          sum + lambda * wx_here * right
          diag + lambda * wx_here
        EndIf
        If y > 0
          wy_up = PeekF(*wy + offset - lgShift2)
          up = PeekF(*current + offset - lgShift2)
          sum + lambda * wy_up * up
          diag + lambda * wy_up
        EndIf
        If y < htMinus1
          wy_here = PeekF(*wy + offset)
          down = PeekF(*current + offset + lgShift2)
          sum + lambda * wy_here * down
          diag + lambda * wy_here
        EndIf
        PokeF(*next + offset, sum / diag)
      Next
    Next
  EndWith
EndProcedure

Procedure WLSBlur_Copy_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected total = lg * ht
    Protected channel = \option[5]
    Protected i, offset
    Protected *src = \addr[11 + channel]
    Protected *dst = \addr[8 + channel]
    
    macro_calul_tread(total)
    
    For i = thread_start To thread_stop - 1
      offset = i << 2
      PokeF(*dst + offset, PeekF(*src + offset))
    Next
  EndWith
EndProcedure

Procedure WLSBlur_Init_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[0]
    Protected i, offset, r, g, b, col
    
    macro_calul_tread(total)
    
    For i = thread_start To thread_stop - 1
      offset = i << 2
      col = PeekL(\addr[0] + offset)
      getrgb(col, r, g, b)
      PokeF(\addr[2] + offset, 0.299 * r + 0.587 * g + 0.114 * b)
      PokeF(\addr[5] + offset, r) : PokeF(\addr[8] + offset, r)
      PokeF(\addr[6] + offset, g) : PokeF(\addr[9] + offset, g)
      PokeF(\addr[7] + offset, b) : PokeF(\addr[10] + offset, b)
    Next
  EndWith
EndProcedure

Procedure WLSBlur_WriteBack_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[0]
    Protected a2, r2, g2, b2, idx, offset, col
    
    macro_calul_tread(total)
    
    For idx = thread_start To thread_stop - 1
      offset = idx << 2
      r2 = PeekF(\addr[8] + offset) + 0.5
      g2 = PeekF(\addr[9] + offset) + 0.5
      b2 = PeekF(\addr[10] + offset) + 0.5
      clamp_rgb(r2, g2, b2)
      col = PeekL(\addr[0] + offset)
      a2 = (col >> 24) & $FF
      PokeL(\addr[1] + offset, (a2 << 24) | (r2 << 16) | (g2 << 8) | b2)
    Next
  EndWith
EndProcedure

; --- Cycle Principal ---

Procedure WLSBlurEx(*FilterCtx.FilterParams)
  Restore WLSBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    
    \option[0] * 0.1
    \option[1] * 0.1
    
    Protected size = \image_lg[0] * \image_ht[0] << 2
    Protected i, err = 0
    For i = 2 To 13
      \addr[i] = AllocateMemory(size)
      If Not \addr[i] : err = 1 : EndIf
    Next
    
    If err
      For i = 2 To 13 : If \addr[i] : FreeMemory(\addr[i]) : EndIf : Next
      ProcedureReturn 0
    EndIf
    
    ; 1. Init & Weights
    Create_MultiThread_MT(@WLSBlur_Init_MT())
    Create_MultiThread_MT(@WLSBlur_ComputeWeights_MT())
    
    ; 2. Jacobi Iterations
    Protected iter, channel
    Protected iterations = \option[2]
    For iter = 1 To iterations
      For channel = 0 To 2
        \option[5] = channel
        Create_MultiThread_MT(@WLSBlur_Jacobi_MT())
        Create_MultiThread_MT(@WLSBlur_Copy_MT())
      Next
    Next
    
    ; 3. Finalize
    Create_MultiThread_MT(@WLSBlur_WriteBack_MT())
    
    ; Cleanup
    For i = 2 To 13 : FreeMemory(\addr[i]) : \addr[i] = 0 : Next
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure WLSBlur(source, cible, mask, lambda.f, alpha.f, iterations)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = lambda
    \option[1] = alpha
    \option[2] = iterations
  EndWith
  WLSBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  WLSBlur_data:
  Data.s "WLSBlur (probleme)"
  Data.s "Lissage Weighted Least Squares (Jacobi)"
  Data.i #FilterType_Blur
  Data.i #Blur_EdgeAware
  Data.s "Lambda (Force)"
  Data.i 1, 100, 10
  Data.s "Alpha (Contours)"
  Data.i 5, 30, 12
  Data.s "Itérations"
  Data.i 1, 50, 10
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 226
; FirstLine = 186
; Folding = --
; EnableXP
; DPIAware