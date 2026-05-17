; Macro de diffusion d'erreur couleur (générique)
Macro SierraDither_DitherDiffuse(mul, div, offset)
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
Macro SierraDither_DitherDiffuseGray(mul, div, offset)
  If currentPos + offset >= 0 And currentPos + offset < totalPixels
    *dstPixel.Pixel32 = *FilterCtx\addr[1] + (currentPos + offset) << 2
    getargb(*dstPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * mul) / div
    clamp(g, 0, 255)
    *dstPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

Procedure SierraDither_MT(*FilterCtx.FilterParams)
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
    
    ; Sierra: diffusion sur 3 lignes
    ;        X   5   3
    ;    2   4   5   4   2
    ;        2   3   2      (diviseur: 32)
    
    For y = startPos To endPos
      For x = 2 To lg - 3
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
          
          SierraDither_DitherDiffuse(5, 32, 1)
          SierraDither_DitherDiffuse(3, 32, 2)
          SierraDither_DitherDiffuse(2, 32, (lg - 2))
          SierraDither_DitherDiffuse(4, 32, (lg - 1))
          SierraDither_DitherDiffuse(5, 32, lg)
          SierraDither_DitherDiffuse(4, 32, (lg + 1))
          SierraDither_DitherDiffuse(2, 32, (lg + 2))
          SierraDither_DitherDiffuse(2, 32, (2 * lg - 1))
          SierraDither_DitherDiffuse(3, 32, (2 * lg))
          SierraDither_DitherDiffuse(2, 32, (2 * lg + 1))
        Else
          g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          newG = PeekA(*ndc + g)
          errG = g - newG
          *dstPixel\l = alphaValue | newG * $10101
          
          SierraDither_DitherDiffuseGray(5, 32, 1)
          SierraDither_DitherDiffuseGray(3, 32, 2)
          SierraDither_DitherDiffuseGray(2, 32, (lg - 2))
          SierraDither_DitherDiffuseGray(4, 32, (lg - 1))
          SierraDither_DitherDiffuseGray(5, 32, lg)
          SierraDither_DitherDiffuseGray(4, 32, (lg + 1))
          SierraDither_DitherDiffuseGray(2, 32, (lg + 2))
          SierraDither_DitherDiffuseGray(2, 32, (2 * lg - 1))
          SierraDither_DitherDiffuseGray(3, 32, (2 * lg))
          SierraDither_DitherDiffuseGray(2, 32, (2 * lg + 1))
        EndIf
      Next
    Next
    
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure SierraDitherEx(*FilterCtx.FilterParams)
  Restore SierraDither_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lancement du filtre (1 thread car la diffusion d'erreur est séquentielle)
    Create_MultiThread_MT(@SierraDither_MT(), 1)
    
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure SierraDither(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  SierraDitherEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  SierraDither_data:
  Data.s "SierraDither"
  Data.s "Sierra dithering (3 lignes)"
  Data.i #FilterType_Dithering
  Data.i #Dither_ErrorDiffusion
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 128
; FirstLine = 100
; Folding = -
; EnableXP
; DPIAware