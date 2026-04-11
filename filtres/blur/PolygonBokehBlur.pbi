; ===== Véritable Bokeh Blur Polygonal =====
; Remplit complètement la forme polygonale, pas juste les sommets

Procedure PolygonBokeh_PrecomputeKernel(*param.parametre)
  Protected radius = *param\option[0]
  Protected sides = *param\option[1]
  Protected lg = *param\lg
  
  If radius < 1 : radius = 1 : EndIf
  If sides < 3 : sides = 3 : EndIf
  
  Protected dx, dy, k = 0
  Protected angle.d, nextAngle.d
  Protected x.d, y.d
  Protected dist.d
  Protected inside
  Protected maxcells = (2 * radius + 1) * (2 * radius + 1)
  Protected twoPI.d = 2.0 * #PI
  Protected invSides.d = 1.0 / sides
  
  ; Pré-calculer les sommets du polygone
  Dim vertices.d(sides * 2 - 1)
  Protected i, j
  For i = 0 To sides - 1
    angle = twoPI * i * invSides - #PI / 2.0  ; Commence en haut
    vertices(i * 2) = Cos(angle)
    vertices(i * 2 + 1) = Sin(angle)
  Next
  
  *param\option[5] = 0  ; Compteur de pixels dans le kernel
  
  ; Parcourir tous les pixels dans le carré englobant
  For dy = -radius To radius
    For dx = -radius To radius
      x = dx
      y = dy
      dist = Sqr(x * x + y * y)
      
      ; Test si le point est dans le cercle circonscrit
      If dist > radius
        Continue
      EndIf
      
      ; Test si le point est dans le polygone (algorithme du rayon - ray casting)
      inside = 0
      For i = 0 To sides - 1
        j = (i + 1) % sides
        
        Protected vx1.d = vertices(i * 2) * radius
        Protected vy1.d = vertices(i * 2 + 1) * radius
        Protected vx2.d = vertices(j * 2) * radius
        Protected vy2.d = vertices(j * 2 + 1) * radius
        
        ; Test de croisement du rayon avec l'arête
        Protected cond1 = 0, cond2 = 0
        
        If vy1 > y : cond1 = 1 : EndIf
        If vy2 > y : cond2 = 1 : EndIf
        
        ; Si les deux points sont du même côté, pas de croisement
        If cond1 <> cond2
          ; Calcul du point d'intersection X
          Protected intersectX.d = (vx2 - vx1) * (y - vy1) / (vy2 - vy1) + vx1
          If x < intersectX
            inside ! 1  ; Toggle (XOR)
          EndIf
        EndIf
      Next
      
      If inside
        ; Stocker l'offset
        PokeL(*param\addr[2] + k * 4, dy * lg + dx)
        
        ; Poids gaussien en fonction de la distance
        Protected weight.d = Exp(-(dist * dist) / (radius * radius * 0.5))
        PokeD(*param\addr[3] + k * 8, weight)
        
        k + 1
      EndIf
    Next
  Next
  
  *param\option[5] = k
  
  FreeArray(vertices())
EndProcedure


Procedure PolygonBokehBlur_MT(*param.parametre)
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
      
      ; Parcourir tous les pixels du kernel pré-calculé
      For k = 0 To kernelCount - 1
        ipos = pos + PeekL(*param\addr[2] + k * 4)
        If ipos < 0 Or ipos >= wcount : Continue : EndIf
        
        *src32 = *param\addr[0] + (ipos << 2)
        GetARGB(*src32\l, a0, r0, g0, b0)
        
        weight = PeekD(*param\addr[3] + k * 8)
        If weight <= 0.0 : Continue : EndIf
        
        ; Highlight boost (simule les zones lumineuses)
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
        ; Copie du pixel source si aucun poids
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


Procedure PolygonBokehBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Optical
    *param\name = "Polygonal Bokeh Blur"
    *param\remarque = "Véritable flou bokeh avec forme polygonale remplie"
    *param\info[0] = "Rayon"
    *param\info[1] = "Nombre de côtés"
    *param\info[2] = "Highlight boost (0..100)"
    *param\info[3] = "Masque"
    *param\info_data(0, 0) = 1   : *param\info_data(0, 1) = 50  : *param\info_data(0, 2) = 10
    *param\info_data(1, 0) = 3   : *param\info_data(1, 1) = 12  : *param\info_data(1, 2) = 6
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 200 : *param\info_data(2, 2) = 20
    *param\info_data(3, 0) = 0   : *param\info_data(3, 1) = 2   : *param\info_data(3, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Validation des paramètres
  If *param\option[0] < 1 : *param\option[0] = 1 : EndIf
  If *param\option[0] > 50 : *param\option[0] = 50 : EndIf
  If *param\option[1] < 3 : *param\option[1] = 3 : EndIf
  If *param\option[1] > 12 : *param\option[1] = 12 : EndIf
  If *param\option[2] < 0 : *param\option[2] = 0 : EndIf
  If *param\option[2] > 200 : *param\option[2] = 200 : EndIf
  
  Protected radius = *param\option[0]
  Protected maxcells = (2 * radius + 1) * (2 * radius + 1)
  
  ; Allocation des buffers
  *param\addr[2] = AllocateMemory(maxcells * 4)  ; Offsets
  *param\addr[3] = AllocateMemory(maxcells * 8)  ; Weights (Double)
  
  If *param\addr[2] = 0 Or *param\addr[3] = 0
    If *param\addr[2] : FreeMemory(*param\addr[2]) : EndIf
    If *param\addr[3] : FreeMemory(*param\addr[3]) : EndIf
    ProcedureReturn
  EndIf
  
  ; Précomputation du kernel polygonal
  PolygonBokeh_PrecomputeKernel(*param)
  
  ; Application du filtre
  If Filter_BufferPrepare(*param) <> 0
    MultiThread_MT(@PolygonBokehBlur_MT())
    macro_Filter_BufferFinalize(3)
  EndIf
  
  ; Libération de la mémoire
  FreeMemory(*param\addr[2])
  FreeMemory(*param\addr[3])
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 207
; FirstLine = 138
; Folding = -
; EnableXP
; DPIAware