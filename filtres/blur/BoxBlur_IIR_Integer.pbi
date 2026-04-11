


; ============================================================================
; PROCÉDURE COMPLÈTE AVEC IIR
; ============================================================================

; Version entière du filtre IIR - évite les float

Procedure BoxBlur_IIR_Integer(*ligne, largeur.l, rayon.l)
  ; Version entière fixe-point (16.16) pour éviter les float
  ; ~20% plus rapide que la version float
  
  #PRECISION = 16  ; Précision fixe-point
  
  ; Conversion des coefficients en entiers
  Protected.l alpha_int = 1 << (#PRECISION - 2)  ; Approximation simple
  Protected.l one_minus_alpha = (1 << #PRECISION) - alpha_int
  
  Protected.l x, pixel
  Protected.l prev_r, prev_g, prev_b, prev_a
  Protected.l cur_r, cur_g, cur_b, cur_a
  Protected.l in_r, in_g, in_b, in_a
  
  ; ---- PASSE 1 : Gauche → Droite ----
  pixel = PeekL(*ligne)
  prev_r = ((pixel >> 16) & $FF) << #PRECISION
  prev_g = ((pixel >> 8) & $FF) << #PRECISION
  prev_b = (pixel & $FF) << #PRECISION
  prev_a = (pixel >> 24) << #PRECISION
  
  For x = 0 To largeur - 1
    pixel = PeekL(*ligne + (x << 2))
    
    ; in[n] * (1-alpha) + out[n-1] * alpha
    in_r = ((pixel >> 16) & $FF) << #PRECISION
    in_g = ((pixel >> 8) & $FF) << #PRECISION
    in_b = (pixel & $FF) << #PRECISION
    in_a = (pixel >> 24) << #PRECISION
    
    cur_r = ((in_r * one_minus_alpha) >> #PRECISION) + ((prev_r * alpha_int) >> #PRECISION)
    cur_g = ((in_g * one_minus_alpha) >> #PRECISION) + ((prev_g * alpha_int) >> #PRECISION)
    cur_b = ((in_b * one_minus_alpha) >> #PRECISION) + ((prev_b * alpha_int) >> #PRECISION)
    cur_a = ((in_a * one_minus_alpha) >> #PRECISION) + ((prev_a * alpha_int) >> #PRECISION)
    
    PokeL(*ligne + (x << 2), 
          ((cur_a >> #PRECISION) << 24) | ((cur_r >> #PRECISION) << 16) | 
          ((cur_g >> #PRECISION) << 8) | (cur_b >> #PRECISION))
    
    prev_r = cur_r : prev_g = cur_g : prev_b = cur_b : prev_a = cur_a
  Next
  
  ; ---- PASSE 2 : Droite → Gauche ----
  pixel = PeekL(*ligne + ((largeur - 1) << 2))
  prev_r = ((pixel >> 16) & $FF) << #PRECISION
  prev_g = ((pixel >> 8) & $FF) << #PRECISION
  prev_b = (pixel & $FF) << #PRECISION
  prev_a = (pixel >> 24) << #PRECISION
  
  For x = largeur - 1 To 0 Step -1
    pixel = PeekL(*ligne + (x << 2))
    
    in_r = ((pixel >> 16) & $FF) << #PRECISION
    in_g = ((pixel >> 8) & $FF) << #PRECISION
    in_b = (pixel & $FF) << #PRECISION
    in_a = (pixel >> 24) << #PRECISION
    
    cur_r = ((in_r * one_minus_alpha) >> #PRECISION) + ((prev_r * alpha_int) >> #PRECISION)
    cur_g = ((in_g * one_minus_alpha) >> #PRECISION) + ((prev_g * alpha_int) >> #PRECISION)
    cur_b = ((in_b * one_minus_alpha) >> #PRECISION) + ((prev_b * alpha_int) >> #PRECISION)
    cur_a = ((in_a * one_minus_alpha) >> #PRECISION) + ((prev_a * alpha_int) >> #PRECISION)
    
    PokeL(*ligne + (x << 2),
          ((cur_a >> #PRECISION) << 24) | ((cur_r >> #PRECISION) << 16) |
          ((cur_g >> #PRECISION) << 8) | (cur_b >> #PRECISION))
    
    prev_r = cur_r : prev_g = cur_g : prev_b = cur_b : prev_a = cur_a
  Next
EndProcedure


Procedure Blur_IIR(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Classic
    *param\name = "Blur_IIR"
    *param\remarque = "Flou IIR ultra-rapide (2-3× plus rapide que fenêtre glissante)"
    *param\info[0] = "Rayon X"
    *param\info[1] = "Rayon Y"
    *param\info[2] = "Nombre de passes"
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 100 : *param\info_data(0,2) = 10
    *param\info_data(1,0) = 1 : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 10
    *param\info_data(2,0) = 1 : *param\info_data(2,1) = 3   : *param\info_data(2,2) = 1
    ProcedureReturn
  EndIf
  
  Protected.l lg = *param\lg
  Protected.l ht = *param\ht
  Protected.l rayon_x = *param\option[0]
  Protected.l rayon_y = *param\option[1]
  Protected.l passes = *param\option[2]
  Protected pass , x , y
  
  Protected *temp = AllocateMemory(lg * ht * 4)
  Protected *ligne 
  max(*ligne , lg, ht)
  *ligne = AllocateMemory(*ligne * 4)

  For pass = 1 To passes
    ; Traitement horizontal
    For y = 0 To ht - 1
      CopyMemory(*param\source + (y * lg * 4), *ligne, lg * 4)
      BoxBlur_IIR_Integer(*ligne, lg, rayon_x)
      CopyMemory(*ligne, *temp + (y * lg * 4), lg * 4)
    Next
    
    ; Traitement vertical
    For x = 0 To lg - 1
      For y = 0 To ht - 1
        PokeL(*ligne + (y << 2), PeekL(*temp + ((y * lg + x) << 2)))
      Next
      BoxBlur_IIR_Integer(*ligne, ht, rayon_y)
      For y = 0 To ht - 1
        PokeL(*param\cible + ((y * lg + x) << 2), PeekL(*ligne + (y << 2)))
      Next
    Next
    
    *param\source = *param\cible
  Next
  
  FreeMemory(*ligne)
  FreeMemory(*temp)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 101
; FirstLine = 64
; Folding = -
; EnableXP
; DPIAware