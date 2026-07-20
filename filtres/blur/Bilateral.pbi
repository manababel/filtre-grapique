
Macro Bilateral_DomainTransform1D_sp0_pb(op)
  clamp(diff_d , 0 , 255)
  idx = Int(diff_d)
  frac = diff_d - idx
  a0 = PeekF(*expLUT + (idx << 2))
  a1 = PeekF(*expLUT + ((idx + Bool(idx < 255)) << 2))
  alpha = a0 + frac * (a1 - a0)
  Data_argb(i)\r + alpha * (Data_argb(i op 1)\r - Data_argb(i)\r)
  Data_argb(i)\g + alpha * (Data_argb(i op 1)\g - Data_argb(i)\g)
  Data_argb(i)\b + alpha * (Data_argb(i op 1)\b - Data_argb(i)\b)
EndMacro



Macro Bilateral_DomainTransform1D_sp1_pb()
  GetRGB(*source\l[pos1], r0, g0, b0)
  GetRGB(*source\l[pos2], r1, g1, b1)
  Data_argb(i)\r = r0 : Data_argb(i)\g = g0 : Data_argb(i)\b = b0
  dr = r1 - r0
  dg = g1 - g0
  db = b1 - b0
  dc(i) = 0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db
  If dc(i) > 255.0 : dc(i) = 255.0 : EndIf
EndMacro

; --- Procédures MT ---

