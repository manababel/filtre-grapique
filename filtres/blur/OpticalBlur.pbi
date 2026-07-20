; ---------------------------------------------------
; Optical Blur - Version optimisée
; Flou circulaire simulant un objectif (Bokeh rudimentaire)
; ---------------------------------------------------

Procedure OpticalBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    Protected radiusSq = radius * radius
    Protected lg_minus_1 = lg - 1, ht_minus_1 = ht - 1
    Protected x, y, ix, iy, rSum, gSum, bSum, count, pos, value
    Protected dx, dy, targetX, targetY
    Protected.l  r , g , b
    
    Protected *src.pixelarray = \addr[0]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        rSum = 0 : gSum = 0 : bSum = 0 : count = 0
        
        ; Parcours du disque circulaire
        For iy = -radius To radius
          targetY = y + iy
          If targetY < 0 Or targetY > ht_minus_1 : Continue : EndIf
          
          dy = iy
          For ix = -radius To radius
            targetX = x + ix
            If targetX < 0 Or targetX > lg_minus_1 : Continue : EndIf
            
            dx = ix
            ; Test de la forme circulaire (Distance Euclidienne)
            If dx * dx + dy * dy <= radiusSq
              getrgb(*src\l[targetY * lg + targetX] , r , g , b)
              rSum + r
              gSum + g
              bSum + b
              count + 1
            EndIf
          Next
        Next
        
        pos = (y * lg + x)
        If count > 0
          *dst\l[pos] = ((rSum / count) << 16) | ((gSum / count) << 8) | (bSum / count)
        Else
          *dst\l[pos] = *src\l[pos]
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure OpticalBlurEx(*FilterCtx.FilterParams)
  Restore OpticalBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected iterations = \option[1]
    If iterations < 1 : iterations = 1 : EndIf
    
    Protected total = \image_lg[0] * \image_ht[0] * 4
    Protected *tempo = AllocateMemory(total)
    If Not *tempo : ProcedureReturn 0 : EndIf
    
    ; On copie la source dans le tempo pour l'itération initiale
    CopyMemory(\addr[0], *tempo, total)
    
    Protected currentSource = *tempo
    Protected currentCible = \addr[1]
    Protected i
    For i = 1 To iterations
      \addr[0] = currentSource
      \addr[1] = currentCible
      
      Create_MultiThread_MT(@OpticalBlur_sp())
      
      ; Swap des buffers pour l'itération suivante
      If i < iterations
        Swap currentSource, currentCible
      EndIf
    Next
    
    FreeMemory(*tempo)
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure OpticalBlur(source, cible, mask, radius, iterations)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = iterations
  EndWith
  OpticalBlurEx(FilterCtx)
EndProcedure

DataSection
  OpticalBlur_data:
  Data.s "Optical Blur"
  Data.s "Flou circulaire simulant l'ouverture d'un objectif"
  Data.i #FilterType_Blur, #Blur_Optical
  Data.s "Rayon"
  Data.i 1, 20, 5
  Data.s "Itérations"
  Data.i 1, 10, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 81
; FirstLine = 30
; Folding = -
; EnableXP
; DPIAware