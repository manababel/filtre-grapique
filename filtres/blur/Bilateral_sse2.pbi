


Macro Bilateral_DomainTransform1D_sp0_sse2(op)
  ; --- 1. clamp(diff_d , 0 , 255) ---
  !movss xmm0, [p.v_diff_d]
  !pxor xmm1, xmm1                
  !maxss xmm0, xmm1               ; Borne basse à 0.0
  !minss xmm0, [p.v_float_255]    ; Borne haute à 255.0
  
  ; --- 2. idx = Int(diff_d) et frac = diff_d - idx ---
  !cvttss2si eax, xmm0            ; eax = idx
  !cvtsi2ss xmm1, eax             
  !movaps xmm2, xmm0
  !subss xmm2, xmm1               ; xmm2 = frac
  
  ; --- 3. idx_next = idx + Bool(idx < 255) ---
  !mov ecx, eax                   
  !add ecx, 1                     ; ecx = idx + 1
  !cmp eax, 255
  !mov r11d, 255
  !cmovge ecx, r11d               ; Si idx >= 255, ecx = 255
  
  ; --- 4. Lecture des tables : a0 et a1 ---
  !mov r11, [p.p_expLUT]          ; r11 = Adresse de la LUT
  !movss xmm3, [r11 + rax * 4]    ; xmm3 = a0
  !movss xmm4, [r11 + rcx * 4]    ; xmm4 = a1
  
  ; --- 5. alpha = a0 + frac * (a1 - a0) ---
  !subss xmm4, xmm3               ; xmm4 = (a1 - a0)
  !mulss xmm4, xmm2               ; xmm4 = frac * (a1 - a0)
  !addss xmm3, xmm4               ; xmm3 = alpha
  !shufps xmm3, xmm3, $00         ; xmm3 = [ alpha | alpha | alpha | alpha ]
  
  ; --- 6. Calcul des offsets mémoire pour (i) et (i op 1) ---
  !mov rax, [p.v_i]
  !mov rcx, rax
  !op rcx, 1                      ; rcx = i op 1
  !shl rax, 4                     ; rax = i * 16 octets
  !shl rcx, 4                     ; rcx = (i op 1) * 16 octets
  
  ; --- 7. Chargement des structures (a,r,g,b) depuis la mémoire ---
  !mov r11, [p.p_datap]           
  !movups xmm0, [r11 + rax]       ; xmm0 = [ R0 | G0 | B0 | A0 ] (vu de gauche à droite)
  !movups xmm1, [r11 + rcx]       ; xmm1 = [ R1 | G1 | B1 | A1 ]
  
  ; --- 8. Inversion pour remettre dans l'ordre natif [ A | B | G | R ] avant calcul ---
  !shufps xmm0, xmm0, $1B         
  !shufps xmm1, xmm1, $1B         
  
  ; --- 9. Interpolation linéaire ---
  ; Data_argb(i) + alpha * (Data_argb(i op 1) - Data_argb(i))
  !subps xmm1, xmm0               ; xmm1 = Data_argb(i op 1) - Data_argb(i)
  !mulps xmm1, xmm3               ; xmm1 = alpha * (...)
  !addps xmm0, xmm1               ; xmm0 = résultat final au format natif [ A | B | G | R ]
  
  ; --- 10. Ré-inversion au format de la structure et Sauvegarde ---
  !shufps xmm0, xmm0, $1B         ; xmm0 = [ R | G | B | A ] pour coller à a,r,g,b
  !movups [r11 + rax], xmm0        
EndMacro


