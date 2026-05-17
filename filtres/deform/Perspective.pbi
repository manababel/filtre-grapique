; ==============================================================================
; FILTRE PERSPECTIVE (DÉFORMATION 4 COINS) - STRUCTURE RÉVISÉE
; ==============================================================================

; --- Fonctions utilitaires géométriques ---

Procedure.f Area2D(x1.f, y1.f, x2.f, y2.f, x3.f, y3.f)
  ProcedureReturn Abs((x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1)) / 2.0
EndProcedure

Procedure.b PointInQuad(x.f, y.f, Array pts.f(1))
  ; Quadrilatère : A(0,1) B(2,3) C(6,7) D(4,5)
  Protected A_x.f = pts(0), A_y.f = pts(1)
  Protected B_x.f = pts(2), B_y.f = pts(3)
  Protected C_x.f = pts(6), C_y.f = pts(7)
  Protected D_x.f = pts(4), D_y.f = pts(5)

  Protected areaQuad.f = Area2D(A_x, A_y, B_x, B_y, C_x, C_y) + Area2D(A_x, A_y, C_x, C_y, D_x, D_y)
  
  Protected areaSum.f = 0.0
  areaSum + Area2D(x, y, A_x, A_y, B_x, B_y)
  areaSum + Area2D(x, y, B_x, B_y, C_x, C_y)
  areaSum + Area2D(x, y, C_x, C_y, D_x, D_y)
  areaSum + Area2D(x, y, D_x, D_y, A_x, A_y)

  If Abs(areaQuad - areaSum) < 0.5
    ProcedureReturn #True
  Else
    ProcedureReturn #False
  EndIf
EndProcedure

; --- Procédure de calcul Multithread ---

Procedure Perspective_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i
    Protected sx.f, sy.f, u.f, v.f
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    Protected inv_lg.f = 1.0 / lg
    Protected inv_ht.f = 1.0 / ht
    Protected deltaX.f = lg / 2.0
    Protected deltaY.f = ht / 2.0

    ; Calcul des positions des 4 coins destination (option[0..7])
    Protected x00.f = deltaX * ((\option[0] - 50.0) / 50.0) + 0.0    ; HG X
    Protected y00.f = deltaY * ((\option[1] - 50.0) / 50.0) + 0.0    ; HG Y
    Protected x10.f = deltaX * ((\option[2] - 50.0) / 50.0) + lg     ; HD X
    Protected y10.f = deltaY * ((\option[3] - 50.0) / 50.0) + 0.0    ; HD Y
    Protected x01.f = deltaX * ((\option[4] - 50.0) / 50.0) + 0.0    ; BG X
    Protected y01.f = deltaY * ((\option[5] - 50.0) / 50.0) + ht     ; BG Y
    Protected x11.f = deltaX * ((\option[6] - 50.0) / 50.0) + lg     ; BD X
    Protected y11.f = deltaY * ((\option[7] - 50.0) / 50.0) + ht     ; BD Y

    ; --- Configuration Multithreading (macro_calcul_thread) ---
    Protected startY.i = (\thread_pos * ht) / \thread_max
    Protected stopY.i  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    Protected coef_1mu_1mv.f, coef_u_1mv.f, coef_1mu_v.f, coef_u_v.f
    Protected mu.f, mv.f
    Protected offset_dst.i, offset_src.i
    Protected sx_int.i, sy_int.i

    ; --- Traitement principal ---
    For y = startY To stopY
      v = y * inv_ht
      mv = 1.0 - v
      offset_dst = y * lg * 4
      
      For x = 0 To lg - 1
        u = x * inv_lg
        mu = 1.0 - u

        ; Interpolation bilinéaire des coordonnées source
        coef_1mu_1mv = mu * mv
        coef_u_1mv   = u * mv
        coef_1mu_v   = mu * v
        coef_u_v     = u * v
        
        sx = coef_1mu_1mv * x00 + coef_u_1mv * x10 + coef_1mu_v * x01 + coef_u_v * x11
        sy = coef_1mu_1mv * y00 + coef_u_1mv * y10 + coef_1mu_v * y01 + coef_u_v * y11

        sx_int = Int(sx)
        sy_int = Int(sy)
        
        If sx_int >= 0 And sx_int < lg And sy_int >= 0 And sy_int < ht
          offset_src = (sy_int * lg + sx_int) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $FF000000) ; Noir opaque (fond)
        EndIf
        
        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure PerspectiveEx(*FilterCtx.FilterParams)
  Restore Perspective_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Perspective_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Perspective(source, cible, mask, xHG=50, yHG=50, xHD=50, yHD=50, xBG=50, yBG=50, xBD=50, yBD=50)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0]=xHG : \option[1]=yHG : \option[2]=xHD : \option[3]=yHD
    \option[4]=xBG : \option[5]=yBG : \option[6]=xBD : \option[7]=yBD
  EndWith
  PerspectiveEx(FilterCtx)
EndProcedure

DataSection
  Perspective_Data:
  Data.s "Perspective"
  Data.s "Déplace les 4 coins pour créer un effet de perspective ou trapèze"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "HG X (%)" : Data.i 0, 100, 50
  Data.s "HG Y (%)" : Data.i 0, 100, 50
  Data.s "HD X (%)" : Data.i 0, 100, 50
  Data.s "HD Y (%)" : Data.i 0, 100, 50
  Data.s "BG X (%)" : Data.i 0, 100, 50
  Data.s "BG Y (%)" : Data.i 0, 100, 50
  Data.s "BD X (%)" : Data.i 0, 100, 50
  Data.s "BD Y (%)" : Data.i 0, 100, 50
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 114
; FirstLine = 88
; Folding = -
; EnableXP
; DPIAware