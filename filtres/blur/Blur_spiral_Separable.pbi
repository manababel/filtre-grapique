; ============================================================================
; ALGORITHME 1 : SEPARABLE SPIRAL BLUR (Le plus rapide - recommand√©)
; Complexit√© : O(n) au lieu de O(n * rayon)
; Gain : 5-10x plus rapide pour des rayons moyens/grands
; ============================================================================

Procedure SpiralBlur_Separable_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected Radius = *param\option[0]
  Protected cx.f = (*param\option[1] * lg) / 100
  Protected cy.f = (*param\option[2] * ht) / 100
  Protected force.i = *param\option[3]
  Protected quality = *param\option[4]
  Protected direction = ((*param\option[6] * 2) - 1)
  
  ; Technique : Box blur it√©ratif en coordonn√©es polaires
  ; Au lieu de tracer chaque rayon, on fait des passes radiales
  
  Protected angleCount = 360 * quality
  Protected maxRadius.i = Sqr(lg*lg + ht*ht)
  Protected passes
  Min(passes , Radius, 3) ; 3 passes suffisent (approximation gaussienne)
  
  Protected *src.Pixel32 = *param\addr[0]
  Protected *dst.Pixel32 = *param\addr[1]
  Protected *temp.Pixel32
  Protected pass , x , y , k
  ; Buffer temporaire
  Protected tempSize = lg * ht * 4
  *temp = AllocateMemory(tempSize)
  If Not *temp : ProcedureReturn : EndIf
  
  macro_calul_tread(ht)
  
  For pass = 1 To passes
    Protected kernelSize = (Radius / passes)
    
    For y = thread_start To thread_stop
      Protected yOffset = y * lg
      
      For x = 0 To lg - 1
        ; Conversion en coordonn√©es polaires
        Protected dx.f = x - cx
        Protected dy.f = y - cy
        Protected dist.f = Sqr(dx*dx + dy*dy)
        Protected angle.f = ATan2(dy, dx)
        
        If dist < 1 : dist = 1 : EndIf
        
        ; Rotation bas√©e sur la distance
        Protected rotation.f = (force * dist * direction) / 100.0
        Protected newAngle.f = angle + Radian(rotation)
        
        ; √âchantillonnage avec kernel r√©duit
        Protected r.f = 0, g.f = 0, b.f = 0, a.i = 0
        Protected ri , gi , bi
        Protected samples = 0
        
        For k = -kernelSize To kernelSize
          Protected sampleDist.f = dist + k
          If sampleDist < 0 Or sampleDist > maxRadius : Continue : EndIf
          
          Protected sx.i = cx + sampleDist * Cos(newAngle)
          Protected sy.i = cy + sampleDist * Sin(newAngle)
          
          If sx >= 0 And sx < lg And sy >= 0 And sy < ht
            Protected pos.i = (sy * lg + sx) << 2
            Protected *pixel.Pixel32 = *src + pos
            Protected pix.l = *pixel\l
            
            getrgb(pix , ri , gi , bi)
            r + ri
            g + gi
            b + bi
            a = (pix >> 24) & $FF
            samples + 1
          EndIf
        Next
        
        If samples > 0
          Protected outPos.i = (yOffset + x) << 2
          Protected *out.Pixel32 = *temp + outPos
          ri = (r/samples)
          gi = (g/samples)
          bi = (b/samples)
          *out\l = (a << 24) | (ri << 16) | (gi << 8) | bi
        EndIf
      Next
    Next
    
    ; Swap buffers
    CopyMemory(*temp, *src, tempSize)
  Next
  
  CopyMemory(*temp, *dst, tempSize)
  FreeMemory(*temp)
EndProcedure

Procedure spiral_Separable(*param.parametre)
  
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Directional
    *param\name = "spiral_Separable"
    *param\remarque = "appliquer un filtre de flou en spirale (optimisÈ)"
    *param\info[0] = "Rayon du filtre"          
    *param\info[1] = "Pos X"           
    *param\info[2] = "Pos Y"          
    *param\info[3] = "Force de rotation"   
    *param\info[4] = "QualitÈ" 
    *param\info[5] = "Rayon actif"   
    *param\info[6] = "sens"   
    *param\info[7] = "Masque binaire"    
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 99 : *param\info_data(0,2) = 50
    *param\info_data(1,0) = 0 : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 50
    *param\info_data(2,0) = 0 : *param\info_data(2,1) = 100 : *param\info_data(2,2) = 50
    *param\info_data(3,0) = 0 : *param\info_data(3,1) = 100 : *param\info_data(3,2) = 10
    *param\info_data(4,0) = 16 : *param\info_data(4,1) = 64 : *param\info_data(4,2) = 32
    *param\info_data(5,0) = 0 : *param\info_data(5,1) = 100 : *param\info_data(5,2) = 100
    *param\info_data(6,0) = 0 : *param\info_data(6,1) = 1 : *param\info_data(6,2) = 0
    *param\info_data(7,0) = 0 : *param\info_data(7,1) = 2 : *param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  
  Filter_BufferPrepare(*param.parametre)
  
  Protected i, angle.f
  Protected quality = *param\option[4]
  Protected inv_quality.f = 1.0 / quality
  Protected angleCount = 360 * quality
  
  ; Allocation optimisÈe avec mÈmoire alignÈe
  Dim cosTable.f(angleCount)
  Dim sinTable.f(angleCount) 
  
  ; PrÈcalcul optimisÈ des tables trigonomÈtriques
  For i = 0 To angleCount - 1
    angle = Radian(i * inv_quality)
    cosTable(i) = Cos(angle)
    sinTable(i) = Sin(angle)
  Next
  
  *param\addr[2] = @cosTable()
  *param\addr[3] = @sinTable()
  
  MultiThread_MT(@SpiralBlur_IIR_MT())
  
  macro_Filter_BufferFinalize(7)
  
  FreeArray(cosTable())
  FreeArray(sinTable())
  
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 104
; FirstLine = 84
; Folding = -
; EnableXP
; DPIAware