; ===== AdvMAME2x Resize (Multithread) =====
Procedure ResizeAdvMAME2x_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y
    Protected *dstLine0.Pixel32, *dstLine1.Pixel32
    
    ; Voisinage (Matrice de lecture)
    ;     [B]
    ; [D] [E] [F]
    ;     [H]
    Protected.l colorE, colorB, colorD, colorF, colorH
    
    macro_calul_tread(ht_src)
    
    For y = thread_start To thread_stop - 1
      ; Calcul des pointeurs de ligne de destination (y*2 et y*2 + 1)
      *dstLine0 = \addr[1] + ((y * 2) * lg_dst << 2)
      *dstLine1 = \addr[1] + (((y * 2 + 1) * lg_dst) << 2)
      
      For x = 0 To lg_src - 1
        ; 1. Récupération des couleurs (Format Long pour comparaison rapide)
        Protected *ptrE.Pixel32 = \addr[0] + ((y * lg_src + x) << 2)
        colorE = *ptrE\l
        
        ; Clamping rapide des voisins
        If y > 0 : colorB = PeekL(*ptrE - (lg_src << 2)) : Else : colorB = colorE : EndIf
        If y < ht_src - 1 : colorH = PeekL(*ptrE + (lg_src << 2)) : Else : colorH = colorE : EndIf
        If x > 0 : colorD = PeekL(*ptrE - 4) : Else : colorD = colorE : EndIf
        If x < lg_src - 1 : colorF = PeekL(*ptrE + 4) : Else : colorF = colorE : EndIf
        
        ; 2. Application des règles AdvMAME2x
        ; Par défaut, les 4 sous-pixels sont égaux au pixel central E
        Protected p0=colorE, p1=colorE, p2=colorE, p3=colorE
        
        ; Si on détecte une ligne/diagonale (B=D et B<>H et D<>F)
        If colorB = colorD And colorB <> colorH And colorD <> colorF
          p0 = colorD
        EndIf
        
        If colorB = colorF And colorB <> colorH And colorF <> colorD
          p1 = colorF
        EndIf
        
        If colorD = colorH And colorD <> colorB And colorH <> colorF
          p2 = colorD
        EndIf
        
        If colorH = colorF And colorH <> colorB And colorF <> colorD
          p3 = colorF
        EndIf
        
        ; 3. Écriture dans la destination (2x2 pixels)
        ; Ligne haute du bloc 2x2
        *dstLine0\l = p0 : *dstLine0 + 4
        *dstLine0\l = p1 : *dstLine0 + 4
        
        ; Ligne basse du bloc 2x2
        *dstLine1\l = p2 : *dstLine1 + 4
        *dstLine1\l = p3 : *dstLine1 + 4
        
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeAdvMAME2xEx(*FilterCtx.FilterParams)
  Restore ResizeAdvMAME2x_data
  Protected last_data = Filter_InitAndValidate(1)
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeAdvMAME2x_sp())
EndProcedure

; ===== Appel =====
Procedure ResizeAdvMAME2x(source, cible)
  Set_Source(source)
  Set_Cible(cible)
  ResizeAdvMAME2xEx(FilterCtx)
EndProcedure

DataSection
  ResizeAdvMAME2x_data:
  Data.s "ResizeAdvMAME2x"
  Data.s "AdvMAME2x (Pixel Art Optimizer)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 81
; FirstLine = 37
; Folding = -
; EnableXP
; DPIAware