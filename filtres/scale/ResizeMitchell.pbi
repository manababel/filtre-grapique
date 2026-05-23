; ===== Mitchell-Netravali Resize (multithread) =====
Procedure.f Filter_Mitchell(x.f)
  Protected B.f = 1.0/3.0
  Protected C.f = 1.0/3.0
  Protected ax.f = Abs(x)
  Protected x2.f = ax * ax
  Protected x3.f = ax * ax * ax

  If ax < 1.0
    ProcedureReturn ((12.0 - 9.0*B - 6.0*C) * x3 + (-18.0 + 12.0*B + 6.0*C) * x2 + (6.0 - 2.0*B)) / 6.0
  ElseIf ax < 2.0
    ProcedureReturn ((-B - 6.0*C) * x3 + (6.0*B + 30.0*C) * x2 + (-12.0*B - 48.0*C) * ax + (8.0*B + 24.0*C)) / 6.0
  Else
    ProcedureReturn 0.0
  EndIf
EndProcedure

Procedure ResizeMitchell_sp(*FilterCtx.FilterParams)
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
      y_src = (y + 0.5) * ratioY
      
      ; Pré-calcul des poids verticaux
      For j = 0 To 3
        indicesY(j) = Int(y_src - 1.5 + j)
        If indicesY(j) < 0 : indicesY(j) = 0 : ElseIf indicesY(j) >= ht_src : indicesY(j) = ht_src - 1 : EndIf
        weightsY(j) = Filter_Mitchell(indicesY(j) - y_src + 0.5)
      Next j
      
      For x = 0 To lg_dst - 1
        x_src = (x + 0.5) * ratioX
        
        ; Pré-calcul des poids horizontaux
        For i = 0 To 3
          indicesX(i) = Int(x_src - 1.5 + i)
          If indicesX(i) < 0 : indicesX(i) = 0 : ElseIf indicesX(i) >= lg_src : indicesX(i) = lg_src - 1 : EndIf
          weightsX(i) = Filter_Mitchell(indicesX(i) - x_src + 0.5)
        Next i
        
        r = 0 : g = 0 : b = 0 : a = 0
        
        ; Échantillonnage 4x4
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
        
        ; Écriture finale avec clamping
        *dstPix = \addr[1] + ((y * lg_dst + x) << 2)
        ;*dstPix\r = Clamp(r, 0, 255) ; Assure-toi d'avoir une macro ou fonction Clamp
        ;*dstPix\g = Clamp(g, 0, 255)
        ;*dstPix\b = Clamp(b, 0, 255)
        ;*dstPix\a = Clamp(a, 0, 255)
      Next x
    Next y
  EndWith
EndProcedure

; (Les procédures ResizeMitchellEx, ResizeMitchell et la DataSection suivent la même logique que les précédentes)
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 78
; FirstLine = 30
; Folding = -
; EnableXP
; DPIAware