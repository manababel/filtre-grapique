; ============================================================================
; Filtre Beucher Gradient - Gradient morphologique de Beucher
; ============================================================================

Procedure.i Beucher_Dilate(*values.Long, *mask.Long, size)
  Protected i, maxVal = 0
  For i = 0 To size - 1
    If *mask\l = 1 And *values\l > maxVal : maxVal = *values\l : EndIf
    *values + 4 : *mask + 4
  Next
  ProcedureReturn maxVal
EndProcedure

Procedure.i Beucher_Erode(*values.Long, *mask.Long, size)
  Protected i, minVal = 255
  For i = 0 To size - 1
    If *mask\l = 1 And *values\l < minVal : minVal = *values\l : EndIf
    *values + 4 : *mask + 4
  Next
  ProcedureReturn minVal
EndProcedure

Procedure Beucher_DilateRGB(*r3.Long, *g3.Long, *b3.Long, *mask.Long, size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
  Protected i, maxR = 0, maxG = 0, maxB = 0
  For i = 0 To size - 1
    If *mask\l = 1
      If *r3\l > maxR : maxR = *r3\l : EndIf
      If *g3\l > maxG : maxG = *g3\l : EndIf
      If *b3\l > maxB : maxB = *b3\l : EndIf
    EndIf
    *r3 + 4 : *g3 + 4 : *b3 + 4 : *mask + 4
  Next
  *rOut\i = maxR : *gOut\i = maxG : *bOut\i = maxB
EndProcedure

Procedure Beucher_ErodeRGB(*r3.Long, *g3.Long, *b3.Long, *mask.Long, size, *rOut.Integer, *gOut.Integer, *bOut.Integer)
  Protected i, minR = 255, minG = 255, minB = 255
  For i = 0 To size - 1
    If *mask\l = 1
      If *r3\l < minR : minR = *r3\l : EndIf
      If *g3\l < minG : minG = *g3\l : EndIf
      If *b3\l < minB : minB = *b3\l : EndIf
    EndIf
    *r3 + 4 : *g3 + 4 : *b3 + 4 : *mask + 4
  Next
  *rOut\i = minR : *gOut\i = minG : *bOut\i = minB
EndProcedure

Procedure Beucher_CreateStructuringElement(*element.Long, shape, size)
  Protected x, y, center, radius.f, dist.f, distManhattan
  center = size >> 1 : radius = center
  For y = 0 To size - 1
    For x = 0 To size - 1
      Select shape
        Case 0 : *element\l = 1 ; Carré
        Case 1 : If x = center Or y = center : *element\l = 1 : Else : *element\l = 0 : EndIf ; Croix
        Case 2 : dist = Sqr((x - center) * (x - center) + (y - center) * (y - center))
                 If dist <= radius + 0.5 : *element\l = 1 : Else : *element\l = 0 : EndIf ; Disque
        Case 3 : distManhattan = Abs(x - center) + Abs(y - center)
                 If distManhattan <= center : *element\l = 1 : Else : *element\l = 0 : EndIf ; Diamant
        Case 4 : dist = Sqr((x - center) * (x - center) + (y - center) * (y - center))
                 distManhattan = Abs(x - center) + Abs(y - center)
                 If dist <= radius Or distManhattan <= center : *element\l = 1 : Else : *element\l = 0 : EndIf ; Octogone
      EndSelect
      *element + 4
    Next
  Next
EndProcedure

Procedure BeucherGradient_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.1 ; Adaptation du multiplicateur
    Protected kernelSize = \option[1]    
    Protected toGray = \option[2]
    Protected inverse = \option[3]
    Protected shape = \option[4]         
    
    Protected kSize
    Select kernelSize
      Case 0 : kSize = 3
      Case 1 : kSize = 5
      Case 2 : kSize = 7
      Default : kSize = 3
    EndSelect
    
    Protected kRadius = kSize >> 1
    Protected maxPixels = kSize * kSize
    
    ; Allocation dynamique de buffers temporaires par thread (évite les conflits et FreeArray)
    Protected *r3 = AllocateMemory(maxPixels * 4)
    Protected *g3 = AllocateMemory(maxPixels * 4)
    Protected *b3 = AllocateMemory(maxPixels * 4)
    Protected *gray = AllocateMemory(maxPixels * 4)
    Protected *structElement = AllocateMemory(maxPixels * 4)
    
    Beucher_CreateStructuringElement(*structElement, shape, kSize)
    
    Protected x, y, i, j, idx, pos
    Protected a, r, g, b
    Protected original, dilated, eroded, beucherGrad, magnitude.f
    Protected originalR, originalG, originalB, dilatedR, dilatedG, dilatedB, erodedR, erodedG, erodedB
    Protected beucherR, beucherG, beucherB
    
    Protected *src.Pixelarray32 = \addr[0]
    Protected *dst.Pixelarray32 = \addr[1]
    
    macro_calul_tread(ht)
    
    ; Gestion des bordures pour éviter de lire hors de l'image
    Protected y_start = thread_start
    Protected y_stop = thread_stop
    If y_start < kRadius : y_start = kRadius : EndIf
    If y_stop > ht - kRadius - 1 : y_stop = ht - kRadius - 1 : EndIf
    
    For y = y_start To y_stop
      For x = kRadius To lg - kRadius - 1
        
        idx = 0
        For j = -kRadius To kRadius
          For i = -kRadius To kRadius
            pos = ((y + j) * lg) + (x + i)
            getargb(*src\Pixel[pos], a, r, g, b)
            
            ; On stocke les valeurs dans nos buffers de voisinage via des pointeurs
            PokeL(*r3 + (idx * 4), r)
            PokeL(*g3 + (idx * 4), g)
            PokeL(*b3 + (idx * 4), b)
            PokeL(*gray + (idx * 4), (r * 77 + g * 150 + b * 29) >> 8)
            idx + 1
          Next
        Next
        
        pos = (y * lg) + x
        Protected centerIdx = maxPixels >> 1
        
        If toGray
          original = PeekL(*gray + (centerIdx * 4))
          dilated = Beucher_Dilate(*gray, *structElement, maxPixels)
          eroded = Beucher_Erode(*gray, *structElement, maxPixels)
          
          beucherGrad = ((dilated - original) + (original - eroded)) >> 1
          magnitude = beucherGrad * mul
          
          r = Int(magnitude) : g = r : b = r
        Else
          originalR = PeekL(*r3 + (centerIdx * 4))
          originalG = PeekL(*g3 + (centerIdx * 4))
          originalB = PeekL(*b3 + (centerIdx * 4))
          
          Beucher_DilateRGB(*r3, *g3, *b3, *structElement, maxPixels, @dilatedR, @dilatedG, @dilatedB)
          Beucher_ErodeRGB(*r3, *g3, *b3, *structElement, maxPixels, @erodedR, @erodedG, @erodedB)
          
          beucherR = ((dilatedR - originalR) + (originalR - erodedR)) >> 1
          beucherG = ((dilatedG - originalG) + (originalG - erodedG)) >> 1
          beucherB = ((dilatedB - originalB) + (originalB - erodedB)) >> 1
          
          r = Int(beucherR * mul)
          g = Int(beucherG * mul)
          b = Int(beucherB * mul)
        EndIf
        
        clamp_rgb(r, g, b)
        
        ; Traitements optionnels identiques au premier programme (Roberts)
        ; (Si vous avez une fonction seuil_rgb, décommentez-la)
        ; If seuillage > 0 : seuil_rgb(seuillage , r , g , b) : EndIf
        If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
        
        *dst\Pixel[pos] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
    
    ; Libération propre de la mémoire du thread
    FreeMemory(*r3) : FreeMemory(*g3) : FreeMemory(*b3) : FreeMemory(*gray) : FreeMemory(*structElement)
  EndWith
EndProcedure

Procedure BeucherGradientEx(*FilterCtx.FilterParams)
  Restore BeucherGradient_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Même logique de buffer temporaire In-Place que votre exemple Roberts
    Protected size = \image_lg[0] * \image_ht[0] * 4
    If \addr[1] = \addr[0]
      \addr[2] = AllocateMemory(size)
      If \addr[2]
        CopyMemory(\addr[0], \addr[2], size)
        \addr[0] = \addr[2]
        Create_MultiThread_MT(@BeucherGradient_MT())
        FreeMemory(\addr[2])
      EndIf
    Else
      Create_MultiThread_MT(@BeucherGradient_MT())
    EndIf
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure BeucherGradient(source, cible, mask, force, noyau, gris, inversion, forme)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = force
    \option[1] = noyau
    \option[2] = gris
    \option[3] = inversion
    \option[4] = forme
  EndWith
  BeucherGradientEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  BeucherGradient_data:
  Data.s "Beucher Gradient"
  Data.s "Gradient de Beucher : moyenne gradients interne/externe"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Morphological
  
  Data.s "Force du gradient"       
  Data.i 1, 100, 10
  Data.s "Taille noyau (0=3x3/1=5x5/2=7x7)"   
  Data.i 0, 2, 0
  Data.s "Noir et blanc"        
  Data.i 0, 1, 0
  Data.s "Inversion"  
  Data.i 0, 1, 0
  Data.s "Forme (0=Sq/1=Cr/2=Di/3=Dm/4=Oc)" 
  Data.i 0, 4, 0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 234
; FirstLine = 185
; Folding = --
; EnableXP
; DPIAware