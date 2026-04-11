Macro LowPassBlur_sp1(op)
  value = PeekL(*addr0 + index)
  getargb(value, a, r, g, b)
  histA(a) op a
  histR(r) op r
  histG(g) op g
  histB(b) op b
EndMacro

Macro LowPassBlur_sp2(var)
  sum = 0
  For i = 0 To 255
    sum + hist#var(i)
  Next
  avg#var = sum * invKernelArea  ; Multiplication au lieu de division
EndMacro

Procedure LowPassBlur_sp(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected kernelSize = *param\option[0]
  
  If kernelSize < 1 : kernelSize = 1 : EndIf
  kernelSize = (kernelSize << 1) + 1  ; Bit shift
  
  Protected half = kernelSize >> 1  ; Division par 2 optimisée
  Protected kernelArea = kernelSize * kernelSize
  Protected invKernelArea.f = 1.0 / kernelArea  ; Précalcul inverse
  
  Dim histA.l(255)
  Dim histR.l(255)
  Dim histG.l(255)
  Dim histB.l(255)
  
  Protected x, y, dx, dy, px, py, index
  Protected value, r.l, g.l, b.l, a.l, sum
  Protected avgA, avgR, avgG, avgB
  Protected oldX, newX
  Protected i
  
  ; Précalcul des constantes
  Protected lgMinus1 = lg - 1
  Protected htMinus1 = ht - 1
  Protected *addr0 = *param\addr[0]
  Protected *addr1 = *param\addr[1]
  Protected halfPlus1 = half + 1
  
  macro_calul_tread(ht)
  
  For y = thread_start To thread_stop - 1
    ; Réinitialiser histogrammes en une seule fois
    FillMemory(@histA(), 1024, 0)  ; 256*4 = 1024
    FillMemory(@histR(), 1024, 0)
    FillMemory(@histG(), 1024, 0)
    FillMemory(@histB(), 1024, 0)
    
    ; Fenêtre initiale (colonne x = 0)
    For dy = -half To half
      py = y + dy
      Clamp(py, 0, htMinus1)
      
      For dx = -half To half
        px = dx
        Clamp(px, 0, lgMinus1)
        
        index = (py * lg + px) << 2
        LowPassBlur_sp1(+)
      Next
    Next
    
    ; Parcours horizontal
    For x = 0 To lgMinus1
      ; Calcul de la moyenne pour chaque canal
      LowPassBlur_sp2(A)
      LowPassBlur_sp2(R)
      LowPassBlur_sp2(G)
      LowPassBlur_sp2(B)
      
      index = (y * lg + x) << 2
      PokeL(*addr1 + index, (avgA << 24) | (avgR << 16) | (avgG << 8) | avgB)
      
      ; Mise à jour glissante : retirer ancienne colonne / ajouter nouvelle
      If x < lgMinus1
        oldX = x - half
        Clamp(oldX, 0, lgMinus1)
        
        newX = x + halfPlus1
        Clamp(newX, 0, lgMinus1)
        
        For dy = -half To half
          py = y + dy
          Clamp(py, 0, htMinus1)
          
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
EndProcedure

Procedure LowPassBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Gaussian
    *param\name = "LowPassBlur"
    *param\remarque = ""
    *param\info[0] = "Rayon"
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 100 : *param\info_data(0,2) = 1
    ProcedureReturn
  EndIf
  
  If *param\option[0] < 1 : *param\option[0] = 1 : EndIf
  filter_start(@LowPassBlur_sp(), 8)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 124
; FirstLine = 55
; Folding = -
; EnableXP
; DPIAware