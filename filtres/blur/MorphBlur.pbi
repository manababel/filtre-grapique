Macro MorphBlur_sp1()
  value = PeekL(*FilterCtx\addr[0] + index)
  
  ; Extraction rapide ARGB
  a_temp = (value >> 24) & $FF
  r_temp = (value >> 16) & $FF
  g_temp = (value >> 8) & $FF
  b_temp = value & $FF
  
  ; Mettre à jour min/max pour chaque canal
  If a_temp < minA : minA = a_temp : EndIf
  If a_temp > maxA : maxA = a_temp : EndIf
  If r_temp < minR : minR = r_temp : EndIf
  If r_temp > maxR : maxR = r_temp : EndIf
  If g_temp < minG : minG = g_temp : EndIf
  If g_temp > maxG : maxG = g_temp : EndIf
  If b_temp < minB : minB = b_temp : EndIf
  If b_temp > maxB : maxB = b_temp : EndIf
EndMacro

Procedure MorphBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected kernelSize = \option[0]
    
    If kernelSize < 1 : kernelSize = 1 : EndIf
    
    Protected radius = kernelSize
    Protected x, y, dx, dy, px, py, index
    Protected value, r.l, g.l, b.l, a.l
    Protected a_temp, r_temp, g_temp, b_temp
    
    Protected minA, minR, minG, minB
    Protected maxA, maxR, maxG, maxB
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        ; Initialiser min et max à des valeurs extrêmes
        minA = 255 : maxA = 0
        minR = 255 : maxR = 0
        minG = 255 : maxG = 0
        minB = 255 : maxB = 0
        
        ; Parcourir le voisinage
        For dy = -radius To radius
          py = y + dy
          If py < 0 Or py >= ht : Continue : EndIf
          
          For dx = -radius To radius
            px = x + dx
            If px < 0 Or px >= lg : Continue : EndIf
            
            index = (py * lg + px) << 2
            MorphBlur_sp1()
          Next
        Next
        
        ; Calculer la moyenne des extrema (morphological blur)
        ; Cette opération préserve la luminosité moyenne
        a = (minA + maxA) >> 1
        r = (minR + maxR) >> 1
        g = (minG + maxG) >> 1
        b = (minB + maxB) >> 1
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure MorphBlurEx(*FilterCtx.FilterParams)
  Restore MorphBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Clamp d'origine conservé via l'initialisation ou manuel
    If \option[0] < 1 : \option[0] = 1 : ElseIf \option[0] > 20 : \option[0] = 20 : EndIf
    
    Create_MultiThread_MT(@MorphBlur_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
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
; CursorPosition = 88
; FirstLine = 57
; Folding = -
; EnableXP
; DPIAware