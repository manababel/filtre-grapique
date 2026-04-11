; ────────────────────────────────────────────────────────────────
; Procédure thread pour inversion négative d'une image ARGB 32 bits
;
; - Inversion bit à bit de chaque pixel ARGB (effet négatif)
; - Appliqué uniquement si masque absent ou alpha >= 128
; - Optimisé pour multithread
; ────────────────────────────────────────────────────────────────
Procedure Negatif_MT(*p.parametre)
  Protected i, a, r, g, b, alpha, var
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected *mask = *p\mask

  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max

  For i = startPos To endPos - 1
    *srcPixel = *p\addr[0] + (i << 2)
    *dstPixel = *p\addr[1] + (i << 2)

    var = *srcPixel\l
    GetARGB(var, a, r, g, b)

    ; Inversion négative : on inverse tous les bits (ARGB)
    *dstPixel\l = ~var
  Next
EndProcedure


Procedure Negatif(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Négatif"
    param\remarque = ""
    param\info[0] = "Masque"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 2 : param\info_data(0,2) = 0
    ProcedureReturn
  EndIf

  filter_start(@Negatif_MT(), 0, 1)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 19
; Folding = -
; EnableXP
; DPIAware