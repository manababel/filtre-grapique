; ------------------------------------------------------------------------------
; RIEMERSMA-HILBERT DITHERING
; ------------------------------------------------------------------------------
; Dithering basé sur la courbe de Hilbert avec diffusion d'erreur
; Parcourt l'image selon une courbe de remplissage d'espace pour meilleure cohérence

; Génération de la courbe de Hilbert
Procedure.i HilbertXY(n, d, *x.Integer, *y.Integer)
  Protected rx, ry, s, t
  *x\i = 0
  *y\i = 0
  
  s = 1
  While s < n
    rx = 1 & (d >> 1)
    ry = Pow(d, rx)
    ry = ry & 1
    
    ; Rotation
    If ry = 0
      If rx = 1
        *x\i = s - 1 - *x\i
        *y\i = s - 1 - *y\i
      EndIf
      t = *x\i
      *x\i = *y\i
      *y\i = t
    EndIf
    
    *x\i + s * rx
    *y\i + s * ry
    d >> 2
    s << 1
  Wend
EndProcedure

Procedure RiemersmaHilbert_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, i, d, hx, hy
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected errR, errG, errB, a, r, g, b
  Protected alphaValue, *currentPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
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
    var = Round(i * reciprocal, #PB_Round_Nearest)
    var = var * Steping
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
  
  Protected startPos = (*param\thread_pos * totalPoints) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * totalPoints) / *param\thread_max - 1
  
  ; Parcourir l'image selon la courbe de Hilbert
  For d = startPos To endPos
    HilbertXY(hilbertSize, d, @hx, @hy)
    
    ; Vérifier si le point est dans l'image
    If hx >= lg Or hy >= ht
      Continue
    EndIf
    
    *currentPixel = *param\addr[1] + (hy * lg + hx) << 2
    
    getargb(*currentPixel\l, a, oldR, oldG, oldB)
    alphaValue = a << 24
    
    If Not gray
      ; Mode couleur
      ; Appliquer l'erreur accumulée du buffer
      r = oldR
      g = oldG
      b = oldB
      
      For i = 0 To bufferSize - 1
        r + errBufferR(i) * weights(i)
        g + errBufferG(i) * weights(i)
        b + errBufferB(i) * weights(i)
      Next
      
      clamp(r, 0, 255)
      clamp(g, 0, 255)
      clamp(b, 0, 255)
      
      newR = PeekA(*ndc + r)
      newG = PeekA(*ndc + g)
      newB = PeekA(*ndc + b)
      
      errR = r - newR
      errG = g - newG
      errB = b - newB
      
      *currentPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
      
      ; Ajouter l'erreur au buffer circulaire
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
    
    ; Avancer dans le buffer circulaire
    bufferPos = (bufferPos + 1) % bufferSize
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure RiemersmaHilbert(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_Hybrid
    *param\name = "Riemersma-Hilbert"
    *param\remarque = "Riemersma dithering with Hilbert curve"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    
    ProcedureReturn
  EndIf
  
  filter_start(@RiemersmaHilbert_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 169
; FirstLine = 123
; Folding = -
; EnableXP
; DPIAware