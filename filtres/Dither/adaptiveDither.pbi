; ------------------------------------------------------------------------------
; ADAPTIVE DITHER - Diffusion adaptative selon le contenu local
; ------------------------------------------------------------------------------

; Calcule la complexité locale (gradient)
Procedure.f AdaptiveDither_LocalComplexity(*baseAddr, x, y, lg, ht)
  Protected r1, g1, b1, r2, g2, b2
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
  
  ProcedureReturn gradient / 6.0  ; Normalisation
EndProcedure

Procedure AdaptiveDither_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, i
    Protected oldR, oldG, oldB, newR, newG, newB
    Protected errR, errG, errB, a, r, g, b
    Protected alphaValue, *dstPixel.Pixel32, *targetPixel.Pixel32
    Protected levels = \option[0]
    Protected gray = \option[1]
    Protected sensitivity = \option[2]
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
    
    macro_calul_tread((ht))
    
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    
    Protected *baseAddr = \addr[1]
    
    ; Diffusion adaptative avec analyse locale
    For y = startPos To endPos
      For x = 0 To lg - 1
        *dstPixel = *baseAddr + (y * lg + x) << 2
        
        getargb(*dstPixel\l, a, oldR, oldG, oldB)
        alphaValue = a << 24
        
        complexity = AdaptiveDither_LocalComplexity(*baseAddr, x, y, lg, ht)
        
        adaptFactor = 1.0 - (complexity * sensitivity / 25500.0)
        If adaptFactor < 0.3 : adaptFactor = 0.3 : EndIf
        If adaptFactor > 1.0 : adaptFactor = 1.0 : EndIf
        
        If complexity > 50  ; Zone complexe
          rightWeight = 7.0 * adaptFactor / 16.0
          downWeight = 5.0 * adaptFactor / 16.0
          diagWeight = 3.0 * adaptFactor / 16.0
        Else  ; Zone lisse
          rightWeight = 7.0 / 16.0
          downWeight = 5.0 / 16.0
          diagWeight = 3.0 / 16.0
        EndIf
        
        If Not gray
          newR = PeekA(*ndc + oldR)
          newG = PeekA(*ndc + oldG)
          newB = PeekA(*ndc + oldB)
          errR = oldR - newR
          errG = oldG - newG
          errB = oldB - newB
          *dstPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
          
          If x < lg - 1
            *targetPixel = *baseAddr + (y * lg + x + 1) << 2
            getrgb(*targetPixel\l, r, g, b)
            r + errR * rightWeight : g + errG * rightWeight : b + errB * rightWeight
            clamp_RGB(r, g, b)
            *targetPixel\l = alphaValue | (r << 16) | (g << 8) | b
          EndIf
          
          If y < ht - 1
            If x > 0
              *targetPixel = *baseAddr + ((y + 1) * lg + x - 1) << 2
              getrgb(*targetPixel\l, r, g, b)
              r + errR * diagWeight : g + errG * diagWeight : b + errB * diagWeight
              clamp_RGB(r, g, b)
              *targetPixel\l = alphaValue | (r << 16) | (g << 8) | b
            EndIf
            *targetPixel = *baseAddr + ((y + 1) * lg + x) << 2
            getrgb(*targetPixel\l, r, g, b)
            r + errR * downWeight : g + errG * downWeight : b + errB * downWeight
            clamp_RGB(r, g, b)
            *targetPixel\l = alphaValue | (r << 16) | (g << 8) | b
            If x < lg - 1
              *targetPixel = *baseAddr + ((y + 1) * lg + x + 1) << 2
              getrgb(*targetPixel\l, r, g, b)
              Protected remWeight.f = (1.0 - rightWeight - downWeight - diagWeight)
              r + errR * remWeight : g + errG * remWeight : b + errB * remWeight
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
          
          If x < lg - 1
            *targetPixel = *baseAddr + (y * lg + x + 1) << 2
            getargb(*targetPixel\l, a, r, g, b)
            g = (r * 77 + g * 150 + b * 29) >> 8
            g + errG * rightWeight : clamp(g, 0, 255)
            *targetPixel\l = (a << 24) | g * $10101
          EndIf
          
          If y < ht - 1
            If x > 0
              *targetPixel = *baseAddr + ((y + 1) * lg + x - 1) << 2
              getargb(*targetPixel\l, a, r, g, b)
              g = (r * 77 + g * 150 + b * 29) >> 8
              g + errG * diagWeight : clamp(g, 0, 255)
              *targetPixel\l = (a << 24) | g * $10101
            EndIf
            *targetPixel = *baseAddr + ((y + 1) * lg + x) << 2
            getargb(*targetPixel\l, a, r, g, b)
            g = (r * 77 + g * 150 + b * 29) >> 8
            g + errG * downWeight : clamp(g, 0, 255)
            *targetPixel\l = (a << 24) | g * $10101
            If x < lg - 1
              *targetPixel = *baseAddr + ((y + 1) * lg + x + 1) << 2
              getargb(*targetPixel\l, a, r, g, b)
              g = (r * 77 + g * 150 + b * 29) >> 8
              g + errG * (1.0 - rightWeight - downWeight - diagWeight) : clamp(g, 0, 255)
              *targetPixel\l = (a << 24) | g * $10101
            EndIf
          EndIf
        EndIf
      Next
    Next
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure AdaptiveDitherEx(*FilterCtx.FilterParams)
  Restore AdaptiveDither_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Note: La diffusion d'erreur est complexe à paralléliser par lignes, 
    ; mais ici traitée par blocs de threads standards.
    Create_MultiThread_MT(@AdaptiveDither_MT())
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure AdaptiveDither(source, cible, mask, levels, gray, sensitivity)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
    \option[2] = sensitivity
  EndWith
  AdaptiveDitherEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  AdaptiveDither_data:
  Data.s "AdaptiveDither"
  Data.s "Dithering adaptatif selon le contenu local"
  Data.i #FilterType_Dithering
  Data.i #Dither_Adaptive
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "Sensibilité"
  Data.i 0, 100, 50
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 190
; FirstLine = 165
; Folding = -
; EnableXP
; DPIAware