Procedure SpinBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected i, j, k
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected samples = \option[0]      ; Nombre d'échantillons
    Protected angle_max.f = \option[1]  ; Angle maximum en degrés
    Protected cx.f, cy.f                ; Centre de rotation
    Protected falloff = \option[4]      ; Atténuation depuis le centre
    
    Protected a.l, r.l, g.l, b.l
    Protected sumA.f, sumR.f, sumG.f, sumB.f ; Passage en float pour la précision des poids
    Protected count
    Protected dx.f, dy.f, dist.f, angle.f, angle_step.f
    Protected nx.f, ny.f, rx.f, ry.f
    Protected cos_a.f, sin_a.f
    Protected px, py
    Protected weight.f, total_weight.f
    
    macro_calul_tread(ht)
    
    ; Calcul du centre de rotation
    If \option[2] = -1  ; Centre automatique
      cx = lg / 2.0
      cy = ht / 2.0
    Else
      cx = \option[2]  ; Centre X personnalisé
      cy = \option[3]  ; Centre Y personnalisé
    EndIf
    
    ; Conversion angle en radians
    angle_max = angle_max * #PI / 180.0
    
    ; Traitement de chaque pixel
    For j = thread_start To thread_stop - 1
      For i = 0 To lg - 1
        
        ; Calcul de la distance au centre
        dx = i - cx
        dy = j - cy
        dist = Sqr(dx * dx + dy * dy)
        
        ; Application de l'atténuation basée sur la distance
        If falloff > 0
          weight = 1.0 - (dist / (Sqr(lg * lg + ht * ht) / 2.0)) * falloff / 100.0
          If weight < 0.1 : weight = 0.1 : EndIf
        Else
          weight = 1.0
        EndIf
        
        ; Angle effectif basé sur la distance
        Protected effective_angle.f = angle_max * weight
        angle_step = effective_angle / (samples - 1)
        
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
        count = 0
        total_weight = 0
        
        ; Échantillonnage le long de l'arc de rotation
        For k = 0 To samples - 1
          angle = -effective_angle / 2.0 + k * angle_step
          
          cos_a = Cos(angle)
          sin_a = Sin(angle)
          
          rx = dx * cos_a - dy * sin_a
          ry = dx * sin_a + dy * cos_a
          
          nx = cx + rx
          ny = cy + ry
          
          px = Int(nx + 0.5)
          py = Int(ny + 0.5)
          
          If px >= 0 And px < lg And py >= 0 And py < ht
            *srcPixel = \addr[0] + ((py * lg + px) << 2)
            Protected pix.l = *srcPixel\l
            a = (pix >> 24) & $FF
            r = (pix >> 16) & $FF
            g = (pix >> 8) & $FF
            b = pix & $FF
            
            ; Pondération gaussienne
            Protected sample_weight.f = 1.0
            If \option[5] = 1
              Protected t.f = (k - samples / 2.0) / (samples / 2.0)
              sample_weight = Exp(-t * t * 2.0)
            EndIf
            
            sumA + a * sample_weight
            sumR + r * sample_weight
            sumG + g * sample_weight
            sumB + b * sample_weight
            total_weight + sample_weight
            count + 1
          EndIf
        Next
        
        If count > 0 And total_weight > 0
          a = sumA / total_weight
          r = sumR / total_weight
          g = sumG / total_weight
          b = sumB / total_weight
        Else
          *srcPixel = \addr[0] + ((j * lg + i) << 2)
          pix.l = *srcPixel\l
          a = (pix >> 24) & $FF : r = (pix >> 16) & $FF : g = (pix >> 8) & $FF : b = pix & $FF
        EndIf
        
        *dstPixel = \addr[1] + ((j * lg + i) << 2)
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure SpinBlurEx(*FilterCtx.FilterParams)
  Restore SpinBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@SpinBlur_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure SpinBlur(source, cible, mask, samples, angle, cx, cy, attenuation, ponderation)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = samples
    \option[1] = angle
    \option[2] = cx
    \option[3] = cy
    \option[4] = attenuation
    \option[5] = ponderation
  EndWith
  SpinBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  SpinBlur_data:
  Data.s "SpinBlur"
  Data.s "Flou de rotation circulaire"
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Qualité (Samples)"
  Data.i 5, 100, 20
  Data.s "Angle (°)"
  Data.i 1, 360, 45
  Data.s "Centre X (-1=auto)"
  Data.i -1, 9999, -1
  Data.s "Centre Y (-1=auto)"
  Data.i -1, 9999, -1
  Data.s "Atténuation (%)"
  Data.i 0, 100, 100
  Data.s "Pondération (0:Unif, 1:Gauss)"
  Data.i 0, 1, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 128
; FirstLine = 112
; Folding = -
; EnableXP
; DPIAware