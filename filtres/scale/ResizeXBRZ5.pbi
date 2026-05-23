; ===== xBRZ 5x Resize (Multithread) =====
Procedure ResizeXBRZ5_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y, i, j
    Protected *dstPix.Pixel32
    
    ; Matrice de voisinage 3x3
    ; [0][1][2] -> A B C
    ; [3][4][5] -> D E F
    ; [6][7][8] -> G H I
    Dim *m.Pixel32(8) 
    
    macro_calul_tread(ht_src) 
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg_src - 1
        
        ; 1. Remplissage de la matrice 3x3
        For j = -1 To 1
          For i = -1 To 1
            Protected py = y + j : If py < 0 : py = 0 : ElseIf py >= ht_src : py = ht_src - 1 : EndIf
            Protected px = x + i : If px < 0 : px = 0 : ElseIf px >= lg_src : px = lg_src - 1 : EndIf
            *m((j+1)*3 + (i+1)) = \addr[0] + ((py * lg_src + px) << 2)
          Next i
        Next j
        
        Protected.Pixel32 *E = *m(4), *B = *m(1), *D = *m(3), *F = *m(5), *H = *m(7)
        
        ; 2. Analyse des distances (Luminance simplifiée)
        ;Protected dist_f = Abs(*B\r - *F\r) + Abs(*B\g - *F\g) + Abs(*B\b - *F\b)
        ;Protected dist_d = Abs(*B\r - *D\r) + Abs(*B\g - *D\g) + Abs(*B\b - *D\b)
        
        ; 3. Remplissage du bloc 5x5
        For j = 0 To 4
          For i = 0 To 4
            *dstPix = \addr[1] + (((y * 5 + j) * lg_dst + (x * 5 + i)) << 2)
            
            ; Détermination du mélange selon la position dans la grille 5x5
            ; Plus on est loin du centre (2,2), plus l'influence des voisins augmente
            Protected weight.f = 0.0
            
            ; Logique de détection de coin pour le x5
            If i > 2 And j < 2 ; Zone Nord-Est
              ;If dist_f < dist_d : weight = 0.4 : EndIf
            ElseIf i < 2 And j < 2 ; Zone Nord-Ouest
              ;If dist_d < dist_f : weight = 0.4 : EndIf
            EndIf
            
            ; Application du lissage
            If weight > 0
              ;*dstPix\r = *E\r * (1 - weight) + *F\r * weight
              ;*dstPix\g = *E\g * (1 - weight) + *F\g * weight
              ;*dstPix\b = *E\b * (1 - weight) + *F\b * weight
            Else
              ;*dstPix\r = *E\r
              ;*dstPix\g = *E\g
              ;*dstPix\b = *E\b
            EndIf
            ;*dstPix\a = *E\a
          Next i
        Next j
        
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeXBRZ5Ex(*FilterCtx.FilterParams)
  Restore ResizeXBRZ5_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeXBRZ5_sp())
EndProcedure

; ===== Appel x5 =====
Procedure ResizeXBRZ5(source, cible)
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = ImageWidth(source) * 5
    \image_ht[1] = ImageHeight(source) * 5
  EndWith
  ResizeXBRZ5Ex(FilterCtx)
EndProcedure

DataSection
  ResizeXBRZ5_data:
  Data.s "ResizeXBRZ5"
  Data.s "xBRZ Scaling x5 (Ultra Sharp)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Info" : Data.i 0, 0, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 95
; FirstLine = 43
; Folding = -
; EnableXP
; DPIAware