Procedure Teinte_Simple_YUV_MT(*p.parametre)
  Protected *src = *p\addr[0]
  Protected *dst = *p\addr[1]
  Protected angleA.f = Mod(*p\option[0], 360)
  Protected angleB.f = Mod(*p\option[1], 360)
  Protected tolerance.f = *p\option[2]
  Protected mode = *p\option[3]
  
  Protected angleA_rad.f = #PI * angleA / 180
  Protected angleB_rad.f = #PI * angleB / 180
  Protected cosA.f = Cos(angleA_rad)
  Protected sinA.f = Sin(angleA_rad)
  Protected cosB.f = Cos(angleB_rad)
  Protected sinB.f = Sin(angleB_rad)
  
  Protected w = *p\lg
  Protected h = *p\ht
  Protected start = (*p\thread_pos * w * h) / *p\thread_max
  Protected stop  = ((*p\thread_pos + 1) * w * h) / *p\thread_max
  
  Protected i, var, a, r, g, b, xpos, ypos
  Protected y.f, u.f, v.f, u2.f, v2.f
  Protected rA, gA, bA, rB, gB, bB
  
  ; Mode affichage : dessiner les carrés de référence (uniquement thread 0)
  If mode And *p\thread_pos = 0
    ; Couleur de référence (vert)
    r = 0 : g = 255 : b = 0
    
    ; RGB → YUV
    y =  0.299 * r + 0.587 * g + 0.114 * b
    u = -0.14713 * r - 0.28886 * g + 0.436 * b
    v =  0.615 * r - 0.51499 * g - 0.10001 * b
    
    ; Teinte A
    u2 = u * cosA - v * sinA
    v2 = u * sinA + v * cosA
    rA = y + 1.13983 * v2
    gA = y - 0.39465 * u2 - 0.58060 * v2
    bA = y + 2.03211 * u2
    Clamp_rgb(rA, gA, bA)
    
    ; Teinte B
    u2 = u * cosB - v * sinB
    v2 = u * sinB + v * cosB
    rB = y + 1.13983 * v2
    gB = y - 0.39465 * u2 - 0.58060 * v2
    bB = y + 2.03211 * u2
    Clamp_rgb(rB, gB, bB)
    
    ; Dessiner carrés 32x32 pixels
    Protected squareSize = 32
    For yPos = 0 To squareSize - 1
      For xPos = 0 To squareSize - 1
        ; Carré teinte A (coin haut-gauche)
        PokeL(*dst + ((yPos * w) + xPos) * 4, $FF000000 | (rA << 16) | (gA << 8) | bA)
        ; Carré teinte B (coin haut-droit, avec espacement de 1 pixel)
        PokeL(*dst + ((yPos * w) + (squareSize + xPos + 1)) * 4, $FF000000 | (rB << 16) | (gB << 8) | bB)
      Next
    Next
  EndIf
  
  ; Application du filtre de remplacement de teinte
  Protected angle_src_rad.f = angleB_rad  ; Teinte à remplacer
  Protected angle_dst_rad.f = angleA_rad  ; Teinte cible
  Protected tol_rad.f = #PI * tolerance / 180
  
  For i = start To stop - 1
    var = PeekL(*src + i * 4)
    getargb(var, a, r, g, b)
    
    ; RGB → YUV
    y =  0.299 * r + 0.587 * g + 0.114 * b
    u = -0.14713 * r - 0.28886 * g + 0.436 * b
    v =  0.615 * r - 0.51499 * g - 0.10001 * b
    
    ; Angle UV (teinte réelle du pixel)
    Protected angle_pixel.f = ATan2(v, u)
    
    ; Calcul de l'écart entre la teinte du pixel et la teinte à remplacer
    Protected angle_diff.f = angle_pixel - angle_src_rad
    
    ; Normalisation de l'angle dans [-π, π]
    While angle_diff > #PI : angle_diff - 2 * #PI : Wend
    While angle_diff < -#PI : angle_diff + 2 * #PI : Wend
    
    ; Si le pixel est dans la zone de tolérance
    If Abs(angle_diff) <= tol_rad
      ; Rotation UV pour atteindre la teinte cible
      Protected angle_delta.f = angle_dst_rad - angle_pixel
      Protected cosD.f = Cos(angle_delta)
      Protected sinD.f = Sin(angle_delta)
      
      u2 = u * cosD - v * sinD
      v2 = u * sinD + v * cosD
      
      ; YUV → RGB
      r = y + 1.13983 * v2
      g = y - 0.39465 * u2 - 0.58060 * v2
      b = y + 2.03211 * u2
      Clamp_rgb(r, g, b)
    EndIf
    
    PokeL(*dst + i * 4, (a << 24) | (r << 16) | (g << 8) | b)
  Next
EndProcedure

Procedure ColorPermutation(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Color Permutation"
    param\remarque = "Remplace une teinte par une autre"
    param\info[0] = "Teinte cible"
    param\info[1] = "Teinte source"
    param\info[2] = "Tolérance"
    param\info[3] = "Afficher guides"
    param\info[4] = "Masque"
    param\info_data(0,0) = 0   : param\info_data(0,1) = 360 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0   : param\info_data(1,1) = 360 : param\info_data(1,2) = 0
    param\info_data(2,0) = 0   : param\info_data(2,1) = 180 : param\info_data(2,2) = 25
    param\info_data(3,0) = 0   : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0   : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Teinte_Simple_YUV_MT(), 2, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 126
; FirstLine = 57
; Folding = -
; EnableXP
; DPIAware