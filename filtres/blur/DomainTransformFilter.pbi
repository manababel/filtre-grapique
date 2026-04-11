; ---------------------------------------------------
; Domain Transform - Version optimisée
; Edge-preserving filter
; ---------------------------------------------------

; --- Split canaux RGB en buffers float ---
Procedure DomainTransform_SP0_MT(*param.parametre)
    Protected total = *param\lg * *param\ht
    Protected start = (*param\thread_pos * total) / *param\thread_max
    Protected stop = (((*param\thread_pos + 1) * total) / *param\thread_max) - 1
    Protected i, pos, r, g, b, col

    For i = start To stop
        pos = i << 2
        col = PeekL(*param\addr[0] + pos)
        getrgb(col, r, g, b)
        
        PokeF(*param\addr[3] + pos, r)
        PokeF(*param\addr[4] + pos, g)
        PokeF(*param\addr[5] + pos, b)
    Next
EndProcedure

; --- Calcul des dérivées pondérées horizontales ---
Procedure DomainTransform_ComputeDx_MT(*param.parametre)
    Protected lg = *param\lg
    Protected ht = *param\ht
    Protected x, y, pos
    Protected r1.f, g1.f, b1.f, r2.f, g2.f, b2.f
    Protected dr.f, dg.f, db.f, diff.f
    Protected factor.f = *param\option[0] / *param\option[1]
    Protected lgMinus1 = lg - 1
    
    Protected start = (*param\thread_pos * ht) / *param\thread_max
    Protected stop = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
    
    For y = start To stop
        pos = y * lg << 2
        For x = 0 To lgMinus1 - 1
            r1 = PeekF(*param\addr[3] + pos)
            g1 = PeekF(*param\addr[4] + pos)
            b1 = PeekF(*param\addr[5] + pos)

            r2 = PeekF(*param\addr[3] + pos + 4)
            g2 = PeekF(*param\addr[4] + pos + 4)
            b2 = PeekF(*param\addr[5] + pos + 4)

            dr = r1 - r2
            dg = g1 - g2
            db = b1 - b2

            diff = Sqr(dr*dr + dg*dg + db*db)
            PokeF(*param\addr[6] + pos, 1.0 + factor * diff)
            pos + 4
        Next
        PokeF(*param\addr[6] + pos, 0.0)
    Next
EndProcedure

; --- Calcul des dérivées pondérées verticales ---
Procedure DomainTransform_ComputeDy_MT(*param.parametre)
    Protected lg = *param\lg
    Protected ht = *param\ht
    Protected x, y, pos, posNext
    Protected r1.f, g1.f, b1.f, r2.f, g2.f, b2.f
    Protected dr.f, dg.f, db.f, diff.f
    Protected factor.f = *param\option[0] / *param\option[1]
    Protected lgShift2 = lg << 2
    Protected htMinus1 = ht - 1
    
    Protected start = (*param\thread_pos * ht) / *param\thread_max
    Protected stop = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
    
    For y = start To stop
        If y < htMinus1
            pos = y * lg << 2
            posNext = pos + lgShift2
            For x = 0 To lg - 1
                r1 = PeekF(*param\addr[3] + pos)
                g1 = PeekF(*param\addr[4] + pos)
                b1 = PeekF(*param\addr[5] + pos)

                r2 = PeekF(*param\addr[3] + posNext)
                g2 = PeekF(*param\addr[4] + posNext)
                b2 = PeekF(*param\addr[5] + posNext)

                dr = r1 - r2
                dg = g1 - g2
                db = b1 - b2

                diff = Sqr(dr*dr + dg*dg + db*db)
                PokeF(*param\addr[7] + pos, 1.0 + factor * diff)
                pos + 4
                posNext + 4
            Next
        Else
            pos = y * lg << 2
            For x = 0 To lg - 1
                PokeF(*param\addr[7] + pos, 0.0)
                pos + 4
            Next
        EndIf
    Next
EndProcedure

