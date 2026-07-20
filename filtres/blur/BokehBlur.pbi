; ---------------------------------------------------
; Bokeh Blur - Version optimisée
; Flou bokeh avec kernel polygonal (diaphragme) pré-calculé
; ---------------------------------------------------

Procedure Bokeh_PrecomputeBoundTableSym(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected sector.d, angle.d, bound.d
    Protected tableSize = 90
    Protected angleIndex
    Protected radius = \option[0]
    Protected sides = \option[1]
    Protected *dst.floatarray = \addr[4]
    
    If sides <= 0 : ProcedureReturn : EndIf
    
    sector = 2.0 * #PI / sides
    Protected sectorHalf.d = sector / 2.0
    Protected piHalfDivTableSize.d = (#PI / 2.0) / tableSize
    
    For angleIndex = 0 To tableSize - 1
      angle = angleIndex * piHalfDivTableSize
      angle = angle - sector * Int(angle / sector)
      bound = radius * Cos(angle - sectorHalf)
      *dst\f[angleIndex] = bound
    Next
  EndWith
EndProcedure

Procedure Bokeh_Precompute_KernelLookup(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected dx, dy, k = 0
    Protected dist.d, angle.d, bound.d
    Protected radius = \option[0]
    Protected sides = \option[1]
    Protected w = \image_lg[0]
    Protected inside, angleIndex
    Protected radiusSq = radius * radius
    Protected invRadius.d = 1.0 / radius
    Protected twoPI.d = 2.0 * #PI
    Protected piHalf.d = #PI / 2.0
    Protected pi.d = #PI
    Protected pi1_5.d = 1.5 * #PI
    Protected angleScale.d = 90.0 / piHalf
    
    If radius <= 0 : ProcedureReturn : EndIf
    
    For dy = -radius To radius
      For dx = -radius To radius
        dist = dx * dx + dy * dy
        inside = 0
        
        If sides > 0
          angle = ATan2(dy, dx)
          If angle < 0.0 : angle + twoPI : EndIf
          
          ; Réduire l'angle à 0..π/2 par symétrie pour la BoundTable
          If angle >= pi1_5
            angle = twoPI - angle
          ElseIf angle >= pi
            angle - pi
          ElseIf angle >= piHalf
            angle = pi - angle
          EndIf
          
          angleIndex = Int(angle * angleScale)
          If angleIndex > 89 : angleIndex = 89 : EndIf
          bound = PeekF(\addr[4] + angleIndex * 4)
          If dist <= bound * bound : inside = 1 : EndIf
        Else
          If dist <= radiusSq : inside = 1 : EndIf
        EndIf
        
        If inside
          PokeL(\addr[2] + k * 4, dy * w + dx)
          Protected weight.d = 1.0 - Sqr(dist) * invRadius
          If weight < 0.0 : weight = 0.0 : EndIf
          PokeD(\addr[3] + k * 8, weight)
          k + 1
        EndIf
      Next
    Next
    \option[5] = k ; Stockage du nombre d'éléments dans le kernel
  EndWith
EndProcedure

Procedure BokehBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0], h = \image_ht[0]
    Protected highlight_boost = \option[2]
    Protected kernelCount = \option[5]
    Protected boost_factor.d = highlight_boost / 100.0
    Protected wcount = w * h
    Protected x, y, k, pos, ipos, a0, r0, g0, b0
    Protected accA.d, accR.d, accG.d, accB.d, weightSum.d, weight.d, bf.d, lum.d
    Protected value, *src32.Pixel32
    
    Protected *src.pixelarray = \addr[0]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(h)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        pos = y * w + x
        accA = 0.0 : accR = 0.0 : accG = 0.0 : accB = 0.0 : weightSum = 0.0
        
        For k = 0 To kernelCount - 1
          ipos = pos + PeekL(\addr[2] + k * 4)
          If ipos < 0 Or ipos >= wcount : Continue : EndIf
          
          getargb(*src\l[ipos] , a0 , r0 , g0 , b0)
          
          weight = PeekD(\addr[3] + k * 8)
          
          ; Highlight boost : augmente l'influence des pixels clairs
          If highlight_boost <> 0
            lum = 0.299 * r0 + 0.587 * g0 + 0.114 * b0
            bf = 1.0 + boost_factor * (lum / 255.0)
          Else
            bf = 1.0
          EndIf
          
          Protected weightBf.d = weight * bf
          accA + a0 * weightBf : accR + r0 * weightBf
          accG + g0 * weightBf : accB + b0 * weightBf
          weightSum + weightBf
        Next
        
        If weightSum > 0.0
          Protected invSum.d = 1.0 / weightSum
          a0 = accA * invSum + 0.5
          r0 = accR * invSum + 0.5
          g0 = accG * invSum + 0.5
          b0 = accB * invSum + 0.5
          If a0 > 255 : a0 = 255 : EndIf
          If r0 > 255 : r0 = 255 : EndIf
          If g0 > 255 : g0 = 255 : EndIf
          If b0 > 255 : b0 = 255 : EndIf
          *dst\l[pos] = (a0 << 24) | (r0 << 16) | (g0 << 8) | b0
        Else
          *dst\l[pos] = *src\l[pos]
        EndIf
        If key_escape_press = 1 : Break 2 : EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure BokehBlurEx(*FilterCtx.FilterParams)
  Restore BokehBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    clamp(\option[0] , 1 , 100)
    
    Protected radius = \option[0]
    Protected maxcells = (2 * radius + 1) * (2 * radius + 1)
    
    ; Allocation des tables temporaires (addr 2, 3, 4)
    \addr[2] = AllocateMemory(maxcells * 4)  ; Offsets
    \addr[3] = AllocateMemory(maxcells * 8)  ; Weights
    \addr[4] = AllocateMemory(90 * 4)        ; Bound table
    
    If \addr[2] And \addr[3] And \addr[4]
      Bokeh_PrecomputeBoundTableSym(*FilterCtx)
      Bokeh_Precompute_KernelLookup(*FilterCtx)
      
      Create_MultiThread_MT(@BokehBlur_sp())
      
      FreeMemory(\addr[2]) : FreeMemory(\addr[3]) : FreeMemory(\addr[4])
    EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure BokehBlur(source, cible, mask, radius, sides, highlightBoost)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = sides
    \option[2] = highlightBoost
  EndWith
  BokehBlurEx(FilterCtx)
EndProcedure

DataSection
  BokehBlur_data:
  Data.s "Bokeh Blur"
  Data.s "Flou bokeh avec forme de diaphragme paramétrable"
  Data.i #FilterType_Blur, #Blur_Optical
  Data.s "Rayon"
  Data.i 1, 20, 8
  Data.s "Côtés (0=Cercle)"
  Data.i 0, 12, 0
  Data.s "Boost hautes lumières"
  Data.i 0, 200, 10
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 197
; FirstLine = 148
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger