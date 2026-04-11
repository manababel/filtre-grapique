Procedure Posterize_MT(*p.parametre)
  Protected *source = *p\addr[0]
  Protected *cible  = *p\addr[1]
  Protected i, pixel, a, r, g, b
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  
  *srcPixel = *source + (startPos << 2)
  *dstPixel = *cible + (startPos << 2)
  
  For i = startPos To endPos - 1
    pixel = *srcPixel\l
    getargb(pixel, a, r, g, b)
    
    ; Lookup des valeurs posterisées
    r = PeekA(*p\addr[2] + r)
    g = PeekA(*p\addr[3] + g)
    b = PeekA(*p\addr[4] + b)
    
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure principale pour l'effet Posterize avec support multithread
Procedure Posterize(*param.parametre)
  ; Mode info
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Posterize"
    param\remarque = "Réduit le nombre de niveaux de couleur"
    param\info[0] = "Niveaux Rouge"
    param\info[1] = "Niveaux Vert"
    param\info[2] = "Niveaux Bleu"
    param\info[3] = "Masque"
    param\info_data(0,0) = 2   : param\info_data(0,1) = 256 : param\info_data(0,2) = 16
    param\info_data(1,0) = 2   : param\info_data(1,1) = 256 : param\info_data(1,2) = 16
    param\info_data(2,0) = 2   : param\info_data(2,1) = 256 : param\info_data(2,2) = 16
    param\info_data(3,0) = 0   : param\info_data(3,1) = 2   : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  
  Protected levelr = *param\option[0]  ; 2-256
  Protected levelg = *param\option[1]  ; 2-256
  Protected levelb = *param\option[2]  ; 2-256
  
  Clamp(levelr, 2, 256)
  Clamp(levelg, 2, 256)
  Clamp(levelb, 2, 256)
  
  ; Allocation des tables de lookup (LUT)
  *param\addr[2] = AllocateMemory(256)  ; LUT rouge
  *param\addr[3] = AllocateMemory(256)  ; LUT vert
  *param\addr[4] = AllocateMemory(256)  ; LUT bleu
  
  ; Précalcul des paliers pour chaque canal
  Protected i, stepR, stepG, stepB
  
  ; Calcul de la taille des paliers
  stepR = 256 / levelr
  stepG = 256 / levelg
  stepB = 256 / levelb
  
  ; Remplissage des tables de lookup
  For i = 0 To 255
    PokeA(*param\addr[2] + i, (i / stepR) * stepR)  ; Rouge
    PokeA(*param\addr[3] + i, (i / stepG) * stepG)  ; Vert
    PokeA(*param\addr[4] + i, (i / stepB) * stepB)  ; Bleu
  Next
  
  filter_start(@Posterize_MT(), 1, 1)
  
  ; Libération de la mémoire
  FreeMemory(*param\addr[2])
  FreeMemory(*param\addr[3])
  FreeMemory(*param\addr[4])
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 81
; FirstLine = 12
; Folding = -
; EnableXP
; DPIAware