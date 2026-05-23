; ===== Lanczos-3 Resize (36 pixels kernel) =====

; Fonction mathématique Lanczos (Noyau de 3)
Procedure.f Filter_Lanczos(x.f)
  If x = 0 : ProcedureReturn 1.0 : EndIf
  If x <= -3.0 Or x >= 3.0 : ProcedureReturn 0.0 : EndIf
  
  Protected pi.f = #PI
  Protected pix.f = pi * x
  ; Sinc(x) * Sinc(x/3)
  ProcedureReturn (3.0 * Sin(pix) * Sin(pix / 3.0)) / (pix * pix)
EndProcedure

Procedure ResizeLanczos_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y, i, j
    Protected x_src.f, y_src.f
    Protected r.f, g.f, b.f, a.f, weight.f, totalWeight.f
    Protected *dstPix.Pixel32, *srcPix.Pixel32
    
    Protected ratioX.f = lg_src / lg_dst
    Protected ratioY.f = ht_src / ht_dst
    
    macro_calul_tread(ht_dst)
    
    For y = thread_start To thread_stop - 1
      y_src = (y + 0.5) * ratioY
      
      For x = 0 To lg_dst - 1
        x_src = (x + 0.5) * ratioX
        
        r = 0 : g = 0 : b = 0 : a = 0 : totalWeight = 0
        
        ; Fenêtre Lanczos-3 : 6x6 pixels (36 pixels au total)
        ; On regarde de -2 à +3 autour de la position source
        Protected x_start = Int(x_src) - 2
        Protected y_start = Int(y_src) - 2
        
        For j = 0 To 5
          Protected srcY = y_start + j
          ; Clamping vertical
          If srcY < 0 : srcY = 0 : ElseIf srcY >= ht_src : srcY = ht_src - 1 : EndIf
          
          Protected.f weightY = Filter_Lanczos(srcY - y_src + 0.5)
          
          For i = 0 To 5
            Protected srcX = x_start + i
            ; Clamping horizontal
            If srcX < 0 : srcX = 0 : ElseIf srcX >= lg_src : srcX = lg_src - 1 : EndIf
            
            Protected.f weightX = Filter_Lanczos(srcX - x_src + 0.5)
            weight = weightX * weightY
            
            *srcPix = \addr[0] + ((srcY * lg_src + srcX) << 2)
            
            ;r + (*srcPix\r * weight)
            ;g + (*srcPix\g * weight)
            ;b + (*srcPix\b * weight)
            ;a + (*srcPix\a * weight)
            totalWeight + weight
          Next i
        Next j
        
        ; Écriture finale avec normalisation du poids
        *dstPix = \addr[1] + ((y * lg_dst + x) << 2)
        If totalWeight <> 0
          ;*dstPix\r = Filter_Limit(r / totalWeight)
          ;*dstPix\g = Filter_Limit(g / totalWeight)
          ;*dstPix\b = Filter_Limit(b / totalWeight)
          ;*dstPix\a = Filter_Limit(a / totalWeight)
        EndIf
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeLanczosEx(*FilterCtx.FilterParams)
  Restore ResizeLanczos_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeLanczos_sp())
EndProcedure

; ===== Appel =====
Procedure ResizeLanczos(source, cible, lg, ht)
  Set_Source(source) : Set_Cible(cible)
  With FilterCtx
    \image_lg[1] = lg
    \image_ht[1] = ht
  EndWith
  ResizeLanczosEx(FilterCtx)
EndProcedure

DataSection
  ResizeLanczos_data:
  Data.s "ResizeLanczos3"
  Data.s "Lanczos-3 (Haute Fidélité - 36px)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "Largeur Cible" : Data.i 1, 8192, 800
  Data.s "Hauteur Cible" : Data.i 1, 8192, 600
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 104
; FirstLine = 53
; Folding = -
; EnableXP
; DPIAware