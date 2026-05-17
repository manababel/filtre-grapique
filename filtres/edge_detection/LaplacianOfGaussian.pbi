Procedure LaplacianOfGaussian_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected seuil = \option[0]
    Protected mul.f = \option[1]
    Protected maskSize = \option[2] ; taille du masque : 5, 7, 9, etc.
    Protected sigma.f = \option[3]  ; sigma : 1.0, 1.4, etc.
    Protected invese = \option[4]
    Protected toGray = \option[5]
    
    maskSize = (maskSize * 2) + 1 ; s'assurer que la taille est impaire
    clamp(seuil, 0, 255)
    clamp(mul, 1, 100)
    clamp(sigma, 1, 100)
    sigma = sigma * 0.01 + 0.1
    mul = mul * 0.1 + 1
    
    Protected offset = maskSize / 2
    Protected maskArea = maskSize * maskSize
    Dim logMask.l(maskArea - 1)
    Dim logMaskf.f(maskArea - 1) 
    
    ; Génération du masque LoG
    Protected i, j, x, y, dx, dy, pos, r, g, b
    Protected cx = maskSize / 2
    Protected norm.f, value.f
    Protected sum.f = 0
    For y = 0 To maskSize - 1
      For x = 0 To maskSize - 1
        dx = x - cx
        dy = y - cx
        norm = (dx * dx + dy * dy) / (2 * sigma * sigma)
        value = -1 / (#PI * Pow(sigma, 4)) * (1 - norm) * Exp(-norm)
        sum = sum + value
        logMaskF(y * maskSize + x) = value
      Next
    Next
    
    For i = 0 To maskArea - 1
      logMask(i) = Int((logMaskF(i) - sum / maskArea) * mul)
    Next
    
    ; Application du filtre
    Protected rf.f, gf.f, bf.f
    Protected rr, gg, bb, gray
    
    macro_calul_tread((ht - 2 * offset))
    Protected startPos = offset + thread_start
    Protected endPos   = offset + thread_stop

    If startPos < offset : startPos = offset : EndIf
    If endPos > ht - offset : endPos = ht - offset : EndIf

    For y = startPos To endPos - 1
      For x = offset To lg - offset - 1
        rr = 0 : gg = 0 : bb = 0 : i = 0
        For dy = -offset To offset
          For dx = -offset To offset
            pos = PeekL(*source + ((y + dy) * lg + (x + dx)) * 4)
            GetRGB(pos, r, g, b)
            rr + r * logMask(i)
            gg + g * logMask(i)
            bb + b * logMask(i)
            i + 1
          Next
        Next

        ; Conversion float vers integer après application du gain
        If rr < 0 : rr = -rr : EndIf
        If gg < 0 : gg = -gg : EndIf
        If bb < 0 : bb = -bb : EndIf
        rr = rr >> 8
        gg = gg >> 8
        bb = bb >> 8
        clamp_rgb(rr, gg, bb)

        If toGray
          gray = (rr * 77 + gg * 150 + bb * 29) >> 8
          rr = gray : gg = gray : bb = gray
        EndIf

        If (rr + gg + bb) / 3 < seuil
          rr = 0 : gg = 0 : bb = 0
        EndIf
        
        If invese 
          rr = 255 - rr : gg = 255 - gg : bb = 255 - bb
        EndIf
        
        PokeL(*cible + (y * lg + x) * 4, rr << 16 + gg << 8 + bb)
      Next
    Next
    FreeArray(logMaskf())
    FreeArray(logMask())
  EndWith
EndProcedure

Procedure LaplacianOfGaussianEx(*FilterCtx.FilterParams)
  
  Restore LaplacianOfGaussian_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@LaplacianOfGaussian_MT())
  
  mask_update(*FilterCtx.FilterParams , last_data)
  
EndProcedure

Procedure LaplacianOfGaussian(source , cible , mask , seuil , multiply , maskSize , sigma , inverse , togray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = seuil
    \option[1] = multiply
    \option[2] = maskSize
    \option[3] = sigma
    \option[4] = inverse
    \option[5] = togray
  EndWith
  LaplacianOfGaussianEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  LaplacianOfGaussian_data:
  Data.s "LaplacianOfGaussian"
  Data.s ""
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Laplacian
  
  Data.s "seuil"        
  Data.i 0,255,50
  Data.s "multiply"   
  Data.i 0,100,60
  Data.s "maskSize"        
  Data.i 1,5,1
  Data.s "sigma"  
  Data.i 1,10,3
  Data.s "inverse"  
  Data.i 0,1,0
  Data.s "togray"  
  Data.i 0,1,0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 112
; FirstLine = 96
; Folding = -
; EnableXP
; DPIAware