; ---------------------------------------------------
; Domain Transform - Version Sécurisée Intégrale
; ---------------------------------------------------

; --- Split canaux RGB ---
Procedure DomainTransform_Image_IntToFloat_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *adr0.PixelArray = \addr[0]    
    Protected *adr13.FloatArray = \addr[3]
    Protected total = \image_lg[0] * \image_ht[1]
    Protected i, r, g, b , index
    macro_calul_tread(total)
    For i = thread_start To thread_stop - 1
      getrgb(*adr0\l[i], r, g, b)
      index = i * 4
      *adr13\f[index + 2] = r
      *adr13\f[index + 1] = g
      *adr13\f[index + 0] = b
    Next
  EndWith
EndProcedure

; --- Calcul Dx ---
Procedure DomainTransform_ComputeDx_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *adr6.FloatArray = \addr[5]
    Protected *adr13.FloatArray = \addr[3]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, pos, idx
    Protected.f dr, dg, db, diff
    Protected.f factor = 1.0 / \option[1] 
    Protected lgMinus1 = lg - 1
    macro_calul_tread(ht)
    For y = thread_start To thread_stop - 1
      pos = y * lg
      For x = 0 To lgMinus1 - 1
        idx = pos * 4
        dr = *adr13\f[idx + 2] - *adr13\f[idx + 6]
        dg = *adr13\f[idx + 1] - *adr13\f[idx + 5]
        db = *adr13\f[idx + 0] - *adr13\f[idx + 4]
        diff = Abs(dr) + Abs(dg) + Abs(db)
        *adr6\f[pos] = 1.0 + factor * diff
        pos + 1
      Next
      *adr6\f[pos] = 1.0 
    Next
  EndWith
EndProcedure

; --- Calcul Dy ---
Procedure DomainTransform_ComputeDy_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *adr7.FloatArray = \addr[6]
    Protected *adr13.FloatArray = \addr[3]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, pos, idx
    Protected.f dr, dg, db, diff
    Protected.f factor = 1.0 / \option[1]
    Protected htMinus1 = ht - 1
    Protected stride = lg * 4
    macro_calul_tread(ht)
    For y = thread_start To thread_stop - 1
      pos = y * lg
      If y = htMinus1
        For x = 0 To lg - 1
          *adr7\f[pos] = 1.0
          pos + 1
        Next
      Else
        For x = 0 To lg - 1
          idx = pos * 4
          dr = *adr13\f[idx + 2] - *adr13\f[idx + stride + 2]
          dg = *adr13\f[idx + 1] - *adr13\f[idx + stride + 1]
          db = *adr13\f[idx + 0] - *adr13\f[idx + stride + 0]
          diff = Abs(dr) + Abs(dg) + Abs(db)
          *adr7\f[pos] = 1.0 + factor * diff
          pos + 1
        Next
      EndIf
    Next
  EndWith
EndProcedure

; --- Filtre Horizontal Indexé (Zéro risque de plantage) ---
Procedure DomainTransform_FilterH_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, pos, idx
    Protected.f sigma = \option[0]
    Protected.f exp_factor = -1.0 / (1.41421356 * sigma)
    Protected.f alpha, dist, invAlpha
    Protected.f prev_r, prev_g, prev_b
    ; --- Entrées et Sorties au format entrelacé à 4 floats ---
    Protected *adr13.FloatArray = \addr[3]
    Protected *adr14.FloatArray = \addr[4]
    ; --- Distances (Dx) ---
    Protected *adr6.FloatArray = \addr[5]
    macro_calul_tread(ht)
    For y = thread_start To thread_stop - 1
        ; --- Passe Gauche -> Droite ---
        pos = y * lg
        idx = pos * 4
        prev_r = *adr13\f[idx + 2]
        prev_g = *adr13\f[idx + 1]
        prev_b = *adr13\f[idx + 0]
        *adr14\f[idx + 2] = prev_r
        *adr14\f[idx + 1] = prev_g
        *adr14\f[idx + 0] = prev_b
        For x = 1 To lg - 1
          pos = (y * lg) + x
          idx = pos * 4 ; <-- AJOUTÉ : Crucial pour mettre à jour l'index à chaque pixel !
          dist = *adr6\f[pos - 1]
          alpha = Exp(dist * exp_factor)
          invAlpha = 1.0 - alpha
          prev_r = alpha * prev_r + invAlpha * *adr13\f[idx + 2]
          prev_g = alpha * prev_g + invAlpha * *adr13\f[idx + 1]
          prev_b = alpha * prev_b + invAlpha * *adr13\f[idx + 0]
          *adr14\f[idx + 2] = prev_r
          *adr14\f[idx + 1] = prev_g
          *adr14\f[idx + 0] = prev_b
        Next
        ; --- Passe Droite -> Gauche ---
        For x = lg - 2 To 0 Step -1
          pos = (y * lg) + x
          idx = pos * 4
          dist = *adr6\f[pos]
          alpha = Exp(dist * exp_factor)
          invAlpha = 1.0 - alpha
          *adr14\f[idx + 2] = alpha * *adr14\f[idx + 6] + invAlpha * *adr14\f[idx + 2]
          *adr14\f[idx + 1] = alpha * *adr14\f[idx + 5] + invAlpha * *adr14\f[idx + 1]
          *adr14\f[idx + 0] = alpha * *adr14\f[idx + 4] + invAlpha * *adr14\f[idx + 0]
        Next
    Next
  EndWith
