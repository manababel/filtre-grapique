Procedure RadialBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
  Protected lg = \image_lg[0]
  Protected ht = \image_ht[0]
  Protected Radius = \option[0]
  If Radius < 1 : Radius = 1 : EndIf
  Protected cx = (\option[1] * lg) / 100
  Protected cy = (\option[2] * ht) / 100
  Protected rmax = (\option[3] * Sqr(lg*lg+ht*ht) )/ 100
  If rmax < 1 : rmax = 1 : EndIf
  Protected rmax2.f = rmax * rmax
  Protected samp.f = 1 / (Radius + 1)
  Protected *scr1.Pixel32
  Protected *dst.Pixel32

  Protected startY = (ht * \thread_pos) / \thread_max
  Protected stopY  = (ht * (\thread_pos + 1)) / \thread_max
  If \thread_pos = (\thread_max - 1) : stopY = ht : EndIf

  ; Pré-calcule rmax2 pour éviter conditions multiples
  Protected x, y, i, sx, sy
  Protected dx, dy, fx.f, fy.f
  Protected r1, g1, b1, r.f, g.f , b.f , a
  Protected dist.f, force.f

  For y = startY To stopY - 1
    Protected rowOffset = y * lg * 4
    dy = y - cy
    For x = 0 To lg - 1
      dx = x - cx
      dist = dx*dx + dy*dy

      Protected pixelOffset = rowOffset + x * 4

      If dist > rmax2
        ; Pixel hors zone : copie rapide pixel original
        *scr1 = \addr[0] + pixelOffset
        *dst = \addr[1] + pixelOffset
        *dst\l = *scr1\l
        Continue
      EndIf

      ; Force (fixed point 16.16)
      force = (rmax2 - dist) / rmax2
      If force < 0 : force = 0 : EndIf

      ; Pré-calcul des incréments en fixed-point
      Protected dxStep.f = ((cx - x) * samp)
      Protected dyStep.f = ((cy - y) * samp)
      fx = x
      fy = y
      r = 0
      g = 0
      b = 0
      For i = 0 To Radius
        sx = fx
        sy = fy
        If sx >= 0 And sx < lg And sy >= 0 And sy < ht
          *scr1 = \addr[0] + (sy * lg + sx) * 4
          getrgb(*scr1\l, r1, g1, b1)
          r = r + r1
          g = g + g1
          b = b + b1
        EndIf
        fx + dxStep
        fy + dyStep
      Next

      ; Calcul de la moyenne et application de la force
      ; Évite division flottante: calcule en int puis ajuste
      r = r * samp
      g = g * samp
      b = b * samp
      
      ; Lecture pixel original pour mix
      *scr1 = \addr[0] + pixelOffset
      getargb(*scr1\l , a , r1, g1, b1)
      
      ; Mix approximatif avec le pixel original selon la force
      r1 = r * force + r1 * (1 - force)
      g1 = g * force + g1 * (1 - force)
      b1 = b * force + b1 * (1 - force)
      
      ; Clamp branchless possible ici
      clamp_rgb(r1, g1, b1)
      
      *dst = \addr[1] + pixelOffset
      *dst\l = (a << 24) | (r1 << 16) | (g1 << 8) | b1
    Next
  Next
EndWith

EndProcedure


Procedure RadialBlurEx( *FilterCtx.FilterParams )
  
  Restore RadialBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@RadialBlur_MT())
  
  mask_update(*FilterCtx.FilterParams , last_data)
  
EndProcedure

Procedure RadialBlur(source , cible , mask , echantillonnage , posx , posy , rmax)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = echantillonnage
    \option[1] = posx
    \option[2] = posy
    \option[3] = rmax
  EndWith
  RadialBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  RadialBlur_data:
  Data.s "RadialBlur"
  Data.s ""
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "échantillonnage"         
  Data.i 1,50,25
  Data.s "Pos X"         
  Data.i 0,100,50
  Data.s "Pos Y"         
  Data.i 0,100,50
  Data.s "Rayon Max"         
  Data.i 0,100,50
  Data.s "XXX"
EndDataSection

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 123
; FirstLine = 86
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger