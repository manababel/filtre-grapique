; ---------------------------------------------------
; Depth Aware Blur - Version optimisée
; Flou sélectif préservant les contours (Bilateral-like)
; ---------------------------------------------------

Procedure DepthAwareBlur_grayscale_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected total = lg * ht
    Protected value, r, g, b, gray, i
    Protected *src.pixelarray = \addr[0]
    
    macro_calul_tread(total)
    
    For i = thread_start To thread_stop - 1
      getrgb(*src\l[i] , r , g , b)
      gray = (r * 1225 + g * 2405 + b * 466) >> 12
      PokeB(\addr[2] + i , gray)
    Next
  EndWith
EndProcedure

Procedure DepthAwareBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected width = \image_lg[0], height = \image_ht[0]
    Protected depthThreshold = \option[0]
    Protected radius = \option[1]
    Protected x, y, dx, dy, sx, sy, offset, col, count
    Protected r, g, b, centerDepth, sampleDepth, dr
    Protected r1 , g1 , b1
    Protected widthLimit = width - 1, heightLimit = height - 1
    
    Protected *src.pixelarray = \addr[0]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(height)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To widthLimit
        r = 0 : g = 0 : b = 0 : count = 0
        
        ; Profondeur (luminance) du pixel central
        centerDepth = PeekA(\addr[2] + (y * width + x))
        
        ; Voisinage
        For dy = -radius To radius
          sy = y + dy
          If sy < 0 Or sy > heightLimit : Continue : EndIf
          
          For dx = -radius To radius
            sx = x + dx
            If sx < 0 Or sx > widthLimit : Continue : EndIf
            
            ; Test de la différence de "profondeur" (luminance)
            sampleDepth = PeekA(\addr[2] + (sy * width + sx))
            dr = Abs(sampleDepth - centerDepth)
            
            If dr <= depthThreshold
              getrgb(*src\l[sy * width + sx] , r1, g1 , b1)
              r + r1
              g + g1
              b + b1
              count + 1
            EndIf
          Next
        Next
        
        offset = (y * width + x)
        If count > 0
          *dst\l[offset] =  $FF000000 | ((r / count) << 16) | ((g / count) << 8) | (b / count)
        Else
          *dst\l[offset] = *src\l[offset] 
        EndIf
        If key_escape_press = 1 : Break 2 : EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure DepthAwareBlurEx(*FilterCtx.FilterParams)
  Restore DepthAwareBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Allocation de la carte de luminance (Buffer temporaire interne)
    Protected *depthMap = AllocateMemory(\image_lg[0] * \image_ht[0])
    If Not *depthMap : ProcedureReturn 0 : EndIf
    
    ; addr[0] = Source, addr[1] = Cible, addr[2] = Map de profondeur
    \addr[2] = *depthMap
    
    ; 1. Génération de la carte de profondeur
    Create_MultiThread_MT(@DepthAwareBlur_grayscale_sp())
    
    ; 2. Application du flou sélectif
    Create_MultiThread_MT(@DepthAwareBlur_sp())
    
    FreeMemory(*depthMap)
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure DepthAwareBlur(source, cible, mask, threshold, radius)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = threshold
    \option[1] = radius
  EndWith
  DepthAwareBlurEx(FilterCtx)
EndProcedure

DataSection
  DepthAwareBlur_data:
  Data.s "Depth Aware Blur"
  Data.s "Flou préservant les contours basé sur la luminance locale"
  Data.i #FilterType_Blur, #Blur_Optical
  Data.s "Seuil"
  Data.i 1, 255, 30
  Data.s "Rayon"
  Data.i 1, 10, 3
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 32
; FirstLine = 24
; Folding = -
; EnableXP
; DPIAware