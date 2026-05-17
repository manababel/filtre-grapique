; =================================================================
; FILTRE : CMYK vers RGB
; Description : Convertit les taux d'encre (C, M, Y) et le noir (K)
;               en couleurs d'affichage (R, G, B).
; =================================================================

Procedure CMYKtoRGB_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    ; Variables de calcul
    Protected.f c, m, y, k, r, g, b
    Protected.l i, alpha, c_in, m_in, y_in
    Protected.l r8, g8, b8
    
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Extraction des composantes CMY depuis les canaux R, G, B
      getargb(*src\pixel[i], alpha, c_in, m_in, y_in)
      
      ; 2. Normalisation et application des réglages utilisateur
      ; On récupère K depuis l'option[3] (Le Noir "Key")
      k = (\option[3] / 255.0)
      
      ; On récupère C, M, Y et on applique l'ajustement des options
      c = (c_in / 255.0) + ((\option[0] - 127) / 127.0)
      m = (m_in / 255.0) + ((\option[1] - 127) / 127.0)
      y = (y_in / 255.0) + ((\option[2] - 127) / 127.0)
      
      ; Protection des bornes [0.0 - 1.0]
      If c < 0 : c = 0 : ElseIf c > 1 : c = 1 : EndIf
      If m < 0 : m = 0 : ElseIf m > 1 : m = 1 : EndIf
      If y < 0 : y = 0 : ElseIf y > 1 : y = 1 : EndIf
      If k < 0 : k = 0 : ElseIf k > 1 : k = 1 : EndIf
      
      ; 3. Formules de conversion CMYK -> RGB
      ; R = 255 * (1-C) * (1-K)
      ; G = 255 * (1-M) * (1-K)
      ; B = 255 * (1-Y) * (1-K)
      r = 255.0 * (1.0 - c) * (1.0 - k)
      g = 255.0 * (1.0 - m) * (1.0 - k)
      b = 255.0 * (1.0 - y) * (1.0 - k)
      
      ; 4. Conversion en entiers 8 bits avec Clamp
      r8 = Int(r) : If r8 < 0 : r8 = 0 : ElseIf r8 > 255 : r8 = 255 : EndIf
      g8 = Int(g) : If g8 < 0 : g8 = 0 : ElseIf g8 > 255 : g8 = 255 : EndIf
      b8 = Int(b) : If b8 < 0 : b8 = 0 : ElseIf b8 > 255 : b8 = 255 : EndIf
      
      ; 5. Stockage dans le buffer de destination (Format standard RGB)
      *dst\pixel[i] = (alpha << 24) | (r8 << 16) | (g8 << 8) | b8
    Next
  EndWith
EndProcedure

Procedure CMYKtoRGBEx(*FilterCtx.FilterParams)
  Restore CMYKtoRGB_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@CMYKtoRGB_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure CMYKtoRGB(source, cible, mask, c_adj, m_adj, y_adj, k_val)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = c_adj
    \option[1] = m_adj
    \option[2] = y_adj
    \option[3] = k_val ; Ici K sert souvent de réglage d'intensité globale
  EndWith
  CMYKtoRGBEx(FilterCtx.FilterParams)
EndProcedure

; ─── Données du Filtre ───
DataSection
  CMYKtoRGB_data:
  Data.s "CMYK -> RGB"
  Data.s "Décodage pour affichage écran (Aperçu Impression)"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Densité Cyan"            
  Data.i 0, 255, 127
  Data.s "Densité Magenta"            
  Data.i 0, 255, 127
  Data.s "Densité Jaune"    
  Data.i 0, 255, 127
  Data.s "Noir (K) Global"    
  Data.i 0, 255, 0 ; Par défaut à 0 pour ne pas assombrir l'image
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 64
; FirstLine = 40
; Folding = -
; EnableXP
; DPIAware