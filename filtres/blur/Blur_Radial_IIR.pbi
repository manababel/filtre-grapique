
Procedure RadialBlur_IIR_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected cx = (*param\option[1] * lg) / 100
  Protected cy = (*param\option[2] * ht) / 100
  Protected pos , i , j
  Protected cosA.f , sinA.f
  Protected maxRadius
  Protected a , r.f , g.f , b.f
  Protected r1 ,g1 ,b1
  Protected firstPixel = #True
  Protected px , py
  Protected Alpha.f , inv_Alpha.f
  Protected quality = *param\option[3]
  Protected *scr.Pixel32
  Protected *dst.Pixel32
  Alpha = Exp(-2.3 / (*param\option[0] + 1))
  inv_Alpha = 1 - alpha
  maxRadius = Sqr(lg * lg + ht * ht)
  Protected tt = 360 * quality

  macro_calul_tread(tt)
  ;For i = 0 To (360 * quality) - 1
  For i = thread_start To thread_stop
    cosA = PeekF(*param\addr[2] + i <<2)
    sinA = PeekF(*param\addr[3] + i <<2)
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
      *scr = *param\addr[0] + pos
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
      *dst = *param\addr[1] + pos
      *dst\l = (a << 24) | (r1 << 16) | (g1 << 8) | b1
    Next
  Next
EndProcedure

Procedure RadialBlur_IIR( *param.parametre )
  ; Mode interface : renseigner les informations sur les options si demandé
  If param\info_active
    param\typ = #FilterType_Blur
    param\subtype = #Blur_Directional
    param\name = "RadialBlur_IIR"
    param\remarque = "Flou radial exponentiel (IIR) rapide"
    param\info[0] = "Rayon"           ; Rayon horizontal
    param\info[1] = "pos X"       
    param\info[2] = "pos Y"  
    param\info[3] = "qualité" 
    param\info[4] = "Masque binaire"    ; Option masque binaire
    param\info_data(0,0) = 1 : param\info_data(0,1) = 1999 : param\info_data(0,2) = 100
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 16 : param\info_data(3,1) = 128   : param\info_data(3,2) = 32
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  
  Filter_BufferPrepare(*param.parametre)
 
  Protected i , angle.f
  Protected quality = *param\option[3]
  Protected inv_quality.f = 1/quality
  Protected Dim rc.f(360 * quality)
  Protected Dim rs.f(360 * quality)
  For i = 0 To (360 * quality) - 1
    angle = Radian(i * inv_quality) 
    rc(i) = Cos(angle)
    rs(i) = Sin(angle)
  Next
  *param\addr[2] = @rc()
  *param\addr[3] = @rs()
  
    MultiThread_MT(@RadialBlur_IIR_MT())

  macro_Filter_BufferFinalize(4)
  
  FreeArray(rc())
  FreeArray(rs())
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 63
; FirstLine = 32
; Folding = -
; EnableXP
; DPIAware