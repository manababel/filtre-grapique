Procedure RollingGuidance_Bilateral(*src, *guide, w, h, radius, sigmaColor)
  Protected *dst = AllocateMemory(w * h * 4)
  If *dst = 0 : ProcedureReturn : EndIf
  
  Protected x, y, dx, dy, px, py
  Protected idx, idx2
  Protected r0, g0, b0
  Protected r, g, b
  Protected sumR.d, sumG.d, sumB.d, sumA.d, sumW.d
  Protected dColor.d, wColor.d, wSpace.d, wTot.d
  Protected sigma2.d = sigmaColor * sigmaColor
  Protected invSigma2.d = 1.0 / sigma2
  Protected radiusSq.d = radius * radius
  Protected invRadiusSq.d = 1.0 / radiusSq
  Protected w_minus_1 = w - 1
  Protected h_minus_1 = h - 1
  Protected invSumW.d
  
  For y = 0 To h - 1
    For x = 0 To w - 1
      idx = (y * w + x) * 4
      
      ; Guide pixel
      r0 = PeekA(*guide + idx + 2)
      g0 = PeekA(*guide + idx + 1)
      b0 = PeekA(*guide + idx)
      
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : sumW = 0.0
      
      For dy = -radius To radius
        py = y + dy
        If py < 0 : py = 0 : ElseIf py > h_minus_1 : py = h_minus_1 : EndIf
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 : px = 0 : ElseIf px > w_minus_1 : px = w_minus_1 : EndIf
          
          idx2 = (py * w + px) * 4
          r = PeekA(*src + idx2 + 2)
          g = PeekA(*src + idx2 + 1)
          b = PeekA(*src + idx2)
          
          ; Distance couleur par rapport au GUIDE
          Protected dr = r0 - r
          Protected dg = g0 - g
          Protected db = b0 - b
          dColor = dr * dr + dg * dg + db * db
          
          wColor = Exp(-dColor * invSigma2)
          wSpace = Exp(-(dx * dx + dy * dy) * invRadiusSq)
          wTot = wColor * wSpace
          
          sumR + r * wTot
          sumG + g * wTot
          sumB + b * wTot
          sumA + PeekA(*src + idx2 + 3) * wTot
          sumW + wTot
        Next
      Next
      
      If sumW > 0.0
        invSumW = 1.0 / sumW
        PokeA(*dst + idx + 3, Int(sumA * invSumW + 0.5))
        PokeA(*dst + idx + 2, Int(sumR * invSumW + 0.5))
        PokeA(*dst + idx + 1, Int(sumG * invSumW + 0.5))
        PokeA(*dst + idx,     Int(sumB * invSumW + 0.5))
      Else
        ; Copie du pixel source si aucun poids
        PokeL(*dst + idx, PeekL(*src + idx))
      EndIf
    Next
  Next
  
  CopyMemory(*dst, *src, w * h * 4)
  FreeMemory(*dst)
EndProcedure


Procedure RollingGuidanceFilter_sp(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]
  Protected sigmaColor = *param\option[1]
  Protected iterations = *param\option[2]
  
  ; Validation des paramètres
  If radius < 1 : radius = 1 : EndIf
  If sigmaColor < 1 : sigmaColor = 1 : EndIf
  If iterations < 1 : iterations = 1 : EndIf
  
  Protected i
  Protected total = lg * ht * 4
  Protected *cur = AllocateMemory(total)
  Protected *guide = AllocateMemory(total)
  
  ; Vérification des allocations
  If *cur = 0 Or *guide = 0
    If *cur : FreeMemory(*cur) : EndIf
    If *guide : FreeMemory(*guide) : EndIf
    ProcedureReturn
  EndIf
  
  ; Initialisation
  CopyMemory(*param\addr[0], *cur, total)
  CopyMemory(*cur, *guide, total)
  
  ; Initial blur léger (optionnel mais recommandé)
  LaplacianPyramidBlur_BlurBuffer(*cur, lg, ht, radius)
  
  ; Itérations RGF
  For i = 0 To iterations - 1
    RollingGuidance_Bilateral(*cur, *guide, lg, ht, radius, sigmaColor)
    CopyMemory(*cur, *guide, total)
  Next
  
  ; Copie du résultat
  CopyMemory(*cur, *param\addr[1], total)
  
  ; Libération de la mémoire
  FreeMemory(*cur)
  FreeMemory(*guide)
EndProcedure


Procedure RollingGuidanceFilter(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Adaptive
    *param\name = "Rolling Guidance Filter"
    *param\remarque = "Filtre de lissage avec préservation des bords"
    *param\info[0] = "Rayon spatial"
    *param\info[1] = "Sigma couleur"
    *param\info[2] = "Itérations"
    *param\info[3] = "Masque"
    *param\info_data(0, 0) = 1  : *param\info_data(0, 1) = 20  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 5  : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 30
    *param\info_data(2, 0) = 1  : *param\info_data(2, 1) = 10  : *param\info_data(2, 2) = 3
    *param\info_data(3, 0) = 0  : *param\info_data(3, 1) = 2   : *param\info_data(3, 2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@RollingGuidanceFilter_sp(), 1)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 142
; FirstLine = 70
; Folding = -
; EnableXP
; DPIAware