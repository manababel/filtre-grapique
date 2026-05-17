; ==============================================================================
; FILTRE EMBOSS BUMP - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure Emboss_bump_MT(*p.FilterParams)
  With *p
    Protected x, y, pos, j, i
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected a, r, g, b
    Protected lValue
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected Dim l(2,2)  ; 3x3 pour le gradient

    ; === Paramètres de lumière ===
    Protected azimuth.f   = \option[0]   ; 0..360°
    Protected elevation.f = \option[1] * 90 / 100  ; 0..90°
    If elevation < 1 : elevation = 1 : EndIf
    Protected intensity.f = (\option[2] + 50) / 100.0
    Protected light_mix   = \option[3]
    Protected bn          = \option[5]
    Protected mix_strength.f = \option[4] / 100
    Protected invert      = \option[6]
    
    ; --- Calcul vecteur lumière ---
    Protected lx.f, ly.f, lz.f
    lx = Cos(Radian(azimuth)) * Sin(Radian(elevation))
    ly = Sin(Radian(azimuth)) * Sin(Radian(elevation))
    lz = Cos(Radian(elevation))
    
    ; Normalisation (Respect strict des opérations d'origine)
    Protected llen.f = Sqr(lx*lx + ly*ly + lz*lz)
    If llen <> 0.0
      lx = lx / llen : ly = ly / llen : lz = lz / llen
    EndIf

    ; --- Configuration Multithreading (macro_calcul_thread) ---
    Protected startY = (\thread_pos * ht) / \thread_max
    Protected endY   = ((\thread_pos + 1) * ht) / \thread_max
    If endY > ht : endY = ht : EndIf
    Protected readStart = startY
    Protected readEnd   = endY
    If readStart < 1 : readStart = 1 : EndIf
    If readEnd > ht-2 : readEnd = ht-2 : EndIf

    ; --- Traitement principal ---
    For y = readStart To readEnd
      For x = 1 To lg-2
        pos = \addr[0] + ((y * lg + x) << 2)
        
        ; --- Lecture des 3x3 voisins ---
        For j = -1 To 1
          For i = -1 To 1
            *srcPixel = pos + ((j * lg + i) << 2)
            GetARGB(*srcPixel\l, a, r, g, b)
            l(i+1, j+1) = (r * 1225 + g * 2405 + b * 466) >> 12
          Next i
        Next j
        
        ; --- Calcul gradient ---
        Protected gx.f, gy.f, gz.f
        gx = ((l(2,0) + 2*l(2,1) + l(2,2)) - (l(0,0) + 2*l(0,1) + l(0,2)))
        gy = ((l(0,2) + 2*l(1,2) + l(2,2)) - (l(0,0) + 2*l(1,0) + l(2,0)))
        gz = 1.0  ; normalisation approximative

        ; --- Produit scalaire lumière × gradient ---
        lValue = 128 + intensity * (gx * lx + gy * ly + gz * lz)
        
        If bn
          lValue = lValue - 128
          If invert
            lValue = 255 - lValue
          EndIf 
        EndIf  
        
        lValue = Pow(lValue/255.0, 1.2) * 255
        Clamp(lValue, 0, 255)
        
        If y >= startY And y < endY
          *dstPixel = \addr[1] + ((y * lg + x) << 2)
          
          ; ---- Mélange lumière / couleur d'origine ----
          If light_mix
            ; récupération de la couleur d'origine (sur le pixel central)
            *srcPixel = pos 
            GetARGB(*srcPixel\l, a, r, g, b)
            
            r = r * (1.0 - mix_strength) + lValue * mix_strength
            g = g * (1.0 - mix_strength) + lValue * mix_strength
            b = b * (1.0 - mix_strength) + lValue * mix_strength
            
            Clamp_rgb(r, g , b)
            *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
          Else
            ; rendu emboss pur en niveaux de gris
            *dstPixel\l = (a << 24) | lValue * $10101
          EndIf
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure Emboss_bumpEx(*FilterCtx.FilterParams)
  Restore Emboss_bump_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Emboss_bump_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure Emboss_bump(source, cible, mask, angle=50, inclinaison=25, intensity=250, mix_img=0, mix_alpha=50, bn=0, invert=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = angle
    \option[1] = inclinaison
    \option[2] = intensity
    \option[3] = mix_img
    \option[4] = mix_alpha
    \option[5] = bn
    \option[6] = invert
  EndWith
  Emboss_bumpEx(FilterCtx)
EndProcedure

DataSection
  Emboss_bump_Data:
  Data.s "Emboss"
  Data.s "Emboss (relief directionnel niveaux de gris)"
  Data.i #FilterType_TexturePattern, #Artistic_Other
  Data.s "angle"       : Data.i 0, 360, 50
  Data.s "inclinaison" : Data.i 1, 100, 25
  Data.s "intensity"   : Data.i 1, 500, 250
  Data.s "Mix_image"   : Data.i 0, 1, 0
  Data.s "mix_alpha"   : Data.i 0, 100, 50
  Data.s "Blanc/noir"  : Data.i 0, 1, 0
  Data.s "invert"      : Data.i 0, 1, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 105
; FirstLine = 93
; Folding = -
; EnableXP
; DPIAware