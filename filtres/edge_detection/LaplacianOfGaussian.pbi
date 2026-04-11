Procedure LaplacianOfGaussian_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected seuil = *param\option[0]
  Protected mul.f = *param\option[1]
  Protected maskSize = *param\option[2] ; taille du masque : 5, 7, 9, etc.
  Protected sigma.f = *param\option[3]  ; sigma : 1.0, 1.4, etc.
  Protected invese = *param\option[4]
  Protected toGray = *param\option[5]
  
  maskSize = (maskSize * 2) + 1 ; s'assurer que la taille est impaire
  clamp(seuil, 0, 255)
  clamp(mul, 1, 100)
  clamp(sigma, 1, 100)
  sigma = sigma *0.01 + 0.1
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
  
Protected startPos = offset + (*param\thread_pos * (ht - 2 * offset)) / *param\thread_max
Protected endPos   = offset + ((*param\thread_pos + 1) * (ht - 2 * offset)) / *param\thread_max

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
EndProcedure
  
Procedure LaplacianOfGaussian(*param.parametre)
  ; Affichage des informations de configuration si demandé
  If param\info_active
    param\typ = #FilterType_EdgeDetection
    param\subtype = #EdgeDetect_Laplacian
    param\name = "LaplacianOfGaussian"
    param\remarque = ""
    param\info[0] = "seuil"             
    param\info[1] = "multiply"                  
    param\info[2] = "maskSize"   
    param\info[3] = "sigma"
    param\info[4] = "inverse"
    param\info[5] = "togray" 
    param\info[6] = "Masque binaire"           
    param\info_data(0,0) = 0 : param\info_data(0,1) = 255  : param\info_data(0,2) = 50
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100  : param\info_data(1,2) = 60 
    param\info_data(2,0) = 1 : param\info_data(2,1) = 5  : param\info_data(2,2) = 1
    param\info_data(3,0) = 1 : param\info_data(3,1) = 10  : param\info_data(3,2) = 3
    param\info_data(4,0) = 0 : param\info_data(4,1) = 1  : param\info_data(4,2) = 0 
    param\info_data(5,0) = 0 : param\info_data(5,1) = 1  : param\info_data(5,2) = 0
    param\info_data(6,0) = 0 : param\info_data(6,1) = 2  : param\info_data(6,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@LaplacianOfGaussian_MT() , 4)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 101
; FirstLine = 59
; Folding = -
; EnableXP
; DPIAware