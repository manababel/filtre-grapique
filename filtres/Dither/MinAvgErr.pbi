; ------------------------------------------------------------------------------
; MINIMUM AVERAGE ERROR DITHER (MinAvgErr)
; ------------------------------------------------------------------------------

; Macro de diffusion d'erreur couleur
Macro MinAvgErr_DitherDiffuse(mul, div, offsetX, offsetY)
  nextY = y + offsetY
  nextX = x + offsetX
  If nextY >= 0 And nextY < ht And nextX >= 0 And nextX < lg
    *dstPixel.Pixel32 = *FilterCtx\addr[1] + (nextY * lg + nextX) << 2
    getrgb(*dstPixel\l, r, g, b)
    r + (errR * mul) / div
    g + (errG * mul) / div
    b + (errB * mul) / div
    clamp_RGB(r, g, b)
    *dstPixel\l = alphaValue | (r << 16) | (g << 8) | b
  EndIf
EndMacro

; Macro de diffusion d'erreur niveaux de gris
Macro MinAvgErr_DitherDiffuseGray(mul, div, offsetX, offsetY)
  nextY = y + offsetY
  nextX = x + offsetX
  If nextY >= 0 And nextY < ht And nextX >= 0 And nextX < lg
    *dstPixel.Pixel32 = *FilterCtx\addr[1] + (nextY * lg + nextX) << 2
    getargb(*dstPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * mul) / div
    clamp(g, 0, 255)
    *dstPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

Procedure MinAvgErr_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, i
    Protected oldR, oldG, oldB, newR, newG, newB
    Protected errR, errG, errB, a, r, g, b
    Protected alphaValue, *dstPixel.Pixel32, *currentPixel.Pixel32
    Protected levels = \option[0]
    Protected gray = \option[1]
    Protected var.i
    Protected nextX, nextY
    Protected serpentine = 1 
    
    clamp(levels, 2, 64)
    
    Protected *ndc = AllocateMemory(256)
    If Not *ndc : ProcedureReturn : EndIf
    
    Protected Steping.f = 255.0 / (levels - 1)
    Protected reciprocal.f = 1.0 / Steping
    
    For i = 0 To 255
      var = Round(i * reciprocal, #PB_Round_Nearest)
      var = var * Steping
      clamp(var, 0, 255)
      PokeA(*ndc + i, var)
    Next
    
    macro_calul_tread((ht))
    
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    
    For y = startPos To endPos
      Protected direction = 1
      Protected xStart = 0
      Protected xEnd = lg - 1
      Protected xStep = 1
      
      If serpentine And (y & 1)
        direction = -1
        xStart = lg - 1
        xEnd = 0
        xStep = -1
      EndIf
      
      x = xStart
      While (direction > 0 And x <= xEnd) Or (direction < 0 And x >= xEnd)
        *currentPixel = \addr[1] + (y * lg + x) << 2
        
        getargb(*currentPixel\l, a, oldR, oldG, oldB)
        alphaValue = a << 24
        
        If Not gray
          newR = PeekA(*ndc + oldR)
          newG = PeekA(*ndc + oldG)
          newB = PeekA(*ndc + oldB)
          errR = oldR - newR
          errG = oldG - newG
          errB = oldB - newB
          *currentPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
          
          If direction > 0
            MinAvgErr_DitherDiffuse(7, 48, 1, 0)
            MinAvgErr_DitherDiffuse(5, 48, 2, 0)
            MinAvgErr_DitherDiffuse(3, 48, -2, 1)
            MinAvgErr_DitherDiffuse(5, 48, -1, 1)
            MinAvgErr_DitherDiffuse(7, 48, 0, 1)
            MinAvgErr_DitherDiffuse(5, 48, 1, 1)
            MinAvgErr_DitherDiffuse(3, 48, 2, 1)
          Else
            MinAvgErr_DitherDiffuse(7, 48, -1, 0)
            MinAvgErr_DitherDiffuse(5, 48, -2, 0)
            MinAvgErr_DitherDiffuse(3, 48, -2, 1)
            MinAvgErr_DitherDiffuse(5, 48, -1, 1)
            MinAvgErr_DitherDiffuse(7, 48, 0, 1)
            MinAvgErr_DitherDiffuse(5, 48, 1, 1)
            MinAvgErr_DitherDiffuse(3, 48, 2, 1)
          EndIf
          
        Else
          g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          newG = PeekA(*ndc + g)
          errG = g - newG
          *currentPixel\l = alphaValue | newG * $10101
          
          If direction > 0
            MinAvgErr_DitherDiffuseGray(7, 48, 1, 0)
            MinAvgErr_DitherDiffuseGray(5, 48, 2, 0)
            MinAvgErr_DitherDiffuseGray(3, 48, -2, 1)
            MinAvgErr_DitherDiffuseGray(5, 48, -1, 1)
            MinAvgErr_DitherDiffuseGray(7, 48, 0, 1)
            MinAvgErr_DitherDiffuseGray(5, 48, 1, 1)
            MinAvgErr_DitherDiffuseGray(3, 48, 2, 1)
          Else
            MinAvgErr_DitherDiffuseGray(7, 48, -1, 0)
            MinAvgErr_DitherDiffuseGray(5, 48, -2, 0)
            MinAvgErr_DitherDiffuseGray(3, 48, -2, 1)
            MinAvgErr_DitherDiffuseGray(5, 48, -1, 1)
            MinAvgErr_DitherDiffuseGray(7, 48, 0, 1)
            MinAvgErr_DitherDiffuseGray(5, 48, 1, 1)
            MinAvgErr_DitherDiffuseGray(3, 48, 2, 1)
          EndIf
        EndIf
        
        x + xStep
      Wend
    Next
    
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure MinAvgErrEx(*FilterCtx.FilterParams)
  Restore MinAvgErr_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@MinAvgErr_MT(), 1)
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure MinAvgErr(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  MinAvgErrEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  MinAvgErr_data:
  Data.s "MinAvgErr"
  Data.s "Minimum Average Error dithering (serpentine)"
  Data.i #FilterType_Dithering
  Data.i #Dither_ErrorDiffusion
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 158
; FirstLine = 130
; Folding = -
; EnableXP
; DPIAware