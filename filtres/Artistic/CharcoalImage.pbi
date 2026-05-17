; =============================================================================
; FILTRE ARTISTIQUE "CHARCOAL" (FUSAIN) POUR IMAGE ARGB 32 BITS
; =============================================================================

Procedure.f RandomFloat(min.f = 0.0, max.f = 1.0)
  ProcedureReturn min + (max - min) * Random(1000000) / 1000000.0
EndProcedure

Procedure ContrastColour(Colour, Scale.f)
  Protected r, g, b
  getrgb(Colour, r, g, b)
  r = r * (1.0 + Scale)
  g = g * (1.0 + Scale)
  b = b * (1.0 + Scale)
  clamp_rgb(r, g, b)
  ProcedureReturn (r << 16) | (g << 8) | b
EndProcedure

; -----------------------------------------------------------------------------
; PROCÉDURE THREAD : Charcoal_MT
; -----------------------------------------------------------------------------
Procedure Charcoal_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected i, a, r, g, b
    Protected r1, g1, b1
    Protected r2, g2, b2
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    
    Protected intensity.f = 0.32 + (\option[0] / 100.0)
    Protected tolerance.f = 1.0 - intensity
    
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    
    Protected totalPixels = w * h
    
    ; Utilisation de la règle de parenthèse pour la macro si nécessaire
    macro_calul_tread(totalPixels)
    
    Protected colour, pixel, grey, grade
    Protected chalking
    Protected definition.f
    
    ; On pointe sur le début du segment
    *srcPixel = \addr[0] + (thread_start << 2)
    *dstPixel = \addr[1] + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
      colour = *srcPixel\l
      a = (colour >> 24) & $FF
      getrgb(colour, r, g, b)
      
      chalking = (r * 1225 + g * 2405 + b * 466) >> 12
      grade = intensity * 64.0
      
      If chalking > (255.0 - grade)
        r = 255 : g = 255 : b = 255
      Else
        getrgb(colour, r1, g1, b1)
        r1 = r1 * (1.0 + intensity)
        g1 = g1 * (1.0 + intensity)
        b1 = b1 * (1.0 + intensity)
        clamp_rgb(r1, g1, b1)
        colour = (r1 << 16) | (g1 << 8) | b1
        
        definition = RandomFloat(0, 1)
        
        If definition > tolerance
          getrgb(pixel, r1, g1, b1)
          getrgb(colour, r2, g2, b2)
          r1 = ((r2 - r1) * tolerance) + r1
          clamp_rgb(r1, g1, b1)
          pixel = (r1 << 16) | (g1 << 8) | b1
        EndIf
        
        getrgb(pixel, r, g, b)
        grey = (r * 1225 + g * 2405 + b * 466) >> 12
        r = grey : g = grey : b = grey
        
        grade = intensity * 64.0
        
        If (grey > grade) And (grey < (255.0 - grade))
          If RandomFloat(0, 1) >= tolerance ; Simplification logique du Random
            r + grade
            g + (grade * 0.5) ; Parenthèses pour sécurité
            clamp(r, 0, 224)
            clamp(g, 0, 224)
          EndIf
        Else
          If r > 127 : r = 224 : Else : r = 0 : EndIf
          If g > 127 : g = 224 : Else : g = 0 : EndIf
          If b > 127 : b = 224 : Else : b = 0 : EndIf
        EndIf
      EndIf
      
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      
      *srcPixel + 4
      *dstPixel + 4
    Next
  EndWith
EndProcedure

; -----------------------------------------------------------------------------
; PROCÉDURE D'APPEL : CharcoalImageEx
; -----------------------------------------------------------------------------
Procedure CharcoalImageEx(*FilterCtx.FilterParams)
  Restore Charcoal_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@Charcoal_MT())
    mask_update(*FilterCtx.FilterParams, last_data)
  EndWith
EndProcedure

; -----------------------------------------------------------------------------
; INTERFACE SIMPLIFIÉE
; -----------------------------------------------------------------------------
Procedure CharcoalImage(source, cible, mask, intensite)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensite
  EndWith
  CharcoalImageEx(FilterCtx)
EndProcedure

; -----------------------------------------------------------------------------
; DONNÉES DU FILTRE
; -----------------------------------------------------------------------------
DataSection
  Charcoal_Data:
  Data.s "Charcoal"
  Data.s "Effet dessin au fusain avec grain aléatoire"
  Data.i #FilterType_Artistic
  Data.i #Artistic_Material
  
  Data.s "Intensité"
  Data.i 0, 17, 8 ; Min, Max, Défaut
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 22
; FirstLine = 7
; Folding = -
; EnableXP
; DPIAware