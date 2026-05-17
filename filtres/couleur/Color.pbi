;--- Fonction de conversion en niveau de gris avec alpha (Non modifiée)
Macro Color_Gray()
  gray = (r * 54 + g * 183 + b * 18) >> 8
  var = (a << 24) | (gray * $010101)
EndMacro

; ----------------------------------------------------------------------------------
; Procédure thread pour le filtre de désaturation sélective
; ----------------------------------------------------------------------------------

Procedure Color_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *source = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[1]
    Protected maxVal, minVal, saturation
    Protected deltaRG, deltaRB, deltaGB
    Protected gray 
    
    Protected seuil = \option[0]
    Protected mode = \option[1]
    
    Protected i, a, r, g, b, var
    Protected totalPixels = lg * ht
    
    ; Utilisation de la macro avec parenthèses pour l'argument composé
    macro_calul_tread((lg * ht))
    
    Protected *srcPixel.Pixel32 = *source + (thread_start << 2)
    Protected *dstPixel.Pixel32 = *cible + (thread_start << 2)
    
    For i = thread_start To thread_stop - 1
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
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Procédure d'appel et définition des métadonnées
; ----------------------------------------------------------------------------------

Procedure ColorEx(*FilterCtx.FilterParams)
  Restore Color_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lance le traitement multithread
    Create_MultiThread_MT(@Color_MT())
    
    ; Applique le masque si présent
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

; ----------------------------------------------------------------------------------
; Interface simplifiée
; ----------------------------------------------------------------------------------

Procedure Color(source, cible, mask, seuil, mode)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = seuil
    \option[1] = mode
  EndWith
  ColorEx(FilterCtx)
EndProcedure

; ----------------------------------------------------------------------------------
; Données du filtre
; ----------------------------------------------------------------------------------

DataSection
  Color_Data:
  Data.s "Color"                                        ; Nom du filtre
  Data.s "Désature selon critères de canaux"            ; Description
  Data.i #FilterType_ColorEffect
  Data.i 0                                              ; Sous-type
  
  Data.s "Seuil (0-255)"                                ; Label option 0
  Data.i 0, 255, 127                                    ; Min, Max, Défaut
  
  Data.s "Mode (0-19)"                                  ; Label option 1
  Data.i 0, 19, 0                                       ; Min, Max, Défaut
  
  Data.s "XXX"                                          ; Fin des options
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 111
; FirstLine = 89
; Folding = -
; EnableAsm
; EnableThread
; EnableXP