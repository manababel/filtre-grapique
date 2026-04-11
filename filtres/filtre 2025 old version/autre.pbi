; Procédure thread pour l'effet "Charcoal" sur une image ARGB 32 bits

Procedure.f RandomFloat(min.f=0.0, max.f=1.0)
  ProcedureReturn min + (max - min) * Random(1000000) / 1000000.0
EndProcedure


Procedure ContrastColour(Colour,Scale.f)
  ; ContrastPixel(Red(Colour),Scale)
  ;Return Int(Float((Pixel*Scale))) 
  Protected r ,g , b
  getrgb(Colour , r , g , b)
  r = r * (1.0 + Scale)
  g = g * (1.0 + Scale)
  b = b * (1.0 + Scale)
  clamp_rgb(r , g , b)
  ProcedureReturn ((r << 16) + ( g << 8) + b)
EndProcedure

Procedure Charcoal_MT(*p.parametre)
  Protected i, x, y, pixel, a, r, g , b
  Protected r1 , g1 , b1
  Protected r2 , g2 , b2
  Protected w = *p\lg
  Protected h = *p\ht
  Protected intensity.f = 0.32 + (*p\option[0] / 100) ; 0.32 to 0.49
  Protected tolerance.f = 1.0 - intensity
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected totalPixels = w * h
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  Protected col, grey, grade
  
  Protected Definition.f
  Protected Colour
  Protected Chalking
  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)   
    Colour = *srcPixel\l
    getrgb(Colour , r , g , b)
    Chalking = ((r * 1225 + g * 2405 + b * 466) >> 12)
    grade = intensity * 64.0
    If Chalking > (255.0 - grade)
      r = 255 : g = 255 : b = 255
    Else
      getrgb(Colour , r1 , g1 , b1)
      r1 = r1 * (1.0 + Intensity)
      g1 = g1 * (1.0 + Intensity)
      b1 = b1 * (1.0 + Intensity)
      clamp_rgb(r1 , g1 , b1)
      Colour = ((r1 << 16) + ( g1 << 8) + b1)
      Definition = RandomFloat(0,1)
      If (Definition>Tolerance)
        getrgb(Pixel , r1 , g1 , b1)
        getrgb(Colour , r2 , g2 , b2)
        r1 = ((r2 - r1) * Tolerance) + r1
        clamp_rgb(r1 , g1 , b1)
        Pixel = ((r1 << 16) + ( g1 << 8) + b1)
      EndIf
      getrgb(Pixel , r , g , b)
      Grey = ((r * 1225 + g * 2405 + b * 466) >> 12)
      r = grey : g = r : b = r
      Grade=(Intensity*64)
      If (grey > grade) And (grey < (255.0 - grade))
        If RandomFloat(0 , 100) >= Int(tolerance * 100.0)
          r + grade
          g + grade * 0.5
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
  Next
EndProcedure

Procedure CharcoalImage(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_autre
    param\name = "Charcoal"
    param\remarque = ""
    param\info[0] = "Intensité"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 17 : param\info_data(0,2) = 8
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Charcoal_MT() , 1)
EndProcedure



;--------------


Procedure Emboss_MT(*p.parametre)
  Protected x, y
  Protected w = *p\lg
  Protected h = *p\ht
  Protected a1, r1, g1, b1
  Protected a2, r2, g2, b2
  Protected r, g, b
  Protected gray1, gray2, diff
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected contrast = *p\option[0]
  Protected direction = *p\option[1]
  Protected renforcer = *p\option[2]
  Protected inversion = *p\option[3]
  

  ; Clamp du contraste pour éviter les débordements
  clamp(contrast, 1, 1024)

  ; Détermination direction du relief
  Protected dx, dy
  Select direction
    Case 0 : dx = 1 : dy = 1   ; ↘ Bas-droite
    Case 1 : dx = 0 : dy = 1   ; ↓ Bas
    Case 2 : dx = 1 : dy = 0   ; → Droite
    Case 3 : dx = -1 : dy = -1 ; ↖ Haut-gauche
    Case 4 : dx = 0 : dy = -1  ; ↑ Haut
    Case 5 : dx = -1 : dy = 0  ; ← Gauche
    Default : dx = 1 : dy = 1
  EndSelect

  ; Calcul des limites verticales pour multithreading
  Protected startY = (*p\thread_pos * h) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * h) / *p\thread_max

  Protected x2, y2, index, index2, dot.f, lx.f, ly.f, len.f

  ; Traitement
  For y = startY To endY - 1
    For x = 0 To w - 1
      x2 = x + dx
      y2 = y + dy
      If x2 < 0 Or x2 >= w Or y2 < 0 Or y2 >= h : Continue : EndIf

      index  = y  * w + x
      index2 = y2 * w + x2

      *srcPixel = *p\addr[0] + (index << 2)
      GetARGB(*srcPixel\l, a1, r1, g1, b1)

      *srcPixel = *p\addr[0] + (index2 << 2)
      GetARGB(*srcPixel\l, a2, r2, g2, b2)
      gray1 = ((r1 + g1 + b1) * 85) >> 8
      gray2 = ((r2 + g2 + b2) * 85) >> 8
      If inversion
        If renforcer
          diff = 128 - ((gray1 - gray2) * (contrast << 2)) >> 8
        Else
          diff = 128 - ((gray1 - gray2) * contrast) >> 7
        EndIf
      Else
        If renforcer
          diff = ((gray1 - gray2) * (contrast << 2)) >> 8 + 128
        Else
          diff = ((gray1 - gray2) * contrast) >> 7 + 128
        EndIf
      EndIf
      clamp(diff, 0, 255)
      *dstPixel = *p\addr[1] + (index << 2)
      *dstPixel\l = (a1 << 24) | (diff << 16) | (diff << 8) | diff
    Next
  Next
EndProcedure


; Procédure principale d'effet Emboss (relief directionnel)

Procedure Emboss(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_autre
    param\name = "Emboss"
    param\remarque = "Emboss (relief directionnel niveaux de gris)"
    param\info[0] = "Contraste"
    param\info[1] = "Direction"
    param\info[2] = "Renforcer"
    param\info[3] = "Inversion"
    param\info[4] = "Masque binaire"
    param\info_data(0,0) = 0    : param\info_data(0,1) = 1024 : param\info_data(0,2) = 512
    param\info_data(1,0) = 0    : param\info_data(1,1) = 5    : param\info_data(1,2) = 0
    param\info_data(2,0) = 0    : param\info_data(2,1) = 1    : param\info_data(2,2) = 0
    param\info_data(3,0) = 0    : param\info_data(3,1) = 1    : param\info_data(3,2) = 0
    param\info_data(4,0) = 0   : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Emboss_MT() , 4)
EndProcedure

;--------------

Macro GlowEffect_IIR_Declare()
  Protected w = *param\lg
  Protected h = *param\ht
  Protected start = (*param\thread_pos * h) / *param\thread_max
  Protected stop   = ((*param\thread_pos + 1) * h) / *param\thread_max
  Protected x, y, pos , col
  Protected a , r, g, b, lum
  Protected GlowStrength = *param\option[0]
  Protected Radius = 50 - *param\option[1]
  Protected seuil = param\option[2]
  Protected Alpha, inv_Alpha, mul = 256
  Alpha = (Exp(-2.3 / (Radius + 1.0))) * mul
  inv_Alpha = mul - Alpha
  Protected glowR = *param\addr[2]
  Protected glowG = *param\addr[3]
  Protected glowB = *param\addr[4]
EndMacro

Macro GlowEffect_IIR_sp1()
  ;r = (Alpha * r + inv_Alpha * glowR(pos)) >> 8
  ;g = (Alpha * g + inv_Alpha * glowG(pos)) >> 8
  ;b = (Alpha * b + inv_Alpha * glowB(pos)) >> 8
  ;glowR(pos) = r : glowG(pos) = g : glowB(pos) = b
  r = (Alpha * r + inv_Alpha * PeekL(glowR + pos)) >> 8
  g = (Alpha * g + inv_Alpha * PeekL(glowG + pos)) >> 8
  b = (Alpha * b + inv_Alpha * PeekL(glowB + pos)) >> 8
  PokeL((glowR + pos) , r)
  PokeL((glowG + pos) , g)
  PokeL((glowB + pos) , b)