EndProcedure

; --- Filtre Vertical Indexé (Zéro risque de plantage) ---
Procedure DomainTransform_FilterV_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected x, y, pos, idx
    Protected.f sigma = \option[0]
    Protected.f exp_factor = -1.0 / (1.41421356 * sigma)
    Protected.f alpha, dist, invAlpha
    Protected.f prev_r, prev_g, prev_b
    Protected stride = lg * 4
    ; --- Entrée/Sortie unifiée ---
    Protected *adr14.FloatArray = \addr[4]
    ; --- Distances (Dy) ---
    Protected *adr7.FloatArray = \addr[6]
    macro_calul_tread(lg) ; Découpage par colonnes 
    For x = thread_start To thread_stop - 1
        pos = x
        idx = pos * 4
        prev_r = *adr14\f[idx + 2]
        prev_g = *adr14\f[idx + 1]
        prev_b = *adr14\f[idx + 0]
        For y = 1 To ht - 1
          pos = (y * lg) + x
          idx = pos * 4 
          dist = *adr7\f[pos - lg]
          alpha = Exp(dist * exp_factor)
          invAlpha = 1.0 - alpha
          prev_r = alpha * prev_r + invAlpha * *adr14\f[idx + 2]
          prev_g = alpha * prev_g + invAlpha * *adr14\f[idx + 1]
          prev_b = alpha * prev_b + invAlpha * *adr14\f[idx + 0]
          *adr14\f[idx + 2] = prev_r
          *adr14\f[idx + 1] = prev_g
          *adr14\f[idx + 0] = prev_b
        Next
        For y = ht - 2 To 0 Step -1
          pos = (y * lg) + x
          idx = pos * 4 
          dist = *adr7\f[pos]
          alpha = Exp(dist * exp_factor)
          invAlpha = 1.0 - alpha
          *adr14\f[idx + 2] = alpha * *adr14\f[idx + stride + 2] + invAlpha * *adr14\f[idx + 2]
          *adr14\f[idx + 1] = alpha * *adr14\f[idx + stride + 1] + invAlpha * *adr14\f[idx + 1]
          *adr14\f[idx + 0] = alpha * *adr14\f[idx + stride + 0] + invAlpha * *adr14\f[idx + 0]
        Next
    Next
  EndWith
EndProcedure

; --- Copie ---
Procedure DomainTransform_Copy_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[1]
    macro_calul_tread(total) 
    Protected offset_octets = thread_start * 16 ; 16 = 4 pixel 32bits float  * 4 byte
    Protected taille_octets = (thread_stop - thread_start) * 16
    CopyMemory(\addr[4] + offset_octets, \addr[3] + offset_octets, taille_octets)
  EndWith
EndProcedure

; --- Écriture finale ---
Procedure DomainTransform_WriteBack_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected total = \image_lg[0] * \image_ht[1]
    Protected i, r, g, b, a, col, idx
    
    Protected *adr0.PixelArray = \addr[0]
    Protected *adr1.PixelArray = \addr[1]
    Protected *adr14.FloatArray = \addr[4]
    
    macro_calul_tread(total)
    
    For i = thread_start To thread_stop - 1
        idx = i * 4
        r = *adr14\f[idx + 2] + 0.5
        g = *adr14\f[idx + 1] + 0.5
        b = *adr14\f[idx + 0] + 0.5
        clamp_rgb(r, g, b)
        col = *adr0\l[i]
        a = (col >> 24) & $FF
        *adr1\l[i] = (a << 24) | (r << 16) | (g << 8) | b
    Next
  EndWith
