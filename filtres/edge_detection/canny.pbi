Procedure canny_grayscale_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0]
    Protected *dst  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected i , var , r , g , b
    
    Protected totalPixels = lg * ht
    Protected start = (\thread_pos * totalPixels) / \thread_max
    Protected stop = ((\thread_pos + 1) * totalPixels) / \thread_max
    
    ;Conversion de l’image couleur en niveaux de gris (dans *dst)
    For i = start To stop -1
      var = PeekL(*src + i * 4)   ; Lecture pixel source (32 bits)
      GetRGB(var, r, g, b) 
      PokeA(*dst + i , ((r * 77 + g * 150 + b * 29) >> 8) ) ; Stockage gris dans *dst (32 bits)
    Next
  EndWith
EndProcedure

Procedure FiltrageGaussien_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0]
    Protected *dst  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y, i, j, r, g, b, v, gray , idx , var
    ; Coefficients du noyau gaussien 3x3 (poids)
    Dim weights(8)
    weights(0) = 1 : weights(1) = 2 : weights(2) = 1
    weights(3) = 2 : weights(4) = 4 : weights(5) = 2
    weights(6) = 1 : weights(7) = 2 : weights(8) = 1
    
    Protected start = (\thread_pos * ht ) / \thread_max
    Protected stop = ((\thread_pos + 1) * ht ) / \thread_max
    If start < 1 : start = 1 : EndIf
    If stop > (ht - 2) : stop = (ht - 2) : EndIf
    ; Application du filtre gaussien sur l’image en niveaux de gris
    For y = start To stop
      For x = 1 To lg - 2
        v = 0 : idx = 0
        ; Convolution avec le noyau 3x3
        For j = -1 To 1
          For i = -1 To 1
            var = PeekA(*src + ((y+j)*lg + (x+i)) ) ; récupération valeur grise
            v + var * weights(idx)                  ; Somme pondérée
            idx + 1
          Next
        Next
        v = v >> 4 ; Normalisation (division par 16, somme des poids)
                   ; Limitation de la valeur entre 0 et 255
        If v > 255 : v = 255 : ElseIf v < 0 : v = 0 : EndIf
        ; Écriture de la valeur floutée dans *dst (en niveaux de gris)
        PokeA(*dst + (y*lg + x), v )
      Next
    Next
  EndWith
EndProcedure

Procedure GradientSobel_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0]
    Protected *mag  = \addr[1]
    Protected *dir  = \addr[2]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    
    Protected x, y, gx, gy, magnitude, angle
    Protected line0, line1, line2
    Protected idx0, idx1, idx2
    ; Buffers temporaires pour 3 lignes consécutives (1 octet par pixel)
    Dim line0(lg - 1)
    Dim line1(lg - 1)
    Dim line2(lg - 1)
    ; Parcours de l’image (sans bord)
    Protected start = (\thread_pos * ht ) / \thread_max
    Protected stop = ((\thread_pos + 1) * ht ) / \thread_max
    If start < 1 : start = 1 : EndIf
    If stop > (ht - 2) : stop = (ht - 2) : EndIf
    For y = start To stop
      ; Chargement des 3 lignes dans les buffers (pour accès rapide)
      For x = 0 To lg - 1
        line0(x) = PeekA(*src + ((y - 1) * lg + x) )
        line1(x) = PeekA(*src + (y * lg + x) )
        line2(x) = PeekA(*src + ((y + 1) * lg + x) )
      Next
      ; Calcul du gradient pour chaque pixel (sans bord)
      For x = 1 To lg - 2
        ; Application des masques Sobel pour Gx et Gy
        gx = -line0(x-1) + line0(x+1) - 2 * line1(x-1) + 2 * line1(x+1) - line2(x-1) + line2(x+1)
        gy = -line0(x-1) - 2 * line0(x) - line0(x+1) + line2(x-1) + 2 * line2(x) + line2(x+1)
        ; Calcul de la magnitude (approximation norme L1)
        magnitude = Abs(gx) + Abs(gy)
        If magnitude > 255 : magnitude = 255 : EndIf
        ; Calcul de l’orientation (angle en degrés entre 0 et 180)
        ;angle = Degree(ATan2(gy, gx))
        ;If angle < 0 : angle + 180  : EndIf
        If Abs(gx) > Abs(gy)
          If gx * gy >= 0
            angle = 0    ; ≈ 0°
          Else
            angle = 3    ; ≈ 135°
          EndIf
        Else
          If gx * gy >= 0
            angle = 1    ; ≈ 45°
          Else
            angle = 2    ; ≈ 90°
          EndIf
        EndIf
        PokeA(*dir + y * lg + x, angle)
        ; Stockage des résultats (magnitude et direction)
        PokeA(*mag + y * lg + x, magnitude)
        PokeA(*dir + y * lg + x, angle)
      Next
    Next
  EndWith
