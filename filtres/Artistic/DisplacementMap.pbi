Procedure DisplacementMap_MT(*p.parametre)
  Protected *src = *p\source
  Protected *dst = *p\cible
  Protected *disp = *p\mix
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected intensity.f = *p\option[0] * 0.5
  Protected offsetX.f = ((*p\option[1] - 100) * lg) / 100
  Protected offsetY.f = ((*p\option[2] - 100) * ht) / 100
  Protected wrapMode = *p\option[3]  ; 0 = clamp, 1 = wrap (modulo)

  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf

  Protected x, y
  Protected srcX.f, srcY.f
  Protected dispXPos.f, dispYPos.f
  Protected offsetDst, offsetDisp

  For y = startY To stopY
    For x = 0 To lg - 1
      dispXPos = x + offsetX
      dispYPos = y + offsetY
      
      If wrapMode = 0
        Clamp(dispXPos, 0, lg - 1)
        Clamp(dispYPos, 0, ht - 1)
      Else
        ; Wrap autour avec modulo
        dispXPos =  Mod(dispXPos , lg)
        If dispXPos < 0 : dispXPos + lg : EndIf
        dispYPos =  Mod(dispYPos , ht)
        If dispYPos < 0 : dispYPos + ht : EndIf
      EndIf

      offsetDisp = (Int(dispYPos) * lg + Int(dispXPos)) * 4
      Protected dispColor = PeekL(*disp + offsetDisp)

      ; Utiliser rouge et vert comme vecteurs de déplacement
      Protected dispX = ((dispColor >> 16) & $FF) - 128 ; rouge
      Protected dispY = ((dispColor >> 8) & $FF) - 128 ; vert

      srcX = x + (dispX / 128.0) * intensity
      srcY = y + (dispY / 128.0) * intensity

      Clamp(srcX, 0, (lg - 1))
      Clamp(srcY, 0, (ht - 1))

      offsetDst = (y * lg + x) * 4
      PokeL(*dst + offsetDst, BilinearSample(*src, lg, ht, srcX, srcY))
    Next
  Next
EndProcedure

Procedure DisplacementMap(*param.parametre)
  If param\info_active
    param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Other
    param\name = "DisplacementMap"
    param\remarque = "Nécessite 2 images : source + displacement"
    param\info[0] = "intensity"
    param\info[1] = "offset X"
    param\info[2] = "offset Y"
    param\info[3] = "Wrap mode"
    param\info[4] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 500 : param\info_data(0,2) = 1
    param\info_data(1,0) = 0 : param\info_data(1,1) = 200 : param\info_data(1,2) = 100
    param\info_data(2,0) = 0 : param\info_data(2,1) = 200 : param\info_data(2,2) = 100
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 1   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf

  Protected *source = *param\source
  Protected *source2 = *param\mix
  Protected *cible  = *param\cible
  Protected *mask = *param\mask
  Protected i
  If *source = 0 Or *cible = 0 Or *source2 = 0 : ProcedureReturn : EndIf
  
  Protected thread = CountCPUs(#PB_System_CPUs)
  Clamp(thread, 1, 128)
  Protected Dim tr(thread)

  MultiThread_MT(@DisplacementMap_MT())
  If *mask : *param\mask_type = *param\option[4] : MultiThread_MT(@_mask()) : EndIf
  FreeArray(tr())
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 75
; FirstLine = 19
; Folding = -
; EnableXP
; DPIAware