; ===== Anisotropic Blur orienté  =====
Procedure AnisotropicBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]   ; longueur du blur (axe principal)
    Protected angle.f = \option[1] * #PI / 180.0
    
    ; Calcul des pas de déplacement
    Protected dx.f = Cos(angle)
    Protected dy.f = Sin(angle)
    
    Protected x, y, k, xi, yi
    Protected r.f, g.f, b.f
    Protected r1, g1, b1
    Protected *srcPix.Pixel32, *dstPix.Pixel32
    Protected steps = radius * 2 + 1
    Protected coeff.f = 1.0 / steps
    Protected lg_minus_1 = lg - 1
    Protected ht_minus_1 = ht - 1
    
    ; Variables pour l'accumulation DDA (Évite Round() et les multiplications)
    Protected curX.f, curY.f
    Protected y_offset, dst_pos
    Protected *src_base = \addr[0]
    Protected *dst_base = \addr[1]
    
    macro_calul_tread(ht)
    
    ; Pré-calculer le décalage de départ (-radius * vecteur)
    Protected start_dx.f = dx * -radius
    Protected start_dy.f = dy * -radius
    
    For y = thread_start To thread_stop - 1
      y_offset = y * lg
      
      For x = 0 To lg - 1
        r = 0.0 : g = 0.0 : b = 0.0
        
        ; Initialisation du point de départ du rayon pour CE pixel
        curX = x + start_dx
        curY = y + start_dy
        
        For k = 0 To steps - 1
          ; Conversion rapide flottant -> entier (Tris / Clamping)
          xi = Int(curX + 0.5) ; Équivalent ultra-rapide de Round au plus proche pour valeurs positives
          yi = Int(curY + 0.5)
          
          ; Clamping direct en une ligne
          If xi < 0 : xi = 0 : ElseIf xi > lg_minus_1 : xi = lg_minus_1 : EndIf
          If yi < 0 : yi = 0 : ElseIf yi > ht_minus_1 : yi = ht_minus_1 : EndIf
          
          ; Accès mémoire direct sans multiplication par 4 à chaque itération
          *srcPix = *src_base + ((yi * lg + xi) << 2)
          getrgb(*srcPix\l, r1, g1, b1)
          
          r + r1
          g + g1
          b + b1
          
          ; Avancer le long du rayon (simple addition ! Plus de multiplications)
          curX + dx
          curY + dy
        Next
        
        ; Normalisation
        r * coeff
        g * coeff
        b * coeff
        
        ; Clamping rapide des sorties (Inlined)
        clamp_rgb(r , g , b)
        
        ; Écriture linéaire du résultat
        dst_pos = (y_offset + x) << 2
        *dstPix = *dst_base + dst_pos
        *dstPix\l = (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure AnisotropicBlurEx(*FilterCtx.FilterParams)
  Restore AnisotropicBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@AnisotropicBlur_sp())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

; ===== Appel simplifie =====
Procedure AnisotropicBlur(source, cible, mask, radius, angle)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = angle
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
; CursorPosition = 86
; FirstLine = 60
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger