; ------------------------------------------------------------------------------
; BLUE NOISE DITHERING (Ordered Dithering)
; ------------------------------------------------------------------------------
; Matrice Blue Noise pour dithering de haute qualité visuelle
; Optimisée pour minimiser les patterns réguliers et maximiser la perception

DataSection
  BlueNoise_Matrix:
  Data.a 32,  8, 40, 16, 34, 10, 42, 18
  Data.a  4, 36, 12, 44, 20,  6, 38, 14
  Data.a 48, 24,  0, 56, 28, 50, 26,  2
  Data.a 60, 52, 20, 44,  8, 62, 54, 22
  Data.a 33,  9, 41, 17, 35, 11, 43, 19
  Data.a  5, 37, 13, 45, 21,  7, 39, 15
  Data.a 49, 25,  1, 57, 29, 51, 27,  3
  Data.a 61, 53, 21, 45,  9, 63, 55, 23
EndDataSection

Procedure BlueNoise_MT(*FilterCtx.FilterParams)
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
    Protected Dim blueNoise(7, 7)
    
    ; Charger la matrice Blue Noise
    Restore BlueNoise_Matrix
    For i = 0 To 7
      For j = 0 To 7
        Read.a blueNoise(i, j)
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
        
        ; Récupérer la valeur de la matrice Blue Noise
        noiseValue = blueNoise(y & 7, x & 7)
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

Procedure BlueNoiseDitherEx(*FilterCtx.FilterParams)
  Restore BlueNoise_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@BlueNoise_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure BlueNoiseDither(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  BlueNoiseDitherEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  BlueNoise_data:
  Data.s "BlueNoise"
  Data.s "Blue Noise ordered dithering (high visual quality)"
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