EndProcedure

Procedure sobel_direction_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *mag = \addr[0]
    Protected *cible  = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x , y , var , pos
    Protected totalPixels = lg * ht
    Protected start = (\thread_pos * totalPixels) / \thread_max
    Protected stop = ((\thread_pos + 1) * totalPixels) / \thread_max
    
    ; Affichage direct de la magnitude
    For pos = start To stop - 1
      var = PeekA(*mag + pos)
      PokeL(*cible + pos << 2, var * $10101)
    Next
  EndWith
EndProcedure

Procedure SuppressionNonMaximale_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *mag = \addr[0]
    Protected *dir  = \addr[1]
    Protected *dst  = \addr[2]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    
    Protected x, y, angle, m, m1, m2
    Protected fx, fy
    
    Protected start = (\thread_pos * ht ) / \thread_max
    Protected stop = ((\thread_pos + 1) * ht ) / \thread_max
    If start < 1 : start = 1 : EndIf
    If stop > (ht - 2) : stop = (ht - 2) : EndIf
    
    ; Parcours image sans bord
    For y = start To stop
      For x = 1 To lg - 2
        m = PeekA(*mag + y*lg + x)       ; magnitude au pixel courant
        angle = PeekA(*dir + y*lg + x)   ; angle du gradient
        
        ; Détermination de la direction
        Select angle
          Case 0  ; ≈ 0° (horizontal)
            fx = 1 : fy = 0
          Case 1  ; ≈ 45°
            fx = 1 : fy = -1
          Case 2  ; ≈ 90° (vertical)
            fx = 0 : fy = -1
          Case 3  ; ≈ 135°
            fx = -1 : fy = -1
          Default
            fx = 0 : fy = 0 ; sécurité
        EndSelect
        ; Récupération des magnitudes des pixels voisins dans la direction du gradient
        m1 = PeekA(*mag + (y+fy)*lg + (x+fx))
        m2 = PeekA(*mag + (y-fy)*lg + (x-fx))
        
        ; Conservation uniquement si magnitude locale maximale
        If m >= m1 And m >= m2
          PokeA(*dst + y*lg + x, m) ; on conserve
        Else
          PokeA(*dst + y*lg + x, 0) ; suppression
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure SeuillageDouble_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0]
    Protected *dst = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected seuilFort = \option[5]
    Protected seuilFaible = \option[6]
    Protected totalPixels = lg * ht
    Protected start = (\thread_pos * totalPixels) / \thread_max
    Protected stop = ((\thread_pos + 1) * totalPixels) / \thread_max
    Protected x, y, var , i
    ; Classification des pixels en fort, faible ou rejeté selon seuils
    For i = start To stop -1
      var = PeekA(*src + i)
      If var >= seuilFort
        PokeA(*dst + i, 255) ; pixel fort
      ElseIf var < seuilFaible
        PokeA(*dst + i, 0)   ; pixel rejeté
      Else
        PokeA(*dst + i, 128) ; pixel faible
      EndIf
    Next
  EndWith
EndProcedure

