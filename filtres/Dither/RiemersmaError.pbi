; ------------------------------------------------------------------------------
; RIEMERSMA ERROR DITHERING
; ------------------------------------------------------------------------------
; Dithering Riemersma avec parcours linéaire standard (sans courbe de Hilbert)
; Utilise un buffer circulaire pour la diffusion d'erreur

Procedure RiemersmaError_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected errR, errG, errB, a, r, g, b
  Protected alphaValue, *currentPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  Protected var.i
  
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
  
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  
  ; Parcourir l'image de manière linéaire (gauche à droite, haut en bas)
  For y = startPos To endPos
    For x = 0 To lg - 1
      *currentPixel = *param\addr[1] + (y * lg + x) << 2
      
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
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure RiemersmaError(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_Hybrid
    *param\name = "Riemersma Error"
    *param\remarque = "Riemersma error diffusion with circular buffer"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    
    ProcedureReturn
  EndIf
  
  filter_start(@RiemersmaError_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 126
; FirstLine = 71
; Folding = -
; EnableXP
; DPIAware