EndMacro

Procedure GlowEffect_IIR_MT_sp1(*param.parametre)
  ; 1. Extraire les zones lumineuses
  GlowEffect_IIR_Declare()
  For y = start To stop - 1
    For x = 0 To w - 1
      pos = (y * w + x) << 2
      col = PeekL(*param\addr[0] + pos)
      getrgb(col , r , g , b)
      lum = ((r + g + b) * 85) >> 8
      If lum > seuil ; seuil de brillance
        PokeL((glowR + pos) , r)
        PokeL((glowG + pos) , g)
        PokeL((glowB + pos) , b)
        ;glowR(pos) = r
        ;glowG(pos) = g
        ;glowB(pos) = b
      Else
        PokeL((glowR + pos) , 0)
        PokeL((glowG + pos) , 0)
        PokeL((glowB + pos) , 0)
        ;glowR(pos) = 0
        ;glowG(pos) = 0
        ;glowB(pos) = 0
      EndIf
    Next
  Next
EndProcedure

Procedure GlowEffect_IIR_MT_spx(*param.parametre)
  GlowEffect_IIR_Declare()
  ; 2. Flou IIR horizontal
  For y = start To stop - 1
    pos = (y * w) << 2
    ;r = glowR(pos) : g = glowG(pos) : b = glowB(pos)
    r = PeekL(glowR + pos)
    g = PeekL(glowG + pos)
    b = PeekL(glowB + pos)
    For x = 1 To w - 1
      pos = (y * w + x) << 2
      GlowEffect_IIR_sp1()
    Next
    pos = (y * w + (w - 1)) << 2
    ;r = glowR(pos) : g = glowG(pos) : b = glowB(pos)
    r = PeekL(glowR + pos)
    g = PeekL(glowG + pos)
    b = PeekL(glowB + pos)
    For x = w - 2 To 0 Step -1
      pos = (y * w + x) << 2
      GlowEffect_IIR_sp1()
    Next
  Next
EndProcedure

Procedure GlowEffect_IIR_MT_spy(*param.parametre)
  ; 3. Flou IIR vertical
  GlowEffect_IIR_Declare()
  start = (*param\thread_pos * w) / *param\thread_max
  stop   = ((*param\thread_pos + 1) * w) / *param\thread_max
  For x = start To stop - 1
    pos = x << 2
    ;r = glowR(pos) : g = glowG(pos) : b = glowB(pos)
    r = PeekL(glowR + pos)
    g = PeekL(glowG + pos)
    b = PeekL(glowB + pos)
    For y = 1 To h - 1
      pos = (y * w + x) << 2
     GlowEffect_IIR_sp1()
    Next
    pos = ((h - 1) * w + x) << 2
    ;r = glowR(pos) : g = glowG(pos) : b = glowB(pos)
    r = PeekL(glowR + pos)
    g = PeekL(glowG + pos)
    b = PeekL(glowB + pos)
    For y = h - 2 To 0 Step -1
      pos = (y * w + x) << 2
      GlowEffect_IIR_sp1()
    Next
  Next
EndProcedure


Procedure GlowEffect_IIR_MT(*param.parametre)
  GlowEffect_IIR_Declare() 
  ; 4. Additionner le glow à l'image d’origine
  For y = start To stop - 1
    For x = 0 To w - 1
      pos = (y * w + x) << 2
      col = PeekL(*param\addr[0] + pos )
        r = ((col >> 16) & $FF) + (PeekL(glowR + pos) * GlowStrength) >> 4
        g = ((col >> 8) & $FF)  + (PeekL(glowG + pos) * GlowStrength) >> 4
        b = (col & $FF)         + (PeekL(glowB + pos) * GlowStrength) >> 4
      clamp_rgb(r,g,b)
      PokeL(*param\addr[1] + pos , (r << 16) | (g << 8) | b)
    Next
  Next
EndProcedure

Procedure GlowEffect_IIR(*param.parametre)
  If *param\info_active
    param\typ = #Filter_Type_autre
    param\name = "GlowEffect_IIR"
    param\remarque = ""
    *param\info[0] = "GlowStrength"
    *param\info[1] = "Radius"
    *param\info[2] = "seuil"
    *param\info[3] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 10
    param\info_data(1,0) = 0 : param\info_data(1,1) = 50 : param\info_data(1,2) = 0
    param\info_data(2,0) = 0 : param\info_data(2,1) = 255 : param\info_data(2,2) = 127
    param\info_data(3,1) = 0 : param\info_data(3,1) = 2  : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  Protected total = *param\lg * *param\ht * 4
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected *glowR = AllocateMemory(total)
  Protected *glowG = AllocateMemory(total)
  Protected *glowB = AllocateMemory(total)
  
  Protected *tempo
  If *param\source = *param\cible
    *tempo = AllocateMemory(total)
    If Not *tempo : ProcedureReturn : EndIf
    CopyMemory(*param\source , *tempo , total)
    *param\addr[0] = *tempo
  Else
    *param\addr[0] = *param\source
  EndIf
  
  *param\addr[1] = *param\cible
  *param\addr[2] = *glowR
  *param\addr[3] = *glowG
  *param\addr[4] = *glowB
  
  MultiThread_MT(@GlowEffect_IIR_MT_sp1())
  MultiThread_MT(@GlowEffect_IIR_MT_spx())
  MultiThread_MT(@GlowEffect_IIR_MT_spy())
  MultiThread_MT(@GlowEffect_IIR_MT())
  
  ; Application d’un second passage pour le masque alpha (optionnel)
  If *param\mask And *param\option[3] : *param\mask_type = *param\option[3] - 1 : MultiThread_MT(@_mask()) : EndIf
  
  FreeMemory(*glowR)
  FreeMemory(*glowG)
  FreeMemory(*glowB)
  If *tempo : FreeMemory(*tempo) : EndIf
EndProcedure

;--------------


Procedure Histogram_SP1_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected lg  = *param\lg
  Protected ht  = *param\ht
  Protected total = lg * ht
  
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  
  Protected i, pix, r, g, b
  
  ; Histogrammes locaux (par thread)
  Protected Dim histR(255)
  Protected Dim histG(255)
  Protected Dim histB(255)
  
  ; Comptage local
  For i = start To stop - 1
    pix = PeekL(*source + i * 4)
    getrgb(pix, r, g, b)
    histR(r) + 1
    histG(g) + 1
    histB(b) + 1
  Next
  
  ; Fusion (ajout dans les histogrammes globaux)
  For i = 0 To 255
    PokeL(*param\addr[2] + i * 4, PeekL(*param\addr[2] + i * 4) + histR(i))
    PokeL(*param\addr[3] + i * 4, PeekL(*param\addr[3] + i * 4) + histG(i))
    PokeL(*param\addr[4] + i * 4, PeekL(*param\addr[4] + i * 4) + histB(i))
  Next
EndProcedure


Procedure Histogram_SP2_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg  = *param\lg
  Protected ht  = *param\ht
  Protected total = lg * ht
  
  Protected minr = *param\option[4]
  Protected ming = *param\option[5]
  Protected minb = *param\option[6]
  Protected maxr = *param\option[7]
  Protected maxg = *param\option[8]
  Protected maxb = *param\option[9]
  
  Protected intensity.f
  If *param\option[1] ; mode automatique
    Protected rangeR = maxr - minr
    Protected rangeG = maxg - ming
    Protected rangeB = maxb - minb
    Protected avgRange = (rangeR + rangeG + rangeB) / 3
    intensity = 1.0 - (avgRange / 255.0) ; <-- Vérifier si c'est bien ce que tu veux
    clamp(intensity , 0 , 1)
  Else
    intensity = (*param\option[0] - 100) / 100.0
  EndIf
  
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  
  Protected i, pix, ro, go, bo
  Protected r, g, b
  
  For i = start To stop - 1
    pix = PeekL(*source + i * 4)
    getrgb(pix, ro, go, bo)
    
    Protected denomR = maxr - minr : If denomR = 0 : denomR = 1 : EndIf
    Protected denomG = maxg - ming : If denomG = 0 : denomG = 1 : EndIf
    Protected denomB = maxb - minb : If denomB = 0 : denomB = 1 : EndIf
    
    r = (PeekL(*param\addr[5] + ro * 4) - minr) * 255 / denomR
    g = (PeekL(*param\addr[6] + go * 4) - ming) * 255 / denomG
    b = (PeekL(*param\addr[7] + bo * 4) - minb) * 255 / denomB
    
    ; Mix avec couleur originale selon intensité
    r = ro * (1.0 - intensity) + r * intensity
    g = go * (1.0 - intensity) + g * intensity
    b = bo * (1.0 - intensity) + b * intensity
    
    clamp_rgb(r, g, b)
    PokeL(*cible + i * 4, (r << 16) | (g << 8) | b)
  Next