Procedure Sobel_No_Hysteresis(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *thresh = \addr[0]
    Protected *cible = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y, var , i
    Protected start = (\thread_pos * ht ) / \thread_max
    Protected stop = ((\thread_pos + 1) * ht ) / \thread_max
    
    ; Option : copie directe du seuillage dans l’image couleur finale
    For y = start To stop - 1
      For x = 0 To lg - 1
        var = PeekA(*thresh + y*lg + x)
        If var = 255
          PokeL(*cible + (y*lg + x) * 4, $FFFFFF)  ; blanc = bord fort
        ElseIf var = 128
          PokeL(*cible + (y*lg + x) * 4, $808080)  ; gris = bord faible
        Else
          PokeL(*cible + (y*lg + x) * 4, 0)         ; noir = non bord
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure Hysteresis_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0]
    Protected *dst = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected x, y, dx, dy, found, var
    Protected start = (\thread_pos * ht ) / \thread_max
    Protected stop = ((\thread_pos + 1) * ht ) / \thread_max
    If start < 1 : start = 1 : EndIf
    If stop > (ht - 2) : stop = (ht - 2) : EndIf
    ; Parcours des pixels sans bord
    For y = start To stop
      For x = 1 To lg - 2
        var = PeekA(*src + y*lg + x)
        If var = 128 ; pixel faible
          found = 0
          ; Vérification des voisins 3x3 pour un pixel fort connecté
          For dy = -1 To 1
            For dx = -1 To 1
              If PeekA(*src + (y+dy)*lg + (x+dx)) = 255
                found = 1 : Break 2
              EndIf
            Next
          Next
          ; Si pixel faible connecté à un fort, on conserve, sinon suppression
          If found
            PokeL(*dst + (y*lg + x)*4, $FFFFFF) ; blanc (bord)
          Else
            PokeL(*dst + (y*lg + x)*4, 0)        ; noir (non-bord)
          EndIf
        ElseIf var = 255
          PokeL(*dst + (y*lg + x)*4, $FFFFFF) ; pixel fort : blanc
        Else
          PokeL(*dst + (y*lg + x)*4, 0)        ; pixel rejeté : noir
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure cannyEx(*FilterCtx.FilterParams)
  
  Restore canny_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Protected *source = \image[0] ; \source -> \image[0]
    Protected *cible  = \image[1] ; \cible  -> \image[1]
                                  ; \mask est devenu \image[2] (utilisé dans mask_update)
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected *gray, *blurred, *mag, *dir, *nms, *thresh, *final
    Protected val, x, y, i
    
    If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf
    
    Protected thread = CountCPUs(#PB_System_CPUs)
    clamp(thread, 1, 128)
    Protected Dim tr(thread)
    
    ; Allocation mémoire pour buffers intermédiaires
    *gray      = AllocateMemory(lg * ht)   
    *blurred   = AllocateMemory(lg * ht)   
    *mag       = AllocateMemory(lg * ht)       
    *dir       = AllocateMemory(lg * ht)       
    *nms       = AllocateMemory(lg * ht)       
    *thresh    = AllocateMemory(lg * ht)       
    *final     = AllocateMemory(lg * ht * 4)   
    
    Protected seuilFort = \option[0]
    Protected seuilFaible = \option[1]
    Protected seuillage = \option[2]
    Protected hysteresis = \option[3]
    
    clamp(seuilFort, 1, 255)
    clamp(seuilFaible, 1, 255)
    
    ; Traitement
    \addr[0] = *source
    \addr[1] = *gray
    Create_MultiThread_MT(@canny_grayscale_MT())
    
    \addr[0] = *gray
    \addr[1] = *blurred
    Create_MultiThread_MT(@FiltrageGaussien_MT())
    
    \addr[0] = *blurred
    \addr[1] = *mag
    \addr[2] = *dir
    Create_MultiThread_MT(@GradientSobel_MT())  
    
    If seuillage = 1
      \addr[0] = *mag
      \addr[1] = *cible
      Create_MultiThread_MT(@sobel_direction_MT())
    Else
      \addr[0] = *mag
      \addr[1] = *dir
      \addr[2] = *nms
      Create_MultiThread_MT(@SuppressionNonMaximale_MT())  
      
      \addr[0] = *nms
      \addr[1] = *thresh
      \option[5] = seuilFort
      \option[6] = seuilFaible
      Create_MultiThread_MT(@SeuillageDouble_MT())  
      
      If hysteresis = 0
        \addr[0] = *thresh
        \addr[1] = *cible
        Create_MultiThread_MT(@Sobel_No_Hysteresis()) 
      Else
        \addr[0] = *thresh
        \addr[1] = *cible
        Create_MultiThread_MT(@Hysteresis_MT()) 
      EndIf
    EndIf
    
    ; Gestion du masque et finalisation
    mask_update(*FilterCtx.FilterParams , last_data)
    
    FreeMemory(*gray)
    FreeMemory(*blurred)
    FreeMemory(*mag)
    FreeMemory(*dir)
    FreeMemory(*nms)
    FreeMemory(*thresh)
    FreeMemory(*final)
    FreeArray(tr())
  EndWith
EndProcedure

Procedure canny(source, cible, mask, seuilF, seuilfai, brute, hyst)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = seuilF
    \option[1] = seuilfai
    \option[2] = brute
    \option[3] = hyst
  EndWith
  cannyEx(FilterCtx)
EndProcedure

DataSection
  canny_data:
  Data.s "canny"
  Data.s "Détection de contours par algorithme de Canny" ; Remarque
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_Advanced
  
  Data.s "seuil_Fort" 
  Data.i 0, 255, 100
  Data.s "seuil_Faible"
  Data.i 0, 255, 50
  Data.s "Sortie brute"
  Data.i 0, 1, 0
  Data.s "hystérésis"
  Data.i 0, 1, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 383
; FirstLine = 354
; Folding = --
; EnableXP
; DPIAware