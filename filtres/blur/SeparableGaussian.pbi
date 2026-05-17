; =================================================================
; FILTRE : SEPARABLE GAUSSIAN BLUR
; =================================================================

; --- Utilitaires de noyau ---

Procedure CreateGaussianKernel_Sep(Array kernel.f(1), radius.l, sigma.f)
  If sigma <= 0.0 : sigma = radius / 3.0 : EndIf
  
  Protected radius_opt = Int(sigma * 3.0 + 0.5)
  If radius_opt < radius : radius = radius_opt : EndIf
  If radius < 1 : radius = 1 : EndIf
  
  Protected size = radius * 2 + 1
  Dim kernel(size - 1)
  
  Protected sigma2.f = 2.0 * sigma * sigma
  Protected sum.f = 0.0
  Protected i, x
  
  For i = 0 To size - 1
    x = i - radius
    kernel(i) = Exp(-(x * x) / sigma2)
    sum + kernel(i)
  Next
  
  If sum > 0.0
    For i = 0 To size - 1
      kernel(i) / sum
    Next
  EndIf
EndProcedure

Procedure.i CalcEffectiveRadius(radius.l, sigma.f)
  If sigma <= 0.0 : sigma = radius / 3.0 : EndIf
  Protected r = Int(sigma * 3.0 + 0.5)
  If r < radius : radius = r : EndIf
  If radius < 1 : radius = 1 : EndIf
  ProcedureReturn radius
EndProcedure

; --- Procédures de traitement Multi-Thread ---

Procedure SeparableGaussian_X_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected sigma.f = \option[1] / 10.0
    Protected radius = CalcEffectiveRadius(\option[0], sigma)
    
    Protected size = radius * 2 + 1
    Dim kernel.f(size - 1)
    CreateGaussianKernel_Sep(kernel(), radius, sigma)
    
    Protected x, y, dx, px, index, value
    Protected a.i, r.i, g.i, b.i ; Variables entières pour l'extraction
    Protected sumA.f, sumR.f, sumG.f, sumB.f
    Protected k.f
    
    Protected Dim lineA.f(lg - 1)
    Protected Dim lineR.f(lg - 1)
    Protected Dim lineG.f(lg - 1)
    Protected Dim lineB.f(lg - 1)
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      ; 1. Lecture de la ligne et conversion propre en Float
      For x = 0 To lg - 1
        index = (y * lg + x) << 2
        value = PeekL(\addr[0] + index)
        
        ; Extraction en entier d'abord (Important pour PB)
        a = (value >> 24) & $FF
        r = (value >> 16) & $FF
        g = (value >> 8)  & $FF
        b = value & $FF
        
        ; Puis passage en flottant
        lineA(x) = a
        lineR(x) = r
        lineG(x) = g
        lineB(x) = b
      Next
      
      ; 2. Convolution horizontale
      For x = 0 To lg - 1
        sumA = 0.0 : sumR = 0.0 : sumG = 0.0 : sumB = 0.0
        For dx = -radius To radius
          px = x + dx
          If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
          k = kernel(dx + radius)
          sumA + lineA(px) * k
          sumR + lineR(px) * k
          sumG + lineG(px) * k
          sumB + lineB(px) * k
        Next
        
        ; 3. Recomposition ARGB
        PokeL(\addr[1] + ((y * lg + x) << 2), (Int(sumA + 0.5) << 24) | (Int(sumR + 0.5) << 16) | (Int(sumG + 0.5) << 8) | Int(sumB + 0.5))
      Next
    Next
  EndWith
EndProcedure

