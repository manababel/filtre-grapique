; ===== Super Eagle Resize (Multithread) =====
Procedure ResizeSuperEagle_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y
    Protected.l c1, c2, c3, c4, c5, c6, c7, c8, c9, s1, s2, s3, s4 ; Couleurs de voisinage
    
    macro_calul_tread(ht_src)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg_src - 1
        
        ; 1. Lecture du voisinage 3x3 étendu (simplifié pour la structure)
        ; [c1][c2][c3]
        ; [c4][c5][c6]  <- c5 est le pixel courant
        ; [c7][c8][c9]
        
        ; Pour un vrai Super Eagle, on lit normalement 16 pixels (4x4), 
        ; mais voici la logique de mélange 2x2 basée sur les contrastes :
        
        Protected *ptr.Pixel32 = \addr[0] + ((y * lg_src + x) << 2)
        c5 = *ptr\l
        
        ; Voisins directs (avec protection bord)
        If x>0 And y>0 : c1 = PeekL(*ptr - 4 - (lg_src<<2)) : Else : c1 = c5 : EndIf
        If y>0 : c2 = PeekL(*ptr - (lg_src<<2)) : Else : c2 = c5 : EndIf
        If x<lg_src-1 And y>0 : c3 = PeekL(*ptr + 4 - (lg_src<<2)) : Else : c3 = c5 : EndIf
       ; If x>0 : c4 = PeekL(*ptr - 4) : Else : colorD = c5 : EndIf
        If x<lg_src-1 : c6 = PeekL(*ptr + 4) : Else : c6 = c5 : EndIf
        If x>0 And y<ht_src-1 : c7 = PeekL(*ptr - 4 + (lg_src<<2)) : Else : c7 = c5 : EndIf
        If y<ht_src-1 : c8 = PeekL(*ptr + (lg_src<<2)) : Else : c8 = c5 : EndIf
        If x<lg_src-1 And y<ht_src-1 : c9 = PeekL(*ptr + 4 + (lg_src<<2)) : Else : c9 = c5 : EndIf

        ; 2. Logique de mélange (Blending)
        ; Le Super Eagle utilise des moyennes de couleurs si des diagonales sont détectées
        Protected p1, p2, p3, p4
        
        If c5 = c9 And c6 <> c8
          If (c5 = c2 And c5 = c4) Or (c9 = c3 And c9 = c6) ; Diagonale forte
             p1 = c5
          Else
             p1 = (c5 + c2) >> 1 ; Moyenne simple
          EndIf
          p4 = c9
          p2 = (c5 + c6) >> 1
          p3 = (c5 + c8) >> 1
        ElseIf c6 = c8 And c5 <> c9
          p1 = (c5 + c6) >> 1
          p2 = c6
          p3 = c8
          p4 = (c8 + c9) >> 1
        ElseIf c5 = c9 And c6 = c8
          p1 = c5 : p2 = c5 : p3 = c5 : p4 = c5
        Else
          p1 = c5 : p2 = (c5 + c6) >> 1
          p3 = (c5 + c8) >> 1
          p4 = (c6 + c8) >> 1
        EndIf

        ; 3. Écriture 2x2
        Protected *dst.Pixel32 = \addr[1] + (((y * 2) * lg_dst + (x * 2)) << 2)
        ;*dst\l = p1 : (*dst + 4)\l = p2
        *dst = \addr[1] + (((y * 2 + 1) * lg_dst + (x * 2)) << 2)
        ;*dst\l = p3 : (*dst + 4)\l = p4
        
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeSuperEagleEx(*FilterCtx.FilterParams)
  Restore ResizeSuperEagle_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeSuperEagle_sp())
EndProcedure

; ===== Appel =====
Procedure ResizeSuperEagle(source, cible)
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = ImageWidth(source) * 2
    \image_ht[1] = ImageHeight(source) * 2
  EndWith
  ResizeSuperEagleEx(FilterCtx)
EndProcedure

DataSection
  ResizeSuperEagle_data:
  Data.s "ResizeSuperEagle"
  Data.s "Super Eagle (Smooth & Paint look)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Info" : Data.i 0, 0, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 97
; FirstLine = 45
; Folding = -
; EnableXP
; DPIAware