EndProcedure

; ---------------- Procédure principale ----------------
Procedure Histogram(*param.parametre)
  If *param\info_active
    *param\name = "Histogram"
    *param\typ  = #Filter_Type_autre
    *param\remarque = ""
    *param\info[0] = "Intensité"
    *param\info[1] = "Mode auto"
    *param\info[2] = "Masque"
    *param\info_data(0,0)=0 : *param\info_data(0,1)=200 : *param\info_data(0,2)=100
    *param\info_data(1,0)=0 : *param\info_data(1,1)=1 : *param\info_data(1,2)=0
    *param\info_data(2,0)=0 : *param\info_data(2,1)=2 : *param\info_data(2,2)=0
    ProcedureReturn
  EndIf
  
  If *param\source=0 Or *param\cible=0 : ProcedureReturn : EndIf
  Protected i, r, g, b
  Protected minr, ming, minb
  Protected maxr, maxg, maxb
  
  Protected *tempo
  If *param\source = *param\cible
    *tempo = AllocateMemory(*param\lg * *param\ht * 4)
    If Not *tempo : ProcedureReturn : EndIf
    CopyMemory(*param\source , *tempo , *param\lg * *param\ht * 4)
    *param\addr[0] = *tempo
  Else
    *param\addr[0] = *param\source
  EndIf
  
  *param\addr[1] = *param\cible
  
; Allocation pour histogrammes par canal (valeurs Long)
*param\addr[2] = AllocateMemory(256 * 4) ; Histogramme R
*param\addr[3] = AllocateMemory(256 * 4) ; Histogramme G
*param\addr[4] = AllocateMemory(256 * 4) ; Histogramme B
  
; Allocation pour histogrammes cumulés
*param\addr[5] = AllocateMemory(256 * 4)
*param\addr[6] = AllocateMemory(256 * 4)
*param\addr[7] = AllocateMemory(256 * 4)
  
  ; Étape 1 - Construire les histogrammes
  MultiThread_MT(@Histogram_SP1_MT())
  
  ; Étape 2 - Cumul
  Protected cumulR, cumulG, cumulB
  cumulR = 0 : cumulG = 0 : cumulB = 0
  For i = 0 To 255
    cumulR + PeekL(*param\addr[2] + i * 4)
    cumulG + PeekL(*param\addr[3] + i * 4)
    cumulB + PeekL(*param\addr[4] + i * 4)
    
    PokeL(*param\addr[5] + i * 4, cumulR)
    PokeL(*param\addr[6] + i * 4, cumulG)
    PokeL(*param\addr[7] + i * 4, cumulB)
  Next
  
  ; Étape 3 - Min / Max
  minr = $7FFFFFFF : ming = $7FFFFFFF : minb = $7FFFFFFF
  maxr = 0 : maxg = 0 : maxb = 0
  
  For i = 0 To 255
    r = PeekL(*param\addr[5] + i * 4)
    g = PeekL(*param\addr[6] + i * 4)
    b = PeekL(*param\addr[7] + i * 4)
    
    If r < minr : minr = r : EndIf
    If g < ming : ming = g : EndIf
    If b < minb : minb = b : EndIf
    
    If r > maxr : maxr = r : EndIf
    If g > maxg : maxg = g : EndIf
    If b > maxb : maxb = b : EndIf
  Next
  
  *param\option[4] = minr
  *param\option[5] = ming
  *param\option[6] = minb
  *param\option[7] = maxr
  *param\option[8] = maxg
  *param\option[9] = maxb  
  
  ; Étape 4 - Normalisation finale
  MultiThread_MT(@Histogram_SP2_MT())
  
  If *param\mask And *param\option[2] : *param\mask_type = *param\option[2] - 1 : MultiThread_MT(@_mask()) : EndIf
  
  ; Nettoyage
  FreeMemory(*param\addr[2])
  FreeMemory(*param\addr[3])
  FreeMemory(*param\addr[4])
  FreeMemory(*param\addr[5])
  FreeMemory(*param\addr[6])
  FreeMemory(*param\addr[7])
  If *tempo : FreeMemory(*tempo) : EndIf
EndProcedure

;--------------

; --- Macro d'init commune (pixel déclaré et clamp start/stop) ---
Macro pencil_Blur_IIR_int(var)
  Protected *pix32.pixel32
  Protected *dst32.pixel32 = *param\addr[0]
  Protected lg       = *param\lg
  Protected ht       = *param\ht
  Protected alpha    = Int(Exp(-2.3 / *param\option[0]) * 256 + 0.5)
  Protected inv_alpha= 256 - alpha
  Protected x, y ,pos , mem
  Protected r, g, b
  Protected r1, g1, b1
  Protected start = (*param\thread_pos * var) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * var) / *param\thread_max
  If start < 0 : start = 0 : EndIf
  If stop  > var : stop = var : EndIf
EndMacro

Macro pencil_Blur_IIR_sp0(r , g , b)
  *pix32 = *dst32 + (pos * 4)
  getrgb(*pix32\l ,r , g , b) 
  r = r << 8
  g = g << 8
  b = b << 8
EndMacro

Macro pencil_Blur_IIR_sp1()
  pencil_Blur_IIR_sp0(r1 , g1 , b1)
  r = (r * alpha + inv_alpha * r1) >> 8 
  g = (g * alpha + inv_alpha * g1) >> 8
  b = (b * alpha + inv_alpha * b1) >> 8
  r1 = (r + 128 ) >> 8
  g1 = (g + 128 ) >> 8
  b1 = (b + 128 ) >> 8
  *pix32\l = (r1 << 16) | (g1 << 8) | b1
EndMacro

Procedure pencil_Blur_IIR_y_MT(*param.parametre)
  pencil_Blur_IIR_int(*param\ht)
  For y = start To stop - 1               ; Parcourt les lignes de haut en bas
    pos = (y * lg)
    mem = pos 
    pencil_Blur_IIR_sp0(r , g , b)
    For x = 1 To lg - 1 : pos = (mem + x) : pencil_Blur_IIR_sp1() : Next ; Gauche → droite
    pos = (mem + (lg - 1))
    pencil_Blur_IIR_sp0(r , g , b)
    For x = lg - 2 To 0 Step -1 : pos = (y * lg + x) : pencil_Blur_IIR_sp1() : Next ; Droite → gauche
  Next
EndProcedure

Procedure pencil_Blur_IIR_x_MT(*param.parametre)
  pencil_Blur_IIR_int(*param\lg)
  For x = start To stop - 1               ; Parcourt les colonnes de gauche à droite
    pos = x 
    pencil_Blur_IIR_sp0(r , g , b)
    For y = 1 To ht - 1 : pos = (y * lg + x) : pencil_Blur_IIR_sp1() : Next ; Haut → bas
    pos = ((ht - 1) * lg + x) 
    pencil_Blur_IIR_sp0(r , g , b)
    For y = ht - 2 To 0 Step -1 : pos = (y * lg + x) : pencil_Blur_IIR_sp1() : Next ; Bas → haut
  Next
EndProcedure

