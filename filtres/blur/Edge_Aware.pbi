; --- Procédures MT de conversion ---

Procedure Edge_Aware_LoadImageToFloatArrays_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source.pixelarray = \addr[0] 
    Protected *cibleR.FloatArray = \addr[3]
    Protected *cibleG.FloatArray = \addr[4]
    Protected *cibleB.FloatArray = \addr[5]
    Protected total = \image_lg[0] * \image_ht[0]
    Protected r , g , b , i , offset
    Protected inv255.f = 1.0 / 255.0
    macro_calul_tread(total)
    For i = thread_start To thread_stop - 1
      getrgb(*source\l[i] , r , g , b)
      *cibleR\f[i] = r * inv255
      *cibleG\f[i] = G * inv255
      *cibleB\f[i] = B * inv255
    Next
  EndWith
EndProcedure

Procedure Edge_Aware_FloatArraysToLoadImage_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *cible.pixelarray   = \addr[1]
    Protected *sourceR.FloatArray = \addr[3]
    Protected *sourceG.FloatArray = \addr[4]
    Protected *sourceB.FloatArray = \addr[5]
    Protected total = \image_lg[0] * \image_ht[0]
    Protected r.f, g.f, b.f
    Protected ri, gi, bi, i, offset
    macro_calul_tread(total)
    For i = thread_start To thread_stop - 1
      ri = (*sourceR\f[i] * 255) + 0.5
      gi = (*sourceG\f[i] * 255) + 0.5
      bi = (*sourceB\f[i] * 255) + 0.5
      clamp_rgb(ri, gi, bi)
      *cible\l[i] = (255 << 24) | (ri << 16) | (gi << 8) | bi
    Next
  EndWith
EndProcedure

; --- Procédures MT de Filtrage ---

Macro Edge_Aware_RecursiveFilter_H_sp0(op)
  r0 = tempR(x)     : g0 = tempG(x)     : b0 = tempB(x)
  r1 = tempR(x op 1) : g1 = tempG(x op 1) : b1 = tempB(x op 1)
  diff_carre = (r0-r1)*(r0-r1) + (g0-g1)*(g0-g1) + (b0-b1)*(b0-b1)
  lut_idx = Int(diff_carre * StepLUT)
  weight = *Lut\f[lut_idx]
  tempR(x) = r0 + weight * (r1 - r0)
  tempG(x) = g0 + weight * (g1 - g0)
  tempB(x) = b0 + weight * (b1 - b0)
EndMacro

Procedure Edge_Aware_RecursiveFilter_H_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected wMinus1 = w - 1
    Protected x, y, idx, lineOffset, srcOffset
    Protected r0.f, g0.f, b0.f, r1.f, g1.f, b1.f
    Protected diff_carre.f, weight.f
    
    macro_calul_tread(h)
    
    Protected *bufR.FloatArray = \addr[3]
    Protected *bufG.FloatArray = \addr[4]
    Protected *bufB.FloatArray = \addr[5]
    Protected *Lut.FloatArray  = \addr[6] ; Récupération de la LUT
    Protected StepLUT.f        = \option[7]
    
    Protected Dim tempR.f(w)
    Protected Dim tempG.f(w)
    Protected Dim tempB.f(w)
    Protected lineByteSize = w << 2
    Protected lut_idx
    
    For y = thread_start To thread_stop - 1
      lineOffset = y * w
      srcOffset = lineOffset << 2
      
      ; Charger la ligne avec CopyMemory (Optimisé au lieu de la boucle For)
      CopyMemory(*bufR + srcOffset, @tempR(0), lineByteSize)
      CopyMemory(*bufG + srcOffset, @tempG(0), lineByteSize)
      CopyMemory(*bufB + srcOffset, @tempB(0), lineByteSize)
      
      ; Gauche -> Droite
      For x = 1 To wMinus1 : Edge_Aware_RecursiveFilter_H_sp0(-) : Next
      
      ; Droite -> Gauche
      For x = wMinus1 - 1 To 0 Step -1 : Edge_Aware_RecursiveFilter_H_sp0(+) : Next
      
      ; Sauvegarder la ligne avec CopyMemory
      CopyMemory(@tempR(0), *bufR + srcOffset, lineByteSize)
      CopyMemory(@tempG(0), *bufG + srcOffset, lineByteSize)
      CopyMemory(@tempB(0), *bufB + srcOffset, lineByteSize)
    Next
  EndWith
EndProcedure

Macro Edge_Aware_RecursiveFilter_V_sp0(op)
  r0 = tempR(y)     : g0 = tempG(y)     : b0 = tempB(y)
  r1 = tempR(y op 1) : g1 = tempG(y op 1) : b1 = tempB(y op 1)
  diff_carre = (r0-r1)*(r0-r1) + (g0-g1)*(g0-g1) + (b0-b1)*(b0-b1)
  lut_idx = Int(diff_carre * StepLUT)
  weight = *Lut\f[lut_idx]
  tempR(y) = r0 + weight * (r1 - r0)
  tempG(y) = g0 + weight * (g1 - g0)
  tempB(y) = b0 + weight * (b1 - b0)
EndMacro

