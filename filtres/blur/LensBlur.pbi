; ---------------------------------------------------
; Lens Blur - Version optimisée
; Flou réaliste avec aberrations chromatiques radiales et vignettage
; ---------------------------------------------------

Procedure LensBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected chromaticAberration.f = \option[1] / 100.0
    Protected vignetting.f = \option[2] / 100.0
    Protected samples = \option[3]
    
    Protected x, y, i
    Protected sumR.f, sumG.f, sumB.f, sumA.f
    Protected countR, countG, countB, countA
    Protected sx, sy, index, value
    Protected r, g, b, a
    Protected angle.f, dist.f, randDist.f
    Protected cx.f = lg * 0.5, cy.f = ht * 0.5
    Protected distFromCenter.f, vignetteAmount.f
    Protected radiusR.f, radiusG.f, radiusB.f
    Protected dx.f, dy.f
    
    RandomSeed((\thread_pos + 1) * 777)
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        ; Distance au centre (pour vignettage et aberration)
        dx = (x - cx) / cx
        dy = (y - cy) / cy
        distFromCenter = Sqr(dx * dx + dy * dy)
        
        Protected aberrationFactor.f = chromaticAberration * distFromCenter
        radiusR = radius * (1.0 + aberrationFactor * 0.1)
        radiusG = radius
        radiusB = radius * (1.0 - aberrationFactor * 0.1)
        
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0
        countR = 0 : countG = 0 : countB = 0 : countA = 0
        
        For i = 0 To samples - 1
          angle = (2.0 * #PI * i) / samples
          randDist = Sqr(Random(1000) / 1000.0)
          
          ; ==== Canal Rouge ====
          dist = radiusR * randDist
          sx = x + Cos(angle) * dist
          sy = y + Sin(angle) * dist
          If sx >= 0 And sx < lg And sy >= 0 And sy < ht
            index = (Int(sy) * lg + Int(sx)) << 2
            value = PeekL(\addr[0] + index)
            r = ((value >> 16) & $FF)
            sumR + r
            countR + 1
          EndIf
          
          ; ==== Canal Vert ====
          dist = radiusG * randDist
          sx = x + Cos(angle) * dist
          sy = y + Sin(angle) * dist
          If sx >= 0 And sx < lg And sy >= 0 And sy < ht
            index = (Int(sy) * lg + Int(sx)) << 2
            value = PeekL(\addr[0] + index)
            g = ((value >> 8) & $FF)
            sumG + g
            countG + 1
          EndIf
          
          ; ==== Canal Bleu ====
          dist = radiusB * randDist
          sx = x + Cos(angle) * dist
          sy = y + Sin(angle) * dist
          If sx >= 0 And sx < lg And sy >= 0 And sy < ht
            index = (Int(sy) * lg + Int(sx)) << 2
            value = PeekL(\addr[0] + index)
            b = (value & $FF)
            sumB + b
            countB + 1
          EndIf
          
          ; ==== Canal Alpha ====
          dist = radiusG * randDist
          sx = x + Cos(angle) * dist
          sy = y + Sin(angle) * dist
          If sx >= 0 And sx < lg And sy >= 0 And sy < ht
            index = (Int(sy) * lg + Int(sx)) << 2
            value = PeekL(\addr[0] + index)
            a = ((value >> 24) & $FF)
            sumA + a
            countA + 1
          EndIf
        Next
        
        If countR > 0 : r = sumR / countR : Else : r = 0 : EndIf
        If countG > 0 : g = sumG / countG : Else : g = 0 : EndIf
        If countB > 0 : b = sumB / countB : Else : b = 0 : EndIf
        If countA > 0 : a = sumA / countA : Else : a = 255 : EndIf
        
        vignetteAmount = 1.0 - (distFromCenter * vignetting)
        If vignetteAmount < 0.0 : vignetteAmount = 0.0 : EndIf
        If vignetteAmount > 1.0 : vignetteAmount = 1.0 : EndIf
        
        r = r * vignetteAmount
        g = g * vignetteAmount
        b = b * vignetteAmount
        
        ; Clamping manuel (équivalent à ta logique Clamp)
        If a > 255 : a = 255 : ElseIf a < 0 : a = 0 : EndIf
        If r > 255 : r = 255 : ElseIf r < 0 : r = 0 : EndIf
        If g > 255 : g = 255 : ElseIf g < 0 : g = 0 : EndIf
        If b > 255 : b = 255 : ElseIf b < 0 : b = 0 : EndIf
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure LensBlurEx(*FilterCtx.FilterParams)
  Restore LensBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@LensBlur_sp())
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure LensBlur(source, cible, mask, radius, chroma, vignette, samples)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius : \option[1] = chroma : \option[2] = vignette : \option[3] = samples
  EndWith
  LensBlurEx(FilterCtx)
EndProcedure

DataSection
  LensBlur_data:
  Data.s "Lens Blur (probleme) "
  Data.s "Flou réaliste avec aberrations chromatiques radiales et vignettage"
  Data.i #FilterType_Blur, #Blur_Specialized
  Data.s "Rayon"
  Data.i 1, 30, 10
  Data.s "Aberration (%)"
  Data.i 0, 100, 30
  Data.s "Vignettage (%)"
  Data.i 0, 100, 20
  Data.s "Échantillons"
  Data.i 4, 32, 12
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 139
; FirstLine = 100
; Folding = -
; EnableXP
; DPIAware