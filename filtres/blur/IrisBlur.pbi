; Macro réutilisable pour calculer le facteur de flou (0.0 à 1.0) sans Sqr()
Macro GetIrisBlurFactor(x_pos, y_pos, blurFactorOut)
  Protected distX.f = x_pos - cx
  Protected distY.f = y_pos - cy
  Protected distSq.f = distX * distX + distY * distY
  
  If distSq <= innerSq
    blurFactorOut = 0.0
  ElseIf distSq >= outerSq
    blurFactorOut = 1.0
  Else
    ; Interpolation linéaire sur la distance
    Protected dist.f = Sqr(distSq)
    blurFactorOut = (dist - innerRadius) / (outerRadius - innerRadius)
  EndIf
EndMacro

; ============================================================================
; PASSE 1 : Flou Horizontal Iris (*src -> *tmp)
; ============================================================================
Procedure IrisBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected centerX.f = \option[0] / 100.0
    Protected centerY.f = \option[1] / 100.0
    Protected innerRadius.f = \option[2]
    Protected outerRadius.f = \option[3]
    Protected maxBlurRadius = \option[4]
    
    If innerRadius < 0 : innerRadius = 0 : EndIf
    If outerRadius <= innerRadius : outerRadius = innerRadius + 10 : EndIf
    If maxBlurRadius < 1 : maxBlurRadius = 1 : EndIf
    
    Protected cx.f = lg * centerX
    Protected cy.f = ht * centerY
    Protected innerSq.f = innerRadius * innerRadius
    Protected outerSq.f = outerRadius * outerRadius
    
    Protected x, y, dx, px, effRad, value
    Protected r, g, b, a, sumR, sumG, sumB, sumA, count
    Protected blurFactor.f, y_offset.i
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      y_offset = y * lg
      For x = 0 To lg - 1
        GetIrisBlurFactor(x, y, blurFactor)
        effRad = Int(maxBlurRadius * blurFactor)
        
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
; PASSE 2 : Flou Vertical Iris (*tmp -> *dst)
; ============================================================================
Procedure IrisBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected centerX.f = \option[0] / 100.0
    Protected centerY.f = \option[1] / 100.0
    Protected innerRadius.f = \option[2]
    Protected outerRadius.f = \option[3]
    Protected maxBlurRadius = \option[4]
    
    If innerRadius < 0 : innerRadius = 0 : EndIf
    If outerRadius <= innerRadius : outerRadius = innerRadius + 10 : EndIf
    If maxBlurRadius < 1 : maxBlurRadius = 1 : EndIf
    
    Protected cx.f = lg * centerX
    Protected cy.f = ht * centerY
    Protected innerSq.f = innerRadius * innerRadius
    Protected outerSq.f = outerRadius * outerRadius
    
    Protected x, y, dy, py, effRad, value
    Protected r, g, b, a, sumR, sumG, sumB, sumA, count
    Protected blurFactor.f
    
    Protected *tmp.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        GetIrisBlurFactor(x, y, blurFactor)
        effRad = Int(maxBlurRadius * blurFactor)
        
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
; LANCEUR PRINCIPAL
; ============================================================================
Procedure IrisBlurEx(*FilterCtx.FilterParams)
  Restore IrisBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Clamps d'origine
    If \option[0] < 0 : \option[0] = 0 : ElseIf \option[0] > 100 : \option[0] = 100 : EndIf
    If \option[1] < 0 : \option[1] = 0 : ElseIf \option[1] > 100 : \option[1] = 100 : EndIf
    If \option[2] < 0 : \option[2] = 0 : ElseIf \option[2] > 500 : \option[2] = 500 : EndIf
    If \option[3] < 0 : \option[3] = 0 : ElseIf \option[3] > 1000 : \option[3] = 1000 : EndIf
    If \option[4] < 1 : \option[4] = 1 : ElseIf \option[4] > 30 : \option[4] = 30 : EndIf
    
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation du tampon mémoire intermédiaire \addr[2]
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@IrisBlur_H_MT())
      Create_MultiThread_MT(@IrisBlur_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

Procedure IrisBlur(source, cible, mask, centreX, centreY, rayon_net, rayon_flou, intensite)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = centreX
    \option[1] = centreY
    \option[2] = rayon_net
    \option[3] = rayon_flou
    \option[4] = intensite
  EndWith
  IrisBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  IrisBlur_data:
  Data.s "IrisBlur"
  Data.s "Flou circulaire graduel (effet iris)"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Centre X (%)"
  Data.i 0, 100, 50
  Data.s "Centre Y (%)"
  Data.i 0, 100, 50
  Data.s "Rayon net"
  Data.i 0, 500, 100
  Data.s "Rayon flou"
  Data.i 0, 1000, 300
  Data.s "Intensité flou"
  Data.i 1, 30, 10
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 170
; FirstLine = 115
; Folding = -
; EnableXP
; DPIAware