;==============================================================================
; GLOWEFFECT_IIR - Filtre d'effet de luminosité avec flou IIR
;==============================================================================

;------------------------------------------------------------------------------
; Macro de déclaration des variables communes à tous les threads
;------------------------------------------------------------------------------
Macro GlowEffect_IIR_DeclareVars()
  ; Pointeurs vers les buffers image
  Protected *source = *FilterCtx\addr[0]  ; Image source
  Protected *cible  = *FilterCtx\addr[1]  ; Image destination
  
  ; Dimensions de l'image
  Protected w = *FilterCtx\image_lg[0]
  Protected h = *FilterCtx\image_ht[0]
  
  ; Utilisation de la macro standard pour le découpage multithread
  Protected totalPixels = h
  macro_calul_tread(totalPixels)
  
  ; Redéfinition des bornes pour la compatibilité avec le code existant
  Protected start = thread_start
  Protected stop  = thread_stop
  
  ; Variables de travail
  Protected x, y        ; Coordonnées de pixel
  Protected pos         ; Offset mémoire du pixel courant
  Protected col         ; Couleur ARGB complète
  Protected a, r, g, b  ; Composantes de couleur
  Protected lum         ; Luminosité calculée
  
  ; Paramètres du filtre
  Protected GlowStrength = *FilterCtx\option[0]  ; Intensité du glow (0-100)
  Protected Radius = (50 - *FilterCtx\option[1])   ; Rayon du flou (Parenthèses pour macro)
  Protected seuil = *FilterCtx\option[2]         ; Seuil de luminosité (0-255)
  
  ; Calcul des coefficients IIR (filtre exponentiel)
  Protected mul = 256  
  Protected Alpha = (Exp(-2.3 / (Radius + 1.0))) * mul
  Protected inv_Alpha = mul - Alpha
  
  ; Pointeurs vers les buffers de travail RGB séparés
  Protected glowR = *FilterCtx\addr[2]  
  Protected glowG = *FilterCtx\addr[3]  
  Protected glowB = *FilterCtx\addr[4]  
  
  Protected.l rVal, gVal, bVal
EndMacro

;------------------------------------------------------------------------------
; Macro d'application du filtre IIR sur un pixel
;------------------------------------------------------------------------------
Macro GlowEffect_IIR_ApplyFilter()
  rVal = PeekL(glowR + pos)
  gVal = PeekL(glowG + pos)
  bVal = PeekL(glowB + pos)
  
  r = (Alpha * r + inv_Alpha * rVal) >> 8
  g = (Alpha * g + inv_Alpha * gVal) >> 8
  b = (Alpha * b + inv_Alpha * bVal) >> 8
  
  PokeL(glowR + pos, r)
  PokeL(glowG + pos, g)
  PokeL(glowB + pos, b)
EndMacro

;------------------------------------------------------------------------------
; ÉTAPES DU TRAITEMENT (Procédures MT)
;------------------------------------------------------------------------------

Procedure GlowEffect_IIR_MT_ExtractBright(*FilterCtx.FilterParams)
  With *FilterCtx
    GlowEffect_IIR_DeclareVars()
    For y = start To stop - 1
      For x = 0 To w - 1
        pos = (y * w + x) << 2 
        col = PeekL(*source + pos)
        r = (col >> 16) & $FF
        g = (col >> 8) & $FF
        b = col & $FF
        lum = (r * 77 + g * 151 + b * 28) >> 8
        If lum > seuil
          PokeL(glowR + pos, r)
          PokeL(glowG + pos, g)
          PokeL(glowB + pos, b)
        Else
          PokeL(glowR + pos, 0)
          PokeL(glowG + pos, 0)
          PokeL(glowB + pos, 0)
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure GlowEffect_IIR_MT_BlurHorizontal(*FilterCtx.FilterParams)
  With *FilterCtx
    GlowEffect_IIR_DeclareVars()
    For y = start To stop - 1
      pos = (y * w) << 2
      r = PeekL(glowR + pos)
      g = PeekL(glowG + pos)
      b = PeekL(glowB + pos)
      For x = 1 To w - 1
        pos = (y * w + x) << 2
        GlowEffect_IIR_ApplyFilter()
      Next
      pos = (y * w + (w - 1)) << 2
      r = PeekL(glowR + pos)
      g = PeekL(glowG + pos)
      b = PeekL(glowB + pos)
      For x = w - 2 To 0 Step -1
        pos = (y * w + x) << 2
        GlowEffect_IIR_ApplyFilter()
      Next
    Next
  EndWith
EndProcedure

