Macro macro_Prewitt8d_calcul_gray()
  rMax = 0 
  v\r[0] = (v\r[0] * 77 + v\g[0] * 150 + v\b[0] * 29) >> 8
  v\r[1] = (v\r[1] * 77 + v\g[1] * 150 + v\b[1] * 29) >> 8
  v\r[2] = (v\r[2] * 77 + v\g[2] * 150 + v\b[2] * 29) >> 8
  v\r[3] = (v\r[3] * 77 + v\g[3] * 150 + v\b[3] * 29) >> 8
  ; Le pixel central g_val[4] n'est pas utilisé par le filtre de Prewitt
  v\r[5] = (v\r[5] * 77 + v\g[5] * 150 + v\b[5] * 29) >> 8
  v\r[6] = (v\r[6] * 77 + v\g[6] * 150 + v\b[6] * 29) >> 8
  v\r[7] = (v\r[7] * 77 + v\g[7] * 150 + v\b[7] * 29) >> 8
  v\r[8] = (v\r[8] * 77 + v\g[8] * 150 + v\b[8] * 29) >> 8
  ; --- 2. SOMMES INTERMÉDIAIRES SUR LE GRIS ---
   Protected top  = v\r[0] + v\r[1] + v\r[2]
   Protected bot  = v\r[6] + v\r[7] + v\r[8]
   Protected left = v\r[0] + v\r[3] + v\r[6]
   Protected right= v\r[2] + v\r[5] + v\r[8]
  ; --- 3. CALCUL DES CONTRASTES PAR AXES ---
  ; Axe Nord / Sud
  valR = Abs(top - bot)
  If valR > rMax : rMax = valR : EndIf
  ; Axe Est / Ouest
  valR = Abs(right - left)
  If valR > rMax : rMax = valR : EndIf
  ; Axe Nord-Est / Sud-Ouest
  valR = Abs((v\r[1] + v\r[2] + v\r[5]) - (v\r[3] + v\r[6] + v\r[7]))
  If valR > rMax : rMax = valR : EndIf
  ; Axe Sud-Est / Nord-Ouest
  valR = Abs((v\r[5] + v\r[7] + v\r[8]) - (v\r[0] + v\r[1] + v\r[3]))
  If valR > rMax : rMax = valR : EndIf
EndMacro

Macro Macro_Prewitt8d_calul()
  ; Réinitialisation des maximums
  rMax = 0 : gMax = 0 : bMax = 0
  ; --- SOMMES INTERMÉDIAIRES (On calcule une fois pour toutes les axes) ---
  ; Lignes horizontales du voisinage
  Protected r_top = v\r[0] + v\r[1] + v\r[2]
  Protected r_bot = v\r[6] + v\r[7] + v\r[8]
  Protected g_top = v\g[0] + v\g[1] + v\g[2]
  Protected g_bot = v\g[6] + v\g[7] + v\g[8]
  Protected b_top = v\b[0] + v\b[1] + v\b[2]
  Protected b_bot = v\b[6] + v\b[7] + v\b[8]
  ; Colonnes verticales du voisinage
  Protected r_left  = v\r[0] + v\r[3] + v\r[6]
  Protected r_right = v\r[2] + v\r[5] + v\r[8]
  Protected g_left  = v\g[0] + v\g[3] + v\g[6]
  Protected g_right = v\g[2] + v\g[5] + v\g[8]
  Protected b_left  = v\b[0] + v\b[3] + v\b[6]
  Protected b_right = v\b[2] + v\b[5] + v\b[8]
  ; --- 1. AXE NORD / SUD (Utilise top et bot) ---
  valR = Abs(r_top - r_bot)
  valG = Abs(g_top - g_bot)
  valB = Abs(b_top - b_bot)
  If valR > rMax : rMax = valR : EndIf
  If valG > gMax : gMax = valG : EndIf
  If valB > bMax : bMax = valB : EndIf
  ; --- 2. AXE EST / OUEST (Utilise left et right) ---
  valR = Abs(r_right - r_left)
  valG = Abs(g_right - g_left)
  valB = Abs(b_right - b_left)
  If valR > rMax : rMax = valR : EndIf
  If valG > gMax : gMax = valG : EndIf
  If valB > bMax : bMax = valB : EndIf
  ; --- 3. AXE NORD-EST / SUD-OUEST ---
  valR = Abs((v\r[1] + v\r[2] + v\r[5]) - (v\r[3] + v\r[6] + v\r[7]))
  valG = Abs((v\g[1] + v\g[2] + v\g[5]) - (v\g[3] + v\g[6] + v\g[7]))
  valB = Abs((v\b[1] + v\b[2] + v\b[5]) - (v\b[3] + v\b[6] + v\b[7]))
  If valR > rMax : rMax = valR : EndIf
  If valG > gMax : gMax = valG : EndIf
  If valB > bMax : bMax = valB : EndIf
  ; --- 4. AXE SUD-EST / NORD-OUEST ---
  valR = Abs((v\r[5] + v\r[7] + v\r[8]) - (v\r[0] + v\r[1] + v\r[3]))
  valG = Abs((v\g[5] + v\g[7] + v\g[8]) - (v\g[0] + v\g[1] + v\g[3]))
  valB = Abs((v\b[5] + v\b[7] + v\b[8]) - (v\b[0] + v\b[1] + v\b[3]))
  If valR > rMax : rMax = valR : EndIf
  If valG > gMax : gMax = valG : EndIf
  If valB > bMax : bMax = valB : EndIf
