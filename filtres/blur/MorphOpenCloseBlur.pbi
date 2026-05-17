Macro ErodeDilate_sp1()
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

Procedure MorphOpenCloseBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected kernelSize = \option[0]
    
    If kernelSize < 1 : kernelSize = 1 : EndIf
    
    Protected radius = kernelSize
    Protected x, y, dx, dy, px, py, index
    Protected value, r.l, g.l, b.l, a.l
    Protected a_temp, r_temp, g_temp, b_temp
    
    Protected minA, maxA, minR, maxR, minG, maxG, minB, maxB
    Protected openA, openR, openG, openB
    Protected closeA, closeR, closeG, closeB
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        
        ; ==== Phase 1 : Érosion (pour Opening) ====
        minA = 255 : minR = 255 : minG = 255 : minB = 255
        maxA = 0   : maxR = 0   : maxG = 0   : maxB = 0
        
        For dy = -radius To radius
          py = y + dy
          If py < 0 Or py >= ht : Continue : EndIf
          
          For dx = -radius To radius
            px = x + dx
            If px < 0 Or px >= lg : Continue : EndIf
            
            index = (py * lg + px) << 2
            ErodeDilate_sp1()
          Next
        Next
        
        ; Résultat de l'érosion = minimum
        openA = minA
        openR = minR
        openG = minG
        openB = minB
        
        ; ==== Phase 2 : Dilatation (pour Closing) ====
        ; Note: Réutilisation des calculs min/max sur le même voisinage 
        ; comme dans le code d'origine.
        minA = 255 : minR = 255 : minG = 255 : minB = 255
        maxA = 0   : maxR = 0   : maxG = 0   : maxB = 0
        
        For dy = -radius To radius
          py = y + dy
          If py < 0 Or py >= ht : Continue : EndIf
          
          For dx = -radius To radius
            px = x + dx
            If px < 0 Or px >= lg : Continue : EndIf
            
            index = (py * lg + px) << 2
            ErodeDilate_sp1()
          Next
        Next
        
        ; Résultat de la dilatation = maximum
        closeA = maxA
        closeR = maxR
        closeG = maxG
        closeB = maxB
        
        ; ==== Résultat final : moyenne Opening + Closing ====
        a = (openA + closeA) >> 1
        r = (openR + closeR) >> 1
        g = (openG + closeG) >> 1
        b = (openB + closeB) >> 1
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure MorphOpenCloseBlurEx(*FilterCtx.FilterParams)
  Restore MorphOpenCloseBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Application du Clamp d'origine
    If \option[0] < 1 : \option[0] = 1 : ElseIf \option[0] > 20 : \option[0] = 20 : EndIf
    
    Create_MultiThread_MT(@MorphOpenCloseBlur_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure MorphOpenCloseBlur(source, cible, mask, rayon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
  EndWith
  MorphOpenCloseBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  MorphOpenCloseBlur_data:
  Data.s "MorphOpenCloseBlur"
  Data.s "Flou morphologique par moyenne Opening + Closing"
  Data.i #FilterType_Blur
  Data.i #Blur_Morphological
  
  Data.s "Rayon"
  Data.i 1, 20, 3
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 117
; FirstLine = 86
; Folding = -
; EnableXP
; DPIAware