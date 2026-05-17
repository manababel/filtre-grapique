;------------------------------------------------
; Macro pour convertir un pixel en niveau de gris
;------------------------------------------------
Macro tab_log_sp(var)
  getrgb(PeekL(*srcPixel), r, g, b)
  gray(var) = (r*77 + g*150 + b*29) >> 8
  *srcPixel + 4
EndMacro

;------------------------------------------------
; Procedure Marr-Hildreth - traitement multi-thread
;------------------------------------------------
Procedure MarrHildreth_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected mul.f = \option[0] * 0.5
    Protected inverse = \option[1]

    Protected Dim gray.q(24)
    Protected *srcPixel.Long, *dstPixel.Long
    Protected x, y, i, j
    Protected v.q, maxv.q
    Protected kSize = 5
    Protected center = kSize/2
    Protected a, r, g, b
    
    ; Noyau tab_log fixe 5x5
    Protected Dim tab_log.l(kSize-1, kSize-1)
    tab_log(0,0)=0  : tab_log(0,1)=0  : tab_log(0,2)=-1 : tab_log(0,3)=0  : tab_log(0,4)=0
    tab_log(1,0)=0  : tab_log(1,1)=-1 : tab_log(1,2)=-2 : tab_log(1,3)=-1 : tab_log(1,4)=0
    tab_log(2,0)=-1 : tab_log(2,1)=-2 : tab_log(2,2)=16 : tab_log(2,3)=-2 : tab_log(2,4)=-1
    tab_log(3,0)=0  : tab_log(3,1)=-1 : tab_log(3,2)=-2 : tab_log(3,3)=-1 : tab_log(3,4)=0
    tab_log(4,0)=0  : tab_log(4,1)=0  : tab_log(4,2)=-1 : tab_log(4,3)=0  : tab_log(4,4)=0

    ; Limites pour multithread
    macro_calul_tread((ht - kSize))
    Protected startPos = thread_start + center
    Protected endPos   = thread_stop + center
    
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
  EndWith
EndProcedure

;------------------------------------------------
; Procedure MarrHildrethEx
;------------------------------------------------
Procedure MarrHildrethEx(*FilterCtx.FilterParams)
  
  Restore MarrHildreth_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@MarrHildreth_MT())
  
  mask_update(*FilterCtx.FilterParams , last_data)
  
EndProcedure

;------------------------------------------------
; Procedure principale
;------------------------------------------------
Procedure MarrHildreth(source , cible , mask , multiplicateur , inversion)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = multiplicateur
    \option[1] = inversion
  EndWith
  MarrHildrethEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  MarrHildreth_data:
  Data.s "MarrHildreth"
  Data.s "Contour par Laplacien du Gaussien"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Laplacian
  
  Data.s "Multiplicateur"        
  Data.i 1,10,1
  Data.s "Inversion"   
  Data.i 0,1,0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 92
; FirstLine = 64
; Folding = -
; EnableXP
; DPIAware
; DisableDebugger