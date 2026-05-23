; ===== Bicubic Kernel (Catmull-Rom) =====
Procedure.f Filter_Bicubic(x.f)
  Protected ax.f = Abs(x)
  Protected x2.f = ax * ax
  Protected x3.f = ax * ax * ax

  ; Formule de Catmull-Rom
  If ax <= 1.0
    ProcedureReturn 1.5 * x3 - 2.5 * x2 + 1.0
  ElseIf ax < 2.0
    ProcedureReturn -0.5 * x3 + 2.5 * x2 - 4.0 * ax + 2.0
  Else
    ProcedureReturn 0.0
  EndIf
EndProcedure

Procedure ResizeBicubic_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y, i, j
    Protected x_src.f, y_src.f, weight.f
    Protected r.f, g.f, b.f, a.f
    Protected *dstPix.Pixel32, *srcPix.Pixel32
    
    Protected ratioX.f = lg_src / lg_dst
    Protected ratioY.f = ht_src / ht_dst
    
    Dim weightsX.f(3)
    Dim weightsY.f(3)
    Dim indicesX(3)
    Dim indicesY(3)
    
    macro_calul_tread(ht_dst)
    
    For y = thread_start To thread_stop - 1
      ; Calcul de la position source (centrage 0.5 pour la précision)
      y_src = (y + 0.5) * ratioY - 0.5
      Protected y_int = Int(y_src)
      
      ; Pré-calcul des poids verticaux
      For j = 0 To 3
        indicesY(j) = y_int - 1 + j
        ; Clamping des bords
        If indicesY(j) < 0 : indicesY(j) = 0 : ElseIf indicesY(j) >= ht_src : indicesY(j) = ht_src - 1 : EndIf
        weightsY(j) = Filter_Bicubic(y_src - indicesY(j))
      Next j
      
      For x = 0 To lg_dst - 1
        x_src = (x + 0.5) * ratioX - 0.5
        Protected x_int = Int(x_src)
        
        ; Pré-calcul des poids horizontaux
        For i = 0 To 3
          indicesX(i) = x_int - 1 + i
          If indicesX(i) < 0 : indicesX(i) = 0 : ElseIf indicesX(i) >= lg_src : indicesX(i) = lg_src - 1 : EndIf
          weightsX(i) = Filter_Bicubic(x_src - indicesX(i))
        Next i
        
        r = 0 : g = 0 : b = 0 : a = 0
        
        ; Interpolation sur les 16 voisins
        For j = 0 To 3
          For i = 0 To 3
            *srcPix = \addr[0] + ((indicesY(j) * lg_src + indicesX(i)) << 2)
            weight = weightsX(i) * weightsY(j)
            ;r + *srcPix\r * weight
            ;g + *srcPix\g * weight
            ;b + *srcPix\b * weight
            ;a + *srcPix\a * weight
          Next i
        Next j
        
        ; Écriture avec Clamping (obligatoire car les poids cubiques peuvent être négatifs)
        *dstPix = \addr[1] + ((y * lg_dst + x) << 2)
        
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        If a < 0 : a = 0 : ElseIf a > 255 : a = 255 : EndIf
        
        ;*dstPix\r = r
        ;*dstPix\g = g
        ;*dstPix\b = b
        ;*dstPix\a = a
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédures Ex / Appel / DataSection (Identiques aux précédentes) =====
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 87
; FirstLine = 39
; Folding = -
; EnableXP
; DPIAware