; =============================================================================
; FILTRE ARTISTIQUE "IMPASTO" - STRUCTURE RÉVISÉE
; =============================================================================

Procedure impasto_MT(*p.FilterParams)
  With *p
    ; --- Dimensions de l'image ---
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    
    ; --- Coordonnées ---
    Protected x, y, i, j
    
    ; --- Composantes ARGB ---
    Protected a, r, g, b
    Protected rC, gC, bC
    Protected rN, gN, bN
    
    ; --- Relief et épaisseur ---
    Protected heightMap.f
    Protected relief.f
    Protected thickness.f
    
    ; --- Coup de pinceau ---
    Protected sumR.f, sumG.f, sumB.f
    Protected count.f
    
    ; --- Direction et structure ---
    Protected dx.f, dy.f
    Protected angle.f
    Protected brushStrength.f
    
    ; --- Texture ---
    Protected noise.f
    Protected impastoNoise.f
    
    ; --- Éclairage du relief ---
    Protected nx.f, ny.f, nz.f
    Protected len.f
    Protected lighting.f
    
    ; --- Pointeurs mémoire ---
    Protected *src.Pixel32
    Protected *dst.Pixel32
    
    ; ============================================================================
    ; LECTURE DES PARAMÈTRES
    ; ============================================================================
    Protected paintThickness.f = \option[0] * 0.01
    
    Protected brushSize = \option[1]
    If brushSize < 2 : brushSize = 2 : EndIf
    If brushSize > 15 : brushSize = 15 : EndIf
    
    Protected reliefStrength.f = \option[2] * 0.01
    Protected textureAmount.f = \option[3] * 0.01
    Protected strokeDirection = \option[4]
    Protected lightIntensity.f = \option[5] * 0.01
    
    Protected lx.f = -0.5
    Protected ly.f = -0.5
    Protected lz.f = 0.7
    
    ; ============================================================================
    ; CONFIGURATION MULTITHREADING
    ; ============================================================================
    Protected startY = (\thread_pos * h) / \thread_max
    Protected endY   = ((\thread_pos + 1) * h) / \thread_max
    
    Protected border = brushSize + 2
    If startY < border : startY = border : EndIf
    If endY > h - border : endY = h - border : EndIf
    
    ; ============================================================================
    ; TRAITEMENT PRINCIPAL
    ; ============================================================================
    For y = startY To endY - 1
      For x = border To w - border - 1
        
        *src = \addr[0] + ((y * w + x) << 2)
        GetARGB(*src\l, a, rC, gC, bC)
        
        heightMap = (rC * 0.299 + gC * 0.587 + bC * 0.114) / 255.0
        heightMap = heightMap * paintThickness
        
        If strokeDirection = 0
          *src = \addr[0] + ((y * w + (x - 1)) << 2)
          GetARGB(*src\l, a, rN, gN, bN)
          Protected grayL.f = rN * 0.299 + gN * 0.587 + bN * 0.114
          
          *src = \addr[0] + ((y * w + (x + 1)) << 2)
          GetARGB(*src\l, a, rN, gN, bN)
          Protected grayR.f = rN * 0.299 + gN * 0.587 + bN * 0.114
          
          *src = \addr[0] + (((y - 1) * w + x) << 2)
          GetARGB(*src\l, a, rN, gN, bN)
          Protected grayU.f = rN * 0.299 + gN * 0.587 + bN * 0.114
          
          *src = \addr[0] + (((y + 1) * w + x) << 2)
          GetARGB(*src\l, a, rN, gN, bN)
          Protected grayD.f = rN * 0.299 + gN * 0.587 + bN * 0.114
          
          dx = (grayR - grayL) / 255.0
          dy = (grayD - grayU) / 255.0
          angle = ATan2(dy, dx) + #PI / 2.0
          brushStrength = Sqr(dx * dx + dy * dy)
        Else
          Protected angleStep.f = #PI / 4.0
          angle = (strokeDirection - 1) * angleStep
          brushStrength = 0.5
        EndIf
        
        sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : count = 0.0
        Protected cosAngle.f = Cos(angle)
        Protected sinAngle.f = Sin(angle)
        
        For i = -brushSize To brushSize
          For j = -2 To 2
            Protected offsetX.f = i * cosAngle - j * sinAngle
            Protected offsetY.f = i * sinAngle + j * cosAngle
            Protected px = x + Int(offsetX)
            Protected py = y + Int(offsetY)
            
            If px >= 0 And px < w And py >= 0 And py < h
              Protected distCenter.f = Sqr(i * i * 0.5 + j * j * 2.0)
              Protected weight.f = 1.0 / (1.0 + distCenter * 0.2)
              *src = \addr[0] + ((py * w + px) << 2)
              GetARGB(*src\l, a, rN, gN, bN)
              sumR + rN * weight
              sumG + gN * weight
              sumB + bN * weight
              count + weight
            EndIf
          Next
        Next
        
        Protected avgR.f = sumR / count
        Protected avgG.f = sumG / count
        Protected avgB.f = sumB / count
        
        Protected blendFactor.f = 0.2 + paintThickness * 0.6
        r = Int(rC * (1.0 - blendFactor) + avgR * blendFactor)
        g = Int(gC * (1.0 - blendFactor) + avgG * blendFactor)
        b = Int(bC * (1.0 - blendFactor) + avgB * blendFactor)
        
        If reliefStrength > 0.01
          Protected heightL.f, heightR.f, heightU.f, heightD.f
          *src = \addr[0] + ((y * w + (x - 1)) << 2)
          GetARGB(*src\l, a, rN, gN, bN)
          heightL = (rN * 0.299 + gN * 0.587 + bN * 0.114) / 255.0
          *src = \addr[0] + ((y * w + (x + 1)) << 2)
          GetARGB(*src\l, a, rN, gN, bN)
          heightR = (rN * 0.299 + gN * 0.587 + bN * 0.114) / 255.0
          *src = \addr[0] + (((y - 1) * w + x) << 2)
          GetARGB(*src\l, a, rN, gN, bN)
          heightU = (rN * 0.299 + gN * 0.587 + bN * 0.114) / 255.0
          *src = \addr[0] + (((y + 1) * w + x) << 2)
          GetARGB(*src\l, a, rN, gN, bN)
          heightD = (rN * 0.299 + gN * 0.587 + bN * 0.114) / 255.0
          
          Protected dxRelief.f = (heightR - heightL) * reliefStrength * 3.0
          Protected dyRelief.f = (heightD - heightU) * reliefStrength * 3.0
          nx = -dxRelief : ny = -dyRelief : nz = 1.0
          len = Sqr(nx * nx + ny * ny + nz * nz)
          If len > 0.0001 : nx / len : ny / len : nz / len : EndIf
          
          Protected dot.f = nx * lx + ny * ly + nz * lz
          If dot < 0.0 : dot = 0.0 : EndIf
          lighting = 0.4 + dot * 0.6 * lightIntensity
          r = Int(r * lighting) : g = Int(g * lighting) : b = Int(b * lighting)
        EndIf
        
        If textureAmount > 0.01
          Protected seed1 = (x * 34567 + y * 98765) & $7FFFFFFF
          Protected noiseVal1 = (seed1 % 1000) - 500
          noise = noiseVal1 / 500.0
          Protected coordAlong = Int(x * cosAngle + y * sinAngle)
          Protected seed2 = (coordAlong * 45678) & $7FFFFFFF
          Protected noiseVal2 = (seed2 % 1000) - 500
          impastoNoise = noiseVal2 / 500.0
          Protected totalTexture.f = (noise * 0.3 + impastoNoise * 0.7) * textureAmount * 40.0
          totalTexture = totalTexture * (0.5 + heightMap)
          r + Int(totalTexture) : g + Int(totalTexture * 0.95) : b + Int(totalTexture * 1.05)
        EndIf
        
        Protected edgeAccum.f = Sqr(dx * dx + dy * dy)
        If edgeAccum > 0.3
          Protected accumEffect.f = (edgeAccum - 0.3) * paintThickness * 20.0
          r + Int(accumEffect) : g + Int(accumEffect) : b + Int(accumEffect)
        EndIf
        
        Protected thicknessSeed = ((x / 4) * 23456 + (y / 4) * 67890) & $7FFFFFFF
        Protected thicknessVal = (thicknessSeed % 1000) - 500
        thickness = thicknessVal / 5000.0
        Protected thicknessEffect.f = thickness * paintThickness * 25.0
        r + Int(thicknessEffect) : g + Int(thicknessEffect * 0.98) : b + Int(thicknessEffect * 1.02)
        
        If heightMap > 0.7
          Protected impastoEffect.f = (heightMap - 0.7) * paintThickness * 30.0
          r + Int(impastoEffect) : g + Int(impastoEffect) : b + Int(impastoEffect)
          Protected highlight.f = (heightMap - 0.7) * lightIntensity * 15.0
          r + Int(highlight) : g + Int(highlight) : b + Int(highlight)
        EndIf
        
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        
        *dst = \addr[1] + ((y * w + x) << 2)
        *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure impastoEx(*FilterCtx.FilterParams)
  Restore impasto_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  With *FilterCtx
    Create_MultiThread_MT(@impasto_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure impasto(source, cible, mask, thickness=60, size=7, relief=70, texture=65, direction=0, light=80)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = thickness
    \option[1] = size
    \option[2] = relief
    \option[3] = texture
    \option[4] = direction
    \option[5] = light
  EndWith
  impastoEx(FilterCtx)
EndProcedure

DataSection
  impasto_Data:
  Data.s "Impasto - Peinture Épaisse"
  Data.s "Simule une peinture très épaisse avec relief prononcé et texture"
  Data.i #FilterType_Artistic, #Artistic_Material
  Data.s "Épaisseur peinture" : Data.i 1, 100, 60
  Data.s "Taille pinceau"     : Data.i 2, 15, 7
  Data.s "Relief"             : Data.i 0, 100, 70
  Data.s "Texture matière"    : Data.i 0, 100, 65
  Data.s "Direction (0=Auto/1-8=Fixe)" : Data.i 0, 8, 0
  Data.s "Éclairage relief"   : Data.i 0, 100, 80
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 225
; FirstLine = 201
; Folding = -
; EnableXP
; DPIAware