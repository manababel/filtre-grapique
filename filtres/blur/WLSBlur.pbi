; ---------------------------------------------------
; WLSBlur (Weighted Least Squares) - Version Jacobi
; Edge-preserving smoothing - Thread-safe
; ---------------------------------------------------

; --- Calcul des poids basés sur les gradients de luminance
Procedure WLSBlur_ComputeWeights_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected alpha.f = *param\option[1]
  Protected x, y, idx, offset
  Protected L_here.f, L_right.f, L_down.f
  Protected grad_x.f, grad_y.f, wx.f, wy.f
  Protected lgMinus1 = lg - 1
  Protected htMinus1 = ht - 1
  Protected lgShift2 = lg << 2
  
  Protected start = (*param\thread_pos * ht) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  
  For y = start To stop
    For x = 0 To lgMinus1
      idx = y * lg + x
      offset = idx << 2
      L_here = PeekF(*param\addr[2] + offset)
      
      ; Poids horizontal
      If x < lgMinus1
        L_right = PeekF(*param\addr[2] + offset + 4)
        grad_x = Abs(L_right - L_here)
        wx = 1.0 / (Pow(grad_x + 0.001, alpha))
      Else
        wx = 0.0
      EndIf
      PokeF(*param\addr[3] + offset, wx)
      
      ; Poids vertical
      If y < htMinus1
        L_down = PeekF(*param\addr[2] + offset + lgShift2)
        grad_y = Abs(L_down - L_here)
        wy = 1.0 / (Pow(grad_y + 0.001, alpha))
      Else
        wy = 0.0
      EndIf
      PokeF(*param\addr[4] + offset, wy)
    Next
  Next
EndProcedure

; --- Itération de Jacobi (thread-safe)
Procedure WLSBlur_Jacobi_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected lambda.f = *param\option[0]
  Protected channel = *param\option[5]
  Protected x, y, idx, offset
  Protected val.f, sum.f, diag.f
  Protected wx_here.f, wx_left.f, wy_here.f, wy_up.f
  Protected left.f, right.f, up.f, down.f
  Protected lgMinus1 = lg - 1
  Protected htMinus1 = ht - 1
  Protected lgShift2 = lg << 2
  
  Protected *input = *param\addr[5 + channel]      ; valeurs originales
  Protected *current = *param\addr[8 + channel]    ; buffer de lecture
  Protected *next = *param\addr[11 + channel]      ; buffer d'écriture
  Protected *wx = *param\addr[3]
  Protected *wy = *param\addr[4]
  
  Protected start = (*param\thread_pos * ht) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  
  For y = start To stop
    For x = 0 To lgMinus1
      idx = y * lg + x
      offset = idx << 2
      
      ; Valeur originale
      val = PeekF(*input + offset)
      sum = val
      diag = 1.0
      
      ; Voisin gauche (lire depuis *current)
      If x > 0
        wx_left = PeekF(*wx + offset - 4)
        left = PeekF(*current + offset - 4)
        sum + lambda * wx_left * left
        diag + lambda * wx_left
      EndIf
      
      ; Voisin droit
      If x < lgMinus1
        wx_here = PeekF(*wx + offset)
        right = PeekF(*current + offset + 4)
        sum + lambda * wx_here * right
        diag + lambda * wx_here
      EndIf
      
      ; Voisin haut
      If y > 0
        wy_up = PeekF(*wy + offset - lgShift2)
        up = PeekF(*current + offset - lgShift2)
        sum + lambda * wy_up * up
        diag + lambda * wy_up
      EndIf
      
      ; Voisin bas
      If y < htMinus1
        wy_here = PeekF(*wy + offset)
        down = PeekF(*current + offset + lgShift2)
        sum + lambda * wy_here * down
        diag + lambda * wy_here
      EndIf
      
      ; Écrire dans le buffer de sortie
      PokeF(*next + offset, sum / diag)
    Next
  Next
EndProcedure

; --- Copie de buffer
Procedure WLSBlur_Copy_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected total = lg * ht
  Protected channel = *param\option[5]
  Protected i, offset
  
  Protected *src = *param\addr[11 + channel]
  Protected *dst = *param\addr[8 + channel]
  
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * total) / *param\thread_max - 1
  
  For i = start To stop
    offset = i << 2
    PokeF(*dst + offset, PeekF(*src + offset))
  Next
EndProcedure

; --- Initialisation
Procedure WLSBlur_Init_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected total = lg * ht
  Protected i, offset, r, g, b, col
  
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * total) / *param\thread_max - 1
  
  For i = start To stop
    offset = i << 2
    col = PeekL(*param\addr[0] + offset)
    getrgb(col, r, g, b)
    
    PokeF(*param\addr[2] + offset, 0.299 * r + 0.587 * g + 0.114 * b)
    PokeF(*param\addr[5] + offset, r)
    PokeF(*param\addr[6] + offset, g)
    PokeF(*param\addr[7] + offset, b)
    PokeF(*param\addr[8] + offset, r)
    PokeF(*param\addr[9] + offset, g)
    PokeF(*param\addr[10] + offset, b)
  Next
