
; --- Phase 1 : Génération de la SAT ---
Procedure SummedArea_Create_SAT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]
    Protected.l x, y, pixel
    Protected *src.PixelArray32 = \image[0]
    Protected.a a, r, g, b ; .a pour 0-255
    
    ; On mappe nos zones mémoires sur des tableaux de Quads (64 bits)
    Protected *satA.array32 = \addr[2]
    Protected *satR.array32 = \addr[3]
    Protected *satG.array32 = \addr[4]
    Protected *satB.array32 = \addr[5]
    
    Protected.l sA, sR, sG, sB
    Protected.l idx, idxPrev
    
; --- Étape 1 : Balayage Horizontal (Somme des lignes) ---
    For y = 0 To ht - 1
      idx = y * lg
      ; Premier pixel de la ligne
      getargb(*src\pixel[idx], a, r, g, b)
      *satA\l[idx] = a : *satR\l[idx] = r : *satG\l[idx] = g : *satB\l[idx] = b
      
      ; Reste de la ligne
      For x = 1 To lg - 1
        idx = y * lg + x
        idxPrev = idx - 1
        getargb(*src\pixel[idx], a, r, g, b)
        
        *satA\l[idx] = a + *satA\l[idxPrev]
        *satR\l[idx] = r + *satR\l[idxPrev]
        *satG\l[idx] = g + *satG\l[idxPrev]
        *satB\l[idx] = b + *satB\l[idxPrev]
      Next
    Next

    ; --- Étape 2 : Balayage Vertical (Somme des colonnes sur le résultat du H) ---
    ; On commence à y=1 car la première ligne est déjà correcte
    For y = 1 To ht - 1
      For x = 0 To lg - 1
        idx = y * lg + x
        idxPrev = (y - 1) * lg + x ; Pixel juste au dessus
        
        *satA\l[idx] + *satA\l[idxPrev]
        *satR\l[idx] + *satR\l[idxPrev]
        *satG\l[idx] + *satG\l[idxPrev]
        *satB\l[idx] + *satB\l[idxPrev]
      Next
    Next
  EndWith
EndProcedure

; Macro locale pour extraire la somme ARGB
Macro GetRectSum(pSAT, targetVar)
  targetVar = pSAT\l[y2 * lg + x2]
  If x1 >= 0 : targetVar - pSAT\l[y2 * lg + x1] : EndIf
  If y1 >= 0 : targetVar - pSAT\l[y1 * lg + x2] : EndIf
  If x1 >= 0 And y1 >= 0 : targetVar + pSAT\l[y1 * lg + x1] : EndIf
EndMacro

; --- Phase 2 : Calcul du flou ---
Procedure SummedArea_SAT_Apply(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]
    Protected.l rx = \option[0]
    Protected.l ry = \option[0] ; On utilise le même rayon si besoin
    Protected *dst.PixelArray32 = \image[1]
    
    Protected *satA.array32 = \addr[2]
    Protected *satR.array32 = \addr[3]
    Protected *satG.array32 = \addr[4]
    Protected *satB.array32 = \addr[5]
    
    Protected.l x, y, x1, y1, x2, y2
    Protected.l count, resA, resR, resG, resB, val
    Protected.l tempX1
    Protected.l tempY1
    
    For y = 0 To ht - 1
      For x = 0 To lg - 1
        x1 = x - rx - 1 : x2 = x + rx
        y1 = y - ry - 1 : y2 = y + ry
        
        If x2 > lg - 1 : x2 = lg - 1 : EndIf
        If y2 > ht - 1 : y2 = ht - 1 : EndIf
        
        tempX1 = x1
        tempY1 = y1
        
        If tempX1 < -1 : tempX1 = -1 : EndIf
        If tempY1 < -1 : tempY1 = -1 : EndIf
        
        count = (x2 - tempX1) * (y2 - tempY1)

        ; On récupère les sommes
        GetRectSum(*satA, resA)
        GetRectSum(*satR, resR)
        GetRectSum(*satG, resG)
        GetRectSum(*satB, resB)
        
        ; On divise tout d'un coup (ou on multiplie par l'inverse pour être un pro de l'optimisation)
        ; Note : resA / count est suffisant, mais (resA / count) & $FF sécurise le résultat
        *dst\pixel[y * lg + x] = ((resA / count) << 24) | ((resR / count) << 16) | ((resG / count) << 8) | (resB / count)
      Next
    Next
  EndWith
EndProcedure



Procedure SummedAreaEx(*FilterCtx.FilterParams)
  
  Restore SummedArea_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected i
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]   
    For i = 2 To 5 : \addr[i] = AllocateMemory(lg * ht * 4) : Next
    
    If \addr[2] And \addr[3]  And \addr[4]  And \addr[5] 
      SummedArea_Create_SAT(*FilterCtx.FilterParams)  
      SummedArea_SAT_Apply(*FilterCtx.FilterParams)
      mask_update(*FilterCtx.FilterParams , last_data)
    EndIf
    
    ; Libération mémoire
    For i = 2 To 5 : If \addr[i] : FreeMemory(\addr[i]) : EndIf : Next
  EndWith
EndProcedure


Procedure SummedArea(source , cible , mask , rayon)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
  EndWith
  SummedAreaEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  SummedArea_data:
  Data.s "SummedArea"
  Data.s "Flou Box area"
  Data.i #FilterType_Blur
  Data.i #Blur_Classic
  
  Data.s "Rayon"           ; Rayon horizontal
  Data.i 1,100,1
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 128
; FirstLine = 98
; Folding = -
; EnableXP
; DPIAware