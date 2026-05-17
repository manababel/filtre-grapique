; Macro de diffusion d'erreur couleur (générique)
Macro ShiauFanDither_DitherDiffuse(mul, div, offset)
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
Macro ShiauFanDither_DitherDiffuseGray(mul, div, offset)
  If currentPos + offset >= 0 And currentPos + offset < totalPixels
    *dstPixel.Pixel32 = *FilterCtx\addr[1] + (currentPos + offset) << 2
    getargb(*dstPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * mul) / div
    clamp(g, 0, 255)
    *dstPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

Procedure ShiauFanDither_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht =\image_ht[0]
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
    
    Protected startPos = (\thread_pos * (ht - 1)) / \thread_max
    Protected endPos = ((\thread_pos + 1) * (ht - 1)) / \thread_max - 1
    
    If startPos < 0 : startPos = 0 : EndIf
    If endPos >= ht - 1 : endPos = ht - 2 : EndIf
    
    ; Shiau-Fan: diffusion sur 2 lignes
    ;       X   4
    ;   1   1   2   1   1  (diviseur: 10)
    
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
          
          ShiauFanDither_DitherDiffuse(4, 10, 1)
          ShiauFanDither_DitherDiffuse(1, 10, lg - 2)
          ShiauFanDither_DitherDiffuse(1, 10, lg - 1)
          ShiauFanDither_DitherDiffuse(2, 10, lg)
          ShiauFanDither_DitherDiffuse(1, 10, lg + 1)
          ShiauFanDither_DitherDiffuse(1, 10, lg + 2)
        Else
          g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          newG = PeekA(*ndc + g)
          errG = g - newG
          *dstPixel\l = alphaValue | newG * $10101
          
          ShiauFanDither_DitherDiffuseGray(4, 10, 1)
          ShiauFanDither_DitherDiffuseGray(1, 10, lg - 2)
          ShiauFanDither_DitherDiffuseGray(1, 10, lg - 1)
          ShiauFanDither_DitherDiffuseGray(2, 10, lg)
          ShiauFanDither_DitherDiffuseGray(1, 10, lg + 1)
          ShiauFanDither_DitherDiffuseGray(1, 10, lg + 2)
        EndIf
      Next
    Next
  EndWith
  FreeMemory(*ndc)
EndProcedure

Procedure ShiauFanDitherEx(*FilterCtx.FilterParams)
  Restore ShiauFanDither_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@ShiauFanDither_MT(),1)
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure ShiauFanDither(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  StuckiDitherEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  ShiauFanDither_data:
  Data.s "ShiauFanDither"
  Data.s "Shiau-Fan dithering"
  Data.i #FilterType_Dithering
  Data.i #Dither_ErrorDiffusion
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 115
; FirstLine = 87
; Folding = -
; EnableXP
; DPIAware