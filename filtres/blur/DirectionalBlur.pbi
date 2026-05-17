Procedure DirectionalBoxBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *output = \addr[1]
    Protected width  = \image_lg[0]
    Protected height = \image_ht[0]
    Protected angle.f  = \option[0] * #PI / 180.0
    Protected radius   = \option[1]
    
    ; Précalcul des valeurs constantes
    Protected dx.f = Cos(angle)
    Protected dy.f = Sin(angle)
    Protected invCount.f
    
    Protected x, y, i
    Protected sx.f, sy.f
    Protected rSum, gSum, bSum  ; Entiers pour l'accumulation
    Protected r, g, b, count
    Protected col, r1, g1, b1, offset
    
    Protected start = (\thread_pos * height) / \thread_max
    Protected stop  = ((\thread_pos + 1) * height) / \thread_max
    
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
  EndWith
EndProcedure

Procedure DirectionalBoxBlurEx(*FilterCtx.FilterParams)
  Restore DirectionalBoxBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    
    Protected total = \image_lg[0] * \image_ht[0] << 2  ; Bit shift au lieu de * 4
     \addr[2] = AllocateMemory(total)
    
    If Not \addr[2] : ProcedureReturn : EndIf
    
    CopyMemory(\image[0], \addr[2], total)
    \addr[0] = \addr[2]
    \addr[1] = \image[1]
    
    Protected i, passes = \option[2]
    
    For i = 1 To passes
      Create_MultiThread_MT(@DirectionalBoxBlur_MT())
      ; Éviter la copie inutile à la dernière passe
      If i < passes
        CopyMemory(\addr[1], \addr[0], total)
      EndIf
    Next
    
    mask_update(*FilterCtx.FilterParams , last_data)
    
    FreeMemory(\addr[2])
  EndWith
EndProcedure

Procedure DirectionalBoxBlur(source , cible , mask , angle , radius , ndp)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = angle
    \option[1] = radius
    \option[2] = ndp
  EndWith
  DirectionalBoxBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  DirectionalBoxBlur_data:
  Data.s "DirectionalBoxBlur"
  Data.s ""
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Angle (°)"       
  Data.i 1,360,0
  Data.s "Radius"   
  Data.i 1,32,8
  Data.s "Nombre de passes"        
  Data.i 1,3,1
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 73
; FirstLine = 48
; Folding = -
; EnableXP
; DPIAware