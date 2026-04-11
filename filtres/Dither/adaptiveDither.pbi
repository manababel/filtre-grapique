; ------------------------------------------------------------------------------
; ADAPTIVE DITHER - Diffusion adaptative selon le contenu local
; ------------------------------------------------------------------------------

; Macro de diffusion d'erreur couleur adaptative
Macro AdaptiveDither_DitherDiffuse(mul, div, offset)
  If x + offset >= 0 And x + offset < lg
    *targetPixel.Pixel32 = *baseAddr + (y * lg + x + offset) << 2
    getrgb(*targetPixel\l, r, g, b)
    r + (errR * mul) / div
    g + (errG * mul) / div
    b + (errB * mul) / div
    clamp_RGB(r, g, b)
    *targetPixel\l = alphaValue | (r << 16) | (g << 8) | b
  EndIf
EndMacro

; Macro de diffusion d'erreur niveaux de gris adaptative
Macro AdaptiveDither_DitherDiffuseGray(mul, div, offset)
  If x + offset >= 0 And x + offset < lg
    *targetPixel.Pixel32 = *baseAddr + (y * lg + x + offset) << 2
    getargb(*targetPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * mul) / div
    clamp(g, 0, 255)
    *targetPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

; Calcule la complexité locale (gradient)
Procedure.f AdaptiveDither_LocalComplexity(*baseAddr, x, y, lg, ht)
  Protected r1, g1, b1, r2, g2, b2, a
  Protected *pixel1.Pixel32, *pixel2.Pixel32
  Protected gradient.f = 0.0
  
  ; Gradient horizontal
  If x < lg - 1
    *pixel1 = *baseAddr + (y * lg + x) << 2
    *pixel2 = *baseAddr + (y * lg + x + 1) << 2
    getrgb(*pixel1\l, r1, g1, b1)
    getrgb(*pixel2\l, r2, g2, b2)
    gradient + Abs(r2 - r1) + Abs(g2 - g1) + Abs(b2 - b1)
  EndIf
  
  ; Gradient vertical
  If y < ht - 1
    *pixel1 = *baseAddr + (y * lg + x) << 2
    *pixel2 = *baseAddr + ((y + 1) * lg + x) << 2
    getrgb(*pixel1\l, r1, g1, b1)
    getrgb(*pixel2\l, r2, g2, b2)
    gradient + Abs(r2 - r1) + Abs(g2 - g1) + Abs(b2 - b1)
  EndIf
  
  ProcedureReturn gradient / 6.0  ; Normalisation (max 255*3*2 = 1530)
EndProcedure

