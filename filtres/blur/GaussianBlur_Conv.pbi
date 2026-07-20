

Procedure GaussianBlur_Conv_H_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray = \addr[0]
    Protected *dst.PixelArray = \addr[1]
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected x, y, k, i, posOffset
    Protected *kernel.FloatArray = \addr[2]
    Protected radius = \option[0]
    Protected wMinus1 = w - 1
    
    macro_calul_tread(h)
    
    ; Variables temporaires pour l'Asm
    Protected pixelIn.l, pixelOut.l
    Protected k_offset.i, kernel_val.f
    
    For y = thread_start To thread_stop - 1
      posOffset = y * w 
      For x = 0 To w - 1
        !pxor xmm0, xmm0 ; xmm0 servira d'accumulateur pour les canaux [A, R, G, B] (mis à 0)
        !pxor xmm4 , xmm4
        For k = -radius To radius
          i = x + k
          If i < 0 : i = 0 : ElseIf i > wMinus1 : i = wMinus1 : EndIf
          pixelIn = *src\l[posOffset + i]
          kernel_val = *kernel\f[k + radius]
          ; --- Début du bloc SSE2 ---
            ; 1. Charger le pixel (32 bits : ARGB) dans un registre
            !movd xmm1, [p.v_pixelIn]
            ; 2. Déballer les octets (Unpack) en entiers 16 bits, puis 32 bits
            !punpcklbw xmm1, xmm4     ; Convertit les octets en Word 16 bits
            !punpcklwd xmm1, xmm4     ; Convertit en DWord 32 bits
            ; 3. Convertir les entiers 32 bits en Flottants (Single Precision)
            !cvtdq2ps xmm1, xmm1      ; xmm1 contient maintenant [A.f, R.f, G.f, B.f]
            ; 4. Charger le coefficient du noyau et le dupliquer sur les 4 slots
            !movss xmm2, [p.v_kernel_val]
            !shufps xmm2, xmm2, 0     ; xmm2 contient [val, val, val, val]
            ; 5. Multiplier le pixel par le poids du noyau
            !mulps xmm1, xmm2
            ; 6. Accumuler le résultat dans xmm0
            !addps xmm0, xmm1
        Next
        ; --- Finalisation du pixel ---
        ; 1. Reconvertir les flottants accumulés en entiers 32 bits (avec arrondi)
        !movups xmm3,xmm0
          !cvtps2dq xmm3, xmm3
          ; 2. Réemballer les dwords en mots, puis en octets
          !packssdw xmm3, xmm3
          !packuswb xmm3, xmm3
          ; 3. Stocker le résultat 32 bits ARGB dans la variable
          !movd [p.v_pixelOut], xmm3
        ; Forcer l'alpha à $FF (Opacité totale) si nécessaire comme dans votre code d'origine
        *dst\l[posOffset + x] = $FF000000 | (pixelOut & $00FFFFFF)
      Next
    Next
  EndWith
EndProcedure


Procedure GaussianBlur_Conv_V_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray = \addr[0]
    Protected *dst.PixelArray = \addr[1]
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected x, y, k, i
    Protected *kernel.FloatArray = \addr[2]
    Protected radius = \option[0]
    Protected hMinus1 = h - 1
    
    macro_calul_tread(h)
    
    Protected pixelIn.l, pixelOut.l
    Protected kernel_val.f
    
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        !pxor xmm0, xmm0 ; Nettoyage de l'accumulateur
        !pxor xmm4 , xmm4
        For k = -radius To radius
          i = y + k
          If i < 0 : i = 0 : ElseIf i > hMinus1 : i = hMinus1 : EndIf
          pixelIn = *src\l[i * w + x]
          kernel_val = *kernel\f[k + radius]
            !movd xmm1, [p.v_pixelIn] ; getrgb(*src\l[i * w + x], r1, g1, b1)
            !punpcklbw xmm1, xmm4    
            !punpcklwd xmm1, xmm4     
            !cvtdq2ps xmm1, xmm1      
            !movss xmm2, [p.v_kernel_val]
            !shufps xmm2, xmm2, 0     
            !mulps xmm1, xmm2
            !addps xmm0, xmm1
        Next
          !movups xmm3,xmm0
          !cvtps2dq xmm3, xmm3
          !packssdw xmm3, xmm3
          !packuswb xmm3, xmm3
          !movd [p.v_pixelOut], xmm3
        *dst\l[y * w + x] = $FF000000 | (pixelOut & $00FFFFFF)
      Next
    Next
  EndWith
EndProcedure

