; ------------------------------------------------------------------------------
; RIEMERSMA-HILBERT DITHERING
; ------------------------------------------------------------------------------
; Dithering basé sur la courbe de Hilbert avec diffusion d'erreur
; Parcourt l'image selon une courbe de remplissage d'espace pour meilleure cohérence

; Génération de la courbe de Hilbert
Procedure.i HilbertXY(n, d, *x.Integer, *y.Integer)
  Protected rx, ry, s, t
  *x\i = 0 : *y\i = 0
  
  s = 1
  While s < n
    rx = 1 & (d >> 1)
    ry = 1 & (d ! rx)
    
    ; Rotation
    If ry = 0
      If rx = 1
        *x\i = s - 1 - *x\i
        *y\i = s - 1 - *y\i
      EndIf
      t = *x\i : *x\i = *y\i : *y\i = t
    EndIf
    
    *x\i + s * rx
    *y\i + s * ry
    d >> 2
    s << 1
  Wend
EndProcedure

Procedure RiemersmaHilbert_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, i, d, hx, hy
    Protected oldR, oldG, oldB, newR, newG, newB
    Protected errR, errG, errB, a, r, g, b
    Protected alphaValue, *currentPixel.Pixel32
    Protected levels = \option[0]
    Protected gray = \option[1]
    Protected var.i
    
    ; Taille de la courbe de Hilbert (puissance de 2)
    Protected hilbertSize = 1
    While hilbertSize < lg Or hilbertSize < ht
      hilbertSize << 1
    Wend
    
    Protected totalPoints = hilbertSize * hilbertSize
    
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
      weights(i) = 1.0 / (i + 1.0) ; Décroissance
      totalWeight + weights(i)
    Next
    
    ; Normaliser les poids
    For i = 0 To bufferSize - 1 : weights(i) / totalWeight : Next
    
    ; Utilisation de la macro de calcul de thread sur les points de la courbe
    macro_calul_tread((totalPoints))
    
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    
    ; Parcourir la portion de la courbe assignée au thread
    For d = startPos To endPos
      HilbertXY(hilbertSize, d, @hx, @hy)
      
      ; Vérifier si le point est dans l'image
      If hx >= lg Or hy >= ht : Continue : EndIf
      
      *currentPixel = \addr[1] + (hy * lg + hx) << 2
      getargb(*currentPixel\l, a, oldR, oldG, oldB)
      alphaValue = a << 24
      
      If Not gray
        r = oldR : g = oldG : b = oldB
        For i = 0 To bufferSize - 1
          r + errBufferR(i) * weights(i)
          g + errBufferG(i) * weights(i)
          b + errBufferB(i) * weights(i)
        Next
        clamp_RGB(r, g, b)
        newR = PeekA(*ndc + r) : newG = PeekA(*ndc + g) : newB = PeekA(*ndc + b)
        errR = r - newR : errG = g - newG : errB = b - newB
        *currentPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
        errBufferR(bufferPos) = errR : errBufferG(bufferPos) = errG : errBufferB(bufferPos) = errB
      Else
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        For i = 0 To bufferSize - 1 : g + errBufferG(i) * weights(i) : Next
        clamp(g, 0, 255)
        newG = PeekA(*ndc + g) : errG = g - newG
        *currentPixel\l = alphaValue | newG * $10101
        errBufferG(bufferPos) = errG
      EndIf
      
      bufferPos = (bufferPos + 1) % bufferSize
    Next
    
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure RiemersmaHilbertEx(*FilterCtx.FilterParams)
  Restore RiemersmaHilbert_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@RiemersmaHilbert_MT())
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure RiemersmaHilbert(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  RiemersmaHilbertEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RiemersmaHilbert_data:
  Data.s "RiemersmaHilbert"
  Data.s "Riemersma dithering with Hilbert curve space-filling"
  Data.i #FilterType_Dithering
  Data.i #Dither_Hybrid
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 142
; FirstLine = 114
; Folding = -
; EnableXP
; DPIAware