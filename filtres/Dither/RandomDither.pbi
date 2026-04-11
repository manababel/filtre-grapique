; ------------------------------------------------------------------------------
; RANDOM DITHER (bruit aléatoire)
; ------------------------------------------------------------------------------
Procedure RandomDither_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, currentPos
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected a, r, g, b, alphaValue
  Protected *dstPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  Protected intensity = *param\option[2]
  
  clamp(levels, 2, 64)
  clamp(intensity, 1, 100)
  
  Protected Steping.f = 255.0 / (levels - 1)
  Protected noiseRange.f = (intensity / 100.0) * Steping
  
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  
  ; Initialisation du générateur aléatoire avec seed basé sur thread
  RandomSeed(*param\thread_pos * 12345)
  
  For y = startPos To endPos
    For x = 0 To lg - 1
      currentPos = y * lg + x
      *dstPixel = *param\addr[1] + currentPos << 2
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      alphaValue = a << 24
      
      Protected noise.f = (Random(1000) / 500.0 - 1.0) * noiseRange
      
      If Not gray
        ; Mode couleur
        newR = Round((oldR + noise) / Steping, #PB_Round_Nearest) * Steping
        newG = Round((oldG + noise) / Steping, #PB_Round_Nearest) * Steping
        newB = Round((oldB + noise) / Steping, #PB_Round_Nearest) * Steping
        clamp(newR, 0, 255)
        clamp(newG, 0, 255)
        clamp(newB, 0, 255)
        *dstPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
      Else
        ; Mode gris
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = Round((g + noise) / Steping, #PB_Round_Nearest) * Steping
        clamp(newG, 0, 255)
        *dstPixel\l = alphaValue | newG * $10101
      EndIf
    Next
  Next
EndProcedure

Procedure RandomDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_Random
    *param\name = "RandomDither"
    *param\remarque = "Random noise dithering"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Intensité"
    *param\info[3] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 1   : *param\info_data(2, 1) = 100 : *param\info_data(2, 2) = 50
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 2   : *param\info_data(3, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@RandomDither_MT(), 2, 0)  ; Parallélisable
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 58
; FirstLine = 12
; Folding = -
; EnableXP
; DPIAware