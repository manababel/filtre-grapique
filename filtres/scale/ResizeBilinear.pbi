; ===== Bilinear Resize (multithread) =====
Procedure ResizeBilinear_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y, pos
    Protected gx.f, gy.f, weightX.f, weightY.f
    Protected x1, y1, x2, y2
    Protected *c00.Pixel32, *c10.Pixel32, *c01.Pixel32, *c11.Pixel32, *dstPix.Pixel32
    Protected r, g, b, a
    
    ; Facteurs d'échelle (on soustrait 1 pour un mapping parfait des bordures)
    Protected ratioX.f = (lg_src - 1) / lg_dst
    Protected ratioY.f = (ht_src - 1) / ht_dst
    
    macro_calul_tread(ht_dst)
    
    For y = thread_start To thread_stop - 1
      gy = y * ratioY
      y1 = Int(gy)
      y2 = y1 + 1
      weightY = gy - y1
      
      ; Sécurité clamping vertical
      If y2 >= ht_src : y2 = ht_src - 1 : EndIf
      
      For x = 0 To lg_dst - 1
        gx = x * ratioX
        x1 = Int(gx)
        x2 = x1 + 1
        weightX = gx - x1
        
        ; Sécurité clamping horizontal
        If x2 >= lg_src : x2 = lg_src - 1 : EndIf
        
        ; --- Lecture des 4 voisins ---
        *c00 = \addr[0] + ((y1 * lg_src + x1) << 2) ; Top-Left
        *c10 = \addr[0] + ((y1 * lg_src + x2) << 2) ; Top-Right
        *c01 = \addr[0] + ((y2 * lg_src + x1) << 2) ; Bottom-Left
        *c11 = \addr[0] + ((y2 * lg_src + x2) << 2) ; Bottom-Right
        
        ; --- Interpolation Bilinéaire ---
        ; Formule : (A * (1-wX) + B * wX) * (1-wY) + (C * (1-wX) + D * wX) * wY
        
        ; Canal Rouge
        ;r = (*c00\r * (1 - weightX) + *c10\r * weightX) * (1 - weightY) + (*c01\r * (1 - weightX) + *c11\r * weightX) * weightY
        ; Canal Vert
        ;g = (*c00\g * (1 - weightX) + *c10\g * weightX) * (1 - weightY) + (*c01\g * (1 - weightX) + *c11\g * weightX) * weightY
        ; Canal Bleu
        ;b = (*c00\b * (1 - weightX) + *c10\b * weightX) * (1 - weightY) + (*c01\b * (1 - weightX) + *c11\b * weightX) * weightY
        ; Canal Alpha (optionnel, sinon copier simplement *c00\a)
        ;a = (*c00\a * (1 - weightX) + *c10\a * weightX) * (1 - weightY) + (*c01\a * (1 - weightX) + *c11\a * weightX) * weightY

        ; --- Écriture ---
        *dstPix = \addr[1] + ((y * lg_dst + x) << 2)
        ;*dstPix\r = r
        ;*dstPix\g = g
        ;*dstPix\b = b
        ;*dstPix\a = a
      Next
    Next
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeBilinearEx(*FilterCtx.FilterParams)
  Restore ResizeBilinear_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeBilinear_sp())
EndProcedure

; ===== Appel simplifié =====
Procedure ResizeBilinear(source, cible, lg, ht)
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = lg
    \image_ht[1] = ht
  EndWith
  ResizeBilinearEx(FilterCtx)
EndProcedure

DataSection
  ResizeBilinear_data:
  Data.s "ResizeBilinear"
  Data.s "Redimensionnement Bilinéaire (Lissage)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Largeur Cible"
  Data.i 1, 4096, 800
  Data.s "Hauteur Cible"
  Data.i 1, 4096, 600
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 90
; FirstLine = 41
; Folding = -
; EnableXP
; DPIAware