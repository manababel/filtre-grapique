; ---------------------------------------------------
; Poisson Disk Blur - Version multithread
; Flou stochastique avec échantillonnage Poisson Disk
; ---------------------------------------------------

Procedure PoissonDiskBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0], *dst = \addr[1]
    Protected w = \image_lg[0], h = \image_ht[0]
    Protected radius.f = \option[0]
    Protected samples = \option[1]
    Protected sharpness.f = \option[2] / 100.0
    
    Protected x, y, s, xi, yi, pos, r1, g1, b1
    Protected r.f, g.f, b.f
    Protected *srcPix.Pixel32, *dstPix.Pixel32
    Protected angle.f, dist.f
    Protected w_minus_1 = w - 1
    Protected h_minus_1 = h - 1
    Protected invSamples.f = 1.0 / samples
    Protected inv_sharpness.f = 1.0 - sharpness
    Protected piOver180.f = #PI / 180.0
    
Dim disk.Point(samples - 1)
    
    ; On initialise le générateur une seule fois pour la table
    ;RandomSeed(12345) 
    ;For s = 0 To samples - 1
      ;angle = Random(360) * piOver180
      ; Distribution un peu plus uniforme (racine carrée pour éviter l'accumulation au centre)
      ;dist = Sqr(Random(1000) / 1000.0) * radius 
      ;disk(s)\x = Cos(angle) * dist
      ;disk(s)\y = Sin(angle) * dist
    ;Next 
    
    macro_calul_tread(h)
    
    ; Initialisation du générateur aléatoire pour ce thread
    RandomSeed(thread_start * 1000 + 1)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        r = 0.0 : g = 0.0 : b = 0.0
        
        For s = 0 To samples - 1
          angle = Random(360) * piOver180
          dist = Random(Int(radius * 1000)) / 1000.0
          
          xi = x + Cos(angle) * dist
          yi = y + Sin(angle) * dist
          
          ;xi = x + disk(s)\x
          ;yi = y + disk(s)\y
          
          ; Clamping
          If xi < 0 : xi = 0 : ElseIf xi > w_minus_1 : xi = w_minus_1 : EndIf
          If yi < 0 : yi = 0 : ElseIf yi > h_minus_1 : yi = h_minus_1 : EndIf
          
          pos = (Int(yi) * w + Int(xi)) << 2
          *srcPix = *src + pos
          getrgb(*srcPix\l, r1, g1, b1)
          r + r1 : g + g1 : b + b1
        Next
        
        r * invSamples : g * invSamples : b * invSamples
        
        ; Interpolation sharpness
        pos = (y * w + x) << 2
        *srcPix = *src + pos
        getrgb(*srcPix\l, r1, g1, b1)
        r = r * sharpness + r1 * inv_sharpness
        g = g * sharpness + g1 * inv_sharpness
        b = b * sharpness + b1 * inv_sharpness
        
        clamp_rgb(r, g, b)
        
        *dstPix = *dst + pos
        *dstPix\l = (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
  EndWith
EndProcedure

Procedure PoissonDiskBlurEx(*FilterCtx.FilterParams)
  Restore PoissonDiskBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected iterations = \option[3]
    Protected total = \image_lg[0] * \image_ht[0] * 4
    Protected *tempo = 0
    Protected tmpSrc = \addr[0]
    Protected tmpDst = \addr[1]
    Protected i
    
    ; Si source = cible, créer un buffer temporaire pour ne pas écraser l'original
    If \addr[0] = \addr[1]
      *tempo = AllocateMemory(total)
      If *tempo
        CopyMemory(\addr[0], *tempo, total)
        tmpSrc = *tempo
      EndIf
    EndIf
    
    For i = 1 To iterations
      \addr[0] = tmpSrc : \addr[1] = tmpDst
      Create_MultiThread_MT(@PoissonDiskBlur_sp())
      If i < iterations : Swap tmpSrc, tmpDst : EndIf
    Next
    
    If *tempo : FreeMemory(*tempo) : EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure PoissonDiskBlur(source, cible, mask, radius, samples, sharpness, iterations)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = samples
    \option[2] = sharpness
    \option[3] = iterations
  EndWith
  PoissonDiskBlurEx(FilterCtx)
EndProcedure

DataSection
  PoissonDiskBlur_data:
  Data.s "Poisson Disk Blur"
  Data.s "Flou stochastique avec échantillonnage Poisson Disk"
  Data.i #FilterType_Blur, #Blur_Stochastic
  Data.s "Rayon"
  Data.i 1, 100, 10
  Data.s "Échantillons"
  Data.i 4, 64, 16
  Data.s "Netteté"
  Data.i 0, 100, 70
  Data.s "Itérations"
  Data.i 1, 10, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 124
; FirstLine = 74
; Folding = -
; EnableXP
; DPIAware