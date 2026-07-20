
Procedure RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE2(*FilterCtx.FilterParams)
Protected radius = *FilterCtx\option[0]
  Protected w = *FilterCtx\image_lg[0]
  Protected h = *FilterCtx\image_ht[0]
  Protected x, y, i, px
  Protected w_minus_1 = w - 1
  Protected *src.pixelarray = *FilterCtx\addr[0]
  Protected *dst.pixelarray = *FilterCtx\addr[5]
  
  macro_calul_tread(h)
  
  Protected c.l
  Protected.i current_src, current_dst
  
  ; --- PRÉCALCUL DE LA TABLE D'INVERSES 16-BIT ---
  ; La taille max de la fenêtre est (radius * 2) + 1
  Protected max_c = (radius * 2) + 1
  Dim invTable.u(max_c)
  For i = 1 To max_c : invTable(i) = ($FFFF + (i / 2)) / i : Next
  Protected.i p_invTable = @invTable()
  Protected inv_c.u
  
  For y = thread_start To thread_stop - 1
    For x = 0 To w - 1
      
      !pxor xmm0, xmm0
      c = 0
      
      For i = -radius To radius
        px = x + i
        If px < 0 : px = 0 : ElseIf px > w_minus_1 : px = w_minus_1 : EndIf
        current_src = *src + ((y * w + px) * 4)
        c + 1
        !mov r8, [p.v_current_src]
        !movd xmm1, [r8]              ; xmm1 = [0 | 0 | 0 | A R G B] (8 bits par canal)
        !pxor xmm2, xmm2
        !punpcklbw xmm1, xmm2         ; xmm1 = [0A | 0R | 0G | 0B] (Converti en 16 bits)
        !paddw xmm0, xmm1             ; xmm0 = sum + pixel
      Next
      
      current_dst = *dst + ((y * w + x) * 4)
      Protected *invPtr.Word = p_invTable + (c * 2)
      inv_c = *invPtr\w
      
      ; --- Division par Multiplication et Paquetage ---
      !mov r10, [p.v_p_invTable]
      !movsxd rax, [p.v_c]
      !movzx eax, word [r10 + rax * 2] ; Charge la valeur d'inverse correspondante à 'c'
      !movd xmm2, eax
      !pshuflw xmm2, xmm2, 0          ; Duplique l'inverse dans les mots 16 bits bas
      ; Multiplie les sommes 16 bits par l'inverse et garde la partie haute (équivaut à /65536)
      !pmulhuw xmm0, xmm2             ; xmm0 = (xmm0 * xmm2) >> 16
      ; Compression finale de 16 bits vers 8 bits non-signés
      !packuswb xmm0, xmm0            ; Réduit les canaux à 8 bits -> [0...0 | A R G B]
      ; Écriture directe
      !mov r9, [p.v_current_dst]
      !movd [r9], xmm0                ; Écrit le pixel ARGB final d'un coup
    Next
  Next
EndProcedure

Procedure RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE2(*FilterCtx.FilterParams)
Protected radius = *FilterCtx\option[0]
  Protected w = *FilterCtx\image_lg[0]
  Protected h = *FilterCtx\image_ht[0]
  Protected x, y, i, py
  Protected h_minus_1 = h - 1
  Protected *src.pixelarray = *FilterCtx\addr[5] ; Lit horizontal buffer
  Protected *dst.pixelarray = *FilterCtx\addr[4] ; Écrit dans GUIDE
  
  macro_calul_tread(w)
  
  Protected c.l
  Protected.i current_src, current_dst
  
  ; --- PRÉCALCUL DE LA TABLE D'INVERSES 16-BIT ---
  Protected max_c = (radius * 2) + 1
  Dim invTable.u(max_c)
  For i = 1 To max_c
    invTable(i) = ($FFFF + (i / 2)) / i
  Next
  Protected.i p_invTable = @invTable()
  
  ; Inversion des boucles : le multi-thread découpe par colonne (x)
  For x = thread_start To thread_stop - 1
    For y = 0 To h - 1
      
      ; Accumulateur 16 bits mis à zéro [A | R | G | B]
      !pxor xmm0, xmm0
      c = 0
      
      For i = -radius To radius
        py = y + i
        ; Clamping vertical rapide
        If py < 0 : py = 0 : ElseIf py > h_minus_1 : py = h_minus_1 : EndIf
        ; Calcul de l'adresse du pixel source (déplacement vertical : py * w)
        current_src = *src + ((py * w + x) * 4)
        c + 1
        !mov r8, [p.v_current_src]
        !movd xmm1, [r8]              ; xmm1 = [0 | 0 | 0 | A R G B]
        !pxor xmm2, xmm2
        !punpcklbw xmm1, xmm2         ; xmm1 = [0A | 0R | 0G | 0B] (en 16 bits)
        !paddw xmm0, xmm1
      Next
      
      ; Calcul de l'adresse destination pour le pixel (y * w + x)
      current_dst = *dst + ((y * w + x) * 4)
      
      ; --- Division par Multiplication (Virgule Fixe) ---
      !mov r10, [p.v_p_invTable]
      !movsxd rax, [p.v_c]
      !movzx eax, word [r10 + rax * 2] ; Récupère le multiplicateur magique pour 'c'
      !movd xmm2, eax
      !pshuflw xmm2, xmm2, 0          ; Duplique l'inverse dans la partie basse
      !pmulhuw xmm0, xmm2             ; xmm0 = (xmm0 * xmm2) >> 16
      !packuswb xmm0, xmm0            ; Réduit à 8 bits -> [0...0 | A R G B]
      !mov r9, [p.v_current_dst]
      !movd [r9], xmm0                ; Écrit le pixel ARGB lissé d'un seul coup
      
    Next
  Next
