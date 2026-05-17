; ------------------------------------------------------------------------------
; LITE DITHER (variante ultra-rapide 1 pixel) - VERSION OPTIMISÉE
; ------------------------------------------------------------------------------

; Macro de diffusion d'erreur couleur (optimisée)
Macro LiteDither_DitherDiffuse(mul, div)
  *dstPixel.Pixel32 = *nextPixel
  getrgb(*dstPixel\l, r, g, b)
  r + (errR * mul) / div
  g + (errG * mul) / div
  b + (errB * mul) / div
  clamp_RGB(r, g, b)
  *dstPixel\l = alphaValue | (r << 16) | (g << 8) | b
EndMacro

; Macro de diffusion d'erreur niveaux de gris (optimisée)
Macro LiteDither_DitherDiffuseGray(mul, div)
  *dstPixel.Pixel32 = *nextPixel
  getargb(*dstPixel\l, a, r, g, b)
  g = (r * 77 + g * 150 + b * 29) >> 8
  g + (errG * mul) / div
  clamp(g, 0, 255)
  *dstPixel\l = (a << 24) | g * $10101
EndMacro

Procedure LiteDither_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, i
    Protected oldR, oldG, oldB, newR, newG, newB
    Protected errR, errG, errB, a, r, g, b, g_lum
    Protected alphaValue, *dstPixel.Pixel32, *nextPixel.Pixel32
    Protected levels = \option[0]
    Protected gray = \option[1]
    Protected var.i
    
    clamp(levels, 2, 64)
    
    ; Table de quantification (LUT)
    Protected *ndc = AllocateMemory(256)
    If Not *ndc : ProcedureReturn : EndIf
    
    Protected Steping.f = 255.0 / (levels - 1)
    Protected reciprocal.f = 1.0 / Steping
    
    For i = 0 To 255
      var = Round(i * reciprocal, #PB_Round_Nearest) * Steping
      clamp(var, 0, 255)
      PokeA(*ndc + i, var)
    Next
    
    macro_calul_tread((ht))
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    Protected *baseAddr = \addr[1]

    ; Lite: diffusion vers un seul pixel (droite uniquement)
    For y = startPos To endPos
      For x = 0 To lg - 2
        *dstPixel = *baseAddr + (y * lg + x) << 2
        *nextPixel = *dstPixel + 4 
        
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
          
          LiteDither_DitherDiffuse(1, 1)
        Else
          g_lum = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          newG = PeekA(*ndc + g_lum)
          errG = g_lum - newG
          *dstPixel\l = alphaValue | newG * $10101
          
          LiteDither_DitherDiffuseGray(1, 1)
        EndIf
      Next
      
      ; Traiter le dernier pixel de la ligne (sans diffusion possible)
      *dstPixel = *baseAddr + (y * lg + lg - 1) << 2
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      alphaValue = a << 24
      
      If Not gray
        newR = PeekA(*ndc + oldR) : newG = PeekA(*ndc + oldG) : newB = PeekA(*ndc + oldB)
        *dstPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
      Else
        g_lum = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g_lum)
        *dstPixel\l = alphaValue | newG * $10101
      EndIf
    Next
    
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure LiteDitherEx(*FilterCtx.FilterParams)
  Restore LiteDither_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@LiteDither_MT())
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure LiteDither(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  LiteDitherEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  LiteDither_data:
  Data.s "LiteDither"
  Data.s "Lite dithering (Diffusion 1D vers la droite, ultra-rapide)"
  Data.i #FilterType_Dithering
  Data.i #Dither_Fast
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 116
; FirstLine = 88
; Folding = -
; EnableXP
; DPIAware