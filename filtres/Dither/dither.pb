; ==============================================================================
; FILTRES DE DITHERING AVANCÉS
; Collection complète d'algorithmes de dithering pour PureBasic
; ==============================================================================

; ------------------------------------------------------------------------------
; MACROS COMMUNES
; ------------------------------------------------------------------------------

; Macro de diffusion d'erreur couleur (générique)
Macro DitherDiffuse(mul, div, offset)
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
Macro DitherDiffuseGray(mul, div, offset)
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
        DitherDiffuse(7, 48, 1)
        DitherDiffuse(5, 48, 2)
        ; Ligne suivante
        DitherDiffuse(3, 48, lg - 2)
        DitherDiffuse(5, 48, lg - 1)
        DitherDiffuse(7, 48, lg)
        DitherDiffuse(5, 48, lg + 1)
        DitherDiffuse(3, 48, lg + 2)
        ; Ligne +2
        DitherDiffuse(1, 48, 2*lg - 2)
        DitherDiffuse(3, 48, 2*lg - 1)
        DitherDiffuse(5, 48, 2*lg)
        DitherDiffuse(3, 48, 2*lg + 1)
        DitherDiffuse(1, 48, 2*lg + 2)
      Else
        Protected g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        DitherDiffuseGray(7, 48, 1)
        DitherDiffuseGray(5, 48, 2)
        DitherDiffuseGray(3, 48, lg - 2)
        DitherDiffuseGray(5, 48, lg - 1)
        DitherDiffuseGray(7, 48, lg)
        DitherDiffuseGray(5, 48, lg + 1)
        DitherDiffuseGray(3, 48, lg + 2)
        DitherDiffuseGray(1, 48, 2*lg - 2)
        DitherDiffuseGray(3, 48, 2*lg - 1)
        DitherDiffuseGray(5, 48, 2*lg)
        DitherDiffuseGray(3, 48, 2*lg + 1)
        DitherDiffuseGray(1, 48, 2*lg + 2)
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

; ------------------------------------------------------------------------------
; STUCKI DITHER (5x3 kernel)
; ------------------------------------------------------------------------------
Procedure StuckiDither_MT(*param.parametre)
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
  
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max - 1
  
  If startPos < 0 : startPos = 0 : EndIf
  If endPos >= ht - 2 : endPos = ht - 3 : EndIf
  
  ; Stucki: diffusion sur 3 lignes
  ;       X   8   4
  ;   2   4   8   4   2
  ;   1   2   4   2   1  (diviseur: 42)
  
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
        
        DitherDiffuse(8, 42, 1)
        DitherDiffuse(4, 42, 2)
        DitherDiffuse(2, 42, lg - 2)
        DitherDiffuse(4, 42, lg - 1)
        DitherDiffuse(8, 42, lg)
        DitherDiffuse(4, 42, lg + 1)
        DitherDiffuse(2, 42, lg + 2)
        DitherDiffuse(1, 42, 2*lg - 2)
        DitherDiffuse(2, 42, 2*lg - 1)
        DitherDiffuse(4, 42, 2*lg)
        DitherDiffuse(2, 42, 2*lg + 1)
        DitherDiffuse(1, 42, 2*lg + 2)
      Else
        Protected g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        DitherDiffuseGray(8, 42, 1)
        DitherDiffuseGray(4, 42, 2)
        DitherDiffuseGray(2, 42, lg - 2)
        DitherDiffuseGray(4, 42, lg - 1)
        DitherDiffuseGray(8, 42, lg)
        DitherDiffuseGray(4, 42, lg + 1)
        DitherDiffuseGray(2, 42, lg + 2)
        DitherDiffuseGray(1, 42, 2*lg - 2)
        DitherDiffuseGray(2, 42, 2*lg - 1)
        DitherDiffuseGray(4, 42, 2*lg)
        DitherDiffuseGray(2, 42, 2*lg + 1)
        DitherDiffuseGray(1, 42, 2*lg + 2)
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure StuckiDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "StuckiDither"
    *param\remarque = "Stucki dithering (grande diffusion)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@StuckiDither_MT(), 2, 1)
EndProcedure

