; ===== Anisotropic Blur orienté (multithread) =====
Procedure AnisotropicBlur_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]   ; longueur du blur (axe principal)
  Protected angle.f = *param\option[1] * #PI / 180.0
  Protected dx.f = Cos(angle)
  Protected dy.f = Sin(angle)
  Protected x, y, k, xi, yi, pos
  Protected r.f, g.f, b.f
  Protected r1, g1, b1
  Protected *srcPix.Pixel32, *dstPix.Pixel32
  Protected steps = radius * 2 + 1
  Protected coeff.f = 1.0 / steps
  Protected lg_minus_1 = lg - 1
  Protected ht_minus_1 = ht - 1
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To lg - 1
      r = 0.0 : g = 0.0 : b = 0.0
      
      For k = -radius To radius
        ; Calcul des coordonnées avec clamping optimisé
        xi = Round(x + dx * k, #PB_Round_Nearest)
        yi = Round(y + dy * k, #PB_Round_Nearest)
        
        ; Clamping optimisé
        If xi < 0
          xi = 0
        ElseIf xi > lg_minus_1
          xi = lg_minus_1
        EndIf
        
        If yi < 0
          yi = 0
        ElseIf yi > ht_minus_1
          yi = ht_minus_1
        EndIf
        
        ; Accès mémoire optimisé
        pos = (yi * lg + xi) << 2
        *srcPix = *param\addr[0] + pos
        getrgb(*srcPix\l, r1, g1, b1)
        
        r + r1
        g + g1
        b + b1
      Next
      
      ; Normalisation
      r * coeff
      g * coeff
      b * coeff
      
      clamp_rgb(r, g, b)
      
      ; Écriture du résultat
      pos = (y * lg + x) << 2
      *dstPix = *param\addr[1] + pos
      *dstPix\l = (Int(r) << 16) | (Int(g) << 8) | Int(b)
    Next
  Next
EndProcedure

; ===== Procédure principale =====
Procedure AnisotropicBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Adaptive
    *param\name = "AnisotropicBlur"
    *param\remarque = "Gaussian anisotrope orienté (ellipse pivotée)"
    *param\info[0] = "Rayon"
    *param\info[1] = "Angle"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 1 : *param\info_data(0, 1) = 50 : *param\info_data(0, 2) = 5
    *param\info_data(1, 0) = 0 : *param\info_data(1, 1) = 180 : *param\info_data(1, 2) = 5
    *param\info_data(2, 0) = 0 : *param\info_data(2, 1) = 2 : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  
  Filter_BufferPrepare(*param)
  MultiThread_MT(@AnisotropicBlur_MT())
  macro_Filter_BufferFinalize(2)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 85
; FirstLine = 16
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger