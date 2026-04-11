Macro Bilateral_DomainTransform1D_declare(length)
  Protected *buf = *param\addr[0]
  Protected *temp = *param\addr[1]
  Protected *expLUT = *param\addr[2]
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
  clamp(diff_d, 0, 255)
  idx = Int(diff_d)
  frac = diff_d - idx
  a0 = PeekF(*expLUT + (idx << 2))  ; Bit shift
  ; Simplification du clamping pour idx+1
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
  ; Optimisation du calcul de différence
  Protected dr = r1 - r0
  Protected dg = g1 - g0
  Protected db = b1 - b0
  dc(i) = Sqr(0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db)
  If dc(i) > 255 : dc(i) = 255 : EndIf
EndMacro

Procedure Bilateral_DomainTransform1D_X(*param.parametre)
  Protected length = *param\lg
  Bilateral_DomainTransform1D_declare(length)
  Protected y, pos
  Protected lengthMinus1 = length - 1
  Protected lengthMinus2 = length - 2
  Protected sigma_color_factor.f = *param\option[4]
  
  macro_calul_tread(*param\ht)
  
  For y = thread_start To thread_stop - 1
    pos = y * length << 2  ; Bit shift
    Protected *source = *buf + pos
    
    ; Calcul des différences de couleur horizontales
    For i = 0 To lengthMinus2
      Bilateral_DomainTransform1D_sp1(4)
    Next
    
    ; Dernier pixel de la ligne
    i = lengthMinus1
    pixel0 = PeekL(*source + (lengthMinus1 << 2))
    GetRGB(pixel0, r0, g0, b0)
    dataR(i) = r0 : dataG(i) = g0 : dataB(i) = b0
    
    ; Calcul du domaine cumulatif
    domain(0) = 0
    For i = 1 To lengthMinus1
      domain(i) = domain(i - 1) + 1.0 + sigma_color_factor * dc(i - 1)
      If domain(i) < domain(i - 1) : domain(i) = domain(i - 1) : EndIf
    Next
    
    ; Filtrage récursif avant-arrière
    For i = 1 To lengthMinus1
      diff_d = domain(i) - domain(i - 1)
      Bilateral_DomainTransform1D_sp0(-)
    Next
    
    For i = lengthMinus2 To 0 Step -1
      diff_d = domain(i + 1) - domain(i)
      Bilateral_DomainTransform1D_sp0(+)
    Next
    
    ; Stockage final dans le buffer temporaire
    For i = 0 To lengthMinus1
      r0 = dataR(i) : g0 = dataG(i) : b0 = dataB(i)
      clamp_rgb(r0, g0, b0)
      PokeL(*temp + pos + (i << 2), (r0 << 16) | (g0 << 8) | b0)
    Next
  Next
  
  Bilateral_DomainTransform1D_end()
EndProcedure

Procedure Bilateral_DomainTransform1D_Y(*param.parametre)
  Protected length = *param\ht
  Bilateral_DomainTransform1D_declare(length)
  Protected stride = *param\lg << 2  ; Bit shift
  Protected start, stop, x
  Protected lengthMinus1 = length - 1
  Protected lengthMinus2 = length - 2
  Protected sigma_color_factor.f = *param\option[4]
  
  start = (*param\thread_pos * *param\lg) / *param\thread_max
  stop = ((*param\thread_pos + 1) * *param\lg) / *param\thread_max
  If stop > *param\lg : stop = *param\lg : EndIf
  
  For x = start To stop - 1
    Protected *source = *buf + (x << 2)
    
    ; Calcul des différences de couleur verticales
    For i = 0 To lengthMinus2
      Bilateral_DomainTransform1D_sp1(stride)
    Next
    
    ; Dernier pixel de la colonne
    i = lengthMinus1
    pixel0 = PeekL(*source + lengthMinus1 * stride)
    GetRGB(pixel0, r0, g0, b0)
    dataR(i) = r0 : dataG(i) = g0 : dataB(i) = b0
    
    ; Calcul du domaine cumulatif vertical
    domain(0) = 0
    For i = 1 To lengthMinus1
      domain(i) = domain(i - 1) + 1.0 + sigma_color_factor * dc(i - 1)
      If domain(i) < domain(i - 1) : domain(i) = domain(i - 1) : EndIf
    Next
    
    ; Filtrage récursif
    For i = 1 To lengthMinus1
      diff_d = domain(i) - domain(i - 1)
      Bilateral_DomainTransform1D_sp0(-)
    Next
    
    For i = lengthMinus2 To 0 Step -1
      diff_d = domain(i + 1) - domain(i)
      Bilateral_DomainTransform1D_sp0(+)
    Next
    
    ; Stockage final
    For i = 0 To lengthMinus1
      r0 = dataR(i) : g0 = dataG(i) : b0 = dataB(i)
      clamp_rgb(r0, g0, b0)
      PokeL(*temp + (x << 2) + i * stride, (r0 << 16) | (g0 << 8) | b0)
    Next
  Next
  
  Bilateral_DomainTransform1D_end()
EndProcedure

Procedure Bilateral(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_EdgeAware
    *param\name = "Bilateral"
    *param\remarque = "Adoucit tout en conservant les contours nets"
    *param\info[0] = "Nb de passes"
    *param\info[1] = "Sigma espace"
    *param\info[2] = "Sigma couleur"
    *param\info[3] = "Masque binaire"
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 5   : *param\info_data(0,2) = 2
    *param\info_data(1,0) = 1 : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 40
    *param\info_data(2,0) = 1 : *param\info_data(2,1) = 100 : *param\info_data(2,2) = 30
    *param\info_data(3,0) = 0 : *param\info_data(3,1) = 2   : *param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  
  Protected pass = *param\option[0]
  Protected sigma_space.f = *param\option[1]
  Protected sigma_color.f = *param\option[2]
  
  Clamp(pass, 1, 5)
  Clamp(sigma_space, 1, 100)
  Clamp(sigma_color, 1, 255)
  
  ; LUT exponentielle pour la couleur
  Protected *expLUT = AllocateMemory(256 << 2)  ; Bit shift
  If *expLUT = 0 : ProcedureReturn : EndIf
  
  Protected d
  Protected invSigmaColor.f = 1.0 / sigma_color  ; Précalcul inverse
  
  For d = 0 To 255
    PokeF(*expLUT + (d << 2), Exp(-d * invSigmaColor))
  Next
  
  *param\addr[2] = *expLUT
  *param\option[4] = sigma_space * invSigmaColor  ; Réutilisation de l'inverse
  
  ; Buffer temporaire pour stockage intermédiaire
  Protected total = *param\lg * *param\ht << 2
  Protected *tempo = AllocateMemory(total)
  If *tempo = 0
    FreeMemory(*expLUT)
    ProcedureReturn
  EndIf
  
  Protected *buf = *param\source
  
  For d = 0 To pass - 1
    *param\addr[0] = *buf
    *param\addr[1] = *tempo
    MultiThread_MT(@Bilateral_DomainTransform1D_X())
    
    *param\addr[0] = *tempo
    *param\addr[1] = *param\cible
    MultiThread_MT(@Bilateral_DomainTransform1D_Y())
    
    *buf = *param\cible
  Next
  
  ; Application du masque éventuel
  macro_Filter_BufferFinalize(3)
  
  ; Libération de la mémoire
  FreeMemory(*expLUT)
  FreeMemory(*tempo)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 228
; FirstLine = 159
; Folding = --
; Optimizer
; EnableXP
; DPIAware
; DisableDebugger
; Compiler = PureBasic 6.21 - C Backend (Windows - x64)