Procedure Edge_Aware_RecursiveFilter_V_MT_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected hMinus1 = h - 1
    Protected x, y, idx
    Protected r0.f, g0.f, b0.f, r1.f, g1.f, b1.f
    Protected diff_carre.f, weight.f
    
    macro_calul_tread(w)
    
    ; Accès direct aux buffers de flottants (Pas de Peek/Poke)
    Protected *bufR.FloatArray = \addr[3]
    Protected *bufG.FloatArray = \addr[4]
    Protected *bufB.FloatArray = \addr[5]
    Protected *Lut.FloatArray  = \addr[6] ; Récupération de la table pré-calculée
    Protected StepLUT.f        = \option[7] ; Facteur d'échelle de la LUT
    
    ; Tableaux locaux sur la pile pour stocker la colonne courante de manière contiguë
    Protected Dim tempR.f(h)
    Protected Dim tempG.f(h)
    Protected Dim tempB.f(h)
    Protected lut_idx
    
    For x = thread_start To thread_stop - 1
      
      ; 1. Charger la colonne (Sauts de lignes de taille 'w')
      For y = 0 To hMinus1
        idx = y * w + x
        tempR(y) = *bufR\f[idx]
        tempG(y) = *bufG\f[idx]
        tempB(y) = *bufB\f[idx]
      Next
      
      ; 2. Filtrage : Haut -> Bas
      For y = 1 To hMinus1 : Edge_Aware_RecursiveFilter_V_sp0(-) : Next
      
      ; 3. Filtrage : Bas -> Haut
      For y = hMinus1 - 1 To 0 Step -1 : Edge_Aware_RecursiveFilter_V_sp0(+) : Next
      
      ; 4. Sauvegarder la colonne modifiée dans les buffers globaux
      For y = 0 To hMinus1
        idx = y * w + x
        *bufR\f[idx] = tempR(y)
        *bufG\f[idx] = tempG(y)
        *bufB\f[idx] = tempB(y)
      Next
    Next
  EndWith
EndProcedure

; --- Cycle principal ---

Macro Edge_AwareEx_sp(opt)
  Create_MultiThread_MT(@Edge_Aware_LoadImageToFloatArrays_MT_PB())
  For i = 1 To iterations
    Create_MultiThread_MT(@Edge_Aware_RecursiveFilter_H_MT_#opt())
    Create_MultiThread_MT(@Edge_Aware_RecursiveFilter_V_MT_#opt())
  Next
  Create_MultiThread_MT(@Edge_Aware_FloatArraysToLoadImage_MT_PB())
EndMacro

Procedure Edge_AwareEx(*FilterCtx.FilterParams)
  Restore Edge_Aware_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected i, iterations = \option[2]
    Protected sigma_s.f = \option[0]
    Protected sigma_r.f = \option[1] * 0.01
    Protected inv_sigma_r.f = 1.0 / sigma_r
    
    Protected size = \image_lg[0] * \image_ht[0] << 2
    \addr[3] = AllocateMemory(size) ; Buffer R float
    \addr[4] = AllocateMemory(size) ; Buffer G float
    \addr[5] = AllocateMemory(size) ; Buffer B float
    
    If Not \addr[3] Or Not \addr[4] Or Not \addr[5]
      If \addr[3] : FreeMemory(\addr[3]) : EndIf
      If \addr[4] : FreeMemory(\addr[4]) : EndIf
      If \addr[5] : FreeMemory(\addr[5]) : EndIf
      ProcedureReturn 0
    EndIf
    
    Protected a.f = Exp(-Sqr(2.0) / sigma_s)
    Protected SizeLUT = 4096
    Protected *LutBuffer = AllocateMemory(SizeLUT * 4) ; 4 octets par Float
    Protected *Lut.FloatArray = *LutBuffer
    \addr[6] = *LutBuffer ; On stocke l'adresse dans le contexte pour les threads
    
    Protected StepLUT.f = (SizeLUT - 1) / 3.0
    \option[7] = StepLUT ; On passe aussi le StepLUT aux threads via une option disponible
    
    ; On pré-calcule la LUT
    Protected lut_i
    For lut_i = 0 To SizeLUT - 1
      Protected dist_carre.f = lut_i / StepLUT
      *Lut\f[lut_i] = a * Exp(-Sqr(dist_carre) * inv_sigma_r) 
    Next
   
    CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
      Edge_AwareEx_sp(PB)
    CompilerElse
      
      CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
        Select FilterCtx\Asm
          Case 1 : Edge_AwareEx_sp(SSE2)
          ;Case 2 : Edge_AwareEx_sp(opt)
          ;Case 3 : Edge_AwareEx_sp(opt)
          ;Case 4 : Create_MultiThread_MT(@name#_AVX512())
          Default : Edge_AwareEx_sp(PB)
        EndSelect
      CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
        Select FilterCtx\Asm
            ;Case 1 : Edge_AwareEx_sp(opt)
            ;Case 2 : Edge_AwareEx_sp(opt)
            ;Case 3 : Edge_AwareEx_sp(opt)
            ;Case 4 : Edge_AwareEx_sp(opt)
          Case 100
          Default : Edge_AwareEx_sp(PB)
        EndSelect
      CompilerEndIf
    CompilerEndIf
      
    ; Nettoyage
    For i = 3 To 6 : If \addr[i] : FreeMemory(\addr[3]) : \addr[i]= 0: EndIf : Next
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Edge_Aware(source, cible, mask, sigma_s, sigma_r, iterations)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = sigma_s
    \option[1] = sigma_r
    \option[2] = iterations
  EndWith
  Edge_AwareEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Edge_Aware_data:
  Data.s "Edge_Aware"
  Data.s "Lissage récursif avec préservation des contours"
  Data.i #FilterType_Blur
  Data.i #Blur_EdgeAware
  Data.s "Rayon spatial"
  Data.i 1, 100, 20
  Data.s "Contraste (%)"
  Data.i 1, 100, 20
  Data.s "Passes"
  Data.i 1, 10, 3
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 170
; FirstLine = 131
; Folding = --
; EnableXP
; DPIAware