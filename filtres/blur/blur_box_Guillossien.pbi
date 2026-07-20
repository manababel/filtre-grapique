Macro blur_box_Guillossien_create_limit_sp0(opt , tail , vers)
  e = (tail - 1) + ( 2 * opt )
  For i = 0 To e : *pointeur#vers\l[i] = (i + tail - opt) % tail : Next
EndMacro

Macro blur_box_Guillossien_create_limit_sp1(opt , tail , vers)
  e = tail + (2 * opt) - 1
  For i = 0 To e : ii = i - opt : clamp( ii , 0 , (tail - 1)) : *pointeur#vers\l[i] = ii : Next
EndMacro

Procedure blur_box_Guillossien_create_limit(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected.l lg = \image_lg[0]              ; largeur de l'image
    Protected.l ht = \image_ht[0]              ; hauteur de l'image
    Protected.l optx = \option[0]
    Protected.l opty = \option[1]
    Protected *pointeur1.Array32 = \addr[2]
    Protected *pointeur2.Array32 = \addr[3]
    Protected.l i, e, ii
    If \option[3] ; Pré-calcul des indices pour gestion des bords
      blur_box_Guillossien_create_limit_sp0(optx , lg , 1)
      blur_box_Guillossien_create_limit_sp0(opty , ht , 2)
    Else ; Mode bord : pixels répétés aux extrémités   
      blur_box_Guillossien_create_limit_sp1(optx , lg , 1)
      blur_box_Guillossien_create_limit_sp1(opty , ht , 2)
    EndIf 
  EndWith
EndProcedure

Procedure blur_box_Guillossien_MT(*FilterCtx.FilterParams)
  
  ; Accumulateurs pour composantes ARGB
  Protected ax1, rx1, gx1, bx1
  Protected a1.l, r1.l, b1.l, g1.l
  Protected a2.l, r2.l, b2.l, g2.l
  ; Index temporaires
  Protected j, i, p1, p2
  ; Paramètres de l’image
  With *FilterCtx
    ; Déclarations de pointeurs pixel source/destination
    Protected *srcPixel.Pixelarray32 = \addr[0]
    Protected *dstPixel.Pixelarray32 = \addr[1]
    Protected *lx.array32 = \addr[2]
    Protected *ly.array32 = \addr[3]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    ; Paramètres du filtre
    Protected nrx = (\option[0] * 2) + 1
    Protected nry = (\option[1] * 2) + 1
    Protected div = Int($800000 / (nrx * nry))  ; Pow(2,23) = $800000
    
    macro_calul_tread(ht)
    
    ; Buffers pour accumuler les sommes par colonne
    Protected Dim a.l(lg) , Dim r.l(lg) , Dim g.l(lg) , Dim b.l(lg)
    ; Initialisation des buffers
    FillMemory(@a(), lg * 4, 0) : FillMemory(@r(), lg * 4, 0) : FillMemory(@g(), lg * 4, 0) : FillMemory(@b(), lg * 4, 0)
    ; === Étape 1 : Accumule les lignes verticales pour démarrer ===
    For j = 0 To nry - 1
      p1 = *ly\l[j + thread_start] * lg
      For i = 0 To lg - 1
        getargb(*srcPixel\pixel[p1 + i], a1, r1, g1, b1)
        a(i) + a1 : r(i) + r1 : g(i) + g1 : b(i) + b1
      Next
    Next
    ; === Étape 2 : Application du filtre pour chaque ligne ===
    For j = thread_start To thread_stop - 1
      ; Mise à jour du buffer colonne (soustraction d’une ancienne ligne et ajout d’une nouvelle)
      p1 = ( *ly\l[j + nry] * lg)
      p2 = ( *ly\l[j]       * lg)
      For i = 0 To lg - 1
        getargb(*srcPixel\pixel[p1 + i], a1, r1, g1, b1)
        getargb(*srcPixel\pixel[p2 + i], a2, r2, g2, b2)
        a(i) + a1 - a2
        r(i) + r1 - r2
        g(i) + g1 - g2
        b(i) + b1 - b2
      Next
      ; Application du filtre horizontal
      ax1 = 0 : rx1 = 0 : gx1 = 0 : bx1 = 0
      For i = 0 To nrx - 1
        p1 = *lx\l[i]
        ax1 + a(p1)
        rx1 + r(p1)
        gx1 + g(p1)
        bx1 + b(p1)
      Next
      ; Boucle de sortie pour chaque pixel de la ligne
      For i = 0 To lg - 1
        p1 = *lx\l[i + nrx]
        p2 = *lx\l[i]
        ax1 + a(p1) - a(p2)
        rx1 + r(p1) - r(p2)
        gx1 + g(p1) - g(p2)
        bx1 + b(p1) - b(p2)
        ; Calcul final avec facteur de division
        a1 = (ax1 * div) >> 23
        r1 = (rx1 * div) >> 23
        g1 = (gx1 * div) >> 23
        b1 = (bx1 * div) >> 23
        ; Écriture dans le buffer temporaire
        *dstPixel\pixel[(j * lg + i)] = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
      Next
    Next
    ; Libération des tableaux
    FreeArray(a())
    FreeArray(r())
    FreeArray(g())
    FreeArray(b())
  EndWith
EndProcedure

Procedure GuillossienEx(*FilterCtx.FilterParams)
  Restore Guillossien_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]
    Protected.l optx = \option[0]
    Protected.l opty = \option[1]
    
    ;*****************************************************************************************************************
    ;-- Allocation mémoire pour la gestion de bords
    \addr[2] = AllocateMemory((lg + 2 * (optx + 2)) * 4)
    \addr[3] = AllocateMemory((ht + 2 * (opty + 2)) * 4)
    ;-- Allocation mémoire pour l'image temporaire
    \addr[4] = AllocateMemory(lg * ht * 4)
    If \addr[4] = 0 Or \addr[2] = 0 Or \addr[3] = 0
      If \addr[2] : FreeMemory(\addr[2]) : EndIf
      If \addr[3] : FreeMemory(\addr[3]) : EndIf
      If \addr[4] : FreeMemory(\addr[4]) : EndIf
      ProcedureReturn
    EndIf
    
    ;*****************************************************************************************************************
    ;-- cacul_des_bords
    blur_box_Guillossien_create_limit(*FilterCtx.FilterParams)
    ;*****************************************************************************************************************
    
    ; --- 1er passe
    ; ---- Passe X ----
    \addr[0] = \image[0]
    \addr[1] = \image[1]
    Create_MultiThread_MT(@blur_box_Guillossien_MT())
    ;*************************************************
    ; --- 2" et 3e passe ---
    If \option[2] = 2
      \addr[0] = \image[1]
      \addr[1] = \addr[4]
      Create_MultiThread_MT(@blur_box_Guillossien_MT())
      CopyMemory(\addr[4], \image[1], lg * ht * 4)
    EndIf
    
    If \option[2] = 3 
      \addr[0] = \image[1]
      \addr[1] = \addr[4]
      Create_MultiThread_MT(@blur_box_Guillossien_MT())
      \addr[0] = \addr[4]
      \addr[1] = \image[1]
      Create_MultiThread_MT(@blur_box_Guillossien_MT())
    EndIf
    
    mask_update(*FilterCtx.FilterParams , last_data)
    ; Libération mémoire
    FreeMemory(\addr[2])
    FreeMemory(\addr[3])
    FreeMemory(\addr[4])
  EndWith
EndProcedure

Procedure Guillossien(source , cible , mask , rx , ry , ndp = 1, bord = 0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rx
    \option[1] = ry
    \option[2] = ndp
    \option[3] = bord
  EndWith
  GuillossienEX(FilterCtx.FilterParams)
EndProcedure


DataSection
  Guillossien_data:
  Data.s "Guillossien"
  Data.s "Blur Box optimise (erreur de decalage)"
  Data.i #FilterType_Blur
  Data.i #Blur_Classic
  
  Data.s "Rayon X"           ; Rayon horizontal
  Data.i 0,63,1
  Data.s "Rayon Y"           ; Rayon vertical
  Data.i 0,63,1
  Data.s "Nombre de passe"   ; Nombre d'itérations du filtre
  Data.i 1,3,1
  Data.s "bord"              ; Mode bord ou boucle
  Data.i 0,1,0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 188
; FirstLine = 153
; Folding = --
; EnableXP
; DPIAware