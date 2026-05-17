; ===== Anisotropic Blur orienté (multithread) =====
Procedure AnisotropicBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]   ; longueur du blur (axe principal)
    Protected angle.f = \option[1] * #PI / 180.0
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
          *srcPix = \addr[0] + pos
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
        *dstPix = \addr[1] + pos
        *dstPix\l = (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure AnisotropicBlurEx(*FilterCtx.FilterParams)
  Restore AnisotropicBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@AnisotropicBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

; ===== Appel simplifie =====
Procedure AnisotropicBlur(source, cible, mask, radius, angle, mask_type)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius : \option[1] = angle : \option[2] = mask_type
  EndWith
  AnisotropicBlurEx(FilterCtx)
EndProcedure

DataSection
  AnisotropicBlur_data:
  Data.s "AnisotropicBlur"
  Data.s "Gaussian anisotrope orienté (ellipse pivotée)"
  Data.i #FilterType_Blur, #Blur_Adaptive
  Data.s "Rayon"
  Data.i 1, 50, 5    ; Rayon
  Data.s "Angle"
  Data.i 0, 180, 5   ; Angle
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 98
; FirstLine = 47
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger