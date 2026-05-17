; ------------------------------------------------------------------------------
; BAYER 4x4 DITHERING (Ordered Dithering)
; ------------------------------------------------------------------------------
; Matrice Bayer pour dithering ordonné 4x4

DataSection
  Bayer4x4_Matrix:
  Data.a  0,  8,  2, 10
  Data.a 12,  4, 14,  6
  Data.a  3, 11,  1,  9
  Data.a 15,  7, 13,  5
EndDataSection

Procedure Bayer4x4_MT(*FilterCtx.FilterParams)
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
    Protected matrixDim = 4
    Protected matrixMax.f = 15.0
    Protected Dim bayer(3, 3)
    
    ; Charger la matrice Bayer 4x4
    Restore Bayer4x4_Matrix
    For i = 0 To 3
      For j = 0 To 3
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
        bayerValue = bayer(y & 3, x & 3)
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

Procedure Bayer4x4Ex(*FilterCtx.FilterParams)
  Restore Bayer4x4_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Bayer4x4_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure Bayer4x4(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  Bayer4x4Ex(FilterCtx.FilterParams)
EndProcedure

DataSection
  Bayer4x4_data:
  Data.s "Bayer4x4"
  Data.s "Bayer 4x4 ordered dithering"
  Data.i #FilterType_Dithering
  Data.i #Dither_Ordered
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 116
; FirstLine = 88
; Folding = -
; EnableXP
; DPIAware