; ------------------------------------------------------------------------------
; STEVENSON-ARCE DITHER
; ------------------------------------------------------------------------------
; Matrice de diffusion Stevenson-Arce (200 parts total)
; Diffusion sur 12 pixels voisins avec distribution optimisée
;
;         X  32  12
;      5  12  26  12   5
;         12  12   5

; Macro de diffusion d'erreur couleur
Macro StevensonArce_DitherDiffuse(mul, div, offsetX, offsetY)
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
Macro StevensonArce_DitherDiffuseGray(mul, div, offsetX, offsetY)
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

Procedure StevensonArceDither_MT(*FilterCtx.FilterParams)
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
    
    macro_calul_tread((ht))
    
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    
    ; Matrice Stevenson-Arce (diviseur: 200)
    ;         X  32  12
    ;      5  12  26  12   5
    ;         12  12   5
    
    For y = startPos To endPos
      For x = 0 To lg - 1
        *currentPixel = \addr[1] + (y * lg + x) << 2
        
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
          StevensonArce_DitherDiffuse(32, 200, 1, 0)
          StevensonArce_DitherDiffuse(12, 200, 2, 0)
          
          StevensonArce_DitherDiffuse(5,  200, -2, 1)
          StevensonArce_DitherDiffuse(12, 200, -1, 1)
          StevensonArce_DitherDiffuse(26, 200, 0, 1)
          StevensonArce_DitherDiffuse(12, 200, 1, 1)
          StevensonArce_DitherDiffuse(5,  200, 2, 1)
          
          StevensonArce_DitherDiffuse(12, 200, -1, 2)
          StevensonArce_DitherDiffuse(12, 200, 0, 2)
          StevensonArce_DitherDiffuse(5,  200, 1, 2)
          
        Else
          ; Mode niveaux de gris
          g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          newG = PeekA(*ndc + g)
          errG = g - newG
          *currentPixel\l = alphaValue | newG * $10101
          
          StevensonArce_DitherDiffuseGray(32, 200, 1, 0)
          StevensonArce_DitherDiffuseGray(12, 200, 2, 0)
          
          StevensonArce_DitherDiffuseGray(5,  200, -2, 1)
          StevensonArce_DitherDiffuseGray(12, 200, -1, 1)
          StevensonArce_DitherDiffuseGray(26, 200, 0, 1)
          StevensonArce_DitherDiffuseGray(12, 200, 1, 1)
          StevensonArce_DitherDiffuseGray(5,  200, 2, 1)
          
          StevensonArce_DitherDiffuseGray(12, 200, -1, 2)
          StevensonArce_DitherDiffuseGray(12, 200, 0, 2)
          StevensonArce_DitherDiffuseGray(5,  200, 1, 2)
        EndIf
      Next
    Next
    
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure StevensonArceEx(*FilterCtx.FilterParams)
  Restore StevensonArce_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lancement du filtre (1 thread car la diffusion d'erreur est séquentielle)
    Create_MultiThread_MT(@StevensonArceDither_MT(), 1)
    
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure StevensonArce(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  StevensonArceEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  StevensonArce_data:
  Data.s "StevensonArce"
  Data.s "Stevenson-Arce error diffusion dithering"
  Data.i #FilterType_Dithering
  Data.i #Dither_ErrorDiffusion
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 150
; FirstLine = 122
; Folding = -
; EnableXP
; DPIAware