Procedure AdaptiveDither_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected errR, errG, errB, a, r, g, b
  Protected alphaValue, *dstPixel.Pixel32, *targetPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  Protected sensitivity = *param\option[2]
  Protected var.i
  Protected complexity.f, adaptFactor.f
  Protected rightWeight.f, downWeight.f, diagWeight.f
  
  clamp(levels, 2, 64)
  clamp(sensitivity, 0, 100)
  
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
  Protected lineSize = lg << 2

  ; Diffusion adaptative avec analyse locale
  For y = startPos To endPos
    For x = 0 To lg - 1
      *dstPixel = *baseAddr + (y * lg + x) << 2
      
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      alphaValue = a << 24
      
      ; Analyse de la complexité locale
      complexity = AdaptiveDither_LocalComplexity(*baseAddr, x, y, lg, ht)
      
      ; Facteur d'adaptation basé sur la sensibilité
      adaptFactor = 1.0 - (complexity * sensitivity / 25500.0)
      If adaptFactor < 0.3 : adaptFactor = 0.3 : EndIf
      If adaptFactor > 1.0 : adaptFactor = 1.0 : EndIf
      
      ; Calcul des poids de diffusion (adaptatifs)
      If complexity > 50  ; Zone complexe (contours)
        ; Distribution plus uniforme pour préserver les détails
        rightWeight = 7.0 * adaptFactor / 16.0
        downWeight = 5.0 * adaptFactor / 16.0
        diagWeight = 3.0 * adaptFactor / 16.0
      Else  ; Zone lisse
        ; Distribution classique Floyd-Steinberg
        rightWeight = 7.0 / 16.0
        downWeight = 5.0 / 16.0
        diagWeight = 3.0 / 16.0
      EndIf
      
      If Not gray
        ; Mode couleur
        newR = PeekA(*ndc + oldR)
        newG = PeekA(*ndc + oldG)
        newB = PeekA(*ndc + oldB)
        errR = oldR - newR
        errG = oldG - newG
        errB = oldB - newB
        *dstPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
        
        ; Diffusion adaptative
        If x < lg - 1  ; Droite (7/16)
          *targetPixel = *baseAddr + (y * lg + x + 1) << 2
          getrgb(*targetPixel\l, r, g, b)
          r + errR * rightWeight
          g + errG * rightWeight
          b + errB * rightWeight
          clamp_RGB(r, g, b)
          *targetPixel\l = alphaValue | (r << 16) | (g << 8) | b
        EndIf
        
        If y < ht - 1
          ; Bas-gauche (3/16)
          If x > 0
            *targetPixel = *baseAddr + ((y + 1) * lg + x - 1) << 2
            getrgb(*targetPixel\l, r, g, b)
            r + errR * diagWeight
            g + errG * diagWeight
            b + errB * diagWeight
            clamp_RGB(r, g, b)
            *targetPixel\l = alphaValue | (r << 16) | (g << 8) | b
          EndIf
          
          ; Bas (5/16)
          *targetPixel = *baseAddr + ((y + 1) * lg + x) << 2
          getrgb(*targetPixel\l, r, g, b)
          r + errR * downWeight
          g + errG * downWeight
          b + errB * downWeight
          clamp_RGB(r, g, b)
          *targetPixel\l = alphaValue | (r << 16) | (g << 8) | b
          
          ; Bas-droite (1/16) - reste de l'erreur
          If x < lg - 1
            *targetPixel = *baseAddr + ((y + 1) * lg + x + 1) << 2
            getrgb(*targetPixel\l, r, g, b)
            r + errR * (1.0 - rightWeight - downWeight - diagWeight)
            g + errG * (1.0 - rightWeight - downWeight - diagWeight)
            b + errB * (1.0 - rightWeight - downWeight - diagWeight)
            clamp_RGB(r, g, b)
            *targetPixel\l = alphaValue | (r << 16) | (g << 8) | b
          EndIf
        EndIf
      Else
        ; Mode niveaux de gris
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
        
        ; Diffusion adaptative (niveaux de gris)
        If x < lg - 1
          *targetPixel = *baseAddr + (y * lg + x + 1) << 2
          getargb(*targetPixel\l, a, r, g, b)
          g = (r * 77 + g * 150 + b * 29) >> 8
          g + errG * rightWeight
          clamp(g, 0, 255)
          *targetPixel\l = (a << 24) | g * $10101
        EndIf
        
        If y < ht - 1
          If x > 0
            *targetPixel = *baseAddr + ((y + 1) * lg + x - 1) << 2
            getargb(*targetPixel\l, a, r, g, b)
            g = (r * 77 + g * 150 + b * 29) >> 8
            g + errG * diagWeight
            clamp(g, 0, 255)
            *targetPixel\l = (a << 24) | g * $10101
          EndIf
          
          *targetPixel = *baseAddr + ((y + 1) * lg + x) << 2
          getargb(*targetPixel\l, a, r, g, b)
          g = (r * 77 + g * 150 + b * 29) >> 8
          g + errG * downWeight
          clamp(g, 0, 255)
          *targetPixel\l = (a << 24) | g * $10101
          
          If x < lg - 1
            *targetPixel = *baseAddr + ((y + 1) * lg + x + 1) << 2
            getargb(*targetPixel\l, a, r, g, b)
            g = (r * 77 + g * 150 + b * 29) >> 8
            g + errG * (1.0 - rightWeight - downWeight - diagWeight)
            clamp(g, 0, 255)
            *targetPixel\l = (a << 24) | g * $10101
          EndIf
        EndIf
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure AdaptiveDither(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_Adaptive
    *param\name = "AdaptiveDither"
    *param\remarque = "Dithering adaptatif selon le contenu local"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Sensibilité"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 100 : *param\info_data(2, 2) = 50
    
    ProcedureReturn
  EndIf
  filter_start(@AdaptiveDither_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 230
; FirstLine = 183
; Folding = -
; EnableXP
; DPIAware