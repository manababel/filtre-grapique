; ────────────────────────────────────────────────────────────────
; Applique un filtre sépia à une image ARGB 32 bits.
;
; Chaque pixel est converti avec la transformation :
;   R' = (R×0.393 + G×0.769 + B×0.189)
;   G' = (R×0.349 + G×0.686 + B×0.168)
;   B' = (R×0.272 + G×0.534 + B×0.131)
;
; Un paramètre de température permet d'ajuster entre sépia chaud et froid.
; ────────────────────────────────────────────────────────────────
Procedure Sepia_MT(*p.parametre)
  Protected i, r, g, b, a, var
  Protected totalPixels = *p\lg * *p\ht
  Protected *src.Pixel32
  Protected *dst.Pixel32
  
  ; Facteur de température : 0-200, où 100 = sépia standard
  Protected temperature = *p\option[0]
  Protected tempOffset = temperature - 100  ; -100 à +100
  
  Protected start = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected stop  = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  
  *src = *p\addr[0] + (start << 2)
  *dst = *p\addr[1] + (start << 2)
  
  For i = start To stop - 1
    var = *src\l
    getargb(var, a, r, g, b)
    
    ; Transformation sépia (coefficients entiers approximés / 256)
    ; R' ≈ 0.393R + 0.769G + 0.189B → (101R + 197G + 48B) / 256
    ; G' ≈ 0.349R + 0.686G + 0.168B → (89R + 175G + 43B) / 256
    ; B' ≈ 0.272R + 0.534G + 0.131B → (70R + 137G + 33B) / 256
    Protected r2 = (r * 101 + g * 197 + b * 48) >> 8
    Protected g2 = (r * 89  + g * 175 + b * 43) >> 8
    Protected b2 = (r * 70  + g * 137 + b * 33) >> 8
    
    ; Ajustement de température
    ; tempOffset > 0 : plus chaud (rouge++, bleu--)
    ; tempOffset < 0 : plus froid (rouge--, bleu++)
    r2 + (tempOffset * 40) / 100
    b2 - (tempOffset * 40) / 100
    
    Clamp_RGB(r2, g2, b2)
    *dst\l = (a << 24) | (r2 << 16) | (g2 << 8) | b2
    
    *src + 4
    *dst + 4
  Next
EndProcedure

Procedure Sepia(*param.parametre)
  If *param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Sepia Tone"
    param\remarque = "Effet sépia vintage avec contrôle de température"
    *param\info[0] = "Température"
    *param\info[1] = "Masque"
    param\info_data(0,0) = 0   : param\info_data(0,1) = 200 : param\info_data(0,2) = 100
    param\info_data(1,0) = 0   : param\info_data(1,1) = 2   : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Sepia_MT(), 1, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 65
; Folding = -
; EnableXP
; DPIAware