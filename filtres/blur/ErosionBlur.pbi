; ============================================================================
; PASSE 1 : Érosion Horizontale (*src -> *tmp)
; ============================================================================
Procedure ErosionBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]
    
    Protected x, y, dx, px, value
    Protected a_temp, r_temp, g_temp, b_temp
    Protected minA, minR, minG, minB
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    Protected y_offset.i
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      y_offset = y * lg
      For x = 0 To lg - 1
        minA = 255 : minR = 255 : minG = 255 : minB = 255
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          
          value = *src\l[y_offset + px]
          
          a_temp = (value >> 24) & $FF
          r_temp = (value >> 16) & $FF
          g_temp = (value >> 8) & $FF
          b_temp = value & $FF
          
          If a_temp < minA : minA = a_temp : EndIf
          If r_temp < minR : minR = r_temp : EndIf
          If g_temp < minG : minG = g_temp : EndIf
          If b_temp < minB : minB = b_temp : EndIf
        Next
        
        *tmp\l[y_offset + x] = (minA << 24) | (minR << 16) | (minG << 8) | minB
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PASSE 2 : Érosion Verticale (*tmp -> *dst)
; ============================================================================
Procedure ErosionBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]
    
    Protected x, y, dy, py, value
    Protected a_temp, r_temp, g_temp, b_temp
    Protected minA, minR, minG, minB
    
    Protected *tmp.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        minA = 255 : minR = 255 : minG = 255 : minB = 255
        
        For dy = -radius To radius
          py = y + dy
          If py < 0 Or py >= ht : Continue : EndIf
          
          value = *tmp\l[py * lg + x]
          
          a_temp = (value >> 24) & $FF
          r_temp = (value >> 16) & $FF
          g_temp = (value >> 8) & $FF
          b_temp = value & $FF
          
          If a_temp < minA : minA = a_temp : EndIf
          If r_temp < minR : minR = r_temp : EndIf
          If g_temp < minG : minG = g_temp : EndIf
          If b_temp < minB : minB = b_temp : EndIf
        Next
        
        *dst\l[y * lg + x] = (minA << 24) | (minR << 16) | (minG << 8) | minB
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; EXÉCUTION DU FILTRE
; ============================================================================
Procedure ErosionBlurEx(*FilterCtx.FilterParams)
  Restore ErosionBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    If \option[0] < 1 : \option[0] = 1 : ElseIf \option[0] > 20 : \option[0] = 20 : EndIf
    
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Un seul tampon temporaire est nécessaire pour l'érosion
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@ErosionBlur_H_MT())
      Create_MultiThread_MT(@ErosionBlur_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure ErosionBlur(source, cible, mask, rayon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
  EndWith
  ErosionBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  ErosionBlur_data:
  Data.s "ErosionBlur"
  Data.s "Flou basé sur l'érosion morphologique (assombrit l'image)"
  Data.i #FilterType_Blur
  Data.i #Blur_Morphological
  
  Data.s "Rayon"
  Data.i 1, 20, 3
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 117
; FirstLine = 62
; Folding = -
; EnableXP
; DPIAware