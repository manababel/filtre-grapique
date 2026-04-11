; ------------------------------------------------------------------------------
; VOID AND CLUSTER DITHERING
; ------------------------------------------------------------------------------
; Dithering par algorithme Void-and-Cluster
; Optimise la distribution spatiale en évitant les vides et les clusters

DataSection
  VoidCluster:
  Data.a 34, 48, 40, 32, 29, 15, 23, 31
  Data.a 42, 58, 56, 53, 21,  5, 13, 36
  Data.a 50, 62, 61, 45, 12,  0,  4, 28
  Data.a 38, 46, 54, 37,  8,  1,  9, 20
  Data.a 30, 22, 14,  6, 16,  3,  2, 11
  Data.a 25,  7, 10, 18, 27, 19, 24, 17
  Data.a 33, 17, 26, 35, 44, 41, 33, 25
  Data.a 49, 41, 52, 60, 57, 51, 43, 52
EndDataSection

Procedure VoidAndCluster_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, i, j
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected a, r, g, b
  Protected alphaValue, *currentPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  Protected var.i
  Protected threshold, clusterValue
  Protected matrixDim = 8
  Protected matrixMax.f = 63.0
  Protected Dim voidCluster(7, 7)
  
  ; Charger la matrice Void-and-Cluster
  Restore VoidCluster
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
  
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  
  ; Facteur de seuil pour le dithering
  Protected thresholdFactor.f = 255.0 / (matrixMax + 1.0)
  
  For y = startPos To endPos
    For x = 0 To lg - 1
      *currentPixel = *param\addr[1] + (y * lg + x) << 2
      
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
EndProcedure

Procedure VoidAndCluster(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_Stochastic
    *param\name = "Void and Cluster"
    *param\remarque = "Void-and-Cluster optimized spatial distribution"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    
    ProcedureReturn
  EndIf
  
  filter_start(@VoidAndCluster_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 108
; FirstLine = 53
; Folding = -
; EnableXP
; DPIAware