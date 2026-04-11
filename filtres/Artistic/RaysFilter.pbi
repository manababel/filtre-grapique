; ---------------- RaysFilter PureBasic ----------------
Procedure RaysFilter_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *output = *param\addr[1]
  Protected *rays = *param\addr[2]
  Protected width  = *param\lg
  Protected height = *param\ht
  Protected threshold = *param\option[0]   ; 0..1
  Protected strength.f  = *param\option[1]   ; 0..1
  Protected raysOnly  = *param\option[2]   ; 0=add to original, 1=rays only
  Protected centerX   = (*param\option[3] * width) / 100
  Protected centerY   = (*param\option[4] * height) / 100
  Protected numRays   = *param\option[5]
  Protected maxLength = *param\option[6]
  
  strength = strength * 0.01
  
  Protected start = (*param\thread_pos * height) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * height) / *param\thread_max

  Protected i, j, x, y
  Protected dx.f, dy.f
  Protected r, g, b, lum
  Protected col, srcCol, r1, g1, b1

  ; Créer un buffer temporaire pour les rayons

  If *rays = 0 : ProcedureReturn : EndIf

  ; Étape 1 : luminosité et threshold
  For y = start To stop - 1
    For x = 0 To width - 1
      srcCol = PeekL(*source + (y*width+x)*4)
      getrgb(srcCol,r1,g1,b1)
      lum = (r1+g1+b1)/3
      If lum < threshold
        PokeL(*rays + (y*width+x)*4, 0)
      Else
        r = lum 
        g = lum
        b = lum
        PokeL(*rays + (y*width+x)*4, (Int(r)<<16)|(Int(g)<<8)|Int(b))
      EndIf
    Next
  Next

  ; Étape 2 : créer les rayons
  For i = 0 To numRays-1
    dx.f = Cos(i * 2*#PI/numRays)
    dy.f = Sin(i * 2*#PI/numRays)
    For y = start To stop - 1
      For x = 0 To width - 1
        col = PeekL(*rays + (y*width+x)*4)
        If col = 0 : Continue : EndIf
        For j = 1 To maxLength
          Protected sx = x + dx*j
          Protected sy = y + dy*j
          If sx < 0 Or sx >= width Or sy < 0 Or sy >= height : Break : EndIf
          getrgb(col , r , g , b)
          r = r * strength
          g = g * strength
          b = b * strength
          srcCol = PeekL(*rays + (Int(sy)*width+Int(sx))*4)
          If raysOnly
            PokeL(*rays + (Int(sy)*width+Int(sx))*4, (Int(r)<<16)|(Int(g)<<8)|Int(b))
          Else
            r1 = (((srcCol>>16)&255)+r)
            g1 = (((srcCol>>8)&255)+g)
            b1 = ((srcCol&255)+b)
            clamp_RGB(r1 , g1 , b1)
            PokeL(*rays + (Int(sy)*width+Int(sx))*4, (Int(r1)<<16)|(Int(g1)<<8)|Int(b1))
          EndIf
        Next
      Next
    Next
  Next

EndProcedure

; ---------------- Procédure principale ----------------
Procedure RaysFilter(*param.parametre)
  If *param\info_active
    *param\name = "RaysFilter"
    *param\typ  = #FilterType_Artistic
    *param\subtype = #Artistic_Other
    *param\remarque = "Effet de rayons lumineux multi-thread"
    *param\info[0] = "Threshold (0-1)"
    *param\info[1] = "Strength (0-1)"
    *param\info[2] = "RaysOnly (0/1)"
    *param\info[3] = "CenterX"
    *param\info[4] = "CenterY"
    *param\info[5] = "NumRays"
    *param\info[6] = "MaxLength"
    *param\info_data(0,0)=0 : *param\info_data(0,1)=255 : *param\info_data(0,2)=10
    *param\info_data(1,0)=0 : *param\info_data(1,1)=100 : *param\info_data(1,2)=100
    *param\info_data(2,0)=0 : *param\info_data(2,1)=1 : *param\info_data(2,2)=0
    *param\info_data(3,0)=0 : *param\info_data(3,1)=100 : *param\info_data(3,2)=50
    *param\info_data(4,0)=0 : *param\info_data(4,1)=100 : *param\info_data(4,2)=50
    *param\info_data(5,0)=1 : *param\info_data(5,1)=360 : *param\info_data(5,2)=64
    *param\info_data(6,0)=1 : *param\info_data(6,1)=200 : *param\info_data(6,2)=100
    ProcedureReturn
  EndIf

  If *param\source=0 Or *param\cible=0 : ProcedureReturn : EndIf
  Protected *rays = AllocateMemory(*param\lg * *param\ht * 4)
  *param\addr[0] = *param\source
  *param\addr[1] = *param\cible
  *param\addr[2] = *rays
  
  MultiThread_MT(@RaysFilter_MT())
  
  CopyMemory(*rays , *param\cible , *param\lg * *param\ht * 4)
  
  If *param\mask
    *param\mask_type = *param\option[7]
    MultiThread_MT(@_mask())
  EndIf
  
  FreeMemory(*rays)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 84
; FirstLine = 47
; Folding = -
; EnableXP
; DPIAware