;--
Procedure pencil_Guillossien_MT(*param.parametre)
  ; Déclarations de pointeurs pixel source/destination
  Protected *srcPixel1.Pixel32
  Protected *srcPixel2.Pixel32
  Protected *dstPixel.Pixel32
  ; Accumulateurs pour composantes ARGB
  Protected ax1, rx1, gx1, bx1
  Protected a1.l, r1.l, b1.l, g1.l
  Protected a2.l, r2.l, b2.l, g2.l
  ; Index temporaires
  Protected j, i, p1, p2
  ; Paramètres de l’image
  Protected *cible = *param\cible
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected *tempo = *param\addr[0]
  Protected lx = *param\addr[1]
  Protected ly = *param\addr[2]
  ; Paramètres du filtre
  Protected nrx = param\option[17] ; Largeur de la fenêtre de flou (X)
  Protected nry = param\option[18] ; Hauteur de la fenêtre de flou (Y)
  Protected div = param\option[19] ; Facteur de division (65536 / (nrx * nry))
  ; Informations de thread (multi-threading horizontal)
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected startPos = (thread_pos * ht) / thread_max
  Protected endPos   = ((thread_pos + 1) * ht) / thread_max - 1
  ; Buffers pour accumuler les sommes par colonne
  Protected Dim a.l(lg)
  Protected Dim r.l(lg)
  Protected Dim g.l(lg)
  Protected Dim b.l(lg)
  ; Initialisation des buffers
  FillMemory(@a(), lg * 4, 0)
  FillMemory(@r(), lg * 4, 0)
  FillMemory(@g(), lg * 4, 0)
  FillMemory(@b(), lg * 4, 0)
  ; === Étape 1 : Accumule les lignes verticales pour démarrer ===
  For j = 0 To nry - 1
    p1 = PeekL(ly + (j + startPos) * 4)
    *srcPixel1 = *cible + ((p1 * lg) << 2)
    For i = 0 To lg - 1
      getargb(*srcPixel1\l, a1, r1, g1, b1)
      a(i) + a1 : r(i) + r1 : g(i) + g1 : b(i) + b1
      *srcPixel1 + 4
    Next
  Next
  ; === Étape 2 : Application du filtre pour chaque ligne ===
  For j = startPos To endPos
    ; Mise à jour du buffer colonne (soustraction d’une ancienne ligne et ajout d’une nouvelle)
    p1 = PeekL(ly + (nry + j) * 4)
    p2 = PeekL(ly + (j * 4))
    *srcPixel1 = *cible + (p1 * lg) << 2
    *srcPixel2 = *cible + (p2 * lg) << 2
    For i = 0 To lg - 1
      getargb(*srcPixel1\l, a1, r1, g1, b1)
      getargb(*srcPixel2\l, a2, r2, g2, b2)
      a(i) + a1 - a2 : r(i) + r1 - r2 : g(i) + g1 - g2 : b(i) + b1 - b2
      *srcPixel1 + 4
      *srcPixel2 + 4
    Next
    ; Application du filtre horizontal
    ax1 = 0 : rx1 = 0 : gx1 = 0 : bx1 = 0
    For i = 0 To nrx - 1
      p1 = PeekL(lx + i * 4)
      ax1 + a(p1) : rx1 + r(p1) : gx1 + g(p1) : bx1 + b(p1)
    Next
    ; Boucle de sortie pour chaque pixel de la ligne
    For i = 0 To lg - 1
      p1 = PeekL(lx + (nrx + i) * 4)
      p2 = PeekL(lx + i * 4)
      ax1 + a(p1) - a(p2) : rx1 + r(p1) - r(p2) : gx1 + g(p1) - g(p2) : bx1 + b(p1) - b(p2)
      ; Calcul final avec facteur de division
      a1 = (ax1 * div) >> 16 : r1 = (rx1 * div) >> 16 : g1 = (gx1 * div) >> 16 : b1 = (bx1 * div) >> 16
      ; Écriture dans le buffer temporaire
      *dstPixel = *tempo + ((j * lg + i) << 2)
      *dstPixel\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
    Next
  Next
  ; Libération des tableaux
  FreeArray(a())
  FreeArray(r())
  FreeArray(g())
  FreeArray(b())
EndProcedure

;--

Macro pencil_sobel_4d_sp(i)
  getrgb(PeekL(pos + 0) ,  r , g , b)
  p(i + 0 ) = ((r * 76 + g * 150 + b * 30) >> 8)
  getrgb(PeekL(pos + 4) ,  r , g , b)
  p(i + 1 ) = ((r * 76 + g * 150 + b * 30) >> 8)
  getrgb(PeekL(pos + 8) ,  r , g , b)
  p(i + 2 ) = ((r * 76 + g * 150 + b * 30) >> 8)
EndMacro


Procedure pencil_sobel_4d_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected mul.f = *param\option[3]
  Protected pos , f
  Protected r , g , b
  Protected c0 , c45 , c90 , c135
  Protected cx0 , cx45 , cx90 , cx135
  Protected cy0 , cy45 , cy90 , cy135
  clamp(mul, 0, 100)
  mul = mul * 0.1
  Protected x, y
  Protected Dim p(8)
  
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max
  If startPos < 1 : startPos = 1 : EndIf
  
  For y = startPos To endPos
    For x = 1 To lg - 2
      
      ; Lecture des 9 pixels (3x3 autour du pixel courant)
      pos = *source + ((y - 1) * lg + (x - 1)) * 4
      pencil_sobel_4d_sp(0)
        
      pos = *source + (y * lg + (x - 1)) * 4
      pencil_sobel_4d_sp(3)
      
      pos = *source + ((y + 1) * lg + (x - 1)) * 4
      pencil_sobel_4d_sp(6)
      
      ; --- Sobel 0° ---
      cx0 = p(2) + 2 * p(5) + p(8) - (p(0) + 2 * p(3) + p(6))
      cy0 = p(0) + 2 * p(1) + p(2) - (p(6) + 2 * p(7) + p(8))
      
      ; --- Sobel 45° ---
      cx45 = p(0) + 2 * p(1) + p(2) - (p(6) + 2 * p(7) + p(8))
      cy45 = p(2) + 2 * p(5) + p(8) - (p(0) + 2 * p(3) + p(6))
      
      ; --- Sobel 90° ---
      cx90 = p(6) + 2 * p(7) + p(8) - (p(0) + 2 * p(1) + p(2))
      cy90 = p(2) + 2 * p(5) + p(8) - (p(0) + 2 * p(3) + p(6))
      
      ; --- Sobel 135° ---
      cx135 = p(6) + 2 * p(3) + p(0) - (p(8) + 2 * p(5) + p(2))
      cy135 = p(0) + 2 * p(3) + p(6) - (p(2) + 2 * p(5) + p(8))
      
      ; Magnitudes
      c0    = Sqr(cx0   * cx0   + cy0   * cy0)
      c45   = Sqr(cx45  * cx45  + cy45  * cy45)
      c90   = Sqr(cx90  * cx90  + cy90  * cy90)
      c135  = Sqr(cx135 * cx135 + cy135 * cy135)
      
      ; Max
      max4(f , c0 , c45 , c90 , c135)
      f * mul
      clamp(f, 0, 255)
      PokeL(*cible + (y * lg + x) * 4, (255-f) * $10101)
      
    Next
  Next
EndProcedure

; --

