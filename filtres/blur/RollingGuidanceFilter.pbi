; ---------------------------------------------------
; Rolling Guidance Filter - Version Optimisée & Corrigée
; Filtre de lissage avec préservation des bords
; ---------------------------------------------------

Procedure RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_PB(*FilterCtx.FilterParams)
  Protected radius = *FilterCtx\option[0]
  Protected w = *FilterCtx\image_lg[0]
  Protected h = *FilterCtx\image_ht[0]
  Protected x, y, i, px
  Protected sr, sg, sb, sa, c
  Protected.l a, r, g, b
  Protected *src.pixelarray = *FilterCtx\addr[0] ; Image d'origine
  Protected *dst.pixelarray = *FilterCtx\addr[5] ; Buffer temporaire
  
  macro_calul_tread(h)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To w - 1
      sr = 0 : sg = 0 : sb = 0 : sa = 0 : c = 0
      For i = -radius To radius
        px = x + i
        CLAMP(px, 0, (w - 1))
        getargb(*src\l[y * w + px], a, r, g, b) 
        sa + a : sr + r : sg + g : sb + b
        c + 1
      Next
      *dst\l[y * w + x] = ((sa / c) << 24) | ((sr / c) << 16) | ((sg / c) << 8) | (sb / c)
    Next
  Next
EndProcedure

Procedure RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_PB(*FilterCtx.FilterParams)
  Protected radius = *FilterCtx\option[0]
  Protected w = *FilterCtx\image_lg[0]
  Protected h = *FilterCtx\image_ht[0]
  Protected x, y, i, py
  Protected sr, sg, sb, sa, c
  Protected.l a, r, g, b
  Protected *src.pixelarray = *FilterCtx\addr[5] ; Lit le buffer temporaire horizontal
  Protected *dst.pixelarray = *FilterCtx\addr[4] ; /!\ Écrit directement dans le GUIDE (\addr[4])
  
  macro_calul_tread(w)
  
  For x = thread_start To thread_stop - 1
    For y = 0 To h - 1
      sr = 0 : sg = 0 : sb = 0 : sa = 0 : c = 0
      For i = -radius To radius
        py = y + i
        CLAMP(py, 0, (h - 1))
        getargb(*src\l[py * w + x], a, r, g, b)
        sa + a : sr + r : sg + g : sb + b
        c + 1
      Next
      *dst\l[y * w + x] = ((sa / c) << 24) | ((sr / c) << 16) | ((sg / c) << 8) | (sb / c)
    Next
  Next
EndProcedure

