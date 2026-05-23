; ===== xBRZ 3x Resize (Logiciel) =====
; Note: xBRZ fonctionne mieux sur des facteurs entiers (ici x3)
Procedure ResizeXBRZ3_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y, i, j, k
    Protected *dstPix.Pixel32, *p.Pixel32
    
    ; Matrice de voisinage 3x3 (9 pixels)
    ; [A][B][C]
    ; [D][E][F]
    ; [G][H][I]  <- E est le pixel central
    Dim *m.Pixel32(8) 
    
    macro_calul_tread(ht_src) ; On itère sur la source pour xBRZ
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg_src - 1
        
        ; 1. Remplissage de la matrice de voisinage avec Clamping
        For j = -1 To 1
          For i = -1 To 1
            Protected py = y + j : If py < 0 : py = 0 : ElseIf py >= ht_src : py = ht_src - 1 : EndIf
            Protected px = x + i : If px < 0 : px = 0 : ElseIf px >= lg_src : px = lg_src - 1 : EndIf
            *m((j+1)*3 + (i+1)) = \addr[0] + ((py * lg_src + px) << 2)
          Next i
        Next j
        
        ; 2. Récupération des pointeurs de la matrice pour clarté
        ; A=*m(0) B=*m(1) C=*m(2) D=*m(3) E=*m(4) F=*m(5) G=*m(6) H=*m(7) I=*m(8)
        
        ; 3. Génération du bloc 3x3 dans la destination
        ; Chaque pixel source E devient 9 pixels (3x3) dans la cible
        For j = 0 To 2
          For i = 0 To 2
            *dstPix = \addr[1] + (((y * 3 + j) * lg_dst + (x * 3 + i)) << 2)
            
            ; Logique Simplifiée xBRZ : 
            ; On compare les distances de couleurs pour décider si on garde E 
            ; ou si on interpole vers un voisin pour lisser une diagonale.
            
            ;Protected dist_f.f = Abs(*m(1)\r - *m(5)\r) + Abs(*m(1)\g - *m(5)\g) ; dist(B,F)
           ; Protected dist_d.f = Abs(*m(1)\r - *m(3)\r) + Abs(*m(1)\g - *m(3)\g) ; dist(B,D)
            
            ; Ici on applique une version très simplifiée de la règle de mélange
            ; (Normalement, xBRZ utilise des seuils et des analyses d'angles)
            ;If dist_f < dist_d And i > 1 ; Si on est sur le bord droit, on tire vers F
               ;*dstPix\r = (*m(4)\r + *m(5)\r) / 2
               ;*dstPix\g = (*m(4)\g + *m(5)\g) / 2
               ;*dstPix\b = (*m(4)\b + *m(5)\b) / 2
            ;Else
               ;*dstPix\r = *m(4)\r ; Par défaut, on garde le pixel central E
               ;*dstPix\g = *m(4)\g
               ;*dstPix\b = *m(4)\b
            ;EndIf
            ;*dstPix\a = *m(4)\a
          Next i
        Next j
        
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeXBRZ3Ex(*FilterCtx.FilterParams)
  Restore ResizeXBRZ3_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeXBRZ3_sp())
EndProcedure

; ===== Appel simplifié (Force le x3) =====
Procedure ResizeXBRZ3(source, cible)
  Protected lg = ImageWidth(source) * 3
  Protected ht = ImageHeight(source) * 3
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = lg
    \image_ht[1] = ht
  EndWith
  ResizeXBRZ3Ex(FilterCtx)
EndProcedure

DataSection
  ResizeXBRZ3_data:
  Data.s "ResizeXBRZ3"
  Data.s "xBRZ Scaling x3 (Haut Contraste)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Largeur Cible (Info)"
  Data.i 1, 12288, 0
  Data.s "Hauteur Cible (Info)"
  Data.i 1, 12288, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 59
; FirstLine = 45
; Folding = -
; EnableXP
; DPIAware