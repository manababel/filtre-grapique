; ==============================================================================
; FILTRE PERSPECTIVE 4 BORDS (TRAPÈZE) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Perspective4Borders_MT(*p.FilterParams)
  With *p
    Protected startY.i, stopY.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]
    
    ; --- Précalcul des constantes ---
    Protected half_lg.f = lg / 2.0
    Protected half_ht.f = ht / 2.0
    Protected inv_lg.f = 1.0 / (lg - 1)
    Protected inv_ht.f = 1.0 / (ht - 1)
    
    ; Normalisation des paramètres
    Protected tiltTop.f    = (\option[0] - 100.0) / 100.0
    Protected tiltBottom.f = (\option[1] - 100.0) / 100.0
    Protected tiltLeft.f   = (\option[2] - 100.0) / 100.0
    Protected tiltRight.f  = (\option[3] - 100.0) / 100.0
    Protected scaleGlobal.f = \option[4] / 100.0
    Protected shiftX.f = ((\option[5] - 100.0) * lg) / 100.0
    Protected shiftY.f = ((\option[6] - 100.0) * ht) / 100.0
    Protected angle.f = Radian(\option[7])
    
    ; Trigonométrie précalculée
    Protected cosA.f = Cos(angle)
    Protected sinA.f = Sin(angle)
    
    ; Sécurités
    If scaleGlobal < 0.01 : scaleGlobal = 0.01 : EndIf
    
    Protected x.i, y.i
    Protected u.f, v.f
    Protected scaleX.f, scaleY.f
    Protected inv_scale.f
    Protected tmp_x.f, tmp_y.f
    Protected src_x.f, src_y.f
    Protected src_x_int.i, src_y_int.i
    Protected offset_dst.i, offset_src.i

    ; --- Configuration Multithreading ---
    startY = (\thread_pos * ht) / \thread_max
    stopY  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stopY > ht - 1 : stopY = ht - 1 : EndIf

    ; --- Traitement principal ---
    For y = startY To stopY
      v = y * inv_ht
      
      ; Interpolation horizontale (X) basée sur la position verticale (Y)
      scaleX = 1.0 - ((1.0 - v) * tiltTop + v * tiltBottom)
      If scaleX < 0.01 : scaleX = 0.01 : EndIf
      
      offset_dst = y * lg * 4
      
      For x = 0 To lg - 1
        u = x * inv_lg
        
        ; Interpolation verticale (Y) basée sur la position horizontale (X)
        scaleY = 1.0 - ((1.0 - u) * tiltLeft + u * tiltRight)
        If scaleY < 0.01 : scaleY = 0.01 : EndIf
        
        ; Facteur d'échelle combiné
        inv_scale = 1.0 / (scaleX * scaleY * scaleGlobal)
        
        ; Translation et Mise à l'échelle
        tmp_x = (x - half_lg) * inv_scale + shiftX
        tmp_y = (y - half_ht) * inv_scale + shiftY
        
        ; Rotation inverse autour du centre
        src_x = tmp_x * cosA - tmp_y * sinA + half_lg
        src_y = tmp_x * sinA + tmp_y * cosA + half_ht
        
        src_x_int = Int(src_x)
        src_y_int = Int(src_y)
        
        ; Échantillonnage avec gestion des bords
        If src_x_int >= 0 And src_x_int < lg And src_y_int >= 0 And src_y_int < ht
          offset_src = (src_y_int * lg + src_x_int) * 4
          PokeL(*cible + offset_dst, PeekL(*source + offset_src))
        Else
          PokeL(*cible + offset_dst, $00000000) ; Vide (Alpha 0)
        EndIf
        
        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure Perspective2Ex(*FilterCtx.FilterParams)
  Restore Perspective2_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Perspective4Borders_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Perspective2(source, cible, mask, top=100, bottom=100, left=100, right=100, zoom=100, posX=100, posY=100, rot=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = top    ; Inclinaison haut
    \option[1] = bottom ; Inclinaison bas
    \option[2] = left   ; Inclinaison gauche
    \option[3] = right  ; Inclinaison droite
    \option[4] = zoom   ; Zoom
    \option[5] = posX   ; Position X
    \option[6] = posY   ; Position Y
    \option[7] = rot    ; Rotation
  EndWith
  Perspective2Ex(FilterCtx)
EndProcedure

DataSection
  Perspective2_Data:
  Data.s "Perspective2"
  Data.s "Déformation trapèze indépendante sur 4 bords avec zoom et rotation"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "Inc. Haut (%)"   : Data.i 0, 200, 100
  Data.s "Inc. Bas (%)"    : Data.i 0, 200, 100
  Data.s "Inc. Gauche (%)" : Data.i 0, 200, 100
  Data.s "Inc. Droite (%)" : Data.i 0, 200, 100
  Data.s "Zoom global (%)" : Data.i 1, 200, 100
  Data.s "Position X (%)"  : Data.i 0, 200, 100
  Data.s "Position Y (%)"  : Data.i 0, 200, 100
  Data.s "Rotation (°)"    : Data.i 0, 360, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 105
; FirstLine = 85
; Folding = -
; EnableXP
; DPIAware