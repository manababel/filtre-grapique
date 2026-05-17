; =============================================================================
; FILTRE ARTISTIQUE "SKETCH / PENCIL" POUR IMAGE ARGB 32 BITS
; =============================================================================

; -----------------------------------------------------------------------------
; PROCÉDURE THREAD : sketch_MT
; -----------------------------------------------------------------------------
Procedure sketch_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    ; --- Dimensions et configuration ---
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    Protected x, y
    
    ; --- Paramètres (Mutation vers \option[]) ---
    Protected edgeStrength.f  = \option[0] * 0.01
    Protected hatchDensity.f  = \option[1] * 0.01
    Protected hatchStyle      = \option[2]
    Protected pencilTexture.f = \option[3] * 0.01
    Protected paperGrain.f    = \option[4] * 0.01
    Protected contrast.f      = \option[5] * 0.01
    
    ; --- Variables de calcul ---
    Protected a, r, g, b
    Protected rC, gC, bC, rN, gN, bN
    Protected grayC.f, grayL.f, grayR.f, grayU.f, grayD.f, grayUL.f, grayDR.f, grayUR.f, grayDL.f
    Protected edgeH.f, edgeV.f, edgeD1.f, edgeD2.f, edge.f
    Protected tone.f, hatchValue.f, shading.f, pencilNoise.f, paperNoise.f, sketchValue.f
    Protected *src.Pixel32, *dst.Pixel32

    ; --- Calcul des segments de thread ---
    ; On utilise une marge de 2 pixels pour le Sobel
    Protected totalRows = h - 4
    macro_calul_tread(totalRows)
    Protected startY = thread_start + 2
    Protected endY   = thread_stop + 2

    For y = startY To endY - 1
      For x = 2 To w - 3
        
        ; 1. Lecture du centre
        *src = \addr[0] + ((y * w + x) << 2)
        GetARGB(*src\l, a, rC, gC, bC)
        grayC = rC * 0.299 + gC * 0.587 + bC * 0.114
        
        ; 2. Sobel multi-directionnel
        GetARGB(PeekL(\addr[0] + ((y * w + (x - 1)) << 2)), a, rN, gN, bN)
        grayL = rN * 0.299 + gN * 0.587 + bN * 0.114
        GetARGB(PeekL(\addr[0] + ((y * w + (x + 1)) << 2)), a, rN, gN, bN)
        grayR = rN * 0.299 + gN * 0.587 + bN * 0.114
        edgeH = Abs(grayR - grayL)
        
        GetARGB(PeekL(\addr[0] + (((y - 1) * w + x) << 2)), a, rN, gN, bN)
        grayU = rN * 0.299 + gN * 0.587 + bN * 0.114
        GetARGB(PeekL(\addr[0] + (((y + 1) * w + x) << 2)), a, rN, gN, bN)
        grayD = rN * 0.299 + gN * 0.587 + bN * 0.114
        edgeV = Abs(grayD - grayU)
        
        GetARGB(PeekL(\addr[0] + (((y - 1) * w + (x - 1)) << 2)), a, rN, gN, bN)
        grayUL = rN * 0.299 + gN * 0.587 + bN * 0.114
        GetARGB(PeekL(\addr[0] + (((y + 1) * w + (x + 1)) << 2)), a, rN, gN, bN)
        grayDR = rN * 0.299 + gN * 0.587 + bN * 0.114
        edgeD1 = Abs(grayDR - grayUL)
        
        GetARGB(PeekL(\addr[0] + (((y - 1) * w + (x + 1)) << 2)), a, rN, gN, bN)
        grayUR = rN * 0.299 + gN * 0.587 + bN * 0.114
        GetARGB(PeekL(\addr[0] + (((y + 1) * w + (x - 1)) << 2)), a, rN, gN, bN)
        grayDL = rN * 0.299 + gN * 0.587 + bN * 0.114
        edgeD2 = Abs(grayDL - grayUR)
        
        edge = Sqr(edgeH * edgeH + edgeV * edgeV + (edgeD1 * edgeD1 * 0.5) + (edgeD2 * edgeD2 * 0.5))
        edge = (edge / 255.0) * edgeStrength
        If edge > 1.0 : edge = 1.0 : EndIf
        
        ; 3. Ton et Contraste
        tone = 1.0 - (grayC / 255.0)
        tone = 0.5 + (tone - 0.5) * contrast
        If tone < 0.0 : tone = 0.0 : EndIf
        If tone > 1.0 : tone = 1.0 : EndIf
        
        ; 4. Hachures
        hatchValue = 0.0
        If hatchStyle > 0 And hatchDensity > 0.01
          Select hatchStyle
            Case 1 ; Simple
              Protected hatchSpacing1.f = 3.0 + (1.0 - hatchDensity) * 5.0
              If ((x + y) / hatchSpacing1) - Int((x + y) / hatchSpacing1) < 0.3
                hatchValue = tone * 0.6
              EndIf
            Case 2 ; Croisée
              Protected hatchSpacing2.f = 3.0 + (1.0 - hatchDensity) * 4.0
              If ((x + y) / hatchSpacing2) - Int((x + y) / hatchSpacing2) < 0.25 Or ((x - y) / hatchSpacing2) - Int((x - y) / hatchSpacing2) < 0.25
                hatchValue = tone * 0.7
              EndIf
            Case 3 ; Circulaire
              Protected gradAngle.f = ATan2(edgeV, edgeH)
              Protected hatchSpacing3.f = 4.0 + (1.0 - hatchDensity) * 4.0
              If ((x * Cos(gradAngle) + y * Sin(gradAngle)) / hatchSpacing3) - Int((x * Cos(gradAngle) + y * Sin(gradAngle)) / hatchSpacing3) < 0.3
                hatchValue = tone * 0.65
              EndIf
          EndSelect
        EndIf
        
        ; 5. Bruitages (Textures) - Respect des types Integer/Float
        pencilNoise = 0.0
        If pencilTexture > 0.01
          Protected noiseValInt = (((x * 23456 + y * 78901) & $7FFFFFFF) % 1000) - 500
          pencilNoise = (noiseValInt * 1.0 / 500.0) * pencilTexture * tone * 0.15
        EndIf
        
        paperNoise = 0.0
        If paperGrain > 0.01
          Protected noiseValInt1 = (((x / 2) * 34567 + (y / 2) * 89012) & $7FFFFFFF) % 1000 - 500
          Protected noiseValInt2 = (((x * 45678 + y * 12345) & $7FFFFFFF) % 1000 - 500)
          paperNoise = (noiseValInt1 * 1.0 / 500.0) * 0.7 + (noiseValInt2 * 1.0 / 500.0) * 0.3
          paperNoise * paperGrain * 0.08
        EndIf
        
        ; 6. Composition
        shading = tone * (1.0 - hatchDensity * 0.5) * 0.4
        sketchValue = 1.0 - edge - hatchValue - shading + pencilNoise + paperNoise
        
        ; 7. Pression variable
        Protected pressureValInt = ((( (x/3) * 56789 + (y/3) * 23456) & $7FFFFFFF) % 1000) - 500
        Protected pressure.f = pressureValInt * 1.0 / 5000.0
        If sketchValue < 0.8
          sketchValue + pressure * (0.8 - sketchValue) * 0.3
        EndIf
        
        If sketchValue < 0.0 : sketchValue = 0.0 : EndIf
        If sketchValue > 1.0 : sketchValue = 1.0 : EndIf
        
        Protected finalValue = Int(sketchValue * 255.0)
        
        r = finalValue : g = finalValue : b = finalValue
        If r > 240 : r - 3 : g - 1 : b - 5 : EndIf
        
        If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
        
        *dst = \addr[1] + ((y * w + x) << 2)
        *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

