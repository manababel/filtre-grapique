Procedure BlackAndWhite_MT(*param.parametre)   
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected seuil = *param\option[0]
  Protected option = *param\option[1]
  clamp(option , 1 , 9)
  
  Protected i, lum, l1, l2
  Protected var, a, r, g, b
  
  Protected totalPixels = lg * ht
  Protected start = (*param\thread_pos * totalPixels) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * totalPixels) / *param\thread_max
  
  Protected *srcPixel.Pixel32 = *source + (start << 2)
  Protected *dstPixel.Pixel32 = *cible + (start << 2)
  
  For i = start To stop - 1
    var = *srcPixel\l
    getargb(var, a, r, g, b)
    
    Select option
      Case 1  ; Rec.601 (0.299R + 0.587G + 0.114B) - Standard TV
        lum = (r * 77 + g * 150 + b * 29) >> 8
        
      Case 2  ; Rec.709 (0.2126R + 0.7152G + 0.0722B) - Vidéo HD
        lum = (r * 54 + g * 183 + b * 18) >> 8
        
      Case 3  ; Valeur max - max(R, G, B)
        max3(lum, r, g, b)
        
      Case 4  ; Valeur min - min(R, G, B)
        min3(lum, r, g, b)
        
      Case 5  ; Valeur médiane - median(R, G, B)
        l1 = g
        If r > l1 : Swap r, l1 : EndIf
        If l1 > b : Swap l1, b : EndIf
        If r > l1 : Swap r, l1 : EndIf
        lum = l1
        
      Case 6  ; HSL Lightness - (max + min) / 2
        min3(l1, r, g, b)
        max3(l2, r, g, b)
        lum = (l1 + l2) >> 1
        
      Case 7  ; Canal rouge uniquement
        lum = r
        
      Case 8  ; Canal vert uniquement
        lum = g
        
      Case 9  ; Canal bleu uniquement
        lum = b
        
      Default ; Moyenne simple (R + G + B) / 3
        lum = (r + g + b) * 85 >> 8
    EndSelect
    
    ; Seuillage binaire
    If lum > seuil
      *dstPixel\l = (a << 24) | $FFFFFF  ; Blanc
    Else
      *dstPixel\l = a << 24              ; Noir
    EndIf
    
    *srcPixel + 4
    *dstPixel + 4
  Next      
EndProcedure

Procedure BlackAndWhite(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Black & White Threshold"
    param\remarque = "Conversion binaire noir/blanc avec seuil"
    param\info[0] = "Seuil"
    param\info[1] = "Méthode de luminance"
    param\info[2] = "Masque"
    param\info_data(0,0) = 1   : param\info_data(0,1) = 254 : param\info_data(0,2) = 127
    param\info_data(1,0) = 1   : param\info_data(1,1) = 9   : param\info_data(1,2) = 2
    param\info_data(2,0) = 0   : param\info_data(2,1) = 2   : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@BlackAndWhite_MT(), 1, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 8
; Folding = -
; EnableAsm
; EnableThread
; EnableXP