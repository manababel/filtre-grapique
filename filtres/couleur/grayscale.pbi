Procedure Grayscale_MT(*param.parametre) 
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected typ = *param\option[0]
  Protected i, var
  Protected a , r, g, b, gray , t1 , t2
  Protected t = lg * ht
  Protected start = (*param\thread_pos * t) / *param\thread_max
  Protected stop = ((*param\thread_pos + 1) * t) / *param\thread_max - 1
  For i = start To stop - 1
    var = PeekL(*source + i << 2)
    getargb( var , a , r , g , b)
    Select typ    
      Case 1 ; Luma BT.601
        gray = (r * 1225 + g * 2405 + b * 466) >> 12
      Case 2 ; Luma BT.709
        gray = (r * 870 + g * 2930 + b * 296) >> 12 
      Case 3 ; Pondération personnalisée (rapide)
        gray = (r * 1293 + g * 2156 + b * 647) >> 12  
      Case 4 ; Maximum (canal dominant)
        gray = r : If g > gray : gray = g : EndIf
        If b > gray : gray = b : EndIf  
      Case 5 ; Minimum (canal le plus faible)
        gray = r : If g < gray : gray = g : EndIf
        If b < gray : gray = b : EndIf     
      Case 6 ; Médiane (ni min ni max)
             ; On trie r, g, b pour obtenir la valeur intermédiaire
        If r > g : Swap r, g : EndIf
        If g > b : Swap g, b : EndIf
        If r > g : Swap r, g : EndIf
        gray = g    
      Case 7 ; Rouge seul
        gray = r       
      Case 8 ; Vert seul
        gray = g    
      Case 9 ; Bleu seul
        gray = b      
      Case 10 ; Luminosité perceptuelle
        gray = Sqr(r * r * 0.299 + g * g * 0.587 + b * b * 0.114)  
        ;gray = Int(Pow(r * r * 0.299 + g * g * 0.587 + b * b * 0.114, 0.5))
      Case 11 ; Moyenne pondérée gamma-corrected (plus proche de la perception)
        gray = Sqr(r * r * 0.2126 + g * g *0.7152 + b * b * 0.0722)   
      Case 12 ; Moyenne (min + max) / 2
        max3( t1 , r , g , b)
        min3( t2 , r , g , b)
        gray = (t1 + t2) >> 1 
      Case 13 ; Valeur (V de HSV) = Max(r, g, b)
        Max3( gray , r, g, b) 
      Case 14 ; Luma BT.2100 (HDR/WCG)
        gray = (r * 1078 + g * 2775 + b * 243) >> 12
      Default ;Moyenne géométrique
        gray = (r * 1365 + g * 1365 + b * 1366) >> 12
    EndSelect
    Clamp(gray, 0, 255)
    PokeL(*cible + i << 2, a << 24 | gray * $10101)
  Next
EndProcedure

Procedure Grayscale(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Grayscale"
    param\remarque = ""
    param\info[0] = "type" ; Rayon vertical
    param\info[1] = "Masque binaire" ; Optionnel : appliquer un masque
    param\info_data(0,0) = 0 : param\info_data(0,1) = 14 : param\info_data(0,2) = 0
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@Grayscale_MT(), 1, 1)
EndProcedure


; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 2
; Folding = -
; EnableXP
; DPIAware