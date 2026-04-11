Procedure PrecomputeBoundTableSym(*param.parametre)
  Protected sector.d, angle.d, bound.d
  Protected tableSize = 90
  Protected angleIndex
  Protected radius = *param\option[0]
  Protected sides = *param\option[1]
  
  If sides <= 0 : ProcedureReturn : EndIf
  
  sector = 2.0 * #PI / sides
  Protected sectorHalf.d = sector / 2.0
  Protected piHalfDivTableSize.d = (#PI / 2.0) / tableSize
  
  For angleIndex = 0 To tableSize - 1
    angle = angleIndex * piHalfDivTableSize
    angle = angle - sector * Int(angle / sector)
    bound = radius * Cos(angle - sectorHalf)
    PokeF(*param\addr[4] + angleIndex * 4, bound)
  Next
EndProcedure


Procedure Precompute_KernelLookup(*param.parametre)
  Protected dx, dy, k = 0
  Protected dist.d, angle.d, bound.d
  Protected radius = *param\option[0]
  Protected sides = *param\option[1]
  Protected w = *param\lg
  Protected maxcells = (2 * radius + 1) * (2 * radius + 1)
  Protected inside
  Protected angleIndex
  Protected radiusSq = radius * radius
  Protected invRadius.d = 1.0 / radius
  Protected twoPI.d = 2.0 * #PI
  Protected piHalf.d = #PI / 2.0
  Protected pi.d = #PI
  Protected pi1_5.d = 1.5 * #PI
  Protected angleScale.d = 90.0 / piHalf
  
  If radius <= 0 : ProcedureReturn : EndIf
  
  *param\option[5] = 0
  
  For dy = -radius To radius
    For dx = -radius To radius
      dist = dx * dx + dy * dy
      inside = 0
      
      If sides > 0
        angle = ATan2(dy, dx)
        If angle < 0.0 : angle + twoPI : EndIf
        
        ; Réduire l'angle à 0..π/2 par symétrie
        If angle >= pi1_5
          angle = twoPI - angle
        ElseIf angle >= pi
          angle - pi
        ElseIf angle >= piHalf
          angle = pi - angle
        EndIf
        
        angleIndex = Int(angle * angleScale)
        If angleIndex > 89 : angleIndex = 89 : EndIf
        
        bound = PeekF(*param\addr[4] + angleIndex * 4)
        
        If dist <= bound * bound
          inside = 1
        EndIf
      Else
        ; Cercle simple
        If dist <= radiusSq
          inside = 1
        EndIf
      EndIf
      
      If inside
        PokeL(*param\addr[2] + k * 4, dy * w + dx)
        Protected weight.d = Max_2(0.0, 1.0 - Sqr(dist) * invRadius)
        PokeD(*param\addr[3] + k * 8, weight)
        k + 1
      EndIf
    Next
  Next
  
  *param\option[5] = k
EndProcedure


; --- Thread worker avec table pré-calculée
Procedure BokehBlur_MT(*param.parametre)
  Protected w = *param\lg
  Protected h = *param\ht
  Protected highlight_boost = *param\option[2]
  Protected *src32.Pixel32
  Protected *dst32.Pixel32
  Protected k, x, y, pos, ipos
  Protected accA.d, accR.d, accG.d, accB.d, weightSum.d
  Protected weight.d, bf.d, lum.d
  Protected a0, r0, g0, b0
  Protected wcount = w * h
  Protected weightSum_inv.d
  Protected kernelCount = *param\option[5]
  Protected boost_factor.d = highlight_boost / 100.0
  
  macro_calul_tread(h)
  
  For y = thread_start To thread_stop - 1
    For x = 0 To w - 1
      pos = y * w + x
      accA = 0.0 : accR = 0.0 : accG = 0.0 : accB = 0.0 : weightSum = 0.0
      
      For k = 0 To kernelCount - 1
        ipos = pos + PeekL(*param\addr[2] + k * 4)
        If ipos < 0 Or ipos >= wcount : Continue : EndIf
        
        *src32 = *param\addr[0] + (ipos << 2)
        GetARGB(*src32\l, a0, r0, g0, b0)
        
        weight = PeekD(*param\addr[3] + k * 8)
        If weight <= 0.0 : Continue : EndIf
        
        ; Highlight boost
        If highlight_boost <> 0
          lum = 0.3 * r0 + 0.59 * g0 + 0.11 * b0
          bf = 1.0 + boost_factor * (lum / 255.0)
        Else
          bf = 1.0
        EndIf
        
        Protected weightBf.d = weight * bf
        accA + a0 * weightBf
        accR + r0 * weightBf
        accG + g0 * weightBf
        accB + b0 * weightBf
        weightSum + weightBf
      Next
      
      *dst32 = *param\addr[1] + (pos << 2)
      
      If weightSum <= 0.0
        *src32 = *param\addr[0] + (pos << 2)
        *dst32\l = *src32\l
      Else
        weightSum_inv = 1.0 / weightSum
        a0 = Int(accA * weightSum_inv + 0.5)
        r0 = Int(accR * weightSum_inv + 0.5)
        g0 = Int(accG * weightSum_inv + 0.5)
        b0 = Int(accB * weightSum_inv + 0.5)
        clamp_argb(a0, r0, g0, b0)
        *dst32\l = (a0 << 24) | (r0 << 16) | (g0 << 8) | b0
      EndIf
    Next
  Next
EndProcedure


; --- Entrée principale optimisée
Procedure BokehBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Optical
    *param\name = "Bokeh Blur"
    *param\remarque = "Flou bokeh avec kernel polygonal pré-calculé"
    *param\info[0] = "Radius"
    *param\info[1] = "Sides (0=circle)"
    *param\info[2] = "Highlight boost (0..100)"
    *param\info[3] = "Masque"
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 100 : *param\info_data(0, 2) = 8
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 12  : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 200 : *param\info_data(2, 2) = 10
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 2   : *param\info_data(3, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Validation du radius
  If *param\option[0] < 1 : *param\option[0] = 1 : EndIf
  If *param\option[0] > 100 : *param\option[0] = 100 : EndIf
  
  Protected radius = *param\option[0]
  Protected maxcells = (2 * radius + 1) * (2 * radius + 1)
  
  ; Allocation des buffers
  *param\addr[2] = AllocateMemory(maxcells * 4)  ; Offsets
  *param\addr[3] = AllocateMemory(maxcells * 8)  ; Weights (Double)
  *param\addr[4] = AllocateMemory(90 * 4)        ; Bound table
  
  If *param\addr[2] = 0 Or *param\addr[3] = 0 Or *param\addr[4] = 0
    If *param\addr[2] : FreeMemory(*param\addr[2]) : EndIf
    If *param\addr[3] : FreeMemory(*param\addr[3]) : EndIf
    If *param\addr[4] : FreeMemory(*param\addr[4]) : EndIf
    ProcedureReturn
  EndIf
  
  ; Précomputation des tables
  PrecomputeBoundTableSym(*param)
  Precompute_KernelLookup(*param)
  
  ; Application du filtre
  If Filter_BufferPrepare(*param) <> 0
    MultiThread_MT(@BokehBlur_MT())
    macro_Filter_BufferFinalize(3)
  EndIf
  
  ; Libération de la mémoire
  FreeMemory(*param\addr[2])
  FreeMemory(*param\addr[3])
  FreeMemory(*param\addr[4])
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 208
; FirstLine = 139
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger