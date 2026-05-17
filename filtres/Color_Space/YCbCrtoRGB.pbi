; =================================================================
; FILTRE : YCbCr vers RGB (Norme BT.601)
; Description : Convertit l'espace YCbCr (Y=R, Cb=G, Cr=B) en RGB.
; =================================================================

Procedure YCbCrtoRGB_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src.PixelArray32 = \addr[0]
    Protected *dst.PixelArray32 = \addr[1]
    
    ; Variables de calcul
    Protected.f y, cb, cr, r, g, b
    Protected.l i, alpha, y_in, cb_in, cr_in
    Protected.l r8, g8, b8
    
    ; Définition de la zone de travail du thread
    macro_calul_tread((\image_lg[0] * \image_ht[0]))
    
    For i = thread_start To thread_stop - 1
      ; 1. Extraction des composantes YCbCr depuis les canaux R, G, B
      getargb(*src\pixel[i], alpha, y_in, cb_in, cr_in)
      
      ; 2. Application des réglages utilisateur sur les signaux d'entrée
      ; On ajuste les signaux avant le décodage matriciel
      y  = y_in  + (\option[0] - 127)
      cb = cb_in + (\option[1] - 127)
      cr = cr_in + (\option[2] - 127)
      
      ; 3. Retrait des offsets de la norme BT.601
      ; Y commence à 16, Cb et Cr sont centrés sur 128
      y  = y - 16.0
      cb = cb - 128.0
      cr = cr - 128.0
      
      ; 4. Formules de décodage (Matrice inverse BT.601)
      ; R = 1.164Y + 1.596Cr
      ; G = 1.164Y - 0.392Cb - 0.813Cr
      ; B = 1.164Y + 2.017Cb
      r = 1.164383 * y + 1.596027 * cr
      g = 1.164383 * y - 0.391762 * cb - 0.812968 * cr
      b = 1.164383 * y + 2.017232 * cb
      
      ; 5. Conversion en entiers 8 bits avec protection (Clamp)
      r8 = Int(r) : If r8 < 0 : r8 = 0 : ElseIf r8 > 255 : r8 = 255 : EndIf
      g8 = Int(g) : If g8 < 0 : g8 = 0 : ElseIf g8 > 255 : g8 = 255 : EndIf
      b8 = Int(b) : If b8 < 0 : b8 = 0 : ElseIf b8 > 255 : b8 = 255 : EndIf
      
      ; 6. Stockage dans le buffer de destination
      *dst\pixel[i] = (alpha << 24) | (r8 << 16) | (g8 << 8) | b8
    Next
  EndWith
EndProcedure

Procedure YCbCrtoRGBEx(*FilterCtx.FilterParams)
  Restore YCbCrtoRGB_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@YCbCrtoRGB_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure YCbCrtoRGB(source, cible, mask, y_adj, cb_adj, cr_adj)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = y_adj
    \option[1] = cb_adj
    \option[2] = cr_adj
  EndWith
  YCbCrtoRGBEx(FilterCtx.FilterParams)
EndProcedure

; ─── Données du Filtre ───
DataSection
  YCbCrtoRGB_data:
  Data.s "YCbCr -> RGB"
  Data.s "Décodage Espace Couleur Vidéo Numérique"
  Data.i #FilterType_ColorSpace
  Data.i 0
  
  Data.s "Y (Luminosité)"            
  Data.i 0, 255, 127
  Data.s "Cb (Chroma Bleu)"            
  Data.i 0, 255, 127
  Data.s "Cr (Chroma Rouge)"    
  Data.i 0, 255, 127
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 5
; Folding = -
; EnableXP
; DPIAware