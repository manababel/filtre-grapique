; ------------------------------------------------------------------------------
; BAYER DITHER (matrice ordonnée de taille variable)
; ------------------------------------------------------------------------------
Procedure BayerDither_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, currentPos
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected a, r, g, b, alphaValue
  Protected *dstPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  Protected matrixSize = *param\option[2]
  
  clamp(levels, 2, 64)
  clamp(matrixSize, 1, 4) ; 1=2x2, 2=4x4, 3=8x8, 4=16x16
  
  ; Matrices de Bayer précalculées
  Protected Dim Bayer2x2(1, 1)
  Bayer2x2(0,0) = 0  : Bayer2x2(0,1) = 2
  Bayer2x2(1,0) = 3  : Bayer2x2(1,1) = 1
  
  Protected Dim Bayer4x4(3, 3)
  Restore data_BayerDither_4x4
  For y = 0 To 3
    For x = 0 To 3
      Read.a Bayer4x4(y, x)
    Next
  Next
  
  Protected Dim Bayer8x8(7, 7)
  Restore data_BayerDither_8x8
  For y = 0 To 7
    For x = 0 To 7
      Read.a Bayer8x8(y, x)
    Next
  Next
  
  Protected matrixMax, threshold.f
  Protected mx, my
  
  Select matrixSize
    Case 1 : matrixMax = 3
    Case 2 : matrixMax = 15
    Case 3 : matrixMax = 63
    Default : matrixMax = 15
  EndSelect
  
  Protected Steping.f = 255.0 / (levels - 1)
  
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  
  For y = startPos To endPos
    For x = 0 To lg - 1
      currentPos = y * lg + x
      *dstPixel = *param\addr[1] + currentPos << 2
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      alphaValue = a << 24
      
      ; Sélection de la valeur de matrice selon la taille
      Select matrixSize
        Case 1
          mx = x & 1
          my = y & 1
          threshold = (Bayer2x2(my, mx) / 3.0) - 0.5
        Case 2
          mx = x & 3
          my = y & 3
          threshold = (Bayer4x4(my, mx) / 15.0) - 0.5
        Case 3
          mx = x & 7
          my = y & 7
          threshold = (Bayer8x8(my, mx) / 63.0) - 0.5
      EndSelect
      
      If Not gray
        ; Mode couleur
        newR = Round((oldR + threshold * Steping) / Steping, #PB_Round_Nearest) * Steping
        newG = Round((oldG + threshold * Steping) / Steping, #PB_Round_Nearest) * Steping
        newB = Round((oldB + threshold * Steping) / Steping, #PB_Round_Nearest) * Steping
        clamp(newR, 0, 255)
        clamp(newG, 0, 255)
        clamp(newB, 0, 255)
        *dstPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
      Else
        ; Mode gris
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = Round((g + threshold * Steping) / Steping, #PB_Round_Nearest) * Steping
        clamp(newG, 0, 255)
        *dstPixel\l = alphaValue | newG * $10101
      EndIf
    Next
  Next
EndProcedure

Procedure BayerDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_Random
    *param\name = "BayerDither"
    *param\remarque = "Bayer ordered dithering (matrice)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Taille matrice"
    *param\info[3] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 1   : *param\info_data(2, 1) = 3   : *param\info_data(2, 2) = 2
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 2   : *param\info_data(3, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@BayerDither_MT(), 2, 0)  ; Parallélisable
EndProcedure

DataSection
  data_BayerDither_4x4:
  Data.a  0,  8,  2, 10
  Data.a 12,  4, 14,  6
  Data.a  3, 11,  1,  9
  Data.a 15,  7, 13,  5
  data_BayerDither_8x8:
  Data.a  0, 32,  8, 40,  2, 34, 10, 42
  Data.a 48, 16, 56, 24, 50, 18, 58, 26
  Data.a 12, 44,  4, 36, 14, 46,  6, 38
  Data.a 60, 28, 52, 20, 62, 30, 54, 22
  Data.a  3, 35, 11, 43,  1, 33,  9, 41
  Data.a 51, 19, 59, 27, 49, 17, 57, 25
  Data.a 15, 47,  7, 39, 13, 45,  5, 37
  Data.a 63, 31, 55, 23, 61, 29, 53, 21
EndDataSection

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 99
; FirstLine = 71
; Folding = -
; EnableXP
; DPIAware