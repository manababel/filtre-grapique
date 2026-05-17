Macro ErosionBlur_sp1()
  value = PeekL(*FilterCtx\addr[0] + index)
  
  ; Extraction rapide ARGB
  a_temp = (value >> 24) & $FF
  r_temp = (value >> 16) & $FF
  g_temp = (value >> 8) & $FF
  b_temp = value & $FF
  
  ; Mettre à jour le minimum pour chaque canal
  If a_temp < minA : minA = a_temp : EndIf
  If r_temp < minR : minR = r_temp : EndIf
  If g_temp < minG : minG = g_temp : EndIf
  If b_temp < minB : minB = b_temp : EndIf
EndMacro

Procedure ErosionBlur_MT(*FilterCtx.FilterParams)
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
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        ; Initialiser le minimum à la valeur maximale possible
        minA = 255 : minR = 255 : minG = 255 : minB = 255
        
        ; Parcourir le voisinage
        For dy = -radius To radius
          py = y + dy
          If py < 0 Or py >= ht : Continue : EndIf
          
          For dx = -radius To radius
            px = x + dx
            If px < 0 Or px >= lg : Continue : EndIf
            
            index = (py * lg + px) << 2
            ErosionBlur_sp1()
          Next
        Next
        
        ; Appliquer la valeur minimale comme résultat (érosion)
        a = minA
        r = minR
        g = minG
        b = minB
        
        PokeL(\addr[1] + (y * lg + x) << 2, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure ErosionBlurEx(*FilterCtx.FilterParams)
  Restore ErosionBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Clamp d'origine
    If \option[0] < 1 : \option[0] = 1 : ElseIf \option[0] > 20 : \option[0] = 20 : EndIf
    
    Create_MultiThread_MT(@ErosionBlur_MT())
    
    mask_update(*FilterCtx.FilterParams , last_data)
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
; CursorPosition = 78
; FirstLine = 47
; Folding = -
; EnableXP
; DPIAware