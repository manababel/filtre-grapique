;==============================================================================
; FLOWLIQUIFY - FILTRE DE DÉFORMATION FLUIDE (STRUCTURE RÉVISÉE)
;==============================================================================

Structure PerlinGradients
  x.f[16]
  y.f[16]
EndStructure

Procedure NormalizeVector(*x.Float, *y.Float)
  Protected len.f = Sqr(*x\f * *x\f + *y\f * *y\f)
  If len <> 0
    *x\f = *x\f / len
    *y\f = *y\f / len
  EndIf
EndProcedure

Procedure SetupPerlinGradients(*grad.PerlinGradients, mode)
  Protected i
  Select mode
    Case 0 ; Classique 8
      *grad\x[0] = 1 : *grad\y[0] = 0 : *grad\x[1] = -1 : *grad\y[1] = 0
      *grad\x[2] = 0 : *grad\y[2] = 1 : *grad\x[3] = 0  : *grad\y[3] = -1
      *grad\x[4] = 1 : *grad\y[4] = 1 : *grad\x[5] = -1 : *grad\y[5] = 1
      *grad\x[6] = 1 : *grad\y[6] = -1: *grad\x[7] = -1 : *grad\y[7] = -1
    Case 1 ; 16 Radiales
      For i = 0 To 15
        *grad\x[i] = Cos(i * 2.0 * #PI / 16)
        *grad\y[i] = Sin(i * 2.0 * #PI / 16)
      Next
    Case 2 ; Verticales
      *grad\x[0] = 0 : *grad\y[0] = 1 : *grad\x[1] = 0 : *grad\y[1] = -1
      *grad\x[2] = 0.3 : *grad\y[2] = 1 : *grad\x[3] = -0.3: *grad\y[3] = 1
    Case 3 ; Croix
      *grad\x[0] = 1 : *grad\y[0] = 0 : *grad\x[1] = -1 : *grad\y[1] = 0
      *grad\x[2] = 0 : *grad\y[2] = 1 : *grad\x[3] = 0  : *grad\y[3] = -1
    Case 4 ; Diagonales
      *grad\x[0] = 1 : *grad\y[0] = 1 : *grad\x[1] = -1 : *grad\y[1] = 1
      *grad\x[2] = 1 : *grad\y[2] = -1: *grad\x[3] = -1 : *grad\y[3] = -1
    Case 5 ; Aléatoire
      For i = 0 To 15
        *grad\x[i] = Random(200) / 100.0 - 1.0
        *grad\y[i] = Random(200) / 100.0 - 1.0
        NormalizeVector(@*grad\x[i], @*grad\y[i])
      Next
  EndSelect
EndProcedure

Procedure.f PerlinFade(t.f)
  ProcedureReturn t * t * t * (t * (t * 6 - 15) + 10)
EndProcedure

Procedure.f Lerp(a.f, b.f, t.f)
  ProcedureReturn a + t * (b - a)
EndProcedure

Procedure.f DotGridGradient(*grad.PerlinGradients, ix, iy, x.f, y.f)
  Protected gradientIndex = ((ix * 1836311903) ! (iy * 2971215073)) & 7
  Protected gx.f = *grad\x[gradientIndex]
  Protected gy.f = *grad\y[gradientIndex]
  Protected dx.f = x - ix
  Protected dy.f = y - iy
  ProcedureReturn (dx * gx + dy * gy)
EndProcedure

Procedure.f PerlinNoise2D(*grad.PerlinGradients, x.f, y.f)
  Protected x0 = Int(x), x1 = x0 + 1
  Protected y0 = Int(y), y1 = y0 + 1
  Protected sx.f = PerlinFade(x - x0)
  Protected sy.f = PerlinFade(y - y0)
  Protected n0.f = DotGridGradient(*grad, x0, y0, x, y)
  Protected n1.f = DotGridGradient(*grad, x1, y0, x, y)
  Protected n2.f = DotGridGradient(*grad, x0, y1, x, y)
  Protected n3.f = DotGridGradient(*grad, x1, y1, x, y)
  Protected ix0.f = Lerp(n0, n1, sx)
  Protected ix1.f = Lerp(n2, n3, sx)
  ProcedureReturn Lerp(ix0, ix1, sy) * 0.5 + 0.5
EndProcedure

Procedure BilinearSample(*src, lg, ht, x.f, y.f)
  Protected x0 = Int(x), y0 = Int(y)
  Protected x1 = x0 + 1, y1 = y0 + 1
  If x1 >= lg : x1 = lg - 1 : EndIf
  If y1 >= ht : y1 = ht - 1 : EndIf
  Protected dx.f = x - x0, dy.f = y - y0
  Protected c00 = PeekL(*src + ((y0 * lg + x0) << 2))
  Protected c10 = PeekL(*src + ((y0 * lg + x1) << 2))
  Protected c01 = PeekL(*src + ((y1 * lg + x0) << 2))
  Protected c11 = PeekL(*src + ((y1 * lg + x1) << 2))
  Protected a00 = (c00 >> 24) & $FF, r00 = (c00 >> 16) & $FF, g00 = (c00 >> 8) & $FF, b00 = c00 & $FF
  Protected a10 = (c10 >> 24) & $FF, r10 = (c10 >> 16) & $FF, g10 = (c10 >> 8) & $FF, b10 = c10 & $FF
  Protected a01 = (c01 >> 24) & $FF, r01 = (c01 >> 16) & $FF, g01 = (c01 >> 8) & $FF, b01 = c01 & $FF
  Protected a11 = (c11 >> 24) & $FF, r11 = (c11 >> 16) & $FF, g11 = (c11 >> 8) & $FF, b11 = c11 & $FF
  Protected w00.f = (1 - dx) * (1 - dy), w10.f = dx * (1 - dy), w01.f = (1 - dx) * dy, w11.f = dx * dy
  Protected a = a00 * w00 + a10 * w10 + a01 * w01 + a11 * w11
  Protected r = r00 * w00 + r10 * w10 + r01 * w01 + r11 * w11
  Protected g = g00 * w00 + g10 * w10 + g01 * w01 + g11 * w11
  Protected b = b00 * w00 + b10 * w10 + b01 * w01 + b11 * w11
  ProcedureReturn (Int(a) << 24) | (Int(r) << 16) | (Int(g) << 8) | Int(b)
EndProcedure

Procedure FlowLiquify_MT(*p.FilterParams)
  With *p
    Protected *src = \addr[0], *dst = \addr[1]
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected intensity.f = \option[0]
    Protected scale.f = \option[1] / 1000.0
    Protected gradMode = \option[2]
    Protected grad.PerlinGradients
    SetupPerlinGradients(@grad, gradMode)
    
    Protected startY = (\thread_pos * ht) / \thread_max
    Protected stopY  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf
    
    Protected x, y, srcX.f, srcY.f, angle.f, vx.f, vy.f
    For y = startY To stopY
      For x = 0 To lg - 1
        angle = PerlinNoise2D(@grad, x * scale, y * scale) * 2.0 * #PI
        vx = Cos(angle) * intensity
        vy = Sin(angle) * intensity
        srcX = x + vx : srcY = y + vy
        If srcX < 0 : srcX = 0 : ElseIf srcX > lg - 1 : srcX = lg - 1 : EndIf
        If srcY < 0 : srcY = 0 : ElseIf srcY > ht - 1 : srcY = ht - 1 : EndIf
        PokeL(*dst + ((y * lg + x) << 2), BilinearSample(*src, lg, ht, srcX, srcY))
      Next
    Next
  EndWith
EndProcedure

Procedure FlowLiquifyEx(*FilterCtx.FilterParams)
  Restore FlowLiquify_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  With *FilterCtx
    Create_MultiThread_MT(@FlowLiquify_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure FlowLiquify(source, cible, mask, intensite=5, echelle=10, mode=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensite
    \option[1] = echelle
    \option[2] = mode
  EndWith
  FlowLiquifyEx(FilterCtx)
EndProcedure

DataSection
  FlowLiquify_Data:
  Data.s "FlowLiquify"
  Data.s "Effet de déformation fluide/liquide avec bruit de Perlin 2D"
  Data.i #FilterType_Artistic, #Artistic_Other
  Data.s "Intensité" : Data.i 0, 50, 5
  Data.s "Échelle bruit" : Data.i 0, 100, 10
  Data.s "Mode gradients (0-5)" : Data.i 0, 5, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 140
; FirstLine = 110
; Folding = --
; EnableXP
; DPIAware