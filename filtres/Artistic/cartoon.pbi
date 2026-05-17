; ==============================================================================
; FILTRE CARTOON / TOON SHADING - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure cartoon_MT(*p.FilterParams)
  With *p
    ; --- Dimensions de l'image ---
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    
    ; --- Coordonnées ---
    Protected x, y
    
    ; --- Composantes ARGB ---
    Protected a, r, g, b
    Protected rC, gC, bC
    Protected r1, g1, b1, r2, g2, b2
    Protected r3, g3, b3, r4, g4, b4
    
    ; --- Détection de contours ---
    Protected.f gx, gy, edge
    
    ; --- Niveaux de gris ---
    Protected.f grayC, gray1, gray2, gray3, gray4
    
    ; --- Quantification ---
    Protected levels, qr, qg, qb
    
    ; --- Pointeurs mémoire ---
    Protected *src.Pixel32, *dst.Pixel32
    
    ; ============================================================================
    ; LECTURE ET VALIDATION DES PARAMÈTRES
    ; ============================================================================
    
    levels = \option[0]
    If levels < 2 : levels = 2 : ElseIf levels > 32 : levels = 32 : EndIf
    
    Protected.f edgeStrength = \option[1] * 0.01
    Protected.f edgeThreshold = \option[2] * 0.01
    
    Protected renderMode = \option[3]
    Protected edgeColor = \option[4]
    Protected smoothing = \option[5]
    
    ; ============================================================================
    ; PRÉCALCULS
    ; ============================================================================
    
    Protected.f stepSize = 255.0 / (levels - 1)
    Protected.f invStepSize = 1.0 / stepSize
    Protected.f smoothBlend = smoothing
    Protected.f invSmoothBlend = 1.0 - smoothBlend
    Protected.f invEdgeThreshold
    If edgeThreshold < 1.0
      invEdgeThreshold = 1.0 / (1.0 - edgeThreshold)
    Else
      invEdgeThreshold = 1.0
    EndIf
    
    ; ============================================================================
    ; CONFIGURATION MULTITHREADING
    ; ============================================================================
    
    Protected startY = (\thread_pos * h) / \thread_max
    Protected endY = ((\thread_pos + 1) * h) / \thread_max
    
    If startY < 1 : startY = 1 : EndIf
    If endY > h - 1 : endY = h - 1 : EndIf
    
    ; ============================================================================
    ; TRAITEMENT PRINCIPAL
    ; ============================================================================
    
    Protected wBytes = w << 2
    Protected offset.l
    
    For y = startY To endY - 1
      offset = y * wBytes
      
      For x = 1 To w - 2
        
        *src = \addr[0] + offset + (x << 2)
        GetARGB(*src\l, a, rC, gC, bC)
        
        *src - 4
        GetARGB(*src\l, a, r1, g1, b1)
        
        *src + 8
        GetARGB(*src\l, a, r2, g2, b2)
        
        *src = \addr[0] + offset - wBytes + (x << 2)
        GetARGB(*src\l, a, r3, g3, b3)
        
        *src = \addr[0] + offset + wBytes + (x << 2)
        GetARGB(*src\l, a, r4, g4, b4)
        
        RGBtoGrayF(grayC, rC, gC, bC)
        RGBtoGrayF(gray1, r1, g1, b1)
        RGBtoGrayF(gray2, r2, g2, b2)
        RGBtoGrayF(gray3, r3, g3, b3)
        RGBtoGrayF(gray4, r4, g4, b4)
        
        gx = (gray2 - gray1) * edgeStrength
        gy = (gray4 - gray3) * edgeStrength
        
        edge = Sqr(gx * gx + gy * gy)
        If edge < 0.0 : edge = 0.0 : ElseIf edge > 255.0 : edge = 255.0 : EndIf
        edge = edge / 255.0
        
        qr = Int(rC * invStepSize + 0.5) * stepSize
        qg = Int(gC * invStepSize + 0.5) * stepSize
        qb = Int(bC * invStepSize + 0.5) * stepSize
        
        If smoothing > 0
          qr = qr * invSmoothBlend + rC * smoothBlend
          qg = qg * invSmoothBlend + gC * smoothBlend
          qb = qb * invSmoothBlend + bC * smoothBlend
        EndIf
        
        Select renderMode
          Case 0 ; CARTOON COMPLET
            If edge > edgeThreshold
              Select edgeColor
                Case 0 : r = 0 : g = 0 : b = 0
                Case 1 : r = 255 : g = 255 : b = 255
                Case 2 : r = 255 - qr : g = 255 - qg : b = 255 - qb
              EndSelect
              
              Protected.f edgeMix = (edge - edgeThreshold) * invEdgeThreshold
              If edgeMix < 0.0 : edgeMix = 0.0 : ElseIf edgeMix > 1.0 : edgeMix = 1.0 : EndIf
              
              r = qr * (1.0 - edgeMix) + r * edgeMix
              g = qg * (1.0 - edgeMix) + g * edgeMix
              b = qb * (1.0 - edgeMix) + b * edgeMix
            Else
              r = qr : g = qg : b = qb
            EndIf
            
          Case 1 ; CONTOURS SEULS
            If edge > edgeThreshold
              Select edgeColor
                Case 0 : r = 0 : g = 0 : b = 0
                Case 1 : r = 255 : g = 255 : b = 255
                Case 2 : r = 255 - rC : g = 255 - gC : b = 255 - bC
              EndSelect
            Else
              r = 255 : g = 255 : b = 255
            EndIf
            
          Case 2 ; COULEURS SEULES
            r = qr : g = qg : b = qb
            
          Case 3 ; SKETCH
            Protected sketch = Int((1.0 - edge) * 255)
            r = sketch : g = sketch : b = sketch
        EndSelect
        
        If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
        
        *dst = \addr[1] + offset + (x << 2)
        *dst\l = $FF000000 | (r << 16) | (g << 8) | b
        
      Next
    Next
  EndWith
EndProcedure

Procedure cartoonEx(*FilterCtx.FilterParams)
  Restore cartoon_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@cartoon_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure cartoon(source, cible, mask, levels=6, sens=50, thick=30, mode=0, color=0, smooth=1)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = sens
    \option[2] = thick
    \option[3] = mode
    \option[4] = color
    \option[5] = smooth
  EndWith
  cartoonEx(FilterCtx)
EndProcedure

DataSection
  cartoon_Data:
  Data.s "Cartoon (marche pas)"
  Data.s "Effet dessin animé avec contours et quantification"
  Data.i #FilterType_Artistic, #Artistic_Other
  Data.s "Niveaux de couleur" : Data.i 2, 32, 6
  Data.s "Sensibilité contours" : Data.i 1, 100, 50
  Data.s "Épaisseur contours" : Data.i 1, 100, 30
  Data.s "Mode (0:Full, 1:Edge, 2:Color, 3:Sketch)" : Data.i 0, 3, 0
  Data.s "Couleur contours (0:N, 1:B, 2:Inv)" : Data.i 0, 2, 0
  Data.s "Lissage" : Data.i 0, 3, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 198
; FirstLine = 157
; Folding = -
; EnableXP
; DPIAware