; ===== EPX Resize (Eric's Pixel Expansion) =====
Procedure ResizeEPX_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y
    Protected *ptrE.Pixel32
    Protected.l colorP, colorA, colorB, colorC, colorD ; Nomenclature EPX originale
    
    macro_calul_tread(ht_src)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg_src - 1
        
        ; 1. Récupération du pixel central P et de ses 4 voisins directs
        ;     [A]
        ; [C] [P] [D]
        ;     [B]
        *ptrE = \addr[0] + ((y * lg_src + x) << 2)
        colorP = *ptrE\l
        
        ; Lecture sécurisée des voisins (Clamping)
        If y > 0 : colorA = PeekL(*ptrE - (lg_src << 2)) : Else : colorA = colorP : EndIf
        If y < ht_src - 1 : colorB = PeekL(*ptrE + (lg_src << 2)) : Else : colorB = colorP : EndIf
        If x > 0 : colorC = PeekL(*ptrE - 4) : Else : colorC = colorP : EndIf
        If x < lg_src - 1 : colorD = PeekL(*ptrE + 4) : Else : colorD = colorP : EndIf
        
        ; 2. Calcul des 4 sous-pixels de sortie (1, 2, 3, 4)
        ; [1][2]
        ; [3][4]
        Protected p1=colorP, p2=colorP, p3=colorP, p4=colorP
        
        ; Règles EPX originales :
        ; Si C==A alors 1=A
        ; Si A==D alors 2=A
        ; Si D==B alors 4=B
        ; Si B==C alors 3=B
        
        ; Condition de sécurité supplémentaire (Optionnelle mais recommandée) :
        ; Si au moins 3 voisins sont identiques, on ne change rien pour éviter de "baver"
        If Not (colorC = colorD And colorA = colorB)
          If colorC = colorA : p1 = colorA : EndIf
          If colorA = colorD : p2 = colorA : EndIf
          If colorD = colorB : p4 = colorB : EndIf
          If colorB = colorC : p3 = colorB : EndIf
        EndIf
        
        ; 3. Écriture dans la destination
        Protected *dstP1.Pixel32 = \addr[1] + (((y * 2) * lg_dst + (x * 2)) << 2)
        Protected *dstP3.Pixel32 = \addr[1] + (((y * 2 + 1) * lg_dst + (x * 2)) << 2)
        
        ;*dstP1\l = p1 : (*dstP1 + 4)\l = p2
        ;*dstP3\l = p3 : (*dstP3 + 4)\l = p4
        
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeEPXEx(*FilterCtx.FilterParams)
  Restore ResizeEPX_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeEPX_sp())
EndProcedure

; ===== Appel =====
Procedure ResizeEPX(source, cible)
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = ImageWidth(source) * 2
    \image_ht[1] = ImageHeight(source) * 2
  EndWith
  ResizeEPXEx(FilterCtx)
EndProcedure

DataSection
  ResizeEPX_data:
  Data.s "ResizeEPX"
  Data.s "EPX (LucasArts Retro Scaling)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Info" : Data.i 0, 0, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 85
; FirstLine = 33
; Folding = -
; EnableXP
; DPIAware