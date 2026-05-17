; ---------------------------------------------------
; Cat Eye Bokeh Blur - Version optimisée
; Flou bokeh elliptique (effet d'objectif anamorphique)
; ---------------------------------------------------

Procedure CatEyeBokehBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0], elong = \option[1]
    Protected x, y, dx, dy, px, py, index, value, count
    Protected sumA, sumR, sumG, sumB, a, r, g, b
    Protected nx.d, ny.d, dist.d
    Protected lg_minus_1 = lg - 1, ht_minus_1 = ht - 1
    Protected radiusSq_elongSq.d = (radius * radius) * (elong * elong)
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0 : count = 0
        
        ; Parcourir un voisinage elliptique
        For dy = -radius To radius
          ny = dy
          For dx = -radius To radius
            ; Transformation elliptique
            nx = dx * elong
            dist = nx * nx + ny * ny
            
            If dist <= radiusSq_elongSq
              px = x + Round(nx, #PB_Round_Nearest)
              py = y + ny
              
              ; Clamping des coordonnées
              If px < 0 : px = 0 : ElseIf px > lg_minus_1 : px = lg_minus_1 : EndIf
              If py < 0 : py = 0 : ElseIf py > ht_minus_1 : py = ht_minus_1 : EndIf
              
              index = (py * lg + px) << 2
              value = PeekL(\addr[0] + index)
              
              sumA + ((value >> 24) & $FF)
              sumR + ((value >> 16) & $FF)
              sumG + ((value >> 8) & $FF)
              sumB + (value & $FF)
              count + 1
            EndIf
          Next
        Next
        
        index = (y * lg + x) << 2
        If count > 0
          a = sumA / count : r = sumR / count
          g = sumG / count : b = sumB / count
          ; Clamping rapide
          If a > 255 : a = 255 : EndIf : If r > 255 : r = 255 : EndIf
          If g > 255 : g = 255 : EndIf : If b > 255 : b = 255 : EndIf
          PokeL(\addr[1] + index, (a << 24) | (r << 16) | (g << 8) | b)
        Else
          PokeL(\addr[1] + index, PeekL(\addr[0] + index))
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure CatEyeBokehBlurEx(*FilterCtx.FilterParams)
  Restore CatEyeBokehBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  ; Bornage des options
  If *FilterCtx\option[0] < 1 : *FilterCtx\option[0] = 1 : EndIf
  If *FilterCtx\option[1] < 1 : *FilterCtx\option[1] = 1 : EndIf
  
  Create_MultiThread_MT(@CatEyeBokehBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure CatEyeBokehBlur(source, cible, mask, radius, elongation)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius : \option[1] = elongation
  EndWith
  CatEyeBokehBlurEx(FilterCtx)
EndProcedure

DataSection
  CatEyeBokehBlur_data:
  Data.s "Cat Eye Bokeh Blur"
  Data.s "Flou bokeh elliptique simulant un effet d'objectif anamorphique"
  Data.i #FilterType_Blur, #Blur_Optical
  Data.s "Rayon"
  Data.i 1, 50, 10
  Data.s "Allongement"
  Data.i 1, 5, 2
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 79
; FirstLine = 46
; Folding = -
; EnableXP
; DPIAware