; ---------------------------------------------------
; Domain Transform - Version optimisée
; Edge-preserving filter
; ---------------------------------------------------

; --- Split canaux RGB en buffers float ---
Procedure DomainTransform_SP0_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[1]
    Protected start = (\thread_pos * total) / \thread_max
    Protected stop = (((\thread_pos + 1) * total) / \thread_max) - 1
    Protected i, pos, r, g, b, col

    For i = start To stop
        pos = i << 2
        col = PeekL(\addr[0] + pos)
        getrgb(col, r, g, b)
        
        PokeF(\addr[3] + pos, r)
        PokeF(\addr[4] + pos, g)
        PokeF(\addr[5] + pos, b)
    Next
  EndWith
EndProcedure

; --- Calcul des dérivées pondérées horizontales ---
Procedure DomainTransform_ComputeDx_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, pos
    Protected r1.f, g1.f, b1.f, r2.f, g2.f, b2.f
    Protected dr.f, dg.f, db.f, diff.f
    Protected factor.f = \option[0] / \option[1]
    Protected lgMinus1 = lg - 1
    
    Protected start = (\thread_pos * ht) / \thread_max
    Protected stop = ((\thread_pos + 1) * ht) / \thread_max - 1
    
    For y = start To stop
        pos = y * lg << 2
        For x = 0 To lgMinus1 - 1
            r1 = PeekF(\addr[3] + pos)
            g1 = PeekF(\addr[4] + pos)
            b1 = PeekF(\addr[5] + pos)

            r2 = PeekF(\addr[3] + pos + 4)
            g2 = PeekF(\addr[4] + pos + 4)
            b2 = PeekF(\addr[5] + pos + 4)

            dr = r1 - r2
            dg = g1 - g2
            db = b1 - b2

            diff = Sqr(dr*dr + dg*dg + db*db)
            PokeF(\addr[6] + pos, 1.0 + factor * diff)
            pos + 4
        Next
        PokeF(\addr[6] + pos, 0.0)
    Next
  EndWith
EndProcedure

; --- Calcul des dérivées pondérées verticales ---
Procedure DomainTransform_ComputeDy_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, pos, posNext
    Protected r1.f, g1.f, b1.f, r2.f, g2.f, b2.f
    Protected dr.f, dg.f, db.f, diff.f
    Protected factor.f = \option[0] / \option[1]
    Protected lgShift2 = lg << 2
    Protected htMinus1 = ht - 1
    
    Protected start = (\thread_pos * ht) / \thread_max
    Protected stop = ((\thread_pos + 1) * ht) / \thread_max - 1
    
    For y = start To stop
        If y < htMinus1
            pos = y * lg << 2
            posNext = pos + lgShift2
            For x = 0 To lg - 1
                r1 = PeekF(\addr[3] + pos)
                g1 = PeekF(\addr[4] + pos)
                b1 = PeekF(\addr[5] + pos)

                r2 = PeekF(\addr[3] + posNext)
                g2 = PeekF(\addr[4] + posNext)
                b2 = PeekF(\addr[5] + posNext)

                dr = r1 - r2
                dg = g1 - g2
                db = b1 - b2

                diff = Sqr(dr*dr + dg*dg + db*db)
                PokeF(\addr[7] + pos, 1.0 + factor * diff)
                pos + 4
                posNext + 4
            Next
        Else
            pos = y * lg << 2
            For x = 0 To lg - 1
                PokeF(\addr[7] + pos, 0.0)
                pos + 4
            Next
        EndIf
    Next
  EndWith
EndProcedure