Procedure SeparableGaussian_Y_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected sigma.f = \option[1] / 10.0
    Protected radius = CalcEffectiveRadius(\option[0], sigma)
    
    Protected size = radius * 2 + 1
    Dim kernel.f(size - 1)
    CreateGaussianKernel_Sep(kernel(), radius, sigma)
    
    Protected x, y, dy, py, index, value
    Protected a.i, r.i, g.i, b.i
    Protected sumA.f, sumR.f, sumG.f, sumB.f
    Protected k.f
    
    Protected Dim colA.f(ht - 1)
    Protected Dim colR.f(ht - 1)
    Protected Dim colG.f(ht - 1)
    Protected Dim colB.f(ht - 1)
    
    macro_calul_tread(lg)
    
    For x = thread_start To thread_stop - 1
      ; 1. Lecture de la colonne et conversion propre en Float
      For y = 0 To ht - 1
        index = (y * lg + x) << 2
        value = PeekL(\addr[0] + index)
        
        a = (value >> 24) & $FF
        r = (value >> 16) & $FF
        g = (value >> 8)  & $FF
        b = value & $FF
        
        colA(y) = a
        colR(y) = r
        colG(y) = g
        colB(y) = b
      Next
      
      ; 2. Convolution verticale
      For y = 0 To ht - 1
        sumA = 0.0 : sumR = 0.0 : sumG = 0.0 : sumB = 0.0
        For dy = -radius To radius
          py = y + dy
          If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
          k = kernel(dy + radius)
          sumA + colA(py) * k
          sumR + colR(py) * k
          sumG + colG(py) * k
          sumB + colB(py) * k
        Next
        
        PokeL(\addr[1] + ((y * lg + x) << 2), (Int(sumA + 0.5) << 24) | (Int(sumR + 0.5) << 16) | (Int(sumG + 0.5) << 8) | Int(sumB + 0.5))
      Next
    Next
  EndWith
EndProcedure

; --- Gestion du cycle du filtre ---

Procedure SeparableGaussian_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected *tmp = AllocateMemory(lg * ht * 4)
    If Not *tmp : ProcedureReturn : EndIf
    
    Protected *original_src = \addr[0]
    Protected *original_dst = \addr[1]
    
    ; Passe Horizontale : Source -> Tmp
    \addr[0] = *original_src
    \addr[1] = *tmp
    Create_MultiThread_MT(@SeparableGaussian_X_MT())
    
    ; Passe Verticale : Tmp -> Destination
    \addr[0] = *tmp
    \addr[1] = *original_dst
    Create_MultiThread_MT(@SeparableGaussian_Y_MT())
    
    FreeMemory(*tmp)
    \addr[0] = *original_src ; Restauration des pointeurs originaux
    \addr[1] = *original_dst
  EndWith
EndProcedure

Procedure SeparableGaussianEx(*FilterCtx.FilterParams)
  Restore SeparableGaussian_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Logique de sécurité sur les paramètres
    If \option[0] < 1 : \option[0] = 1 : EndIf
    If \option[1] = 0 : \option[1] = \option[0] * 10 / 3 : EndIf
    
    Protected sigma_real.f = \option[1] / 10.0
    Protected radius_max = Int(sigma_real * 3.0 + 0.5)
    If radius_max > 50 : radius_max = 50 : EndIf
    If \option[0] > radius_max : \option[0] = radius_max : EndIf
    
    ; Exécution
    SeparableGaussian_sp(*FilterCtx)
    
    ; Application finale (Masque)
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure SeparableGaussian(source, cible, mask, rayon, sigma_x10)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = sigma_x10
  EndWith
  SeparableGaussianEx(FilterCtx.FilterParams)
EndProcedure

; --- Métadonnées ---

DataSection
  SeparableGaussian_data:
  Data.s "SeparableGaussian"
  Data.s "Flou gaussien haute performance (Sépare les axes X et Y)"
  Data.i #FilterType_Blur
  Data.i #Blur_Gaussian
  
  Data.s "Rayon (px)"
  Data.i 1, 50, 5
  Data.s "Sigma x10 (0=auto)"
  Data.i 0, 100, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 239
; FirstLine = 188
; Folding = --
; EnableXP
; DPIAware