Procedure pencil_color_dodge(*param.parametre)
  Protected *dodge = *param\addr[0]
  Protected *blur  = *param\addr[1]
  Protected *cible = *param\addr[2]
  Protected lg     = *param\lg
  Protected ht     = *param\ht
  Protected total  = lg * ht
  
  Protected intensity = (*param\option[1] * 255) / 100
  Protected gamma.f   = *param\option[2] * 0.1
  
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  If stop > total : stop = total : EndIf
  
  Protected i, pos
  Protected r, g, b
  Protected r1, g1, b1
  Protected r2, g2, b2
  Protected r3, g3, b3
  
  Protected Dim GammaLUT(255)
  
  ; --- Pré-calcul de la LUT gamma ---
  For i = 0 To 255
    GammaLUT(i) = Int(255.0 * Pow(i / 255.0, gamma))
    clamp(GammaLUT(i), 0, 255)
  Next
  
  ; --- Boucle principale ---
  For i = start To stop - 1
    pos = i << 2
    
    getrgb(PeekL(*dodge + pos), r1, g1, b1)
    getrgb(PeekL(*blur  + pos), r2, g2, b2)
    
    ; Inversion
    r3 = 255 - r1 : If r3 < 1 : r3 = 1 : EndIf
    g3 = 255 - g1 : If g3 < 1 : g3 = 1 : EndIf
    b3 = 255 - b1 : If b3 < 1 : b3 = 1 : EndIf
    
    ; Division (Color Dodge)
    r = (r2 << 8) / r3
    g = (g2 << 8) / g3
    b = (b2 << 8) / b3
    
    ; Application intensité
    r = (r * intensity) >> 8
    g = (g * intensity) >> 8
    b = (b * intensity) >> 8
    
    clamp_rgb(r, g, b)
    
    ; Application gamma via LUT
    r = GammaLUT(r)
    g = GammaLUT(g)
    b = GammaLUT(b)
    
    PokeL(*cible + pos, (r << 16) | (g << 8) | b)
  Next
  
  FreeArray(GammaLUT())
EndProcedure


Procedure pencil_gray_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg      = *param\lg
  Protected ht      = *param\ht
  Protected total   = lg * ht
  
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  If stop > total : stop = total : EndIf
  
  Protected i, lum, a, r, g, b
  
  For i = start To stop - 1
    getargb(PeekL(*source + (i << 2)), a, r, g, b)
    lum = ((r * 76 + g * 150 + b * 30) >> 8)
    PokeL(*cible + (i << 2), lum * $10101) ; Écrit R=G=B=lum
  Next
EndProcedure

Procedure pencil( *param.parametre )
  ; Mode interface : renseigner les informations sur les options si demandé
  If param\info_active
    param\typ = #Filter_Type_autre
    param\name = "pencil"
    param\remarque = ""
    param\info[0] = "option 1"          
    param\info[1] = "intensité mellange"       
    param\info[2] = "gamma"   
    param\info[3] = "intensité contour"  
    param\info[4] = "Style du crayon"
    param\info[5] = "Masque binaire" 
    param\info_data(0,0) = 1 : param\info_data(0,1) = 80 : param\info_data(0,2) = 3
    param\info_data(1,0) = 1 : param\info_data(1,1) = 100 : param\info_data(1,2) = 10
    param\info_data(2,0) = 1 : param\info_data(2,1) = 100   : param\info_data(2,2) = 10
    param\info_data(3,0) = 1 : param\info_data(3,1) = 100   : param\info_data(3,2) = 10
    param\info_data(4,0) = 0 : param\info_data(4,1) = 9   : param\info_data(4,2) = 0
    param\info_data(5,0) = 0 : param\info_data(5,1) = 2   : param\info_data(5,2) = 0
    ProcedureReturn
  EndIf
  
  Protected i 
  Protected *source = *param\source
  Protected *cible = *param\cible
  Protected *mask = *param\mask
  Protected lg = *param\lg
  Protected ht = *param\ht
  If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf
  
  
  Protected *gray= AllocateMemory(lg * ht * 4)
  Protected *blur = AllocateMemory(lg * ht * 4)
  Protected *sobel = AllocateMemory(lg * ht * 4)
  Protected *tmp = AllocateMemory(lg * ht * 4)
  
  Protected thread = CountCPUs(#PB_System_CPUs)
  clamp(thread , 1 , 128)
  Protected Dim tr(thread)
  
  
  Protected *tempo
  If *source = *cible
    *tempo = AllocateMemory(lg * ht * 4)
    If Not *tempo : ProcedureReturn :EndIf
    CopyMemory(*source , *tempo , lg * ht * 4)
    *param\addr[0] = *tempo
  Else
    *param\addr[0] = *source
  EndIf
  *param\addr[1] = *gray
  MultiThread_MT(@pencil_gray_MT())
  
  If blur_box_create_limit(lg, ht, 3, 3, 0)
    ;Pré-filtrage ou Post-traitement optionnel : blurbox 2 pass
    Protected *tempo2 = AllocateMemory(lg * ht * 4)
    ; Passage des paramètres au thread de travail
    param\addr[0] = *tempo2
    param\addr[1] = *blur_box_limit_x
    param\addr[2] = *blur_box_limit_y
    param\option[17] = 3
    param\option[18] = 3
    param\option[19] = Int(65536 / (3 * 3)) ; Facteur normalisation
    Protected passe                                         ; Boucle de passes de flou (1 à 3)
    For passe = 1 To 2
      MultiThread_MT(@pencil_Guillossien_MT())
      CopyMemory(*tempo2, *cible, lg * ht * 4)
    Next
    blur_box_free_limit()
  EndIf
  
  CopyMemory(*gray , *blur , lg * ht * 4)
  *param\addr[0] = *blur
  MultiThread_MT(@pencil_Blur_IIR_y_MT())
  MultiThread_MT(@pencil_Blur_IIR_x_MT())
  
  ;[Post-traitement (optionnel : contraste, correction, niveaux)] correction gamma
  
  *param\addr[0] = *blur
  *param\addr[1] = *sobel
  MultiThread_MT(@pencil_sobel_4d_MT())
  
  Select *param\option[4]
      
    Case 0 ; Style par défaut (actuel)
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
      
    Case 1 ; Contour seul (line art)
      *param\addr[0] = *gray
      *param\addr[1] = *cible
      MultiThread_MT(@pencil_sobel_4d_MT()) ; Pas de dodge ici
      
    Case 2 ; Crayon sombre (inversé)
      *param\addr[0] = *blur
      *param\addr[1] = *sobel
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge()) ; mais inverser couleur (voir plus bas)
      
    Case 3 ; Crayon doux (moins de contours)
      ;*param\option[3] * 0.5 ; réduit l’intensité des contours
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
      
    Case 4 ; Crayon esquissé (avec bruit léger)
      For i = 0 To (lg * ht - 1)
        PokeL(*blur + i << 2, PeekL(*blur + i << 2) + Random(10) - 5)
      Next
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
      
    Case 5 ; Style charbon (charcoal)
           ; Accentue le contour et obscurcit l’image
      For i = 0 To (lg * ht - 1)
        Protected v = PeekL(*sobel + i << 2)
        v = v + (255 - PeekL(*blur + i)) >> 1
        clamp(v, 0, 255)
        PokeL(*sobel + i << 2, v)
      Next
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      ;MultiThread_MT(@pencil_color_dodge_invert()) ; version sombre
      
    Case 6 ; Style estampe (high contrast)
      For i = 0 To (lg * ht - 1)
        v = PeekL(*sobel + i << 2)
        If v > 128
          PokeL(*sobel + i << 2, 255)
        Else
          PokeL(*sobel + i << 2, 0)
        EndIf
      Next
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
      
    Case 7 ; Style peinture crayonnée
           ; Mélange les niveaux de gris et flou pour créer un fond doux
      For i = 0 To (lg * ht - 1)
        Protected v1 = PeekL(*gray + i << 2)
        Protected v2 = PeekL(*blur + i << 2)
        PokeL(*blur + i << 2, (v1 * 3 + v2) >> 2) ; mix 75/25
      Next
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
      
    Case 8 ; Style pastel doux
      ;*param\option[3] * 0.3 ; contours très doux
      ;*param\option[2] * 0.6 ; gamma plus clair
      
      For i = 0 To (lg * ht - 1)
         v1 = PeekL(*gray + i)
         v2 = PeekL(*blur + i)
        PokeL(*blur + i << 2, (v1 + v2 * 3) >> 2) ; mix 25/75 (plus doux)
      Next
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
      
    Case 9 ; Style cartoon
      *param\addr[0] = *gray
      *param\addr[1] = *tmp
      MultiThread_MT(@pencil_sobel_4d_MT()) ; détection des contours
      
      For i = 0 To (lg * ht - 1)
        Protected lum = PeekL(*gray + i << 2)
        Protected steps = 4
        Protected level = (lum * steps) / 256
        lum = (255 * level) / (steps - 1) ; postérisation 4 niveaux
        clamp(lum, 0, 255)
        PokeL(*gray + i << 2, lum)
      Next
      
      ; Mix image postérisée et contours
      For i = 0 To (lg * ht - 1)
        Protected edge = PeekL(*tmp + i << 2)
        Protected base = PeekL(*gray + i << 2)
        Protected final = base - (edge >> 1)
        clamp(final, 0, 255)
        PokeL(*cible + i * 4, final | (final << 8) | (final << 16))
      Next
      
      
  EndSelect
  
  ;*param\addr[0] = *sobel
  ;*param\addr[1] = *blur
  ;*param\addr[2] = *cible
  ;MultiThread_MT(@pencil_color_dodge())
  
  If *param\mask And *param\option[5] : *param\mask_type = *param\option[5] - 1 : MultiThread_MT(@_mask()) : EndIf
  FreeArray(tr())
  FreeMemory(*gray)
  FreeMemory(*blur)
  FreeMemory(*sobel)
  FreeMemory(*tmp)
  If *tempo2 : FreeMemory(*tempo2) : EndIf
