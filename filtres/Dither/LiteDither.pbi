; ------------------------------------------------------------------------------
; LITE DITHER (variante ultra-rapide 1 pixel) - VERSION OPTIMISÉE
; ------------------------------------------------------------------------------

; Macro de diffusion d'erreur couleur (optimisée)
Macro LiteDither_DitherDiffuse(mul, div, offset)
  If x < lg - 1  ; Vérification simplifiée pour offset = 1
    *dstPixel.Pixel32 = *nextPixel
    getrgb(*dstPixel\l, r, g, b)
    r + (errR * mul) / div
    g + (errG * mul) / div
    b + (errB * mul) / div
    clamp_RGB(r, g, b)
    *dstPixel\l = alphaValue | (r << 16) | (g << 8) | b
  EndIf
EndMacro

; Macro de diffusion d'erreur niveaux de gris (optimisée)
Macro LiteDither_DitherDiffuseGray(mul, div, offset)
  If x < lg - 1
    *dstPixel.Pixel32 = *nextPixel
    getargb(*dstPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * mul) / div
    clamp(g, 0, 255)
    *dstPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

Procedure LiteDither_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected errR, errG, errB, a, r, g, b
  Protected alphaValue, *dstPixel.Pixel32, *nextPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  Protected var.i
  
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
  
  ; Précalcul de l'adresse de base
  Protected *baseAddr = *param\addr[1]
  Protected lineSize = lg << 2  ; lg * 4 octets par pixel

  ; Lite: diffusion vers un seul pixel (droite)
  For y = startPos To endPos
    For x = 0 To lg - 2
      *dstPixel = *baseAddr + (y * lg + x) << 2
      *nextPixel = *dstPixel + 4  ; Pixel suivant (à droite)
      
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      alphaValue = a << 24
      
      If Not gray
        ; Mode couleur
        newR = PeekA(*ndc + oldR)
        newG = PeekA(*ndc + oldG)
        newB = PeekA(*ndc + oldB)
        errR = oldR - newR
        errG = oldG - newG
        errB = oldB - newB
        *dstPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
        
        ; Diffusion vers la droite (100% de l'erreur)
        LiteDither_DitherDiffuse(1, 1, 1)
      Else
        ; Mode niveaux de gris
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        LiteDither_DitherDiffuseGray(1, 1, 1)
      EndIf
    Next
    
    ; Traiter le dernier pixel de la ligne (sans diffusion)
    getargb(*dstPixel\l, a, oldR, oldG, oldB)
    alphaValue = a << 24
    
    If Not gray
      newR = PeekA(*ndc + oldR)
      newG = PeekA(*ndc + oldG)
      newB = PeekA(*ndc + oldB)
      *dstPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
    Else
      g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
      newG = PeekA(*ndc + g)
      *dstPixel\l = alphaValue | newG * $10101
    EndIf
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure LiteDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_Fast
    *param\name = "LiteDither"
    *param\remarque = "Lite dithering (ultra-rapide)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    
    ProcedureReturn
  EndIf
  filter_start(@LiteDither_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 118
; FirstLine = 62
; Folding = -
; EnableXP
; DPIAware