; --- Transformée domaine + filtrage horizontal (fusionnés) ---
Procedure DomainTransform_FilterH_MT(*param.parametre)
    Protected lg = *param\lg
    Protected ht = *param\ht
    Protected x, y, posLine
    Protected sigma.f = *param\option[0]
    Protected exp_factor.f = -1.0 / (2.0 * sigma * sigma)
    Protected alpha.f, dist.f
    Protected trans_prev.f, trans_curr.f
    Protected rSrc.f, gSrc.f, bSrc.f
    Protected rDst.f, gDst.f, bDst.f
    Protected invAlpha.f
    
    Protected start = (*param\thread_pos * ht) / *param\thread_max
    Protected stop = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
    
    For y = start To stop
        posLine = y * lg << 2
        
        ; Initialiser première colonne
        rDst = PeekF(*param\addr[3] + posLine)
        gDst = PeekF(*param\addr[4] + posLine)
        bDst = PeekF(*param\addr[5] + posLine)
        PokeF(*param\addr[10] + posLine, rDst)
        PokeF(*param\addr[11] + posLine, gDst)
        PokeF(*param\addr[12] + posLine, bDst)
        
        trans_prev = 0.0
        
        ; Gauche → droite
        For x = 1 To lg - 1
            trans_curr = trans_prev + PeekF(*param\addr[6] + posLine + ((x-1) << 2))
            dist = trans_curr - trans_prev
            alpha = Exp(dist * dist * exp_factor)
            invAlpha = 1.0 - alpha
            
            rSrc = PeekF(*param\addr[3] + posLine + (x << 2))
            gSrc = PeekF(*param\addr[4] + posLine + (x << 2))
            bSrc = PeekF(*param\addr[5] + posLine + (x << 2))
            
            rDst = alpha * rDst + invAlpha * rSrc
            gDst = alpha * gDst + invAlpha * gSrc
            bDst = alpha * bDst + invAlpha * bSrc
            
            PokeF(*param\addr[10] + posLine + (x << 2), rDst)
            PokeF(*param\addr[11] + posLine + (x << 2), gDst)
            PokeF(*param\addr[12] + posLine + (x << 2), bDst)
            
            trans_prev = trans_curr
        Next
        
        ; Droite → gauche
        For x = lg - 2 To 0 Step -1
            dist = trans_curr - trans_prev + PeekF(*param\addr[6] + posLine + (x << 2))
            alpha = Exp(dist * dist * exp_factor)
            invAlpha = 1.0 - alpha
            
            rSrc = PeekF(*param\addr[10] + posLine + (x << 2))
            gSrc = PeekF(*param\addr[11] + posLine + (x << 2))
            bSrc = PeekF(*param\addr[12] + posLine + (x << 2))
            
            rDst = alpha * rDst + invAlpha * rSrc
            gDst = alpha * gDst + invAlpha * gSrc
            bDst = alpha * bDst + invAlpha * bSrc
            
            PokeF(*param\addr[10] + posLine + (x << 2), rDst)
            PokeF(*param\addr[11] + posLine + (x << 2), gDst)
            PokeF(*param\addr[12] + posLine + (x << 2), bDst)
            
            trans_curr = trans_prev
            If x > 0
                trans_prev - PeekF(*param\addr[6] + posLine + ((x-1) << 2))
            EndIf
        Next
    Next
EndProcedure

