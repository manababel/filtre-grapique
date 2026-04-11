Procedure ChannelSwap_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected opt = *param\option[0]
  
  Clamp(opt, 0, 5)
  
  Protected i, var, a, r, g, b, rgb
  Protected totalPixels = lg * ht
  Protected startPos = (*param\thread_pos * totalPixels) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * totalPixels) / *param\thread_max
  
  Protected *srcPixel.Pixel32 = *source + (startPos << 2)
  Protected *dstPixel.Pixel32 = *cible + (startPos << 2)
  
  For i = startPos To endPos - 1
    var = *srcPixel\l
    getargb(var, a, r, g, b)
    
    ; Permutations directes des canaux (6 combinaisons possibles)
    Select opt
      Case 0 : rgb = (r << 16) | (g << 8) | b  ; RGB (original)
      Case 1 : rgb = (r << 16) | (b << 8) | g  ; RBG
      Case 2 : rgb = (g << 16) | (r << 8) | b  ; GRB
      Case 3 : rgb = (g << 16) | (b << 8) | r  ; GBR
      Case 4 : rgb = (b << 16) | (r << 8) | g  ; BRG
      Case 5 : rgb = (b << 16) | (g << 8) | r  ; BGR
    EndSelect
    
    *dstPixel\l = (a << 24) | rgb
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

Procedure ChannelSwap(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Channel Swap"
    param\remarque = "Permutation pure des canaux RGB"
    param\info[0] = "Mode"
    param\info[1] = "Masque"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 5 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2 : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@ChannelSwap_MT(), 1, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 51
; Folding = -
; EnableXP
; DPIAware