; --- Worker Thread : Bilateral Filter Guidé ---
Procedure RollingGuidance_Worker_pb(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected radius = \option[0]
    Protected sigmaColor = \option[1]
    Protected dim_size = (radius * 2) + 1
    Protected x, y, dx, dy, px, py, idx
    Protected.l r0, g0, b0, r, g, b, a
    
    ; Structures Float pour l'accumulation
    Protected sumR.f, sumG.f, sumB.f, sumA.f, sumW.f
    Protected dColor.l
    Protected wSpace.f, wTot.f
    
    Protected w_minus_1 = w - 1
    Protected h_minus_1 = h - 1
    
    Protected *src   = \addr[0]
    Protected *dst   = \addr[1]
    Protected *guide = \addr[2]
    
    ; Pointeurs de lecture/écriture
    Protected *currentGuide.pixelarray
    Protected *currentDst.pixelarray
    Protected *pixelSrc.pixelarray
    Protected offsetLine.i
    
    Protected *buf1.floatarray = \addr[7] ; Table Couleur
    Protected *buf2.floatarray = \addr[6] ; Table Espace
    
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
        
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : sumA = 0.0 : sumW = 0.0
        
        For dy = -radius To radius
          py = y + dy
          If py < 0 : py = 0 : ElseIf py > h_minus_1 : py = h_minus_1 : EndIf
          
          Protected *srcLine = *src + (py * w * 4)
          Protected ly = dy + radius
          
          For dx = -radius To radius
            px = x + dx
            If px < 0 : px = 0 : ElseIf px > w_minus_1 : px = w_minus_1 : EndIf
            
            *pixelSrc = *srcLine + (px * 4)
            idx = *pixelSrc\l[0]
            
            a = (idx >> 24) & $FF
            r = (idx >> 16) & $FF
            g = (idx >> 8) & $FF
            b = idx & $FF
            
            dColor = (r0-r)*(r0-r) + (g0-g)*(g0-g) + (b0-b)*(b0-b)
            
            Protected lx = dx + radius
            wTot = *buf1\f[dColor] * *buf2\f[(ly * dim_size) + lx]
            
            sumR + r * wTot
            sumG + g * wTot
            sumB + b * wTot
            sumA + a * wTot
            sumW + wTot
            
          Next
        Next
        
        If sumW > 0.0
          Protected invSumW.f = 1.0 / sumW
          a = Int(sumA * invSumW + 0.5)
          r = Int(sumR * invSumW + 0.5)
          g = Int(sumG * invSumW + 0.5)
          b = Int(sumB * invSumW + 0.5)
        EndIf
          
        *currentDst\l[x] = (a << 24) | (r << 16) | (g << 8) | b
        If Key_Escape_Press = 1 : Break 2 : EndIf
      Next
    Next
  EndWith
EndProcedure

; --- Procédure Ex : Gestion des itérations et de la mémoire -:--
Procedure RollingGuidanceFilterEx(*FilterCtx.FilterParams)
  Restore RollingGuidanceFilter_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 2
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx 
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected total = lg * ht * 4
    Protected radius = \option[0]
    Protected sigmaColor = \option[1]
    Protected i, dx, dy
    
    ; 1. PRÉCALCUL DE LA LUT SPATIALE (\addr[6])
    Protected dim_size = (radius * 2) + 1
    Protected spaceLUT_Size = dim_size * dim_size * 4
    \addr[6] = AllocateMemory(spaceLUT_Size)
    Protected *buf2.floatarray = \addr[6]
    Protected invRadiusSq.d = 1.0 / (radius * radius)
    
    If \addr[6]
      For dy = -radius To radius
        Protected ly = dy + radius
        For dx = -radius To radius
          Protected lx = dx + radius
          Protected idx_space = (ly * dim_size) + lx
          *buf2\f[idx_space] = Exp(-(dx*dx + dy*dy) * invRadiusSq)
        Next
      Next
    EndIf
    
    ; 2. PRÉCALCUL DE LA LUT COULEUR DYNAMIQUE (\addr[7])
    Protected maxColorDist = 195075
    Protected colorLUT_Size = (maxColorDist + 1) * 4
    \addr[7] = AllocateMemory(colorLUT_Size)
    Protected *buf1.floatarray = \addr[7]
    Protected invSigma2.d = 1.0 / (sigmaColor * sigmaColor)
    Protected dColor.l
    
    If \addr[7]
      For dColor = 0 To maxColorDist
        *buf1\f[dColor] = Exp(-dColor * invSigma2)
      Next
    EndIf
    
    ; Sauvegarde des adresses originales
    Protected orig_addr0 = \addr[0]
    Protected orig_addr1 = \addr[1]
    
    ; Allocation des buffers temporaires d'image (\addr[3] à \addr[5])
    For i = 3 To 5 : \addr[i] = AllocateMemory(total) : Next
    
    If \addr[3] And \addr[4] And \addr[5]
      CopyMemory(orig_addr0, \addr[3], total) 
      CopyMemory(orig_addr0, \addr[4], total) 
      
      ; --- INITIAL BLUR SUR LE GUIDE ---
      If \option[0] < 1 : \option[0] = 1 : EndIf
      
      CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
        Create_MultiThread_MT(@RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_PB())
        Create_MultiThread_MT(@RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_PB())
      CompilerElse
        
        CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
          Select FilterCtx\Asm
            Case 1
              Create_MultiThread_MT(@RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE2())
              Create_MultiThread_MT(@RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE2())
            Case 2
              Create_MultiThread_MT(@RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_SSE4())
              Create_MultiThread_MT(@RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_SSE4())
            Default
              Create_MultiThread_MT(@RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_PB())
              Create_MultiThread_MT(@RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_PB())
          EndSelect
        CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
          Select FilterCtx\Asm
              ;Case 1 : Create_MultiThread_MT(name_SSE2())
              ;Case 2 : Create_MultiThread_MT(Mname_SSE4())
              ;Case 3 : Create_MultiThread_MT(name_AVX())
              ;Case 4 : Create_MultiThread_MT(name_AVX512())
            Case 100
            Default
              Create_MultiThread_MT(@RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Horizontal_PB())
              Create_MultiThread_MT(@RollingGuidance_LaplacianPyramidBlur_BlurBuffer_Vertical_PB())
          EndSelect
        CompilerEndIf
      CompilerEndIf
      
      ; --- BOUCLE D'ITÉRATIONS ---
      Protected *currentSource = \addr[3]
      Protected *currentGuide  = \addr[4]
      Protected *currentDest   = orig_addr1
      
      For i = 0 To \option[2] - 1
        If Key_Escape_Press = 1 : Break : EndIf
        \addr[0] = *currentSource
        \addr[1] = *currentDest
        \addr[2] = *currentGuide
        
        Protected t = ElapsedMilliseconds()
        
        CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
          Create_MultiThread_MT(@RollingGuidance_Worker_pb())
        CompilerElse
          
          CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
            Select FilterCtx\Asm
              Case 2
                Create_MultiThread_MT(@RollingGuidance_Worker_sse4())
              Case 1
                Create_MultiThread_MT(@RollingGuidance_Worker_sse2())
              Default
                Create_MultiThread_MT(@RollingGuidance_Worker_pb())
            EndSelect
          CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
            Select FilterCtx\Asm
                ;Case 1 : Create_MultiThread_MT(name_SSE2())
                ;Case 2 : Create_MultiThread_MT(Mname_SSE4())
                ;Case 3 : Create_MultiThread_MT(name_AVX())
                ;Case 4 : Create_MultiThread_MT(name_AVX512())
              Case 100
              Default
                Create_MultiThread_MT(@RollingGuidance_Worker_pb())
            EndSelect
          CompilerEndIf
        CompilerEndIf
        
        \tmp = ElapsedMilliseconds() - t
        
        Swap *currentGuide, *currentDest
      Next
      
      If *currentGuide = orig_addr1 : CopyMemory(*currentDest, orig_addr1, total) : EndIf
    EndIf
    
    ; Restauration obligatoire des adresses d'origine de l'application
    \addr[0] = orig_addr0
    \addr[1] = orig_addr1
    
    ; Libération de TOUS les buffers temporaires alloués (3 à 7)
    For i = 3 To 7 : If \addr[i] : FreeMemory(\addr[i]) : \addr[i] = 0 : EndIf : Next
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; --- Appel Simplifié ---
Procedure RollingGuidanceFilter(source, cible, mask, radius, sigmaColor, iterations)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = sigmaColor
    \option[2] = iterations
  EndWith
  RollingGuidanceFilterEx(FilterCtx)
EndProcedure

DataSection
  RollingGuidanceFilter_data:
  Data.s "Rolling Guidance Filter"
  Data.s "Lissage itératif préservant les détails (Edge-Preserving)"
  Data.i #FilterType_Blur, #Blur_Adaptive
  Data.s "Rayon spatial"
  Data.i 1, 20, 6
  Data.s "Sigma couleur"
  Data.i 5, 100, 100
  Data.s "Itérations"
  Data.i 1, 10, 4
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 268
; FirstLine = 240
; Folding = --
; Markers = 305
; EnableXP
; DPIAware