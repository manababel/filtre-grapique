; ------------------------------------------------------------------------------
; KITE DITHER (variante minimale 2x2)
; ------------------------------------------------------------------------------

; Macro de diffusion d'erreur couleur
Macro KiteDither_DitherDiffuse(mul, div, offset)
  If currentPos + offset >= 0 And currentPos + offset < totalPixels
    *dstPixel.Pixel32 = *baseAddr + (currentPos + offset) << 2
    getrgb(*dstPixel\l, r, g, b)
    r + (errR * mul) / div
    g + (errG * mul) / div
    b + (errB * mul) / div
    clamp_RGB(r, g, b)
    *dstPixel\l = alphaValue | (r << 16) | (g << 8) | b
  EndIf
EndMacro

; Macro de diffusion d'erreur niveaux de gris
Macro KiteDither_DitherDiffuseGray(mul, div, offset)
  If currentPos + offset >= 0 And currentPos + offset < totalPixels
    *dstPixel.Pixel32 = *baseAddr + (currentPos + offset) << 2
    getargb(*dstPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * mul) / div
    clamp(g, 0, 255)
    *dstPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

Procedure KiteDither_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected totalPixels = lg * ht
    Protected x, y, i, currentPos
    Protected oldR, oldG, oldB, newR, newG, newB
    Protected errR, errG, errB, a, r, g, b, g_lum
    Protected alphaValue, *dstPixel.Pixel32
    Protected levels = \option[0]
    Protected gray = \option[1]
    
    clamp(levels, 2, 64)
    
    Protected *ndc = AllocateMemory(256)
    If Not *ndc : ProcedureReturn : EndIf
    
    Protected Steping.f = 255.0 / (levels - 1)
    Protected reciprocal.f = 1.0 / Steping
    
    For i = 0 To 255
      Protected var = Round(i * reciprocal, #PB_Round_Nearest) * Steping
      clamp(var, 0, 255)
      PokeA(*ndc + i, var)
    Next
    
    macro_calul_tread((ht))
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    
    ; Sécurité pour la diffusion 2x2 (ne pas déborder sur la dernière ligne/colonne)
    If endPos >= ht - 1 : endPos = ht - 2 : EndIf
    
    Protected *baseAddr = \addr[1]
    
    ; Kite: diffusion minimale
    ;   X   1
    ;   1       (diviseur: 2)
    
    For y = startPos To endPos
      For x = 0 To lg - 2
        currentPos = y * lg + x
        *dstPixel = *baseAddr + currentPos << 2
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
          
          KiteDither_DitherDiffuse(1, 2, 1)    ; Droite
          KiteDither_DitherDiffuse(1, 2, lg)   ; Bas
        Else
          g_lum = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          newG = PeekA(*ndc + g_lum)
          errG = g_lum - newG
          *dstPixel\l = alphaValue | newG * $10101
          
          KiteDither_DitherDiffuseGray(1, 2, 1)
          KiteDither_DitherDiffuseGray(1, 2, lg)
        EndIf
      Next
    Next
    
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure KiteDitherEx(*FilterCtx.FilterParams)
  Restore KiteDither_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@KiteDither_MT())
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure KiteDither(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  KiteDitherEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  KiteDither_data:
  Data.s "KiteDither"
  Data.s "Kite dithering (Minimal 2x2, très rapide)"
  Data.i #FilterType_Dithering
  Data.i #Dither_Hybrid
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 113
; FirstLine = 85
; Folding = -
; EnableXP
; DPIAware