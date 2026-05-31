; --- Macros de calcul (conservées) ---

Macro Bilateral_DomainTransform1D_declare(length)
  Protected *buf = *FilterCtx\addr[0]
  Protected *temp = *FilterCtx\addr[1]
  Protected *expLUT = *FilterCtx\addr[2]
  Protected Dim domain.f(length)
  Protected Dim dc.f(length)
  Protected Dim dataR.f(length)
  Protected Dim dataG.f(length)
  Protected Dim dataB.f(length)
  Protected i.i, idx.i
  Protected diff_d.f, alpha.f, frac.f, a0.f, a1.f
  Protected pixel0.i, r0, g0, b0, r1, g1, b1
  Protected *scr1.pixel32
  Protected *scr2.pixel32
EndMacro

Macro Bilateral_DomainTransform1D_end()
  FreeArray(domain())
  FreeArray(dc())
  FreeArray(dataR())
  FreeArray(dataG())
  FreeArray(dataB())
EndMacro

Macro Bilateral_DomainTransform1D_sp0(op)
  If diff_d < 0 : diff_d = 0 : ElseIf diff_d > 255 : diff_d = 255 : EndIf
  idx = Int(diff_d)
  frac = diff_d - idx
  a0 = PeekF(*expLUT + (idx << 2))
  a1 = PeekF(*expLUT + ((idx + Bool(idx < 255)) << 2))
  alpha = a0 + frac * (a1 - a0)
  dataR(i) + alpha * (dataR(i op 1) - dataR(i))
  dataG(i) + alpha * (dataG(i op 1) - dataG(i))
  dataB(i) + alpha * (dataB(i op 1) - dataB(i))
EndMacro

Macro Bilateral_DomainTransform1D_sp1(v1)
  *scr1 = *source + (i * v1)
  *scr2 = *scr1 + v1
  GetRGB(*scr1\l, r0, g0, b0)
  GetRGB(*scr2\l, r1, g1, b1)
  dataR(i) = r0 : dataG(i) = g0 : dataB(i) = b0
  Protected dr = r1 - r0
  Protected dg = g1 - g0
  Protected db = b1 - b0
  dc(i) = Sqr(0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db)
  If dc(i) > 255 : dc(i) = 255 : EndIf
EndMacro

; --- Procédures MT ---

Procedure Bilateral_DomainTransform1D_X(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected length = \image_lg[0]
    Bilateral_DomainTransform1D_declare(length)
    Protected y, pos
    Protected lengthMinus1 = length - 1
    Protected lengthMinus2 = length - 2
    Protected sigma_color_factor.f = \option[4]
    
    macro_calul_tread(\image_ht[0])
    
    For y = thread_start To thread_stop - 1
      pos = y * length << 2
      Protected *source = *buf + pos
      
      For i = 0 To lengthMinus2
        Bilateral_DomainTransform1D_sp1(4)
      Next
      
      i = lengthMinus1
      pixel0 = PeekL(*source + (lengthMinus1 << 2))
      GetRGB(pixel0, r0, g0, b0)
      dataR(i) = r0 : dataG(i) = g0 : dataB(i) = b0
      
      domain(0) = 0
      For i = 1 To lengthMinus1
        domain(i) = domain(i - 1) + 1.0 + sigma_color_factor * dc(i - 1)
        If domain(i) < domain(i - 1) : domain(i) = domain(i - 1) : EndIf
      Next
      
      For i = 1 To lengthMinus1
        diff_d = domain(i) - domain(i - 1)
        Bilateral_DomainTransform1D_sp0(-)
      Next
      
      For i = lengthMinus2 To 0 Step -1
        diff_d = domain(i + 1) - domain(i)
        Bilateral_DomainTransform1D_sp0(+)
      Next
      
      For i = 0 To lengthMinus1
        r0 = dataR(i) : g0 = dataG(i) : b0 = dataB(i)
        clamp_rgb(r0, g0, b0)
        PokeL(*temp + pos + (i << 2), (Int(r0) << 16) | (Int(g0) << 8) | Int(b0))
      Next
    Next
    Bilateral_DomainTransform1D_end()
  EndWith
EndProcedure

Procedure Bilateral_DomainTransform1D_Y(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected length = \image_ht[0]
    Bilateral_DomainTransform1D_declare(length)
    Protected stride = \image_lg[0] << 2
    Protected x, y
    Protected lengthMinus1 = length - 1
    Protected lengthMinus2 = length - 2
    Protected sigma_color_factor.f = \option[4]
    
    macro_calul_tread(\image_lg[0])
    
    For x = thread_start To thread_stop - 1
      Protected *source = *buf + (x << 2)
      
      For i = 0 To lengthMinus2
        Bilateral_DomainTransform1D_sp1(stride)
      Next
      
      i = lengthMinus1
      pixel0 = PeekL(*source + lengthMinus1 * stride)
      GetRGB(pixel0, r0, g0, b0)
      dataR(i) = r0 : dataG(i) = g0 : dataB(i) = b0
      
      domain(0) = 0
      For i = 1 To lengthMinus1
        domain(i) = domain(i - 1) + 1.0 + sigma_color_factor * dc(i - 1)
        If domain(i) < domain(i - 1) : domain(i) = domain(i - 1) : EndIf
      Next
      
      For i = 1 To lengthMinus1
        diff_d = domain(i) - domain(i - 1)
        Bilateral_DomainTransform1D_sp0(-)
      Next
      
      For i = lengthMinus2 To 0 Step -1
        diff_d = domain(i + 1) - domain(i)
        Bilateral_DomainTransform1D_sp0(+)
      Next
      
      For i = 0 To lengthMinus1
        r0 = dataR(i) : g0 = dataG(i) : b0 = dataB(i)
        clamp_rgb(r0, g0, b0)
        PokeL(*temp + (x << 2) + i * stride, (Int(r0) << 16) | (Int(g0) << 8) | Int(b0))
      Next
    Next
    Bilateral_DomainTransform1D_end()
  EndWith
EndProcedure

; --- Gestion du cycle du filtre ---

Procedure BilateralEx(*FilterCtx.FilterParams)
  Restore Bilateral_data
  Protected last_data = Filter_InitAndValidate()
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
      PokeF(\addr[2] + (d << 2), Exp(-d * invSigmaColor))
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
    
    ; Boucle de passes
    For d = 1 To pass
      ; Passe X (Source -> Tempo)
      \addr[0] = *buf_src
      \addr[1] = *tempo
      Create_MultiThread_MT(@Bilateral_DomainTransform1D_X())
      
      ; Passe Y (Tempo -> Cible)
      \addr[0] = *tempo
      \addr[1] = *buf_final
      Create_MultiThread_MT(@Bilateral_DomainTransform1D_Y())
      
      ; Pour la passe suivante, la source devient la cible actuelle
      *buf_src = *buf_final
    Next
    
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
; CursorPosition = 5
; Folding = --
; Optimizer
; EnableXP
; DPIAware
; DisableDebugger
; Compiler = PureBasic 6.21 - C Backend (Windows - x64)