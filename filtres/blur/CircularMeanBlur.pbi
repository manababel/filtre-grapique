; ---------------------------------------------------
; CircularMeanBlur using 2D Integral Image (Summed-Area Table)
; ARGB32 — multithread / masque optionnel
; ---------------------------------------------------

; --- Build Summed-Area Tables (SAT) for A,R,G,B
Macro CMB_build_SAT()
  Protected y, x, idx, idx_up, idx_left, idx_ul
  Protected a_s, r_s, g_s, b_s
  ; W1 = w + 1 ; H1 = h + 1
  For y = 0 To h
    For x = 0 To w
      idx = y * W1 + x
      If (y = 0) Or (x = 0)
        SAT_A[idx] = 0 : SAT_R[idx] = 0 : SAT_G[idx] = 0 : SAT_B[idx] = 0
      Else
        ; source pixel coords
        sx = x - 1 : sy = y - 1
        spos = sy * w + sx
        srcpix32 = src32 + (spos * 4)
        a_s = (srcpix32\l >> 16) & $ff00
        r_s = (srcpix32\l >>  8) & $ff00
        g_s = (srcpix32\l      ) & $ff00
        b_s = (srcpix32\l <<  8) & $ff00

        idx_up = (y-1) * W1 + x
        idx_left = y * W1 + (x-1)
        idx_ul = (y-1) * W1 + (x-1)

        ; SAT(y,x) = val + SAT(y-1,x) + SAT(y,x-1) - SAT(y-1,x-1)
        SAT_A[idx] = a_s + SAT_A[idx_up] + SAT_A[idx_left] - SAT_A[idx_ul]
        SAT_R[idx] = r_s + SAT_R[idx_up] + SAT_R[idx_left] - SAT_R[idx_ul]
        SAT_G[idx] = g_s + SAT_G[idx_up] + SAT_G[idx_left] - SAT_G[idx_ul]
        SAT_B[idx] = b_s + SAT_B[idx_up] + SAT_B[idx_left] - SAT_B[idx_ul]
      EndIf
    Next
  Next
EndMacro

; --- Query rectangle sum using SAT
; rectangle inclusive coords: x0..x1, y0..y1  (0-based src coords)
; we use W1 = w+1, SAT indexed with +1 offset internally
Macro CMB_SAT_rect_sum(x0,y0,x1,y1, outA,outR,outG,outB)
  ; clamp
  If x0 < 0 Then x0 = 0 : EndIf
  If y0 < 0 Then y0 = 0 : EndIf
  If x1 > w-1 Then x1 = w-1 : EndIf
  If y1 > h-1 Then y1 = h-1 : EndIf

  ix0 = x0
  iy0 = y0
  ix1 = x1
  iy1 = y1

  ; convert to SAT indices (offset +1)
  sx0 = iy0 * W1 + ix0
  ; but formula uses (y1+1,x1+1) etc:
  A00 = SAT_A[iy0 * W1 + ix0]            ; not used directly but kept for clarity

  iA11 = (iy1 + 1) * W1 + (ix1 + 1)
  iA01 = (iy0)     * W1 + (ix1 + 1)
  iA10 = (iy1 + 1) * W1 + (ix0)
  iA00 = (iy0)     * W1 + (ix0)

  outA = SAT_A[iA11] - SAT_A[iA01] - SAT_A[iA10] + SAT_A[iA00]
  outR = SAT_R[iA11] - SAT_R[iA01] - SAT_R[iA10] + SAT_R[iA00]
  outG = SAT_G[iA11] - SAT_G[iA01] - SAT_G[iA10] + SAT_G[iA00]
  outB = SAT_B[iA11] - SAT_B[iA01] - SAT_B[iA10] + SAT_B[iA00]
EndMacro

