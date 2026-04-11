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
Procedure GaussianBlur1D_MT(*param.parametre)
  ; kernel en local (suffisamment grand pour radius ≤ 32)
  Protected Dim kernel.f(64)

  Protected *src = *param\addr[2]         ; source fournie via param.addr
  Protected *dst = *param\addr[3]         ; destination fournie via param.addr
  Protected lg = *param\lg
  Protected ht = *param\ht
  ; option[0] = sigma, option[9] = horizontal (Bool)
  Protected sigma.f = *param\option[0]
  Protected radius = Int(sigma * 2)
  Protected horizontal = *param\option[9]
  clamp(radius , 1 , 32)
  ; Génération du noyau (on passe l'adresse du tableau local)
  CreateGaussianKernel(@kernel(), radius, sigma)
  Protected x, y, k, offset, idx
  Protected a , r , g, b
  Protected sumR.f, sumG.f, sumB.f
  Protected *srcPixel.Pixel32, *dstPixel.Pixel32
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * ht) / *param\thread_max
  If startPos < 0 : startPos = 0 : EndIf
  If endPos > ht : endPos = ht : EndIf
  For y = startPos To endPos - 1
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
EndProcedure


; ===== DoG Multi-thread (soustraction de deux images déjà floutées) =====
Procedure DoG_MT(*param.parametre)
  Protected *blur1 = *param\addr[2]
  Protected *blur2 = *param\addr[3]
  Protected *cible = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected math = *param\option[2]
  Protected toGray = *param\option[3]
  Protected inverse = *param\option[4]
  Protected seuillage = *param\option[5]
  Protected multiply = *param\option[6] + 10
  clamp(multiply, 0, 100)
  multiply = multiply * 0.05
  Protected x, y, a
  Protected r1, g1, b1, r2, g2, b2
  Protected *p1.Pixel32, *p2.Pixel32, *dst.Pixel32
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * ht) / *param\thread_max
  If startPos < 0 : startPos = 0 : EndIf
  If endPos > ht : endPos = ht : EndIf
  For y = startPos To endPos - 1
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
EndProcedure

; ===== Enveloppe DoG (orchestration multi-thread) =====
Procedure DoG(*param.parametre)
  If param\info_active
    param\typ = #FilterType_EdgeDetection
    param\subtype = #EdgeDetect_Laplacian
    param\name = "DoG (programme buggé avec les threads)"
    param\remarque = "Difference of Gaussian"
    param\info[0] = "sigma1"
    param\info[1] = "sigma2"
    param\info[2] = "math (ABS ou SQR)"
    param\info[3] = "Noir et blanc"
    param\info[4] = "inversion"
    param\info[5] = "seuillage : 0 = off"
    param\info[6] = "multiply"
    param\info[7] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 10 : param\info_data(0,2) = 1
    param\info_data(1,0) = 2 : param\info_data(1,1) = 20 : param\info_data(1,2) = 5
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1  : param\info_data(2,2) = 0
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1  : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 1  : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 255: param\info_data(5,2) = 0
    param\info_data(6,0) = 0 : param\info_data(6,1) = 100: param\info_data(6,2) = 10
    param\info_data(7,0) = 0 : param\info_data(7,1) = 2   : param\info_data(7,2) = 0
    ProcedureReturn
  EndIf

  If *param\source = 0 Or *param\cible = 0
    ProcedureReturn
  EndIf

  ; Buffer temporaire si source = cible
  Protected *tempo = 0
  If *param\source = *param\cible
    *tempo = AllocateMemory(*param\lg * *param\ht * 4)
    If Not *tempo
      ProcedureReturn
    EndIf
    CopyMemory(*param\source, *tempo, *param\lg * *param\ht * 4)
    *param\addr[0] = *tempo
  Else
    *param\addr[0] = *param\source
  EndIf
  ; Buffers pour les flous
  Protected *blur1 = AllocateMemory(*param\lg * *param\ht * 4)
  Protected *blur2 = AllocateMemory(*param\lg * *param\ht * 4)
  If Not *blur1 Or Not *blur2
    If *tempo : FreeMemory(*tempo) : EndIf
    If *blur1 : FreeMemory(*blur1) : EndIf
    If *blur2 : FreeMemory(*blur2) : EndIf
    ProcedureReturn
  EndIf
  ; --- Flou sigma1 ---
  *param\option[0] = *param\option[0]  ; sigma1
  *param\addr[2] = *param\addr[0]
  *param\addr[3] = *blur1
  *param\option[9] = #True
  MultiThread_MT(@GaussianBlur1D_MT())
  *param\addr[2] = *blur1
  *param\addr[3] = *blur1
  *param\option[9] = #False
  MultiThread_MT(@GaussianBlur1D_MT())
  ; --- Flou sigma2 ---
  *param\option[0] = *param\option[1]  ; sigma2
  *param\addr[2] = *param\addr[0]
  *param\addr[3] = *blur2
  *param\option[9] = #True
  MultiThread_MT(@GaussianBlur1D_MT())
  *param\addr[2] = *blur2
  *param\addr[3] = *blur2
  *param\option[9] = #False
  MultiThread_MT(@GaussianBlur1D_MT())
  ; --- Soustraction DoG ---
  *param\addr[2] = *blur1
  *param\addr[3] = *blur2
  *param\addr[1] = *param\cible
  MultiThread_MT(@DoG_MT())
  ; Masque optionnel
  If *param\mask And *param\option[7] : *param\mask_type = *param\option[7] - 1 : MultiThread_MT(@_mask()) : EndIf
  ; Libération mémoire
  If *tempo : FreeMemory(*tempo) : EndIf
  FreeMemory(*blur1)
  FreeMemory(*blur2)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 143
; FirstLine = 138
; Folding = -
; EnableXP
; DPIAware