EndProcedure

;--------------

;--
Macro FakeHDR_thread_total()
  Protected lg =  *param\lg
  Protected ht =  *param\ht
  Protected total = lg * ht
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop   = ((*param\thread_pos + 1) * total) / *param\thread_max
  If stop >= total : stop = total - 1 : EndIf
EndMacro
;---
Procedure FakeHDR_Guillossien_MT(*param.parametre)
  ; Déclarations de pointeurs pixel source/destination
  Protected *srcPixel1.Pixel32
  Protected *srcPixel2.Pixel32
  Protected *dstPixel.Pixel32

  ; Accumulateurs pour composantes ARGB
  Protected ax1.l, rx1.l, gx1.l, bx1.l
  Protected a1.l, r1.l, b1.l, g1.l
  Protected a2.l, r2.l, b2.l, g2.l

  ; Index temporaires
  Protected j, i, p1, p2

  ; Paramètres de l’image
  Protected *cible = *param\addr[3]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected *tempo = *param\addr[0]
  Protected lx = *param\addr[1]
  Protected ly = *param\addr[2]

  ; Paramètres du filtre
  Protected nrx = param\option[17] ; Largeur de la fenêtre de flou (X)
  Protected nry = param\option[18] ; Hauteur de la fenêtre de flou (Y)
  Protected div = param\option[19] ; Facteur de division (65536 / (nrx * nry))

  ; Threads
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected startPos = (thread_pos * ht) / thread_max
  Protected endPos   = ((thread_pos + 1) * ht) / thread_max - 1

  ; Buffers pour accumuler les sommes par colonne
  Protected Dim a.l(lg)
  Protected Dim r.l(lg)
  Protected Dim g.l(lg)
  Protected Dim b.l(lg)

  ; Initialisation des buffers
  FillMemory(@a(), lg * 4, 0)
  FillMemory(@r(), lg * 4, 0)
  FillMemory(@g(), lg * 4, 0)
  FillMemory(@b(), lg * 4, 0)

  ; === Étape 1 : Accumule les lignes verticales pour démarrer ===
  For j = 0 To nry - 1
    p1 = PeekL(ly + (j + startPos) << 2)
    *srcPixel1 = *cible + ((p1 * lg) << 2)
    For i = 0 To lg - 1
      getargb(*srcPixel1\l, a1, r1, g1, b1)
      a(i) = a(i) + a1
      r(i) = r(i) + r1
      g(i) = g(i) + g1
      b(i) = b(i) + b1
      *srcPixel1 + 4
    Next
  Next

  ; === Étape 2 : Application du filtre pour chaque ligne ===
  For j = startPos To endPos
    ; Mise à jour du buffer colonne (soustraction d’une ancienne ligne et ajout d’une nouvelle)
    p1 = PeekL(ly + (nry + j) << 2) ; index de la ligne ajoutée
    p2 = PeekL(ly + (j << 2))       ; index de la ligne retirée
    *srcPixel1 = *cible + (p1 * lg) << 2
    *srcPixel2 = *cible + (p2 * lg) << 2

    For i = 0 To lg - 1
      getargb(*srcPixel1\l, a1, r1, g1, b1)
      getargb(*srcPixel2\l, a2, r2, g2, b2)
      a(i) = a(i) + a1 - a2
      r(i) = r(i) + r1 - r2
      g(i) = g(i) + g1 - g2
      b(i) = b(i) + b1 - b2
      *srcPixel1 + 4
      *srcPixel2 + 4
    Next

    ; Application du filtre horizontal (initialisation des accumulateurs)
    ax1 = 0 : rx1 = 0 : gx1 = 0 : bx1 = 0
    For i = 0 To nrx - 1
      p1 = PeekL(lx + i << 2)
      ax1 = ax1 + a(p1)
      rx1 = rx1 + r(p1)
      gx1 = gx1 + g(p1)
      bx1 = bx1 + b(p1)
    Next

    ; Boucle de sortie pour chaque pixel de la ligne (fenêtre glissante)
    For i = 0 To lg - 1
      p1 = PeekL(lx + (nrx + i) << 2)
      p2 = PeekL(lx + i  << 2)
      ax1 = ax1 + a(p1) - a(p2)
      rx1 = rx1 + r(p1) - r(p2)
      gx1 = gx1 + g(p1) - g(p2)
      bx1 = bx1 + b(p1) - b(p2)

      ; Calcul final avec facteur de division
      a1 = (ax1 * div) >> 16
      r1 = (rx1 * div) >> 16
      g1 = (gx1 * div) >> 16
      b1 = (bx1 * div) >> 16

      ; Clamp pour sécurité
      clamp_argb(a1 , r1 , g1 , b1)
      ; Écriture dans le buffer temporaire
      *dstPixel = *tempo + ((j * lg + i) << 2)
      *dstPixel\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
    Next
  Next

  ; Libération des tableaux
  FreeArray(a())
  FreeArray(r())
  FreeArray(g())
  FreeArray(b())
EndProcedure
;--
Procedure FakeHDR_sp_MT(*param.parametre)
  Protected *src = *param\source
  Protected *dst = *param\addr[0]
  Protected *bright =  *param\addr[1]
  Protected vmin.f =  *param\option[0] * 0.05
  Protected vmax.f =  *param\option[1] * 0.05
  Protected seuil1 = *param\option[2]
  Protected shadowBoos = *param\option[3]
  Protected seuil2 = *param\option[4]
  Protected i , pixel , lum
  Protected r0.f, g0.f, b0.f
  Protected r_under.f, g_under.f, b_under.f
  Protected r_over.f, g_over.f, b_over.f
  Protected r, g, b
  
  ;Protected Dim tab(255)
  ;For i = 0 To 255
    ;tab(i) = Pow(i / 255 , 2.2) * 255
  ;Next
  
  FakeHDR_thread_total()
  
    For i = start To stop 
      pixel = PeekL(*src + i << 2)
      getrgb(pixel ,r ,g , b)
      ;r = tab(r)
      ;g = tab(g)
      ;b = tab(b)
      r0 = r : g0 = g : b0 = b
      ; Sous-exposition
      r_under = r0 * vmin
      g_under = g0 * vmin
      b_under = b0 * vmin
      ; Sur-exposition
      r_over = r0 * vmax
      g_over = g0 * vmax
      b_over = b0 * vmax
      If r_over > 255 : r_over = 255 : EndIf
      If g_over > 255 : g_over = 255 : EndIf
      If b_over > 255 : b_over = 255 : EndIf
      ; Fusion pondérée
      r = r_under * 0.3 + r0 * 0.4 + r_over * 0.3
      g = g_under * 0.3 + g0 * 0.4 + g_over * 0.3
      b = b_under * 0.3 + b0 * 0.4 + b_over * 0.3
      ; Clamp
      If r > 255 : r = 255 : EndIf
      If g > 255 : g = 255 : EndIf
      If b > 255 : b = 255 : EndIf
      
      ; FakeHDR_ShadowBoost_MT
      lum = ((r * 77 + g * 150 + b * 29) >> 8)
      If lum < seuil1
        r = (r + ((seuil1 - lum) * shadowBoos))
        g = (g + ((seuil1 - lum) * shadowBoos))
        b = (b + ((seuil1 - lum) * shadowBoos))
      EndIf
      clamp_rgb(r ,g , b)
      PokeL(*dst + i << 2, (r<<16) | (g<<8) | b)
      
      ;Procedure FakeHDR_GlowEffect_IIR_sp1_MT
      lum = (r * 77 + g * 150 + b * 29) >> 8
      If lum > seuil2 : PokeL(*bright + i << 2, pixel) : Else : PokeL(*bright + i << 2, 0) : EndIf
      
    Next
    ;FreeArray(tab())
  EndProcedure
  ;--
  

