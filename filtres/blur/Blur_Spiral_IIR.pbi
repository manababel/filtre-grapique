Procedure SpiralBlur_IIR_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected Radius = *param\option[0]
  Protected cx.f = (*param\option[1] * lg) / 100
  Protected cy.f = (*param\option[2] * ht) / 100
  Protected force.i = *param\option[3]
  Protected quality = *param\option[4]
  Protected direction = *param\option[6]
  Protected pos, i, j
  
  ; Précalcul direction
  direction = (direction * 2) - 1
  
  Protected a, r.f, g.f, b.f
  Protected r1, g1, b1
  Protected firstPixel
  Protected px.f, py.f
  Protected Alpha.f, inv_Alpha.f
  Protected maxRadiusInt.i
  
  ; Optimisation : calcul des carrés une seule fois
  Protected cx2.f = cx * cx
  Protected cy2.f = cy * cy
  Protected lgMinusCx.f = lg - cx
  Protected htMinusCy.f = ht - cy
  Protected lgMinusCx2.f = lgMinusCx * lgMinusCx
  Protected htMinusCy2.f = htMinusCy * htMinusCy
  
  maxRadiusInt = Max_4(Sqr(cx2 + cy2), Sqr(lgMinusCx2 + cy2), Sqr(cx2 + htMinusCy2), Sqr(lgMinusCx2 + htMinusCy2))
  Protected activeRadius.f = (*param\option[5] * maxRadiusInt) / 100
  
  Protected angleCount = 360 * quality
  Protected forceMod = (force * direction) % angleCount
  If forceMod < 0 : forceMod + angleCount : EndIf
  
  ; Précalcul Alpha
  Alpha = Exp(-2.3 / (Radius + 1))
  inv_Alpha = 1 - Alpha
  
  Protected *scr.Pixel32
  Protected *dst.Pixel32
  
  ; Pointeurs vers les buffers pré-alloués
  Protected *cosTable.Float = *param\addr[2]
  Protected *sinTable.Float = *param\addr[3]
  
  ; Précalculs pour l'accès mémoire
  Protected lgShift2.i = lg << 2
  Protected activeRadiusInt.i = activeRadius
  
  macro_calul_tread(angleCount)
  
  For i = thread_start To thread_stop
    r = 0 : g = 0 : b = 0
    firstPixel = #True
    
    ; idx normalisé une seule fois
    Protected idx.i = i
    If idx >= angleCount
      idx = idx % angleCount
    EndIf
    
    ; Précalcul des offsets cosinus/sinus
    Protected idxOffset.i = idx << 2
    Protected cosVal.f = PeekF(*cosTable + idxOffset)
    Protected sinVal.f = PeekF(*sinTable + idxOffset)
    
    For j = 0 To maxRadiusInt
      ; Mise à jour de l'angle avec la force
      If j > 0
        idx + forceMod
        If idx >= angleCount
          idx - angleCount
        EndIf
        idxOffset = idx << 2
        cosVal = PeekF(*cosTable + idxOffset)
        sinVal = PeekF(*sinTable + idxOffset)
      EndIf
      
      ; Calcul optimisé de la position avec multiplication par j factorisée
      Protected jFloat.f = j
      px = cx + jFloat * cosVal
      py = cy + jFloat * sinVal
      
      ; Test de limites optimisé
      If px < 0 Or py < 0 Or px >= lg Or py >= ht
        Continue
      EndIf
      
      Protected ix.i = Int(px)
      Protected iy.i = Int(py)
      
      ; Calcul d'offset optimisé
      pos = (iy * lgShift2) + (ix << 2)
      *scr = *param\addr[0] + pos
      
      ; Lecture directe des composantes
      Protected pixel.l = *scr\l
      a = (pixel >> 24) & $FF
      r1 = (pixel >> 16) & $FF
      g1 = (pixel >> 8) & $FF
      b1 = pixel & $FF
      
      ; Application du filtre IIR uniquement dans le rayon actif
      If j < activeRadiusInt
        If firstPixel
          r = r1
          g = g1
          b = b1
          firstPixel = #False
        Else
          r = Alpha * r + inv_Alpha * r1
          g = Alpha * g + inv_Alpha * g1
          b = Alpha * b + inv_Alpha * b1
        EndIf
        r1 = r
        g1 = g
        b1 = b
      EndIf
      
      ; Clamping optimisé inline
      If r1 < 0 : r1 = 0 : ElseIf r1 > 255 : r1 = 255 : EndIf
      If g1 < 0 : g1 = 0 : ElseIf g1 > 255 : g1 = 255 : EndIf
      If b1 < 0 : b1 = 0 : ElseIf b1 > 255 : b1 = 255 : EndIf
      
      ; Écriture directe
      *dst = *param\addr[1] + pos
      *dst\l = (a << 24) | (r1 << 16) | (g1 << 8) | b1
    Next
  Next
EndProcedure


Procedure SpiralBlur_IIR(*param.parametre)
  
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Directional
    *param\name = "SpiralBlur_IIR"
    *param\remarque = "appliquer un filtre de flou en spirale (optimisé)"
    *param\info[0] = "Rayon du filtre"          
    *param\info[1] = "Pos X"           
    *param\info[2] = "Pos Y"          
    *param\info[3] = "Force de rotation"   
    *param\info[4] = "Qualité" 
    *param\info[5] = "Rayon actif"   
    *param\info[6] = "sens"   
    *param\info[7] = "Masque binaire"    
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 99 : *param\info_data(0,2) = 50
    *param\info_data(1,0) = 0 : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 50
    *param\info_data(2,0) = 0 : *param\info_data(2,1) = 100 : *param\info_data(2,2) = 50
    *param\info_data(3,0) = 0 : *param\info_data(3,1) = 100 : *param\info_data(3,2) = 10
    *param\info_data(4,0) = 16 : *param\info_data(4,1) = 64 : *param\info_data(4,2) = 32
    *param\info_data(5,0) = 0 : *param\info_data(5,1) = 100 : *param\info_data(5,2) = 100
    *param\info_data(6,0) = 0 : *param\info_data(6,1) = 1 : *param\info_data(6,2) = 0
    *param\info_data(7,0) = 0 : *param\info_data(7,1) = 2 : *param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  
  Filter_BufferPrepare(*param.parametre)
  
  Protected i, angle.f
  Protected quality = *param\option[4]
  Protected inv_quality.f = 1.0 / quality
  Protected angleCount = 360 * quality
  
  ; Allocation optimisée avec mémoire alignée
  Dim cosTable.f(angleCount)
  Dim sinTable.f(angleCount) 
  
  ; Précalcul optimisé des tables trigonométriques
  For i = 0 To angleCount - 1
    angle = Radian(i * inv_quality)
    cosTable(i) = Cos(angle)
    sinTable(i) = Sin(angle)
  Next
  
  *param\addr[2] = @cosTable()
  *param\addr[3] = @sinTable()
  
  MultiThread_MT(@SpiralBlur_IIR_MT())
  
  macro_Filter_BufferFinalize(7)
  
  FreeArray(cosTable())
  FreeArray(sinTable())
  
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 125
; FirstLine = 119
; Folding = -
; EnableXP
; DPIAware