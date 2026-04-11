Procedure DirectionalBoxBlur_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *output = *param\addr[1]
  Protected width  = *param\lg
  Protected height = *param\ht
  Protected angle.f  = *param\option[0] * #PI / 180.0
  Protected radius   = *param\option[1]
  
  ; Précalcul des valeurs constantes
  Protected dx.f = Cos(angle)
  Protected dy.f = Sin(angle)
  Protected invCount.f
  
  Protected x, y, i
  Protected sx.f, sy.f
  Protected rSum, gSum, bSum  ; Entiers pour l'accumulation
  Protected r, g, b, count
  Protected col, r1, g1, b1, offset
  
  Protected start = (*param\thread_pos * height) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * height) / *param\thread_max
  
  For y = start To stop - 1
    For x = 0 To width - 1
      rSum = 0 : gSum = 0 : bSum = 0 : count = 0
      
      For i = -radius To radius
        sx = x + i * dx
        sy = y + i * dy
        
        ; Vérification des limites en une seule condition
        If sx >= 0 And sx < width And sy >= 0 And sy < height
          ; Calcul d'offset optimisé
          offset = (Int(sy) * width + Int(sx)) << 2  ; Bit shift au lieu de * 4
          col = PeekL(*source + offset)
          getrgb(col, r1, g1, b1)
          rSum + r1 : gSum + g1 : bSum + b1
          count + 1
        EndIf
      Next
      
      ; Division optimisée
      If count > 0
        invCount = 1.0 / count
        r = rSum * invCount
        g = gSum * invCount
        b = bSum * invCount
      Else
        r = 0 : g = 0 : b = 0
      EndIf
      
      ; Écriture directe du pixel
      PokeL(*output + ((y * width + x) << 2), (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure DirectionalBoxBlur(*param.parametre)
  If *param\info_active
    *param\name = "DirectionalBoxBlur"
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Directional
    *param\remarque = "Flou directionnel approximatif, multi-thread"
    *param\info[0] = "Angle (°)"
    *param\info[1] = "Radius"
    *param\info[2] = "Nombre de passes"
    *param\info[3] = "Mask"
    *param\info_data(0,0) = 0   : *param\info_data(0,1) = 360 : *param\info_data(0,2) = 0
    *param\info_data(1,0) = 1   : *param\info_data(1,1) = 32  : *param\info_data(1,2) = 8
    *param\info_data(2,0) = 1   : *param\info_data(2,1) = 3   : *param\info_data(2,2) = 1
    *param\info_data(3,0) = 0   : *param\info_data(3,1) = 2   : *param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  clamp(*param\option[2], 1, 3)
  
  Protected total = *param\lg * *param\ht << 2  ; Bit shift au lieu de * 4
  Protected *tempo = AllocateMemory(total)
  
  If Not *tempo : ProcedureReturn : EndIf
  
  CopyMemory(*param\source, *tempo, total)
  *param\addr[0] = *tempo
  *param\addr[1] = *param\cible
  
  Protected i, passes = *param\option[2]
  
  For i = 1 To passes
    MultiThread_MT(@DirectionalBoxBlur_MT())
    ; Éviter la copie inutile à la dernière passe
    If i < passes
      CopyMemory(*param\addr[1], *param\addr[0], total)
    EndIf
  Next
  
  If *param\mask And *param\option[3]
    *param\mask_type = *param\option[3] - 1
    MultiThread_MT(@_mask())
  EndIf
  
  FreeMemory(*tempo)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 103
; FirstLine = 34
; Folding = -
; EnableXP
; DPIAware