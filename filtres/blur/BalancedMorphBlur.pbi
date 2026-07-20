; ============================================================================
; PASSE 1 : Horizontale (*src -> *tmpMin et *tmpMax)
; ============================================================================
Procedure BalancedMorphBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    
    Protected x, y, dx, px, value
    Protected a_temp, r_temp, g_temp, b_temp
    Protected minA, minR, minG, minB
    Protected maxA, maxR, maxG, maxB
    
    Protected *src.pixelarray    = \addr[0]
    Protected *tmpMin.pixelarray = \addr[2]
    Protected *tmpMax.pixelarray = \addr[3]
    Protected y_offset.i
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      y_offset = y * lg
      For x = 0 To lg - 1
        minA = 255 : minR = 255 : minG = 255 : minB = 255
        maxA = 0   : maxR = 0   : maxG = 0   : maxB = 0
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          
          value = *src\l[y_offset + px]
          
          a_temp = (value >> 24) & $FF
          r_temp = (value >> 16) & $FF
          g_temp = (value >> 8) & $FF
          b_temp = value & $FF
          
          If a_temp < minA : minA = a_temp : EndIf
          If a_temp > maxA : maxA = a_temp : EndIf
          If r_temp < minR : minR = r_temp : EndIf
          If r_temp > maxR : maxR = r_temp : EndIf
          If g_temp < minG : minG = g_temp : EndIf
          If g_temp > maxG : maxG = g_temp : EndIf
          If b_temp < minB : minB = b_temp : EndIf
          If b_temp > maxB : maxB = b_temp : EndIf
        Next
        
        *tmpMin\l[y_offset + x] = (minA << 24) | (minR << 16) | (minG << 8) | minB
        *tmpMax\l[y_offset + x] = (maxA << 24) | (maxR << 16) | (maxG << 8) | maxB
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PASSE 2 : Verticale (*tmpMin et *tmpMax -> *dst)
; ============================================================================
Procedure BalancedMorphBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    
    Protected x, y, dy, py, valMin, valMax
    Protected minA, minR, minG, minB
    Protected maxA, maxR, maxG, maxB
    Protected r, g, b, a
    
    Protected *tmpMin.pixelarray = \addr[2]
    Protected *tmpMax.pixelarray = \addr[3]
    Protected *dst.pixelarray    = \addr[1]
    Protected py_offset.i
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        minA = 255 : minR = 255 : minG = 255 : minB = 255
        maxA = 0   : maxR = 0   : maxG = 0   : maxB = 0
        
        For dy = -radius To radius
          py = y + dy
          If py < 0 Or py >= ht : Continue : EndIf
          
          py_offset = py * lg + x
          valMin = *tmpMin\l[py_offset]
          valMax = *tmpMax\l[py_offset]
          
          ; Traitement Min
          If ((valMin >> 24) & $FF) < minA : minA = (valMin >> 24) & $FF : EndIf
          If ((valMin >> 16) & $FF) < minR : minR = (valMin >> 16) & $FF : EndIf
          If ((valMin >> 8) & $FF)  < minG : minG = ((valMin >> 8) & $FF) : EndIf
          If (valMin & $FF)         < minB : minB = (valMin & $FF)        : EndIf
          
          ; Traitement Max
          If ((valMax >> 24) & $FF) > maxA : maxA = (valMax >> 24) & $FF : EndIf
          If ((valMax >> 16) & $FF) > maxR : maxR = (valMax >> 16) & $FF : EndIf
          If ((valMax >> 8) & $FF)  > maxG : maxG = ((valMax >> 8) & $FF) : EndIf
          If (valMax & $FF)         > maxB : maxB = (valMax & $FF)        : EndIf
        Next
        
        a = (minA + maxA) >> 1
        r = (minR + maxR) >> 1
        g = (minG + maxG) >> 1
        b = (minB + maxB) >> 1
        
        *dst\l[y * lg + x] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; EXÉCUTION DU FILTRE
; ============================================================================
Procedure BalancedMorphBlurEx(*FilterCtx.FilterParams)
  Restore BalancedMorphBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    If \option[0] < 1 : \option[0] = 1 : ElseIf \option[0] > 20 : \option[0] = 20 : EndIf
    
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation des deux tampons (Min et Max)
    \addr[2] = AllocateMemory(imgSize)
    \addr[3] = AllocateMemory(imgSize)
    
    If \addr[2] And \addr[3]
      Create_MultiThread_MT(@BalancedMorphBlur_H_MT())
      Create_MultiThread_MT(@BalancedMorphBlur_V_MT())
      
      FreeMemory(\addr[2])
      FreeMemory(\addr[3])
    EndIf
    
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure BalancedMorphBlur(source, cible, mask, rayon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
  EndWith
  BalancedMorphBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  BalancedMorphBlur_data:
  Data.s "BalancedMorphBlur"
  Data.s "Flou morphologique équilibré (moyenne érosion+dilatation)"
  Data.i #FilterType_Blur
  Data.i #Blur_Morphological
  
  Data.s "Rayon"
  Data.i 1, 20, 3
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 138
; FirstLine = 83
; Folding = -
; EnableXP
; DPIAware