; --- Transformée domaine + filtrage vertical (fusionnés) ---
Procedure DomainTransform_FilterV_MT(*param.parametre)
    Protected lg = *param\lg
    Protected ht = *param\ht
    Protected x, y, pos
    Protected sigma.f = *param\option[0]
    Protected exp_factor.f = -1.0 / (2.0 * sigma * sigma)
    Protected alpha.f, dist.f
    Protected trans_prev.f, trans_curr.f
    Protected rSrc.f, gSrc.f, bSrc.f
    Protected rDst.f, gDst.f, bDst.f
    Protected invAlpha.f
    Protected lgShift2 = lg << 2
    
    Protected start = (*param\thread_pos * lg) / *param\thread_max
    Protected stop = ((*param\thread_pos + 1) * lg) / *param\thread_max - 1
    
    For x = start To stop
        pos = x << 2
        
        ; Initialiser première ligne
        rDst = PeekF(*param\addr[3] + pos)
        gDst = PeekF(*param\addr[4] + pos)
        bDst = PeekF(*param\addr[5] + pos)
        PokeF(*param\addr[10] + pos, rDst)
        PokeF(*param\addr[11] + pos, gDst)
        PokeF(*param\addr[12] + pos, bDst)
        
        trans_prev = 0.0
        
        ; Haut → bas
        For y = 1 To ht - 1
            trans_curr = trans_prev + PeekF(*param\addr[7] + pos + ((y-1) * lgShift2))
            dist = trans_curr - trans_prev
            alpha = Exp(dist * dist * exp_factor)
            invAlpha = 1.0 - alpha
            
            rSrc = PeekF(*param\addr[3] + pos + (y * lgShift2))
            gSrc = PeekF(*param\addr[4] + pos + (y * lgShift2))
            bSrc = PeekF(*param\addr[5] + pos + (y * lgShift2))
            
            rDst = alpha * rDst + invAlpha * rSrc
            gDst = alpha * gDst + invAlpha * gSrc
            bDst = alpha * bDst + invAlpha * bSrc
            
            PokeF(*param\addr[10] + pos + (y * lgShift2), rDst)
            PokeF(*param\addr[11] + pos + (y * lgShift2), gDst)
            PokeF(*param\addr[12] + pos + (y * lgShift2), bDst)
            
            trans_prev = trans_curr
        Next
        
        ; Bas → haut
        For y = ht - 2 To 0 Step -1
            dist = trans_curr - trans_prev + PeekF(*param\addr[7] + pos + (y * lgShift2))
            alpha = Exp(dist * dist * exp_factor)
            invAlpha = 1.0 - alpha
            
            rSrc = PeekF(*param\addr[10] + pos + (y * lgShift2))
            gSrc = PeekF(*param\addr[11] + pos + (y * lgShift2))
            bSrc = PeekF(*param\addr[12] + pos + (y * lgShift2))
            
            rDst = alpha * rDst + invAlpha * rSrc
            gDst = alpha * gDst + invAlpha * gSrc
            bDst = alpha * bDst + invAlpha * bSrc
            
            PokeF(*param\addr[10] + pos + (y * lgShift2), rDst)
            PokeF(*param\addr[11] + pos + (y * lgShift2), gDst)
            PokeF(*param\addr[12] + pos + (y * lgShift2), bDst)
            
            trans_curr = trans_prev
            If y > 0
                trans_prev - PeekF(*param\addr[7] + pos + ((y-1) * lgShift2))
            EndIf
        Next
    Next
EndProcedure

; --- Copie des résultats ---
Procedure DomainTransform_Copy_MT(*param.parametre)
    Protected total = *param\lg * *param\ht
    Protected start = (*param\thread_pos * total) / *param\thread_max
    Protected stop = ((*param\thread_pos + 1) * total) / *param\thread_max - 1
    Protected i, pos
    
    For i = start To stop
        pos = i << 2
        PokeF(*param\addr[3] + pos, PeekF(*param\addr[10] + pos))
        PokeF(*param\addr[4] + pos, PeekF(*param\addr[11] + pos))
        PokeF(*param\addr[5] + pos, PeekF(*param\addr[12] + pos))
    Next
EndProcedure

; --- Conversion float vers image ---
Procedure DomainTransform_WriteBack_MT(*param.parametre)
    Protected total = *param\lg * *param\ht
    Protected start = (*param\thread_pos * total) / *param\thread_max
    Protected stop = ((*param\thread_pos + 1) * total) / *param\thread_max - 1
    Protected i, pos, r, g, b, a, col
    
    For i = start To stop
        pos = i << 2
        
        r = PeekF(*param\addr[10] + pos) + 0.5
        g = PeekF(*param\addr[11] + pos) + 0.5
        b = PeekF(*param\addr[12] + pos) + 0.5
        
        clamp_rgb(r, g, b)
        
        col = PeekL(*param\addr[0] + pos)
        a = (col >> 24) & $FF
        
        PokeL(*param\addr[1] + pos, (a << 24) | (r << 16) | (g << 8) | b)
    Next
