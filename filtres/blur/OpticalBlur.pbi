Procedure OpticalBlur_MT(*param.parametre)
  Protected *source.Pixel32
  Protected *cible.Pixel32 
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]
  Protected x, y, ix, iy
  Protected rSum, gSum, bSum
  Protected count
  Protected pos, r, g, b, r1, g1, b1
  Protected dx, dy
  Protected lg_minus_1 = lg - 1
  Protected ht_minus_1 = ht - 1
  Protected radiusSq = radius * radius
  
  ; Thread split
  Protected thread_startY = (*param\thread_pos * ht) / *param\thread_max
  Protected thread_stopY  = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  If thread_stopY >= ht : thread_stopY = ht_minus_1 : EndIf
  
  For y = thread_startY To thread_stopY
    For x = 0 To lg - 1
      rSum = 0 : gSum = 0 : bSum = 0 : count = 0
      pos = (y * lg + x) << 2
      
      ; Parcours du disque circulaire
      For iy = -radius To radius
        dy = iy
        
        ; Vérification Y
        If (y + iy) < 0 Or (y + iy) > ht_minus_1
          Continue
        EndIf
        
        For ix = -radius To radius
          dx = ix
          
          ; Test du disque circulaire
          If dx * dx + dy * dy > radiusSq
            Continue
          EndIf
          
          ; Vérification X
          If (x + ix) < 0 Or (x + ix) > lg_minus_1
            Continue
          EndIf
          
          ; Lecture du pixel
          *source = *param\addr[0] + ((y + iy) * lg + (x + ix)) * 4
          getrgb(*source\l, r1, g1, b1)
          rSum + r1
          gSum + g1
          bSum + b1
          count + 1
        Next
      Next
      
      ; Calcul de la moyenne
      If count > 0
        r = rSum / count
        g = gSum / count
        b = bSum / count
      Else
        ; Copie du pixel source si aucun échantillon
        *source = *param\addr[0] + pos
        getrgb(*source\l, r, g, b)
      EndIf
      
      ; Écriture du résultat
      *cible = *param\addr[1] + pos
      *cible\l = (r << 16) | (g << 8) | b
    Next
  Next
EndProcedure


Procedure OpticalBlur(*param.parametre)
  If *param\info_active
    *param\name = "Optical Blur"
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Optical
    *param\remarque = "Flou optique circulaire simulant un objectif"
    *param\info[0] = "Radius"
    *param\info[1] = "Nombre de passes"
    *param\info[2] = "Masque binaire"
    *param\info_data(0, 0) = 1  : *param\info_data(0, 1) = 50  : *param\info_data(0, 2) = 5
    *param\info_data(1, 0) = 1  : *param\info_data(1, 1) = 10  : *param\info_data(1, 2) = 1
    *param\info_data(2, 0) = 0  : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0
    ProcedureReturn
  EndIf
  
  ; Validation du nombre de passes
  If *param\option[1] < 1 : *param\option[1] = 1 : EndIf
  If *param\option[1] > 10 : *param\option[1] = 10 : EndIf
  
  Protected total = *param\lg * *param\ht * 4
  Protected *tempo = AllocateMemory(total)
  
  If Not *tempo
    ProcedureReturn
  EndIf
  
  ; Initialisation
  CopyMemory(*param\source, *tempo, total)
  *param\addr[0] = *tempo
  *param\addr[1] = *param\cible
  
  ; Boucle d'itérations
  Protected i
  For i = 1 To *param\option[1]
    MultiThread_MT(@OpticalBlur_MT())
    
    ; Swap pour la prochaine itération
    If i < *param\option[1]
      Swap *param\addr[0], *param\addr[1]
    EndIf
  Next
  
  ; Application du masque si nécessaire
  If *param\mask And *param\option[2]
    *param\mask_type = *param\option[2] - 1
    MultiThread_MT(@_mask())
  EndIf
  
  ; Libération de la mémoire
  If *tempo
    FreeMemory(*tempo)
  EndIf
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 132
; FirstLine = 63
; Folding = -
; EnableXP
; DPIAware