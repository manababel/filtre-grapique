; ------------------------------------------------------------------------------
; VARIABLE ERROR DIFFUSION - Algorithmes multiples de diffusion d'erreur
; ------------------------------------------------------------------------------

; Macro de diffusion avec offset variable
Macro VarED_DiffuseColor(xOff, yOff, weight, weightDiv)
  If x + xOff >= 0 And x + xOff < lg And y + yOff >= 0 And y + yOff < ht
    *targetPixel.Pixel32 = *baseAddr + ((y + yOff) * lg + x + xOff) << 2
    getrgb(*targetPixel\l, r, g, b)
    r + (errR * weight) / weightDiv
    g + (errG * weight) / weightDiv
    b + (errB * weight) / weightDiv
    clamp_RGB(r, g, b)
    *targetPixel\l = alphaValue | (r << 16) | (g << 8) | b
  EndIf
EndMacro

Macro VarED_DiffuseGray(xOff, yOff, weight, weightDiv)
  If x + xOff >= 0 And x + xOff < lg And y + yOff >= 0 And y + yOff < ht
    *targetPixel.Pixel32 = *baseAddr + ((y + yOff) * lg + x + xOff) << 2
    getargb(*targetPixel\l, a, r, g, b)
    g = (r * 77 + g * 150 + b * 29) >> 8
    g + (errG * weight) / weightDiv
    clamp(g, 0, 255)
    *targetPixel\l = (a << 24) | g * $10101
  EndIf
EndMacro

