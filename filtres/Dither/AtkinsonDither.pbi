; Macro de diffusion d'erreur couleur (générique)
Macro AtkinsonDither_DitherDiffuse(mul, div, offset)
  If currentPos + offset >= 0 And currentPos + offset < totalPixels
    *dstPixel.Pixel32 = *FilterCtx\addr[1] + (currentPos + offset) << 2
    getrgb(*dstPixel\l, r, g, b)
    r + (errR * mul) / div
    g + (errG * mul) / div
    b + (errB * mul) / div
    clamp_RGB(r, g, b)
    *dstPixel\l = alphaValue | (r << 16) | (g << 8) | b
  EndIf
EndMacro

; Macro de diffusion d'erreur niveaux de gris (générique)
Macro AtkinsonDither_DitherDiffuseGray(mul, div, offset)
  If currentPos + offset >= 0 And currentPos + offset < totalPixels
    *dstPixel.Pixel32 = *FilterCtx\addr[1] + (currentPos + offset) << 2
    getargb(*dstPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * mul) / div
    clamp(g, 0, 255)
    *dstPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

Procedure AtkinsonDither_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected totalPixels = lg * ht
    Protected i, x, y, currentPos
    Protected oldR, oldG, oldB, newR, newG, newB
    Protected errR, errG, errB, a, r, g, b
    Protected alphaValue, *dstPixel.Pixel32
    Protected levels = \option[0]
    Protected gray = \option[1]
    
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
    
    macro_calul_tread((ht - 2))
    
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    
    If startPos < 0 : startPos = 0 : EndIf
    If endPos >= ht - 2 : endPos = ht - 3 : EndIf
    
    ; Atkinson: diffusion sur 3 lignes (divise l'erreur par 8, pas tous distribués)
    ;        X   1   1
    ;    1   1   1
    ;        1       (diviseur: 8, mais somme = 6/8)
    
    For y = startPos To endPos
      For x = 1 To lg - 2
        currentPos = y * lg + x
        *dstPixel = \addr[1] + currentPos << 2
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
          AtkinsonDither_DitherDiffuse(1, 8, 1)
          AtkinsonDither_DitherDiffuse(1, 8, 2)
          ; Ligne suivante
          AtkinsonDither_DitherDiffuse(1, 8, (lg - 1))
          AtkinsonDither_DitherDiffuse(1, 8, lg)
          AtkinsonDither_DitherDiffuse(1, 8, (lg + 1))
          ; Ligne +2
          AtkinsonDither_DitherDiffuse(1, 8, (2 * lg))
        Else
          g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          newG = PeekA(*ndc + g)
          errG = g - newG
          *dstPixel\l = alphaValue | newG * $10101
          
          AtkinsonDither_DitherDiffuseGray(1, 8, 1)
          AtkinsonDither_DitherDiffuseGray(1, 8, 2)
          AtkinsonDither_DitherDiffuseGray(1, 8, (lg - 1))
          AtkinsonDither_DitherDiffuseGray(1, 8, lg)
          AtkinsonDither_DitherDiffuseGray(1, 8, (lg + 1))
          AtkinsonDither_DitherDiffuseGray(1, 8, (2 * lg))
        EndIf
      Next
    Next
    
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure AtkinsonDitherEx(*FilterCtx.FilterParams)
  Restore AtkinsonDither_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lancement du filtre (1 thread car Atkinson nécessite un ordre séquentiel)
    Create_MultiThread_MT(@AtkinsonDither_MT(), 1)
    
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure AtkinsonDither(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  AtkinsonDitherEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  AtkinsonDither_data:
  Data.s "AtkinsonDither"
  Data.s "Atkinson dithering (MacPaint style)"
  Data.i #FilterType_Dithering
  Data.i #Dither_ErrorDiffusion
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 123
; FirstLine = 95
; Folding = -
; EnableXP
; DPIAware