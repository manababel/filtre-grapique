; ------------------------------------------------------------------------------
; HALFTONE SCREEN DITHERING (Ordered Dithering)
; ------------------------------------------------------------------------------
; Matrice Halftone Screen pour simulation de trame halftone classique
; Simule les écrans de trame utilisés dans l'impression traditionnelle

DataSection
  HalftoneScreen:
  Data.a 24, 10, 12, 26, 35, 47, 49, 37
  Data.a  8,  0,  2, 14, 45, 59, 61, 51
  Data.a 22,  6,  4, 16, 43, 57, 63, 53
  Data.a 30, 20, 18, 28, 33, 41, 55, 39
  Data.a 34, 46, 48, 36, 25, 11, 13, 27
  Data.a 44, 58, 60, 50,  9,  1,  3, 15
  Data.a 42, 56, 62, 52, 23,  7,  5, 17
  Data.a 32, 40, 54, 38, 31, 21, 19, 29
EndDataSection

Procedure HalftoneScreen_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, i, j
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected a, r, g, b
  Protected alphaValue, *currentPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  Protected var.i
  Protected threshold, screenValue
  Protected matrixDim = 8
  Protected matrixMax.f = 63.0
  Protected Dim halftone(7, 7)
  
  ; Charger la matrice Halftone Screen
  Restore HalftoneScreen
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
  
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  
  ; Facteur de seuil pour le dithering
  Protected thresholdFactor.f = 255.0 / (matrixMax + 1.0)
  
  For y = startPos To endPos
    For x = 0 To lg - 1
      *currentPixel = *param\addr[1] + (y * lg + x) << 2
      
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
EndProcedure

Procedure HalftoneScreen(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_Ordered
    *param\name = "Halftone Screen"
    *param\remarque = "Halftone Screen ordered dithering (classic print simulation)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    
    ProcedureReturn
  EndIf
  
  filter_start(@HalftoneScreen_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 108
; FirstLine = 53
; Folding = -
; EnableXP
; DPIAware