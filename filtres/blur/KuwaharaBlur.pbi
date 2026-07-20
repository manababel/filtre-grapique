

Macro macro_KuwaharaBlur_peek4(a, b, c, d)
  ; Correction de l'indexation : pos << 2 suffit pour pointer le bon bloc de 4 Longs
  idx_peek = pos << 2
  a = *adr7\l[idx_peek + 1] ; Lit Rouge
  b = *adr7\l[idx_peek + 2] ; Lit Vert
  c = *adr7\l[idx_peek + 3] ; Lit Bleu
  d = *adr6\q[pos]          ; Lit la somme des carrés (Quad) sans PeekQ
EndMacro

; --- Étape 1 : Génération des images intégrales (Mono-thread car séquentiel) ---
Procedure KuwaharaBlur_sp0_y(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected pos, pos1, x, y, r1, g1, b1
    Protected idx, idx1
    Protected *adr0.pixelarray = \addr[0]
    Protected *adr7.pixelarray = \addr[7]
    Protected *adr6.quadarray  = \addr[6] ; Remplplace l'accès brut à \addr[6]
    ; Première colonne (x = 0)
    For y = 1 To ht - 1
      pos = (y * lg)
      pos1 = (pos - lg)
      getrgb(*adr0\l[pos] , r1 , g1 , b1)
      idx = pos << 2 
      idx1 = pos1 << 2
      *adr7\l[idx]     = 0                             ; Alpha (SAT)
      *adr7\l[idx + 1] = *adr7\l[idx1 + 1] + r1        ; Rouge (SAT)
      *adr7\l[idx + 2] = *adr7\l[idx1 + 2] + g1        ; Vert (SAT)
      *adr7\l[idx + 3] = *adr7\l[idx1 + 3] + b1        ; Bleu (SAT)
      *adr6\q[pos] = *adr6\q[pos1] + (r1 * r1 + g1 * g1 + b1 * b1)
    Next
  EndWith
EndProcedure

Procedure KuwaharaBlur_sp0_x(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected pos, pos1, x, y, r1, g1, b1
    Protected idx, idx1
    Protected *adr0.pixelarray = \addr[0]
    Protected *adr7.pixelarray = \addr[7]
    Protected *adr6.quadarray  = \addr[6] ; Remplplace l'accès brut à \addr[6]
    For x = 1 To lg - 1
      pos = x
      pos1 = (x - 1)
      getrgb(*adr0\l[pos] , r1 , g1 , b1)
      idx = pos << 2 
      idx1 = pos1 << 2
      *adr7\l[idx]     = 0                             ; Alpha (SAT)
      *adr7\l[idx + 1] = *adr7\l[idx1 + 1] + r1        ; Rouge (SAT)
      *adr7\l[idx + 2] = *adr7\l[idx1 + 2] + g1        ; Vert (SAT)
      *adr7\l[idx + 3] = *adr7\l[idx1 + 3] + b1        ; Bleu (SAT)
      *adr6\q[pos] = *adr6\q[pos1] + (r1 * r1 + g1 * g1 + b1 * b1)
    Next
  EndWith
EndProcedure

Procedure Kuwahara_Passe1_Worker_PB(*FilterCtx.FilterParams)  
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y, r1, g1, b1, pos, idx
    Protected *adr0.pixelarray = \addr[0]
    Protected *adr7.pixelarray = \addr[7]
    Protected *adr6.quadarray  = \addr[6]
    ; 1. Calcul des bornes du thread (génère thread_start et thread_stop)
    macro_calul_tread(ht) 
    If thread_start < 0 : thread_start = 0 : EndIf ; Changé à 0 car la passe 1 traite TOUTES les lignes, même la 0
    ; 2. RAJOUT DE LA BOUCLE Y
    For y = thread_start To thread_stop - 1
      ; L'initialisation du pixel x = 0 doit être ICI, au début de CHAQUE ligne
      pos = y * lg
      idx = pos << 2
      getrgb(*adr0\l[pos], r1, g1, b1)
      *adr7\l[idx]     = 0
      *adr7\l[idx + 1] = r1
      *adr7\l[idx + 2] = g1
      *adr7\l[idx + 3] = b1
      *adr6\q[pos]     = (r1 * r1 + g1 * g1 + b1 * b1)
      ; On passe aux pixels suivants de la ligne (on incrémente simplement pos et idx)
      pos + 1
      idx + 4    
      ; 3. Boucle interne x optimisée (plus de multiplication 'y * lg + x')
      For x = 1 To lg - 1
        getrgb(*adr0\l[pos], r1, g1, b1)
        *adr7\l[idx]     = 0
        *adr7\l[idx + 1] = *adr7\l[idx - 3] + r1 ; Gauche + Source
        *adr7\l[idx + 2] = *adr7\l[idx - 2] + g1 
        *adr7\l[idx + 3] = *adr7\l[idx - 1] + b1 
        *adr6\q[pos]     = *adr6\q[pos - 1] + (r1 * r1 + g1 * g1 + b1 * b1)
        pos + 1
        idx + 4
      Next
    Next
  EndWith
EndProcedure

Procedure Kuwahara_Passe2_Worker_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y, pos, idx, idx_dessus, pos_dessus
    Protected.i lg4 = lg << 2
    Protected *adr7.pixelarray = \addr[7]
    Protected *adr6.quadarray  = \addr[6]
    ; 1. Calcul des bornes de colonnes pour ce thread
    macro_calul_tread(lg) 
    If thread_start < 0 : thread_start = 0 : EndIf ; Doit commencer à 0 pour inclure la première colonne
    ; 2. On parcourt ligne par ligne (Y en premier = Cache CPU ultra-efficace !)
    For y = 1 To ht - 1
      ; Pré-calculs pour le début de la ligne y, uniquement pour les colonnes de ce thread
      pos = y * lg + thread_start
      idx = pos << 2
      pos_dessus = pos - lg
      idx_dessus = idx - lg4
      ; 3. Boucle interne sur les colonnes attribuées à ce thread
      For x = thread_start To thread_stop - 1 
        ; Pixel = Pixel Actuel (somme H) + Pixel du dessus
        *adr7\l[idx + 1] + *adr7\l[idx_dessus + 1]
        *adr7\l[idx + 2] + *adr7\l[idx_dessus + 2]
        *adr7\l[idx + 3] + *adr7\l[idx_dessus + 3]
        *adr6\q[pos] + *adr6\q[pos_dessus]
        ; Avance d'un pixel horizontalement (incrémentation pure, zéro multiplication)
        pos + 1
        idx + 4
        pos_dessus + 1
        idx_dessus + 4
      Next 
    Next 
  EndWith
EndProcedure

; --- Étape 2 : Filtrage Kuwahara (Multi-thread) ---
Procedure KuwaharaBlur_sp_PB(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected radius = \option[0]
    Protected sharpness.f = \option[1] / 100.0
    Protected x, y, minIndex, pos, pos_pixel
    Protected.l a1 , r1, g1, b1
    
    Protected r.f, g.f, b.f, v.f, minVar.f
    Protected inv_sharpness.f = 1.0 - sharpness
    Protected w_minus_1 = w - 1, h_minus_1 = h - 1
    Protected idx_peek
    
    Protected *adr0.pixelarray = \addr[0]
    Protected *adr1.pixelarray = \addr[1]
    Protected *adr7.pixelarray = \addr[7]
    Protected *adr6.quadarray  = \addr[6]
    
    ; Variables de travail sorties des boucles (Très Important)
    Protected x0, y0, x1, y1
    Protected.d count, invC, sum, currentVar
    Protected.q sR0, sR1, sR2, sR3, sG0, sG1, sG2, sG3, sB0, sB1, sB2, sB3, sS0, sS1, sS2, sS3
    
    ; Remplacement du tableau quadrant() par des variables locales directes
    Protected.d q_R0, q_G0, q_B0, q_S0, q_C0
    Protected.d q_R1, q_G1, q_B1, q_S1, q_C1
    Protected.d q_R2, q_G2, q_B2, q_S2, q_C2
    Protected.d q_R3, q_G3, q_B3, q_S3, q_C3
    
    macro_calul_tread(h)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        ; =====================================================================
        ; QUADRANT 0 : En haut à gauche (x0 = x-r, y0 = y-r, x1 = x, y1 = y)
        ; =====================================================================
        x0 = x - radius : If x0 < 0 : x0 = 0 : EndIf
        y0 = y - radius : If y0 < 0 : y0 = 0 : EndIf
        x1 = x : y1 = y
        q_C0 = (x1 - x0 + 1) * (y1 - y0 + 1)
        pos = (y1 * w + x1) : macro_KuwaharaBlur_peek4(sR0, sG0, sB0, sS0)
        ; --- CORRECTION ICI : sS1 est maintenant bien remis à 0 ---
        sR1 = 0 : sG1 = 0 : sB1 = 0 : sS1 = 0 
        sR2 = 0 : sG2 = 0 : sB2 = 0 : sS2 = 0 
        sR3 = 0 : sG3 = 0 : sB3 = 0 : sS3 = 0
        If y0 > 0 : pos = ((y0 - 1) * w + x1) : macro_KuwaharaBlur_peek4(sR1, sG1, sB1, sS1) : EndIf
        If x0 > 0 : pos = (y1 * w + (x0 - 1)) : macro_KuwaharaBlur_peek4(sR2, sG2, sB2, sS2) : EndIf
        If x0 > 0 And y0 > 0 : pos = ((y0 - 1) * w + (x0 - 1)) : macro_KuwaharaBlur_peek4(sR3, sG3, sB3, sS3) : EndIf
        q_R0 = sR0 - sR1 - sR2 + sR3
        q_G0 = sG0 - sG1 - sG2 + sG3
        q_B0 = sB0 - sB1 - sB2 + sB3
        q_S0 = sS0 - sS1 - sS2 + sS3
        ; =====================================================================
        ; QUADRANT 1 : En haut à droite (x0 = x, y0 = y-r, x1 = x+r, y1 = y)
        ; =====================================================================
        x0 = x : y0 = y - radius : If y0 < 0 : y0 = 0 : EndIf
        x1 = x + radius : If x1 > w_minus_1 : x1 = w_minus_1 : EndIf
        y1 = y
        q_C1 = (x1 - x0 + 1) * (y1 - y0 + 1)
        pos = (y1 * w + x1)
        macro_KuwaharaBlur_peek4(sR0, sG0, sB0, sS0)
        sR1 = 0 : sG1 = 0 : sB1 = 0 : sS1 = 0
        sR2 = 0 : sG2 = 0 : sB2 = 0 : sS2 = 0
        sR3 = 0 : sG3 = 0 : sB3 = 0 : sS3 = 0
        If y0 > 0 : pos = ((y0 - 1) * w + x1) : macro_KuwaharaBlur_peek4(sR1, sG1, sB1, sS1) : EndIf
        If x0 > 0 : pos = (y1 * w + (x0 - 1)) : macro_KuwaharaBlur_peek4(sR2, sG2, sB2, sS2) : EndIf
        If x0 > 0 And y0 > 0 : pos = ((y0 - 1) * w + (x0 - 1)) : macro_KuwaharaBlur_peek4(sR3, sG3, sB3, sS3) : EndIf
        q_R1 = sR0 - sR1 - sR2 + sR3 : q_G1 = sG0 - sG1 - sG2 + sG3 : q_B1 = sB0 - sB1 - sB2 + sB3 : q_S1 = sS0 - sS1 - sS2 + sS3
        ; =====================================================================
        ; QUADRANT 2 : En bas à gauche (x0 = x-r, y0 = y, x1 = x, y1 = y+r)
        ; =====================================================================
        x0 = x - radius : If x0 < 0 : x0 = 0 : EndIf
        y0 = y : x1 = x
        y1 = y + radius : If y1 > h_minus_1 : y1 = h_minus_1 : EndIf
        q_C2 = (x1 - x0 + 1) * (y1 - y0 + 1)
        pos = (y1 * w + x1) : macro_KuwaharaBlur_peek4(sR0, sG0, sB0, sS0)
        sR1 = 0 : sG1 = 0 : sB1 = 0 : sS1 = 0 : sR2 = 0 : sG2 = 0 : sB2 = 0 : sS2 = 0 : sR3 = 0 : sG3 = 0 : sB3 = 0 : sS3 = 0
        If y0 > 0 : pos = ((y0 - 1) * w + x1) : macro_KuwaharaBlur_peek4(sR1, sG1, sB1, sS1) : EndIf
        If x0 > 0 : pos = (y1 * w + (x0 - 1)) : macro_KuwaharaBlur_peek4(sR2, sG2, sB2, sS2) : EndIf
        If x0 > 0 And y0 > 0 : pos = ((y0 - 1) * w + (x0 - 1)) : macro_KuwaharaBlur_peek4(sR3, sG3, sB3, sS3) : EndIf
        q_R2 = sR0 - sR1 - sR2 + sR3 : q_G2 = sG0 - sG1 - sG2 + sG3 : q_B2 = sB0 - sB1 - sB2 + sB3 : q_S2 = sS0 - sS1 - sS2 + sS3
        ; =====================================================================
        ; QUADRANT 3 : En bas à droite (x0 = x, y0 = y, x1 = x+r, y1 = y+r)
        ; =====================================================================
        x0 = x : y0 = y
        x1 = x + radius : If x1 > w_minus_1 : x1 = w_minus_1 : EndIf
        y1 = y + radius : If y1 > h_minus_1 : y1 = h_minus_1 : EndIf
        q_C3 = (x1 - x0 + 1) * (y1 - y0 + 1)
        pos = (y1 * w + x1) : macro_KuwaharaBlur_peek4(sR0, sG0, sB0, sS0)
        sR1 = 0 : sG1 = 0 : sB1 = 0 : sS1 = 0 : sR2 = 0 : sG2 = 0 : sB2 = 0 : sS2 = 0 : sR3 = 0 : sG3 = 0 : sB3 = 0 : sS3 = 0
        If y0 > 0 : pos = ((y0 - 1) * w + x1) : macro_KuwaharaBlur_peek4(sR1, sG1, sB1, sS1) : EndIf
        If x0 > 0 : pos = (y1 * w + (x0 - 1)) : macro_KuwaharaBlur_peek4(sR2, sG2, sB2, sS2) : EndIf
        If x0 > 0 And y0 > 0 : pos = ((y0 - 1) * w + (x0 - 1)) : macro_KuwaharaBlur_peek4(sR3, sG3, sB3, sS3) : EndIf
        q_R3 = sR0 - sR1 - sR2 + sR3 : q_G3 = sG0 - sG1 - sG2 + sG3 : q_B3 = sB0 - sB1 - sB2 + sB3 : q_S3 = sS0 - sS1 - sS2 + sS3
        ; =====================================================================
        ; RECHERCHE DE LA VARIANCE MINIMALE (Déroulée également)
        ; =====================================================================
        minIndex = 0
        sum = q_R0 + q_G0 + q_B0
        minVar = q_S0 / q_C0 - (sum / q_C0) * (sum / q_C0)
        ; Test Quadrant 1
        sum = q_R1 + q_G1 + q_B1
        currentVar = q_S1 / q_C1 - (sum / q_C1) * (sum / q_C1)
        If currentVar < minVar : minVar = currentVar : minIndex = 1 : EndIf
        ; Test Quadrant 2
        sum = q_R2 + q_G2 + q_B2
        currentVar = q_S2 / q_C2 - (sum / q_C2) * (sum / q_C2)
        If currentVar < minVar : minVar = currentVar : minIndex = 2 : EndIf
        ; Test Quadrant 3
        sum = q_R3 + q_G3 + q_B3
        currentVar = q_S3 / q_C3 - (sum / q_C3) * (sum / q_C3)
        If currentVar < minVar : minVar = currentVar : minIndex = 3 : EndIf
        ; =====================================================================
        ; APPLICATION DU BLUR SUR LE PIXEL
        ; =====================================================================
        pos_pixel = (y * w + x)
        getargb(*adr0\l[pos_pixel] , a1 ,r1 , g1 , b1)
        Select minIndex
          Case 0 : invC = 1.0 / q_C0 : r = q_R0 : g = q_G0 : b = q_B0
          Case 1 : invC = 1.0 / q_C1 : r = q_R1 : g = q_G1 : b = q_B1
          Case 2 : invC = 1.0 / q_C2 : r = q_R2 : g = q_G2 : b = q_B2
          Case 3 : invC = 1.0 / q_C3 : r = q_R3 : g = q_G3 : b = q_B3
        EndSelect
        r = (r * invC) * sharpness + r1 * inv_sharpness
        g = (g * invC) * sharpness + g1 * inv_sharpness
        b = (b * invC) * sharpness + b1 * inv_sharpness
        clamp_rgb(r , g , b)
        *adr1\l[pos_pixel] = (a1 << 24) | (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next 
    Next 
  EndWith
EndProcedure


Macro KuwaharaBlurEx_select_language(opt)
  Create_MultiThread_MT(@Kuwahara_Passe1_Worker_#opt())
  Create_MultiThread_MT(@Kuwahara_Passe2_Worker_#opt())
  Create_MultiThread_MT(@KuwaharaBlur_sp_#opt())
EndMacro

; --- Procédure Ex ---
Procedure KuwaharaBlurEx(*FilterCtx.FilterParams)
  Restore KuwaharaBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 1
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected total = lg * ht * 4
    Protected totalQ = lg * ht * 8
    Protected tmpSrc = \addr[0]
    Protected tmpDst = \addr[1]
    Protected.i i , r1, g1, b1
    
    \addr[6] = 0 : \addr[7] = 0
    \addr[6] = AllocateMemory(totalQ)
    \addr[7] = AllocateMemory(total * 4) ;  *4 = argb , mais a n'est jamais utilisé
    
    If \addr[6] And \addr[7] 
      Protected *adr0.pixelarray = \addr[0]
      Protected *adr7.pixelarray = \addr[7]
      Protected *adr6.quadarray  = \addr[6] 
      For i = 1 To \option[2]
        \addr[0] = tmpSrc
        \addr[1] = tmpDst
        ; Coin haut-gauche (0,0)
        getrgb(*adr0\l[0] , r1 , g1 , b1)
        ; Initialisation pixel 0 au format ARGB (4 Longs)
        *adr7\l[0] = 0  : *adr7\l[1] = r1 : *adr7\l[2] = g1  : *adr7\l[3] = b1 
        *adr6\q[0] = r1 * r1 + g1 * g1 + b1 * b1
        ; Première colonne (x = 0)
        KuwaharaBlur_sp0_y(*FilterCtx.FilterParams)
        ; Première ligne (y = 0)
        KuwaharaBlur_sp0_x(*FilterCtx.FilterParams)
        
        CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
          KuwaharaBlurEx_select_language(PB) ; version pb pour la version 32bits
        CompilerElse
          
          CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
            Select FilterCtx\Asm
              Case 1 : KuwaharaBlurEx_select_language(SSE2)
                ;Case 2 : KuwaharaBlurEx_select_language(SSE4()
                ;Case 3 : KuwaharaBlurEx_select_language(AVX()
                ;Case 4 : KuwaharaBlurEx_select_language(AVX512()
              Default :KuwaharaBlurEx_select_language(PB)
            EndSelect
          CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
            Select FilterCtx\Asm
                ;Case 1 : Create_MultiThread_MT(name_SSE2())
                ;Case 2 : Create_MultiThread_MT(Mname_SSE4())
                ;Case 3 : Create_MultiThread_MT(name_AVX())
                ;Case 4 : Create_MultiThread_MT(name_AVX512())
              Case 100
              Default :KuwaharaBlurEx_select_language(PB)
            EndSelect
          CompilerEndIf
        CompilerEndIf
        
        If i < \option[2] : Swap tmpSrc, tmpDst : EndIf
      Next
      mask_update(*FilterCtx, last_data)
    EndIf
    For i = 6 To 7 : If \addr[i] : FreeMemory(\addr[i]) : EndIf : Next
  EndWith
EndProcedure

; --- Appel simplifiée ---
Procedure KuwaharaBlur(source, cible, mask, radius, sharpness, iterations)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = sharpness
    \option[2] = iterations
  EndWith
  KuwaharaBlurEx(FilterCtx)
EndProcedure

DataSection
  KuwaharaBlur_data:
  Data.s "KuwaharaBlur"
  Data.s "Flou adaptatif préservant les bords (Kuwahara)"
  Data.i #FilterType_Blur, #Blur_Adaptive
  Data.s "Rayon"
  Data.i 1, 50, 10    ; Rayon
  Data.s "Netteté"
  Data.i 0, 100, 70   ; Netteté
  Data.s "Itérations"
  Data.i 1, 5, 3      ; Itérations
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 282
; FirstLine = 266
; Folding = --
; EnableXP
; DPIAware