; --- Process band for each thread using SAT
Macro CircularMean_process_band_SAT()
  Protected y, x, dx, dy, x2, y0, y1, wdx, rr
  Protected colA, colR, colG, colB
  Protected a_acc, r_acc, g_acc, b_acc, count
  rr = radius * radius
  For y = thread_start To thread_stop - 1
    mem_line = y * w
    For x = 0 To w - 1
      pos = mem_line + x
      ; masque optionnel : si présent et =0 -> skip (laisser dst copie)
      If has_mask
        maskpix = mask32 + (pos * 4)
        If maskpix\l = 0
          ProcedureContinue
        EndIf
      EndIf

      a_acc = 0 : r_acc = 0 : g_acc = 0 : b_acc = 0 : count = 0

      ; pour chaque colonne dx dans le disque, on récupère la colonne segment via SAT
      For dx = -radius To radius
        x2 = x + dx
        If (x2 < 0) Or (x2 >= w) Then Continue
        tmp = rr - dx * dx
        If tmp < 0 Then Continue
        wdx = Int(Sqrt(tmp))
        y0 = y - wdx : If y0 < 0 Then y0 = 0 : EndIf
        y1 = y + wdx : If y1 >= h Then y1 = h - 1 : EndIf

        ; sum rectangle x2..x2 , y0..y1  (single column)
        CMB_SAT_rect_sum(x2, y0, x2, y1, colA, colR, colG, colB)

        a_acc = a_acc + colA
        r_acc = r_acc + colR
        g_acc = g_acc + colG
        b_acc = b_acc + colB
        count = count + (y1 - y0 + 1)
      Next

      ; calcul moyenne et écriture (accumulateurs sont en 16-bit-scaled sums)
      If count = 0
        a1 = 0 : r1 = 0 : g1 = 0 : b1 = 0
      Else
        ; a_acc etc sont sommes de valeurs en échelle 256 (16-bit). 
        ; faire la moyenne : (sum + count/2) / count -> valeur 16-bit-scaled
        a_tmp = (a_acc + (count >> 1)) / count
        r_tmp = (r_acc + (count >> 1)) / count
        g_tmp = (g_acc + (count >> 1)) / count
        b_tmp = (b_acc + (count >> 1)) / count

        ; convertir en 8-bit : (v + 128) >> 8
        a1 = (a_tmp + 128) >> 8
        r1 = (r_tmp + 128) >> 8
        g1 = (g_tmp + 128) >> 8
        b1 = (b_tmp + 128) >> 8
      EndIf

      dstpix32 = dst32 + (pos * 4)
      dstpix32\l = (a1 << 24) + (r1 << 16) + (g1 << 8) + b1
    Next
  Next
EndMacro

; --- Init & SAT allocation
Macro CircularMean_init_SAT()
  Protected *cible  = *param\addr[1]
  Protected *src    = *param\addr[0]
  Protected w = *param\lg, h = *param\ht
  Protected radius
  Protected *dst32.pixel32 = *cible
  Protected *src32.pixel32 = *src
  Protected *mask32.pixel32 = 0

  radius = *param\option[0]
  If radius < 0 Then radius = 0 : EndIf

  has_mask = 0
  If *param\option[3] <> 0
    mask_ptr = *param\addr[2]
    If mask_ptr <> 0
      has_mask = 1
      mask32 = mask_ptr
    EndIf
  EndIf

  ; dimension SAT : (w+1) * (h+1)
  W1 = w + 1
  H1 = h + 1
  sizeSAT = W1 * H1

  ; allouer SATs (utiliser un type 64-bit si possible)
  SAT_A = AllocateMemory(sizeSAT * 8)  ; 8 bytes per cell (int64)
  SAT_R = AllocateMemory(sizeSAT * 8)
  SAT_G = AllocateMemory(sizeSAT * 8)
  SAT_B = AllocateMemory(sizeSAT * 8)

  ; initialiser/ construire
  CMB_build_SAT()

  ; découpage threads selon la hauteur
  macro_calul_tread(h)
EndMacro

; --- Thread proc
Procedure CircularMean_SAT_thread(*param.parametre)
  CircularMean_init_SAT()
  CircularMean_process_band_SAT()
  ; free SATs
  FreeMemory(SAT_A) : FreeMemory(SAT_R) : FreeMemory(SAT_G) : FreeMemory(SAT_B)
EndProcedure

; --- Entrée principale
Procedure CircularMeanSAT(*param.parametre)
  If param\info_active
    param\typ = #FilterType_Blur
    param\subtype = #Blur_Classic
    param\name = "CircularMeanBlurSAT"
    param\remarque = "Moyenne circulaire via Summed-Area Table (SAT) — rapide pour rayons moyens/grands"
    param\info[0] = "Rayon"
    param\info[3] = "Masque"
    param\info_data(0,0)=0:param\info_data(0,1)=200:param\info_data(0,2)=1
    param\info_data(3,0)=0:param\info_data(3,1)=1:param\info_data(3,2)=0
    ProcedureReturn
  EndIf

  If Filter_BufferPrepare(*param.parametre) <> 0
    ; on copie source->dest pour laisser dst initialisée (on écrit dessus)
    CopyMemory(*param\addr[0], *param\addr[1], (*param\lg * *param\ht * 4))
    MultiThread_MT(@CircularMean_SAT_thread())
    macro_Filter_BufferFinalize(3)
  EndIf
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 183
; FirstLine = 134
; Folding = --
; EnableXP
; DPIAware