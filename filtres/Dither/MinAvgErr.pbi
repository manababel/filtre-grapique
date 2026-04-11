; ------------------------------------------------------------------------------
; MINIMUM AVERAGE ERROR DITHER (MinAvgErr)
; ------------------------------------------------------------------------------
; Matrice de diffusion MinAvgErr
; Diffusion serpentine (zigzag) pour minimiser l'erreur moyenne
;
; Direction gauche->droite:        Direction droite->gauche:
;       X  7  5                           5  7  X
;   3  5  7  5  3                     3  5  7  5  3

; Macro de diffusion d'erreur couleur
Macro MinAvgErr_DitherDiffuse(mul, div, offsetX, offsetY)
  nextY = y + offsetY
  nextX = x + offsetX
  If nextY >= 0 And nextY < ht And nextX >= 0 And nextX < lg
    *dstPixel.Pixel32 = *param\addr[1] + (nextY * lg + nextX) << 2
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
    *dstPixel.Pixel32 = *param\addr[1] + (nextY * lg + nextX) << 2
    getargb(*dstPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * mul) / div
    clamp(g, 0, 255)
    *dstPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

Procedure MinAvgErr_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected errR, errG, errB, a, r, g, b
  Protected alphaValue, *dstPixel.Pixel32, *currentPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  Protected var.i
  Protected nextX, nextY
  Protected serpentine = 1  ; Active le mode serpentine par défaut
  
  clamp(levels, 2, 64)
  
  ; Table de quantification (LUT)
  Protected *ndc = AllocateMemory(256)
  If Not *ndc : ProcedureReturn : EndIf
  
  Protected Steping.f = 255.0 / (levels - 1)
  Protected reciprocal.f = 1.0 / Steping
  
  ; Précalcul de la table de quantification
  For i = 0 To 255
    var = Round(i * reciprocal, #PB_Round_Nearest)
    var = var * Steping
    clamp(var, 0, 255)
    PokeA(*ndc + i, var)
  Next
  
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  
  ; Matrice MinAvgErr (diviseur: 48)
  ; Direction L->R:  X  7  5  / 3  5  7  5  3
  ; Direction R->L:  5  7  X  / 3  5  7  5  3
  
  For y = startPos To endPos
    ; Déterminer la direction selon le mode serpentine
    Protected direction = 1
    Protected xStart = 0
    Protected xEnd = lg - 1
    Protected xStep = 1
    
    If serpentine And (y & 1)  ; Ligne impaire en mode serpentine
      direction = -1
      xStart = lg - 1
      xEnd = 0
      xStep = -1
    EndIf
    
    x = xStart
    While (direction > 0 And x <= xEnd) Or (direction < 0 And x >= xEnd)
      *currentPixel = *param\addr[1] + (y * lg + x) << 2
      
      getargb(*currentPixel\l, a, oldR, oldG, oldB)
      alphaValue = a << 24
      
      If Not gray
        ; Mode couleur
        newR = PeekA(*ndc + oldR)
        newG = PeekA(*ndc + oldG)
        newB = PeekA(*ndc + oldB)
        errR = oldR - newR
        errG = oldG - newG
        errB = oldB - newB
        *currentPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
        
        ; Diffusion selon la matrice MinAvgErr et la direction
        If direction > 0  ; Gauche -> Droite
          ; Ligne courante
          MinAvgErr_DitherDiffuse(7, 48, 1, 0)   ; X+1, Y+0 : 7/48
          MinAvgErr_DitherDiffuse(5, 48, 2, 0)   ; X+2, Y+0 : 5/48
          
          ; Ligne suivante
          MinAvgErr_DitherDiffuse(3, 48, -2, 1)  ; X-2, Y+1 : 3/48
          MinAvgErr_DitherDiffuse(5, 48, -1, 1)  ; X-1, Y+1 : 5/48
          MinAvgErr_DitherDiffuse(7, 48, 0, 1)   ; X+0, Y+1 : 7/48
          MinAvgErr_DitherDiffuse(5, 48, 1, 1)   ; X+1, Y+1 : 5/48
          MinAvgErr_DitherDiffuse(3, 48, 2, 1)   ; X+2, Y+1 : 3/48
        Else  ; Droite -> Gauche
          ; Ligne courante
          MinAvgErr_DitherDiffuse(7, 48, -1, 0)  ; X-1, Y+0 : 7/48
          MinAvgErr_DitherDiffuse(5, 48, -2, 0)  ; X-2, Y+0 : 5/48
          
          ; Ligne suivante
          MinAvgErr_DitherDiffuse(3, 48, -2, 1)  ; X-2, Y+1 : 3/48
          MinAvgErr_DitherDiffuse(5, 48, -1, 1)  ; X-1, Y+1 : 5/48
          MinAvgErr_DitherDiffuse(7, 48, 0, 1)   ; X+0, Y+1 : 7/48
          MinAvgErr_DitherDiffuse(5, 48, 1, 1)   ; X+1, Y+1 : 5/48
          MinAvgErr_DitherDiffuse(3, 48, 2, 1)   ; X+2, Y+1 : 3/48
        EndIf
        
      Else
        ; Mode niveaux de gris
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *currentPixel\l = alphaValue | newG * $10101
        
        ; Diffusion selon la matrice MinAvgErr et la direction
        If direction > 0  ; Gauche -> Droite
          ; Ligne courante
          MinAvgErr_DitherDiffuseGray(7, 48, 1, 0)
          MinAvgErr_DitherDiffuseGray(5, 48, 2, 0)
          
          ; Ligne suivante
          MinAvgErr_DitherDiffuseGray(3, 48, -2, 1)
          MinAvgErr_DitherDiffuseGray(5, 48, -1, 1)
          MinAvgErr_DitherDiffuseGray(7, 48, 0, 1)
          MinAvgErr_DitherDiffuseGray(5, 48, 1, 1)
          MinAvgErr_DitherDiffuseGray(3, 48, 2, 1)
        Else  ; Droite -> Gauche
          ; Ligne courante
          MinAvgErr_DitherDiffuseGray(7, 48, -1, 0)
          MinAvgErr_DitherDiffuseGray(5, 48, -2, 0)
          
          ; Ligne suivante
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
EndProcedure

Procedure MinAvgErr(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "MinAvgErr"
    *param\remarque = "Minimum Average Error dithering (serpentine)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    
    ProcedureReturn
  EndIf
  filter_start(@MinAvgErr_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 175
; FirstLine = 119
; Folding = -
; EnableXP
; DPIAware