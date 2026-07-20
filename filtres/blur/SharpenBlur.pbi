; ============================================================================
; MACRO : Calcul et mélange Sharpen / Blur
; Syntaxiquement valide pour PureBasic (arguments sans type)
; ============================================================================
Macro ProcessSharpenBlurPixel(origR, origG, origB, blurR, blurG, blurB, sharpenAmount, blendRatio, r_out, g_out, b_out)
  ; 1. Netteté accentuée (Masque flou inversé)
  sharpR = origR + sharpenAmount * (origR - blurR)
  sharpG = origG + sharpenAmount * (origG - blurG)
  sharpB = origB + sharpenAmount * (origB - blurB)
  
  ; 2. Mélange entre version floutée et version accentuée
  fR = (blurR * blendRatio) + (sharpR * (1.0 - blendRatio))
  fG = (blurG * blendRatio) + (sharpG * (1.0 - blendRatio))
  fB = (blurB * blendRatio) + (sharpB * (1.0 - blendRatio))
  
  ; 3. Clamping
  If fR < 0.0 : r_out = 0 : ElseIf fR > 255.0 : r_out = 255 : Else : r_out = Int(fR) : EndIf
  If fG < 0.0 : g_out = 0 : ElseIf fG > 255.0 : g_out = 255 : Else : g_out = Int(fG) : EndIf
  If fB < 0.0 : b_out = 0 : ElseIf fB > 255.0 : b_out = 255 : Else : b_out = Int(fB) : EndIf
EndMacro

; ============================================================================
; PASSE 1 : Flou Box Horizontal (*src -> *tmp)
; ============================================================================
Procedure SharpenBlur_H_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected blurRadius = \option[0]
    If blurRadius < 1 : blurRadius = 1 : EndIf
    
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
        
        For dx = -blurRadius To blurRadius
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
; PASSE 2 : Flou Box Vertical + Calcul Sharpen & Mélange (*tmp -> *dst)
; ============================================================================
Procedure SharpenBlur_V_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected blurRadius      = \option[0]
    Protected sharpenAmount.f = \option[1] / 100.0
    Protected blendRatio.f    = \option[2] / 100.0
    If blurRadius < 1 : blurRadius = 1 : EndIf
    
    Protected i, j, dy, py, y_offset.i
    Protected a.l, r.l, g.l, b.l
    Protected origA.l, origR.l, origG.l, origB.l
    Protected sumR.l, sumG.l, sumB.l, count.l
    Protected blurR.l, blurG.l, blurB.l
    Protected finalR.l, finalG.l, finalB.l
    
    ; Variables locales requises pour la macro ProcessSharpenBlurPixel
    Protected sharpR.f, sharpG.f, sharpB.f
    Protected fR.f, fG.f, fB.f
    
    Protected *src.pixelarray = \addr[0]
    Protected *tmp.pixelarray = \addr[2]
    Protected *dst.pixelarray = \addr[1]
    
    macro_calul_tread(ht)
    
    For j = thread_start To thread_stop - 1
      y_offset = j * lg
      For i = 0 To lg - 1
        ; 1. Pixel original
        getargb(*src\l[y_offset + i], origA, origR, origG, origB)
        
        ; 2. Deuxième passe du flou (Vertical)
        sumR = 0 : sumG = 0 : sumB = 0 : count = 0
        
        For dy = -blurRadius To blurRadius
          py = j + dy
          If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
          
          getargb(*tmp\l[py * lg + i], a, r, g, b)
          
          sumR + r
          sumG + g
          sumB + b
          count + 1
        Next
        
        blurR = sumR / count
        blurG = sumG / count
        blurB = sumB / count
        
        ; 3. Application du calcul de netteté et du mélange
        ProcessSharpenBlurPixel(origR, origG, origB, blurR, blurG, blurB, sharpenAmount, blendRatio, finalR, finalG, finalB)
        
        ; 4. Écriture dans l'image destination
        *dst\l[y_offset + i] = (origA << 24) | (finalR << 16) | (finalG << 8) | finalB
      Next
    Next
  EndWith
EndProcedure

; ============================================================================
; LANCEUR PRINCIPAL ET ENVELOPPE PUBLIQUE
; ============================================================================
Procedure SharpenBlurEx(*FilterCtx.FilterParams)
  Restore SharpenBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  With *FilterCtx
    Protected imgSize = \image_lg[0] * \image_ht[0] * 4
    
    ; Allocation du tampon temporaire \addr[2]
    \addr[2] = AllocateMemory(imgSize)
    
    If \addr[2]
      Create_MultiThread_MT(@SharpenBlur_H_MT())
      Create_MultiThread_MT(@SharpenBlur_V_MT())
      
      FreeMemory(\addr[2])
    EndIf
    
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure SharpenBlur(source, cible, mask, rayon_flou, force_nettete, ratio_flou)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon_flou
    \option[1] = force_nettete
    \option[2] = ratio_flou
  EndWith
  SharpenBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  SharpenBlur_data:
  Data.s "SharpenBlur"
  Data.s "Combinaison ajustable de flou et de netteté accentuée"
  Data.i #FilterType_Blur
  Data.i #Blur_Specialized
  
  Data.s "Rayon flou"
  Data.i 1, 20, 5
  Data.s "Force netteté (%)"
  Data.i 0, 300, 150
  Data.s "Ratio flou (%)"
  Data.i 0, 100, 30
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 104
; FirstLine = 100
; Folding = -
; EnableXP
; DPIAware