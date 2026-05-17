; ============================================================================
; Filtre Zero Crossing - Détection de passages par zéro (Laplacien)
; ============================================================================

Macro ZeroCrossing_ReadGray(var)
  getrgb(PeekL(*srcPixel), r, g, b)
  gray(var) = (r * 77 + g * 150 + b * 29) >> 8
  *srcPixel + 4
EndMacro

Macro ZeroCrossing_ReadRGB(var)
  getrgb(PeekL(*srcPixel), r3(var), g3(var), b3(var))
  *srcPixel + 4
EndMacro

Procedure ZeroCrossing_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    
    Protected threshold = \option[0]
    Protected kernelType = \option[1]
    Protected toGray = \option[2]
    Protected inverse = \option[3]
    
    ; Normalisation du seuil (0-100 -> 0-50)
    clamp(threshold, 0, 100)
    threshold = threshold * 0.5
    
    Protected Dim r3(8)
    Protected Dim g3(8)
    Protected Dim b3(8)
    Protected Dim gray(8)
    Protected Dim kernel(8)
    
    ; Sélection du type de noyau Laplacien
    Select kernelType
      Case 0  ; Laplacien 4-connecté (croix)
        kernel(0) = 0  : kernel(1) = 1  : kernel(2) = 0
        kernel(3) = 1  : kernel(4) = -4 : kernel(5) = 1
        kernel(6) = 0  : kernel(7) = 1  : kernel(8) = 0
        
      Case 1  ; Laplacien 8-connecté (complet)
        kernel(0) = 1  : kernel(1) = 1  : kernel(2) = 1
        kernel(3) = 1  : kernel(4) = -8 : kernel(5) = 1
        kernel(6) = 1  : kernel(7) = 1  : kernel(8) = 1
        
      Case 2  ; Laplacien diagonal
        kernel(0) = 1  : kernel(1) = 2  : kernel(2) = 1
        kernel(3) = 2  : kernel(4) = -12 : kernel(5) = 2
        kernel(6) = 1  : kernel(7) = 2  : kernel(8) = 1
    EndSelect
    
    Protected *srcPixel.Long
    Protected *dstPixel.Long
    Protected a, r, g, b
    Protected x, y, i, j
    Protected laplacian_r.f, laplacian_g.f, laplacian_b.f, laplacian_gray.f
    Protected zc_r, zc_g, zc_b, zc_gray
    Protected neighbor_r.f, neighbor_g.f, neighbor_b.f, neighbor_gray.f
    Protected sign_change
    
    ; Calcul des limites de traitement
    macro_calul_tread((ht - 2))
    Protected startPos = thread_start + 1
    Protected endPos   = thread_stop
    
    clamp(startPos, 1, ht - 2)
    clamp(endPos, 1, ht - 2)
    
    If startPos > endPos : ProcedureReturn : EndIf
    
    For y = startPos To endPos
      For x = 1 To lg - 2
        
        If toGray
          ; MODE NIVEAU DE GRIS
          *srcPixel = *source + ((y - 1) * lg + (x - 1)) * 4
          ZeroCrossing_ReadGray(0) : ZeroCrossing_ReadGray(1) : ZeroCrossing_ReadGray(2)
          *srcPixel = *source + (y * lg + (x - 1)) * 4
          ZeroCrossing_ReadGray(3) : ZeroCrossing_ReadGray(4) : ZeroCrossing_ReadGray(5)
          *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
          ZeroCrossing_ReadGray(6) : ZeroCrossing_ReadGray(7) : ZeroCrossing_ReadGray(8)
          
          laplacian_gray = 0
          For i = 0 To 8
            laplacian_gray + gray(i) * kernel(i)
          Next
          
          sign_change = #False
          For i = 0 To 8
            If i = 4 : Continue : EndIf
            neighbor_gray = 0
            For j = 0 To 8
              neighbor_gray + gray(j) * kernel((i + j) % 9)
            Next
            If (laplacian_gray * neighbor_gray < 0) And (Abs(laplacian_gray - neighbor_gray) > threshold)
              sign_change = #True : Break
            EndIf
          Next
          
          zc_gray = 0
          If sign_change : zc_gray = 255 : EndIf
          If inverse : zc_gray = 255 - zc_gray : EndIf
          
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (zc_gray * $010101))
          
        Else
          ; MODE COULEUR
          *srcPixel = *source + ((y - 1) * lg + (x - 1)) * 4
          ZeroCrossing_ReadRGB(0) : ZeroCrossing_ReadRGB(1) : ZeroCrossing_ReadRGB(2)
          *srcPixel = *source + (y * lg + (x - 1)) * 4
          ZeroCrossing_ReadRGB(3) : ZeroCrossing_ReadRGB(4) : ZeroCrossing_ReadRGB(5)
          *srcPixel = *source + ((y + 1) * lg + (x - 1)) * 4
          ZeroCrossing_ReadRGB(6) : ZeroCrossing_ReadRGB(7) : ZeroCrossing_ReadRGB(8)
          
          laplacian_r = 0 : laplacian_g = 0 : laplacian_b = 0
          For i = 0 To 8
            laplacian_r + r3(i) * kernel(i)
            laplacian_g + g3(i) * kernel(i)
            laplacian_b + b3(i) * kernel(i)
          Next
          
          zc_r = 0 : zc_g = 0 : zc_b = 0
          
          ; Canal Rouge
          sign_change = #False
          For i = 0 To 8
            If i = 4 : Continue : EndIf
            neighbor_r = 0
            For j = 0 To 8 : neighbor_r + r3(j) * kernel((i + j) % 9) : Next
            If (laplacian_r * neighbor_r < 0) And (Abs(laplacian_r - neighbor_r) > threshold)
              sign_change = #True : Break
            EndIf
          Next
          If sign_change : zc_r = 255 : EndIf
          
          ; Canal Vert
          sign_change = #False
          For i = 0 To 8
            If i = 4 : Continue : EndIf
            neighbor_g = 0
            For j = 0 To 8 : neighbor_g + g3(j) * kernel((i + j) % 9) : Next
            If (laplacian_g * neighbor_g < 0) And (Abs(laplacian_g - neighbor_g) > threshold)
              sign_change = #True : Break
            EndIf
          Next
          If sign_change : zc_g = 255 : EndIf
          
          ; Canal Bleu
          sign_change = #False
          For i = 0 To 8
            If i = 4 : Continue : EndIf
            neighbor_b = 0
            For j = 0 To 8 : neighbor_b + b3(j) * kernel((i + j) % 9) : Next
            If (laplacian_b * neighbor_b < 0) And (Abs(laplacian_b - neighbor_b) > threshold)
              sign_change = #True : Break
            EndIf
          Next
          If sign_change : zc_b = 255 : EndIf
          
          If inverse
            zc_r = 255 - zc_r : zc_g = 255 - zc_g : zc_b = 255 - zc_b
          EndIf
          
          *dstPixel = *cible + (y * lg + x) * 4
          PokeL(*dstPixel, $FF000000 | (zc_r << 16) | (zc_g << 8) | zc_b)
        EndIf
      Next
    Next
    
    FreeArray(r3()) : FreeArray(g3()) : FreeArray(b3())
    FreeArray(gray()) : FreeArray(kernel())
  EndWith
EndProcedure

Procedure ZeroCrossingEx(*FilterCtx.FilterParams)
  Restore ZeroCrossing_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@ZeroCrossing_MT())
  
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure ZeroCrossing(source, cible, mask, seuil, type_noyau, noir_et_blanc, inversion)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = seuil
    \option[1] = type_noyau
    \option[2] = noir_et_blanc
    \option[3] = inversion
  EndWith
  ZeroCrossingEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  ZeroCrossing_data:
  Data.s "Zero Crossing"
  Data.s "Détection de contours par passages par zéro du Laplacien"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Laplacian
  
  Data.s "Seuil"
  Data.i 0, 100, 10
  Data.s "Type noyau (0:4C, 1:8C, 2:Diag)"
  Data.i 0, 2, 1
  Data.s "Noir et blanc"
  Data.i 0, 1, 1
  Data.s "Inversion"
  Data.i 0, 1, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 189
; FirstLine = 167
; Folding = -
; EnableXP
; DPIAware