; ------------------------------------------------------------------------------
; STEVENSON-ARCE DITHER
; ------------------------------------------------------------------------------
; Matrice de diffusion Stevenson-Arce (200 parts total)
; Diffusion sur 12 pixels voisins avec distribution optimisée
;
;         X  32  12
;     5  12  26  12   5
;        12  12   5

; Macro de diffusion d'erreur couleur
Macro StevensonArce_DitherDiffuse(mul, div, offsetX, offsetY)
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
Macro StevensonArce_DitherDiffuseGray(mul, div, offsetX, offsetY)
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

Procedure StevensonArceDither_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected errR, errG, errB, a, r, g, b
  Protected alphaValue, *dstPixel.Pixel32, *currentPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  Protected var.i
  Protected nextX ,  nextY
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
  
  ; Matrice Stevenson-Arce (diviseur: 200)
  ;         X  32  12
  ;     5  12  26  12   5
  ;        12  12   5
  
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
        
        ; Diffusion selon la matrice Stevenson-Arce
        ; Ligne courante (y+0)
        StevensonArce_DitherDiffuse(32, 200, 1, 0)   ; X+1, Y+0 : 32/200
        StevensonArce_DitherDiffuse(12, 200, 2, 0)   ; X+2, Y+0 : 12/200
        
        ; Ligne suivante (y+1)
        StevensonArce_DitherDiffuse(5,  200, -2, 1)  ; X-2, Y+1 : 5/200
        StevensonArce_DitherDiffuse(12, 200, -1, 1)  ; X-1, Y+1 : 12/200
        StevensonArce_DitherDiffuse(26, 200, 0, 1)   ; X+0, Y+1 : 26/200
        StevensonArce_DitherDiffuse(12, 200, 1, 1)   ; X+1, Y+1 : 12/200
        StevensonArce_DitherDiffuse(5,  200, 2, 1)   ; X+2, Y+1 : 5/200
        
        ; Ligne suivante (y+2)
        StevensonArce_DitherDiffuse(12, 200, -1, 2)  ; X-1, Y+2 : 12/200
        StevensonArce_DitherDiffuse(12, 200, 0, 2)   ; X+0, Y+2 : 12/200
        StevensonArce_DitherDiffuse(5,  200, 1, 2)   ; X+1, Y+2 : 5/200
        
      Else
        ; Mode niveaux de gris
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *currentPixel\l = alphaValue | newG * $10101
        
        ; Diffusion selon la matrice Stevenson-Arce
        ; Ligne courante (y+0)
        StevensonArce_DitherDiffuseGray(32, 200, 1, 0)
        StevensonArce_DitherDiffuseGray(12, 200, 2, 0)
        
        ; Ligne suivante (y+1)
        StevensonArce_DitherDiffuseGray(5,  200, -2, 1)
        StevensonArce_DitherDiffuseGray(12, 200, -1, 1)
        StevensonArce_DitherDiffuseGray(26, 200, 0, 1)
        StevensonArce_DitherDiffuseGray(12, 200, 1, 1)
        StevensonArce_DitherDiffuseGray(5,  200, 2, 1)
        
        ; Ligne suivante (y+2)
        StevensonArce_DitherDiffuseGray(12, 200, -1, 2)
        StevensonArce_DitherDiffuseGray(12, 200, 0, 2)
        StevensonArce_DitherDiffuseGray(5,  200, 1, 2)
      EndIf
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure StevensonArce(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "Stevenson-Arce"
    *param\remarque = "Stevenson-Arce error diffusion dithering"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    
    ProcedureReturn
  EndIf
  filter_start(@StevensonArceDither_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 142
; FirstLine = 95
; Folding = -
; EnableXP
; DPIAware