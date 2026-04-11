; ===== Poisson Disk Blur multithread avec itérations et sharpness =====
Procedure PoissonDiskBlur_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected w = *param\lg
  Protected h = *param\ht
  Protected radius.f = *param\option[0]
  Protected samples = *param\option[1]
  Protected sharpness.f = *param\option[2] / 100.0
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected yStart = (thread_pos * h) / thread_max
  Protected yEnd = ((thread_pos + 1) * h) / thread_max - 1
  
  Protected x, y, s, xi, yi, pos
  Protected r.f, g.f, b.f, r1, g1, b1
  Protected *srcPix.Pixel32, *dstPix.Pixel32
  Protected angle.f, dist.f
  Protected w_minus_1 = w - 1
  Protected h_minus_1 = h - 1
  Protected invSamples.f = 1.0 / samples
  Protected inv_sharpness.f = 1.0 - sharpness
  Protected piOver180.f = #PI / 180.0
  
  ; Initialisation du générateur aléatoire pour ce thread
  RandomSeed((thread_pos + 1) * 1000)
  
  For y = yStart To yEnd
    For x = 0 To w - 1
      r = 0.0 : g = 0.0 : b = 0.0
      
      For s = 0 To samples - 1
        ; Angle aléatoire en radians
        angle = Random(360) * piOver180
        ; Distance aléatoire
        dist = Random(Int(radius * 1000)) / 1000.0
        
        xi = x + Cos(angle) * dist
        yi = y + Sin(angle) * dist
        
        ; Clamping
        If xi < 0
          xi = 0
        ElseIf xi > w_minus_1
          xi = w_minus_1
        EndIf
        
        If yi < 0
          yi = 0
        ElseIf yi > h_minus_1
          yi = h_minus_1
        EndIf
        
        pos = (Int(yi) * w + Int(xi)) << 2
        *srcPix = *src + pos
        getrgb(*srcPix\l, r1, g1, b1)
        r + r1
        g + g1
        b + b1
      Next
      
      ; Moyenne
      r * invSamples
      g * invSamples
      b * invSamples
      
      ; Interpolation sharpness
      *srcPix = *src + ((y * w + x) << 2)
      getrgb(*srcPix\l, r1, g1, b1)
      r = r * sharpness + r1 * inv_sharpness
      g = g * sharpness + g1 * inv_sharpness
      b = b * sharpness + b1 * inv_sharpness
      
      clamp_rgb(r, g, b)
      
      pos = (y * w + x) << 2
      *dstPix = *dst + pos
      *dstPix\l = (Int(r) << 16) | (Int(g) << 8) | Int(b)
    Next
  Next
EndProcedure


; ===== Procédure principale =====
Procedure PoissonDiskBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Stochastic
    *param\name = "Poisson Disk Blur"
    *param\remarque = "Flou stochastique avec échantillonnage Poisson Disk"
    *param\info[0] = "Rayon"
    *param\info[1] = "Échantillons"
    *param\info[2] = "Force (sharpness)"
    *param\info[3] = "Itérations"
    *param\info[4] = "Masque"
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 4   : *param\info_data(1, 1) = 64  : *param\info_data(1, 2) = 16
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 100 : *param\info_data(2, 2) = 70
    *param\info_data(3, 0) = 1   : *param\info_data(3, 1) = 10  : *param\info_data(3, 2) = 1
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 2   : *param\info_data(4, 2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0
    ProcedureReturn
  EndIf
  
  Protected iterations = *param\option[3]
  Protected total = *param\lg * *param\ht * 4
  Protected tmpSrc = *param\source
  Protected tmpDst = *param\cible
  Protected *tempo = 0
  Protected i
  
  ; Si source = cible, créer un buffer temporaire
  If *param\source = *param\cible
    *tempo = AllocateMemory(total)
    If Not *tempo
      ProcedureReturn
    EndIf
    CopyMemory(*param\source, *tempo, total)
    tmpSrc = *tempo
  EndIf
  
  For i = 1 To iterations
    *param\addr[0] = tmpSrc
    *param\addr[1] = tmpDst
    MultiThread_MT(@PoissonDiskBlur_MT())
    
    ; Swap pour la prochaine itération
    If i < iterations
      Swap tmpSrc, tmpDst
    EndIf
  Next
  
  ; Application du masque si nécessaire
  If *param\mask And *param\option[4]
    *param\mask_type = *param\option[4] - 1
    MultiThread_MT(@_mask())
  EndIf
  
  ; Libération de la mémoire temporaire
  If *tempo
    FreeMemory(*tempo)
  EndIf
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 145
; FirstLine = 76
; Folding = -
; EnableXP
; DPIAware