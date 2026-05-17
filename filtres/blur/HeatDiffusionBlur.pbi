Macro HeatDiffusionAnisoBlur_sp1(var, Nvar, Svar, Wvar, Evar)
  cN = PeekF(*lookupTable + Abs(Nvar - var) * 4)
  cS = PeekF(*lookupTable + Abs(Svar - var) * 4)
  cW = PeekF(*lookupTable + Abs(Wvar - var) * 4)
  cE = PeekF(*lookupTable + Abs(Evar - var) * 4)
  var + lambda * (cN * (Nvar - var) + cS * (Svar - var) + cW * (Wvar - var) + cE * (Evar - var))
EndMacro

Procedure HeatDiffusionAnisoBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.pixelarray32 = \addr[0]
    Protected *cible.pixelarray32  = \addr[1]
    Protected *lookupTable = \addr[3]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected lambda.f = 0.2
    Protected k.f = 10.0
    If \option[1] > 0 : k = \option[1] : EndIf
    If \option[2] > 0 : lambda = \option[2] * 0.01 : EndIf
    Protected x, y, r, g, b, pos
    Protected Nr, Ng, Nb, Sr, Sg, Sb, Wr, Wg, Wb, Er, Eg, Eb
    Protected cN.f, cS.f, cW.f, cE.f
    Protected lgMinus1 = lg - 1
    Protected htMinus1 = ht - 1
    macro_calul_tread(ht)
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        pos = (y * lg + x)
        getrgb(*source\pixel[pos] , r , g , b)
        If y > 0 : getrgb(*source\pixel[pos - lg] , Nr ,Ng , Nb) : Else : Nr = r : Ng = g : Nb = b : EndIf
        If y < htMinus1 : getrgb(*source\pixel[pos + lg] , Sr , Sg , Sb) : Else : Sr = r : Sg = g : Sb = b : EndIf
        If x > 0 : getrgb(*source\pixel[pos - 1] , Wr , Wg , Wb) : Else : Wr = r : Wg = g : Wb = b : EndIf
        If x < lgMinus1 : getrgb(*source\pixel[pos + 1] , Er , Eg , Eb) : Else : Er = r : Eg = g : Eb = b : EndIf
        HeatDiffusionAnisoBlur_sp1(r, Nr, Sr, Wr, Er)
        HeatDiffusionAnisoBlur_sp1(g, Ng, Sg, Wg, Eg)
        HeatDiffusionAnisoBlur_sp1(b, Nb, Sb, Wb, Eb)
        clamp_rgb(r, g, b)
        *cible\pixel[pos] = (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure HeatDiffusionBlurEx(*FilterCtx.FilterParams)
  Restore HeatDiffusionBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[0] << 2
    Protected *tempo = AllocateMemory(total)
    If Not *tempo : ProcedureReturn 0 : EndIf
    
    \addr[3] = AllocateMemory(256 << 2)
    If Not \addr[3] : FreeMemory(*tempo) : ProcedureReturn 0 : EndIf
    
    Protected i
    Protected var.f
    Protected invK.f = 1.0 / \option[1]
    Protected invKSq.f = invK * invK
    
    For i = 0 To 255
      var = Exp(-i * i * invKSq)
      PokeF(\addr[3] + (i << 2), var)
    Next
    
    CopyMemory(\addr[0], *tempo, total)
    Protected *buf_src = *tempo
    Protected *buf_dst = \addr[1]
    
    Protected iterations = \option[0]
    For i = 1 To iterations
      \addr[0] = *buf_src
      \addr[1] = *buf_dst
      Create_MultiThread_MT(@HeatDiffusionAnisoBlur_MT())
      Swap *buf_src, *buf_dst
    Next
    
    If *buf_src <> \addr[1]
      CopyMemory(*buf_src, \addr[1], total)
    EndIf
    
    FreeMemory(*tempo)
    FreeMemory(\addr[3])
    \addr[3] = 0
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure HeatDiffusionBlur(source, cible, mask, iterations, contraste, lambda_percent)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = iterations
    \option[1] = contraste
    \option[2] = lambda_percent
  EndWith
  HeatDiffusionBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  HeatDiffusionBlur_data:
  Data.s "HeatDiffusionAnisotropic"
  Data.s "Flou anisotrope (Perona-Malik)"
  Data.i #FilterType_Blur
  Data.i #Blur_Gaussian
  Data.s "Itérations"
  Data.i 1, 50, 50
  Data.s "Contraste K"
  Data.i 1, 100, 20
  Data.s "Lambda (%)"
  Data.i 1, 25, 25
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 4
; Folding = -
; EnableXP
; DPIAware