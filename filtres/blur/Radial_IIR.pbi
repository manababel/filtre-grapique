
Procedure RadialBlur_IIR_MT(*FilterCtx.FilterParams)
  With FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected cx = (\option[1] * lg) / 100
    Protected cy = (\option[2] * ht) / 100
    Protected pos , i , j
    Protected cosA.f , sinA.f
    Protected maxRadius
    Protected a , r.f , g.f , b.f
    Protected r1 ,g1 ,b1
    Protected firstPixel = #True
    Protected px , py
    Protected Alpha.f , inv_Alpha.f
    Protected quality = \option[3]
    Protected *scr.Pixel32
    Protected *dst.Pixel32
    Alpha = Exp(-2.3 / (\option[0] + 1))
    inv_Alpha = 1 - alpha
    maxRadius = Sqr(lg * lg + ht * ht)
    Protected tt = 360 * quality
    
    macro_calul_tread(tt)
    ;For i = 0 To (360 * quality) - 1
    For i = thread_start To thread_stop
      cosA = PeekF(\addr[2] + i <<2)
      sinA = PeekF(\addr[3] + i <<2)
      ; Variables pour flou IIR
      r = 0 : g = 0 : b = 0
      firstPixel = #True
      For j = 0 To maxRadius
        ; Position en cartésien
        px = cx + (j * cosA)
        py = cy + (j * sinA)
        If px < 0 Or py < 0 Or px >= lg Or py >= ht : Continue : EndIf
        ; Lecture pixel depuis buffer source (nearest neighbor)
        pos = ((py) * lg + (px)) << 2
        *scr = \addr[0] + pos
        getargb(*scr\l , a , r1 , g1 , b1)
        If firstPixel
          r = r1  : g = g1  : b = b1 
          firstPixel = #False
        Else
          ; Application du flou IIR exponentiel
          r = (Alpha * r + inv_Alpha * r1)
          g = (Alpha * g + inv_Alpha * g1)
          b = (Alpha * b + inv_Alpha * b1)
        EndIf
        ; Écriture dans image temporaire
        r1 = r
        g1 = g
        b1 = b
        clamp_rgb(r1,g1,b1)
        *dst = \addr[1] + pos
        *dst\l = (a << 24) | (r1 << 16) | (g1 << 8) | b1
      Next
    Next
  EndWith
EndProcedure

Procedure RadialBlur_IIREx( *FilterCtx.FilterParams )
  ; Mode interface : renseigner les informations sur les options si demandé
  Restore RadialBlur_IIR_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With FilterCtx
    Protected i , angle.f
    Protected quality = \option[3]
    Protected inv_quality.f = 1/quality
    Protected Dim rc.f(360 * quality)
    Protected Dim rs.f(360 * quality)
    For i = 0 To (360 * quality) - 1
      angle = Radian(i * inv_quality) 
      rc(i) = Cos(angle)
      rs(i) = Sin(angle)
    Next
    \addr[2] = @rc()
    \addr[3] = @rs()
    
  EndWith
  
  Create_MultiThread_MT(@RadialBlur_IIR_MT())
  
  mask_update(*FilterCtx.FilterParams , last_data)
  
  FreeArray(rc())
  FreeArray(rs())
EndProcedure

Procedure RadialBlur_IIR(source , cible , mask , Rayon , posx , posy , qualite)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = Rayon
    \option[1] = posx
    \option[2] = posy
    \option[3] = qualite
  EndWith
  RadialBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RadialBlur_IIR_data:
  Data.s "RadialBlur_IIR"
  Data.s ""
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Rayon"         
  Data.i 1,50,25
  Data.s "Pos X"         
  Data.i 0,100,50
  Data.s "Pos Y"         
  Data.i 0,100,50
  Data.s "qualité"         
  Data.i 0,128,32
  Data.s "XXX"
EndDataSection

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 63
; FirstLine = 52
; Folding = -
; EnableXP
; DPIAware