; ------------------------------------------------------------------------------
; BURKES DITHER (5x2 kernel)
; ------------------------------------------------------------------------------
Procedure BurkesDither_MT(*param.parametre)
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
  
  ; Burkes: diffusion sur 2 lignes
  ;       X   8   4
  ;   2   4   8   4   2  (diviseur: 32)
  
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
        
        DitherDiffuse(8, 32, 1)
        DitherDiffuse(4, 32, 2)
        DitherDiffuse(2, 32, lg - 2)
        DitherDiffuse(4, 32, lg - 1)
        DitherDiffuse(8, 32, lg)
        DitherDiffuse(4, 32, lg + 1)
        DitherDiffuse(2, 32, lg + 2)
      Else
        Protected g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        DitherDiffuseGray(8, 32, 1)
        DitherDiffuseGray(4, 32, 2)
        DitherDiffuseGray(2, 32, lg - 2)
        DitherDiffuseGray(4, 32, lg - 1)
        DitherDiffuseGray(8, 32, lg)
        DitherDiffuseGray(4, 32, lg + 1)
        DitherDiffuseGray(2, 32, lg + 2)
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure BurkesDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "BurkesDither"
    *param\remarque = "Burkes dithering (2 lignes)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@BurkesDither_MT(), 2, 1)
EndProcedure

; ------------------------------------------------------------------------------
; SIERRA DITHER (5x3 kernel)
; ------------------------------------------------------------------------------
Procedure SierraDither_MT(*param.parametre)
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
  
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max - 1
  
  If startPos < 0 : startPos = 0 : EndIf
  If endPos >= ht - 2 : endPos = ht - 3 : EndIf
  
  ; Sierra: diffusion sur 3 lignes
  ;       X   5   3
  ;   2   4   5   4   2
  ;       2   3   2      (diviseur: 32)
  
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
        
        DitherDiffuse(5, 32, 1)
        DitherDiffuse(3, 32, 2)
        DitherDiffuse(2, 32, lg - 2)
        DitherDiffuse(4, 32, lg - 1)
        DitherDiffuse(5, 32, lg)
        DitherDiffuse(4, 32, lg + 1)
        DitherDiffuse(2, 32, lg + 2)
        DitherDiffuse(2, 32, 2*lg - 1)
        DitherDiffuse(3, 32, 2*lg)
        DitherDiffuse(2, 32, 2*lg + 1)
      Else
        Protected g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        DitherDiffuseGray(5, 32, 1)
        DitherDiffuseGray(3, 32, 2)
        DitherDiffuseGray(2, 32, lg - 2)
        DitherDiffuseGray(4, 32, lg - 1)
        DitherDiffuseGray(5, 32, lg)
        DitherDiffuseGray(4, 32, lg + 1)
        DitherDiffuseGray(2, 32, lg + 2)
        DitherDiffuseGray(2, 32, 2*lg - 1)
        DitherDiffuseGray(3, 32, 2*lg)
        DitherDiffuseGray(2, 32, 2*lg + 1)
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure SierraDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "SierraDither"
    *param\remarque = "Sierra dithering (3 lignes)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@SierraDither_MT(), 2, 1)
EndProcedure

; ------------------------------------------------------------------------------
; SIERRA LITE DITHER (3x2 kernel - version légère)
; ------------------------------------------------------------------------------
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
        
        DitherDiffuse(2, 4, 1)
        DitherDiffuse(1, 4, lg - 1)
        DitherDiffuse(1, 4, lg)
      Else
        Protected g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        DitherDiffuseGray(2, 4, 1)
        DitherDiffuseGray(1, 4, lg - 1)
        DitherDiffuseGray(1, 4, lg)
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

; ==============================================================================
; FILTRES DE DITHERING - PARTIE 2
; Atkinson, Shiau-Fan, Bayer, Random, Kite et Lite
; ==============================================================================

; ------------------------------------------------------------------------------
; ATKINSON DITHER (3x3 kernel - utilisé par MacPaint)
; ------------------------------------------------------------------------------
Procedure AtkinsonDither_MT(*param.parametre)
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
  
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max - 1
  
  If startPos < 0 : startPos = 0 : EndIf
  If endPos >= ht - 2 : endPos = ht - 3 : EndIf
  
  ; Atkinson: diffusion sur 3 lignes (divise l'erreur par 8, pas tous distribués)
  ;     X   1   1
  ;   1   1   1
  ;       1       (diviseur: 8, mais somme = 6/8)
  
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
        
        ; Ligne courante
        DitherDiffuse(1, 8, 1)
        DitherDiffuse(1, 8, 2)
        ; Ligne suivante
        DitherDiffuse(1, 8, lg - 1)
        DitherDiffuse(1, 8, lg)
        DitherDiffuse(1, 8, lg + 1)
        ; Ligne +2
        DitherDiffuse(1, 8, 2*lg)
      Else
        Protected g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        DitherDiffuseGray(1, 8, 1)
        DitherDiffuseGray(1, 8, 2)
        DitherDiffuseGray(1, 8, lg - 1)
        DitherDiffuseGray(1, 8, lg)
        DitherDiffuseGray(1, 8, lg + 1)
        DitherDiffuseGray(1, 8, 2*lg)
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure AtkinsonDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "AtkinsonDither"
    *param\remarque = "Atkinson dithering (MacPaint style)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@AtkinsonDither_MT(), 2, 1)
EndProcedure

; ------------------------------------------------------------------------------
; SHIAU-FAN DITHER (5x2 kernel)
; ------------------------------------------------------------------------------
Procedure ShiauFanDither_MT(*param.parametre)
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
  
  ; Shiau-Fan: diffusion sur 2 lignes
  ;       X   4
  ;   1   1   2   1   1  (diviseur: 10)
  
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
        
        DitherDiffuse(4, 10, 1)
        DitherDiffuse(1, 10, lg - 2)
        DitherDiffuse(1, 10, lg - 1)
        DitherDiffuse(2, 10, lg)
        DitherDiffuse(1, 10, lg + 1)
        DitherDiffuse(1, 10, lg + 2)
      Else
        Protected g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        DitherDiffuseGray(4, 10, 1)
        DitherDiffuseGray(1, 10, lg - 2)
        DitherDiffuseGray(1, 10, lg - 1)
        DitherDiffuseGray(2, 10, lg)
        DitherDiffuseGray(1, 10, lg + 1)
        DitherDiffuseGray(1, 10, lg + 2)
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure ShiauFanDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "ShiauFanDither"
    *param\remarque = "Shiau-Fan dithering"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@ShiauFanDither_MT(), 2, 1)
