Procedure ZoomBlur_sp(*param.parametre)
  Protected lg = *param\lg, ht = *param\ht
  Protected strength.f = *param\option[0] / 100.0  ; Force du zoom (0-100)
  Protected samples = *param\option[1]              ; Nombre d'échantillons
  Protected centerX.f = *param\option[2] / 100.0    ; Position X du centre (0-100)
  Protected centerY.f = *param\option[3] / 100.0    ; Position Y du centre (0-100)
  
  If samples < 2 : samples = 2 : EndIf
  If samples > 50 : samples = 50 : EndIf
  
  ; Calcul du centre en pixels
  Protected cx.f = lg * centerX
  Protected cy.f = ht * centerY
  
  Protected x, y, i
  Protected sumR.f, sumG.f, sumB.f, sumA.f
  Protected sx, sy, index, value
  Protected r, g, b, a
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0
      
      ; Vecteur du centre vers le pixel
      Protected dx.f = x - cx
      Protected dy.f = y - cy
      
      ; Échantillonnage le long du rayon
      For i = 0 To samples - 1
        Protected t.f = i / (samples - 1.0)  ; 0.0 à 1.0
        Protected scale.f = 1.0 - t * strength
        
        ; Position échantillonnée
        sx = cx + dx * scale
        sy = cy + dy * scale
        
        ; Clamp
        If sx < 0 : sx = 0 : EndIf
        If sx >= lg : sx = lg - 1 : EndIf
        If sy < 0 : sy = 0 : EndIf
        If sy >= ht : sy = ht - 1 : EndIf
        
        index = (sy * lg + sx) << 2
        value = PeekL(*param\addr[0] + index)
        
        a = ((value >> 24) & $FF)
        r =  ((value >> 16) & $FF)
        g =  ((value >> 8) & $FF)
        b =  (value & $FF)
        sumA + a
        sumR + r
        sumG + g
        sumB + b
      Next
      
      ; Moyenne
      a = sumA / samples
      r = sumR / samples
      g = sumG / samples
      b = sumB / samples
      
      Clamp(a, 0, 255)
      Clamp(r, 0, 255)
      Clamp(g, 0, 255)
      Clamp(b, 0, 255)
      
      PokeL(*param\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure ZoomBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Directional
    *param\name = "ZoomBlur"
    *param\remarque = "Flou de zoom radial depuis un point central"
    *param\info[0] = "Force (%)"
    *param\info_data(0, 0) = 0 : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 20
    *param\info[1] = "Échantillons"
    *param\info_data(1, 0) = 2 : *param\info_data(1, 1) = 50 : *param\info_data(1, 2) = 10
    *param\info[2] = "Centre X (%)"
    *param\info_data(2, 0) = 0 : *param\info_data(2, 1) = 100 : *param\info_data(2, 2) = 50
    *param\info[3] = "Centre Y (%)"
    *param\info_data(3, 0) = 0 : *param\info_data(3, 1) = 100 : *param\info_data(3, 2) = 50
    ProcedureReturn
  EndIf
  
  Clamp(*param\option[0], 0, 100)
  Clamp(*param\option[1], 2, 50)
  Clamp(*param\option[2], 0, 100)
  Clamp(*param\option[3], 0, 100)
  
  filter_start(@ZoomBlur_sp(), 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 54
; Folding = -
; EnableXP
; DPIAware