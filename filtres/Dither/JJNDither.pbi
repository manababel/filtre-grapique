; ==============================================================================
; FILTRES DE DITHERING AVANCÉS
; Collection complète d'algorithmes de dithering pour PureBasic
; ==============================================================================

; ------------------------------------------------------------------------------
; MACROS COMMUNES
; ------------------------------------------------------------------------------

; Macro de diffusion d'erreur couleur (générique)
Macro JJNDither_DitherDiffuse(mul, div, offset)
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
Macro JJNDither_DitherDiffuseGray(mul, div, offset)
  If currentPos + offset >= 0 And currentPos + offset < totalPixels
    *dstPixel.Pixel32 = *param\addr[1] + (currentPos + offset) << 2
    getargb(*dstPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * mul) / div
    clamp(g, 0, 255)
    *dstPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

; ------------------------------------------------------------------------------
; JARVIS-JUDICE-NINKE DITHER (7x3 kernel)
; ------------------------------------------------------------------------------
Procedure JJNDither_MT(*param.parametre)
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
  
  ; Table de quantification
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
  
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max - 1
  
  If startPos < 0 : startPos = 0 : EndIf
  If endPos >= ht - 2 : endPos = ht - 3 : EndIf
  
  ; Jarvis-Judice-Ninke: diffusion sur 3 lignes
  ;       X   7   5
  ;   3   5   7   5   3
  ;   1   3   5   3   1  (diviseur: 48)
  
  For y = startPos To endPos
    For x = 2 To lg - 3
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
        
        ; Ligne courante
        JJNDither_DitherDiffuse(7, 48, 1)
        JJNDither_DitherDiffuse(5, 48, 2)
        ; Ligne suivante
        JJNDither_DitherDiffuse(3, 48, lg - 2)
        JJNDither_DitherDiffuse(5, 48, lg - 1)
        JJNDither_DitherDiffuse(7, 48, lg)
        JJNDither_DitherDiffuse(5, 48, lg + 1)
        JJNDither_DitherDiffuse(3, 48, lg + 2)
        ; Ligne +2
        JJNDither_DitherDiffuse(1, 48, 2*lg - 2)
        JJNDither_DitherDiffuse(3, 48, 2*lg - 1)
        JJNDither_DitherDiffuse(5, 48, 2*lg)
        JJNDither_DitherDiffuse(3, 48, 2*lg + 1)
        JJNDither_DitherDiffuse(1, 48, 2*lg + 2)
      Else
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        JJNDither_DitherDiffuseGray(7, 48, 1)
        JJNDither_DitherDiffuseGray(5, 48, 2)
        JJNDither_DitherDiffuseGray(3, 48, lg - 2)
        JJNDither_DitherDiffuseGray(5, 48, lg - 1)
        JJNDither_DitherDiffuseGray(7, 48, lg)
        JJNDither_DitherDiffuseGray(5, 48, lg + 1)
        JJNDither_DitherDiffuseGray(3, 48, lg + 2)
        JJNDither_DitherDiffuseGray(1, 48, 2*lg - 2)
        JJNDither_DitherDiffuseGray(3, 48, 2*lg - 1)
        JJNDither_DitherDiffuseGray(5, 48, 2*lg)
        JJNDither_DitherDiffuseGray(3, 48, 2*lg + 1)
        JJNDither_DitherDiffuseGray(1, 48, 2*lg + 2)
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure JJNDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "JJNDither"
    *param\remarque = "Jarvis-Judice-Ninke dithering"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@JJNDither_MT(), 2, 1)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 134
; FirstLine = 87
; Folding = -
; EnableXP
; DPIAware