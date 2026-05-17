; =================================================================
; FILTRE : RGB vers CMYK
; Description : Convertit l'espace RGB (Additif) en CMYK (Soustractif).
;               C=R, M=G, Y=B. Le K est géré par l'option[3].
; =================================================================

Procedure RGBtoCMYK_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    ; Variables de calcul
    Protected.f r, g, b, c, m, y, k
    Protected.l i, alpha, r_in, g_in, b_in
    Protected.l c8, m8, y8, k8
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Extraction des composantes RGB [0-255]
      getargb(*src\pixel[i], alpha, r_in, g_in, b_in)
      
      ; 2. Normalisation [0.0 - 1.0]
      r = r_in / 255.0
      g = g_in / 255.0
      b = b_in / 255.0
      
      ; 3. Calcul du composant Noir (K)
      ; k est le complément de la valeur la plus élevée
      max(k,g,b)
      max(k,k,r)
      k = 1.0 - k
      
      ; 4. Calcul du Cyan, Magenta, Jaune
      If k < 1.0
        c = (1.0 - r - k) / (1.0 - k)
        m = (1.0 - g - k) / (1.0 - k)
        y = (1.0 - b - k) / (1.0 - k)
      Else
        ; Si k = 1.0, on est sur du noir pur
        c = 0 : m = 0 : y = 0
      EndIf
      
      ; 5. Application des réglages (Options)
      ; On ajuste les taux d'encrage
      c = c + ((\option[0] - 127) / 127.0)
      m = m + ((\option[1] - 127) / 127.0)
      y = y + ((\option[2] - 127) / 127.0)
      k = k + ((\option[3] - 127) / 127.0)
      
      ; Clamp des valeurs flottantes [0.0 - 1.0]
      If c < 0 : c = 0 : ElseIf c > 1 : c = 1 : EndIf
      If m < 0 : m = 0 : ElseIf m > 1 : m = 1 : EndIf
      If y < 0 : y = 0 : ElseIf y > 1 : y = 1 : EndIf
      If k < 0 : k = 0 : ElseIf k > 1 : k = 1 : EndIf
      
      ; 6. Mapping vers 8-bit
      ; Note : Comme on ne peut pas stocker 4 canaux + Alpha facilement sans changer 
      ; la structure, on affiche le CMY et on peut utiliser l'Alpha pour K 
      ; ou simplement simuler le rendu visuel. 
      ; Ici, on stocke C, M, Y pour la prévisualisation.
      c8 = Int(c * 255)
      m8 = Int(m * 255)
      y8 = Int(y * 255)
      k8 = Int(k * 255) ; Optionnel : pourrait être stocké dans alpha si besoin
      
      *dst\pixel[i] = (alpha << 24) | (c8 << 16) | (m8 << 8) | y8
    Next
  EndWith
EndProcedure

Procedure RGBtoCMYKEx(*FilterCtx.FilterParams)
  Restore RGBtoCMYK_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@RGBtoCMYK_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure RGBtoCMYK(source, cible, mask, c_adj, m_adj, y_adj, k_adj)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = c_adj
    \option[1] = m_adj
    \option[2] = y_adj
    \option[3] = k_adj
  EndWith
  RGBtoCMYKEx(FilterCtx.FilterParams)
EndProcedure

; ─── Données du Filtre ───
DataSection
  RGBtoCMYK_data:
  Data.s "RGB -> CMYK"
  Data.s "Simulation d'encrage soustractif (PAO)"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Cyan (C)"            
  Data.i 0, 255, 127
  Data.s "Magenta (M)"            
  Data.i 0, 255, 127
  Data.s "Jaune (Y)"    
  Data.i 0, 255, 127
  Data.s "Noir (K)"    
  Data.i 0, 255, 127
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 31
; FirstLine = 26
; Folding = -
; EnableXP
; DPIAware