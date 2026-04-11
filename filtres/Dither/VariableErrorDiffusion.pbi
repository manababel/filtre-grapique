; ------------------------------------------------------------------------------
; VARIABLE ERROR DIFFUSION - Algorithmes multiples de diffusion d'erreur
; ------------------------------------------------------------------------------

; Macro de diffusion avec offset variable
Macro VarED_DiffuseColor(xOff, yOff, weight)
  If x + xOff >= 0 And x + xOff < lg And y + yOff >= 0 And y + yOff < ht
    *targetPixel.Pixel32 = *baseAddr + ((y + yOff) * lg + x + xOff) << 2
    getrgb(*targetPixel\l, r, g, b)
    r + (errR * weight) >> 4  ; Division par 16
    g + (errG * weight) >> 4
    b + (errB * weight) >> 4
    clamp_RGB(r, g, b)
    *targetPixel\l = alphaValue | (r << 16) | (g << 8) | b
  EndIf
EndMacro

Macro VarED_DiffuseGray(xOff, yOff, weight)
  If x + xOff >= 0 And x + xOff < lg And y + yOff >= 0 And y + yOff < ht
    *targetPixel.Pixel32 = *baseAddr + ((y + yOff) * lg + x + xOff) << 2
    getargb(*targetPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * weight) >> 4
    clamp(g, 0, 255)
    *targetPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

