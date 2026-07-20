
Procedure WLSBlur_Init_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *adr0.pixelarray  = \addr[0]
    Protected *adr2.floatarray  = \addr[2]
    Protected *adr5.floatarray  = \addr[5]
    Protected *adr6.floatarray  = \addr[6]
    Protected *adr7.floatarray  = \addr[7]
    Protected *adr8.floatarray  = \addr[8]
    Protected *adr9.floatarray  = \addr[9]
    Protected *adr10.floatarray = \addr[10]
    
    Protected *adr15.floatarray = \addr[15]
    Protected *adr16.floatarray = \addr[16]
    Protected *adr17.floatarray = \addr[17]
    
    Protected total = \image_lg[0] * \image_ht[0]
    Protected i, r, g, b
    Protected offset, taille_octets
   
    macro_calul_tread(total)
    
    ; 1. Boucle ultra-allégée (seulement 4 écritures au lieu de 7)
    For i = thread_start To thread_stop - 1
      getrgb(*adr0\l[i] , r , g , b)
      ;*adr2\f[i] = 0.299 * r + 0.587 * g + 0.114 * b
      *adr2\f[i] = *adr15\f[r] + *adr16\f[g] + *adr17\f[b]
      *adr5\f[i] = r
      *adr6\f[i] = g
      *adr7\f[i] = b
    Next
    
    ; 2. Duplication par bloc via CopyMemory pour ce Thread
    offset = thread_start * 4
    taille_octets = (thread_stop - thread_start) * 4 ; (Pas de "-1" ici, on veut la taille exacte)
    CopyMemory(*adr5 + offset, *adr8 + offset,  taille_octets) ; Rouge -> adr8
    CopyMemory(*adr6 + offset, *adr9 + offset,  taille_octets) ; Vert  -> adr9
    CopyMemory(*adr7 + offset, *adr10 + offset, taille_octets) ; Bleu  -> adr10

  EndWith
EndProcedure

