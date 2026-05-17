; ------------------------------------------------------------------------------
; RANDOM DITHER (bruit aléatoire)
; ------------------------------------------------------------------------------

Procedure RandomDither_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, currentPos
    Protected oldR, oldG, oldB, newR, newG, newB
    Protected a, r, g, b, alphaValue
    Protected *dstPixel.Pixel32
    Protected levels = \option[0]
    Protected gray = \option[1]
    Protected intensity = \option[2]
    
    clamp(levels, 2, 64)
    clamp(intensity, 1, 100)
    
    Protected Steping.f = 255.0 / (levels - 1)
    Protected noiseRange.f = (intensity / 100.0) * Steping
    
    macro_calul_tread((ht))
    
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    
    ; Initialisation du générateur aléatoire avec seed basé sur thread
    RandomSeed(\thread_pos * 12345)
    
    For y = startPos To endPos
      For x = 0 To lg - 1
        currentPos = y * lg + x
        *dstPixel = \addr[1] + currentPos << 2
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
          g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          newG = Round((g + noise) / Steping, #PB_Round_Nearest) * Steping
          clamp(newG, 0, 255)
          *dstPixel\l = alphaValue | newG * $10101
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure RandomDitherEx(*FilterCtx.FilterParams)
  Restore RandomDither_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Parallélisable
    Create_MultiThread_MT(@RandomDither_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure RandomDither(source, cible, mask, levels, gray, intensity)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
    \option[2] = intensity
  EndWith
  RandomDitherEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RandomDither_data:
  Data.s "RandomDither"
  Data.s "Random noise dithering"
  Data.i #FilterType_Dithering
  Data.i #Dither_Random
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "Intensité"
  Data.i 1, 100, 50
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 28
; FirstLine = 12
; Folding = -
; EnableXP
; DPIAware