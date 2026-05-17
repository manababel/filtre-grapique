Procedure GaussianBlur_Conv_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.array32 = \addr[0]
    Protected *dst.array32 = \addr[1]
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected x, y, k, i, posOffset
    Protected r.f, g.f, b.f
    Protected r1, g1, b1
    Protected *kernel = \addr[2]
    Protected wMinus1 = w - 1
    Protected var.f
    macro_calul_tread(h)
    For y = thread_start To thread_stop - 1
      posOffset = y * w 
      For x = 0 To w - 1
        r = 0 : g = 0 : b = 0
        For k = -\option[0] To \option[0]
          i = x + k
          If i < 0 : i = 0 : ElseIf i > wMinus1 : i = wMinus1 : EndIf
          getrgb(*src\l[posOffset + i] , r1, g1, b1)
          var = PeekF(*kernel + (k + \option[0]) * 4)
          r + r1 * var
          g + g1 * var
          b + b1 * var
        Next
        *dst\l[posOffset + x] = $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
  EndWith
EndProcedure

Procedure GaussianBlur_Conv_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected x, y, k, i
    Protected r.f, g.f, b.f
    Protected r1, g1, b1
    Protected *kernel = \addr[2]
    Protected hMinus1 = h - 1
    Protected var.f
    macro_calul_tread(h)
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        r = 0 : g = 0 : b = 0
        For k = -\option[0] To \option[0]
          i = y + k
          If i < 0 : i = 0 : ElseIf i > hMinus1 : i = hMinus1 : EndIf
          getrgb(*src\pixel[i * w + x] , r1, g1, b1)
          var = PeekF(*kernel + (k + \option[0]) * 4)
          r + r1 * var
          g + g1 * var
          b + b1 * var
        Next
        *dst\pixel[y * w + x] = $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
  EndWith
EndProcedure

Procedure GaussianBlur_ConvEx(*FilterCtx.FilterParams)
  Restore GaussianBlur_Conv_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[0] << 2
    Protected *tempo = AllocateMemory(total)
    If Not *tempo : ProcedureReturn 0 : EndIf
    
    ; Générer le noyau
    Protected radius = \option[0]
    Protected sigma.f = radius * 0.5
    Protected size = (radius << 1) + 1
    Protected *kernel = AllocateMemory(size * SizeOf(Float))
    
    If Not *kernel
      FreeMemory(*tempo)
      ProcedureReturn 0
    EndIf
    
    Protected i, x, var.f, sum.f = 0.0
    Protected invTwoSigmaSq.f = 1.0 / (2.0 * sigma * sigma)
    
    For i = 0 To size - 1
      x = i - radius
      var = Exp(-x * x * invTwoSigmaSq)
      PokeF(*kernel + (i * SizeOf(Float)), var)
      sum + var
    Next
    
    ; Normalisation
    Protected invSum.f = 1.0 / sum
    For i = 0 To size - 1
      Protected offset = i * SizeOf(Float)
      PokeF(*kernel + offset, PeekF(*kernel + offset) * invSum)
    Next
    
    ; === Passe horizontale ===
    \addr[1] = *tempo
    \addr[2] = *kernel
    Create_MultiThread_MT(@GaussianBlur_Conv_H_MT())
    
    ; === Passe verticale ===
    \addr[0] = *tempo
    \addr[1] = \image[1]
    Create_MultiThread_MT(@GaussianBlur_Conv_V_MT())
    
    mask_update(*FilterCtx, last_data)
    
    FreeMemory(*tempo)
    FreeMemory(*kernel)
  EndWith
EndProcedure

Procedure GaussianBlur_Conv(source, cible, mask, rayon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
  EndWith
  GaussianBlur_ConvEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  GaussianBlur_Conv_data:
  Data.s "GaussianBlur_Conv"
  Data.s "Flou gaussien haute qualité (Convolution séparable)"
  Data.i #FilterType_Blur
  Data.i #Blur_Gaussian
  
  Data.s "Rayon"
  Data.i 1, 25, 5
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 130
; FirstLine = 78
; Folding = -
; EnableXP
; DPIAware