; ---------------------------------------------------
; FrostedGlassBlur - Véritable effet verre dépoli
; Combine déplacement aléatoire + moyennage local
; ---------------------------------------------------

; --- Hash rapide pseudo-aléatoire
Macro FGB_random_offset(x, y, radius, seed, dx, dy)
  n = (x * 73856093) ! (y * 19349663) ! (seed * 83492791)
  n = n ! (n >> 13)
  n = n * 1274126177
  
  hi = (n >> 16) & $FFFF
  lo = n & $FFFF
  
  dx = hi - Int(hi / modv) * modv - radius
  dy = lo - Int(lo / modv) * modv - radius
EndMacro


; --- Thread worker
Procedure FrostedGlassBlur_MT(*param.parametre)
  Protected w = *param\lg
  Protected h = *param\ht
  Protected *src32.Pixel32
  
  Protected radius = *param\option[0]
  Protected seed   = *param\option[1]
  Protected blurRadius = *param\option[2]  ; Rayon de flou additionnel
  
  ; Validation
  If radius < 0 : radius = 0 : EndIf
  If radius > 50 : radius = 50 : EndIf
  If blurRadius < 1 : blurRadius = 1 : EndIf
  If blurRadius > 5 : blurRadius = 5 : EndIf
  
  Protected modv = 2 * radius + 1
  Protected w_minus_1 = w - 1
  Protected h_minus_1 = h - 1
  
  macro_calul_tread(h)
  
  Protected x, y, pos
  Protected n, hi, lo, dx, dy, cx, cy
  Protected bx, by, sx, sy
  Protected sumA, sumR, sumG, sumB, count
  Protected a1, r1, g1, b1
  
  For y = thread_start To thread_stop - 1
    For x = 0 To w - 1
      
      ; 1. Décalage aléatoire (effet distorsion du verre)
      If modv > 0
        FGB_random_offset(x, y, radius, seed, dx, dy)
        cx = x + dx
        cy = y + dy
        
        ; Clamping du centre
        If cx < 0
          cx = 0
        ElseIf cx > w_minus_1
          cx = w_minus_1
        EndIf
        
        If cy < 0
          cy = 0
        ElseIf cy > h_minus_1
          cy = h_minus_1
        EndIf
      Else
        cx = x
        cy = y
      EndIf
      
      ; 2. Moyennage autour du point décalé (effet givré/flou)
      sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0 : count = 0
      
      For by = -blurRadius To blurRadius
        sy = cy + by
        If sy < 0 : sy = 0 : ElseIf sy > h_minus_1 : sy = h_minus_1 : EndIf
        
        For bx = -blurRadius To blurRadius
          sx = cx + bx
          If sx < 0 : sx = 0 : ElseIf sx > w_minus_1 : sx = w_minus_1 : EndIf
          
          *src32 = *param\addr[0] + ((sy * w + sx) << 2)
          a1 = (*src32\l >> 24) & $FF
          r1 = (*src32\l >> 16) & $FF
          g1 = (*src32\l >> 8)  & $FF
          b1 =  *src32\l & $FF
          
          sumA + a1
          sumR + r1
          sumG + g1
          sumB + b1
          count + 1
        Next
      Next
      
      ; Moyenne
      If count > 0
        a1 = sumA / count
        r1 = sumR / count
        g1 = sumG / count
        b1 = sumB / count
      Else
        a1 = 255 : r1 = 0 : g1 = 0 : b1 = 0
      EndIf
      
      ; Écriture
      pos = (y * w + x) << 2
      *src32 = *param\addr[1] + pos
      *src32\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
    Next
  Next
EndProcedure


; --- Entrée principale
Procedure FrostedGlassBlur(*param.parametre)
  If *param\info_active
    *param\typ      = #FilterType_Blur
    *param\subtype  = #Blur_Stochastic
    *param\name     = "Frosted Glass Blur"
    *param\remarque = "Véritable effet verre dépoli : distorsion + flou local"
    *param\info[0]  = "Distorsion (px)"
    *param\info[1]  = "Seed"
    *param\info[2]  = "Rayon flou"
    *param\info[3]  = "Masque"
    *param\info_data(0, 0) = 0  : *param\info_data(0, 1) = 50   : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 0  : *param\info_data(1, 1) = 9999 : *param\info_data(1, 2) = 1234
    *param\info_data(2, 0) = 0  : *param\info_data(2, 1) = 5    : *param\info_data(2, 2) = 2
    *param\info_data(3, 0) = 1  : *param\info_data(3, 1) = 2    : *param\info_data(3, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Validation
  If *param\option[0] < 0 : *param\option[0] = 0 : EndIf
  If *param\option[0] > 50 : *param\option[0] = 50 : EndIf
  If *param\option[2] < 1 : *param\option[2] = 1 : EndIf
  If *param\option[2] > 5 : *param\option[2] = 5 : EndIf
  
  If Filter_BufferPrepare(*param) <> 0
    MultiThread_MT(@FrostedGlassBlur_MT())
    macro_Filter_BufferFinalize(3)
  EndIf
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 76
; FirstLine = 58
; Folding = -
; EnableXP
; DPIAware