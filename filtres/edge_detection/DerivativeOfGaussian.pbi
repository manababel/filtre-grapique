;------------------------------------------------
; Macro pour convertir un pixel en niveau de gris
;------------------------------------------------
Macro DoG_sp(var)
  getrgb(PeekL(*srcPixel), r, g, b)
  gray(var) = (r*77 + g*150 + b*29) >> 8
  *srcPixel = *srcPixel + 4
EndMacro

;------------------------------------------------
; Procedure DoG - traitement multi-thread
;------------------------------------------------
Procedure DerivativeOfGaussian_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]

    Protected sigma.f = \option[0] * 0.5   ; écart-type du Gaussien
    Protected mul.f = \option[1] * 0.05
    Protected inverse = \option[2]

    If sigma < 0.5 : sigma = 0.5 : EndIf

    ; définir taille du noyau
    Protected kSize = 5   ; noyau 5x5
    Protected center = kSize/2

    ; créer le noyau de dérivée de Gaussienne (X et Y)
    Protected Dim Gx.f(kSize-1, kSize-1)
    Protected Dim Gy.f(kSize-1, kSize-1)

    Protected x, y
    Protected sumX.f, sumY.f
    Protected *srcPixel.Long
    Protected *dstPixel.Long
    Protected i, j
    Protected a , r , g , b
    Protected Dim gray.q(24)
    Protected v.q, maxv.q
    Protected startPos, endPos
    Protected var = (2*sigma*sigma)
    Protected xc.f , yc.f
    
    ; calcul du noyau DoG
    For y=0 To kSize-1
      For x=0 To kSize-1
        Gx(x,y) = -(x-center) * Exp(-((x-center)*(x-center)+(y-center)*(y-center))/var)
        Gy(x,y) = -(y-center) * Exp(-((x-center)*(x-center)+(y-center)*(y-center))/var)
      Next
    Next

    ; limites pour multi-thread
    macro_calul_tread((ht - kSize))
    startPos = thread_start + center
    endPos   = thread_stop + center
    
    If startPos < center : startPos = center : EndIf
    If endPos > ht-center-1 : endPos = ht-center-1 : EndIf

    ; traitement pixels
    For y=startPos To endPos
      For x=center To lg-center-1
        ; lecture 5x5
        i=0
        For j=-center To center
          *srcPixel = *source + ((y+j)*lg + (x-center))*4
          DoG_sp(i) : DoG_sp(i+1) : DoG_sp(i+2) : DoG_sp(i+3) : DoG_sp(i+4)
          i=i+5
        Next

        ; convolution DoG
        v=0
        For j=0 To kSize-1
          For i=0 To kSize-1
            v = v + gray(j*kSize+i) * (Gx(i,j) + Gy(i,j))
          Next
        Next

        ; normalisation et clamp
        v = Abs(v) * mul
        clamp(v,0,255)
        If inverse : v = 255-v : EndIf

        *dstPixel = *cible + (y*lg + x)*4
        PokeL(*dstPixel, $FF000000 | (v*$010101))
      Next
    Next
  EndWith
EndProcedure

;------------------------------------------------
; Procedure DerivativeOfGaussianEx
;------------------------------------------------
Procedure DerivativeOfGaussianEx(*FilterCtx.FilterParams)
  
  Restore DerivativeOfGaussian_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@DerivativeOfGaussian_MT())
  
  mask_update(*FilterCtx.FilterParams , last_data)
  
EndProcedure

;------------------------------------------------
; Procedure principale
;------------------------------------------------
Procedure DerivativeOfGaussian(source , cible , mask , sigma , multiplicateur , inversion)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = sigma
    \option[1] = multiplicateur
    \option[2] = inversion
  EndWith
  DerivativeOfGaussianEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  DerivativeOfGaussian_data:
  Data.s "DerivativeOfGaussian"
  Data.s "Contour avec dérivée de Gaussienne"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
  
  Data.s "Sigma"        
  Data.i 1,10,2
  Data.s "Multiplicateur"   
  Data.i 1,100,10
  Data.s "Inversion"        
  Data.i 0,1,0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 131
; FirstLine = 85
; Folding = -
; EnableXP
; DPIAware