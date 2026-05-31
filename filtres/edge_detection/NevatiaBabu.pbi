; Structure plate pour le voisinage 5x5 (évite les Dim)
Structure neighborhood5x5
  r.l[25]
  g.l[25]
  b.l[25]
EndStructure

Macro Macro_NevatiaBabu_lecture_pixel5x5()
  pos = ((y - 2) * lg) + (x - 2)
  ; Ligne -2
  getrgb(*src\pixel[pos + 0], v\r[0], v\g[0], v\b[0]) : getrgb(*src\pixel[pos + 1], v\r[1], v\g[1], v\b[1]) : getrgb(*src\pixel[pos + 2], v\r[2], v\g[2], v\b[2]) : getrgb(*src\pixel[pos + 3], v\r[3], v\g[3], v\b[3]) : getrgb(*src\pixel[pos + 4], v\r[4], v\g[4], v\b[4])
  pos + lg
  ; Ligne -1
  getrgb(*src\pixel[pos + 0], v\r[5], v\g[5], v\b[5]) : getrgb(*src\pixel[pos + 1], v\r[6], v\g[6], v\b[6]) : getrgb(*src\pixel[pos + 2], v\r[7], v\g[7], v\b[7]) : getrgb(*src\pixel[pos + 3], v\r[8], v\g[8], v\b[8]) : getrgb(*src\pixel[pos + 4], v\r[9], v\g[9], v\b[9])
  pos + lg
  ; Ligne 0 (Pixel central au milieu : index 12)
  getrgb(*src\pixel[pos + 0], v\r[10], v\g[10], v\b[10]) : getrgb(*src\pixel[pos + 1], v\r[11], v\g[11], v\b[11]) : getargb(*src\pixel[pos + 2], a, v\r[12], v\g[12], v\b[12]) : getrgb(*src\pixel[pos + 3], v\r[13], v\g[13], v\b[13]) : getrgb(*src\pixel[pos + 4], v\r[14], v\g[14], v\b[14])
  pos + lg
  ; Ligne +1
  getrgb(*src\pixel[pos + 0], v\r[15], v\g[15], v\b[15]) : getrgb(*src\pixel[pos + 1], v\r[16], v\g[16], v\b[16]) : getrgb(*src\pixel[pos + 2], v\r[17], v\g[17], v\b[17]) : getrgb(*src\pixel[pos + 3], v\r[18], v\g[18], v\b[18]) : getrgb(*src\pixel[pos + 4], v\r[19], v\g[19], v\b[19])
  pos + lg
  ; Ligne +2
  getrgb(*src\pixel[pos + 0], v\r[20], v\g[20], v\b[20]) : getrgb(*src\pixel[pos + 1], v\r[21], v\g[21], v\b[21]) : getrgb(*src\pixel[pos + 2], v\r[22], v\g[22], v\b[22]) : getrgb(*src\pixel[pos + 3], v\r[23], v\g[23], v\b[23]) : getrgb(*src\pixel[pos + 4], v\r[24], v\g[24], v\b[24])
EndMacro

Procedure NevatiaBabu_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul = \option[0] * 1024
    Protected toGray = \option[1]
    Protected inverse = \option[2]
    Protected seuil_bas  = \option[3]
    Protected seuil_haut = \option[4]
    
    Protected v.neighborhood5x5
    Protected Dim gray(24)
    Protected Dim NBmask(5, 24)
    Protected valR, valG, valB, maxR, maxG, maxB
    Protected a, r, g, b, x, y, i, m, pos
    Protected *src.pixelarray32 = \addr[2]
    Protected *dst.pixelarray32 = \addr[1]
    
    ; Chargement unique des masques Nevatia-Babu pour ce thread
    Restore NevatiaBabu_kernels
    For m = 0 To 5 : For i = 0 To 24 : Read.i NBmask(m, i) : Next : Next
    
    macro_calul_tread(ht)
    
    ; Protection stricte des bords pour un noyau 5x5
    If thread_start < 2 : thread_start = 2 : EndIf
    If thread_stop > ht - 3 : thread_stop = ht - 3 : EndIf
    
    ; Correction de la borne Y (To thread_stop) et de la borne X (To lg - 3)
    For y = thread_start To thread_stop
      For x = 2 To lg - 3
        Macro_NevatiaBabu_lecture_pixel5x5()
        
        If toGray
          ; 1. Conversion de la matrice 5x5 locale en niveaux de gris
          For i = 0 To 24
            gray(i) = (v\r[i] * 77 + v\g[i] * 150 + v\b[i] * 29) >> 8
          Next
          
          ; 2. Application des 6 masques directionnels
          maxR = 0
          For m = 0 To 5
            valR = 0
            For i = 0 To 24 : valR + gray(i) * NBmask(m, i) : Next
            valR = Abs(valR)
            If valR > maxR : maxR = valR : EndIf
          Next
          
          ; Remise à l'échelle via virgule fixe 16 bits
          r = (maxR * mul) >> 16
          If inverse : r = 255 - r : EndIf
          g = r : b = r
          
        Else
          ; Traitement en couleur RGB complète
          maxR = 0 : maxG = 0 : maxB = 0
          
          For m = 0 To 5
            valR = 0 : valG = 0 : valB = 0
            For i = 0 To 24
              valR + v\r[i] * NBmask(m, i)
              valG + v\g[i] * NBmask(m, i)
              valB + v\b[i] * NBmask(m, i)
            Next
            valR = Abs(valR) : valG = Abs(valG) : valB = Abs(valB)
            
            If valR > maxR : maxR = valR : EndIf
            If valG > maxG : maxG = valG : EndIf
            If valB > maxB : maxB = valB : EndIf
          Next
          
          ; Application du multiplicateur sur les variables réelles r, g, b
          r = (maxR * mul) >> 16
          g = (maxG * mul) >> 16
          b = (maxB * mul) >> 16
          
          clamp_rgb(r, g, b)
          If inverse : r = 255 - r : g = 255 - g : b = 255 - b : EndIf
        EndIf
        
        ; Seuillage final (dynamique globale de ta bibliothèque)
        If seuil_bas  >   0 : seuil_min_rgb(seuil_bas  , r , g , b) : EndIf
        If seuil_haut < 255 : seuil_max_rgb(seuil_haut , r , g , b) : EndIf
        
        *dst\pixel[(y * lg) + x] = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
    
    FreeArray(gray()) : FreeArray(NBmask())
  EndWith
