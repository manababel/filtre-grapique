Macro tab_log_sp(var)
  getrgb(PeekL(*srcPixel), r, g, b)
  gray(var) = (r*77 + g*150 + b*29) >> 8
  *srcPixel + 4
EndMacro

Procedure MarrHildreth_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected mul.f = *param\option[0] * 0.5
  Protected inverse = *param\option[1]

  Protected Dim gray.q(24)
  Protected *srcPixel.Long, *dstPixel.Long
  Protected x, y, i, j
  Protected v.q, maxv.q
  Protected kSize = 5
  Protected center = kSize/2
  Protected a , r , g, b
  
  ; Noyau tab_log fixe 5x5
  Protected Dim tab_log.l(kSize-1, kSize-1)
  tab_log(0,0)=0  : tab_log(0,1)=0  : tab_log(0,2)=-1 : tab_log(0,3)=0  : tab_log(0,4)=0
  tab_log(1,0)=0  : tab_log(1,1)=-1 : tab_log(1,2)=-2 : tab_log(1,3)=-1 : tab_log(1,4)=0
  tab_log(2,0)=-1 : tab_log(2,1)=-2 : tab_log(2,2)=16 : tab_log(2,3)=-2 : tab_log(2,4)=-1
  tab_log(3,0)=0  : tab_log(3,1)=-1 : tab_log(3,2)=-2 : tab_log(3,3)=-1 : tab_log(3,4)=0
  tab_log(4,0)=0  : tab_log(4,1)=0  : tab_log(4,2)=-1 : tab_log(4,3)=0  : tab_log(4,4)=0

  ; Limites pour multithread
  Protected startPos = (*param\thread_pos * (ht-kSize)) / *param\thread_max + center
  Protected endPos   = ((*param\thread_pos+1)*(ht-kSize)) / *param\thread_max + center
  If startPos < center : startPos = center : EndIf
  If endPos > ht-center-1 : endPos = ht-center-1 : EndIf

  For y = startPos To endPos
    For x = center To lg-center-1
      i = 0
      For j = -center To center
        *srcPixel = *source + ((y+j)*lg + (x-center))*4
        tab_log_sp(i) : tab_log_sp(i+1) : tab_log_sp(i+2) : tab_log_sp(i+3) : tab_log_sp(i+4)
        i = i + 5
      Next

      ; Convolution tab_log
      v = 0
      For j = 0 To kSize-1
        For i = 0 To kSize-1
          v + gray(j*kSize+i) * tab_log(i,j)
        Next
      Next

      ; Normalisation
      v = Abs(v) * mul
      clamp(v,0,255)
      If inverse : v = 255 - v : EndIf

      *dstPixel = *cible + (y*lg + x)*4
      PokeL(*dstPixel, $FF000000 | (v*$010101))
    Next
  Next

EndProcedure

Procedure MarrHildreth(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_EdgeDetection
    *param\subtype = #EdgeDetect_Laplacian
    *param\name = "Marr-Hildreth"
    *param\remarque = "Contour par Laplacien du Gaussien"
    *param\info[0] = "Multiplicateur"
    *param\info[1] = "Inversion"
    *param\info[2] = "mask"
    *param\info_data(0,0)=1 : *param\info_data(0,1)=10 : *param\info_data(0,2)=1
    *param\info_data(1,0)=0 : *param\info_data(1,1)=1  : *param\info_data(1,2)=0
    *param\info_data(2,0)=0 : *param\info_data(2,1)=2  : *param\info_data(2,2)=0
    ProcedureReturn
  EndIf
  filter_start(@MarrHildreth_MT(), 2)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 75
; FirstLine = 12
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger