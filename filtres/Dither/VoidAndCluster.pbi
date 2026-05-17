; ------------------------------------------------------------------------------
; VOID AND CLUSTER DITHERING
; ------------------------------------------------------------------------------
; Dithering par algorithme Void-and-Cluster
; Optimise la distribution spatiale en évitant les vides et les clusters

DataSection
  VoidCluster_Matrix:
  Data.a 34, 48, 40, 32, 29, 15, 23, 31
  Data.a 42, 58, 56, 53, 21,  5, 13, 36
  Data.a 50, 62, 61, 45, 12,  0,  4, 28
  Data.a 38, 46, 54, 37,  8,  1,  9, 20
  Data.a 30, 22, 14,  6, 16,  3,  2, 11
  Data.a 25,  7, 10, 18, 27, 19, 24, 17
  Data.a 33, 17, 26, 35, 44, 41, 33, 25
  Data.a 49, 41, 52, 60, 57, 51, 43, 52
EndDataSection

Procedure VoidAndCluster_MT(*FilterCtx.FilterParams)
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
    Protected threshold, clusterValue
    Protected matrixDim = 8
    Protected matrixMax.f = 63.0
    Protected Dim voidCluster(7, 7)
    
    ; Charger la matrice Void-and-Cluster
    Restore VoidCluster_Matrix
    For i = 0 To 7
      For j = 0 To 7
        Read.a voidCluster(i, j)
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
    
    macro_calul_tread(ht)
    
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    
    ; Facteur de seuil pour le dithering
    Protected thresholdFactor.f = 255.0 / (matrixMax + 1.0)
    
    For y = startPos To endPos
      For x = 0 To lg - 1
        *currentPixel = \addr[1] + (y * lg + x) << 2
        
        ; Récupérer la valeur de la matrice Void-and-Cluster
        clusterValue = voidCluster(y & 7, x & 7)
        threshold = clusterValue * thresholdFactor
        
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

Procedure VoidAndClusterEx(*FilterCtx.FilterParams)
  Restore VoidAndCluster_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@VoidAndCluster_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure VoidAndCluster(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  VoidAndClusterEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  VoidAndCluster_data:
  Data.s "VoidAndCluster"
  Data.s "Void-and-Cluster optimized spatial distribution"
  Data.i #FilterType_Dithering
  Data.i #Dither_Stochastic
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 59
; FirstLine = 57
; Folding = -
; EnableXP
; DPIAware