; ------------------------------------------------------------------------------
; SIERRA TWO-ROW DITHER
; ------------------------------------------------------------------------------
; Matrice de diffusion Sierra Two-Row (16 parts total)
; Diffusion sur 2 lignes avec 5 pixels
;
;       X  4  3
;   1  2  3  2  1

; Macro de diffusion d'erreur couleur
Macro SierraTwoRow_DitherDiffuse(mul, div, offsetX, offsetY)
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
Macro SierraTwoRow_DitherDiffuseGray(mul, div, offsetX, offsetY)
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

Procedure SierraTwoRow_MT(*param.parametre)
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
  
  ; Matrice Sierra Two-Row (diviseur: 16)
  ;       X  4  3
  ;   1  2  3  2  1
  
  For y = startPos To endPos
    For x = 0 To lg - 1
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
        
        ; Diffusion selon la matrice Sierra Two-Row
        ; Ligne courante (y+0)
        SierraTwoRow_DitherDiffuse(4, 16, 1, 0)   ; X+1, Y+0 : 4/16
        SierraTwoRow_DitherDiffuse(3, 16, 2, 0)   ; X+2, Y+0 : 3/16
        
        ; Ligne suivante (y+1)
        SierraTwoRow_DitherDiffuse(1, 16, -2, 1)  ; X-2, Y+1 : 1/16
        SierraTwoRow_DitherDiffuse(2, 16, -1, 1)  ; X-1, Y+1 : 2/16
        SierraTwoRow_DitherDiffuse(3, 16, 0, 1)   ; X+0, Y+1 : 3/16
        SierraTwoRow_DitherDiffuse(2, 16, 1, 1)   ; X+1, Y+1 : 2/16
        SierraTwoRow_DitherDiffuse(1, 16, 2, 1)   ; X+2, Y+1 : 1/16
        
      Else
        ; Mode niveaux de gris
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *currentPixel\l = alphaValue | newG * $10101
        
        ; Diffusion selon la matrice Sierra Two-Row
        ; Ligne courante (y+0)
        SierraTwoRow_DitherDiffuseGray(4, 16, 1, 0)
        SierraTwoRow_DitherDiffuseGray(3, 16, 2, 0)
        
        ; Ligne suivante (y+1)
        SierraTwoRow_DitherDiffuseGray(1, 16, -2, 1)
        SierraTwoRow_DitherDiffuseGray(2, 16, -1, 1)
        SierraTwoRow_DitherDiffuseGray(3, 16, 0, 1)
        SierraTwoRow_DitherDiffuseGray(2, 16, 1, 1)
        SierraTwoRow_DitherDiffuseGray(1, 16, 2, 1)
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure SierraTwoRow(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "Sierra Two-Row"
    *param\remarque = "Sierra Two-Row error diffusion dithering"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    
    ProcedureReturn
  EndIf
  filter_start(@SierraTwoRow_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 131
; FirstLine = 75
; Folding = -
; EnableXP
; DPIAware