Procedure Bilateral_DomainTransform1D_X_pb(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.pixelarray = \addr[0]
    Protected *cible.pixelarray  = \addr[1]
    Protected *expLUT = *FilterCtx\addr[2]
    Protected lg = \image_lg[0]
    Protected Dim domain.f(lg)
    Protected Dim dc.f(lg)
    Protected i.i, idx.i
    Protected diff_d.f, alpha.f, frac.f, a0.f, a1.f
    Protected.l pixel0, r0, g0, b0, r1, g1, b1
    Protected y , pos1 , pos2
    Protected lengthMinus1 = lg - 1
    Protected lengthMinus2 = lg - 2
    Protected sigma_color_factor.f = \option[4]
    Protected.l dr , dg , db
    Protected Dim Data_argb.PixelVec(lg)
    
    macro_calul_tread(\image_ht[0])
    
    For y = thread_start To thread_stop - 1

      For i = 0 To lengthMinus2
        pos1 = (y * lg + i )
        pos2 = pos1 + 1
        Bilateral_DomainTransform1D_sp1_pb()
      Next
      
      i = lengthMinus1
      getrgb(*source\l[y * lg + lengthMinus1] , r0 , g0 , b0)
      Data_argb(i)\r = r0 : Data_argb(i)\g = g0 : Data_argb(i)\b = b0
      
      domain(0) = 0
      For i = 1 To lengthMinus1
        domain(i) = domain(i - 1) + 1.0 + sigma_color_factor * dc(i - 1)
        If domain(i) < domain(i - 1) : domain(i) = domain(i - 1) : EndIf
      Next
      
      For i = 1 To lengthMinus1
        diff_d = domain(i) - domain(i - 1)
        Bilateral_DomainTransform1D_sp0_pb(-)
      Next
      
      For i = lengthMinus2 To 0 Step -1
        diff_d = domain(i + 1) - domain(i)
        Bilateral_DomainTransform1D_sp0_pb(+)
      Next
      
      For i = 0 To lengthMinus1
        r0 = Data_argb(i)\r : g0 = Data_argb(i)\g : b0 = Data_argb(i)\b
        clamp_rgb(r0, g0, b0)
        *cible\l[y * lg + i] = (r0 << 16) | (g0 << 8) | b0
      Next
    Next
    FreeArray(domain())
    FreeArray(dc())
  EndWith
EndProcedure

Procedure Bilateral_DomainTransform1D_Y_pb(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.pixelarray = \addr[0]
    Protected *cible.pixelarray  = \addr[1]
    Protected *expLUT = *FilterCtx\addr[2]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected Dim domain.f(ht)
    Protected Dim dc.f(ht)
    Protected i.i, idx.i
    Protected diff_d.f, alpha.f, frac.f, a0.f, a1.f
    Protected.l pixel0, r0, g0, b0, r1, g1, b1
    Protected stride = \image_lg[0] << 2
    Protected x, y , pos1 , pos2
    Protected lengthMinus1 = ht - 1
    Protected lengthMinus2 = ht - 2
    Protected sigma_color_factor.f = \option[4]
    Protected.l dr , dg , db
    Protected Dim Data_argb.PixelVec(ht)
    macro_calul_tread(\image_lg[0])
    
    For x = thread_start To thread_stop - 1
      
      For i = 0 To lengthMinus2
        pos1 = lg * i + x
        pos2 = pos1 + lg
        Bilateral_DomainTransform1D_sp1_pb()
      Next
      
      i = lengthMinus1
      getRGB(*source\l[ lengthMinus1 * lg + x] , r0 , g0 , b0)
      Data_argb(i)\r = r0 : Data_argb(i)\g = g0 : Data_argb(i)\b = b0
      
      domain(0) = 0
      For i = 1 To lengthMinus1
        domain(i) = domain(i - 1) + 1.0 + sigma_color_factor * dc(i - 1)
        If domain(i) < domain(i - 1) : domain(i) = domain(i - 1) : EndIf
      Next
      
      For i = 1 To lengthMinus1
        diff_d = domain(i) - domain(i - 1)
        Bilateral_DomainTransform1D_sp0_pb(-)
      Next
      
      For i = lengthMinus2 To 0 Step -1
        diff_d = domain(i + 1) - domain(i)
        Bilateral_DomainTransform1D_sp0_pb(+)
      Next
      
      For i = 0 To lengthMinus1
        r0 = Data_argb(i)\r : g0 = Data_argb(i)\g : b0 = Data_argb(i)\b
        clamp_rgb(r0, g0, b0)
        *cible\l[i * \image_lg[0]  + x] = (r0 << 16) | (g0 << 8) |  b0
      Next
    Next
    FreeArray(domain())
    FreeArray(dc())
  EndWith
EndProcedure



Macro BilateralEx_sp(opt)
  For d = 1 To pass
    ; Passe X (Source -> Tempo)
    *FilterCtx\addr[0] = *buf_src
    *FilterCtx\addr[1] = *tempo
    Create_MultiThread_MT(@Bilateral_DomainTransform1D_X_#opt())
    ; Passe Y (Tempo -> Cible)
    *FilterCtx\addr[0] = *tempo
    *FilterCtx\addr[1] = *buf_final
    Create_MultiThread_MT(@Bilateral_DomainTransform1D_Y_#opt())
    
    ; Pour la passe suivante, la source devient la cible actuelle
    *buf_src = *buf_final
  Next
EndMacro



Procedure BilateralEx(*FilterCtx.FilterParams)
  Restore Bilateral_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Initialisation des paramètres
    Protected pass = \option[0]
    Protected sigma_space.f = \option[1]
    Protected sigma_color.f = \option[2]
    
    If pass < 1 : pass = 1 : EndIf
    If sigma_color < 1 : sigma_color = 1 : EndIf
    
    ; LUT exponentielle
    \addr[2] = AllocateMemory(256 << 2)
    If \addr[2] = 0 : ProcedureReturn 0 : EndIf
    
    Protected d
    Protected invSigmaColor.f = 1.0 / sigma_color
    For d = 0 To 255
      PokeF(\addr[2] + (d << 2), Exp(-Sqr(d) * invSigmaColor))
    Next
    
    \option[4] = sigma_space * invSigmaColor
    
    ; Buffer temporaire
    Protected total = \image_lg[0] * \image_ht[0] << 2
    Protected *tempo = AllocateMemory(total)
    If *tempo = 0
      FreeMemory(\addr[2]) : ProcedureReturn 0
    EndIf
    
    Protected *buf_src = \addr[0]
    Protected *buf_final = \addr[1]
    
    CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
      BilateralEx_sp(PB) ; version pb pour la version 32bits
    CompilerElse
      
      CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
        Select FilterCtx\Asm
          Case 1 : BilateralEx_sp(SSE2)
          ;Case 2 : BilateralEx_sp()
          ;Case 3 : BilateralEx_sp()
          ;Case 4 : BilateralEx_sp()
          Default :BilateralEx_sp(PB)
        EndSelect
      CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
        Select FilterCtx\Asm
            ;Case 1 : Create_MultiThread_MT(name_SSE2())
            ;Case 2 : Create_MultiThread_MT(Mname_SSE4())
            ;Case 3 : Create_MultiThread_MT(name_AVX())
            ;Case 4 : Create_MultiThread_MT(name_AVX512())
          Case 100
          Default :BilateralEx_sp(PB)
        EndSelect
      CompilerEndIf
    CompilerEndIf
  
  
    ; Nettoyage
    FreeMemory(\addr[2])
    FreeMemory(*tempo)
    \addr[2] = 0
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Bilateral(source, cible, mask, pass, sigma_space, sigma_color)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = pass
    \option[1] = sigma_space
    \option[2] = sigma_color
  EndWith
  BilateralEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Bilateral_data:
  Data.s "Bilateral"
  Data.s "Lissage par transformation de domaine (Edge-Preserving)"
  Data.i #FilterType_Blur
  Data.i #Blur_EdgeAware
  
  Data.s "Nb de passes"
  Data.i 1, 5, 2
  Data.s "Sigma espace"
  Data.i 1, 100, 40
  Data.s "Sigma couleur"
  Data.i 1, 100, 30
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 22
; Folding = --
; Optimizer
; EnableXP
; DPIAware
; DisableDebugger
; Compiler = PureBasic 6.21 - C Backend (Windows - x64)