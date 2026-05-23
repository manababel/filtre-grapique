; ===== xBRZ 6x Resize (Multithread) =====
Procedure ResizeXBRZ6_sp(*FilterCtx.FilterParams)
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
        
        ; 1. Remplissage de la matrice 3x3 (Voisinage du pixel E)
        For j = -1 To 1
          For i = -1 To 1
            Protected py = y + j : If py < 0 : py = 0 : ElseIf py >= ht_src : py = ht_src - 1 : EndIf
            Protected px = x + i : If px < 0 : px = 0 : ElseIf px >= lg_src : px = lg_src - 1 : EndIf
            *m((j+1)*3 + (i+1)) = \addr[0] + ((py * lg_src + px) << 2)
          Next i
        Next j
        
        Protected.Pixel32 *E = *m(4), *B = *m(1), *D = *m(3), *F = *m(5), *H = *m(7)
        
        ; 2. Calcul des distances (Analyse de contraste)
        ;Protected dist_f = Abs(*B\r - *F\r) + Abs(*B\g - *F\g) + Abs(*B\b - *F\b)
        ;Protected dist_d = Abs(*B\r - *D\r) + Abs(*B\g - *D\g) + Abs(*B\b - *D\b)
        
        ; 3. Remplissage du bloc 6x6 de destination
        For j = 0 To 5
          For i = 0 To 5
            *dstPix = \addr[1] + (((y * 6 + j) * lg_dst + (x * 6 + i)) << 2)
            
            ; Logique de détection de coin pour le 6x
            ; On applique un mélange si on s'éloigne du centre vers les bords
            Protected blend = #False
            If i > 2 And j < 3 ; Secteur Haut-Droite
              ;If dist_f < dist_d : blend = #True : EndIf
            ElseIf i < 3 And j < 3 ; Secteur Haut-Gauche
              ;If dist_d < dist_f : blend = #True : EndIf
            EndIf
            
            If blend
              ; Mélange 1/3 Voisin - 2/3 Centre pour un lissage progressif
              ;*dstPix\r = (*E\r * 2 + *F\r) / 3
              ;*dstPix\g = (*E\g * 2 + *F\g) / 3
              ;*dstPix\b = (*E\b * 2 + *F\b) / 3
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
Procedure ResizeXBRZ6Ex(*FilterCtx.FilterParams)
  Restore ResizeXBRZ6_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeXBRZ6_sp())
EndProcedure

; ===== Appel x6 =====
Procedure ResizeXBRZ6(source, cible)
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = ImageWidth(source) * 6
    \image_ht[1] = ImageHeight(source) * 6
  EndWith
  ResizeXBRZ6Ex(FilterCtx)
EndProcedure

DataSection
  ResizeXBRZ6_data:
  Data.s "ResizeXBRZ6"
  Data.s "xBRZ Scaling x6 (High Definition)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Info" : Data.i 0, 0, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 93
; FirstLine = 41
; Folding = -
; EnableXP
; DPIAware