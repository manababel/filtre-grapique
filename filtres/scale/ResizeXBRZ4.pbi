; ===== xBRZ 4x Resize (Multithread) =====
Procedure ResizeXBRZ4_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y, i, j
    Protected *dstPix.Pixel32
    
    ; Matrice de voisinage 3x3 pour l'analyse
    ; [0][1][2]  (A, B, C)
    ; [3][4][5]  (D, E, F) -> E est le centre
    ; [6][7][8]  (G, H, I)
    Dim *m.Pixel32(8) 
    
    macro_calul_tread(ht_src) 
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg_src - 1
        
        ; 1. Remplissage de la matrice 3x3 avec protection des bords
        For j = -1 To 1
          For i = -1 To 1
            Protected py = y + j : If py < 0 : py = 0 : ElseIf py >= ht_src : py = ht_src - 1 : EndIf
            Protected px = x + i : If px < 0 : px = 0 : ElseIf px >= lg_src : px = lg_src - 1 : EndIf
            *m((j+1)*3 + (i+1)) = \addr[0] + ((py * lg_src + px) << 2)
          Next i
        Next j
        
        ; 2. On traite le bloc 4x4 de destination
        ; On définit des pointeurs vers les voisins critiques pour la détection de lignes
        Protected.Pixel32 *E = *m(4), *B = *m(1), *D = *m(3), *F = *m(5), *H = *m(7)
        
        For j = 0 To 3
          For i = 0 To 3
            *dstPix = \addr[1] + (((y * 4 + j) * lg_dst + (x * 4 + i)) << 2)
            
            ; 3. Logique simplifiée de "Blending" xBRZ
            ; On calcule la distance de luminosité/couleur (Simple Manhattan Distance)
            ;Protected dist_f = Abs(*B\r - *F\r) + Abs(*B\g - *F\g) + Abs(*B\b - *F\b)
            ;Protected dist_d = Abs(*B\r - *D\r) + Abs(*B\g - *D\g) + Abs(*B\b - *D\b)
            
            ; Détection basique de diagonale :
            ; Si on est dans un coin du bloc 4x4, on regarde si un voisin est plus proche
            ; qu'un autre pour "arrondir" le pixel.
            
            Protected blend = #False
            If i > 1 And j < 2 ; Quart Nord-Est
              ;If dist_f < dist_d : blend = #True : EndIf
            ElseIf i < 2 And j < 2 ; Quart Nord-Ouest
              ;If dist_d < dist_f : blend = #True : EndIf
            EndIf
            
            If blend
              ; On mélange légèrement le pixel central avec le voisin dominant
              ;*dstPix\r = (*E\r * 3 + *F\r) >> 2
              ;*dstPix\g = (*E\g * 3 + *F\g) >> 2
              ;*dstPix\b = (*E\b * 3 + *F\b) >> 2
            Else
              ; Pixel brut
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
Procedure ResizeXBRZ4Ex(*FilterCtx.FilterParams)
  Restore ResizeXBRZ4_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeXBRZ4_sp())
EndProcedure

; ===== Appel x4 =====
Procedure ResizeXBRZ4(source, cible)
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = ImageWidth(source) * 4
    \image_ht[1] = ImageHeight(source) * 4
  EndWith
  ResizeXBRZ4Ex(FilterCtx)
EndProcedure

DataSection
  ResizeXBRZ4_data:
  Data.s "ResizeXBRZ4"
  Data.s "xBRZ Scaling x4 (Pixel Art Sharp)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Info" : Data.i 0, 0, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 98
; FirstLine = 46
; Folding = -
; EnableXP
; DPIAware