Macro FakeHDR_Blur_IIR_sp()
  pos = (y * lg + x) << 2
  *pix32 = *dst32 + pos
  getrgb(*pix32\l ,r1 , g1 , b1)
  r1 = r1 << 8 : g1 = g1 << 8 : b1 = b1 << 8 
  r = (r * alpha + inv_alpha * r1) >> 8 
  g = (g * alpha + inv_alpha * g1) >> 8 
  b = (b * alpha + inv_alpha * b1) >> 8 
  r2 = (r + 128 ) >> 8 : g2 = (g + 128 ) >> 8 : b2 = (b + 128 ) >> 8
  clamp_rgb(r2 ,g2 ,b2)
  *pix32\l = (r2 << 16) + (g2 << 8) + b2
EndMacro

Procedure FakeHDR_Blur_IIR_y_MT(*param.parametre)
  Protected *dst32.pixel32 = *param\addr[0]
  Protected *pix32.pixel32
  Protected lg =  *param\lg
  Protected ht =  *param\ht
  Protected alpha = *param\option[18]
  Protected inv_alpha = *param\option[19]
  Protected x, y, pos
  Protected r, g, b
  Protected r1, g1, b1
  Protected r2, g2, b2
  Protected pixel
  Protected start = (*param\thread_pos * ht) / *param\thread_max
  Protected stop   = ((*param\thread_pos + 1) * ht) / *param\thread_max
  For y = start To stop -1
    r = 0 : g = 0 : b = 0
    For x = 0 To lg - 1 : FakeHDR_Blur_IIR_sp() : Next
  Next
  For y = start To stop -1
    r = 0 : g = 0 : b = 0
    For x = lg - 1 To 0 Step -1 : FakeHDR_Blur_IIR_sp() : Next
  Next
EndProcedure

Procedure FakeHDR_Blur_IIR_x_MT(*param.parametre)
  Protected *dst32.pixel32 =  *param\addr[0]
  Protected *pix32.pixel32
  Protected lg =  *param\lg
  Protected ht =  *param\ht
  Protected alpha = *param\option[18]
  Protected inv_alpha = *param\option[19]
  Protected x, y, pos
  Protected r, g, b
  Protected r1, g1, b1
  Protected r2, g2, b2
  Protected pixel
  Protected start = (*param\thread_pos * lg) / *param\thread_max
  Protected stop   = ((*param\thread_pos + 1) * lg) / *param\thread_max
  For x = start To stop -1
    r = 0 : g = 0 : b = 0
    For y = 0 To ht - 1 : FakeHDR_Blur_IIR_sp() : Next
  Next
  For x = start To stop -1
    r = 0 : g = 0 : b = 0
    For y = ht - 1 To 0 Step -1 : FakeHDR_Blur_IIR_sp() : Next
  Next
EndProcedure

;--
Procedure FakeHDR_GlowEffect_IIR_sp2_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *bright = *param\addr[1]
  Protected *dst = *param\addr[2]
  Protected glowStrength = (*param\option[5] * 256) / 100
  Protected i , pixel, r, g, b
  Protected r0, g0, b0
  FakeHDR_thread_total()
  For i = start To stop
    pixel = PeekL(*src + i << 2)
    getrgb(pixel , r0 , g0 , b0)
    pixel = PeekL(*bright + i << 2)
    getrgb(pixel , r , g , b)
    ; Mélange glow + original avec intensité
    r = r0 + ((r * glowStrength) >> 8)
    g = g0 + ((g * glowStrength) >> 8)
    b = b0 + ((b * glowStrength) >> 8)
    clamp_rgb(r, g, b)
    PokeL(*dst + i << 2, (r << 16) + (g << 8) + b)
  Next
EndProcedure
;--
Procedure UnsharpMask_MT(*param.parametre)
  Protected *src  = *param\addr[0]
  Protected *dst  = *param\addr[1]
  Protected *blur = *param\addr[2]
  Protected strengthQ8 = Int(*param\option[6] * 25.6) ; 0.0–10.0 → 0–2560 (Q8)

  Protected i, pixelOrig, pixelBlur
  Protected rOrig, gOrig, bOrig, rBlur, gBlur, bBlur
  Protected rDiff, gDiff, bDiff, r, g, b

  FakeHDR_thread_total()  

  For i = start To stop
      pixelOrig = PeekL(*src + i << 2)
      pixelBlur = PeekL(*blur + i << 2)
      getrgb(pixelOrig, rOrig, gOrig, bOrig)
      getrgb(pixelBlur, rBlur, gBlur, bBlur)
      rDiff = rOrig - rBlur
      gDiff = gOrig - gBlur
      bDiff = bOrig - bBlur
      r = rOrig + ((rDiff * strengthQ8) >> 8)
      g = gOrig + ((gDiff * strengthQ8) >> 8)
      b = bOrig + ((bDiff * strengthQ8) >> 8)
      clamp_rgb(r, g, b)
      PokeL(*dst + i <<2 , (r << 16) + (g << 8) + b)
  Next
EndProcedure
;--
Procedure LocalContrast_MT(*param.parametre)
  Protected *src1 =  *param\addr[0]
  Protected *dst =  *param\cible

  ; Conversion de contrast en Q8 (x256)
  Protected contrastQ8 = Int(*param\option[8] * 10)
  Protected factorQ8 = Int(*param\option[9] * 10) ; Q8
  Protected levels = 100 - *param\option[10]
  If levels < 2 : levels = 2 : EndIf
  If contrastQ8 < 26 : contrastQ8 = 26 : EndIf ; équivaut à 0.1
  
  ; On calcule en Q8 fixed point les échelles pour quantification et déquantification
  ; scaleQuant = (levels - 1) << 8 / 255  -> pour r * scaleQuant >> 8 = quantification en [0..levels-1]
  Protected scaleQuant = ((levels - 1) << 8) / 255
  ; scaleDequant = 255 << 8 / (levels - 1) -> pour restituer la valeur dans [0..255]
  Protected scaleDequant = (255 << 8) / (levels - 1)
  
  Protected half = 128 ; pour arrondi (0.5 en Q8)
  
  Protected i , lum
  Protected r1, g1, b1, r2, g2, b2
  Protected r, g, b , rF, gF, bF
  FakeHDR_thread_total() 

  For i = start To stop
      getrgb(PeekL(*src1 + i << 2), r1, g1, b1)
      getrgb(PeekL(*dst + i << 2), r2, g2, b2)

      r = ((r1 - r2) * contrastQ8) >> 8 + r2
      g = ((g1 - g2) * contrastQ8) >> 8 + g2
      b = ((b1 - b2) * contrastQ8) >> 8 + b2

      clamp_rgb(r, g, b)
      ;PokeL(*dst + i << 2, (r << 16) + (g << 8) + b)
      
      ;procedure FakeHDR_sat_MT
     lum = (r * 77 + g * 150 + b * 29) >> 8

    ; Saturation ajustée avec Q8 fixed point
    rF = lum + ((r - lum) * factorQ8) >> 8
    gF = lum + ((g - lum) * factorQ8) >> 8
    bF = lum + ((b - lum) * factorQ8) >> 8

    clamp_rgb(rF, gF, bF)
    ;PokeL(*dst + i << 2, (rF << 16) + (gF << 8) + bF)     
    
    ;procedure PosterizeDoucement_MT
    r = (((rf * scaleQuant + half) >> 8) * scaleDequant + half) >> 8
    g = (((gf * scaleQuant + half) >> 8) * scaleDequant + half) >> 8
    b = (((bf * scaleQuant + half) >> 8) * scaleDequant + half) >> 8
    clamp_rgb(r, g, b)
    PokeL(*dst + i << 2, (r << 16) | (g << 8) | b)
  Next
