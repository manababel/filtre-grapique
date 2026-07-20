; ============================================================================
; MACRO : Calcul Unsharp Mask (Seuil + Renforcement + Clamping)
; Syntaxiquement valide pour PureBasic (arguments sans type)
; ============================================================================
Macro ProcessUnsharpPixel(origR, origG, origB, blurR, blurG, blurB, amount_f, threshold, r_out, g_out, b_out)
  ; 1. Calcul de la différence globale pour le seuil
  diff_val = Abs(origR - blurR) + Abs(origG - blurG) + Abs(origB - blurB)
  
  If diff_val >= threshold
    ; Formule d'accentuation : original + force * (original - flou)
    rf_val = origR + amount_f * (origR - blurR)
    gf_val = origG + amount_f * (origG - blurG)
    bf_val = origB + amount_f * (origB - blurB)
    
    ; Clamping
    If rf_val < 0.0 : r_out = 0 : ElseIf rf_val > 255.0 : r_out = 255 : Else : r_out = Int(rf_val) : EndIf
    If gf_val < 0.0 : g_out = 0 : ElseIf gf_val > 255.0 : g_out = 255 : Else : g_out = Int(gf_val) : EndIf
    If bf_val < 0.0 : b_out = 0 : ElseIf bf_val > 255.0 : b_out = 255 : Else : b_out = Int(bf_val) : EndIf
  Else
    ; Si sous le seuil, conservation de l'original (évite le bruit sur les aplats)
    r_out = origR
    g_out = origG
    b_out = origB
  EndIf
EndMacro

; ============================================================================
; PASSE 1 : Flou Box Horizontal (*src -> *tmp)
; ============================================================================
Procedure UnsharpMask_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius = \option[0]
    If radius < 1 : radius = 1 : EndIf
    
    Protected i, j, dx, px, y_offset.i
    Protected a.l, r.l, g.l, b.l
    Protected sumA.l, sumR.l, sumG.l, sumB.l, count.l
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    
    macro_calul_tread(ht)
    
    For j = thread_start To thread_stop - 1
      y_offset = j * lg
      For i = 0 To lg - 1
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0 : count = 0
        
        For dx = -radius To radius
          px = i + dx
          If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
          
          getargb(*src\l[y_offset + px], a, r, g, b)
          
          sumA + a
          sumR + r
          sumG + g
          sumB + b
          count + 1
        Next
        
        *tmp\l[y_offset + i] = ((sumA / count) << 24) | ((sumR / count) << 16) | ((sumG / count) << 8) | (sumB / count)
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; PASSE 2 : Flou Box Vertical + Application Accentuation (*tmp -> *dst)
; ============================================================================
Procedure UnsharpMask_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected radius    = \option[0]
    Protected amount_f.f = \option[1] / 100.0
    Protected threshold = \option[2]
    If radius < 1 : radius = 1 : EndIf
    
    Protected i, j, dy, py, y_offset.i
    Protected a.l, r.l, g.l, b.l
    Protected origA.l, origR.l, origG.l, origB.l
    Protected sumA.l, sumR.l, sumG.f, sumB.f, sumR_l.l, sumG_l.l, sumB_l.l, count.l
    Protected blurR.l, blurG.l, blurB.l
    Protected finalR.l, finalG.l, finalB.l
    
    ; Variables locales requises pour la macro ProcessUnsharpPixel
    Protected diff_val.l, rf_val.f, gf_val.f, bf_val.f
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(ht)
    
    For j = thread_start To thread_stop - 1
      y_offset = j * lg
      For i = 0 To lg - 1
        ; 1. Récupération du pixel original
        getargb(*src\l[y_offset + i], origA, origR, origG, origB)
        
        ; 2. Deuxième passe du flou (Vertical)
        sumR_l = 0 : sumG_l = 0 : sumB_l = 0 : count = 0
        
        For dy = -radius To radius
          py = j + dy
          If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
          
          getargb(*tmp\l[py * lg + i], a, r, g, b)
          
          sumR_l + r
          sumG_l + g
          sumB_l + b
          count + 1
        Next
        
        blurR = sumR_l / count
        blurG = sumG_l / count
        blurB = sumB_l / count
        
        ; 3. Application du calcul Unsharp Mask
        ProcessUnsharpPixel(origR, origG, origB, blurR, blurG, blurB, amount_f, threshold, finalR, finalG, finalB)
        
        ; 4. Écriture dans l'image destination
        *dst\l[y_offset + i] = (origA << 24) | (finalR << 16) | (finalG << 8) | finalB
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; LANCEUR PRINCIPAL ET ENVELOPPE PUBLIQUE
; ============================================================================
Procedure UnsharpMaskEx(*FilterCtx.FilterParams)
  Restore UnsharpMask_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  With *FilterCtx
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation du tampon temporaire \addr[2]
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@UnsharpMask_H_MT())
      Create_MultiThread_MT(@UnsharpMask_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure UnsharpMask(source, cible, mask, rayon, force, seuil)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = force
    \option[2] = seuil
  EndWith
  UnsharpMaskEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  UnsharpMask_data:
  Data.s "UnsharpMask"
  Data.s "Accentuation par masque flou (Unsharp Mask)"
  Data.i #FilterType_Blur
  Data.i #Blur_Specialized
  
  Data.s "Rayon"
  Data.i 1, 20, 3
  Data.s "Force (%)"
  Data.i 0, 500, 100
  Data.s "Seuil"
  Data.i 0, 100, 5
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 108
; FirstLine = 104
; Folding = -
; EnableXP
; DPIAware