Procedure WLSBlur_ComputeWeights_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.floatarray = \addr[2]
    Protected *cible1.floatarray = \addr[3]
    Protected *cible2.floatarray = \addr[4]
    Protected *lut.floatarray    = \addr[14]
    
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y, idx
    Protected L_here.f, L_right.f, L_down.f
    Protected grad_x.f, grad_y.f, wx.f, wy.f
    Protected lgMinus1 = lg - 1
    Protected htMinus1 = ht - 1
    Protected idx_lut.i
   
    macro_calul_tread(ht)
    
    ; On ajuste la borne de fin pour traiter la toute dernière ligne de l'image à part
    Protected end_y = thread_stop - 1
    Protected handle_last_line = #False
    If end_y >= htMinus1
      end_y = htMinus1 - 1
      handle_last_line = #True
    EndIf
    
    ; 1. BOUCLE PRINCIPALE : Lignes de 0 à ht-2 (Zéro condition 'If' à l'intérieur !)
    For y = thread_start To end_y  
      idx = y * lg ; Calculé une seule fois par ligne au lieu de par pixel
      
      For x = 0 To lgMinus1 - 1
        L_here = *source\f[idx]
        
        ; --- Poids horizontal ---
        L_right = *source\f[idx + 1]
        grad_x = Abs(L_right - L_here)
        
        idx_lut = Int(grad_x * 10.0)
        If idx_lut > 2550 : idx_lut = 2550 : EndIf
        *cible1\f[idx] = *lut\f[idx_lut]
        
        ; --- Poids vertical (Garanti sans débordement ici) ---
        L_down = *source\f[idx + lg]
        grad_y = Abs(L_down - L_here)
        
        idx_lut = Int(grad_y * 10.0)
        If idx_lut > 2550 : idx_lut = 2550 : EndIf
        *cible2\f[idx] = *lut\f[idx_lut]
        
        idx + 1 ; On avance l'index de 1 (simple addition)
      Next
      *cible1\f[idx] = 0 ; Gère le pixel lg-1 de la ligne
    Next
    
    ; 2. TRAITEMENT DE LA DERNIÈRE LIGNE (Uniquement si ce thread s'en occupe)
    If handle_last_line
      idx = htMinus1 * lg
      For x = 0 To lgMinus1 - 1
        L_here = *source\f[idx]
        L_right = *source\f[idx + 1]
        grad_x = Abs(L_right - L_here)
        
        idx_lut = Int(grad_x * 10.0)
        If idx_lut > 2550 : idx_lut = 2550 : EndIf
        *cible1\f[idx] = *lut\f[idx_lut]
        
        *cible2\f[idx] = 0.0 ; wy est forcé à 0 sur la dernière ligne
        idx + 1
      Next
      *cible1\f[idx] = 0
    EndIf
    
  EndWith
EndProcedure

Procedure WLSBlur_Jacobi_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected lambda.f = \option[0]
    Protected channel = \option[5]
    Protected x, y, idx
    Protected val.f, sum.f, diag.f
    Protected wx_here.f, wx_left.f, wy_here.f, wy_up.f
    Protected lgMinus1 = lg - 1
    Protected htMinus1 = ht - 1

    macro_calul_tread(ht) 
        
    Protected *input.FloatArray   = \addr[5 + channel]
    Protected *current.FloatArray = \addr[8 + channel]
    Protected *next.FloatArray    = \addr[11 + channel]
    Protected *wx.FloatArray      = \addr[3]
    Protected *wy.FloatArray      = \addr[4]
    
    For y = thread_start To thread_stop - 1
      ; Index de départ pour le début de la ligne active
      Protected line_start_idx = y * lg
      
      ; =======================================================================
      ; 1. PREMIER PIXEL DE LA LIGNE (x = 0)
      ; =======================================================================
      idx = line_start_idx
      sum  = *input\f[idx]
      diag = 1.0
      
      ; Droite (x < lgMinus1 est garanti si l'image fait plus de 1 pixel de large)
      wx_here = *wx\f[idx]
      sum  + lambda * wx_here * *current\f[idx + 1]
      diag + lambda * wx_here
      
      ; Haut & Bas
      If y > 0
        wy_up = *wy\f[idx - lg]
        sum  + lambda * wy_up * *current\f[idx - lg]
        diag + lambda * wy_up
      EndIf
      If y < htMinus1
        wy_here = *wy\f[idx]
        sum  + lambda * wy_here * *current\f[idx + lg]
        diag + lambda * wy_here
      EndIf
      *next\f[idx] = sum / diag
      
      ; =======================================================================
      ; 2. CŒUR DE LA LIGNE (x = 1 À lgMinus1 - 1) -> ZÉRO "IF" SUR X !
      ; =======================================================================
      ; On initialise un pointeur d'index qui va simplement s'incrémenter
      idx = line_start_idx + 1
      
      ; Pour optimiser les accès Y, on pré-calcule les décalages de lignes
      Protected idx_up = idx - lg
      Protected idx_down = idx + lg
      
      ; On crée deux variables pour éviter de répéter les "If y" dans la boucle interne
      Protected has_up = Bool(y > 0)
      Protected has_down = Bool(y < htMinus1)
      
      For x = 1 To lgMinus1 - 1
        sum  = *input\f[idx]
        diag = 1.0
        
        ; Gauche (Puisque x > 0)
        wx_left = *wx\f[idx - 1]
        sum  + lambda * wx_left * *current\f[idx - 1]
        diag + lambda * wx_left
        
        ; Droite (Puisque x < lgMinus1)
        wx_here = *wx\f[idx]
        sum  + lambda * wx_here * *current\f[idx + 1]
        diag + lambda * wx_here
        
        ; Haut
        If has_up
          wy_up = *wy\f[idx_up]
          sum  + lambda * wy_up * *current\f[idx_up]
          diag + lambda * wy_up
        EndIf
        
        ; Bas
        If has_down
          wy_here = *wy\f[idx]
          sum  + lambda * wy_here * *current\f[idx_down]
          diag + lambda * wy_here
        EndIf
        
        *next\f[idx] = sum / diag
        
        ; Incrémentation ultra-rapide de tous nos index en même temps
        idx + 1
        idx_up + 1
        idx_down + 1
      Next
      
      ; =======================================================================
      ; 3. DERNIER PIXEL DE LA LIGNE (x = lgMinus1)
      ; =======================================================================
      idx = line_start_idx + lgMinus1
      sum  = *input\f[idx]
      diag = 1.0
      
      ; Gauche (Puisque x > 0 est garanti)
      wx_left = *wx\f[idx - 1]
      sum  + lambda * wx_left * *current\f[idx - 1]
      diag + lambda * wx_left
      
      ; Haut & Bas
      If y > 0
        wy_up = *wy\f[idx - lg]
        sum  + lambda * wy_up * *current\f[idx - lg]
        diag + lambda * wy_up
      EndIf
      If y < htMinus1
        wy_here = *wy\f[idx]
        sum  + lambda * wy_here * *current\f[idx + lg]
        diag + lambda * wy_here
      EndIf
      *next\f[idx] = sum / diag
      
    Next y
  EndWith
EndProcedure

Procedure WLSBlur_Copy_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected total = lg * ht
    Protected channel = \option[5]
    Protected dif
    Protected *src = (\addr[11 + channel])
    Protected *dst = (\addr[8 + channel] )
    
    macro_calul_tread(total)
    
    dif = (thread_stop - thread_start)
    CopyMemory(*src + thread_start * 4 , *dst + thread_start * 4, dif * 4)

  EndWith
EndProcedure


Procedure WLSBlur_WriteBack_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *adr0.pixelarray  = \addr[0]
    Protected *adr1.pixelarray  = \addr[1]
    Protected *adr8.floatarray  = \addr[8]
    Protected *adr9.floatarray  = \addr[9]
    Protected *adr10.floatarray = \addr[10]
    Protected total = \image_lg[0] * \image_ht[0]
    Protected r2, g2, b2, idx
   
    macro_calul_tread(total)
    
    For idx = thread_start To thread_stop - 1
      r2 = *adr8\f[idx]  + 0.5
      g2 = *adr9\f[idx]  + 0.5
      b2 = *adr10\f[idx] + 0.5
      clamp_rgb(r2, g2, b2)
      *adr1\l[idx] = (*adr0\l[idx] & $ff000000) | (r2 << 16) | (g2 << 8) | b2
    Next
  EndWith
EndProcedure

; --- Cycle Principal ---

Macro WLSBlurEx_sp0(opt)
  
    ; 1. Init & Weights
    Create_MultiThread_MT(@WLSBlur_Init_MT_#opt())
    Create_MultiThread_MT(@WLSBlur_ComputeWeights_MT_#opt())

    ; 2. Jacobi Iterations
    For iter = 1 To iterations
      For channel = 0 To 2
        *FilterCtx\option[5] = channel
        Create_MultiThread_MT(@WLSBlur_Jacobi_MT_#opt())
        Create_MultiThread_MT(@WLSBlur_Copy_MT_#opt())
      Next
    Next
    
    ; 3. Finalize
    t = ElapsedMilliseconds()
    Create_MultiThread_MT(@WLSBlur_WriteBack_MT_#opt())
    *FilterCtx\tmp = ElapsedMilliseconds() - t
EndMacro

Procedure WLSBlurEx(*FilterCtx.FilterParams)
  Restore WLSBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    
    \option[0] * 0.1
    \option[1] * 0.1
    
    Protected size = \image_lg[0] * \image_ht[0] * 4
    Protected i, err = 0
    For i = 2 To 13
      \addr[i] = AllocateMemory(size)
      If Not \addr[i] : err = 1 : EndIf
    Next
    
    If err
      For i = 2 To 13 : If \addr[i] : FreeMemory(\addr[i]) : EndIf : Next
      ProcedureReturn 0
    EndIf
    
    Protected size_lut = 2555 * 4
    \addr[14] = AllocateMemory(size_lut)
    If \addr[14]
      Protected *lut.floatarray = \addr[14]
      Protected g_idx
      Protected grad_val.f
      Protected alpha_lut.f = \option[1]
      
      ; Remplissage de la table
      ; L'index correspond à : gradient * 10
      For g_idx = 0 To 2550
        grad_val = g_idx / 10.0
        *lut\f[g_idx] = 1.0 / Pow(grad_val + 0.001, alpha_lut)
      Next
    EndIf
    
    \addr[15] = AllocateMemory(256 * 4)
    \addr[16] = AllocateMemory(256 * 4)
    \addr[17] = AllocateMemory(256 * 4)
    Protected *adr15.floatarray = \addr[15]
    Protected *adr16.floatarray = \addr[16]
    Protected *adr17.floatarray = \addr[17]
    For i = 0 To 255
      *adr15\f[i] = 0.299 * i
      *adr16\f[i] = 0.587 * i
      *adr17\f[i] = 0.114 * i
    Next
    
    Protected t.q
    Protected iter, channel
    Protected iterations = *FilterCtx\option[2]
    
    CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
      WLSBlurEx_sp0(PB)
    CompilerElse
      
      CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
        Select FilterCtx\Asm
          Case 1 : WLSBlurEx_sp0(SSE2)
          ;Case 2 : WLSBlurEx_sp0()
          ;Case 3 : WLSBlurEx_sp0()
          ;Case 4 : WLSBlurEx_sp0()
          Default : WLSBlurEx_sp0(PB)
        EndSelect
      CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
        Select FilterCtx\Asm
            ;Case 1 :WLSBlurEx_sp0()
            ;Case 2 : WLSBlurEx_sp0()
            ;Case 3 : WLSBlurEx_sp0()
            ;Case 4 : WLSBlurEx_sp0()
          Case 100
          Default : WLSBlurEx_sp0(PB)
        EndSelect
      CompilerEndIf
    CompilerEndIf
    
    ; Cleanup
    For i = 2 To 17
      If \addr[i]
        FreeMemory(\addr[i]) 
        \addr[i] = 0 
      EndIf
    Next
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure WLSBlur(source, cible, mask, lambda.f, alpha.f, iterations)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = lambda
    \option[1] = alpha
    \option[2] = iterations
  EndWith
  WLSBlurEx(FilterCtx)
EndProcedure

DataSection
  WLSBlur_data:
  Data.s "WLSBlur"
  Data.s "Lissage Weighted Least Squares (Jacobi)"
  Data.i #FilterType_Blur
  Data.i #Blur_EdgeAware
  Data.s "Lambda (Force)"
  Data.i 1, 100, 10
  Data.s "Alpha (Contours)"
  Data.i 5, 30, 12
  Data.s "Itérations"
  Data.i 1, 50, 10
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 406
; FirstLine = 369
; Folding = --
; EnableXP
; DPIAware