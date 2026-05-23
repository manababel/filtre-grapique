; ===== Bell Resize (multithread) =====
Procedure ResizeBell_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y, i, j
    Protected x_src.f, y_src.f, f.f
    Protected r.f, g.f, b.f, a.f
    Protected *dstPix.Pixel32, *srcPix.Pixel32
    
    Protected ratioX.f = lg_src / lg_dst
    Protected ratioY.f = ht_src / ht_dst
    
    ; Tableaux pour stocker les poids (fenêtre de 3 à 4 pixels pour Bell)
    Dim weightsX.f(3)
    Dim weightsY.f(3)
    Dim indicesX(3)
    Dim indicesY(3)
    
    macro_calul_tread(ht_dst)
    
    For y = thread_start To thread_stop - 1
      y_src = (y + 0.5) * ratioY
      
      ; Calcul des poids verticaux (Bell Spline)
      For j = 0 To 3
        indicesY(j) = Int(y_src - 1.5 + j)
        ; Clamping
        If indicesY(j) < 0 : indicesY(j) = 0 : ElseIf indicesY(j) >= ht_src : indicesY(j) = ht_src - 1 : EndIf
        
        f = Abs(indicesY(j) - y_src)
        If f < 0.5
          weightsY(j) = 0.75 - (f * f)
        ElseIf f < 1.5
          weightsY(j) = 0.5 * Pow(1.5 - f, 2)
        Else
          weightsY(j) = 0
        EndIf
      Next j
      
      For x = 0 To lg_dst - 1
        x_src = (x + 0.5) * ratioX
        
        ; Calcul des poids horizontaux
        For i = 0 To 3
          indicesX(i) = Int(x_src - 1.5 + i)
          ; Clamping
          If indicesX(i) < 0 : indicesX(i) = 0 : ElseIf indicesX(i) >= lg_src : indicesX(i) = lg_src - 1 : EndIf
          
          f = Abs(indicesX(i) - x_src)
          If f < 0.5
            weightsX(i) = 0.75 - (f * f)
          ElseIf f < 1.5
            weightsX(i) = 0.5 * Pow(1.5 - f, 2)
          Else
            weightsX(i) = 0
          EndIf
        Next i
        
        r = 0 : g = 0 : b = 0 : a = 0
        
        ; Accumulation des 16 pixels (4x4) pour un résultat optimal
        For j = 0 To 3
          For i = 0 To 3
            *srcPix = \addr[0] + ((indicesY(j) * lg_src + indicesX(i)) << 2)
            Protected w.f = weightsX(i) * weightsY(j)
            ;r + *srcPix\r * w
            ;g + *srcPix\g * w
            ;b + *srcPix\b * w
            ;a + *srcPix\a * w
          Next i
        Next j
        
        ; Écriture finale
        *dstPix = \addr[1] + ((y * lg_dst + x) << 2)
        ;*dstPix\r = Filter_Limit(r)
        ;*dstPix\g = Filter_Limit(g)
        ;*dstPix\b = Filter_Limit(b)
        ;*dstPix\a = Filter_Limit(a)
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeBellEx(*FilterCtx.FilterParams)
  Restore ResizeBell_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeBell_sp())
EndProcedure

; ===== Appel simplifié =====
Procedure ResizeBell(source, cible, lg, ht)
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = lg
    \image_ht[1] = ht
  EndWith
  ResizeBellEx(FilterCtx)
EndProcedure

DataSection
  ResizeBell_data:
  Data.s "ResizeBell"
  Data.s "Redimensionnement Bell (Lissage Doux)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Largeur Cible"
  Data.i 1, 4096, 800
  Data.s "Hauteur Cible"
  Data.i 1, 4096, 600
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 81
; FirstLine = 62
; Folding = -
; EnableXP
; DPIAware