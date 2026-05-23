; ===== hq2x Resize (Multithread) =====

; Fonction de comparaison RGB rapide (sans pointeurs)
Procedure.i hq2x_Diff(c1.l, c2.l, threshold)
  Protected r1, g1, b1
  Protected r2, g2, b2
  
  ; Extraction directe des canaux (ajuste les décalages si ton format est BGRA au lieu de ARGB)
  r1 = (c1 >> 16) & $FF
  g1 = (c1 >> 8)  & $FF
  b1 = c1 & $FF
  
  r2 = (c2 >> 16) & $FF
  g2 = (c2 >> 8)  & $FF
  b2 = c2 & $FF
  
  ; Si la différence sur TOUS les canaux est inférieure au seuil, ils sont similaires (0)
  If Abs(r1 - r2) < threshold And Abs(g1 - g2) < threshold And Abs(b1 - b2) < threshold
    ProcedureReturn 0 
  EndIf
  
  ProcedureReturn 1 ; Couleurs différentes
EndProcedure

Procedure ResizeHq2x_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1] ; Utilise la valeur de la structure cible
    
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    Protected x, y, pos1, pos_dst
    Protected pixel_idx
    Protected c1, c2, c3, c4, c5, c6, c7, c8, c9 ; Les 9 pixels de la fenêtre 3x3
    Protected p1, p2, p3, p4                     ; Les 4 pixels de sortie
    Protected.i next_row_dst = lg_dst
    
    macro_calul_tread(ht_src) ; On itère sur la SOURCE
    
    For y = thread_start To thread_stop - 1
      pos_dst = (y * 2 * lg_dst) ; Alignement ligne de destination
      
      For x = 0 To lg_src - 1
        pos1 = (y * lg_src) + x
        c5 = *src\pixel[pos1] ; Pixel central
        
        ; --- 1. Lecture sécurisée du voisinage 3x3 ---
        
        ; Ligne supérieure (c1, c2, c3)
        If y > 0
          c2 = *src\pixel[pos1 - lg_src]
          
          If x > 0
            c1 = *src\pixel[pos1 - lg_src - 1]
          Else
            c1 = c2
          EndIf
          
          If x < lg_src - 1
            c3 = *src\pixel[pos1 - lg_src + 1]
          Else
            c3 = c2
          EndIf
        Else
          c2 = c5 : c1 = c5 : c3 = c5
        EndIf
        
        ; Ligne centrale (c4, c6)
        If x > 0
          c4 = *src\pixel[pos1 - 1]
        Else
          c4 = c5
        EndIf
        
        If x < lg_src - 1
          c6 = *src\pixel[pos1 + 1]
        Else
          c6 = c5
        EndIf
        
        ; Ligne inférieure (c7, c8, c9)
        If y < ht_src - 1
          c8 = *src\pixel[pos1 + lg_src]
          
          If x > 0
            c7 = *src\pixel[pos1 + lg_src - 1]
          Else
            c7 = c8
          EndIf
          
          If x < lg_src - 1
            c9 = *src\pixel[pos1 + lg_src + 1]
          Else
            c9 = c8
          EndIf
        Else
          c8 = c5 : c7 = c5 : c9 = c5
        EndIf
        
        ; --- 2. Création de l'index de voisinage (8 bits) ---
        pixel_idx = 0
        If hq2x_Diff(c5, c1, 32) : pixel_idx | 1   : EndIf
        If hq2x_Diff(c5, c2, 32) : pixel_idx | 2   : EndIf
        If hq2x_Diff(c5, c3, 32) : pixel_idx | 4   : EndIf
        If hq2x_Diff(c5, c4, 32) : pixel_idx | 8   : EndIf
        If hq2x_Diff(c5, c6, 32) : pixel_idx | 16  : EndIf
        If hq2x_Diff(c5, c7, 32) : pixel_idx | 32  : EndIf
        If hq2x_Diff(c5, c8, 32) : pixel_idx | 64  : EndIf
        If hq2x_Diff(c5, c9, 32) : pixel_idx | 128 : EndIf
        
        ; --- 3. Logique d'interpolation hq2x ---
        ; Note : Pour avoir le vrai hq2x complet, il faudra brancher une table (LUT) 
        ; contenant les 256 combinaisons de pixel_idx. En attendant, voici le rendu par défaut :
        p1 = c5 : p2 = c5 : p3 = c5 : p4 = c5
        
        ; --- 4. Écriture du bloc 2x2 ---
        *dst\pixel[pos_dst]                 = p1
        *dst\pixel[pos_dst + 1]             = p2
        *dst\pixel[pos_dst + next_row_dst]     = p3
        *dst\pixel[pos_dst + next_row_dst + 1] = p4
        
        pos_dst + 2 ; Avancer de 2 pixels en destination
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeHq2xEx(*FilterCtx.FilterParams)
  Restore ResizeHq2x_data
  Protected last_data = Filter_InitAndValidate(1)
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  ; CORRECTION : On appelle bien la procédure hq2x et pas l'ancienne 2xSaI !
  Create_MultiThread_MT(@ResizeHq2x_sp())
EndProcedure

; ===== Appel =====
Procedure ResizeHq2x(source, cible)
  Set_Source(source)
  Set_Cible(cible)
  ResizeHq2xEx(FilterCtx)
EndProcedure

DataSection
  ResizeHq2x_data:
  Data.s "ResizeHq2x"
  Data.s "Hq2x (High Quality 2x)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 121
; FirstLine = 99
; Folding = -
; EnableXP
; DPIAware