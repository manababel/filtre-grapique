; ---------------------------------------------------
; Polygonal Bokeh Blur - Version optimisée
; Flou bokeh avec forme polygonale remplie (Ray Casting)
; ---------------------------------------------------

Procedure PolygonBokeh_PrecomputeKernel(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected radius = \option[0]
    Protected sides = \option[1]
    Protected lg = \image_lg[0]
    Protected dx, dy, k = 0, i, j
    Protected x.d, y.d, dist.d, angle.d
    Protected inside, cond1, cond2
    Protected twoPI.d = 2.0 * #PI
    Protected invSides.d = 1.0 / sides
    
    ; Pré-calculer les sommets du polygone
    Dim vertices.d(sides * 2 - 1)
    For i = 0 To sides - 1
      angle = twoPI * i * invSides - #PI / 2.0
      vertices(i * 2) = Cos(angle) * radius
      vertices(i * 2 + 1) = Sin(angle) * radius
    Next
    
    ; Parcourir le carré englobant pour définir le kernel
    For dy = -radius To radius
      For dx = -radius To radius
        x = dx : y = dy
        dist = Sqr(x * x + y * y)
        
        If dist > radius : Continue : EndIf
        
        ; Test Point-in-Polygon (Ray Casting)
        inside = 0
        For i = 0 To sides - 1
          j = (i + 1) % sides
          Protected vx1.d = vertices(i * 2)
          Protected vy1.d = vertices(i * 2 + 1)
          Protected vx2.d = vertices(j * 2)
          Protected vy2.d = vertices(j * 2 + 1)
          
          cond1 = 0 : cond2 = 0
          If vy1 > y : cond1 = 1 : EndIf
          If vy2 > y : cond2 = 1 : EndIf
          
          If cond1 <> cond2
            Protected intersectX.d = (vx2 - vx1) * (y - vy1) / (vy2 - vy1) + vx1
            If x < intersectX : inside ! 1 : EndIf
          EndIf
        Next
        
        If inside
          PokeL(\addr[2] + k * 4, dy * lg + dx)
          ; Poids gaussien basé sur la distance au centre
          Protected weight.d = Exp(-(dist * dist) / (radius * radius * 0.5))
          PokeD(\addr[3] + k * 8, weight)
          k + 1
        EndIf
      Next
    Next
    
    \option[5] = k ; Nombre de pixels actifs dans le kernel
    FreeArray(vertices())
  EndWith
EndProcedure

Procedure PolygonBokehBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected w = \image_lg[0], h = \image_ht[0]
    Protected highlight_boost = \option[2]
    Protected kernelCount = \option[5]
    Protected boost_factor.d = highlight_boost / 100.0
    Protected wcount = w * h
    Protected x, y, k, pos, ipos, value
    Protected accA.d, accR.d, accG.d, accB.d, weightSum.d, weight.d, bf.d, lum.d
    Protected a0, r0, g0, b0
    
    macro_calul_tread(h)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To w - 1
        pos = y * w + x
        accA = 0.0 : accR = 0.0 : accG = 0.0 : accB = 0.0 : weightSum = 0.0
        
        For k = 0 To kernelCount - 1
          ipos = pos + PeekL(\addr[2] + k * 4)
          If ipos < 0 Or ipos >= wcount : Continue : EndIf
          
          value = PeekL(\addr[0] + (ipos << 2))
          a0 = (value >> 24) & $FF : r0 = (value >> 16) & $FF
          g0 = (value >> 8)  & $FF : b0 = value & $FF
          
          weight = PeekD(\addr[3] + k * 8)
          
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
          a0 = accA * invSum + 0.5 : r0 = accR * invSum + 0.5
          g0 = accG * invSum + 0.5 : b0 = accB * invSum + 0.5
          If a0 > 255 : a0 = 255 : EndIf : If r0 > 255 : r0 = 255 : EndIf
          If g0 > 255 : g0 = 255 : EndIf : If b0 > 255 : b0 = 255 : EndIf
          PokeL(\addr[1] + (pos << 2), (a0 << 24) | (r0 << 16) | (g0 << 8) | b0)
        Else
          PokeL(\addr[1] + (pos << 2), PeekL(\addr[0] + (pos << 2)))
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure PolygonBokehBlurEx(*FilterCtx.FilterParams)
  Restore PolygonBokehBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    If \option[0] < 1 : \option[0] = 1 : EndIf
    If \option[1] < 3 : \option[1] = 3 : EndIf
    
    Protected radius = \option[0]
    Protected maxcells = (2 * radius + 1) * (2 * radius + 1)
    
    \addr[2] = AllocateMemory(maxcells * 4) ; Offsets
    \addr[3] = AllocateMemory(maxcells * 8) ; Weights (Double)
    
    If \addr[2] And \addr[3]
      PolygonBokeh_PrecomputeKernel(*FilterCtx)
      Create_MultiThread_MT(@PolygonBokehBlur_sp(), 1)
      FreeMemory(\addr[2]) : FreeMemory(\addr[3])
    EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure PolygonBokehBlur(source, cible, mask, radius, sides, highlightBoost)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius : \option[1] = sides : \option[2] = highlightBoost
  EndWith
  PolygonBokehBlurEx(FilterCtx)
EndProcedure

DataSection
  PolygonBokehBlur_data:
  Data.s "Polygonal Bokeh Blur"
  Data.s "Flou bokeh avec diaphragme polygonal rempli et boost lumineux"
  Data.i #FilterType_Blur, #Blur_Optical
  Data.s "Rayon"
  Data.i 1, 50, 10
  Data.s "Côtés"
  Data.i 3, 12, 6
  Data.s "Highlight boost"
  Data.i 0, 200, 20
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 147
; FirstLine = 116
; Folding = -
; EnableXP
; DPIAware