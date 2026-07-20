; ---------------------------------------------------
; CircularMeanBlurSAT (Version optimisée SSE2 / SIMD CORRIGÉE)
; ---------------------------------------------------
; ---------------------------------------------------
; CircularMeanBlurSAT (Version SSE2 QUI MARCHE)
; ---------------------------------------------------

Procedure CircularMean_MT_SSE2(*FilterCtx.FilterParams)
  With *FilterCtx
    pop_reg(*FilterCtx)
    pop_reg_xmm(*FilterCtx)
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected radius = \option[0]
    Protected *src32.pixel32
    Protected *dst32.pixel32

    Protected W1 = w + 1, H1 = h + 1, sizeSAT = W1 * H1
    
    ; SAT avec 4 canaux consécutifs par pixel (32 octets/pixel)
    ; Format: [B(8)|G(8)|R(8)|A(8)] pour chaque canal en 64-bit
    Protected *SAT = AllocateMemory(sizeSAT * 32)
    If *SAT = 0 : ProcedureReturn : EndIf
    
    Protected x, y, dx, dy, pos, x2, y0, y1, rr, tmp, wdx, count
    Protected idx, idx_up, idx_left, idx_ul, sx, sy, spos
    Protected.q b_acc, g_acc, r_acc, a_acc
    Protected a1, r1, g1, b1
    Protected pixelColor, a_s, r_s, g_s, b_s

    ; --- 1. CONSTRUIRE LA SAT (version avec petits bouts d'ASM pour les additions) ---
    For y = 0 To h
      For x = 0 To w
        idx = (y * W1 + x) << 5  ; * 32 (décalage plus rapide)
        
        If y = 0 Or x = 0
          ; Mettre à zéro les 32 octets
          !mov eax, [p.v_idx]
          !mov rdx, [p.p_SAT]
          !pxor xmm0, xmm0
          !movdqa [rdx + rax], xmm0
          !movdqa [rdx + rax + 16], xmm0
        Else
          sx = x - 1 : sy = y - 1
          spos = sy * w + sx
          *src32 = \image[0] + spos * 4
          pixelColor = *src32\l
          
          ; Extraire les canaux et décaler (<< 8) pour la précision
          a_s = ((pixelColor >> 24) & $FF) << 8
          r_s = ((pixelColor >> 16) & $FF) << 8
          g_s = ((pixelColor >> 8)  & $FF) << 8
          b_s = ((pixelColor)       & $FF) << 8
          
          idx_up   = ((y - 1) * W1 + x) << 5
          idx_left = (y * W1 + (x - 1)) << 5
          idx_ul   = ((y - 1) * W1 + (x - 1)) << 5
          
          ; Calcul avec SSE2: pixel + haut + gauche - diagonale
          !mov rax, [p.p_SAT]
          
          ; Charger haut (4 QWORDs)
          !mov rcx, [p.v_idx_up]
          !movdqa xmm0, [rax + rcx]
          !movdqa xmm1, [rax + rcx + 16]
          
          ; Ajouter gauche
          !mov rcx, [p.v_idx_left]
          !paddq xmm0, [rax + rcx]
          !paddq xmm1, [rax + rcx + 16]
          
          ; Soustraire diagonale
          !mov rcx, [p.v_idx_ul]
          !psubq xmm0, [rax + rcx]
          !psubq xmm1, [rax + rcx + 16]
          
          ; Ajouter le pixel actuel
          !movq xmm2, [p.v_b_s]
          !movq xmm3, [p.v_g_s]
          !movq xmm4, [p.v_r_s]
          !movq xmm5, [p.v_a_s]
          
          ; Packer les 4 canaux dans xmm0 et xmm1
          !punpcklqdq xmm2, xmm3    ; xmm2 = [G_s | B_s]
          !punpcklqdq xmm4, xmm5    ; xmm4 = [A_s | R_s]
          
          !paddq xmm0, xmm2
          !paddq xmm1, xmm4
          
          ; Stocker
          !mov rcx, [p.v_idx]
          !movdqa [rax + rcx], xmm0
          !movdqa [rax + rcx + 16], xmm1
        EndIf
      Next
    Next

    ; --- Découpe des threads ---
    macro_calul_tread(h)
    rr = radius * radius

    ; --- 2. PARCOURS DES PIXELS (version PB pure pour la boucle, c'est plus sûr) ---
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        pos = y * w + x
        
        b_acc = 0 : g_acc = 0 : r_acc = 0 : a_acc = 0
        count = 0
        
        For dx = -radius To radius
          x2 = x + dx
          If x2 < 0 Or x2 >= w : Continue : EndIf
          
          tmp = rr - dx * dx
          If tmp < 0 : Continue : EndIf
          
          wdx = Int(Sqr(tmp))
          y0 = y - wdx : If y0 < 0 : y0 = 0 : EndIf
          y1 = y + wdx : If y1 >= h : y1 = h - 1 : EndIf
          
          If y0 > y1 : Continue : EndIf
          
          ; Indices SAT (en octets)
          Protected i11 = ((y1 + 1) * W1 + (x2 + 1)) << 5
          Protected i01 = (y0 * W1 + (x2 + 1)) << 5
          Protected i10 = ((y1 + 1) * W1 + x2) << 5
          Protected i00 = (y0 * W1 + x2) << 5
          
          ; Somme rectangle avec SSE2 (uniquement cette partie est optimisée)
          !mov rax, [p.p_SAT]
          
          ; Canal B (offset 0)
          !mov rcx, [p.v_i11]
          !mov r8, [rax + rcx]
          !mov rcx, [p.v_i01]
          !sub r8, [rax + rcx]
          !mov rcx, [p.v_i10]
          !sub r8, [rax + rcx]
          !mov rcx, [p.v_i00]
          !add r8, [rax + rcx]
          !add [p.v_b_acc], r8
          
          ; Canal G (offset 8)
          !mov rcx, [p.v_i11]
          !mov r8, [rax + rcx + 8]
          !mov rcx, [p.v_i01]
          !sub r8, [rax + rcx + 8]
          !mov rcx, [p.v_i10]
          !sub r8, [rax + rcx + 8]
          !mov rcx, [p.v_i00]
          !add r8, [rax + rcx + 8]
          !add [p.v_g_acc], r8
          
          ; Canal R (offset 16)
          !mov rcx, [p.v_i11]
          !mov r8, [rax + rcx + 16]
          !mov rcx, [p.v_i01]
          !sub r8, [rax + rcx + 16]
          !mov rcx, [p.v_i10]
          !sub r8, [rax + rcx + 16]
          !mov rcx, [p.v_i00]
          !add r8, [rax + rcx + 16]
          !add [p.v_r_acc], r8
          
          ; Canal A (offset 24)
          !mov rcx, [p.v_i11]
          !mov r8, [rax + rcx + 24]
          !mov rcx, [p.v_i01]
          !sub r8, [rax + rcx + 24]
          !mov rcx, [p.v_i10]
          !sub r8, [rax + rcx + 24]
          !mov rcx, [p.v_i00]
          !add r8, [rax + rcx + 24]
          !add [p.v_a_acc], r8
          
          count + (y1 - y0 + 1)
        Next
        
        If count > 0
          ; Calcul des moyennes
          b1 = ((b_acc + (count >> 1)) / count + 128) >> 8
          g1 = ((g_acc + (count >> 1)) / count + 128) >> 8
          r1 = ((r_acc + (count >> 1)) / count + 128) >> 8
          a1 = ((a_acc + (count >> 1)) / count + 128) >> 8
          clamp_argb(a1 , r1 ,g1 , b1)
        Else
          a1 = 0 : r1 = 0 : g1 = 0 : b1 = 0
        EndIf
        
        *dst32 = \image[1] + pos * 4
        *dst32\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
      Next
    Next
    
    FreeMemory(*SAT)
  EndWith
  push_reg_xmm(*FilterCtx)
  push_reg(*FilterCtx)
EndProcedure

; ---------------------------------------------------
; CircularMeanBlurSAT (moyenne circulaire via somme intégrale 2D)
; ---------------------------------------------------

; --- Procédure threadée
Procedure CircularMean_MT(*FilterCtx.FilterParams)
  Protected w = FilterCtx\image_lg[0]
  Protected h = FilterCtx\image_ht[0]
  Protected radius = FilterCtx\option[0]
  Protected *src32.pixel32
  Protected *dst32.pixel32

  Protected W1 = w + 1, H1 = h + 1, sizeSAT = W1 * H1
  Protected SAT_A, SAT_R, SAT_G, SAT_B
  Protected x, y, dx, dy, pos, x2, y0, y1, rr, tmp, wdx
  ; accumulateurs int64 (Q = 8 octets)
  Protected a_acc.q, r_acc.q, g_acc.q, b_acc.q
  Protected count.i
  Protected colA.q, colR.q, colG.q, colB.q
  Protected a1, r1, g1, b1, a_tmp.q, r_tmp.q, g_tmp.q, b_tmp.q

  ; --- Allouer SAT (int64 par canal)
  SAT_A = AllocateMemory(sizeSAT * 8)
  SAT_R = AllocateMemory(sizeSAT * 8)
  SAT_G = AllocateMemory(sizeSAT * 8)
  SAT_B = AllocateMemory(sizeSAT * 8)

  ; --- Construire SAT
  Protected idx, idx_up, idx_left, idx_ul, sx, sy, spos
  For y = 0 To h
    For x = 0 To w
      idx = y * W1 + x
      If (y = 0) Or (x = 0)
        PokeQ(SAT_A + idx*8, 0)
        PokeQ(SAT_R + idx*8, 0)
        PokeQ(SAT_G + idx*8, 0)
        PokeQ(SAT_B + idx*8, 0)
      Else
        sx = x - 1
        sy = y - 1
        spos = sy * w + sx
        *src32 = FilterCtx\image[0] + spos * 4
        ; on stocke les canaux en 16-bit (décalés) pour garder précision lors de l'accumulation
        Protected a_s = ((*src32\l >> 24) & $FF) << 8
        Protected r_s = ((*src32\l >> 16) & $FF) << 8
        Protected g_s = ((*src32\l >>  8) & $FF) << 8
        Protected b_s = ((*src32\l      ) & $FF) << 8

        idx_up   = (y - 1) * W1 + x
        idx_left = y * W1 + (x - 1)
        idx_ul   = (y - 1) * W1 + (x - 1)

        PokeQ(SAT_A + idx*8, a_s + PeekQ(SAT_A + idx_up*8) + PeekQ(SAT_A + idx_left*8) - PeekQ(SAT_A + idx_ul*8))
        PokeQ(SAT_R + idx*8, r_s + PeekQ(SAT_R + idx_up*8) + PeekQ(SAT_R + idx_left*8) - PeekQ(SAT_R + idx_ul*8))
        PokeQ(SAT_G + idx*8, g_s + PeekQ(SAT_G + idx_up*8) + PeekQ(SAT_G + idx_left*8) - PeekQ(SAT_G + idx_ul*8))
        PokeQ(SAT_B + idx*8, b_s + PeekQ(SAT_B + idx_up*8) + PeekQ(SAT_B + idx_left*8) - PeekQ(SAT_B + idx_ul*8))
      EndIf
    Next
  Next

  ; --- Découpe en bandes
  macro_calul_tread(h)

  rr = radius * radius

  ; --- Parcours pixels
  For y = thread_start To thread_stop - 1
    For x = 0 To w - 1
      pos = y * w + x

      a_acc = 0 : r_acc = 0 : g_acc = 0 : b_acc = 0
      count = 0

      For dx = -radius To radius
        x2 = x + dx
        If x2 < 0 Or x2 >= w : Continue : EndIf
        tmp = rr - dx*dx
        If tmp < 0 : Continue : EndIf
        wdx = Int(Sqr(tmp))
        y0 = y - wdx
        If y0 < 0 : y0 = 0 : EndIf
        y1 = y + wdx
        If y1 >= h : y1 = h - 1 : EndIf

        ; --- Rectangle sum via SAT pour la colonne x2 de y0..y1
        Protected ix0 = x2, ix1 = x2, iy0 = y0, iy1 = y1
        Protected iA11 = (iy1 + 1) * W1 + (ix1 + 1)
        Protected iA01 = (iy0)     * W1 + (ix1 + 1)
        Protected iA10 = (iy1 + 1) * W1 + (ix0)
        Protected iA00 = (iy0)     * W1 + (ix0)

        colA = PeekQ(SAT_A + iA11*8) - PeekQ(SAT_A + iA01*8) - PeekQ(SAT_A + iA10*8) + PeekQ(SAT_A + iA00*8)
        colR = PeekQ(SAT_R + iA11*8) - PeekQ(SAT_R + iA01*8) - PeekQ(SAT_R + iA10*8) + PeekQ(SAT_R + iA00*8)
        colG = PeekQ(SAT_G + iA11*8) - PeekQ(SAT_G + iA01*8) - PeekQ(SAT_G + iA10*8) + PeekQ(SAT_G + iA00*8)
        colB = PeekQ(SAT_B + iA11*8) - PeekQ(SAT_B + iA01*8) - PeekQ(SAT_B + iA10*8) + PeekQ(SAT_B + iA00*8)

        ; accumulation (les valeurs sont en Q = 16-bit*count)
        a_acc = a_acc + colA
        r_acc = r_acc + colR
        g_acc = g_acc + colG
        b_acc = b_acc + colB
        count = count + (y1 - y0 + 1)
      Next

      If count > 0
        ; moyenne (les accumulateurs sont en valeur<<8, donc division puis arrondi)
        a_tmp = (a_acc + (count >> 1)) / count    ; still shifted <<8
        r_tmp = (r_acc + (count >> 1)) / count
        g_tmp = (g_acc + (count >> 1)) / count
        b_tmp = (b_acc + (count >> 1)) / count

        a1 = (a_tmp + 128) >> 8
        r1 = (r_tmp + 128) >> 8
        g1 = (g_tmp + 128) >> 8
        b1 = (b_tmp + 128) >> 8
      Else
        a1 = 0 : r1 = 0 : g1 = 0 : b1 = 0
      EndIf

      ; clamp result (utilise ta fonction clamp_rgb si existante)
      clamp_rgb(r1 , g1 , b1)

      *dst32 = FilterCtx\image[1] + pos * 4
      *dst32\l = (a1 << 24) + (r1 << 16) + (g1 << 8) + b1
    Next
  Next

  FreeMemory(SAT_A) : FreeMemory(SAT_R)
  FreeMemory(SAT_G) : FreeMemory(SAT_B)
EndProcedure

; --- Procédure principale (inchangée)
Procedure CircularMeanblurEx(*FilterCtx.FilterParams)
  
  Restore CircularMeanblur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
   CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
     StackBlurEx_select(PB)
  CompilerElse
    
    CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
      Select FilterCtx\Asm
        Case 1 : Create_MultiThread_MT(@CircularMean_MT_SSE2())
        ;Case 2 : StackBlurEx_select(SSE4)
        ;Case 3 : StackBlurEx_select(AVX2)
        ;Case 4 : StackBlurEx_select(AVX512)
        Default :Create_MultiThread_MT(@CircularMean_MT())
      EndSelect
      
    CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
      
      Select FilterCtx\Asm
        Case 100
        Default : Create_MultiThread_MT(@CircularMean_MT())
      EndSelect
      
    CompilerEndIf
    
  CompilerEndIf
  
  mask_update(*FilterCtx.FilterParams , last_data)
  
EndProcedure

Procedure CircularMeanblur(source , cible , mask , rayon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
  EndWith
  CircularMeanblurEx(FilterCtx.FilterParams)
EndProcedure


DataSection
  CircularMeanblur_data:
  Data.s "CircularMeanBlur"
  Data.s "Moyenne circulaire via somme intégrale 2D"
  Data.i #FilterType_Blur
  Data.i #Blur_Classic
  
  Data.s "Rayon"         
  Data.i 1,15,1
  Data.s "XXX"
EndDataSection

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 196
; FirstLine = 141
; Folding = --
; EnableXP
; DPIAware