EndProcedure

Macro DomainTransformEx_sp0(opt)
  Create_MultiThread_MT(@DomainTransform_Image_IntToFloat_MT_#opt())
  Create_MultiThread_MT(@DomainTransform_ComputeDx_MT_#opt())
  Create_MultiThread_MT(@DomainTransform_ComputeDy_MT_#opt())
  
  For iter = 1 To iterations
    *FilterCtx\option[0] = current_sigma_s * Sqr(3.0) * Pow(2.0, iterations - iter) / Sqr(Pow(4.0, iterations) - 1.0)
    Create_MultiThread_MT(@DomainTransform_FilterH_MT_#opt())
    Create_MultiThread_MT(@DomainTransform_Copy_MT_PB())
    Create_MultiThread_MT(@DomainTransform_FilterV_MT_#opt())
    If iter < iterations : Create_MultiThread_MT(@DomainTransform_Copy_MT_PB()) : EndIf
  Next
  
  Create_MultiThread_MT(@DomainTransform_WriteBack_MT_#opt())
  
EndMacro

; --- Lanceur Principal ---
Procedure DomainTransformEx(*FilterCtx.FilterParams)
    Restore DomainTransform_data
    Protected last_data = Filter_InitAndValidate()
    *FilterCtx\asm_dispo = 1
    If last_data < 0 : ProcedureReturn 0 : EndIf

    With *FilterCtx
      Protected lg = \image_lg[0]
      Protected sigma_s.f = \option[0]
      Protected sigma_r.f = \option[1]
      Protected iterations = \option[2]
      Protected size = \image_lg[0] * \image_ht[1] * 4
      Protected i, err = 0 , t
      Protected.f current_sigma_s = sigma_s
      Protected iter
     
      clamp(sigma_s , 1 , 10)
      clamp(sigma_r , 1 , 20)
      clamp(iterations , 1 , 9)

      \option[0] = sigma_s
      \option[1] = sigma_r

      ; Initialisation propre à 0 avant allocation
      For i = 3 To 6 : \addr[i] = 0 : Next
      \addr[3] = AllocateMemory(size * 4) 
      \addr[4] = AllocateMemory(size * 4) 
      \addr[5] = AllocateMemory(size)
      \addr[6] = AllocateMemory(size)
      err = 0
      For i = 3 To 6 : If \addr[i] = 0 : err = 1 : EndIf: Next

        If err = 0
          CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
            DomainTransformEx_sp0(PB) ; version pb pour la version 32bits
          CompilerElse
            
            CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
              Select FilterCtx\Asm
                Case 1 : DomainTransformEx_sp0(SSE2)
                  ;Case 2 : DomainTransformEx_sp0(SSE4)
                  ;Case 3 : DomainTransformEx_sp0(AVX)
                  ;Case 4 : DomainTransformEx_sp0(AVX512)
                Default :DomainTransformEx_sp0(PB)
              EndSelect
            CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
              Select FilterCtx\Asm
                  ;Case 1 : DomainTransformEx_sp0(PB)
                  ;Case 2 : DomainTransformEx_sp0(PB)
                  ;Case 3 : DomainTransformEx_sp0(PB)
                  ;Case 4 : DomainTransformEx_sp0(PB)
                Case 100
                Default :DomainTransformEx_sp0(PB)
              EndSelect
            CompilerEndIf
          CompilerEndIf
        EndIf
    
      For i = 3 To 6  : If Not \addr[i] : FreeMemory(\addr[i]) : \addr[i] = 0 : EndIf : Next
      
      mask_update(*FilterCtx.FilterParams , last_data)
    EndWith
EndProcedure

Procedure DomainTransform(source, cible, mask, sigma_s, sigma_r, iterations)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = sigma_s
    \option[1] = sigma_r
    \option[2] = iterations
  EndWith
  DomainTransformEx(FilterCtx)
EndProcedure

DataSection
  DomainTransform_data:
  Data.s "DomainTransform"
  Data.s "Lissage préservant les contours (Domain Transform)"
  Data.i #FilterType_Blur
  Data.i #Blur_EdgeAware
  
  Data.s "Sigma spatial"
  Data.i 1, 25, 5
  Data.s "Sigma range"
  Data.i 1, 25, 5
  Data.s "Itérations"
  Data.i 1, 9, 1
  Data.s "XXX"
EndDataSection




; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 313
; FirstLine = 281
; Folding = ---
; EnableXP
; DPIAware
; DisableDebugger