Procedure GlowEffect_IIR_MT_BlurVertical(*FilterCtx.FilterParams)
  With *FilterCtx
    ; Récupération des variables de base
    Protected w = \image_lg[0]
    Protected h = \image_ht[1]
    
    ; Pour le flou vertical, le découpage se fait sur la largeur
    Protected totalPixels = w
    macro_calul_tread(totalPixels)
    
    Protected start = thread_start
    Protected stop  = thread_stop
    
    Protected x, y, pos, col, r, g, b, rVal, gVal, bVal
    Protected mul = 256
    Protected Radius = (50 - \option[1])
    Protected Alpha = (Exp(-2.3 / (Radius + 1.0))) * mul
    Protected inv_Alpha = mul - Alpha
    Protected glowR = \addr[2], glowG = \addr[3], glowB = \addr[4]

    For x = start To stop - 1
      pos = x << 2
      r = PeekL(glowR + pos)
      g = PeekL(glowG + pos)
      b = PeekL(glowB + pos)
      For y = 1 To h - 1
        pos = (y * w + x) << 2
        GlowEffect_IIR_ApplyFilter()
      Next
      pos = ((h - 1) * w + x) << 2
      r = PeekL(glowR + pos)
      g = PeekL(glowG + pos)
      b = PeekL(glowB + pos)
      For y = h - 2 To 0 Step -1
        pos = (y * w + x) << 2
        GlowEffect_IIR_ApplyFilter()
      Next
    Next
  EndWith
EndProcedure

Procedure GlowEffect_IIR_MT_Composite(*FilterCtx.FilterParams)
  With *FilterCtx
    GlowEffect_IIR_DeclareVars()
    For y = start To stop - 1
      For x = 0 To w - 1
        pos = (y * w + x) << 2
        col = PeekL(*cible + pos)
        Protected colR = (col >> 16) & $FF
        Protected colG = (col >> 8) & $FF
        Protected colB = col & $FF
        r = colR + ((PeekL(glowR + pos) * GlowStrength) >> 4)
        g = colG + ((PeekL(glowG + pos) * GlowStrength) >> 4)
        b = colB + ((PeekL(glowB + pos) * GlowStrength) >> 4)
        clamp_rgb(r, g, b)
        PokeL(*cible + pos, $FF000000 | (r << 16) | (g << 8) | b)
      Next
    Next
  EndWith
EndProcedure

;------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées (GlowEffect_IIR devient Ex)
;------------------------------------------------------------------------------

Procedure GlowEffect_IIREx(*FilterCtx.FilterParams)
  Restore GlowEffect_IIR_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected t = \image_lg[0] * \image_ht[1] * 4
    Protected *tempo = 0
    
    If \addr[0] = \addr[1]
      *tempo = AllocateMemory(t)
      If *tempo
        CopyMemory(\addr[0], *tempo, t)
        \addr[0] = *tempo
      EndIf
    EndIf
    
    Protected *glowR = AllocateMemory(t)
    Protected *glowG = AllocateMemory(t)
    Protected *glowB = AllocateMemory(t)
    
    If *glowR And *glowG And *glowB
      \addr[2] = *glowR
      \addr[3] = *glowG
      \addr[4] = *glowB
      
      Create_MultiThread_MT(@GlowEffect_IIR_MT_ExtractBright())
      Create_MultiThread_MT(@GlowEffect_IIR_MT_BlurHorizontal())
      Create_MultiThread_MT(@GlowEffect_IIR_MT_BlurVertical())
      Create_MultiThread_MT(@GlowEffect_IIR_MT_Composite())
      
      mask_update(*FilterCtx, last_data)
      
      FreeMemory(*glowR)
      FreeMemory(*glowG)
      FreeMemory(*glowB)
    EndIf
    
    If *tempo : FreeMemory(*tempo) : EndIf
  EndWith
EndProcedure

;------------------------------------------------------------------------------
; Interface simplifiée (Nom d'origine)
;------------------------------------------------------------------------------

Procedure GlowEffect_IIR(source, cible, mask, intensity, radius, threshold)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = intensity
    \option[1] = radius
    \option[2] = threshold
  EndWith
  GlowEffect_IIREx(FilterCtx)
EndProcedure

;------------------------------------------------------------------------------
; Données du filtre
;------------------------------------------------------------------------------

DataSection
  GlowEffect_IIR_Data:
  Data.s "GlowEffect_IIR"
  Data.s "Effet de halo lumineux avec filtre IIR (rapide et efficace)"
  Data.i #FilterType_Artistic
  Data.i #Artistic_Light
  
  Data.s "Intensité glow"
  Data.i 0, 100, 10
  
  Data.s "Rayon flou"
  Data.i 0, 50, 10
  
  Data.s "Seuil luminosité"
  Data.i 0, 255, 127
  
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 14
; Folding = --
; EnableXP
; DPIAware
; DisableDebugger