Macro Bilateral_DomainTransform1D_sp1_sse2()
  p1 = *source\l[pos1]
  p2 = *source\l[pos2]
  
  ; --- 1. Dépaquètement de P1 (Pixel 1) ---
  !movd xmm1, [p.v_p1]            
  !pxor xmm0, xmm0                
  !punpcklbw xmm1, xmm0           
  !punpcklwd xmm1, xmm0           ; xmm1 = [ A | B | G | R ] (de gauche à droite)
  !cvtdq2ps xmm1, xmm1
  
  ; --- 2. Inversion de l'ordre pour coller à la structure a, r, g, b ---
  !movaps xmm4, xmm1
  !shufps xmm4, xmm4, $1B         ; Inversion complète -> xmm4 = [ R | G | B | A ]
  
  ; --- 3. Stockage dans la structure (MOVUPS sécurisé) ---
  !mov rax, [p.v_i]
  !shl rax, 4                     ; i * 16 octets
  !mov rcx, [p.p_datap]   
  !movups [rcx + rax], xmm4       ; Écrit dans l'ordre exact : a, r, g, b

  ; --- 4. Dépaquètement de P2 (Pixel 2) ---
  !movd xmm2, [p.v_p2]            
  !punpcklbw xmm2, xmm0           
  !punpcklwd xmm2, xmm0           ; xmm2 = [ A | B | G | R ]
  !cvtdq2ps xmm2, xmm2
  
  ; --- 5. Calcul de la distance au carré (sur les registres natifs xmm1 et xmm2) ---
  !subps xmm2, xmm1               ; xmm2 = [ da | db | dg | dr ]
  !mulps xmm2, xmm2               ; xmm2 = [ da² | db² | dg² | dr² ]
  
  ; --- 6. Application des coefficients de luminance ---
  ; Comme on travaille sur les registres natifs [ da² | db² | dg² | dr² ]
  ; l'ordre mémoire du tableau de coefficients doit être : R, G, B, A
  !mov rcx, [p.v_coeff_lum]
  !movups xmm3, [rcx]              
  !mulps xmm2, xmm3                
  
  ; --- 7. Somme horizontale SSE2 ---
  !movaps xmm3, xmm2
  !shufps xmm3, xmm3, $4E         
  !addps xmm2, xmm3               
  !movaps xmm3, xmm2
  !shufps xmm3, xmm3, $11
  !addps xmm2, xmm3               ; xmm2 (canal bas) = distance finale au carré
  
  ; --- 8. Clamping & Stockage dc(i) ---
  !minss xmm2, [p.v_float_255]    
  !mov rax, [p.v_i]
  !mov rcx, [p.v_dcp]
  !movss [rcx + rax * 4], xmm2     
EndMacro

Macro Bilateral_DomainTransform1D_Write_Pixel()
  !mov rax, [p.v_i]
  !shl rax, 4                
  !mov rcx, [p.p_datap]   
  !movups xmm0, [rcx + rax] ; xmm0 = [ R | G | B | A ] (format structure)
  ; --- 1. Remise dans l'ordre natif pour l'encodage pixel ---
  !shufps xmm0, xmm0, $1B   ; xmm0 = [ A | B | G | R ]
  ; --- 2. Conversion Flottants -> Entiers 32-bit ---
  !cvttps2dq xmm0, xmm0     ; Convertit les 4 floats en 4 entiers 32-bit
  ; --- 3. Paquetage 32-bit -> 16-bit -> 8-bit ---
  !packssdw xmm0, xmm0      ; Compacte les 4 entiers 32-bit en 4 mots 16-bit
  !packuswb xmm0, xmm0      ; Compacte les 4 mots 16-bit en 4 octets 8-bit
  ; À ce stade, le canal bas de xmm0 contient ton pixel encodé en 32-bit (0xAARRGGBB)
  ; --- 4. Calcul de l'adresse cible et stockage du pixel ---
  ;!mov eax,[p.v_i]
  ;!imul eax,[p.v_lg]
  !mov eax,[p.v_pos1]
  !mov rcx, [p.p_cible]     ; Adresse de base de *cible
  !movd [rcx + rax * 4], xmm0 ; Écrit directement le pixel 32-bit (4 octets)
EndMacro

; --- Procédures MT ---