EndProcedure

; --- Écriture du résultat
Procedure WLSBlur_WriteBack_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected n = lg * ht
  Protected a2, r2, g2, b2, idx, offset, col
  
  Protected start = (*param\thread_pos * n) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * n) / *param\thread_max - 1
  
  For idx = start To stop
    offset = idx << 2
    
    r2 = PeekF(*param\addr[8] + offset) + 0.5
    g2 = PeekF(*param\addr[9] + offset) + 0.5
    b2 = PeekF(*param\addr[10] + offset) + 0.5
    
    clamp_rgb(r2, g2, b2)
    
    col = PeekL(*param\addr[0] + offset)
    a2 = (col >> 24) & $FF
    
    PokeL(*param\addr[1] + offset, (a2 << 24) | (r2 << 16) | (g2 << 8) | b2)
  Next
EndProcedure

; --- Procédure principale
Procedure WLSBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_EdgeAware
    *param\name = "WLSBlur"
    *param\remarque = "Lissage préservant les contours (Weighted Least Squares) na marche pas"
    *param\info[0] = "Lambda (force)"
    *param\info[1] = "Alpha (contours)"
    *param\info[2] = "Itérations"
    *param\info[3] = "Masque"
    *param\info_data(0,0) = 0.1 : *param\info_data(0,1) = 10.0 : *param\info_data(0,2) = 1.0
    *param\info_data(1,0) = 0.5 : *param\info_data(1,1) = 3.0  : *param\info_data(1,2) = 1.2
    *param\info_data(2,0) = 1   : *param\info_data(2,1) = 50   : *param\info_data(2,2) = 10
    *param\info_data(3,0) = 0   : *param\info_data(3,1) = 2    : *param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected lambda.f = *param\option[0]
  Protected alpha.f = *param\option[1]
  Protected iterations = *param\option[2]
  
  If lambda <= 0.0 : lambda = 1.0 : EndIf
  If alpha <= 0.0 : alpha = 1.2 : EndIf
  If iterations < 1 : iterations = 10 : EndIf
  If iterations > 50 : iterations = 50 : EndIf
  
  *param\option[0] = lambda
  *param\option[1] = alpha
  *param\option[2] = iterations
  
  If Filter_BufferPrepare(*param.parametre) = 0 : ProcedureReturn : EndIf
  
  Protected w = *param\lg
  Protected h = *param\ht
  Protected n = w * h
  Protected size = n << 2
  
  ; Allocation buffers
  ; addr[2] = luminance
  ; addr[3] = poids wx
  ; addr[4] = poids wy
  ; addr[5-7] = RGB input (constants)
  ; addr[8-10] = RGB current
  ; addr[11-13] = RGB next (buffers temporaires)
  
  Protected i
  For i = 2 To 13
    *param\addr[i] = AllocateMemory(size)
    If Not *param\addr[i]
      For i = 2 To 13
        If *param\addr[i] : FreeMemory(*param\addr[i]) : EndIf
      Next
      ProcedureReturn
    EndIf
  Next
  
  ; 1. Initialisation
  MultiThread_MT(@WLSBlur_Init_MT())
  
  ; 2. Calculer les poids
  MultiThread_MT(@WLSBlur_ComputeWeights_MT())
  
  ; 3. Itérations Jacobi
  Protected iter
  For iter = 1 To iterations
    ; Rouge
    *param\option[5] = 0
    MultiThread_MT(@WLSBlur_Jacobi_MT())
    MultiThread_MT(@WLSBlur_Copy_MT())
    
    ; Vert
    *param\option[5] = 1
    MultiThread_MT(@WLSBlur_Jacobi_MT())
    MultiThread_MT(@WLSBlur_Copy_MT())
    
    ; Bleu
    *param\option[5] = 2
    MultiThread_MT(@WLSBlur_Jacobi_MT())
    MultiThread_MT(@WLSBlur_Copy_MT())
  Next
  
  ; 4. Écrire résultat
  MultiThread_MT(@WLSBlur_WriteBack_MT())
  
  ; 5. Libération
  For i = 2 To 13
    FreeMemory(*param\addr[i])
  Next
  
  ; 6. Masque
  If *param\mask And *param\option[3]
    *param\mask_type = *param\option[3] - 1
    MultiThread_MT(@_mask())
  EndIf
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 207
; FirstLine = 177
; Folding = --
; EnableXP
; DPIAware