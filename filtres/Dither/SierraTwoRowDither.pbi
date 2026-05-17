; ------------------------------------------------------------------------------
; SIERRA TWO-ROW DITHER
; ------------------------------------------------------------------------------
; Matrice de diffusion Sierra Two-Row (16 parts total)
; Diffusion sur 2 lignes avec 5 pixels
;
;        X  4  3
;    1  2  3  2  1

; Macro de diffusion d'erreur couleur
Macro SierraTwoRow_DitherDiffuse(mul, div, offsetX, offsetY)
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
Macro SierraTwoRow_DitherDiffuseGray(mul, div, offsetX, offsetY)
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

Procedure SierraTwoRow_MT(*FilterCtx.FilterParams)
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
    
    ; Matrice Sierra Two-Row (diviseur: 16)
    ;        X  4  3
    ;    1  2  3  2  1
    
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
          
          ; Diffusion selon la matrice Sierra Two-Row
          SierraTwoRow_DitherDiffuse(4, 16, 1, 0)
          SierraTwoRow_DitherDiffuse(3, 16, 2, 0)
          
          SierraTwoRow_DitherDiffuse(1, 16, -2, 1)
          SierraTwoRow_DitherDiffuse(2, 16, -1, 1)
          SierraTwoRow_DitherDiffuse(3, 16, 0, 1)
          SierraTwoRow_DitherDiffuse(2, 16, 1, 1)
          SierraTwoRow_DitherDiffuse(1, 16, 2, 1)
          
        Else
          ; Mode niveaux de gris
          g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          newG = PeekA(*ndc + g)
          errG = g - newG
          *currentPixel\l = alphaValue | newG * $10101
          
          SierraTwoRow_DitherDiffuseGray(4, 16, 1, 0)
          SierraTwoRow_DitherDiffuseGray(3, 16, 2, 0)
          
          SierraTwoRow_DitherDiffuseGray(1, 16, -2, 1)
          SierraTwoRow_DitherDiffuseGray(2, 16, -1, 1)
          SierraTwoRow_DitherDiffuseGray(3, 16, 0, 1)
          SierraTwoRow_DitherDiffuseGray(2, 16, 1, 1)
          SierraTwoRow_DitherDiffuseGray(1, 16, 2, 1)
        EndIf
      Next
    Next
    
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure SierraTwoRowEx(*FilterCtx.FilterParams)
  Restore SierraTwoRow_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lancement du filtre (1 thread car Sierra nécessite un ordre séquentiel)
    Create_MultiThread_MT(@SierraTwoRow_MT(), 1)
    
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure SierraTwoRow(source, cible, mask, levels, gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  SierraTwoRowEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  SierraTwoRow_data:
  Data.s "SierraTwoRow"
  Data.s "Sierra Two-Row error diffusion dithering"
  Data.i #FilterType_Dithering
  Data.i #Dither_ErrorDiffusion
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 140
; FirstLine = 112
; Folding = -
; EnableXP
; DPIAware