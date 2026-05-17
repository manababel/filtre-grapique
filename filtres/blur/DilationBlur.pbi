
Procedure DilationBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    If radius < 1 : radius = 1 : EndIf
    
    Protected x, y, dx, dy, px, py, index, value
    Protected r.l, g.l, b.l, a.l
    Protected a_temp, r_temp, g_temp, b_temp
    Protected maxA, maxR, maxG, maxB
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        maxA = 0 : maxR = 0 : maxG = 0 : maxB = 0
        
        For dy = -radius To radius
          py = y + dy
          If py < 0 Or py >= ht : Continue : EndIf
          For dx = -radius To radius
            px = x + dx
            If px < 0 Or px >= lg : Continue : EndIf
            index = (py * lg + px) << 2
            value = PeekL(\addr[0] + index)
            a_temp = (value >> 24) & $FF
            r_temp = (value >> 16) & $FF
            g_temp = (value >> 8) & $FF
            b_temp = value & $FF
            If a_temp > maxA : maxA = a_temp : EndIf
            If r_temp > maxR : maxR = r_temp : EndIf
            If g_temp > maxG : maxG = g_temp : EndIf
            If b_temp > maxB : maxB = b_temp : EndIf
          Next
        Next
        
        a = maxA : r = maxR : g = maxG : b = maxB
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure DilationBlurEx(*FilterCtx.FilterParams)
  Restore DilationBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@DilationBlur_MT())
  
  mask_update(*FilterCtx.FilterParams , last_data)
  
EndProcedure

Procedure DilationBlur(source , cible , mask , rayon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
  EndWith
  DilationBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  DilationBlur_data:
  Data.s "DilationBlur"
  Data.s "Dilatation morphologique (éclaircit l'image)"
  Data.i #FilterType_Blur
  Data.i #Blur_Morphological
  
  Data.s "Rayon"       
  Data.i 1,20,3
  Data.s "XXX"  
EndDataSection

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 45
; FirstLine = 25
; Folding = -
; EnableXP
; DPIAware