EndProcedure
  
; --- Worker Thread : Bilateral Filter Guidé ---
Procedure RollingGuidance_Worker_SSE2(*FilterCtx.FilterParams)
With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected radius = \option[0]
    Protected sigmaColor = \option[1]
    Protected dim_size = (radius * 2) + 1
    Protected x, y, dx, dy, px, py, idx
    Protected.l r0, g0, b0
    
    Protected w_minus_1 = w - 1
    Protected h_minus_1 = h - 1
    
    Protected *src   = \addr[0]
    Protected *dst   = \addr[1]
    Protected *guide = \addr[2]
    
    Protected *currentGuide.pixelarray
    Protected *currentDst.pixelarray
    Protected *pixelSrc.pixelarray
    Protected offsetLine.i
    
    Protected *buf1.floatarray = \addr[7] ; Table Couleur (Float)
    Protected *buf2.floatarray = \addr[6] ; Table Espace (Float)
    
    ; Variables de transit pour l'ASM
    Protected.i current_src, current_dst
    Protected.l dColor
    Protected.f wTot
    
    ; Découpage multi-thread
    macro_calul_tread(h)

    For y = thread_start To thread_stop - 1
      
      offsetLine = y * w
      *currentGuide = *guide + (offsetLine * 4)
      *currentDst   = *dst + (offsetLine * 4)
      
      For x = 0 To w - 1
        idx = *currentGuide\l[x]
        r0 = (idx >> 16) & $FF
        g0 = (idx >> 8) & $FF
        b0 = idx & $FF
        
        ; --- Initialisation des Accumulateurs SSE2 ---
        !pxor xmm0, xmm0
        !pxor xmm4, xmm4
        
        For dy = -radius To radius
          py = y + dy
          If py < 0 : py = 0 : ElseIf py > h_minus_1 : py = h_minus_1 : EndIf
          
          Protected *srcLine = *src + (py * w * 4)
          Protected ly = dy + radius
          Protected idx_space_base = ly * dim_size
          
          For dx = -radius To radius
            px = x + dx
            If px < 0 : px = 0 : ElseIf px > w_minus_1 : px = w_minus_1 : EndIf
            
            current_src = *srcLine + (px * 4)
            *pixelSrc = current_src
            idx = *pixelSrc\l[0]
            
            ; Calcul rapide de la distance de couleur
            Protected r_diff = r0 - ((idx >> 16) & $FF)
            Protected g_diff = g0 - ((idx >> 8) & $FF)
            Protected b_diff = b0 - (idx & $FF)
            dColor = r_diff*r_diff + g_diff*g_diff + b_diff*b_diff
            
            Protected lx = dx + radius
            
            ; Récupération des deux poids float et calcul de wTot
            wTot = *buf1\f[dColor] * *buf2\f[idx_space_base + lx]
            
            ; --- Traitement Vectoriel SSE2 ---
            !mov r8, [p.v_current_src]
            !movd xmm1, [r8]                ; xmm1 = [0 | 0 | 0 | A R G B]
            
            !pxor xmm2, xmm2
            !punpcklbw xmm1, xmm2           ; 8-bit -> 16-bit
            !punpcklwd xmm1, xmm2           ; 16-bit -> 32-bit entier
            
            !cvtdq2ps xmm1, xmm1            ; Convertit en Floats
            
            !movss xmm3, [p.v_wTot]
            !shufps xmm3, xmm3, 0           ; xmm3 = [wTot | wTot | wTot | wTot]
            
            !addss xmm4, xmm3               ; Accumule sumW (slot bas)
            
            !mulps xmm1, xmm3               ; Canaux * wTot
            !addps xmm0, xmm1               ; Accumule canaux
          Next
        Next
        
        ; --- Normalisation Finale & Division ---
        !pxor xmm2, xmm2
        !ucomiss xmm4, xmm2             ; Compare sumW à 0.0
        !jbe l_rollingguidance_worker_sse2_jp1
        
        !shufps xmm4, xmm4, 0           ; Duplique sumW
        !divps xmm0, xmm4               ; Division : xmm0 / sumW
        
        ; Arrondi parfait (+0.5f)
        !mov eax, $3F000000             ; Hex pour 0.5f
        !movd xmm5, eax
        !shufps xmm5, xmm5, 0
        !addps xmm0, xmm5
        
        !cvttps2dq xmm0, xmm0           ; Float -> Int 32-bit
        !packssdw xmm0, xmm0            ; 32-bit -> 16-bit
        !packuswb xmm0, xmm0            ; 16-bit -> 8-bit
        
        ; --- Écriture Sécurisée (Correction de l'indexation) ---
        !mov r9, [p.p_currentDst]       ; Récupère le pointeur de la ligne destination (v_ obligatoire)
        !movsxd rax, [p.v_x]            ; Charge l'index 'x' étendu en 64-bit dans RAX
        !movd [r9 + rax * 4], xmm0      ; Écrit le pixel ARGB final
        !jmp l_rollingguidance_worker_sse2_jp2
        
        !l_rollingguidance_worker_sse2_jp1:
        !mov r9, [p.p_currentDst]
        !movsxd rax, [p.v_x]
        !mov dword [r9 + rax * 4], 0    ; Écrit noir si sumW <= 0
        
        !l_rollingguidance_worker_sse2_jp2:
        If Key_Escape_Press = 1 : Break 2 : EndIf
      Next
    Next
  EndWith
EndProcedure



; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 251
; FirstLine = 202
; Folding = -
; EnableXP
; DPIAware