; ---------------------------------------------------
; Chromatic Aberration Blur - Version optimisée
; Simule les franges colorées dues aux défauts de lentille
; ---------------------------------------------------

Macro ChromaticBokehBlur_sp0()
  dx = Random(chromaRange) - chroma
  dy = Random(chromaRange) - chroma
  px = x + dx
  py = y + dy
  clamp(px , 0 , lg_minus_1)
  clamp(py , 0 , ht_minus_1)
  value = *src\l[py * lg + px]
EndMacro

Procedure ChromaticBokehBlur_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0], chroma = \option[1]
    Protected x, y, i, samples = radius * radius
    Protected dx, dy, px, py, index, value
    Protected sumR, sumG, sumB, sumA, count
    Protected r, g, b, a
    Protected lg_minus_1 = lg - 1, ht_minus_1 = ht - 1
    Protected chromaRange = chroma * 2 + 1
    
    Protected *src.pixelarray = \addr[0]
    Protected *dst.pixelarray = \addr[1]
    
    ; Initialisation du générateur pour le thread (reproductibilité locale)
    RandomSeed((\thread_pos + 1) * 9876)
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        sumR = 0 : sumG = 0 : sumB = 0 : sumA = 0 : count = 0
        
        For i = 1 To samples
          ; --- Canal Rouge ---
          ChromaticBokehBlur_sp0()
          sumR + ((value >> 16) & $FF)
          ; --- Canal Vert ---
          ChromaticBokehBlur_sp0()
          sumG + ((value >> 8) & $FF)
          ; --- Canal Bleu ---
          ChromaticBokehBlur_sp0()
          sumB + (value & $FF)
          ; --- Canal Alpha (échantillonné au centre) ---
          value = *src\l[y * lg + x]
          sumA + ((value >> 24) & $FF)
          
          count + 1
        Next
        
        index = (y * lg + x)
        If count > 0
          a = sumA / count : r = sumR / count : g = sumG / count : b = sumB / count
          ; Clamping rapide
          If a > 255 : a = 255 : EndIf
          If r > 255 : r = 255 : EndIf
          If g > 255 : g = 255 : EndIf
          If b > 255 : b = 255 : EndIf
          *dst\l[index] =  (a << 24) | (r << 16) | (g << 8) | b
        Else
          *dst\l[index] = *src\l[index]
        EndIf
        If key_escape_press = 1 : Break 2 : EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure ChromaticBokehBlurEx(*FilterCtx.FilterParams)
  Restore ChromaticBokehBlur_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\asm_dispo = 0
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    If \option[0] < 1 : \option[0] = 1 : EndIf
    If \option[1] < 0 : \option[1] = 0 : EndIf
  EndWith
  
  Create_MultiThread_MT(@ChromaticBokehBlur_sp())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure ChromaticBokehBlur(source, cible, mask, radius, chromaShift)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = radius
    \option[1] = chromaShift
  EndWith
  ChromaticBokehBlurEx(FilterCtx)
EndProcedure

DataSection
  ChromaticBokehBlur_data:
  Data.s "Chromatic Bokeh  Blur"
  Data.s "Simule les franges colorées des objectifs via échantillonnage décalé"
  Data.i #FilterType_Blur, #Blur_Optical
  Data.s "Rayon"
  Data.i 1, 50, 10
  Data.s "Décalage Chroma"
  Data.i 0, 10, 2
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 47
; FirstLine = 55
; Folding = -
; EnableXP
; DPIAware