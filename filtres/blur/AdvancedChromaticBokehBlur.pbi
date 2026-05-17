; ---------------------------------------------------
; Advanced Chromatic Bokeh Blur - Version optimisée
; Flou cinématographique polygonal avec aberration chromatique
; ---------------------------------------------------

Procedure AdvancedChromaticBokehBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0], sides = \option[1], chroma = \option[2]
    Protected x, y, i, px, py, index, value, countR, countG, countB
    Protected sumR, sumG, sumB, sumA, r, g, b, a
    Protected dx, dy, value_src
    Protected angle.f, angleStep.f = 2.0 * #PI / sides
    Protected chromaRange = chroma * 2
    
    ; Générateur pour le thread
    RandomSeed((\thread_pos + 1) * 1234)
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        sumR = 0 : sumG = 0 : sumB = 0 : sumA = 0
        countR = 0 : countG = 0 : countB = 0
        
        ; Parcourir les sommets du polygone pour chaque canal
        For i = 0 To sides - 1
          angle = angleStep * i
          
          ; --- Canal Rouge ---
          dx = Round(radius * Cos(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
          dy = Round(radius * Sin(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
          px = x + dx : py = y + dy
          If px < 0 : px = 0 : ElseIf px > lg - 1 : px = lg - 1 : EndIf
          If py < 0 : py = 0 : ElseIf py > ht - 1 : py = ht - 1 : EndIf
          value = PeekL(\addr[0] + (py * lg + px) << 2)
          sumR + ((value >> 16) & $FF) : sumA + ((value >> 24) & $FF) : countR + 1
          
          ; --- Canal Vert ---
          dx = Round(radius * Cos(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
          dy = Round(radius * Sin(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
          px = x + dx : py = y + dy
          If px < 0 : px = 0 : ElseIf px > lg - 1 : px = lg - 1 : EndIf
          If py < 0 : py = 0 : ElseIf py > ht - 1 : py = ht - 1 : EndIf
          value = PeekL(\addr[0] + (py * lg + px) << 2)
          sumG + ((value >> 8) & $FF) : sumA + ((value >> 24) & $FF) : countG + 1
          
          ; --- Canal Bleu ---
          dx = Round(radius * Cos(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
          dy = Round(radius * Sin(angle) + Random(chromaRange) - chroma, #PB_Round_Nearest)
          px = x + dx : py = y + dy
          If px < 0 : px = 0 : ElseIf px > lg - 1 : px = lg - 1 : EndIf
          If py < 0 : py = 0 : ElseIf py > ht - 1 : py = ht - 1 : EndIf
          value = PeekL(\addr[0] + (py * lg + px) << 2)
          sumB + (value & $FF) : sumA + ((value >> 24) & $FF) : countB + 1
        Next
        
        index = (y * lg + x) << 2
        value_src = PeekL(\addr[0] + index)
        
        ; Calcul des moyennes par canal
        r = sumR / countR
        g = sumG / countG
        b = sumB / countB
        a = sumA / (countR + countG + countB)
        
        ; Clamping rapide
        If r > 255 : r = 255 : EndIf : If g > 255 : g = 255 : EndIf
        If b > 255 : b = 255 : EndIf : If a > 255 : a = 255 : EndIf
        
        PokeL(\addr[1] + index, (a << 24) | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

Procedure AdvancedChromaticBokehBlurEx(*FilterCtx.FilterParams)
  Restore AdvancedChromaticBokehBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Bornage des options
    If \option[0] < 1 : \option[0] = 1 : EndIf
    If \option[1] < 3 : \option[1] = 3 : EndIf
    If \option[2] < 0 : \option[2] = 0 : EndIf
  EndWith
  
  Create_MultiThread_MT(@AdvancedChromaticBokehBlur_sp(), 1)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure AdvancedChromaticBokehBlur(source, cible, mask, radius, sides, chromaShift)
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  With FilterCtx
    \option[0] = radius : \option[1] = sides : \option[2] = chromaShift
  EndWith
  AdvancedChromaticBokehBlurEx(FilterCtx)
EndProcedure

DataSection
  AdvancedChromaticBokehBlur_data:
  Data.s "Advanced Chromatic Bokeh"
  Data.s "Flou polygonal avec simulation d'aberrations chromatiques par canal"
  Data.i #FilterType_Blur, #Blur_Optical
  Data.s "Rayon"
  Data.i 1, 50, 5
  Data.s "Côtés"
  Data.i 3, 12, 6
  Data.s "Chroma"
  Data.i 0, 10, 2
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 93
; FirstLine = 62
; Folding = -
; EnableXP
; DPIAware