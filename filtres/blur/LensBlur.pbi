Procedure LensBlur_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected radius = *param\option[0]
  Protected chromaticAberration.f = *param\option[1] / 100.0  ; Aberration (0-100%)
  Protected vignetting.f = *param\option[2] / 100.0           ; Vignettage (0-100%)
  Protected samples = *param\option[3]
  
  If radius < 1 : radius = 1 : EndIf
  If samples < 4 : samples = 4 : EndIf
  If samples > 32 : samples = 32 : EndIf
  
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
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      ; Distance au centre (pour vignettage et aberration)
      dx = (x - cx) / cx
      dy = (y - cy) / cy
      distFromCenter = Sqr(dx * dx + dy * dy)
      
      ; Aberration chromatique radiale (rouge décalé vers l'extérieur, bleu vers l'intérieur)
      ; Plus fort aux bords de l'image
      Protected aberrationFactor.f = chromaticAberration * distFromCenter
      radiusR = radius * (1.0 + aberrationFactor * 0.1)  ; Rouge plus grand
      radiusG = radius                                     ; Vert de référence
      radiusB = radius * (1.0 - aberrationFactor * 0.1)  ; Bleu plus petit
      
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0
      countR = 0 : countG = 0 : countB = 0 : countA = 0
      
      ; Échantillonnage circulaire pour chaque canal
      For i = 0 To samples - 1
        angle = (2.0 * #PI * i) / samples
        randDist = Sqr(Random(1000) / 1000.0)  ; Distribution uniforme dans le disque
        
        ; ==== Canal Rouge (rayon plus grand) ====
        dist = radiusR * randDist
        sx = x + Cos(angle) * dist
        sy = y + Sin(angle) * dist
        
        If sx >= 0 And sx < lg And sy >= 0 And sy < ht
          index = (Int(sy) * lg + Int(sx)) << 2
          value = PeekL(*param\addr[0] + index)
          r = ((value >> 16) & $FF)
          sumR + r
          countR + 1
        EndIf
        
        ; ==== Canal Vert (rayon de référence) ====
        dist = radiusG * randDist
        sx = x + Cos(angle) * dist
        sy = y + Sin(angle) * dist
        
        If sx >= 0 And sx < lg And sy >= 0 And sy < ht
          index = (Int(sy) * lg + Int(sx)) << 2
          value = PeekL(*param\addr[0] + index)
          g = ((value >> 8) & $FF)
          sumG + g
          countG + 1
        EndIf
        
        ; ==== Canal Bleu (rayon plus petit) ====
        dist = radiusB * randDist
        sx = x + Cos(angle) * dist
        sy = y + Sin(angle) * dist
        
        If sx >= 0 And sx < lg And sy >= 0 And sy < ht
          index = (Int(sy) * lg + Int(sx)) << 2
          value = PeekL(*param\addr[0] + index)
          b = (value & $FF)
          sumB + b
          countB + 1
        EndIf
        
        ; ==== Canal Alpha (pas d'aberration) ====
        dist = radiusG * randDist
        sx = x + Cos(angle) * dist
        sy = y + Sin(angle) * dist
        
        If sx >= 0 And sx < lg And sy >= 0 And sy < ht
          index = (Int(sy) * lg + Int(sx)) << 2
          value = PeekL(*param\addr[0] + index)
          a = ((value >> 24) & $FF)
          sumA + a
          countA + 1
        EndIf
      Next
      
      ; Calcul des moyennes par canal
      If countR > 0 : r = sumR / countR : Else : r = 0 : EndIf
      If countG > 0 : g = sumG / countG : Else : g = 0 : EndIf
      If countB > 0 : b = sumB / countB : Else : b = 0 : EndIf
      If countA > 0 : a = sumA / countA : Else : a = 255 : EndIf
      
      ; Application du vignettage (assombrissement progressif vers les bords)
      vignetteAmount = 1.0 - (distFromCenter * vignetting)
      If vignetteAmount < 0.0 : vignetteAmount = 0.0 : EndIf
      If vignetteAmount > 1.0 : vignetteAmount = 1.0 : EndIf
      
      r = r * vignetteAmount
      g = g * vignetteAmount
      b = b * vignetteAmount
      
      ; Clamp final
      Clamp(a, 0, 255)
      Clamp(r, 0, 255)
      Clamp(g, 0, 255)
      Clamp(b, 0, 255)
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure LensBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Specialized
    *param\name = "LensBlur"
    *param\remarque = "Flou réaliste avec aberrations chromatiques et vignettage"
    *param\info[0] = "Rayon"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 30 : *param\info_data(0, 2) = 10
    *param\info[1] = "Aberration chromatique (%)"
    *param\info_data(1, 0) = 0 : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 30
    *param\info[2] = "Vignettage (%)"
    *param\info_data(2, 0) = 0 : *param\info_data(2, 1) = 100 : *param\info_data(2, 2) = 20
    *param\info[3] = "Échantillons"
    *param\info_data(3, 0) = 4 : *param\info_data(3, 1) = 32 : *param\info_data(3, 2) = 12
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 1, 30)
  Clamp(*param\option[1], 0, 100)
  Clamp(*param\option[2], 0, 100)
  Clamp(*param\option[3], 4, 32)
  
  filter_start(@LensBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 93
; FirstLine = 78
; Folding = -
; EnableXP
; DPIAware