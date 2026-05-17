; ----------------------------------------------------------------------------------
; Procédure thread pour le remplacement de teinte (YUV)
; ----------------------------------------------------------------------------------

Procedure Teinte_Simple_YUV_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0]
    Protected *dst = \addr[1]
    Protected angleA.f = Mod(\option[0], 360)
    Protected angleB.f = Mod(\option[1], 360)
    Protected tolerance.f = \option[2]
    Protected mode = \option[3]
    
    Protected angleA_rad.f = #PI * angleA / 180
    Protected angleB_rad.f = #PI * angleB / 180
    Protected cosA.f = Cos(angleA_rad)
    Protected sinA.f = Sin(angleA_rad)
    Protected cosB.f = Cos(angleB_rad)
    Protected sinB.f = Sin(angleB_rad)
    
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected totalPixels = w * h
    
    Protected start = (\thread_pos * totalPixels) / \thread_max
    Protected stop  = ((\thread_pos + 1) * totalPixels) / \thread_max
    
    Protected i, var, a, r, g, b, xpos, ypos
    Protected y.f, u.f, v.f, u2.f, v2.f
    Protected rA, gA, bA, rB, gB, bB
    
    ; Mode affichage : dessiner les carrés de référence (uniquement thread 0)
    If mode And \thread_pos = 0
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
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure ColorPermutationEx(*FilterCtx.FilterParams)
  Restore ColorPermutation_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Teinte_Simple_YUV_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure ColorPermutation(source, cible, mask, target_hue, source_hue, tolerance, show_guides)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = target_hue
    \option[1] = source_hue
    \option[2] = tolerance
    \option[3] = show_guides
  EndWith
  ColorPermutationEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  ColorPermutation_Data:
  Data.s "Color Permutation"
  Data.s "Remplace une teinte par une autre"
  Data.i #FilterType_ColorEffect
  Data.i 0
  
  Data.s "Teinte cible"
  Data.i 0, 360, 0
  
  Data.s "Teinte source"
  Data.i 0, 360, 0
  
  Data.s "Tolérance"
  Data.i 0, 180, 25
  
  Data.s "Afficher guides"
  Data.i 0, 1, 0
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 134
; FirstLine = 120
; Folding = -
; EnableXP
; DPIAware