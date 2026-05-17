; ============================================================================
; Filtre Gabor - Analyse de texture et détection de contours orientés
; ============================================================================

Structure GaborKernel
  size.i           ; Taille du noyau (ex: 31x31)
  *real.Float      ; Partie réelle du filtre
  *imag.Float      ; Partie imaginaire du filtre
EndStructure

Procedure CreateGaborKernel(*kernel.GaborKernel, wavelength, orientation, sigma, gamma, psi)
  Protected ksize, halfsize, x, y, x_theta.f, y_theta.f, angle.f, sigma_x.f, sigma_y.f
  Protected gaussian.f, sinusoid_real.f, sinusoid_imag.f
  
  ksize = Int(sigma * 6) | 1
  If ksize < 3 : ksize = 3 : EndIf
  If ksize > 63 : ksize = 63 : EndIf
  
  halfsize = ksize >> 1
  *kernel\size = ksize
  
  *kernel\real = AllocateMemory(ksize * ksize * SizeOf(Float))
  *kernel\imag = AllocateMemory(ksize * ksize * SizeOf(Float))
  
  If Not *kernel\real Or Not *kernel\imag
    If *kernel\real : FreeMemory(*kernel\real) : EndIf
    If *kernel\imag : FreeMemory(*kernel\imag) : EndIf
    ProcedureReturn #False
  EndIf
  
  angle = orientation * #PI / 180.0
  sigma_x = sigma
  sigma_y = sigma / gamma
  
  For y = 0 To ksize - 1
    For x = 0 To ksize - 1
      x_theta = (x - halfsize) * Cos(angle) + (y - halfsize) * Sin(angle)
      y_theta = -(x - halfsize) * Sin(angle) + (y - halfsize) * Cos(angle)
      
      gaussian = Exp(-0.5 * ((x_theta * x_theta) / (sigma_x * sigma_x) + (y_theta * y_theta) / (sigma_y * sigma_y)))
      
      sinusoid_real = Cos(2.0 * #PI * x_theta / wavelength + psi)
      sinusoid_imag = Sin(2.0 * #PI * x_theta / wavelength + psi)
      
      PokeF(*kernel\real + (y * ksize + x) * SizeOf(Float), gaussian * sinusoid_real)
      PokeF(*kernel\imag + (y * ksize + x) * SizeOf(Float), gaussian * sinusoid_imag)
    Next
  Next
  ProcedureReturn #True
EndProcedure

Macro FreeGaborKernel(kernel)
  If kernel\real : FreeMemory(kernel\real) : kernel\real = 0 : EndIf
  If kernel\imag : FreeMemory(kernel\imag) : kernel\imag = 0 : EndIf
EndMacro

Procedure Gabor_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    
    ; Paramètres indexés
    Protected wavelength.f = \option[0]
    Protected orientation.f = \option[1]
    Protected sigma.f = \option[2]
    Protected gamma.f = \option[3] / 100.0 ; Ajustement car l'original attendait 0.23-0.92
    Protected psi.f = \option[4]
    Protected outputMode = \option[5]
    Protected toGray = \option[6]
    Protected normalize = \option[7]
    
    If wavelength < 2 : wavelength = 2 : EndIf
    If orientation > 180 : orientation = 180 : EndIf
    
    psi * #PI / 180.0
    
    Protected kernel.GaborKernel
    If Not CreateGaborKernel(@kernel, wavelength, orientation, sigma, gamma, psi)
      ProcedureReturn
    EndIf
    
    Protected *srcPixel.Long, *dstPixel.Long
    Protected x, y, kx, ky, sx, sy, idx
    Protected r, g, b, gray, pixelValue
    Protected real_sum.f, imag_sum.f
    Protected kernel_val_real.f, kernel_val_imag.f
    Protected halfsize = kernel\size >> 1
    Protected result.f, output.f
    Protected minVal.f, maxVal.f, range.f
    
    Dim tempResults.f(lg * ht)
    Protected needNormalize
    If normalize And outputMode <> 3 : needNormalize = #True : Else : needNormalize = #False : EndIf
    
    macro_calul_tread((ht - 1))
    
    For y = thread_start To thread_stop
      For x = 0 To lg - 1
        real_sum = 0
        imag_sum = 0
        
        For ky = 0 To kernel\size - 1
          sy = y + ky - halfsize
          If sy < 0 : sy = 0 : ElseIf sy >= ht : sy = ht - 1 : EndIf
          
          For kx = 0 To kernel\size - 1
            sx = x + kx - halfsize
            If sx < 0 : sx = 0 : ElseIf sx >= lg : sx = lg - 1 : EndIf
            
            *srcPixel = \addr[0] + (sy * lg + sx) * 4
            GetRGB(PeekL(*srcPixel), r, g, b)
            
            If toGray
              pixelValue = (r * 77 + g * 150 + b * 29) >> 8
            Else
              pixelValue = (r + g + b) / 3
            EndIf
            
            idx = ky * kernel\size + kx
            kernel_val_real = PeekF(kernel\real + idx * SizeOf(Float))
            kernel_val_imag = PeekF(kernel\imag + idx * SizeOf(Float))
            
            real_sum + pixelValue * kernel_val_real
            imag_sum + pixelValue * kernel_val_imag
          Next
        Next
        
        Select outputMode
          Case 0 : output = Sqr(real_sum * real_sum + imag_sum * imag_sum)
          Case 1 : output = real_sum
          Case 2 : output = imag_sum
          Case 3
            output = ATan2(imag_sum, real_sum) * 180.0 / #PI
            If output < 0 : output + 360 : EndIf
        EndSelect
        
        If needNormalize
          idx = y * lg + x
          tempResults(idx) = output
          If y = thread_start And x = 0
            minVal = output : maxVal = output
          Else
            If output < minVal : minVal = output : EndIf
            If output > maxVal : maxVal = output : EndIf
          EndIf
        Else
          If outputMode = 3
            result = output * 255.0 / 360.0
          Else
            result = Abs(output)
          EndIf
          
          If result < 0 : result = 0 : ElseIf result > 255 : result = 255 : EndIf
          
          *dstPixel = \addr[1] + (y * lg + x) * 4
          If toGray
            PokeL(*dstPixel, $FF000000 | (Int(result) * $010101))
          Else
            *srcPixel = \addr[0] + (y * lg + x) * 4
            GetRGB(PeekL(*srcPixel), r, g, b)
            Protected a = (PeekL(*srcPixel) >> 24) & $FF
            r = (r * result) / 255
            g = (g * result) / 255
            b = (b * result) / 255
            Clamp_RGB(r, g, b)
            PokeL(*dstPixel, (a << 24) | (r << 16) | (g << 8) | b)
          EndIf
        EndIf
      Next
    Next
    
    If needNormalize
      range = maxVal - minVal
      If range < 0.001 : range = 1.0 : EndIf
      For y = thread_start To thread_stop
        For x = 0 To lg - 1
          idx = y * lg + x
          result = (tempResults(idx) - minVal) * 255.0 / range
          If result < 0 : result = 0 : ElseIf result > 255 : result = 255 : EndIf
          
          *dstPixel = \addr[1] + idx * 4
          If toGray
            PokeL(*dstPixel, $FF000000 | (Int(result) * $010101))
          Else
            *srcPixel = \addr[0] + idx * 4
            GetRGB(PeekL(*srcPixel), r, g, b)
            a = (PeekL(*srcPixel) >> 24) & $FF
            r = (r * result) / 255
            g = (g * result) / 255
            b = (b * result) / 255
            Clamp_RGB(r, g, b)
            PokeL(*dstPixel, (a << 24) | (r << 16) | (g << 8) | b)
          EndIf
        Next
      Next
    EndIf
    
    FreeGaborKernel(kernel)
    FreeArray(tempResults())
  EndWith
EndProcedure

Procedure GaborEx(*FilterCtx.FilterParams)
  Restore Gabor_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Gabor_MT())
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure Gabor(source, cible, mask, wavelength, orientation, sigma, gamma, psi, outputMode, toGray, normalize)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = wavelength
    \option[1] = orientation
    \option[2] = sigma
    \option[3] = gamma
    \option[4] = psi
    \option[5] = outputMode
    \option[6] = toGray
    \option[7] = normalize
  EndWith
  GaborEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Gabor_data:
  Data.s "Gabor"
  Data.s "Analyse de texture et détection orientée (Dennis Gabor)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Advanced
  
  Data.s "Longueur d'onde (wavelength)"
  Data.i 2, 100, 10
  Data.s "Orientation (degrés)"
  Data.i 0, 180, 0
  Data.s "Sigma (écart-type)"
  Data.i 1, 20, 5
  Data.s "Gamma (aspect ratio)"
  Data.i 23, 92, 50
  Data.s "Psi (phase, degrés)"
  Data.i 0, 360, 0
  Data.s "Mode sortie (0=Mag/1=Real/2=Imag/3=Phase)"
  Data.i 0, 3, 0
  Data.s "Noir et blanc"
  Data.i 0, 1, 1
  Data.s "Normalisation"
  Data.i 0, 1, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 94
; FirstLine = 58
; Folding = -
; EnableXP
; DPIAware