; --- Transformée domaine + filtrage horizontal ---
Procedure DomainTransform_FilterH_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, posLine
    Protected sigma.f = \option[0]
    Protected exp_factor.f = -1.0 / (2.0 * sigma * sigma)
    Protected alpha.f, dist.f
    Protected trans_prev.f, trans_curr.f
    Protected rSrc.f, gSrc.f, bSrc.f
    Protected rDst.f, gDst.f, bDst.f
    Protected invAlpha.f
    
    Protected start = (\thread_pos * ht) / \thread_max
    Protected stop = ((\thread_pos + 1) * ht) / \thread_max - 1
    
    For y = start To stop
        posLine = y * lg << 2
        rDst = PeekF(\addr[3] + posLine)
        gDst = PeekF(\addr[4] + posLine)
        bDst = PeekF(\addr[5] + posLine)
        PokeF(\addr[10] + posLine, rDst)
        PokeF(\addr[11] + posLine, gDst)
        PokeF(\addr[12] + posLine, bDst)
        trans_prev = 0.0
        
        For x = 1 To lg - 1
            trans_curr = trans_prev + PeekF(\addr[6] + posLine + ((x-1) << 2))
            dist = trans_curr - trans_prev
            alpha = Exp(dist * dist * exp_factor)
            invAlpha = 1.0 - alpha
            rSrc = PeekF(\addr[3] + posLine + (x << 2))
            gSrc = PeekF(\addr[4] + posLine + (x << 2))
            bSrc = PeekF(\addr[5] + posLine + (x << 2))
            rDst = alpha * rDst + invAlpha * rSrc
            gDst = alpha * gDst + invAlpha * gSrc
            bDst = alpha * bDst + invAlpha * bSrc
            PokeF(\addr[10] + posLine + (x << 2), rDst)
            PokeF(\addr[11] + posLine + (x << 2), gDst)
            PokeF(\addr[12] + posLine + (x << 2), bDst)
            trans_prev = trans_curr
        Next
        
        For x = lg - 2 To 0 Step -1
            dist = trans_curr - trans_prev + PeekF(\addr[6] + posLine + (x << 2))
            alpha = Exp(dist * dist * exp_factor)
            invAlpha = 1.0 - alpha
            rSrc = PeekF(\addr[10] + posLine + (x << 2))
            gSrc = PeekF(\addr[11] + posLine + (x << 2))
            bSrc = PeekF(\addr[12] + posLine + (x << 2))
            rDst = alpha * rDst + invAlpha * rSrc
            gDst = alpha * gDst + invAlpha * gSrc
            bDst = alpha * bDst + invAlpha * bSrc
            PokeF(\addr[10] + posLine + (x << 2), rDst)
            PokeF(\addr[11] + posLine + (x << 2), gDst)
            PokeF(\addr[12] + posLine + (x << 2), bDst)
            trans_curr = trans_prev
            If x > 0 : trans_prev - PeekF(\addr[6] + posLine + ((x-1) << 2)) : EndIf
        Next
    Next
  EndWith
EndProcedure

; --- Transformée domaine + filtrage vertical ---
Procedure DomainTransform_FilterV_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, pos
    Protected sigma.f = \option[0]
    Protected exp_factor.f = -1.0 / (2.0 * sigma * sigma)
    Protected alpha.f, dist.f
    Protected trans_prev.f, trans_curr.f
    Protected rSrc.f, gSrc.f, bSrc.f
    Protected rDst.f, gDst.f, bDst.f
    Protected invAlpha.f
    Protected lgShift2 = lg << 2
    
    Protected start = (\thread_pos * lg) / \thread_max
    Protected stop = ((\thread_pos + 1) * lg) / \thread_max - 1
    
    For x = start To stop
        pos = x << 2
        rDst = PeekF(\addr[3] + pos)
        gDst = PeekF(\addr[4] + pos)
        bDst = PeekF(\addr[5] + pos)
        PokeF(\addr[10] + pos, rDst)
        PokeF(\addr[11] + pos, gDst)
        PokeF(\addr[12] + pos, bDst)
        trans_prev = 0.0
        
        For y = 1 To ht - 1
            trans_curr = trans_prev + PeekF(\addr[7] + pos + ((y-1) * lgShift2))
            dist = trans_curr - trans_prev
            alpha = Exp(dist * dist * exp_factor)
            invAlpha = 1.0 - alpha
            rSrc = PeekF(\addr[3] + pos + (y * lgShift2))
            gSrc = PeekF(\addr[4] + pos + (y * lgShift2))
            bSrc = PeekF(\addr[5] + pos + (y * lgShift2))
            rDst = alpha * rDst + invAlpha * rSrc
            gDst = alpha * gDst + invAlpha * gSrc
            bDst = alpha * bDst + invAlpha * bSrc
            PokeF(\addr[10] + pos + (y * lgShift2), rDst)
            PokeF(\addr[11] + pos + (y * lgShift2), gDst)
            PokeF(\addr[12] + pos + (y * lgShift2), bDst)
            trans_prev = trans_curr
        Next
        
        For y = ht - 2 To 0 Step -1
            dist = trans_curr - trans_prev + PeekF(\addr[7] + pos + (y * lgShift2))
            alpha = Exp(dist * dist * exp_factor)
            invAlpha = 1.0 - alpha
            rSrc = PeekF(\addr[10] + pos + (y * lgShift2))
            gSrc = PeekF(\addr[11] + pos + (y * lgShift2))
            bSrc = PeekF(\addr[12] + pos + (y * lgShift2))
            rDst = alpha * rDst + invAlpha * rSrc
            gDst = alpha * gDst + invAlpha * gSrc
            bDst = alpha * bDst + invAlpha * bSrc
            PokeF(\addr[10] + pos + (y * lgShift2), rDst)
            PokeF(\addr[11] + pos + (y * lgShift2), gDst)
            PokeF(\addr[12] + pos + (y * lgShift2), bDst)
            trans_curr = trans_prev
            If y > 0 : trans_prev - PeekF(\addr[7] + pos + ((y-1) * lgShift2)) : EndIf
        Next
    Next
  EndWith
