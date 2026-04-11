Procedure AutoOtsuThreshold_MT(*param.parametre)
  
  Protected *source = *param\source
  Protected *cible  = *param\cible
  Protected *mask   = *param\mask
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected tmax = lg * ht
  Protected i, x, y, r, g, b, lum, var, alpha ,t
  Protected threshold

  Dim histo(255)
  Dim buffer(tmax)

  ; === Étape 1 : Calcul histogramme de luminance ===
  For i = 0 To tmax - 1
    var = PeekL(*source + i * 4)
    r = (var >> 16) & $FF
    g = (var >> 8)  & $FF
    b = var & $FF
    lum = (r * 54 + g * 183 + b * 18) >> 8  ; Rec.709
    buffer(i) = lum
    histo(lum) + 1
  Next

  ; === Étape 2 : Calcul du seuil optimal (Otsu) ===
  Protected total = tmax
  Protected sumAll = 0
  For i = 0 To 255 : sumAll + i * histo(i) : Next

  Protected sum = 0, wB = 0, wF, mB.f, mF.f
  Protected maxVar.f = -1.0
  threshold = 0

  For t = 0 To 255
    wB + histo(t)
    If wB = 0 : Continue : EndIf
    wF = total - wB
    If wF = 0 : Break : EndIf

    sum + t * histo(t)
    mB = sum / wB
    mF = (sumAll - sum) / wF

    Protected varBetween.f = wB * wF * (mB - mF) * (mB - mF)
    If varBetween > maxVar
      maxVar = varBetween
      threshold = t
    EndIf
  Next

  ; === Étape 3 : Binarisation ===
  For i = 0 To tmax - 1
    If buffer(i) > threshold
      PokeL(*cible + i * 4, $FFFFFF)
    Else
      PokeL(*cible + i * 4, 0)
    EndIf
  Next

EndProcedure

Procedure AutoOtsuThreshold(*param.parametre)
  ; Affichage des informations si demandé
  If param\info_active
    param\typ = #FilterType_Dithering
    param\name = "AutoOtsuThreshold"
    param\remarque = "Attention , fonction non threadée"
    *param\info[0] = "Masque"
    *param\info_data(0, 0) = 0   : *param\info_data(0, 1) = 2  : *param\info_data(0, 2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@AutoOtsuThreshold_MT(), 2, 1)
  
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 52
; FirstLine = 7
; Folding = -
; EnableXP
; DPIAware