; Macro pour récupérer le facteur de flou (0.0 à 1.0) selon l'angle et la position
Macro GetTiltShiftFactor(x_pos, y_pos, blurFactorOut)
  Protected yRel.f = (y_pos - centerY) / ht
  Protected xRel.f = (x_pos - lg * 0.5) / lg
  Protected yRot.f = yRel * cosA - xRel * sinA
  Protected dist.f = Abs(yRot - (focusPos - 0.5))
  
  If dist < focusWidth * 0.5
    blurFactorOut = 0.0
  Else
    blurFactorOut = (dist - focusWidth * 0.5) / (0.5 - focusWidth * 0.5)
    If blurFactorOut > 1.0 : blurFactorOut = 1.0 : EndIf
  EndIf
EndMacro

; ============================================================================
; PASSE 1 : Flou Horizontal à Rayon Variable (*src -> *tmp)
; ============================================================================
Procedure TiltShift_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected focusPos.f   = \option[0] / 100.0
    Protected focusWidth.f = \option[1] / 100.0
    Protected blurRadius   = \option[2]
    Protected angle.f      = \option[3] * #PI / 180.0
    
    Protected cosA.f = Cos(angle), sinA.f = Sin(angle)
    Protected centerY.f = ht * 0.5
    
    Protected x, y, dx, px, value, effRad
    Protected r, g, b, a, sumR, sumG, sumB, sumA, count
    Protected blurFactor.f, y_offset.i
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      y_offset = y * lg
      For x = 0 To lg - 1
        GetTiltShiftFactor(x, y, blurFactor)
        effRad = Int(blurRadius * blurFactor)
        
        If effRad <= 0
          *tmp\l[y_offset + x] = *src\l[y_offset + x]
        Else
          sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0 : count = 0
          
          For dx = -effRad To effRad
            px = x + dx
            If px < 0 Or px >= lg : Continue : EndIf
            
            getargb(*src\l[y_offset + px], a, r, g, b)
            sumA + a : sumR + r : sumG + g : sumB + b
            count + 1
          Next
          
          If count > 0
            a = sumA / count : r = sumR / count : g = sumG / count : b = sumB / count
            *tmp\l[y_offset + x] = (a << 24) | (r << 16) | (g << 8) | b
          Else
            *tmp\l[y_offset + x] = *src\l[y_offset + x]
          EndIf
        EndIf
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PASSE 2 : Flou Vertical à Rayon Variable (*tmp -> *dst)
; ============================================================================
Procedure TiltShift_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected focusPos.f   = \option[0] / 100.0
    Protected focusWidth.f = \option[1] / 100.0
    Protected blurRadius   = \option[2]
    Protected angle.f      = \option[3] * #PI / 180.0
    
    Protected cosA.f = Cos(angle), sinA.f = Sin(angle)
    Protected centerY.f = ht * 0.5
    
    Protected x, y, dy, py, value, effRad
    Protected r, g, b, a, sumR, sumG, sumB, sumA, count
    Protected blurFactor.f
    
    Protected *tmp.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        GetTiltShiftFactor(x, y, blurFactor)
        effRad = Int(blurRadius * blurFactor)
        
        If effRad <= 0
          *dst\l[y * lg + x] = *tmp\l[y * lg + x]
        Else
          sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0 : count = 0
          
          For dy = -effRad To effRad
            py = y + dy
            If py < 0 Or py >= ht : Continue : EndIf
            
            getargb(*tmp\l[py * lg + x], a, r, g, b)
            sumA + a : sumR + r : sumG + g : sumB + b
            count + 1
          Next
          
          If count > 0
            a = sumA / count : r = sumR / count : g = sumG / count : b = sumB / count
            *dst\l[y * lg + x] = (a << 24) | (r << 16) | (g << 8) | b
          Else
            *dst\l[y * lg + x] = *tmp\l[y * lg + x]
          EndIf
        EndIf
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; EXÉCUTION DU FILTRE
; ============================================================================
Procedure TiltShiftEx(*FilterCtx.FilterParams)
  Restore TiltShift_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Application des Clamps d'origine
    If \option[0] < 0 : \option[0] = 0 : ElseIf \option[0] > 100 : \option[0] = 100 : EndIf
    If \option[1] < 0 : \option[1] = 0 : ElseIf \option[1] > 100 : \option[1] = 100 : EndIf
    If \option[2] < 1 : \option[2] = 1 : ElseIf \option[2] > 20  : \option[2] = 20  : EndIf
    If \option[3] < 0 : \option[3] = 0 : ElseIf \option[3] > 360 : \option[3] = 360 : EndIf
    
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation du tampon temporaire \addr[2]
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@TiltShift_H_MT())
      Create_MultiThread_MT(@TiltShift_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure TiltShift(source, cible, mask, pos_focus, largeur_focus, rayon, angle)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = pos_focus
    \option[1] = largeur_focus
    \option[2] = rayon
    \option[3] = angle
  EndWith
  TiltShiftEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  TiltShift_data:
  Data.s "TiltShift"
  Data.s "Effet miniature / Tilt-Shift"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Position focus (%)"
  Data.i 0, 100, 50
  Data.s "Largeur focus (%)"
  Data.i 0, 100, 20
  Data.s "Rayon flou"
  Data.i 1, 20, 5
  Data.s "Angle (°)"
  Data.i 0, 360, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 154
; FirstLine = 128
; Folding = -
; EnableXP
; DPIAware