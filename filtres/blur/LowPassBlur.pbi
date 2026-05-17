Macro LowPassBlur_sp1(op)
  *srcPixel = *FilterCtx\addr[0] + (index)
  value = *srcPixel\l
  getargb(value, a, r, g, b)
  histA(a) op 1
  histR(r) op 1
  histG(g) op 1
  histB(b) op 1
EndMacro

Macro LowPassBlur_sp2(var)
  sum = 0
  ; Note : ici on calcule la somme des valeurs pondérées par l'histogramme
  For i = 0 To 255
    sum + (hist#var(i) * i)
  Next
  avg#var = sum * invKernelArea
EndMacro

Procedure LowPassBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected kernelSize = \option[0]
    
    If kernelSize < 1 : kernelSize = 1 : EndIf
    kernelSize = (kernelSize << 1) + 1
    
    Protected half = kernelSize >> 1
    Protected kernelArea = kernelSize * kernelSize
    Protected invKernelArea.f = 1.0 / kernelArea
    
    ; Histogrammes locaux pour le thread
    Dim histA.l(255)
    Dim histR.l(255)
    Dim histG.l(255)
    Dim histB.l(255)
    
    Protected x, y, dx, dy, px, py, index
    Protected value, r.l, g.l, b.l, a.l, sum, i
    Protected avgA, avgR, avgG, avgB
    Protected oldX, newX
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    
    ; Précalcul des constantes
    Protected lgMinus1 = lg - 1
    Protected htMinus1 = ht - 1
    Protected halfPlus1 = half + 1
    
    macro_calul_tread(ht)
    
    For y = thread_start To thread_stop - 1
      ; Réinitialiser les histogrammes pour chaque nouvelle ligne
      FillMemory(@histA(0), 1024, 0)
      FillMemory(@histR(0), 1024, 0)
      FillMemory(@histG(0), 1024, 0)
      FillMemory(@histB(0), 1024, 0)
      
      ; Fenêtre initiale (colonne x = 0)
      For dy = -half To half
        py = y + dy
        If py < 0 : py = 0 : ElseIf py > htMinus1 : py = htMinus1 : EndIf
        
        For dx = -half To half
          px = dx
          If px < 0 : px = 0 : ElseIf px > lgMinus1 : px = lgMinus1 : EndIf
          
          index = (py * lg + px) << 2
          LowPassBlur_sp1(+)
        Next
      Next
      
      ; Parcours horizontal (Fenêtre glissante)
      For x = 0 To lgMinus1
        LowPassBlur_sp2(A)
        LowPassBlur_sp2(R)
        LowPassBlur_sp2(G)
        LowPassBlur_sp2(B)
        
        *dstPixel = \addr[1] + ((y * lg + x) << 2)
        *dstPixel\l = (avgA << 24) | (avgR << 16) | (avgG << 8) | avgB
        
        ; Mise à jour glissante : retirer ancienne colonne / ajouter nouvelle
        If x < lgMinus1
          oldX = x - half
          If oldX < 0 : oldX = 0 : ElseIf oldX > lgMinus1 : oldX = lgMinus1 : EndIf
          
          newX = x + halfPlus1
          If newX < 0 : newX = 0 : ElseIf newX > lgMinus1 : newX = lgMinus1 : EndIf
          
          For dy = -half To half
            py = y + dy
            If py < 0 : py = 0 : ElseIf py > htMinus1 : py = htMinus1 : EndIf
            
            ; Retirer ancienne colonne
            index = (py * lg + oldX) << 2
            LowPassBlur_sp1(-)
            
            ; Ajouter nouvelle colonne
            index = (py * lg + newX) << 2
            LowPassBlur_sp1(+)
          Next
        EndIf
      Next
    Next
    
    FreeArray(histA())
    FreeArray(histR())
    FreeArray(histG())
    FreeArray(histB())
  EndWith
EndProcedure

Procedure LowPassBlurEx(*FilterCtx.FilterParams)
  Restore LowPassBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@LowPassBlur_MT())
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure LowPassBlur(source, cible, mask, rayon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
  EndWith
  LowPassBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  LowPassBlur_data:
  Data.s "LowPassBlur"
  Data.s "Flou passe-bas optimisé par histogramme glissant"
  Data.i #FilterType_Blur
  Data.i #Blur_Gaussian
  
  Data.s "Rayon"
  Data.i 1, 100, 1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 1
; Folding = -
; EnableXP
; DPIAware