EndProcedure

; --- Copie des résultats ---
Procedure DomainTransform_Copy_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[1]
    Protected start = (\thread_pos * total) / \thread_max
    Protected stop = ((\thread_pos + 1) * total) / \thread_max - 1
    Protected i, pos
    
    For i = start To stop
        pos = i << 2
        PokeF(\addr[3] + pos, PeekF(\addr[10] + pos))
        PokeF(\addr[4] + pos, PeekF(\addr[11] + pos))
        PokeF(\addr[5] + pos, PeekF(\addr[12] + pos))
    Next
  EndWith
EndProcedure

; --- Conversion float vers image ---
Procedure DomainTransform_WriteBack_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[1]
    Protected start = (\thread_pos * total) / \thread_max
    Protected stop = ((\thread_pos + 1) * total) / \thread_max - 1
    Protected i, pos, r, g, b, a, col
    
    For i = start To stop
        pos = i << 2
        r = PeekF(\addr[10] + pos) + 0.5
        g = PeekF(\addr[11] + pos) + 0.5
        b = PeekF(\addr[12] + pos) + 0.5
        clamp_rgb(r, g, b)
        col = PeekL(\addr[0] + pos)
        a = (col >> 24) & $FF
        PokeL(\addr[1] + pos, (a << 24) | (r << 16) | (g << 8) | b)
    Next
  EndWith
EndProcedure

; --- Procédure principale renommée ---
Procedure DomainTransformEx(*FilterCtx.FilterParams)
    Restore DomainTransform_data
    Protected last_data = Filter_InitAndValidate()
    If last_data < 0 : ProcedureReturn 0 : EndIf

    With *FilterCtx
      Protected sigma_s.f = \option[0]
      Protected sigma_r.f = \option[1]
      Protected iterations = \option[2]
      Protected size = \image_lg[0] * \image_ht[1] << 2
      Protected i, err = 0

      If sigma_s <= 0.0 : sigma_s = 10.0 : EndIf
      If sigma_r <= 0.0 : sigma_r = 20.0 : EndIf
      If iterations < 1 : iterations = 3 : EndIf
      If iterations > 10 : iterations = 10 : EndIf
      
      \option[0] = sigma_s
      \option[1] = sigma_r

      ;If Filter_BufferPrepare(*FilterCtx.FilterParams) = 0 : ProcedureReturn : EndIf

      For i = 3 To 7
          \addr[i] = AllocateMemory(size)
          If Not \addr[i] : err = 1 : Break : EndIf
      Next
      For i = 10 To 12
          \addr[i] = AllocateMemory(size)
          If Not \addr[i] : err = 1 : Break : EndIf
      Next

      If err
          For i = 3 To 7 : If \addr[i] : FreeMemory(\addr[i]) : EndIf : Next
          For i = 10 To 12 : If \addr[i] : FreeMemory(\addr[i]) : EndIf : Next
          ProcedureReturn
      EndIf

      Create_MultiThread_MT(@DomainTransform_SP0_MT())

      Protected iter
      For iter = 1 To iterations
          Create_MultiThread_MT(@DomainTransform_ComputeDx_MT())
          Create_MultiThread_MT(@DomainTransform_FilterH_MT())
          Create_MultiThread_MT(@DomainTransform_Copy_MT())

          Create_MultiThread_MT(@DomainTransform_ComputeDy_MT())
          Create_MultiThread_MT(@DomainTransform_FilterV_MT())
          If iter < iterations
              Create_MultiThread_MT(@DomainTransform_Copy_MT())
          EndIf
      Next

      Create_MultiThread_MT(@DomainTransform_WriteBack_MT())

      For i = 3 To 7 : FreeMemory(\addr[i]) : Next
      For i = 10 To 12 : FreeMemory(\addr[i]) : Next

      mask_update(*FilterCtx.FilterParams , last_data)
    EndWith
EndProcedure

; --- Nouvelle procédure principale ---
Procedure DomainTransform(source, cible, mask, sigma_s, sigma_r, iterations, mask_type)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = sigma_s
    \option[1] = sigma_r
    \option[2] = iterations
    \option[3] = mask_type
  EndWith
  DomainTransformEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  DomainTransform_data:
  Data.s "DomainTransform (probleme)"
  Data.s "Lissage préservant les contours (Domain Transform)"
  Data.i #FilterType_Blur
  Data.i #Blur_EdgeAware
  
  Data.s "Sigma spatial"
  Data.i 1, 50, 10
  Data.s "Sigma range"
  Data.i 1, 100, 20
  Data.s "Itérations"
  Data.i 1, 10, 3
  Data.s "Masque"
  Data.i 0, 2, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 299
; FirstLine = 277
; Folding = --
; EnableXP
; DPIAware