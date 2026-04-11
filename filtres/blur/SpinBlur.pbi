Procedure SpinBlur_MT(*param.parametre)
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected i, j, k
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected samples = *param\option[0]      ; Nombre d'échantillons
  Protected angle_max.f = *param\option[1]  ; Angle maximum en degrés
  Protected cx.f, cy.f                       ; Centre de rotation
  Protected falloff = *param\option[4]      ; Atténuation depuis le centre
  
  Protected a.l, r.l, g.l, b.l
  Protected sumA.l, sumR.l, sumG.l, sumB.l
  Protected count
  Protected dx.f, dy.f, dist.f, angle.f, angle_step.f
  Protected nx.f, ny.f, rx.f, ry.f
  Protected cos_a.f, sin_a.f
  Protected px, py
  Protected weight.f, total_weight.f
  
  macro_calul_tread(ht)
  
  ; Calcul du centre de rotation
  If *param\option[2] = -1  ; Centre automatique
    cx = lg / 2.0
    cy = ht / 2.0
  Else
    cx = *param\option[2]  ; Centre X personnalisé
    cy = *param\option[3]  ; Centre Y personnalisé
  EndIf
  
  ; Conversion angle en radians et calcul du pas
  angle_max = angle_max * #PI / 180.0
  angle_step = angle_max / (samples - 1)
  
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
        
        ; Calcul de la rotation
        cos_a = Cos(angle)
        sin_a = Sin(angle)
        
        ; Application de la rotation autour du centre
        rx = dx * cos_a - dy * sin_a
        ry = dx * sin_a + dy * cos_a
        
        ; Position finale
        nx = cx + rx
        ny = cy + ry
        
        px = Int(nx + 0.5)
        py = Int(ny + 0.5)
        
        ; Vérification des limites
        If px >= 0 And px < lg And py >= 0 And py < ht
          *srcPixel = *param\addr[0] + ((py * lg + px) << 2)
          getargb(*srcPixel\l, a, r, g, b)
          
          ; Pondération gaussienne (plus de poids au centre)
          Protected sample_weight.f = 1.0
          If *param\option[5] = 1  ; Pondération gaussienne active
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
      
      ; Calcul de la moyenne pondérée
      If count > 0 And total_weight > 0
        a = sumA / total_weight
        r = sumR / total_weight
        g = sumG / total_weight
        b = sumB / total_weight
      Else
        *srcPixel = *param\addr[0] + ((j * lg + i) << 2)
        getargb(*srcPixel\l, a, r, g, b)
      EndIf
      
      ; Écriture du résultat
      *dstPixel = *param\addr[1] + ((j * lg + i) << 2)
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    Next
  Next
EndProcedure

Procedure SpinBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Directional
    *param\name = "Spin Blur"
    *param\remarque = "Flou de rotation circulaire"
    *param\info[0] = "Samples"        ; Nombre d'échantillons (qualité)
    *param\info[1] = "Angle"          ; Angle de rotation en degrés
    *param\info[2] = "Centre X"       ; Position X du centre (-1 = auto)
    *param\info[3] = "Centre Y"       ; Position Y du centre (-1 = auto)
    *param\info[4] = "Atténuation"    ; Atténuation vers le centre (0-100%)
    *param\info[5] = "Pondération"    ; Pondération gaussienne (0=uniforme, 1=gaussienne)
    
    *param\info_data(0, 0) = 5   : *param\info_data(0, 1) = 100  : *param\info_data(0, 2) = 20
    *param\info_data(1, 0) = 1   : *param\info_data(1, 1) = 360  : *param\info_data(1, 2) = 45
    *param\info_data(2, 0) = -1  : *param\info_data(2, 1) = 9999 : *param\info_data(2, 2) = -1
    *param\info_data(3, 0) = -1  : *param\info_data(3, 1) = 9999 : *param\info_data(3, 2) = -1
    *param\info_data(4, 0) = 0   : *param\info_data(4, 1) = 100  : *param\info_data(4, 2) = 100
    *param\info_data(5, 0) = 0   : *param\info_data(5, 1) = 1    : *param\info_data(5, 2) = 1
    ProcedureReturn
  EndIf
  
  ; Validation des paramètres
  clamp(*param\option[0], 5, 100)     ; Samples
  clamp(*param\option[1], 1, 360)     ; Angle
  ; option[2] et [3] : Centre X et Y (peuvent être -1 pour auto)
  clamp(*param\option[4], 0, 100)     ; Atténuation
  clamp(*param\option[5], 0, 1)       ; Pondération
  
  ; Préparation des buffers
  Filter_BufferPrepare(*param.parametre)
  
  ; Application du filtre multi-thread
  MultiThread_MT(@SpinBlur_MT(), 2)
  
  ; Finalisation
  macro_Filter_BufferFinalize(4)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 121
; FirstLine = 86
; Folding = -
; EnableXP
; DPIAware