; ------------------------------------------------------------------------------
; HALFTONE SCREEN DITHERING (Ordered Dithering)
; ------------------------------------------------------------------------------
; Matrice Halftone Screen pour simulation de trame halftone classique
; Simule les écrans de trame utilisés dans l'impression traditionnelle

DataSection
  HalftoneScreen_Matrix:
  Data.a 24, 10, 12, 26, 35, 47, 49, 37
  Data.a  8,  0,  2, 14, 45, 59, 61, 51
  Data.a 22,  6,  4, 16, 43, 57, 63, 53
  Data.a 30, 20, 18, 28, 33, 41, 55, 39
  Data.a 34, 46, 48, 36, 25, 11, 13, 27
  Data.a 44, 58, 60, 50,  9,  1,  3, 15
  Data.a 42, 56, 62, 52, 23,  7,  5, 17
  Data.a 32, 40, 54, 38, 31, 21, 19, 29
EndDataSection

Procedure HalftoneScreen_MT(*FilterCtx.FilterParams)
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
    Protected threshold, screenValue
    Protected matrixDim = 8
    Protected matrixMax.f = 63.0
    Protected Dim halftone(7, 7)
    
    ; Charger la matrice Halftone Screen
    Restore HalftoneScreen_Matrix
    For i = 0 To 7
      For j = 0 To 7
        Read.a halftone(i, j)
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
        
        ; Récupérer la valeur de la matrice Halftone Screen
        screenValue = halftone(y & 7, x & 7)
        threshold = screenValue * thresholdFactor
        
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

Procedure HalftoneScreenEx(*FilterCtx.FilterParams)
  Restore HalftoneScreen_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@HalftoneScreen_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure HalftoneScreen(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  HalftoneScreenEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  HalftoneScreen_data:
  Data.s "HalftoneScreen"
  Data.s "Halftone Screen ordered dithering (classic print simulation)"
  Data.i #FilterType_Dithering
  Data.i #Dither_Ordered
  
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