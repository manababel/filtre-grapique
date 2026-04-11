; ---------------------------------------------------
; CircularMeanBlurSAT (moyenne circulaire via somme intégrale 2D)
; ARGB32, multithread, masque optionnel
; ---------------------------------------------------

; --- Procédure threadée
Procedure CircularMean_MT(*param.parametre)
  Protected w = *param\lg, h = *param\ht
  Protected radius = *param\option[0]
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
        *src32 = *param\addr[0] + spos*4
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
      If r1 < 0 : r1 = 0 : EndIf
      If r1 > 255 : r1 = 255 : EndIf
      If g1 < 0 : g1 = 0 : EndIf
      If g1 > 255 : g1 = 255 : EndIf
      If b1 < 0 : b1 = 0 : EndIf
      If b1 > 255 : b1 = 255 : EndIf

      *dst32 = *param\addr[1] + pos * 4
      *dst32\l = (a1 << 24) + (r1 << 16) + (g1 << 8) + b1
    Next
  Next

  FreeMemory(SAT_A) : FreeMemory(SAT_R)
  FreeMemory(SAT_G) : FreeMemory(SAT_B)
EndProcedure


; --- Procédure principale (inchangée)
Procedure CircularMeanblur(*param.parametre)
  If param\info_active
    param\typ      = #FilterType_Blur
    param\subtype  = #Blur_Classic
    param\name     = "CircularMeanBlurSAT"
    param\remarque = "Moyenne circulaire via somme intégrale 2D"
    param\info[0]  = "Rayon"
    param\info[3]  = "Masque"
    param\info_data(0,0)=0 : param\info_data(0,1)=200 : param\info_data(0,2)=1
    param\info_data(3,0)=0 : param\info_data(3,1)=1   : param\info_data(3,2)=0
    ProcedureReturn
  EndIf

  If Filter_BufferPrepare(*param.parametre) <> 0
    CopyMemory(*param\addr[0], *param\addr[1], (*param\lg * *param\ht * 4))
    MultiThread_MT(@CircularMean_MT())
    macro_Filter_BufferFinalize(3)
  EndIf
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 157
; FirstLine = 88
; Folding = -
; EnableXP
; DPIAware