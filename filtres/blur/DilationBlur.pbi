; ============================================================================
; PASSE 1 : Dilatation Horizontale (*src -> *tmp)
; ============================================================================
Procedure DilationBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    
    Protected x, y, dx, px, value
    Protected a_temp, r_temp, g_temp, b_temp
    Protected maxA, maxR, maxG, maxB
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    Protected y_offset.i
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      y_offset = y * lg
      For x = 0 To lg - 1
        maxA = 0 : maxR = 0 : maxG = 0 : maxB = 0
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          
          value = *src\l[y_offset + px]
          
          a_temp = (value >> 24) & $FF
          r_temp = (value >> 16) & $FF
          g_temp = (value >> 8) & $FF
          b_temp = value & $FF
          
          If a_temp > maxA : maxA = a_temp : EndIf
          If r_temp > maxR : maxR = r_temp : EndIf
          If g_temp > maxG : maxG = g_temp : EndIf
          If b_temp > maxB : maxB = b_temp : EndIf
        Next
        
        *tmp\l[y_offset + x] = (maxA << 24) | (maxR << 16) | (maxG << 8) | maxB
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PASSE 2 : Dilatation Verticale (*tmp -> *dst)
; ============================================================================
Procedure DilationBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    
    Protected x, y, dy, py, value
    Protected a_temp, r_temp, g_temp, b_temp
    Protected maxA, maxR, maxG, maxB
    
    Protected *tmp.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        maxA = 0 : maxR = 0 : maxG = 0 : maxB = 0
        
        For dy = -radius To radius
          py = y + dy
          If py < 0 Or py >= ht : Continue : EndIf
          
          value = *tmp\l[py * lg + x]
          
          a_temp = (value >> 24) & $FF
          r_temp = (value >> 16) & $FF
          g_temp = (value >> 8) & $FF
          b_temp = value & $FF
          
          If a_temp > maxA : maxA = a_temp : EndIf
          If r_temp > maxR : maxR = r_temp : EndIf
          If g_temp > maxG : maxG = g_temp : EndIf
          If b_temp > maxB : maxB = b_temp : EndIf
        Next
        
        *dst\l[y * lg + x] = (maxA << 24) | (maxR << 16) | (maxG << 8) | maxB
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; EXÉCUTION DU FILTRE
; ============================================================================
Procedure DilationBlurEx(*FilterCtx.FilterParams)
  Restore DilationBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Ajout du clamp de sécurité sur l'option
    If \option[0] < 1 : \option[0] = 1 : ElseIf \option[0] > 20 : \option[0] = 20 : EndIf
    
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation du tampon temporaire
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@DilationBlur_H_MT())
      Create_MultiThread_MT(@DilationBlur_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
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
; CursorPosition = 116
; FirstLine = 61
; Folding = -
; EnableXP
; DPIAware