EndProcedure

Procedure NevatiaBabu_bords(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y
    Protected *dst.pixelarray32 = \addr[1]
    
    ; Remplissage des 2 colonnes gauches et 2 colonnes droites
    For y = 2 To ht - 3
      *dst\pixel[y * lg] = *dst\pixel[y * lg + 2]
      *dst\pixel[y * lg + 1] = *dst\pixel[y * lg + 2]
      
      *dst\pixel[(y * lg) + lg - 1] = *dst\pixel[(y * lg) + lg - 3]
      *dst\pixel[(y * lg) + lg - 2] = *dst\pixel[(y * lg) + lg - 3]
    Next
    
    ; Copie des 2 lignes du haut
    For x = 0 To lg - 1
      *dst\pixel[0 * lg + x] = *dst\pixel[2 * lg + x]
      *dst\pixel[1 * lg + x] = *dst\pixel[2 * lg + x]
    Next
    
    ; Copie des 2 lignes du bas
    Protected last1 = (ht - 1) * lg
    Protected last2 = (ht - 2) * lg
    Protected source_line = (ht - 3) * lg
    For x = 0 To lg - 1
      *dst\pixel[last1 + x] = *dst\pixel[source_line + x]
      *dst\pixel[last2 + x] = *dst\pixel[source_line + x]
    Next
  EndWith
EndProcedure

Procedure NevatiaBabuEx(*FilterCtx.FilterParams)
  Restore NevatiaBabu_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  With *FilterCtx
    Protected size = \image_lg[0] * \image_ht[0] * 4
    If \addr[1] = \addr[0]
      \addr[2] = AllocateMemory(size)
      If \addr[2]
        CopyMemory(\addr[0], \addr[2], size)
        Create_MultiThread_MT(@NevatiaBabu_MT())
        NevatiaBabu_bords(*FilterCtx)
        FreeMemory(\addr[2]) 
      EndIf
    Else
      \addr[2] = \addr[0]
      Create_MultiThread_MT(@NevatiaBabu_MT())
      NevatiaBabu_bords(*FilterCtx)
    EndIf  
    mask_update(*FilterCtx, last_data) 
  EndWith
EndProcedure

Procedure NevatiaBabu(source, cible, mask, multiply=10, gray=0, inverse=0, seuil_bas = 0, seuil_haut = 255)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiply
    \option[1] = gray
    \option[2] = inverse
    \option[3] = seuil_bas
    \option[4] = seuil_haut
  EndWith
  NevatiaBabuEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  NevatiaBabu_data:
  Data.s "Nevatia-Babu ne marche pas"
  Data.s "Détection de contours directionnelle 5x5 (6 masques)"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Gradient
  
  Data.s "Multiplicateur"
  Data.i 1, 100, 10
  Data.s "Noir et Blanc"
  Data.i 0, 1, 0
  Data.s "Inverser"
  Data.i 0, 1, 0
  Data.s "seuil bas"
  Data.i 0, 255, 0
  Data.s "seuil haut"
  Data.i 0, 255, 255
  Data.s "XXX"

  NevatiaBabu_kernels:
  ; M0 - 0°
  Data.l  100, 100, 100, 100, 100,  100, 100, 100, 100, 100,  0, 0, 0, 0, 0, -100,-100,-100,-100,-100, -100,-100,-100,-100,-100
  ; M1 - 30°
  Data.l  100, 100, 100, 100, 0,  100, 100, 100, 0, -100,  100, 100, 0, -100,-100,  100, 0, -100,-100,-100,  0, -100,-100,-100,-100
  ; M2 - 60°
  Data.l  100, 100, 100, 0, -100,  100, 100, 0, -100,-100,  100, 0, -100,-100,-100,  0, -100,-100,-100,-100, -100,-100,-100,-100,-100
  ; M3 - 90°
  Data.l  0, 100, 100, 100, 0,  0, 100, 100, 100, 0,  0, 0, 0, 0, 0,  0, -100,-100,-100, 0,  0, -100,-100,-100, 0
  ; M4 - 120°
  Data.l  -100, 0, 100, 100, 100,  -100,-100, 0, 100, 100,  -100,-100,-100, 0, 100,  -100,-100,-100,-100, 0,  -100,-100,-100,-100,-100
  ; M5 - 150°
  Data.l  0, -100,-100,-100,-100,  100, 0, -100,-100,-100,  100, 100, 0, -100,-100,  100, 100, 100, 0, -100,  100, 100, 100, 100, 0
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 189
; FirstLine = 132
; Folding = -
; EnableXP
; DPIAware