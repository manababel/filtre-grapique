; ------------------------------------------------------------------------------
; CLUSTERED DOT DITHERING (Ordered Dithering)
; ------------------------------------------------------------------------------
; Matrice Clustered Dot pour simulation de trame d'imprimerie
; Simule les points de trame utilisés dans l'impression offset

DataSection
  ClusteredDot:
  Data.a 12, 5, 6, 13
  Data.a  4, 0, 1,  7
  Data.a 11, 3, 2,  8
  Data.a 15, 10, 9, 14
EndDataSection

Procedure ClusteredDot_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, i, j
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected a, r, g, b
  Protected alphaValue, *currentPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  Protected var.i
  Protected threshold, dotValue
  Protected matrixDim = 4
  Protected matrixMax.f = 15.0
  Protected Dim cluster(3, 3)
  
  ; Charger la matrice Clustered Dot
  Restore ClusteredDot
  For i = 0 To 3
    For j = 0 To 3
      Read.a cluster(i, j)
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
      
      ; Récupérer la valeur de la matrice Clustered Dot
      dotValue = cluster(y & 3, x & 3)
      threshold = dotValue * thresholdFactor
      
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

Procedure ClusteredDot(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_Ordered
    *param\name = "Clustered Dot"
    *param\remarque = "Clustered Dot ordered dithering (halftone simulation)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    
    ProcedureReturn
  EndIf
  
  filter_start(@ClusteredDot_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 104
; FirstLine = 49
; Folding = -
; EnableXP
; DPIAware