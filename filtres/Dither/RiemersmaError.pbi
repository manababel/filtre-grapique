; ------------------------------------------------------------------------------
; RIEMERSMA ERROR DITHERING
; ------------------------------------------------------------------------------
; Dithering Riemersma avec parcours linéaire standard
; Utilise un buffer circulaire pour la diffusion d'erreur

Procedure RiemersmaError_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, i
    Protected oldR, oldG, oldB, newR, newG, newB
    Protected errR, errG, errB, a, r, g, b
    Protected alphaValue, *currentPixel.Pixel32
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
    
    ; Buffer circulaire pour l'erreur (Riemersma)
    Protected bufferSize = 16
    Protected Dim errBufferR(bufferSize - 1)
    Protected Dim errBufferG(bufferSize - 1)
    Protected Dim errBufferB(bufferSize - 1)
    Protected bufferPos = 0
    
    ; Poids de diffusion pour le buffer circulaire
    Protected Dim weights.f(bufferSize - 1)
    Protected totalWeight.f = 0.0
    
    For i = 0 To bufferSize - 1
      weights(i) = 1.0 / (i + 1.0)  ; Décroissance exponentielle
      totalWeight + weights(i)
    Next
    
    ; Normaliser les poids
    For i = 0 To bufferSize - 1
      weights(i) / totalWeight
    Next
    
    macro_calul_tread((ht))
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    Protected *baseAddr = \addr[1]

    ; Parcourir l'image de manière linéaire
    For y = startPos To endPos
      For x = 0 To lg - 1
        *currentPixel = *baseAddr + (y * lg + x) << 2
        
        getargb(*currentPixel\l, a, oldR, oldG, oldB)
        alphaValue = a << 24
        
        If Not gray
          ; Mode couleur - Application de l'erreur accumulée
          r = oldR : g = oldG : b = oldB
          
          For i = 0 To bufferSize - 1
            r + errBufferR(i) * weights(i)
            g + errBufferG(i) * weights(i)
            b + errBufferB(i) * weights(i)
          Next
          
          clamp_RGB(r, g, b)
          
          newR = PeekA(*ndc + r)
          newG = PeekA(*ndc + g)
          newB = PeekA(*ndc + b)
          
          errR = r - newR
          errG = g - newG
          errB = b - newB
          
          *currentPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
          
          ; Mise à jour du buffer circulaire
          errBufferR(bufferPos) = errR
          errBufferG(bufferPos) = errG
          errBufferB(bufferPos) = errB
          
        Else
          ; Mode niveaux de gris
          g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          
          For i = 0 To bufferSize - 1
            g + errBufferG(i) * weights(i)
          Next
          
          clamp(g, 0, 255)
          
          newG = PeekA(*ndc + g)
          errG = g - newG
          
          *currentPixel\l = alphaValue | newG * $10101
          errBufferG(bufferPos) = errG
        EndIf
        
        bufferPos = (bufferPos + 1) % bufferSize
      Next
    Next
    
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure RiemersmaErrorEx(*FilterCtx.FilterParams)
  Restore RiemersmaError_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@RiemersmaError_MT())
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure RiemersmaError(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  RiemersmaErrorEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RiemersmaError_data:
  Data.s "RiemersmaError"
  Data.s "Riemersma error diffusion with circular buffer (Linear path)"
  Data.i #FilterType_Dithering
  Data.i #Dither_Hybrid
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 130
; FirstLine = 102
; Folding = -
; EnableXP
; DPIAware