; Applique la diffusion Floyd-Steinberg (Div 16)
Procedure VarED_ApplyFloydSteinberg(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a, *targetPixel.Pixel32
  If Not gray
    VarED_DiffuseColor(1, 0, 7, 16) : VarED_DiffuseColor(-1, 1, 3, 16)
    VarED_DiffuseColor(0, 1, 5, 16) : VarED_DiffuseColor(1, 1, 1, 16)
  Else
    VarED_DiffuseGray(1, 0, 7, 16) : VarED_DiffuseGray(-1, 1, 3, 16)
    VarED_DiffuseGray(0, 1, 5, 16) : VarED_DiffuseGray(1, 1, 1, 16)
  EndIf
EndProcedure

; Applique la diffusion Jarvis-Judice-Ninke (Div 48)
Procedure VarED_ApplyJJN(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a, *targetPixel.Pixel32
  If Not gray
    VarED_DiffuseColor(1, 0, 7, 48) : VarED_DiffuseColor(2, 0, 5, 48)
    VarED_DiffuseColor(-2, 1, 3, 48) : VarED_DiffuseColor(-1, 1, 5, 48) : VarED_DiffuseColor(0, 1, 7, 48) : VarED_DiffuseColor(1, 1, 5, 48) : VarED_DiffuseColor(2, 1, 3, 48)
    VarED_DiffuseColor(-2, 2, 1, 48) : VarED_DiffuseColor(-1, 2, 3, 48) : VarED_DiffuseColor(0, 2, 5, 48) : VarED_DiffuseColor(1, 2, 3, 48) : VarED_DiffuseColor(2, 2, 1, 48)
  Else
    VarED_DiffuseGray(1, 0, 7, 48) : VarED_DiffuseGray(2, 0, 5, 48)
    VarED_DiffuseGray(-2, 1, 3, 48) : VarED_DiffuseGray(-1, 1, 5, 48) : VarED_DiffuseGray(0, 1, 7, 48) : VarED_DiffuseGray(1, 1, 5, 48) : VarED_DiffuseGray(2, 1, 3, 48)
    VarED_DiffuseGray(-2, 2, 1, 48) : VarED_DiffuseGray(-1, 2, 3, 48) : VarED_DiffuseGray(0, 2, 5, 48) : VarED_DiffuseGray(1, 2, 3, 48) : VarED_DiffuseGray(2, 2, 1, 48)
  EndIf
EndProcedure

; Applique la diffusion Stucki (Div 42)
Procedure VarED_ApplyStucki(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a, *targetPixel.Pixel32
  If Not gray
    VarED_DiffuseColor(1, 0, 8, 42) : VarED_DiffuseColor(2, 0, 4, 42)
    VarED_DiffuseColor(-2, 1, 2, 42) : VarED_DiffuseColor(-1, 1, 4, 42) : VarED_DiffuseColor(0, 1, 8, 42) : VarED_DiffuseColor(1, 1, 4, 42) : VarED_DiffuseColor(2, 1, 2, 42)
    VarED_DiffuseColor(-2, 2, 1, 42) : VarED_DiffuseColor(-1, 2, 2, 42) : VarED_DiffuseColor(0, 2, 4, 42) : VarED_DiffuseColor(1, 2, 2, 42) : VarED_DiffuseColor(2, 2, 1, 42)
  Else
    VarED_DiffuseGray(1, 0, 8, 42) : VarED_DiffuseGray(2, 0, 4, 42)
    VarED_DiffuseGray(-2, 1, 2, 42) : VarED_DiffuseGray(-1, 1, 4, 42) : VarED_DiffuseGray(0, 1, 8, 42) : VarED_DiffuseGray(1, 1, 4, 42) : VarED_DiffuseGray(2, 1, 2, 42)
    VarED_DiffuseGray(-2, 2, 1, 42) : VarED_DiffuseGray(-1, 2, 2, 42) : VarED_DiffuseGray(0, 2, 4, 42) : VarED_DiffuseGray(1, 2, 2, 42) : VarED_DiffuseGray(2, 2, 1, 42)
  EndIf
EndProcedure

; Applique la diffusion Atkinson (Div 8)
Procedure VarED_ApplyAtkinson(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a, *targetPixel.Pixel32
  If Not gray
    VarED_DiffuseColor(1, 0, 1, 8) : VarED_DiffuseColor(2, 0, 1, 8)
    VarED_DiffuseColor(-1, 1, 1, 8) : VarED_DiffuseColor(0, 1, 1, 8) : VarED_DiffuseColor(1, 1, 1, 8)
    VarED_DiffuseColor(0, 2, 1, 8)
  Else
    VarED_DiffuseGray(1, 0, 1, 8) : VarED_DiffuseGray(2, 0, 1, 8)
    VarED_DiffuseGray(-1, 1, 1, 8) : VarED_DiffuseGray(0, 1, 1, 8) : VarED_DiffuseGray(1, 1, 1, 8)
    VarED_DiffuseGray(0, 2, 1, 8)
  EndIf
EndProcedure

; Applique la diffusion Burkes (Div 32)
Procedure VarED_ApplyBurkes(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a, *targetPixel.Pixel32
  If Not gray
    VarED_DiffuseColor(1, 0, 8, 32) : VarED_DiffuseColor(2, 0, 4, 32)
    VarED_DiffuseColor(-2, 1, 2, 32) : VarED_DiffuseColor(-1, 1, 4, 32) : VarED_DiffuseColor(0, 1, 8, 32) : VarED_DiffuseColor(1, 1, 4, 32) : VarED_DiffuseColor(2, 1, 2, 32)
  Else
    VarED_DiffuseGray(1, 0, 8, 32) : VarED_DiffuseGray(2, 0, 4, 32)
    VarED_DiffuseGray(-2, 1, 2, 32) : VarED_DiffuseGray(-1, 1, 4, 32) : VarED_DiffuseGray(0, 1, 8, 32) : VarED_DiffuseGray(1, 1, 4, 32) : VarED_DiffuseGray(2, 1, 2, 32)
  EndIf
EndProcedure

; Applique la diffusion Sierra (Div 32)
Procedure VarED_ApplySierra(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
  Protected r, g, b, a, *targetPixel.Pixel32
  If Not gray
    VarED_DiffuseColor(1, 0, 5, 32) : VarED_DiffuseColor(2, 0, 3, 32)
    VarED_DiffuseColor(-2, 1, 2, 32) : VarED_DiffuseColor(-1, 1, 4, 32) : VarED_DiffuseColor(0, 1, 5, 32) : VarED_DiffuseColor(1, 1, 4, 32) : VarED_DiffuseColor(2, 1, 2, 32)
    VarED_DiffuseColor(-1, 2, 2, 32) : VarED_DiffuseColor(0, 2, 3, 32) : VarED_DiffuseColor(1, 2, 2, 32)
  Else
    VarED_DiffuseGray(1, 0, 5, 32) : VarED_DiffuseGray(2, 0, 3, 32)
    VarED_DiffuseGray(-2, 1, 2, 32) : VarED_DiffuseGray(-1, 1, 4, 32) : VarED_DiffuseGray(0, 1, 5, 32) : VarED_DiffuseGray(1, 1, 4, 32) : VarED_DiffuseGray(2, 1, 2, 32)
    VarED_DiffuseGray(-1, 2, 2, 32) : VarED_DiffuseGray(0, 2, 3, 32) : VarED_DiffuseGray(1, 2, 2, 32)
  EndIf
EndProcedure

Procedure VariableErrorDiffusion_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, i
    Protected oldR, oldG, oldB, newR, newG, newB
    Protected errR, errG, errB, a, g
    Protected alphaValue, *dstPixel.Pixel32
    Protected levels = \option[0]
    Protected gray = \option[1]
    Protected algorithm = \option[2]
    Protected var.i
    
    clamp(levels, 2, 64)
    clamp(algorithm, 0, 5)
    
    Protected *ndc = AllocateMemory(256)
    If Not *ndc : ProcedureReturn : EndIf
    
    Protected Steping.f = 255.0 / (levels - 1)
    Protected reciprocal.f = 1.0 / Steping
    
    For i = 0 To 255
      var = Round(i * reciprocal, #PB_Round_Nearest) * Steping
      clamp(var, 0, 255)
      PokeA(*ndc + i, var)
    Next
    
    macro_calul_tread((ht))
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    Protected *baseAddr = \addr[1]

    For y = startPos To endPos
      For x = 0 To lg - 1
        *dstPixel = *baseAddr + (y * lg + x) << 2
        getargb(*dstPixel\l, a, oldR, oldG, oldB)
        alphaValue = a << 24
        
        If Not gray
          newR = PeekA(*ndc + oldR) : newG = PeekA(*ndc + oldG) : newB = PeekA(*ndc + oldB)
          errR = oldR - newR : errG = oldG - newG : errB = oldB - newB
          *dstPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
        Else
          g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
          newG = PeekA(*ndc + g) : errG = g - newG
          *dstPixel\l = alphaValue | newG * $10101
        EndIf
        
        Select algorithm
          Case 0 : VarED_ApplyFloydSteinberg(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
          Case 1 : VarED_ApplyJJN(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
          Case 2 : VarED_ApplyStucki(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
          Case 3 : VarED_ApplyAtkinson(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
          Case 4 : VarED_ApplyBurkes(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
          Case 5 : VarED_ApplySierra(*baseAddr, x, y, lg, ht, errR, errG, errB, alphaValue, gray)
        EndSelect
      Next
    Next
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure VariableErrorDiffusionEx(*FilterCtx.FilterParams)
  Restore VariableErrorDiffusion_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@VariableErrorDiffusion_MT())
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure VariableErrorDiffusion(source, cible, mask, levels, gray, algorithm)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
    \option[2] = algorithm
  EndWith
  VariableErrorDiffusionEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  VariableErrorDiffusion_data:
  Data.s "VariableErrorDiffusion"
  Data.s "Diffusion d'erreur avec algorithmes multiples"
  Data.i #FilterType_Dithering
  Data.i #Dither_Adaptive
  
  Data.s "Nb de niveaux"       
  Data.i 2, 64, 6
  Data.s "Noir et blanc"   
  Data.i 0, 1, 0
  Data.s "Algorithme"
  Data.i 0, 5, 0 ; 0=Floyd, 1=JJN, 2=Stucki, 3=Atkinson, 4=Burkes, 5=Sierra
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 182
; FirstLine = 157
; Folding = --
; EnableXP
; DPIAware