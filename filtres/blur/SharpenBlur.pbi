Procedure SharpenBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected blurRadius = \option[0]
    Protected sharpenAmount.f = \option[1] / 100.0  ; Force netteté
    Protected blendRatio.f = \option[2] / 100.0     ; Mélange flou/net
    
    Protected x, y, dx, dy, px, py
    Protected r, g, b, a
    Protected blurR, blurG, blurB
    Protected origR, origG, origB, origA
    Protected sumR, sumG, sumB, count
    Protected sharpR.f, sharpG.f, sharpB.f
    Protected finalR.f, finalG.f, finalB.f
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        ; Pixel original
        *srcPixel = \addr[0] + ((y * lg + x) << 2)
        getargb(*srcPixel\l, origA, origR, origG, origB)
        
        ; Calcul du flou
        sumR = 0 : sumG = 0 : sumB = 0 : count = 0
        
        For dy = -blurRadius To blurRadius
          py = y + dy
          If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
          
          For dx = -blurRadius To blurRadius
            px = x + dx
            If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
            
            *srcPixel = \addr[0] + ((py * lg + px) << 2)
            sumR + ((*srcPixel\l >> 16) & $FF)
            sumG + ((*srcPixel\l >> 8) & $FF)
            sumB + (*srcPixel\l & $FF)
            count + 1
          Next
        Next
        
        blurR = sumR / count
        blurG = sumG / count
        blurB = sumB / count
        
        ; Netteté accentuée (Masque flou inversé)
        sharpR = origR + sharpenAmount * (origR - blurR)
        sharpG = origG + sharpenAmount * (origG - blurG)
        sharpB = origB + sharpenAmount * (origB - blurB)
        
        ; Mélange entre flou et netteté
        finalR = (blurR * blendRatio) + (sharpR * (1.0 - blendRatio))
        finalG = (blurG * blendRatio) + (sharpG * (1.0 - blendRatio))
        finalB = (blurB * blendRatio) + (sharpB * (1.0 - blendRatio))
        
        ; Clamping
        If finalR < 0 : finalR = 0 : ElseIf finalR > 255 : finalR = 255 : EndIf
        If finalG < 0 : finalG = 0 : ElseIf finalG > 255 : finalG = 255 : EndIf
        If finalB < 0 : finalB = 0 : ElseIf finalB > 255 : finalB = 255 : EndIf
        
        ; Écriture du résultat
        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (origA << 24) | (Int(finalR) << 16) | (Int(finalG) << 8) | Int(finalB)
      Next
    Next
  EndWith
EndProcedure

Procedure SharpenBlurEx(*FilterCtx.FilterParams)
  Restore SharpenBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@SharpenBlur_MT())
  
  mask_update(*FilterCtx, last_data)
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
; CursorPosition = 82
; FirstLine = 57
; Folding = -
; EnableXP
; DPIAware