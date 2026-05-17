; ------------------------------------------------------------------------------
; GREEN NOISE DITHERING (Ordered Dithering)
; ------------------------------------------------------------------------------
; Matrice Green Noise pour dithering avec distribution moyenne fréquence
; Compromis entre Blue Noise (hautes fréquences) et White Noise (toutes fréquences)

DataSection
  GreenNoise_Matrix:
  Data.a 16, 48,  8, 40, 18, 50, 10, 42
  Data.a 32,  0, 56, 24, 34,  2, 58, 26
  Data.a 12, 44,  4, 36, 14, 46,  6, 38
  Data.a 60, 28, 52, 20, 62, 30, 54, 22
  Data.a 17, 49,  9, 41, 19, 51, 11, 43
  Data.a 33,  1, 57, 25, 35,  3, 59, 27
  Data.a 13, 45,  5, 37, 15, 47,  7, 39
  Data.a 61, 29, 53, 21, 63, 31, 55, 23
EndDataSection

Procedure GreenNoise_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, i, j
    Protected oldR, oldG, oldB, newR, newG, newB
    Protected a, r, g, b
    Protected alphaValue, *currentPixel.Pixel32
    Protected levels = \option[0]
    Protected gray = \option[1]
    Protected var.i
    Protected threshold, noiseValue
    Protected matrixDim = 8
    Protected matrixMax.f = 63.0
    Protected Dim greenNoise(7, 7)
    
    ; Charger la matrice Green Noise
    Restore GreenNoise_Matrix
    For i = 0 To 7
      For j = 0 To 7
        Read.a greenNoise(i, j)
      Next
    Next
    
    clamp(levels, 2, 64)
    
    ; Table de quantification (LUT)
    Protected *ndc = AllocateMemory(256)
    If Not *ndc : ProcedureReturn : EndIf
    
    Protected Steping.f = 255.0 / (levels - 1)
    Protected reciprocal.f = 1.0 / Steping
    
    ; Précalcul de la table de quantification
    For i = 0 To 255
      var = Round(i * reciprocal, #PB_Round_Nearest)
      var = var * Steping
      clamp(var, 0, 255)
      PokeA(*ndc + i, var)
    Next
    
    macro_calul_tread((ht))
    
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    
    ; Facteur de seuil pour le dithering
    Protected thresholdFactor.f = 255.0 / (matrixMax + 1.0)
    
    For y = startPos To endPos
      For x = 0 To lg - 1
        *currentPixel = \addr[1] + (y * lg + x) << 2
        
        ; Récupérer la valeur de la matrice Green Noise
        noiseValue = greenNoise(y & 7, x & 7)
        threshold = noiseValue * thresholdFactor
        
        getargb(*currentPixel\l, a, oldR, oldG, oldB)
        alphaValue = a << 24
        
        If Not gray
          ; Mode couleur
          ; Ajouter le seuil avant quantification
          r = oldR + threshold - 128
          g = oldG + threshold - 128
          b = oldB + threshold - 128
          clamp(r, 0, 255)
          clamp(g, 0, 255)
          clamp(b, 0, 255)
          
          newR = PeekA(*ndc + r)
          newG = PeekA(*ndc + g)
          newB = PeekA(*ndc + b)
          
          *currentPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
        Else
          ; Mode niveaux de gris
          g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          g + threshold - 128
          clamp(g, 0, 255)
          
          newG = PeekA(*ndc + g)
          *currentPixel\l = alphaValue | newG * $10101
        EndIf
      Next
    Next
    
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure GreenNoiseDitherEx(*FilterCtx.FilterParams)
  Restore GreenNoise_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@GreenNoise_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure GreenNoiseDither(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  GreenNoiseDitherEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  GreenNoise_data:
  Data.s "GreenNoise"
  Data.s "Green Noise ordered dithering (mid-frequency optimized)"
  Data.i #FilterType_Dithering
  Data.i #Dither_Stochastic
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 121
; FirstLine = 93
; Folding = -
; EnableXP
; DPIAware