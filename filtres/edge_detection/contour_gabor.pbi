

Procedure gabor(*param.parametre)
  Protected *src = *param\source
  Protected *dst = *param\cible
  Protected lg = *param\lg
  Protected ht = *param\ht

  ; Options utilisateur
  Protected sigma.f  = *param\option[0]  ; largeur du noyau (ex: 4.0)
  Protected theta.f  = *param\option[1]  ; orientation (ex: #PI / 4)
  Protected lambda.f = *param\option[2]  ; fréquence (ex: 10.0)
  Protected psi.f    = *param\option[3]  ; phase (ex: 0.0)
  Protected gamma.f  = *param\option[4]  ; aspect ratio (ex: 0.5)

  clamp(sigma , 0 , 200)
  sigma = sigma * 0.01 + 2

  clamp(theta,1,100)
  theta = theta * (2 * #PI) / 100

  clamp(lambda,0,50)
  lambda = lambda * 0.1 + 5

  clamp(gamma,1,10)
  gamma = gamma * 0.1

  ; --- Initialisation du noyau Gabor (réel + imaginaire) ---
  Protected sigma_x.f = sigma
  Protected sigma_y.f = sigma / gamma
  Protected half = Int(sigma_x + 0.5)
  Protected sz = half * 2 + 1

  Protected *kernel_real = AllocateMemory(sz * sz * SizeOf(Float))
  Protected *kernel_imag = AllocateMemory(sz * sz * SizeOf(Float))
  If Not *kernel_real Or Not *kernel_imag : ProcedureReturn : EndIf

  Protected i, j
  For j = -half To half
    For i = -half To half
      Protected x_theta = i * Cos(theta) + j * Sin(theta)
      Protected y_theta = -i * Sin(theta) + j * Cos(theta)
      Protected gauss = Exp(-0.5 * (x_theta*x_theta/(sigma_x*sigma_x) + y_theta*y_theta/(sigma_y*sigma_y)))
      
      Protected realPart = gauss * Cos(2 * #PI * x_theta / lambda + psi)
      Protected imagPart = gauss * Sin(2 * #PI * x_theta / lambda + psi)
      
      PokeF(*kernel_real + ((j+half)*sz + (i+half)) * 4, realPart)
      PokeF(*kernel_imag + ((j+half)*sz + (i+half)) * 4, imagPart)
    Next
  Next

  ; Normalisation (valeurs absolues) des deux kernels
  Protected sum_real.f = 0.0
  Protected sum_imag.f = 0.0
  For i = 0 To sz*sz - 1
    sum_real + Abs(PeekF(*kernel_real + i * 4))
    sum_imag + Abs(PeekF(*kernel_imag + i * 4))
  Next

  If sum_real > 0.0001
    For i = 0 To sz*sz - 1
      PokeF(*kernel_real + i * 4, PeekF(*kernel_real + i * 4) / sum_real)
    Next
  EndIf

  If sum_imag > 0.0001
    For i = 0 To sz*sz - 1
      PokeF(*kernel_imag + i * 4, PeekF(*kernel_imag + i * 4) / sum_imag)
    Next
  EndIf

  ; --- Convolution avec image en niveaux de gris ---

  Protected x, y, dx, dy, sx, sy
  Protected pr, pg, pb, rgb
  Protected sum_r.f, sum_g.f, sum_b.f
  Protected real_conv.f, imag_conv.f, magnitude.f
  Protected gray, val_r, val_g, val_b

  For y = 0 To ht - 1
    For x = 0 To lg - 1
      real_conv = 0.0
      imag_conv = 0.0

      For dy = -half To half
        sy = y + dy
        If sy < 0
          sy = -sy
        ElseIf sy >= ht
          sy = 2 * ht - sy - 2
        EndIf

        For dx = -half To half
          sx = x + dx
          If sx < 0
            sx = -sx
          ElseIf sx >= lg
            sx = 2 * lg - sx - 2
          EndIf

          rgb = PeekL(*src + ((sy * lg + sx) << 2))
          getrgb(rgb, pr, pg, pb)
          ; Conversion en gris (pondération classique)
          gray = (pr * 77 + pg * 150 + pb * 29) >> 8

          Protected w_real.f = PeekF(*kernel_real + ((dy + half) * sz + (dx + half)) * 4)
          Protected w_imag.f = PeekF(*kernel_imag + ((dy + half) * sz + (dx + half)) * 4)

          real_conv + gray * w_real
          imag_conv + gray * w_imag
        Next
      Next

      ; Calcul de la magnitude
      magnitude = Sqr(real_conv * real_conv + imag_conv * imag_conv)
      clamp(magnitude, 0, 255)

      val_r = magnitude
      val_g = magnitude
      val_b = magnitude

      PokeL(*dst + ((y * lg + x) << 2), (Int(val_r) << 16) | (Int(val_g) << 8) | Int(val_b))
    Next
  Next

  FreeMemory(*kernel_real)
  FreeMemory(*kernel_imag)
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 129
; FirstLine = 59
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger