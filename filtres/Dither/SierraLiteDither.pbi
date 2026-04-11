; Macro de diffusion d'erreur couleur (générique)
Macro SierraLiteDither_DitherDiffuse(mul, div, offset)
  If currentPos + offset >= 0 And currentPos + offset < totalPixels
    *dstPixel.Pixel32 = *param\addr[1] + (currentPos + offset) << 2
    getrgb(*dstPixel\l, r, g, b)
    r + (errR * mul) / div
    g + (errG * mul) / div
    b + (errB * mul) / div
    clamp_RGB(r, g, b)
    *dstPixel\l = alphaValue | (r << 16) | (g << 8) | b
  EndIf
EndMacro

; Macro de diffusion d'erreur niveaux de gris (générique)
Macro SierraLiteDither_DitherDiffuseGray(mul, div, offset)
  If currentPos + offset >= 0 And currentPos + offset < totalPixels
    *dstPixel.Pixel32 = *param\addr[1] + (currentPos + offset) << 2
    getargb(*dstPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * mul) / div
    clamp(g, 0, 255)
    *dstPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

Procedure SierraLiteDither_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected totalPixels = lg * ht
  Protected i, x, y, currentPos
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected errR, errG, errB, a, r, g, b
  Protected alphaValue, *dstPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  
  clamp(levels, 2, 64)
  
  Protected *ndc = AllocateMemory(256)
  If Not *ndc : ProcedureReturn : EndIf
  
  Protected Steping.f = 255.0 / (levels - 1)
  Protected reciprocal.f = 1.0 / Steping
  
  For i = 0 To 255
    Protected var = Round(i * reciprocal, #PB_Round_Nearest)
    var = var * Steping
    clamp(var, 0, 255)
    PokeA(*ndc + i, var)
  Next
  
  Protected startPos = (*param\thread_pos * (ht - 1)) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * (ht - 1)) / *param\thread_max - 1
  
  If startPos < 0 : startPos = 0 : EndIf
  If endPos >= ht - 1 : endPos = ht - 2 : EndIf
  
  ; Sierra Lite: diffusion sur 2 lignes
  ;     X   2
  ;   1   1     (diviseur: 4)
  
  For y = startPos To endPos
    For x = 1 To lg - 2
      currentPos = y * lg + x
      *dstPixel = *param\addr[1] + currentPos << 2
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      alphaValue = a << 24
      
      If Not gray
        newR = PeekA(*ndc + oldR)
        newG = PeekA(*ndc + oldG)
        newB = PeekA(*ndc + oldB)
        errR = oldR - newR
        errG = oldG - newG
        errB = oldB - newB
        *dstPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
        
        SierraLiteDither_DitherDiffuse(2, 4, 1)
        SierraLiteDither_DitherDiffuse(1, 4, lg - 1)
        SierraLiteDither_DitherDiffuse(1, 4, lg)
      Else
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        SierraLiteDither_DitherDiffuseGray(2, 4, 1)
        SierraLiteDither_DitherDiffuseGray(1, 4, lg - 1)
        SierraLiteDither_DitherDiffuseGray(1, 4, lg)
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure SierraLiteDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "SierraLiteDither"
    *param\remarque = "Sierra Lite (version rapide)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@SierraLiteDither_MT(), 2, 1)
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 99
; FirstLine = 53
; Folding = -
; EnableXP
; DPIAware