EndMacro

Macro Macro_Prewitt8d_lecture_pixel3x3()
  pos = ((y - 1) * lg) + (x - 1)
  getrgb(*src\pixel[pos + 0], v\r[0], v\g[0], v\b[0])
  getrgb(*src\pixel[pos + 1], v\r[1], v\g[1], v\b[1])
  getrgb(*src\pixel[pos + 2], v\r[2], v\g[2], v\b[2])
  pos + lg
  getrgb( *src\pixel[pos + 0],    v\r[3], v\g[3], v\b[3])
  getargb(*src\pixel[pos + 1], a, v\r[4], v\g[4], v\b[4])
  getrgb( *src\pixel[pos + 2],    v\r[5], v\g[5], v\b[5])
  pos + lg 
  getrgb(*src\pixel[pos + 0], v\r[6], v\g[6], v\b[6])
  getrgb(*src\pixel[pos + 1], v\r[7], v\g[7], v\b[7]) 
  getrgb(*src\pixel[pos + 2], v\r[8], v\g[8], v\b[8])
EndMacro

Procedure Prewitt8d_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected Dim g_val.l(8)
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul = \option[0]
    Protected toGray = \option[1]
    Protected inverse = \option[2]
    Protected seuil_bas  = \option[3]
    Protected seuil_haut = \option[4]
    Protected v.Edge_Detection
    Protected a, r, g, b, x, y , pos
    Protected valR, valG, valB, rMax, gMax, bMax
    Protected *src.pixelarray32
    Protected *dst.Pixelarray32    
    *src = \addr[2]
    *dst = \addr[1]
    mul = (mul * 1024)
    macro_calul_tread(ht)
    If thread_start < 1 : thread_start = 1 : EndIf
    If thread_stop > ht - 2 : thread_stop = ht - 2 : EndIf
    For y = thread_start To thread_stop
      For x = 1 To lg - 2
        Macro_Prewitt_lecture_pixel3x3() ; Lecture du voisinage 3x3
        If toGray 
          macro_Prewitt8d_calcul_gray()
          r = (rMax * mul) >> 16
          clamp(r , 0 , 255)
          If inverse : r = 255 - r : EndIf
          g = r : b = r
        Else
          Macro_Prewitt8d_calul()
          r = (rMax * mul)>>16
          g = (gMax * mul)>>16
          b = (bMax * mul)>>16
          clamp_rgb(r , g , b)
          If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
        EndIf
        If seuil_bas  >   0 : seuil_min_rgb(seuil_bas  , r , g , b) : EndIf
        If seuil_haut < 255 : seuil_max_rgb(seuil_haut , r , g , b) : EndIf
        *dst\Pixel[(y * lg) + x] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure Prewitt8d_bords(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y
    Protected *dst.Pixelarray32 = \addr[1]
    For y = 1 To ht - 2
      *dst\pixel[y * lg] = *dst\pixel[y * lg + 1]
      *dst\pixel[(y * lg) + lg - 1] = *dst\pixel[(y * lg) + lg - 2]
    Next
    Protected top_line_offset = 0
    Protected sec_line_offset = lg
    For x = 0 To lg - 1
      *dst\pixel[top_line_offset + x] = *dst\pixel[sec_line_offset + x]
    Next
    Protected last_line_offset = (ht - 1) * lg
    Protected prev_line_offset = (ht - 2) * lg
    For x = 0 To lg - 1
      *dst\pixel[last_line_offset + x] = *dst\pixel[prev_line_offset + x]
    Next
  EndWith
EndProcedure

Procedure Prewitt8dEx(*FilterCtx.FilterParams)
  Restore Prewitt8d_data
  Protected i , var
  Protected *dst.pixelarray32
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  With *FilterCtx
      Protected size = \image_lg[0] * \image_ht[0] * 4
      If \addr[1] = \addr[0] ; test si l'image cible est l'image source (la meme image)
        \addr[2] = AllocateMemory(size) ; cree un image tempo (addr[2])
        If \addr[2]
          CopyMemory(\addr[0] , \addr[2] , size) ; copie la source dans tempo
          Create_MultiThread_MT(@Prewitt8d_MT())
          Prewitt8d_bords(*FilterCtx)
          FreeMemory(\addr[2]) 
        EndIf
      Else
        \addr[2] = \addr[0]
        Create_MultiThread_MT(@Prewitt_MT())
        Prewitt_bords(*FilterCtx)
      EndIf 
      mask_update(*FilterCtx, last_data) 
  EndWith
EndProcedure

Procedure Prewitt8d(source, cible, mask, multiplicateur=10, noir_blanc=0, inversion=0, seuil_bas = 0, seuil_haut = 255)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiplicateur
    \option[1] = noir_blanc
    \option[2] = inversion
    \option[3] = seuil_bas
    \option[4] = seuil_haut
  EndWith
  PrewittEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  Prewitt8d_data:
  Data.s "Prewitt"
  Data.s "Détection de contours par l'opérateur de Prewitt (8 directions)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
  
  Data.s "Multiplicateur"
  Data.i 1, 100, 25
  Data.s "Noir et Blanc"
  Data.i 0, 1, 0
  Data.s "Inverser"
  Data.i 0, 1, 0
  Data.s "seuil bas"
  Data.i 0, 255, 0
  Data.s "seuil haut"
  Data.i 0, 255, 255
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 164
; FirstLine = 160
; Folding = --
; EnableXP
; DPIAware