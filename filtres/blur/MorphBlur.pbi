
; ============================================================================
; PASSE 1 : Min/Max Horizontal (*src -> *tmp)
; ============================================================================
Procedure MorphBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]
    
    Protected x, y, dx, px
    Protected a_temp, r_temp, g_temp, b_temp
    Protected minA, minR, minG, minB
    Protected maxA, maxR, maxG, maxB
    
    ; Structure personnalisée ou cast selon ton framework pour stocker 8 octets par pixel (min/max RGB)
    ; Ici on utilise deux tampons 32 bits : un pour le MIN, un pour le MAX
    Protected *src.pixelarray = \addr[0]
    Protected *tmpMin.pixelarray = \addr[2] ; Tampon temporaire Min
    Protected *tmpMax.pixelarray = \addr[3] ; Tampon temporaire Max
    
    Protected y_offset.i
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      y_offset = y * lg
      For x = 0 To lg - 1
        minA = 255 : maxA = 0
        minR = 255 : maxR = 0
        minG = 255 : maxG = 0
        minB = 255 : maxB = 0
        
        For dx = -radius To radius
          px = x + dx
          If px < 0 Or px >= lg : Continue : EndIf
          
          getargb(*src\l[y_offset + px], a_temp, r_temp, g_temp, b_temp)
          
          If a_temp < minA : minA = a_temp : EndIf
          If a_temp > maxA : maxA = a_temp : EndIf
          If r_temp < minR : minR = r_temp : EndIf
          If r_temp > maxR : maxR = r_temp : EndIf
          If g_temp < minG : minG = g_temp : EndIf
          If g_temp > maxG : maxG = g_temp : EndIf
          If b_temp < minB : minB = b_temp : EndIf
          If b_temp > maxB : maxB = b_temp : EndIf
        Next
        
        ; On stocke les minima et maxima séparément pour la passe suivante
        *tmpMin\l[y_offset + x] = (minA << 24) | (minR << 16) | (minG << 8) | minB
        *tmpMax\l[y_offset + x] = (maxA << 24) | (maxR << 16) | (maxG << 8) | maxB
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PASSE 2 : Min/Max Vertical (*tmp -> *dst)
; ============================================================================
Procedure MorphBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]
    
    Protected x, y, dy, py
    Protected a_temp, r_temp, g_temp, b_temp
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
          
          ; Extraire le Min accumulé horizontalement
          getargb(*tmpMin\l[py_offset], a_temp, r_temp, g_temp, b_temp)
          If a_temp < minA : minA = a_temp : EndIf
          If r_temp < minR : minR = r_temp : EndIf
          If g_temp < minG : minG = g_temp : EndIf
          If b_temp < minB : minB = b_temp : EndIf
          
          ; Extraire le Max accumulé horizontalement
          getargb(*tmpMax\l[py_offset], a_temp, r_temp, g_temp, b_temp)
          If a_temp > maxA : maxA = a_temp : EndIf
          If r_temp > maxR : maxR = r_temp : EndIf
          If g_temp > maxG : maxG = g_temp : EndIf
          If b_temp > maxB : maxB = b_temp : EndIf
        Next
        
        ; Moyenne des extrêmes
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
; FONCTION PRINCIPALE (GESTION DES PASSES)
; ============================================================================
Procedure MorphBlurEx(*FilterCtx.FilterParams)
  Restore MorphBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    If \option[0] < 1 : \option[0] = 1 : ElseIf \option[0] > 20 : \option[0] = 20 : EndIf
    
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation de 2 tampons temporaires (Min et Max)
    \addr[2] = AllocateMemory(imgSize)
    \addr[3] = AllocateMemory(imgSize)
    
    If \addr[2] And \addr[3]
      ; Passe 1 : Horizontale
      Create_MultiThread_MT(@MorphBlur_H_MT())
      
      ; Passe 2 : Verticale
      Create_MultiThread_MT(@MorphBlur_V_MT())
      
      ; Libération de la mémoire
      FreeMemory(\addr[2])
      FreeMemory(\addr[3])
    EndIf
    
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure MorphBlur(source, cible, mask, rayon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
  EndWith
  MorphBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  MorphBlur_data:
  Data.s "MorphBlur"
  Data.s "Flou morphologique basé sur la moyenne des extrema locaux"
  Data.i #FilterType_Blur
  Data.i #Blur_Morphological
  
  Data.s "Rayon"
  Data.i 1, 20, 3
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 149
; FirstLine = 94
; Folding = -
; EnableXP
; DPIAware