EndProcedure
;--

;--
Procedure FakeHDR_MixWithOriginal_MT(*param.parametre)
  Protected *src1 = *param\source
  Protected *src2 = *param\cible
  
  ; mix en pourcentage [0..100], on convertit en Q8 [0..256]
  Protected mixPercent = *param\option[11]
  If mixPercent < 0 : mixPercent = 0 : EndIf
  If mixPercent > 100 : mixPercent = 100 : EndIf
  Protected mix = (mixPercent * 256) / 100
  Protected invMix = 256 - mix
  Protected half = 128 ; pour arrondi
  
  Protected i, pixel1, pixel2
  Protected r1, g1, b1, r2, g2, b2
  Protected r, g, b
  
  ;Protected Dim tab(255)
  ;For i = 0 To 255
    ;tab(i) = Pow(i/255  ,1 /  2.2) * 255
  ;Next
  
  FakeHDR_thread_total()

  For i = start To stop
    pixel1 = PeekL(*src1 + i << 2)
    pixel2 = PeekL(*src2 + i << 2)
    getrgb(pixel1, r1, g1, b1)
    getrgb(pixel2, r2, g2, b2)
    ;r2 = tab(r2)
    ;g2 = tab(g2)
    ;b2 = tab(b2)

    ; Interpolation en Q8 avec arrondi
    r = (r1 * invMix + r2 * mix + half) >> 8
    g = (g1 * invMix + g2 * mix + half) >> 8
    b = (b1 * invMix + b2 * mix + half) >> 8

    clamp_rgb(r, g, b)
    PokeL(*src2 + i << 2, (r << 16) + (g << 8) + b)
  Next
  ;FreeArray(tab())
EndProcedure
;--
Macro FakeHDR_sp1()
  dx = lg - 1
  dy = ht - 1
  If radius > dx : radius = dx : EndIf
  If radius > dy : radius = dy : EndIf
  nrx = radius + 1
  nry = radius + 1
  ; Allocation mémoire pour les tables d’indices en X et Y
  *lx = AllocateMemory((lg + 2 * nrx) * 4)
  *ly = AllocateMemory((ht + 2 * nry) * 4)
  ; Remplissage des tables selon le mode bord ou boucle
  For i = 0 To dx + 2 * nrx : ii = i - 1 - nrx / 2 : If ii < 0 : ii = 0 : ElseIf ii > dx : ii = dx : EndIf : PokeL(*lx + i * 4, ii) : Next
  For i = 0 To dy + 2 * nry : ii = i - 1 - nry / 2 : If ii < 0 : ii = 0 : ElseIf ii > dy : ii = dy : EndIf : PokeL(*ly + i * 4, ii) : Next
  param\addr[1] = *lx
  param\addr[2] = *ly
  param\option[17] = nrx
  param\option[18] = nry
  param\option[19] = Int(65536 / (nrx * nry)) ; Facteur normalisation
EndMacro
;--
Procedure FakeHDR(*param.parametre)
  
  If param\info_active
    param\typ = #Filter_Type_autre
    param\name = "FakeHDR"
    param\remarque = ""
    param\info[0] = "vmin"
    param\info[1] = "vmax"
    param\info[2] = "ShadowBoost_seuil"
    param\info[3] = "ShadowBoost_value"
    param\info[4] = "seuil"
    param\info[5] = "Intensité Glow"
    param\info[6] = "strength"
    param\info[7] = "radius"
    param\info[8] = "contrast"
    param\info[9] = "factor"
    param\info[10] = "Posterize"
    param\info[11] = "Mix final"
    param\info[12] = "Masque binaire"
    
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 30
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 40
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100 : param\info_data(2,2) = 7
    param\info_data(3,0) = 0 : param\info_data(3,1) = 100 : param\info_data(3,2) = 4
    param\info_data(4,0) = 0 : param\info_data(4,1) = 255 : param\info_data(4,2) = 127
    param\info_data(5,0) = 0 : param\info_data(5,1) = 100 : param\info_data(5,2) = 6
    param\info_data(6,0) = 0 : param\info_data(6,1) = 100 : param\info_data(6,2) = 50
    param\info_data(7,0) = 0 : param\info_data(7,1) = 100 : param\info_data(7,2) = 100
    param\info_data(8,0) = 0 : param\info_data(8,1) = 100 : param\info_data(8,2) = 30
    param\info_data(9,0) = 0 : param\info_data(9, 1) = 100 : param\info_data(9, 2) = 60
    param\info_data(10,0) = 0 : param\info_data(10,1) = 100 : param\info_data(10,2) = 0
    param\info_data(11,0) = 0 : param\info_data(11,1) = 100 : param\info_data(11,2) = 100 ; Mix final
    param\info_data(12,0) = 0 : param\info_data(12,1) = 2 : param\info_data(12,2) = 0     ; Masque binaire
    
    ProcedureReturn
  EndIf
  
  Protected *source = *param\source
  Protected *cible = *param\cible
  Protected *mask = *param\mask
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected i
  If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf
  
  Protected *temp1 = AllocateMemory(lg * ht * 4)
  Protected *temp2 = AllocateMemory(lg * ht * 4)
  Protected *bright = AllocateMemory(lg * ht * 4)
  Protected *blur = AllocateMemory(lg * ht * 4)
  Protected *tempo = AllocateMemory(lg * ht * 4)
  
  ; Détermine le nombre de threads disponibles
  Protected thread = CountCPUs(#PB_System_CPUs)
  clamp(thread , 1 , 128)
  Protected Dim tr(thread)
  
  Protected ii, e, passe , t

  ; Étape 1 : Fake HDR
  ;FakeHDR_sp(*source, *temp1, lg, ht ,  vmin , vmax)
  *param\addr[0] = *temp1
  *param\addr[1] = *bright
  MultiThread_MT(@FakeHDR_sp_MT())
  

  Protected Radius0.f = 0.3
  *param\option[18] = Int((Exp(-2.3 / (Radius0 + 1.0))) * 256)
  *param\option[19]  = 256 - *param\option[18]
  *param\addr[0] = *bright
  MultiThread_MT(@FakeHDR_Blur_IIR_y_MT())
  MultiThread_MT(@FakeHDR_Blur_IIR_x_MT())
  
  *param\addr[0] = *temp1
  *param\addr[1] = *bright
  *param\addr[2] = *temp2
  MultiThread_MT(@FakeHDR_GlowEffect_IIR_sp2_MT())

  

  ; Étape 3 : Sharpen
  Protected dx , dy , nrx ,nry
  Protected *lx , *ly
  Protected radius.f = *param\option[7] 
  clamp(radius, 1, 100)
  radius * 0.1
  FakeHDR_sp1()
  param\addr[0] = *blur
  param\addr[3] = *temp2
  MultiThread_MT(@FakeHDR_Guillossien_MT())
  FreeMemory(*lx) : FreeMemory(*ly)
  
  param\addr[0] = *temp2
  param\addr[1] = *temp1
  param\addr[2] = *blur  
  MultiThread_MT(@UnsharpMask_MT())

  
  ; Étape 4 : Local contrast
  radius = 3
  FakeHDR_sp1()
  param\addr[0] = *temp2
  param\addr[3] = *temp1
  MultiThread_MT(@FakeHDR_Guillossien_MT())
  FreeMemory(*lx) : FreeMemory(*ly)
  
  param\addr[0] = *temp1
  param\addr[1] = *temp2
  MultiThread_MT(@LocalContrast_Mt())


  MultiThread_MT(@FakeHDR_MixWithOriginal_MT())

  If *param\mask And *param\option[12] : *param\mask_type = *param\option[12] - 1 : MultiThread_MT(@_mask()) : EndIf
  
  FreeMemory(*temp1)
  FreeMemory(*temp2)
  FreeMemory(*bright)
  FreeMemory(*blur)
  FreeMemory(*tempo)
  FreeArray(tr())
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 1634
; FirstLine = 1558
; Folding = -------
; EnableXP
; DPIAware