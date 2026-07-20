; ---------------------------------------------------
; Flou intelligent préservant les contours
; ---------------------------------------------------

Procedure SmartBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray = \addr[0]
    Protected *dst.PixelArray = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]
    Protected threshold = \option[1]
    
    If radius < 1 : radius = 1 : EndIf
    If threshold < 0 : threshold = 0 : EndIf
    
    ; Optimisation du seuil pour éviter la division par 3 dans la boucle locale
    Protected thresholdX3 = threshold * 3
    
    Protected x, y, dx, dy, px, py
    Protected.l r, g, b, a
    Protected.l centerR, centerG, centerB, centerA
    Protected.l sumR, sumG, sumB, sumA, count
    Protected.l diffR, diffG, diffB
    
    Protected min_py, max_py, min_px, max_px
    Protected y_offset, py_offset
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      y_offset = y * lg  ; Pré-calcul de la ligne courante
      
      ; Gestion dynamique des bornes Y pour éviter le "If py < 0..."
      min_py = y - radius : If min_py < 0  : min_py = 0  : EndIf
      max_py = y + radius : If max_py >= ht : max_py = ht - 1 : EndIf
      
      For x = 0 To lg - 1
        ; Pixel central via indexation directe pré-calculée
        GetARGB(*src\l[y_offset + x] , centerA , centerR , centerG , centerB)
        
        sumR = 0 : sumG = 0 : sumB = 0 : sumA = 0 : count = 0
        
        ; Gestion dynamique des bornes X pour éviter le "If px < 0..."
        min_px = x - radius : If min_px < 0  : min_px = 0  : EndIf
        max_px = x + radius : If max_px >= lg : max_px = lg - 1 : EndIf
        
        ; Parcourir le voisinage nettoyé des vérifications de limites
        For py = min_py To max_py
          py_offset = py * lg  ; Pré-calcul de la ligne du voisinage
          
          For px = min_px To max_px
            GetARGB(*src\l[py_offset + px] , a , r , g , b)

            ; Calcul de la différence absolue
            diffR = r - centerR : If diffR < 0 : diffR = -diffR : EndIf
            diffG = g - centerG : If diffG < 0 : diffG = -diffG : EndIf
            diffB = b - centerB : If diffB < 0 : diffB = -diffB : EndIf
            
            ; Comparaison directe (évite la division par 3 à chaque pixel)
            If (diffR + diffG + diffB) <= thresholdX3
              sumA + a
              sumR + r
              sumG + g
              sumB + b
              count + 1
            EndIf
          Next
        Next
        
        ; Calculer la moyenne ou garder l'original
        If count > 0
          a = sumA / count
          r = sumR / count
          g = sumG / count
          b = sumB / count
        Else
          a = centerA
          r = centerR
          g = centerG
          b = centerB
        EndIf

        ; Écriture directe sur la destination
        *dst\l[y_offset + x] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure SmartBlurEx(*FilterCtx.FilterParams)
  Restore SmartBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@SmartBlur_sp())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure SmartBlur(source, cible, mask, radius, threshold)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = threshold
  EndWith
  SmartBlurEx(FilterCtx)
EndProcedure

DataSection
  SmartBlur_data:
  Data.s "SmartBlur"
  Data.s "Flou intelligent préservant les contours"
  Data.i #FilterType_Blur, #Blur_EdgeAware
  Data.s "Rayon"
  Data.i 1, 20, 3    ; Rayon
  Data.s "Seuil"
  Data.i 0, 100, 30  ; Seuil
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 93
; FirstLine = 66
; Folding = -
; EnableXP
; DPIAware