;==============================================================================
; HISTOGRAM EQUALIZATION - STRUCTURE RÉVISÉE
;==============================================================================

; --- ÉTAPE 1 : Construction des histogrammes (multi-thread) ---
Procedure Histogram_MT_BuildHistograms(*p.FilterParams)
  With *p
    Protected *source = \addr[0]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected total = lg * ht
    
    Protected start = (\thread_pos * total) / \thread_max
    Protected stop  = ((\thread_pos + 1) * total) / \thread_max
    
    Protected i, pix, r, g, b
    Protected Dim histR(255)
    Protected Dim histG(255)
    Protected Dim histB(255)
    
    For i = start To stop - 1
      pix = PeekL(*source + (i << 2))
      getrgb(pix, r, g, b)
      histR(r) + 1
      histG(g) + 1
      histB(b) + 1
    Next
    
    ; Fusion dans les buffers d'adresses 2, 3 et 4
    For i = 0 To 255
      PokeL(\addr[2] + (i << 2), PeekL(\addr[2] + (i << 2)) + histR(i))
      PokeL(\addr[3] + (i << 2), PeekL(\addr[3] + (i << 2)) + histG(i))
      PokeL(\addr[4] + (i << 2), PeekL(\addr[4] + (i << 2)) + histB(i))
    Next
  EndWith
EndProcedure

; --- ÉTAPE 4 : Application de l'égalisation (multi-thread) ---
Procedure Histogram_MT_ApplyEqualization(*p.FilterParams)
  With *p
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected total = lg * ht
    
    Protected minr = \option[4]
    Protected ming = \option[5]
    Protected minb = \option[6]
    Protected maxr = \option[7]
    Protected maxg = \option[8]
    Protected maxb = \option[9]
    
    Protected intensity.f
    
    If \option[1] ; Mode automatique
      Protected rangeR = maxr - minr
      Protected rangeG = maxg - ming
      Protected rangeB = maxb - minb
      Protected avgRange.f = (rangeR + rangeG + rangeB) / 3.0
      intensity = 1.0 - (avgRange / 255.0)
      If intensity < 0 : intensity = 0 : EndIf
      If intensity > 1 : intensity = 1 : EndIf
    Else ; Mode manuel
      intensity = (\option[0] - 100) / 100.0
    EndIf
    
    Protected start = (\thread_pos * total) / \thread_max
    Protected stop  = ((\thread_pos + 1) * total) / \thread_max
    
    Protected i, pix
    Protected ro, go, bo
    Protected r, g, b
    
    Protected denomR = maxr - minr : If denomR = 0 : denomR = 1 : EndIf
    Protected denomG = maxg - ming : If denomG = 0 : denomG = 1 : EndIf
    Protected denomB = maxb - minb : If denomB = 0 : denomB = 1 : EndIf
    
    Protected blendOrig.f = 1.0 - intensity
    Protected blendEqual.f = intensity
    
    For i = start To stop - 1
      pix = PeekL(*source + (i << 2))
      getrgb(pix, ro, go, bo)
      
      r = (PeekL(\addr[5] + (ro << 2)) - minr) * 255 / denomR
      g = (PeekL(\addr[6] + (go << 2)) - ming) * 255 / denomG
      b = (PeekL(\addr[7] + (bo << 2)) - minb) * 255 / denomB
      
      r = ro * blendOrig + r * blendEqual
      g = go * blendOrig + g * blendEqual
      b = bo * blendOrig + b * blendEqual
      
      clamp_rgb(r, g, b)
      PokeL(*cible + (i << 2), $FF000000 | (r << 16) | (g << 8) | b)
    Next
  EndWith
EndProcedure

Procedure HistogramEx(*FilterCtx.FilterParams)
  Restore Histogram_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Allocation des buffers pour histogrammes (256 * 4 bytes)
    \addr[2] = AllocateMemory(1024) ; Hist R
    \addr[3] = AllocateMemory(1024) ; Hist G
    \addr[4] = AllocateMemory(1024) ; Hist B
    \addr[5] = AllocateMemory(1024) ; Cumul R
    \addr[6] = AllocateMemory(1024) ; Cumul G
    \addr[7] = AllocateMemory(1024) ; Cumul B
    
    If \addr[2] And \addr[3] And \addr[4] And \addr[5] And \addr[6] And \addr[7]
      FillMemory(\addr[2], 1024, 0)
      FillMemory(\addr[3], 1024, 0)
      FillMemory(\addr[4], 1024, 0)
      
      ; Passe 1 : Comptage
      Create_MultiThread_MT(@Histogram_MT_BuildHistograms())
      
      ; Calcul des cumulés et Min/Max en séquentiel
      Protected i, r, g, b, cumulR, cumulG, cumulB
      Protected minr = $7FFFFFFF, ming = $7FFFFFFF, minb = $7FFFFFFF
      Protected maxr = 0, maxg = 0, maxb = 0
      
      For i = 0 To 255
        cumulR + PeekL(\addr[2] + (i << 2))
        cumulG + PeekL(\addr[3] + (i << 2))
        cumulB + PeekL(\addr[4] + (i << 2))
        PokeL(\addr[5] + (i << 2), cumulR)
        PokeL(\addr[6] + (i << 2), cumulG)
        PokeL(\addr[7] + (i << 2), cumulB)
        
        r = cumulR : g = cumulG : b = cumulB
        If r < minr : minr = r : EndIf : If r > maxr : maxr = r : EndIf
        If g < ming : ming = g : EndIf : If g > maxg : maxg = g : EndIf
        If b < minb : minb = b : EndIf : If b > maxb : maxb = b : EndIf
      Next
      
      \option[4] = minr : \option[5] = ming : \option[6] = minb
      \option[7] = maxr : \option[8] = maxg : \option[9] = maxb
      
      ; Passe 2 : Application
      Create_MultiThread_MT(@Histogram_MT_ApplyEqualization())
      
      mask_update(*FilterCtx, last_data)
    EndIf
    
    ; Libération mémoire
    For i = 2 To 7
      If \addr[i] : FreeMemory(\addr[i]) : \addr[i] = 0 : EndIf
    Next
  EndWith
EndProcedure

Procedure Histogram(source, cible, mask, intensite=100, modeAuto=0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensite
    \option[1] = modeAuto
  EndWith
  HistogramEx(FilterCtx)
EndProcedure

DataSection
  Histogram_Data:
  Data.s "Histogram Equalization"
  Data.s "Égalisation d'histogramme pour améliorer le contraste"
  Data.i #FilterType_Artistic, #Artistic_Other
  Data.s "Intensité" : Data.i 0, 200, 100
  Data.s "Mode auto (0=Manuel/1=Auto)" : Data.i 0, 1, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 156
; FirstLine = 124
; Folding = -
; EnableXP
; DPIAware