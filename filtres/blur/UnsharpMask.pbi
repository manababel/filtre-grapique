Procedure UnsharpMask_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]
    Protected amount.f = \option[1] / 100.0  ; Force (0-500%)
    Protected threshold = \option[2]         ; Seuil de détection des contours
    
    Protected x, y, dx, dy, px, py
    Protected r, g, b, a
    Protected blurR, blurG, blurB
    Protected origR, origG, origB, origA
    Protected sumR, sumG, sumB, count
    Protected diff, sharpR, sharpG, sharpB
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      For x = 0 To lg - 1
        ; Pixel original
        *srcPixel = \addr[0] + ((y * lg + x) << 2)
        getargb(*srcPixel\l, origA, origR, origG, origB)
        
        ; Calcul du flou local (Box Blur pour le masque)
        sumR = 0 : sumG = 0 : sumB = 0 : count = 0
        
        For dy = -radius To radius
          py = y + dy
          If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
          
          For dx = -radius To radius
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
        
        ; Calcul de la différence (masque flou)
        ; On utilise la somme des différences absolues pour le seuil
        diff = Abs(origR - blurR) + Abs(origG - blurG) + Abs(origB - blurB)
        
        If diff >= threshold
          ; Formule d'accentuation : original + force * (original - flou)
          sharpR = origR + amount * (origR - blurR)
          sharpG = origG + amount * (origG - blurG)
          sharpB = origB + amount * (origB - blurB)
          
          ; Clamping des valeurs
          If sharpR < 0 : sharpR = 0 : ElseIf sharpR > 255 : sharpR = 255 : EndIf
          If sharpG < 0 : sharpG = 0 : ElseIf sharpG > 255 : sharpG = 255 : EndIf
          If sharpB < 0 : sharpB = 0 : ElseIf sharpB > 255 : sharpB = 255 : EndIf
          
          r = sharpR
          g = sharpG
          b = sharpB
        Else
          ; En dessous du seuil, on préserve l'original (évite de bruiter les aplats)
          r = origR
          g = origG
          b = origB
        EndIf
        
        ; Écriture vers la cible
        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (origA << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure UnsharpMaskEx(*FilterCtx.FilterParams)
  Restore UnsharpMask_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@UnsharpMask_MT())
  
  mask_update(*FilterCtx, last_data)
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
; CursorPosition = 115
; FirstLine = 66
; Folding = -
; EnableXP
; DPIAware