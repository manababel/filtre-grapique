Macro HeatDiffusionAnisoBlur_sp1(var, Nvar, Svar, Wvar, Evar)
  cN = PeekF(*lookupTable + Abs(Nvar - var) * 4)
  cS = PeekF(*lookupTable + Abs(Svar - var) * 4)
  cW = PeekF(*lookupTable + Abs(Wvar - var) * 4)
  cE = PeekF(*lookupTable + Abs(Evar - var) * 4)
  var + lambda * (cN * (Nvar - var) + cS * (Svar - var) + cW * (Wvar - var) + cE * (Evar - var))
EndMacro

Procedure HeatDiffusionAnisoBlur(*param.parametre)
  Protected *addr0 = *param\addr[0]
  Protected *addr1 = *param\addr[1]
  Protected *lookupTable = *param\addr[3]
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected lambda.f = 0.2
  Protected k.f = 10.0
  If *param\option[1] > 0 : k = *param\option[1] : EndIf
  If *param\option[2] > 0 : lambda = *param\option[2] * 0.01 : EndIf  ; Division optimisée
  
  Protected x, y, r, g, b, pos
  Protected Nr, Ng, Nb, Sr, Sg, Sb, Wr, Wg, Wb, Er, Eg, Eb
  Protected cN.f, cS.f, cW.f, cE.f
  Protected col
  
  Protected startY = (*param\thread_pos * ht) / *param\thread_max
  Protected stopY = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  If stopY >= ht : stopY = ht - 1 : EndIf
  
  ; Précalcul des constantes
  Protected lgShift2 = lg << 2  ; lg * 4
  Protected lgMinus1 = lg - 1
  Protected htMinus1 = ht - 1
  Protected posN, posS, posW, posE
  
  For y = startY To stopY
    For x = 0 To lg - 1
      pos = (y * lg + x) << 2
      
      ; Pixel central
      col = PeekL(*addr0 + pos)
      getrgb(col, r, g, b)
      
      ; Voisins - calcul optimisé des positions
      If y > 0
        posN = pos - lgShift2
        col = PeekL(*addr0 + posN)
        getrgb(col, Nr, Ng, Nb)
      Else
        Nr = r : Ng = g : Nb = b
      EndIf
      
      If y < htMinus1
        posS = pos + lgShift2
        col = PeekL(*addr0 + posS)
        getrgb(col, Sr, Sg, Sb)
      Else
        Sr = r : Sg = g : Sb = b
      EndIf
      
      If x > 0
        posW = pos - 4
        col = PeekL(*addr0 + posW)
        getrgb(col, Wr, Wg, Wb)
      Else
        Wr = r : Wg = g : Wb = b
      EndIf
      
      If x < lgMinus1
        posE = pos + 4
        col = PeekL(*addr0 + posE)
        getrgb(col, Er, Eg, Eb)
      Else
        Er = r : Eg = g : Eb = b
      EndIf
      
      ; === DIFFUSION ANISOTROPE ===
      HeatDiffusionAnisoBlur_sp1(r, Nr, Sr, Wr, Er)
      HeatDiffusionAnisoBlur_sp1(g, Ng, Sg, Wg, Eg)
      HeatDiffusionAnisoBlur_sp1(b, Nb, Sb, Wb, Eb)
      
      clamp_rgb(r, g, b)
      PokeL(*addr1 + pos, (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure HeatDiffusionBlur(*param.parametre)
  If *param\info_active
    *param\name = "HeatDiffusionAnisotropic"
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Gaussian
    *param\remarque = "Flou anisotrope (Perona-Malik)"
    *param\info[0] = "Itérations"
    *param\info[1] = "Contraste K"
    *param\info[2] = "Lambda (%)"
    *param\info[3] = "Masque binaire"
    *param\info_data(0,0) = 1   : *param\info_data(0,1) = 50  : *param\info_data(0,2) = 50
    *param\info_data(1,0) = 1   : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 20
    *param\info_data(2,0) = 1   : *param\info_data(2,1) = 25  : *param\info_data(2,2) = 25
    *param\info_data(3,0) = 0   : *param\info_data(3,1) = 2   : *param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected total = *param\lg * *param\ht << 2
  Protected *tempo = AllocateMemory(total)
  If Not *tempo : ProcedureReturn : EndIf
  
  ; Allocation de la lookup table (256 valeurs)
  *param\addr[3] = AllocateMemory(256 << 2)  ; 256 * 4
  If Not *param\addr[3]
    FreeMemory(*tempo)
    ProcedureReturn
  EndIf
  
  ; Précalcul de la lookup table
  Protected i
  Protected var.f
  Protected invK.f = 1.0 / *param\option[1]  ; Précalcul
  Protected invKSq.f = invK * invK
  
  For i = 0 To 255
    var = Exp(-i * i * invKSq)  ; Optimisé : évite Pow() et division répétée
    PokeF(*param\addr[3] + (i << 2), var)
  Next
  
  CopyMemory(*param\source, *tempo, total)
  *param\addr[0] = *tempo
  *param\addr[1] = *param\cible
  
  Protected iterations = *param\option[0]
  For i = 1 To iterations
    MultiThread_MT(@HeatDiffusionAnisoBlur())
    Swap *param\addr[0], *param\addr[1]
  Next
  
  If *param\mask And *param\option[3]
    *param\mask_type = *param\option[3] - 1
    MultiThread_MT(@_mask())
  EndIf
  
  If *tempo : FreeMemory(*tempo) : EndIf
  If *param\addr[3] : FreeMemory(*param\addr[3]) : EndIf
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 3
; Folding = -
; EnableXP
; DPIAware