Procedure Deriche_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected alpha.f = *param\option[0]
  Protected seuillage = *param\option[1]
  Protected toGray = *param\option[2]
  Protected inverse = *param\option[3]

  ; Coefficients
  Protected ea.f = Exp(-alpha)
  Protected k.f  = (1 - ea)*(1 - ea)/(1 + 2*alpha*ea - ea*ea)
  Protected a1.f = k
  Protected a2.f = k*ea*(alpha - 1)
  Protected a3.f = k
  Protected a4.f = k*ea*(alpha + 1)
  Protected b1.f = 2*ea
  Protected b2.f = -ea*ea

  ; Buffers temporaires
  Protected *tmpX = AllocateMemory(lg*ht*4)
  Protected *tmpY = AllocateMemory(lg*ht*4)
  
  Protected x , y
  ; --- Dérivée horizontale ---
  For y = 0 To ht-1
    Protected yp.f = 0, ym.f = 0
    For x = 0 To lg-1
      Protected *p.Pixel32 = (*source + (y*lg+x)*4)
      Protected r, g, b, a
      getargb(*p\l, a, r, g, b)
      If toGray
        r = (r*77 + g*150 + b*29) >> 8
        g = r : b = r
      EndIf

      Protected prevR.f = 0
      If x > 0
        prevR = PeekL(*source + (y*lg + x - 1)*4)
      EndIf

      yp = a1*r + b1*yp + b2*ym
      If x > 0
        yp = yp + a2*prevR
      EndIf
      ym = yp
      PokeL(*tmpX + (y*lg+x)*4, yp)
    Next
  Next

  ; --- Dérivée verticale ---
  For x = 0 To lg-1
    yp = 0 : ym = 0
    For y = 0 To ht-1
      Protected val.f
      val = PeekL(*tmpX + (y*lg+x)*4)
      Protected prevVal.f = 0
      If y > 0
        prevVal = PeekL(*tmpX + ((y-1)*lg+x)*4)
      EndIf

      yp = a1*val + b1*yp + b2*ym
      If y > 0
        yp = yp + a2*prevVal
      EndIf
      ym = yp
      PokeL(*tmpY + (y*lg+x)*4, yp)
    Next
  Next

  ; --- Magnitude et écriture ---
  For y = 0 To ht-1
    For x = 0 To lg-1

      val = Abs(PeekL(*tmpY + (y*lg+x)*4))
      If seuillage > 0
        If val > seuillage
          val = 255
        Else
          val = 0
        EndIf
      EndIf
      If inverse
        val = 255 - val
      EndIf
      Protected *pDst.Pixel32 = (*cible + (y*lg+x)*4)
      *pDst\l = (255<<24) | (Int(val)<<16) | (Int(val)<<8) | Int(val)
    Next
  Next

  FreeMemory(*tmpX)
  FreeMemory(*tmpY)
EndProcedure


Procedure Deriche(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_edge_detection
    param\subtype = #EdgeDetect_Gradient
    param\name = "Deriche"
    param\remarque = "Détection de contours par filtre récursif"
    param\info[0] = "alpha (0.0 → 1.0)"
    param\info[1] = "seuillage (0 = off)"
    param\info[2] = "Noir et blanc"
    param\info[3] = "inversion"
    param\info_data(0,0)=1 : param\info_data(0,1)=10 : param\info_data(0,2)=5
    param\info_data(1,0)=0 : param\info_data(1,1)=255 : param\info_data(1,2)=0
    param\info_data(2,0)=0 : param\info_data(2,1)=1 : param\info_data(2,2)=0
    param\info_data(3,0)=0 : param\info_data(3,1)=1 : param\info_data(3,2)=0
    ProcedureReturn
  EndIf
  filter_start(@Deriche_MT(), 4)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 99
; FirstLine = 48
; Folding = -
; EnableXP
; DPIAware