; -----------------------------------------------------------------------------
; PROCÉDURE D'APPEL : sketchEx
; -----------------------------------------------------------------------------
Procedure sketchEx(*FilterCtx.FilterParams)
  Restore sketch_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@sketch_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; -----------------------------------------------------------------------------
; INTERFACE SIMPLIFIÉE
; -----------------------------------------------------------------------------
Procedure sketch(source, cible, mask, edge=70, density=50, style=2, pencil=40, grain=30, contrast=120)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = edge
    \option[1] = density
    \option[2] = style
    \option[3] = pencil
    \option[4] = grain
    \option[5] = contrast
  EndWith
  sketchEx(FilterCtx)
EndProcedure

; -----------------------------------------------------------------------------
; DONNÉES DU FILTRE
; -----------------------------------------------------------------------------
DataSection
  sketch_Data:
  Data.s "Sketch / Pencil (buguee) "
  Data.s "Transforme l'image en dessin au crayon avec hachures et textures"
  Data.i #FilterType_Artistic
  Data.i #Artistic_Material
  
  Data.s "Contours"
  Data.i 0, 100, 70
  
  Data.s "Densité hachures"
  Data.i 0, 100, 50
  
  Data.s "Style (0-3)"
  Data.i 0, 3, 2
  
  Data.s "Texture crayon"
  Data.i 0, 100, 40
  
  Data.s "Grain papier"
  Data.i 0, 100, 30
  
  Data.s "Contraste"
  Data.i 50, 200, 120
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 185
; FirstLine = 158
; Folding = -
; EnableXP
; DPIAware