Procedure GaussianBlur_Conv_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.Pixelarray = \addr[0]
    Protected *dst.Pixelarray = \addr[1]
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected x, y, k, i, posOffset
    Protected r.f, g.f, b.f
    Protected r1, g1, b1
    Protected *kernel.FloatArray = \addr[2] ; Optimisation : Pointeur structuré
    Protected radius = \option[0]
    Protected wMinus1 = w - 1
    Protected var.f
    
    macro_calul_tread(h)
    
    For y = thread_start To thread_stop - 1
      posOffset = y * w 
      For x = 0 To w - 1
        r = 0 : g = 0 : b = 0
        For k = -radius To radius
          i = x + k
          If i < 0 : i = 0 : ElseIf i > wMinus1 : i = wMinus1 : EndIf
          getrgb(*src\l[posOffset + i], r1, g1, b1)
          var = *kernel\f[k + radius]
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
    Protected *src.Pixelarray = \addr[0]
    Protected *dst.Pixelarray = \addr[1]
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected x, y, k, i
    Protected r.f, g.f, b.f
    Protected r1, g1, b1
    Protected *kernel.FloatArray = \addr[2] ; Optimisation : Pointeur structuré
    Protected radius = \option[0]
    Protected hMinus1 = h - 1
    Protected var.f
    Protected current_pixel_offset
    
    macro_calul_tread(h)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        r = 0 : g = 0 : b = 0
        For k = -radius To radius
          i = y + k
          If i < 0 : i = 0 : ElseIf i > hMinus1 : i = hMinus1 : EndIf
          
          ; Optimisation du calcul d'index : i * w + x
          getrgb(*src\l[i * w + x], r1, g1, b1)
          
          var = *kernel\f[k + radius]
          r + r1 * var
          g + g1 * var
          b + b1 * var
        Next
        *dst\l[y * w + x] = $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
  EndWith
EndProcedure

Macro GaussianBlur_ConvEx_sp(m1 , m2 , m3 , m4 , var)
  *FilterCtx\addr[m1] = m2
  *FilterCtx\addr[m3] = m4
  Create_MultiThread_MT(@GaussianBlur_Conv_#var)
EndMacro


Procedure GaussianBlur_ConvEx(*FilterCtx.FilterParams)
  Restore GaussianBlur_Conv_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
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
    
    If Not *kernel : FreeMemory(*tempo) : ProcedureReturn 0 : EndIf
    
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
    ;GaussianBlur_ConvEx_sp(1 , *tempo , 2 , *kernel , H_MT())
    ;\addr[1] = *tempo
    ;\addr[2] = *kernel
    ;Create_MultiThread_MT(@GaussianBlur_Conv_H_MT())
    
    ; === Passe verticale ===
    ;GaussianBlur_ConvEx_sp(0 , *tempo , 1 , *FilterCtx\image[1] , V_MT())
    ;\addr[0] = *tempo
    ;\addr[1] = \image[1]
    ;Create_MultiThread_MT(@GaussianBlur_Conv_V_MT())
    
    CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
      GaussianBlur_ConvEx_sp(1 , *tempo , 2 , *kernel , H_MT())
      GaussianBlur_ConvEx_sp(0 , *tempo , 1 , *FilterCtx\image[1] , V_MT())
    CompilerElse
      
      CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
        Select FilterCtx\Asm
          Case 1      
            GaussianBlur_ConvEx_sp(1 , *tempo , 2 , *kernel , H_MT_SSE2())
            GaussianBlur_ConvEx_sp(0 , *tempo , 1 , *FilterCtx\image[1] , V_MT_SSE2())
            ;Case 2 : StackBlurEx_select(SSE4)
            ;Case 3 : StackBlurEx_select(AVX2)
            ;Case 4 : StackBlurEx_select(AVX512)
          Default 
            GaussianBlur_ConvEx_sp(1 , *tempo , 2 , *kernel , H_MT())
            GaussianBlur_ConvEx_sp(0 , *tempo , 1 , *FilterCtx\image[1] , V_MT())
        EndSelect
        
      CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
        
        Select FilterCtx\Asm
          Case 100
          Default
            GaussianBlur_ConvEx_sp(1 , *tempo , 2 , *kernel , H_MT())
            GaussianBlur_ConvEx_sp(0 , *tempo , 1 , *FilterCtx\image[1] , V_MT())
        EndSelect
        
      CompilerEndIf
      
    CompilerEndIf
  
  
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
; CursorPosition = 81
; FirstLine = 44
; Folding = --
; EnableXP
; DPIAware