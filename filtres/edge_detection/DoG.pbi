; ===== Fonction pour générer un noyau gaussien (écrit dans un buffer de Float) =====
Procedure CreateGaussianKernel(*kernel, radius, sigma.f)
  Protected x, i, value.f, sum.f = 0.0
  If sigma <= 0.0 : sigma = 1.0 : EndIf
  If radius < 1 : radius = Int(sigma * 2) : EndIf
  Protected div.f = 2.0 * sigma * sigma
  ; Calcul du noyau (non normalisé)
  For x = -radius To radius
    value = Exp(-(x * x) / div)
    PokeF(*kernel + (x + radius) * 4, value)
    sum = sum + value
  Next
  ; Normalisation pour que la somme fasse 1.0
  If sum = 0.0 : sum = 1.0 : EndIf
  For i = 0 To 2 * radius
    value = PeekF(*kernel + i * 4) / sum
    PokeF(*kernel + i * 4, value)
  Next
EndProcedure

; ===== Flou gaussien en 1D (séparable) - version multi-thread =====
Procedure GaussianBlur1D_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    ; kernel en local (suffisamment grand pour radius ≤ 32)
    Protected Dim kernel.f(64)

    Protected *src = \addr[2]         ; source fournie via addr[2]
    Protected *dst = \addr[3]         ; destination fournie via addr[3]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    ; option[0] = sigma, option[9] = horizontal (Bool)
    Protected sigma.f = \option[0]
    Protected radius = Int(sigma * 2)
    Protected horizontal = \option[9]
    clamp(radius , 1 , 32)
    
    ; Génération du noyau
    CreateGaussianKernel(@kernel(), radius, sigma)
    
    Protected x, y, k, offset, idx
    Protected a , r , g, b
    Protected sumR.f, sumG.f, sumB.f
    Protected *srcPixel.Pixel32, *dstPixel.Pixel32
    
    macro_calul_tread((ht))
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0

        For k = -radius To radius
          If horizontal
            offset = x + k
            If offset < 0 : offset = 0
            ElseIf offset >= lg : offset = lg - 1
            EndIf
            idx = (y * lg + offset) * 4
          Else
            offset = y + k
            If offset < 0 : offset = 0
            ElseIf offset >= ht : offset = ht - 1
            EndIf
            idx = (offset * lg + x) * 4
          EndIf
          *srcPixel = *src + idx
          getargb(*srcPixel\l, a, r, g, b)
          ; accumulation (avec valeur du noyau)
          sumR = sumR + r * kernel(k + radius)
          sumG = sumG + g * kernel(k + radius)
          sumB = sumB + b * kernel(k + radius)
        Next
        ; écrire pixel flouté (on reconstruit l'ARGB)
        *dstPixel = *dst + (y * lg + x) * 4
        *dstPixel\l = (a << 24) | (Int(sumR + 0.5) << 16) | (Int(sumG + 0.5) << 8) | Int(sumB + 0.5)
      Next
    Next
    FreeArray(kernel())
  EndWith
EndProcedure

; ===== DoG Multi-thread (soustraction de deux images déjà floutées) =====
Procedure DoG_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *blur1 = \addr[2]
    Protected *blur2 = \addr[3]
    Protected *cible = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected math = \option[2]
    Protected toGray = \option[3]
    Protected inverse = \option[4]
    Protected seuillage = \option[5]
    Protected multiply = \option[6] + 10
    clamp(multiply, 0, 100)
    multiply = multiply * 0.05
    Protected x, y, a
    Protected r1, g1, b1, r2, g2, b2
    Protected *p1.Pixel32, *p2.Pixel32, *dst.Pixel32
    
    macro_calul_tread((ht))
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        *p1 = *blur1 + (y * lg + x) * 4
        *p2 = *blur2 + (y * lg + x) * 4
        getargb(*p1\l, a, r1, g1, b1)
        getrgb(*p2\l, r2, g2, b2)
        If Not math
          r1 = Abs(r1 - r2)
          g1 = Abs(g1 - g2)
          b1 = Abs(b1 - b2)
        Else
          r1 = Sqr(Abs(r1 * r1 - r2 * r2))
          g1 = Sqr(Abs(g1 * g1 - g2 * g2))
          b1 = Sqr(Abs(b1 * b1 - b2 * b2))
          clamp_rgb(r1 , g1 , b1)
        EndIf
        
        r1 * multiply
        g1 * multiply
        b1 * multiply
        
        If seuillage > 0
          If r1 > seuillage : r1 = 255 : Else : r1 = 0 : EndIf
          If g1 > seuillage : g1 = 255 : Else : g1 = 0 : EndIf
          If b1 > seuillage : b1 = 255 : Else : b1 = 0 : EndIf
        EndIf
        If toGray
          r1 = (r1 * 77 + g1 * 150 + b1 * 29) >> 8
          g1 = r1 : b1 = r1
        EndIf
        If inverse
          r1 = 255 - r1 : g1 = 255 - g1 : b1 = 255 - b1
        EndIf
        *dst = *cible + (y * lg + x) * 4
        *dst\l = (a << 24) | (Int(r1) << 16) | (Int(g1) << 8) | Int(b1)
      Next
    Next
  EndWith
EndProcedure

; ===== Enveloppe DoGEx (orchestration multi-thread) =====
Procedure DoGEx(*FilterCtx.FilterParams)
  Restore DoG_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  With *FilterCtx
    ; Buffer temporaire si source = cible
    Protected *tempo = 0
    If \addr[0] = \addr[1]
      *tempo = AllocateMemory(\image_lg[0] * \image_ht[0] * 4)
      If Not *tempo : ProcedureReturn : EndIf
      CopyMemory(\addr[0], *tempo, \image_lg[0] * \image_ht[0] * 4)
      \addr[4] = *tempo ; utilisation d'un slot libre pour le tempo
    Else
      \addr[4] = \addr[0]
    EndIf
    
    ; Buffers pour les flous
    Protected *blur1 = AllocateMemory(\image_lg[0] * \image_ht[0] * 4)
    Protected *blur2 = AllocateMemory(\image_lg[0] * \image_ht[0] * 4)
    If Not *blur1 Or Not *blur2
      If *tempo : FreeMemory(*tempo) : EndIf
      If *blur1 : FreeMemory(*blur1) : EndIf
      If *blur2 : FreeMemory(*blur2) : EndIf
      ProcedureReturn
    EndIf
    
    ; --- Flou sigma1 ---
    Protected original_sigma.f = \option[0]
    \addr[2] = \addr[4]
    \addr[3] = *blur1
    \option[9] = #True
    Create_MultiThread_MT(@GaussianBlur1D_MT())
    \addr[2] = *blur1
    \addr[3] = *blur1
    \option[9] = #False
    Create_MultiThread_MT(@GaussianBlur1D_MT())
    
    ; --- Flou sigma2 ---
    \option[0] = \option[1] ; sigma2
    \addr[2] = \addr[4]
    \addr[3] = *blur2
    \option[9] = #True
    Create_MultiThread_MT(@GaussianBlur1D_MT())
    \addr[2] = *blur2
    \addr[3] = *blur2
    \option[9] = #False
    Create_MultiThread_MT(@GaussianBlur1D_MT())
    
    ; Restaurer sigma1 pour la suite si besoin et configurer soustraction
    \option[0] = original_sigma
    \addr[2] = *blur1
    \addr[3] = *blur2
    Create_MultiThread_MT(@DoG_MT())
    
    mask_update(*FilterCtx , last_data)
    
    ; Libération mémoire
    If *tempo : FreeMemory(*tempo) : EndIf
    FreeMemory(*blur1)
    FreeMemory(*blur2)
  EndWith
EndProcedure

; ===== Procedure principale =====
Procedure DoG(source, cible, mask, sigma1, sigma2, math, noir_et_blanc, inversion, seuillage, multiply)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = sigma1
    \option[1] = sigma2
    \option[2] = math
    \option[3] = noir_et_blanc
    \option[4] = inversion
    \option[5] = seuillage
    \option[6] = multiply
  EndWith
  DoGEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  DoG_data:
  Data.s "DoG"
  Data.s "Difference of Gaussian"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Laplacian
  
  Data.s "sigma1"
  Data.i 1, 10, 1
  Data.s "sigma2"
  Data.i 2, 20, 5
  Data.s "math (ABS ou SQR)"
  Data.i 0, 1, 0
  Data.s "Noir et blanc"
  Data.i 0, 1, 0
  Data.s "inversion"
  Data.i 0, 1, 0
  Data.s "seuillage : 0 = off"
  Data.i 0, 255, 0
  Data.s "multiply"
  Data.i 0, 100, 10
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 207
; FirstLine = 194
; Folding = -
; EnableXP
; DPIAware