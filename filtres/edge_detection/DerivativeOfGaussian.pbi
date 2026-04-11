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
Procedure DerivativeOfGaussian_MT(*param.parametre)

  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht

  Protected sigma.f = *param\option[0] * 0.5   ; écart-type du Gaussien
  Protected mul.f = *param\option[1] * 0.05
  Protected inverse = *param\option[2]

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
  startPos = (*param\thread_pos * (ht - kSize)) / *param\thread_max + center
  endPos   = ((*param\thread_pos + 1) * (ht - kSize)) / *param\thread_max + center
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

EndProcedure

;------------------------------------------------
; Procedure principale
;------------------------------------------------
Procedure DerivativeOfGaussian(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Gradient
    *param\name = "Derivative of Gaussian"
    *param\remarque = "Contour avec dérivée de Gaussienne"
    *param\info[0] = "Sigma"
    *param\info[1] = "Multiplicateur"
    *param\info[2] = "Inversion"
    *param\info[3] = "masque"
    *param\info_data(0,0)=1 : *param\info_data(0,1)=10  : *param\info_data(0,2)=2
    *param\info_data(1,0)=1 : *param\info_data(1,1)=100 : *param\info_data(1,2)=10
    *param\info_data(2,0)=0 : *param\info_data(2,1)=1   : *param\info_data(2,2)=0
    *param\info_data(3,0) = 0   : *param\info_data(3,1) = 2   : *param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@DerivativeOfGaussian_MT(), 3)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 108
; FirstLine = 50
; Folding = -
; EnableXP
; DPIAware