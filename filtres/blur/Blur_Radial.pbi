Procedure RadialBlur_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected Radius = *param\option[0]
  If Radius < 1 : Radius = 1 : EndIf
  Protected cx = (*param\option[1] * lg) / 100
  Protected cy = (*param\option[2] * ht) / 100
  Protected rmax = (*param\option[3] * Sqr(lg*lg+ht*ht) )/ 100
  If rmax < 1 : rmax = 1 : EndIf
  Protected rmax2.f = rmax * rmax
  Protected samp.f = 1 / (Radius + 1)
  Protected *scr1.Pixel32
  Protected *dst.Pixel32

  Protected startY = (ht * *param\thread_pos) / *param\thread_max
  Protected stopY  = (ht * (*param\thread_pos + 1)) / *param\thread_max
  If *param\thread_pos = (*param\thread_max - 1) : stopY = ht : EndIf

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
        *scr1 = *param\addr[0] + pixelOffset
        *dst = *param\addr[1] + pixelOffset
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
          *scr1 = *param\addr[0] + (sy * lg + sx) * 4
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
      *scr1 = *param\addr[0] + pixelOffset
      getargb(*scr1\l , a , r1, g1, b1)
      
      ; Mix approximatif avec le pixel original selon la force
      r1 = r * force + r1 * (1 - force)
      g1 = g * force + g1 * (1 - force)
      b1 = b * force + b1 * (1 - force)
      
      ; Clamp branchless possible ici
      clamp_rgb(r1, g1, b1)
      
      *dst = *param\addr[1] + pixelOffset
      *dst\l = (a << 24) | (r1 << 16) | (g1 << 8) | b1
    Next
  Next

EndProcedure


Procedure RadialBlur( *param.parametre )
  ; Mode interface : renseigner les informations sur les options si demandé
  If param\info_active
    param\typ = #FilterType_Blur
    param\subtype = #Blur_Directional
    param\name = "RadialBlur"
    param\remarque = "#Blur_Classic"
    param\info[0] = "échantillonnage"          
    param\info[1] = "Pos X"           
    param\info[2] = "Pos Y"          
    param\info[3] = "Rayon Max"   
    param\info[5] = "Masque"    
    param\info_data(0,0) = 1 : param\info_data(0,1) = 50 : param\info_data(0,2) = 25
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 0 : param\info_data(3,1) = 100 : param\info_data(3,2) = 50
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@RadialBlur_MT() , 4)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 97
; FirstLine = 45
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger