; ------------------------------------------------------------------------------
; BAYER 8x8 DITHERING (Ordered Dithering)
; ------------------------------------------------------------------------------
; Matrice Bayer pour dithering ordonné 8x8

DataSection
  Bayer8x8_Matrix:
  Data.a  0, 32,  8, 40,  2, 34, 10, 42
  Data.a 48, 16, 56, 24, 50, 18, 58, 26
  Data.a 12, 44,  4, 36, 14, 46,  6, 38
  Data.a 60, 28, 52, 20, 62, 30, 54, 22
  Data.a  3, 35, 11, 43,  1, 33,  9, 41
  Data.a 51, 19, 59, 27, 49, 17, 57, 25
  Data.a 15, 47,  7, 39, 13, 45,  5, 37
  Data.a 63, 31, 55, 23, 61, 29, 53, 21
EndDataSection

Procedure Bayer8x8_MT(*FilterCtx.FilterParams)
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
    Protected threshold, bayerValue
    Protected matrixDim = 8
    Protected matrixMax.f = 63.0
    Protected Dim bayer(7, 7)
    
    ; Charger la matrice Bayer 8x8
    Restore Bayer8x8_Matrix
    For i = 0 To 7
      For j = 0 To 7
        Read.a bayer(i, j)
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
        
        ; Récupérer la valeur de la matrice Bayer
        bayerValue = bayer(y & 7, x & 7)
        threshold = bayerValue * thresholdFactor
        
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

Procedure Bayer8x8Ex(*FilterCtx.FilterParams)
  Restore Bayer8x8_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Bayer8x8_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure Bayer8x8(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  Bayer8x8Ex(FilterCtx.FilterParams)
EndProcedure

DataSection
  Bayer8x8_data:
  Data.s "Bayer8x8"
  Data.s "Bayer 8x8 ordered dithering"
  Data.i #FilterType_Dithering
  Data.i #Dither_Ordered
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 120
; FirstLine = 92
; Folding = -
; EnableXP
; DPIAware