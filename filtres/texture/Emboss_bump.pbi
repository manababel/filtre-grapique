Procedure Emboss_bump_MT(*p.parametre)
  Protected x, y, pos, j, i
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected a, r, g, b
  Protected lValue
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected Dim l(2,2)  ; 3x3 pour le gradient

  ; === Paramètres de lumière ===
  Protected azimuth.f   = *p\option[0]   ; 0..360°
  Protected elevation.f = *p\option[1] * 90 / 100  ; 0..90°
  If elevation < 1 : elevation = 1 : EndIf
  Protected intensity.f = (*p\option[2] + 50) / 100.0
  Protected light_mix   = *p\option[3]
  Protected bn     = *p\option[5]
  Protected mix_strength.f = *p\option[4] / 100
  Protected invert   = *p\option[6]
  
  ; --- Calcul vecteur lumière ---
  Protected lx.f, ly.f, lz.f
  lx = Cos(Radian(azimuth)) * Sin(Radian(elevation))
  ly = Sin(Radian(azimuth)) * Sin(Radian(elevation))
  lz = Cos(Radian(elevation))
  ; Normalisation correcte (affectation)
  Protected llen.f = Sqr(lx*lx + ly*ly + lz*lz)
  If llen <> 0.0
    lx = lx / llen : ly = ly / llen : lz = lz / llen
  EndIf

  ; --- Calcul plage verticale pour le thread ---
  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * ht) / *p\thread_max
  If endY > ht : endY = ht : EndIf
  Protected readStart = startY
  Protected readEnd   = endY
  If readStart < 1 : readStart = 1 : EndIf
  If readEnd > ht-2 : readEnd = ht-2 : EndIf

  For y = readStart To readEnd
    For x = 1 To lg-2
      pos = *p\addr[0] + ((y * lg + x) << 2)
      ; --- Lecture des 3x3 voisins ---
      For j = -1 To 1
        For i = -1 To 1
          *srcPixel = pos + ((j * lg + i) << 2)
          GetARGB(*srcPixel\l, a, r, g, b)
          l(i+1, j+1) = (r * 1225 + g * 2405 + b * 466) >> 12
        Next i
      Next j
      ; --- Calcul gradient ---
      Protected gx.f, gy.f, gz.f
      gx = ((l(2,0) + 2*l(2,1) + l(2,2)) - (l(0,0) + 2*l(0,1) + l(0,2)))
      gy = ((l(0,2) + 2*l(1,2) + l(2,2)) - (l(0,0) + 2*l(1,0) + l(2,0)))
      gz = 1.0  ; normalisation approximative

      ; --- Produit scalaire lumière × gradient ---
      lValue = 128 + intensity * (gx * lx + gy * ly + gz * lz)
      If bn
        lValue = lValue - 128
        If invert
          lValue = 255 - lValue
        EndIf 
      EndIf  
      lValue = Pow(lValue/255.0, 1.2) * 255
      Clamp(lValue, 0, 255)
      If y >= startY And y < endY
        *dstPixel = *p\addr[1] + ((y * lg + x) << 2)
        ; ---- Mélange lumière / couleur d'origine ----
        If light_mix
          ; récupération de la couleur d'origine
          GetARGB(*srcPixel\l, a, r, g, b)
          ; mélange (tu peux ajuster le facteur de mixage 0.5 → 0.2..0.8)
          r = r * (1.0 - mix_strength) + lValue * mix_strength
          g = g * (1.0 - mix_strength) + lValue * mix_strength
          b = b * (1.0 - mix_strength) + lValue * mix_strength
          
          Clamp_rgb(r, g , b)
          *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
        Else
          ; rendu emboss pur en niveaux de gris
          *dstPixel\l = (a << 24) | lValue * $10101
        EndIf
      EndIf
    Next
  Next
EndProcedure

    
    ;For y=0 To ht
    ;For x=0 To lg
        ;k1=0
        ;For yy=-val To 0
        ;For xx=-val To 0
            ;If ((x+xx)>=0 And (y+yy)>=0) Then
                ;rgb=tab(x+xx,y+yy)
                ;r=((rgb And $ff0000)Shr 16)
                ;g=((rgb And $00ff00)Shr 8)
                ;b=((rgb And $0000ff))
                ;c=(tabr(r)+tabg(g)+tabb(b))Shr 10
                ;If (xx+yy)=0 Then
                    ;k1=(c-(k1/k2)+255)Shr 1
                ;Else
                    ;k1=k1+c
                ;EndIf
            ;EndIf
        ;Next
        ;Next
            ;WritePixelFast(x,y,taba(k1),ImageBuffer(img))
    ;Next
  ;Next
  
; ----------------------------------------------------------------------------------
; Procédure principale d'effet Emboss (relief directionnel)

Procedure Emboss_bump(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_TexturePattern
    *param\name = "Emboss"
    *param\remarque = "Emboss (relief directionnel niveaux de gris)"
    *param\info[0] = "angle"
    *param\info[1] = "inclinaison"
    *param\info[2] = "intensity"
    *param\info[3] = "Mix_image"
    *param\info[4] = "mix_alpha"
    *param\info[5] = "Blanc/noir"
    *param\info[6] = "invert"
    *param\info[7] = "masque"
    *param\info_data(0,0) = 0    : *param\info_data(0,1) = 360  : *param\info_data(0,2) = 50
    *param\info_data(1,0) = 1    : *param\info_data(1,1) = 100  : *param\info_data(1,2) = 25
    *param\info_data(2,0) = 1    : *param\info_data(2,1) = 500  : *param\info_data(2,2) = 250
    *param\info_data(3,0) = 0    : *param\info_data(3,1) = 1    : *param\info_data(3,2) = 0
    *param\info_data(4,0) = 0    : *param\info_data(4,1) = 100  : *param\info_data(4,2) = 50
    *param\info_data(5,0) = 0    : *param\info_data(5,1) = 1    : *param\info_data(5,2) = 0
    *param\info_data(6,0) = 0    : *param\info_data(6,1) = 1    : *param\info_data(6,2) = 0
    *param\info_data(7,0) = 0    : *param\info_data(7,1) = 2    : *param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Emboss_bump_MT(), 7, 1)
  
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 68
; FirstLine = 31
; Folding = -
; EnableXP
; DPIAware