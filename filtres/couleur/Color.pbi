;--- Fonction de conversion en niveau de gris avec alpha
Macro Color_Gray()
  gray = (r * 54 + g * 183 + b * 18) >> 8
  var = (a << 24) | (gray * $010101)
EndMacro

;--- Filtre de désaturation sélective selon canal dominant
Procedure Color_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected maxVal, minVal, saturation
  Protected deltaRG, deltaRB, deltaGB
  Protected gray 
  
  Protected seuil = *param\option[0]
  Protected mode = *param\option[1]
  
  Protected i, a, r, g, b, var
  Protected totalPixels = lg * ht
  Protected startPos = (*param\thread_pos * totalPixels) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * totalPixels) / *param\thread_max
  
  Protected *srcPixel.Pixel32 = *source + (startPos << 2)
  Protected *dstPixel.Pixel32 = *cible + (startPos << 2)
  
  For i = startPos To endPos - 1
    var = *srcPixel\l
    getargb(var, a, r, g, b)
    
    Select mode
      ; OR conditions - canal dominant >
      Case 0  : If (g > r Or b > r Or r > seuil) : Color_Gray() : EndIf         ; Red dominant
      Case 1  : If (r > g Or b > g Or g > seuil) : Color_Gray() : EndIf         ; Green dominant
      Case 2  : If (g > b Or r > b Or b > seuil) : Color_Gray() : EndIf         ; Blue dominant
      
      ; OR conditions - canal dominant 
      Case 3  : If (r < g Or r < b Or r > seuil) : Color_Gray() : EndIf         ; Red recessive
      Case 4  : If (g < r Or g < b Or g > seuil) : Color_Gray() : EndIf         ; Green recessive
      Case 5  : If (b < r Or b < g Or b > seuil) : Color_Gray() : EndIf         ; Blue recessive
      
      ; AND conditions - canal strictement dominant >
      Case 6  : If ((g > r And b > r) Or r > seuil) : Color_Gray() : EndIf      ; Red weakest
      Case 7  : If ((r > g And b > g) Or g > seuil) : Color_Gray() : EndIf      ; Green weakest
      Case 8  : If ((g > b And r > b) Or b > seuil) : Color_Gray() : EndIf      ; Blue weakest
      
      ; AND conditions - canal strictement dominant 
      Case 9  : If ((r < g And r < b) Or r > seuil) : Color_Gray() : EndIf      ; Red strongest
      Case 10 : If ((g < r And g < b) Or g > seuil) : Color_Gray() : EndIf      ; Green strongest
      Case 11 : If ((b < g And b < r) Or b > seuil) : Color_Gray() : EndIf      ; Blue strongest
      
      ; XOR conditions - un seul canal supérieur >
      Case 12 : If ((g > r) XOr (b > r) Or r > seuil) : Color_Gray() : EndIf    ; Red XOR >
      Case 13 : If ((r > g) XOr (b > g) Or g > seuil) : Color_Gray() : EndIf    ; Green XOR >
      Case 14 : If ((g > b) XOr (r > b) Or b > seuil) : Color_Gray() : EndIf    ; Blue XOR >
      
      ; XOR conditions - un seul canal inférieur 
      Case 15 : If ((r < g) XOr (r < b) Or r > seuil) : Color_Gray() : EndIf    ; Red XOR 
      Case 16 : If ((g < r) XOr (g < b) Or g > seuil) : Color_Gray() : EndIf    ; Green XOR 
      Case 17 : If ((b < g) XOr (b < r) Or b > seuil) : Color_Gray() : EndIf    ; Blue XOR 
      
      ; Saturation faible
      Case 18
        max3(maxVal, r, g, b)
        min3(minVal, r, g, b)
        saturation = maxVal - minVal
        If saturation < seuil : Color_Gray() : EndIf
      
      ; Différences de canaux élevées
      Case 19
        deltaRG = Abs(r - g)
        deltaRB = Abs(r - b)
        deltaGB = Abs(g - b)
        If deltaRG > seuil Or deltaRB > seuil Or deltaGB > seuil : Color_Gray() : EndIf
    EndSelect
    
    *dstPixel\l = var
    *srcPixel + 4
    *dstPixel + 4
  Next
EndProcedure

Procedure Color(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Color"
    param\remarque = "Désature selon critères de canaux"
    param\info[0] = "Seuil"
    param\info[1] = "Mode"
    param\info[2] = "Masque"
    param\info_data(0,0) = 0   : param\info_data(0,1) = 255 : param\info_data(0,2) = 127
    param\info_data(1,0) = 0   : param\info_data(1,1) = 19  : param\info_data(1,2) = 0
    param\info_data(2,0) = 0   : param\info_data(2,1) = 2   : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  
  filter_start(@Color_MT(), 1, 1)
EndProcedure

; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 2
; Folding = -
; EnableAsm
; EnableThread
; EnableXP