; Applique la diffusion Floyd-Steinberg
Procedure VarED_ApplyFloydSteinberg(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a
  Protected *targetPixel.Pixel32
  
  If Not gray
    ; Droite: 7/16
    VarED_DiffuseColor(1, 0, 7)
    ; Bas-gauche: 3/16
    VarED_DiffuseColor(-1, 1, 3)
    ; Bas: 5/16
    VarED_DiffuseColor(0, 1, 5)
    ; Bas-droite: 1/16
    VarED_DiffuseColor(1, 1, 1)
  Else
    VarED_DiffuseGray(1, 0, 7)
    VarED_DiffuseGray(-1, 1, 3)
    VarED_DiffuseGray(0, 1, 5)
    VarED_DiffuseGray(1, 1, 1)
  EndIf
EndProcedure

; Applique la diffusion Jarvis-Judice-Ninke
Procedure VarED_ApplyJarvisJudiceNinke(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a
  Protected *targetPixel.Pixel32
  
  ; Matrice JJN (divisée par 48):
  ;       X   7   5
  ; 3   5   7   5   3
  ; 1   3   5   3   1
  
  If Not gray
    ; Ligne actuelle
    VarED_DiffuseColor(1, 0, 7)
    VarED_DiffuseColor(2, 0, 5)
    
    ; Ligne suivante
    VarED_DiffuseColor(-2, 1, 3)
    VarED_DiffuseColor(-1, 1, 5)
    VarED_DiffuseColor(0, 1, 7)
    VarED_DiffuseColor(1, 1, 5)
    VarED_DiffuseColor(2, 1, 3)
    
    ; Ligne +2
    VarED_DiffuseColor(-2, 2, 1)
    VarED_DiffuseColor(-1, 2, 3)
    VarED_DiffuseColor(0, 2, 5)
    VarED_DiffuseColor(1, 2, 3)
    VarED_DiffuseColor(2, 2, 1)
  Else
    VarED_DiffuseGray(1, 0, 7)
    VarED_DiffuseGray(2, 0, 5)
    
    VarED_DiffuseGray(-2, 1, 3)
    VarED_DiffuseGray(-1, 1, 5)
    VarED_DiffuseGray(0, 1, 7)
    VarED_DiffuseGray(1, 1, 5)
    VarED_DiffuseGray(2, 1, 3)
    
    VarED_DiffuseGray(-2, 2, 1)
    VarED_DiffuseGray(-1, 2, 3)
    VarED_DiffuseGray(0, 2, 5)
    VarED_DiffuseGray(1, 2, 3)
    VarED_DiffuseGray(2, 2, 1)
  EndIf
EndProcedure

; Applique la diffusion Stucki
Procedure VarED_ApplyStucki(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a
  Protected *targetPixel.Pixel32
  
  ; Matrice Stucki (divisée par 42):
  ;       X   8   4
  ; 2   4   8   4   2
  ; 1   2   4   2   1
  
  If Not gray
    VarED_DiffuseColor(1, 0, 8)
    VarED_DiffuseColor(2, 0, 4)
    
    VarED_DiffuseColor(-2, 1, 2)
    VarED_DiffuseColor(-1, 1, 4)
    VarED_DiffuseColor(0, 1, 8)
    VarED_DiffuseColor(1, 1, 4)
    VarED_DiffuseColor(2, 1, 2)
    
    VarED_DiffuseColor(-2, 2, 1)
    VarED_DiffuseColor(-1, 2, 2)
    VarED_DiffuseColor(0, 2, 4)
    VarED_DiffuseColor(1, 2, 2)
    VarED_DiffuseColor(2, 2, 1)
  Else
    VarED_DiffuseGray(1, 0, 8)
    VarED_DiffuseGray(2, 0, 4)
    
    VarED_DiffuseGray(-2, 1, 2)
    VarED_DiffuseGray(-1, 1, 4)
    VarED_DiffuseGray(0, 1, 8)
    VarED_DiffuseGray(1, 1, 4)
    VarED_DiffuseGray(2, 1, 2)
    
    VarED_DiffuseGray(-2, 2, 1)
    VarED_DiffuseGray(-1, 2, 2)
    VarED_DiffuseGray(0, 2, 4)
    VarED_DiffuseGray(1, 2, 2)
    VarED_DiffuseGray(2, 2, 1)
  EndIf
EndProcedure

; Applique la diffusion Atkinson
Procedure VarED_ApplyAtkinson(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a
  Protected *targetPixel.Pixel32
  
  ; Matrice Atkinson (divisée par 8):
  ;     X   1   1
  ; 1   1   1
  ;     1
  
  If Not gray
    VarED_DiffuseColor(1, 0, 1)
    VarED_DiffuseColor(2, 0, 1)
    
    VarED_DiffuseColor(-1, 1, 1)
    VarED_DiffuseColor(0, 1, 1)
    VarED_DiffuseColor(1, 1, 1)
    
    VarED_DiffuseColor(0, 2, 1)
  Else
    VarED_DiffuseGray(1, 0, 1)
    VarED_DiffuseGray(2, 0, 1)
    
    VarED_DiffuseGray(-1, 1, 1)
    VarED_DiffuseGray(0, 1, 1)
    VarED_DiffuseGray(1, 1, 1)
    
    VarED_DiffuseGray(0, 2, 1)
  EndIf
EndProcedure

; Applique la diffusion Burkes
Procedure VarED_ApplyBurkes(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a
  Protected *targetPixel.Pixel32
  
  ; Matrice Burkes (divisée par 32):
  ;         X   8   4
  ; 2   4   8   4   2
  
  If Not gray
    VarED_DiffuseColor(1, 0, 8)
    VarED_DiffuseColor(2, 0, 4)
    
    VarED_DiffuseColor(-2, 1, 2)
    VarED_DiffuseColor(-1, 1, 4)
    VarED_DiffuseColor(0, 1, 8)
    VarED_DiffuseColor(1, 1, 4)
    VarED_DiffuseColor(2, 1, 2)
  Else
    VarED_DiffuseGray(1, 0, 8)
    VarED_DiffuseGray(2, 0, 4)
    
    VarED_DiffuseGray(-2, 1, 2)
    VarED_DiffuseGray(-1, 1, 4)
    VarED_DiffuseGray(0, 1, 8)
    VarED_DiffuseGray(1, 1, 4)
    VarED_DiffuseGray(2, 1, 2)
  EndIf
EndProcedure

; Applique la diffusion Sierra
Procedure VarED_ApplySierra(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a
  Protected *targetPixel.Pixel32
  
  ; Matrice Sierra (divisée par 32):
  ;       X   5   3
  ; 2   4   5   4   2
  ;     2   3   2
  
  If Not gray
    VarED_DiffuseColor(1, 0, 5)
    VarED_DiffuseColor(2, 0, 3)
    
    VarED_DiffuseColor(-2, 1, 2)
    VarED_DiffuseColor(-1, 1, 4)
    VarED_DiffuseColor(0, 1, 5)
    VarED_DiffuseColor(1, 1, 4)
    VarED_DiffuseColor(2, 1, 2)
    
    VarED_DiffuseColor(-1, 2, 2)
    VarED_DiffuseColor(0, 2, 3)
    VarED_DiffuseColor(1, 2, 2)
  Else
    VarED_DiffuseGray(1, 0, 5)
    VarED_DiffuseGray(2, 0, 3)
    
    VarED_DiffuseGray(-2, 1, 2)
    VarED_DiffuseGray(-1, 1, 4)
    VarED_DiffuseGray(0, 1, 5)
    VarED_DiffuseGray(1, 1, 4)
    VarED_DiffuseGray(2, 1, 2)
    
    VarED_DiffuseGray(-1, 2, 2)
    VarED_DiffuseGray(0, 2, 3)
    VarED_DiffuseGray(1, 2, 2)
  EndIf
EndProcedure

Procedure VariableErrorDiffusion_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB, newR, newG, newB
  Protected errR, errG, errB, a, r, g, b
  Protected alphaValue, *dstPixel.Pixel32
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  Protected algorithm = *param\option[2]
  Protected var.i
  
  clamp(levels, 2, 64)
  clamp(algorithm, 0, 5)
  
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
  
  ; Précalcul de l'adresse de base
  Protected *baseAddr = *param\addr[1]

  ; Traitement avec l'algorithme sélectionné
  For y = startPos To endPos
    For x = 0 To lg - 1
      *dstPixel = *baseAddr + (y * lg + x) << 2
      
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      alphaValue = a << 24
      
      If Not gray
        ; Mode couleur
        newR = PeekA(*ndc + oldR)
        newG = PeekA(*ndc + oldG)
        newB = PeekA(*ndc + oldB)
        errR = oldR - newR
        errG = oldG - newG
        errB = oldB - newB
        *dstPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
      Else
        ; Mode niveaux de gris
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        newG = PeekA(*ndc + g)
        errG = g - newG
        *dstPixel\l = alphaValue | newG * $10101
      EndIf
      
      ; Sélection de l'algorithme de diffusion
      Select algorithm
        Case 0  ; Floyd-Steinberg
          VarED_ApplyFloydSteinberg(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
          
        Case 1  ; Jarvis-Judice-Ninke
          VarED_ApplyJarvisJudiceNinke(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
          
        Case 2  ; Stucki
          VarED_ApplyStucki(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
          
        Case 3  ; Atkinson
          VarED_ApplyAtkinson(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
          
        Case 4  ; Burkes
          VarED_ApplyBurkes(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
          
        Case 5  ; Sierra
          VarED_ApplySierra(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
      EndSelect
    Next
  Next
  
  FreeMemory(*ndc)
EndProcedure

Procedure VariableErrorDiffusion(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_Adaptive
    *param\name = "VariableErrorDiffusion"
    *param\remarque = "Diffusion d'erreur avec algorithmes multiples"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Algorithme"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 5   : *param\info_data(2, 2) = 0
    ; 0=Floyd-Steinberg, 1=JJN, 2=Stucki, 3=Atkinson, 4=Burkes, 5=Sierra
    
    ProcedureReturn
  EndIf
  filter_start(@VariableErrorDiffusion_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 329
; FirstLine = 283
; Folding = --
; EnableXP
; DPIAware