EndProcedure

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
  Data.a  0,  8,  2, 10
  Data.a 12,  4, 14,  6
  Data.a  3, 11,  1,  9
  Data.a 15,  7, 13,  5
  
  Restore
  For y = 0 To 3
    For x = 0 To 3
      Read.a Bayer4x4(y, x)
    Next
  Next
  
  Protected Dim Bayer8x8(7, 7)
  Data.a  0, 32,  8, 40,  2, 34, 10, 42
  Data.a 48, 16, 56, 24, 50, 18, 58, 26
  Data.a 12, 44,  4, 36, 14, 46,  6, 38
  Data.a 60, 28, 52, 20, 62, 30, 54, 22
  Data.a  3, 35, 11, 43,  1, 33,  9, 41
  Data.a 51, 19, 59, 27, 49, 17, 57, 25
  Data.a 15, 47,  7, 39, 13, 45,  5, 37
  Data.a 63, 31, 55, 23, 61, 29, 53, 21
  
  Restore
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
        Protected g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
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
    *param\subtype = #Dither_Ordered
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
        Protected g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
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
    *param\subtype = #Dither_Stochastic
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

; ------------------------------------------------------------------------------
; KITE DITHER (variante minimale 2x2)
; ------------------------------------------------------------------------------
Procedure KiteDither_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected totalPixels = lg * ht
  Protected x, y, currentPos
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
  
  For Protected i = 0 To 255
    Protected var = Round(i * reciprocal, #PB_Round_Nearest)
    var = var * Steping
    clamp(var, 0, 255)
    PokeA(*ndc + i, var)
  Next
  
  Protected startPos = (*param\thread_pos * (ht - 1)) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * (ht - 1)) / *param\thread_max - 1
  
  If startPos < 0 : startPos = 0 : EndIf
  If endPos >= ht - 1 : endPos = ht - 2 : EndIf
  
  ; Kite: diffusion minimale
  ;   X   1
  ;   1       (diviseur: 2)
  
  For y = startPos To endPos
    For x = 0 To lg - 2
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
        
        DitherDiffuse(1, 2, 1)
        DitherDiffuse(1, 2, lg)
      Else
        Protected g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        DitherDiffuseGray(1, 2, 1)
        DitherDiffuseGray(1, 2, lg)
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure KiteDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "KiteDither"
    *param\remarque = "Kite dithering (très rapide)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  filter_start(@KiteDither_MT(), 2, 1)
EndProcedure

; ------------------------------------------------------------------------------
; LITE DITHER (variante ultra-rapide 1 pixel)
; ------------------------------------------------------------------------------
Procedure LiteDither_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected totalPixels = lg * ht
  Protected x, y, currentPos
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
  
  For Protected i = 0 To 255
    Protected var = Round(i * reciprocal, #PB_Round_Nearest)
    var = var * Steping
    clamp(var, 0, 255)
    PokeA(*ndc + i, var)
  Next
  
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  
  ; Lite: diffusion vers un seul pixel (droite)
  ;   X   1  (diviseur: 1, pas de diffusion réelle, juste quantification)
  
  For y = startPos To endPos
    For x = 0 To lg - 2
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
        
        ; Diffusion minimale vers la droite uniquement
        DitherDiffuse(1, 1, 1)
      Else
        Protected g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        DitherDiffuseGray(1, 1, 1)
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure LiteDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "LiteDither"
    *param\remarque = "Lite dithering (ultra-rapide)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 1126
; FirstLine = 1066
; Folding = -----
; EnableXP
; DPIAware