EndProcedure

; --- Procédure principale ---
Procedure DomainTransform(*param.parametre)
    If *param\info_active
        *param\typ      = #FilterType_Blur
        *param\subtype  = #Blur_EdgeAware
        *param\name     = "DomainTransform"
        *param\remarque = "Lissage préservant les contours (Domain Transform) ne marche pas"
        *param\info[0]  = "Sigma spatial"
        *param\info[1]  = "Sigma range"
        *param\info[2]  = "Itérations"
        *param\info[3]  = "Masque"
        *param\info_data(0,0) = 1.0  : *param\info_data(0,1) = 50.0 : *param\info_data(0,2) = 10.0
        *param\info_data(1,0) = 1.0  : *param\info_data(1,1) = 100.0 : *param\info_data(1,2) = 20.0
        *param\info_data(2,0) = 1    : *param\info_data(2,1) = 10    : *param\info_data(2,2) = 3
        *param\info_data(3,0) = 0    : *param\info_data(3,1) = 2     : *param\info_data(3,2) = 0
        ProcedureReturn
    EndIf

    If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf

    Protected sigma_s.f = *param\option[0]
    Protected sigma_r.f = *param\option[1]
    Protected iterations = *param\option[2]
    Protected size = *param\lg * *param\ht << 2
    Protected i, err = 0

    If sigma_s <= 0.0 : sigma_s = 10.0 : EndIf
    If sigma_r <= 0.0 : sigma_r = 20.0 : EndIf
    If iterations < 1 : iterations = 3 : EndIf
    If iterations > 10 : iterations = 10 : EndIf
    
    *param\option[0] = sigma_s
    *param\option[1] = sigma_r

    If Filter_BufferPrepare(*param.parametre) = 0 : ProcedureReturn : EndIf

    ; Allocation mémoire
    ; addr[3-5] = RGB courant (float)
    ; addr[6] = dx (poids horizontaux)
    ; addr[7] = dy (poids verticaux)
    ; addr[10-12] = RGB sortie (float)
    
    For i = 3 To 7
        *param\addr[i] = AllocateMemory(size)
        If Not *param\addr[i] : err = 1 : Break : EndIf
    Next
    For i = 10 To 12
        *param\addr[i] = AllocateMemory(size)
        If Not *param\addr[i] : err = 1 : Break : EndIf
    Next

    If err
        For i = 3 To 7 : If *param\addr[i] : FreeMemory(*param\addr[i]) : EndIf : Next
        For i = 10 To 12 : If *param\addr[i] : FreeMemory(*param\addr[i]) : EndIf : Next
        ProcedureReturn
    EndIf

    ; Extraire les canaux RGB
    MultiThread_MT(@DomainTransform_SP0_MT())

    ; Boucle d'itérations
    Protected iter
    For iter = 1 To iterations
        ; Passe horizontale
        MultiThread_MT(@DomainTransform_ComputeDx_MT())
        MultiThread_MT(@DomainTransform_FilterH_MT())
        MultiThread_MT(@DomainTransform_Copy_MT())

        ; Passe verticale
        MultiThread_MT(@DomainTransform_ComputeDy_MT())
        MultiThread_MT(@DomainTransform_FilterV_MT())
        If iter < iterations
            MultiThread_MT(@DomainTransform_Copy_MT())
        EndIf
    Next

    ; Convertir vers l'image de sortie
    MultiThread_MT(@DomainTransform_WriteBack_MT())

    ; Libération
    For i = 3 To 7 : FreeMemory(*param\addr[i]) : Next
    For i = 10 To 12 : FreeMemory(*param\addr[i]) : Next

    ; Masque
    If *param\mask And *param\option[3]
        *param\mask_type = *param\option[3] - 1
        MultiThread_MT(@_mask())
    EndIf
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 315
; FirstLine = 281
; Folding = --
; EnableXP
; DPIAware