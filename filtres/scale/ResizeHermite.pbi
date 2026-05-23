; ===== Hermite Resize (multithread) =====
Procedure ResizeHermite_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y, i, j
    Protected x_src.f, y_src.f, weightX.f, weightY.f
    Protected h1.f, h2.f, h3.f, h4.f ; Coefficients d'Hermite
    Protected r.f, g.f, b.f, a.f
    Protected *srcPix.Pixel32, *dstPix.Pixel32
    
    Protected ratioX.f = lg_src / lg_dst
    Protected ratioY.f = ht_src / ht_dst
    
    macro_calul_tread(ht_dst)
    
    For y = thread_start To thread_stop - 1
      y_src = y * ratioY
      weightY = y_src - Int(y_src)
      
      ; Calcul des fonctions de base d'Hermite pour Y
      ; h1(t) = 2t³ - 3t² + 1
      ; h2(t) = -2t³ + 3t²
      h1 = (2.0 * weightY - 3.0) * weightY * weightY + 1.0
      h2 = (-2.0 * weightY + 3.0) * weightY * weightY
      
      ; Indices sources pour Y
      Protected y1 = Int(y_src)
      Protected y2 = y1 + 1
      If y2 >= ht_src : y2 = ht_src - 1 : EndIf
      
      For x = 0 To lg_dst - 1
        x_src = x * ratioX
        weightX = x_src - Int(x_src)
        
        ; Calcul des fonctions de base d'Hermite pour X
        h3 = (2.0 * weightX - 3.0) * weightX * weightX + 1.0
        h4 = (-2.0 * weightX + 3.0) * weightX * weightX
        
        ; Indices sources pour X
        Protected x1 = Int(x_src)
        Protected x2 = x1 + 1
        If x2 >= lg_src : x2 = lg_src - 1 : EndIf
        
        ; Lecture des 4 voisins (Hermite 2x2 est souvent utilisé comme approximation)
        ; Pour un vrai Hermite cubique complet, on utiliserait 16 points, 
        ; mais la version 4 points avec dérivées à zéro (h1/h2) est le standard "Hermite" en imagerie.
        
        Protected *p00.Pixel32 = \addr[0] + ((y1 * lg_src + x1) << 2)
        Protected *p10.Pixel32 = \addr[0] + ((y1 * lg_src + x2) << 2)
        Protected *p01.Pixel32 = \addr[0] + ((y2 * lg_src + x1) << 2)
        Protected *p11.Pixel32 = \addr[0] + ((y2 * lg_src + x2) << 2)
        
        ; Interpolation sur les composantes
        ; On interpole d'abord horizontalement sur les deux lignes, puis verticalement
        
        ; Ligne 1
        ;Protected r1.f = *p00\r * h3 + *p10\r * h4
        ;Protected g1.f = *p00\g * h3 + *p10\g * h4
        ;Protected b1.f = *p00\b * h3 + *p10\b * h4
        ;Protected a1.f = *p00\a * h3 + *p10\a * h4
        
        ; Ligne 2
        ;Protected r2.f = *p01\r * h3 + *p11\r * h4
        ;Protected g2.f = *p01\g * h3 + *p11\g * h4
        ;Protected b2.f = *p01\b * h3 + *p11\b * h4
        ;Protected a2.f = *p01\a * h3 + *p11\a * h4
        
        ; Finale (Verticale)
        *dstPix = \addr[1] + ((y * lg_dst + x) << 2)
        ;*dstPix\r = r1 * h1 + r2 * h2
        ;*dstPix\g = g1 * h1 + g2 * h2
        ;*dstPix\b = b1 * h1 + b2 * h2
        ;*dstPix\a = a1 * h1 + a2 * h2
      Next
    Next
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeHermiteEx(*FilterCtx.FilterParams)
  Restore ResizeHermite_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeHermite_sp())
EndProcedure

; ===== Appel simplifié =====
Procedure ResizeHermite(source, cible, lg, ht)
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = lg
    \image_ht[1] = ht
  EndWith
  ResizeHermiteEx(FilterCtx)
EndProcedure

DataSection
  ResizeHermite_data:
  Data.s "ResizeHermite"
  Data.s "Redimensionnement Hermite (Plus net)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Largeur Cible"
  Data.i 1, 4096, 800
  Data.s "Hauteur Cible"
  Data.i 1, 4096, 600
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 105
; FirstLine = 56
; Folding = -
; EnableXP
; DPIAware