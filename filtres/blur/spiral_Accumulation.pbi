; ============================================================================
; ALGORITHME 2 : ACCUMULATION BUFFER (Meilleur qualit√©/vitesse)
; Technique : Accumulation par passes angulaires avec downsampling
; Gain : 3-5x plus rapide, excellente qualit√©
; ============================================================================

Procedure SpiralBlur_Accumulation_MT(*FilterCtx.FilterParams)
  With *FilterCtx
  Protected lg = \image_lg[0]
  Protected ht = \image_ht[0]
  Protected Radius = \option[0]
  Protected cx.f = (\option[1] * lg) / 100
  Protected cy.f = (\option[2] * ht) / 100
  Protected force.i = \option[3]
  Protected quality = \option[4]
  
  ; Downsampling adaptatif selon le rayon
  Protected sampleStep = 1
  If Radius > 50 : sampleStep = 2 : EndIf
  If Radius > 100 : sampleStep = 4 : EndIf
  
  Protected angleCount = 360 * quality
  Protected angleStep
  Max(angleStep , 1, angleCount / 32) ; Seulement 32 angles au lieu de 360*quality
  
  Protected *source.Pixelarray = \addr[0]
  Protected angleIdx , dist , tt , rx , ry , i
  Protected.l a , r , g , b
  ; Buffers d'accumulation (√©vite les allocations r√©p√©t√©es)
  Protected *accumR.pixelArray     = \addr[4]
  Protected *accumG.pixelArray     = \addr[5]
  Protected *accumB.pixelArray     = \addr[6]
  Protected *accumA.pixelArray     = \addr[7]
  Protected *accumCount.pixelArray = \addr[8]
  
  macro_calul_tread(angleCount / angleStep)
  
  For angleIdx = thread_start To thread_stop - 1
    Protected angle.f = Radian((angleIdx * angleStep) / quality)
    Protected cosA.f = Cos(angle)
    Protected sinA.f = Sin(angle)
    
    tt = Sqr(lg*lg + ht*ht)
    dist = 0
    While dist <= tt
      ;For dist = 0 To Sqr(lg*lg + ht*ht) Step sampleStep
      ; Rotation progressive
      Protected rotation.f = (force * dist) / 100.0
      Protected rotAngle.f = angle + Radian(rotation)
      
      Protected x.i = cx + dist * Cos(rotAngle)
      Protected y.i = cy + dist * Sin(rotAngle)
      
      If x >= 0 And x < lg And y >= 0 And y < ht
        
        getargb(*source\l[y * lg + x]  , a, r , g , b)
        
        ; Accumuler dans un rayon autour du point
        ry = - Radius
        While ry <= Radius
          rx  =- Radius
          While rx <= Radius
            Protected tx.i = x + rx
            Protected ty.i = y + ry
            
            If tx >= 0 And tx < lg And ty >= 0 And ty < ht
              Protected distSq.i = rx*rx + ry*ry
              If distSq <= Radius * Radius
                Protected dstIdx.i = ty * lg + tx
                
                *accumR\l[dstIdx] + r
                *accumG\l[dstIdx] + g
                *accumB\l[dstIdx] + b
                *accumA\l[dstIdx] + a
                *accumCount\l[dstIdx] + 1
              EndIf
            EndIf
            rx + sampleStep
          Wend
          
          ry + sampleStep
        Wend
      EndIf
     
      dist + sampleStep
    Wend
  Next
  
  EndWith
EndProcedure

Procedure spiral_AccumulationEx(*FilterCtx.FilterParams)
  Restore spiral_Accumulation_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected *source.Pixelarray = \addr[0]
    Protected *cible.Pixelarray  = \addr[1]
    Protected i, lg = \image_lg[0], ht = \image_ht[0]
    Protected imgSize = lg * ht
    Protected.l a, r, g, b, count
    
    ; Allocation des buffers d'accumulation (propres et sans Ècraser d'index)
    Protected err = 0
    For i = 4 To 8
      \addr[i] = AllocateMemory(imgSize * 4)
      If \addr[i] = 0 : err = 1 : EndIf
    Next
    
    If err = 0
      ; Lancement des threads
      Create_MultiThread_MT(@SpiralBlur_Accumulation_MT())
      
      ; Pointeurs pour une lecture simplifiÈe et ultra-rapide
      Protected *accR.Pixelarray = \addr[4]
      Protected *accG.Pixelarray = \addr[5]
      Protected *accB.Pixelarray = \addr[6]
      Protected *accA.Pixelarray = \addr[7]
      Protected *accCount.Pixelarray = \addr[8]
      
      ; --- Normalisation finale (Correction arithmÈtique et des dÈcalages) ---
      For i = 0 To imgSize - 1
        count = *accCount\l[i]
        If count > 0
          a = *accA\l[i] / count
          r = *accR\l[i] / count
          g = *accG\l[i] / count
          b = *accB\l[i] / count
          *cible\l[i] = (a << 24) | (r << 16) | (g << 8) | b
        Else
          *cible\l[i] = *source\l[i]
        EndIf
      Next
      
      mask_update(*FilterCtx.FilterParams , last_data)
    EndIf
    ; LibÈration propre de la mÈmoire
    For i = 4 To 8 
      If \addr[i] : FreeMemory(\addr[i]) : \addr[i] = 0 : EndIf 
    Next
  EndWith
EndProcedure

Procedure spiral_Accumulation(source , cible , mask , rayon , posx , posy , force , qualite , ra , sens)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = posx
    \option[2] = posy
    \option[3] = force
    \option[4] = qualite
    \option[5] = ra
    \option[6] = sens
  EndWith
  SpiralBlur_IIREx(FilterCtx.FilterParams)
EndProcedure

DataSection
  spiral_Accumulation_data:
  Data.s "spiral_Accumulation"
  Data.s "appliquer un filtre de flou en spirale (programme bugue)"
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Rayon du filtre"       
  Data.i 1,99,1
  Data.s "Pos X"   
  Data.i 0,100,50
  Data.s "Pos Y"        
  Data.i 0,100,50
  Data.s "Force de rotation"  
  Data.i 0,100,10
  Data.s "QualitÈ" 
  Data.i 16,64,32
  Data.s "Rayon actif"   
  Data.i 0,100,100
  Data.s "sens"  
  Data.i 0,1,0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 163
; FirstLine = 128
; Folding = -
; EnableXP
; DPIAware