Procedure Bilateral_DomainTransform1D_X_sse2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.pixelarray = \addr[0]
    Protected *cible.pixelarray  = \addr[1]
    Protected *expLUT = *FilterCtx\addr[2]
    Protected lg = \image_lg[0]
    Protected Dim domain.f(lg)
    Protected Dim dc.f(lg)
    Protected i.i, idx.i
    Protected diff_d.f, alpha.f, frac.f, a0.f, a1.f
    Protected.l pixel0, r0, g0, b0, r1, g1, b1
    Protected y , pos1 , pos2
    Protected lengthMinus1 = lg - 1
    Protected lengthMinus2 = lg - 2
    Protected sigma_color_factor.f = \option[4]
    Protected.l dr , dg , db
    
    Protected dcp = @dc()
    Protected p1 , p2
    
    Protected Dim coeff.f(4)
    coeff(0) = 0.30  ; R (Canal bas)
    coeff(1) = 0.59  ; G
    coeff(2) = 0.11  ; B
    coeff(3) = 0.0   ; A (Canal haut)
    Protected coeff_lum = @coeff()
    Protected float_255.f = 255.0
    
    Protected Dim Data_argb.PixelVec(lg)
    Protected *datap = @Data_argb()
    
    macro_calul_tread(\image_ht[0])

    For y = thread_start To thread_stop - 1
      
      For i = 0 To lengthMinus2
        pos1 = (y * lg + i )
        pos2 = pos1 + 1
        Bilateral_DomainTransform1D_sp1_sse2()
      Next
      
      i = lengthMinus1
      getrgb(*source\l[y * lg + lengthMinus1] , r0 , g0 , b0)
      Data_argb(i)\r = r0 : Data_argb(i)\g = g0 : Data_argb(i)\b = b0
      
      domain(0) = 0
      For i = 1 To lengthMinus1
        domain(i) = domain(i - 1) + 1.0 + sigma_color_factor * dc(i - 1)
        If domain(i) < domain(i - 1) : domain(i) = domain(i - 1) : EndIf
      Next
      
      For i = 1 To lengthMinus1
        diff_d = domain(i) - domain(i - 1)
        Bilateral_DomainTransform1D_sp0_sse2(sub)
      Next
      
      For i = lengthMinus2 To 0 Step -1
        diff_d = domain(i + 1) - domain(i)
        Bilateral_DomainTransform1D_sp0_sse2(add)
      Next
      
      For i = 0 To lengthMinus1
        pos1 = y * lg + i
        Bilateral_DomainTransform1D_Write_Pixel()
      Next
    Next
    FreeArray(domain())
    FreeArray(dc())
    FreeArray(Data_argb())
  EndWith
EndProcedure

Procedure Bilateral_DomainTransform1D_Y_sse2(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.pixelarray = \addr[0]
    Protected *cible.pixelarray  = \addr[1]
    Protected *expLUT = *FilterCtx\addr[2]
    Protected lg.l = \image_lg[0]
    Protected ht.l = \image_ht[0]
    Protected Dim domain.f(ht)
    Protected Dim dc.f(ht)
    Protected i.i, idx.i
    Protected diff_d.f, alpha.f, frac.f, a0.f, a1.f
    Protected.l pixel0, r0, g0, b0, r1, g1, b1
    Protected stride = \image_lg[0] << 2
    Protected x, y , pos1 , pos2
    Protected lengthMinus1 = ht - 1
    Protected lengthMinus2 = ht - 2
    Protected sigma_color_factor.f = \option[4]
    Protected.l dr , dg , db
    
    Protected dcp = @dc()
    Protected p1 , p2
    
    Protected Dim coeff.f(4)
    coeff(0) = 0.30  ; R (Canal bas)
    coeff(1) = 0.59  ; G
    coeff(2) = 0.11  ; B
    coeff(3) = 0.0   ; A (Canal haut)
    Protected coeff_lum = @coeff()
    Protected float_255.f = 255.0
    
    Protected Dim Data_argb.PixelVec(ht)
    Protected *datap = @Data_argb()
    
    macro_calul_tread(\image_lg[0])
    
    For x = thread_start To thread_stop - 1
      
      For i = 0 To lengthMinus2
        pos1 = lg * i + x
        pos2 = pos1 + lg
        Bilateral_DomainTransform1D_sp1_sse2()
      Next
      
      i = lengthMinus1
      getRGB(*source\l[ lengthMinus1 * lg + x] , r0 , g0 , b0)
      Data_argb(i)\r = r0 : Data_argb(i)\g = g0 : Data_argb(i)\b = b0
      
      domain(0) = 0
      For i = 1 To lengthMinus1
        domain(i) = domain(i - 1) + 1.0 + sigma_color_factor * dc(i - 1)
        If domain(i) < domain(i - 1) : domain(i) = domain(i - 1) : EndIf
      Next
      
      For i = 1 To lengthMinus1
        diff_d = domain(i) - domain(i - 1)
        Bilateral_DomainTransform1D_sp0_sse2(sub)
      Next
      
      For i = lengthMinus2 To 0 Step -1
        diff_d = domain(i + 1) - domain(i)
        Bilateral_DomainTransform1D_sp0_sse2(add)
      Next
      
      For i = 0 To lengthMinus1
        pos1 = i * lg + x
        Bilateral_DomainTransform1D_Write_Pixel() 
      Next
    Next
    FreeArray(domain())
    FreeArray(dc())
    FreeArray(Data_argb())
  EndWith
EndProcedure
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 273
; Folding = -
; EnableXP
; DPIAware