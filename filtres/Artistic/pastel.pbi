Procedure pastel_MT(*p.parametre)
  ; ============================================================================
  ; DÉCLARATION DES VARIABLES
  ; ============================================================================
  
  ; --- Dimensions de l'image ---
  Protected w = *p\lg  ; Largeur de l'image en pixels
  Protected h = *p\ht  ; Hauteur de l'image en pixels
  
  ; --- Coordonnées ---
  Protected x, y, i, j  ; Positions et indices de boucle
  
  ; --- Composantes ARGB ---
  Protected a, r, g, b              ; Alpha, Rouge, Vert, Bleu du pixel de sortie
  Protected rC, gC, bC              ; RGB du pixel central
  Protected rN, gN, bN              ; RGB des pixels voisins
  
  ; --- Moyennage et diffusion ---
  Protected sumR.f, sumG.f, sumB.f  ; Sommes pour effet poudré
  Protected count.f                  ; Nombre de pixels échantillonnés
  
  ; --- Texture et grain ---
  Protected noise.f                  ; Bruit pour grain du papier
  Protected paperNoise.f             ; Texture spécifique papier
  Protected chalkNoise.f             ; Variation du crayon pastel
  
  ; --- Saturation et luminosité ---
  Protected hue.f, sat.f, val.f     ; Composantes HSV
  Protected minRGB.f, maxRGB.f, delta.f
  
  ; --- Pointeurs mémoire ---
  Protected *src.Pixel32            ; Pointeur vers pixel source (lecture)
  Protected *dst.Pixel32            ; Pointeur vers pixel destination (écriture)
  
  ; ============================================================================
  ; LECTURE DES PARAMÈTRES
  ; ============================================================================
  
  ; --- Paramètre 0 : Douceur/Diffusion ---
  Protected softness.f = *p\option[0] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 1 : Grain du papier ---
  Protected paperGrain.f = *p\option[1] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 2 : Intensité de désaturation ---
  Protected desaturation.f = *p\option[2] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 3 : Éclaircissement ---
  Protected lighten.f = *p\option[3] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 4 : Taille du grain ---
  Protected grainSize = *p\option[4]
  If grainSize < 1 : grainSize = 1 : EndIf
  If grainSize > 8 : grainSize = 8 : EndIf
  
  ; --- Paramètre 5 : Type de papier ---
  Protected paperType = *p\option[5]  ; 0=Fin, 1=Moyen, 2=Rugueux, 3=Velours
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  
  Protected startY = (*p\thread_pos * h) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * h) / *p\thread_max
  
  ; --- Protection des bordures ---
  Protected border = grainSize + 2
  If startY < border : startY = border : EndIf
  If endY > h - border : endY = h - border : EndIf
  
  ; ============================================================================
  ; TRAITEMENT PRINCIPAL - BOUCLE SUR CHAQUE PIXEL
  ; ============================================================================
  
  For y = startY To endY - 1
    For x = border To w - border - 1
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 1 : LECTURE DU PIXEL CENTRAL
      ; ------------------------------------------------------------------------
      *src = *p\addr[0] + ((y * w + x) << 2)
      GetARGB(*src\l, a, rC, gC, bC)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 2 : EFFET POUDRÉ (Diffusion douce)
      ; ------------------------------------------------------------------------
      ; Simule l'aspect poudré du pastel en mélangeant avec les voisins
      
      sumR = 0.0 : sumG = 0.0 : sumB = 0.0 : count = 0.0
      
      Protected radius = 2 + Int(softness * 3.0)
      
      For i = -radius To radius
        For j = -radius To radius
          Protected dist.f = Sqr(i*i + j*j)
          
          If dist <= radius
            ; Poids gaussien pour effet doux
            Protected weight.f = 1.0 / (1.0 + dist * dist * 0.2)
            
            *src = *p\addr[0] + (((y + i) * w + (x + j)) << 2)
            GetARGB(*src\l, a, rN, gN, bN)
            
            sumR + rN * weight
            sumG + gN * weight
            sumB + bN * weight
            count + weight
          EndIf
        Next
      Next
      
      Protected avgR.f = sumR / count
      Protected avgG.f = sumG / count
      Protected avgB.f = sumB / count
      
      ; Mélange avec l'original (plus de diffusion = plus d'effet poudré)
      r = Int(rC * (1.0 - softness) + avgR * softness)
      g = Int(gC * (1.0 - softness) + avgG * softness)
      b = Int(bC * (1.0 - softness) + avgB * softness)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 3 : DÉSATURATION (Couleurs pastel douces)
      ; ------------------------------------------------------------------------
      ; Les pastels ont des couleurs plus douces, moins saturées
      
      If desaturation > 0.01
        ; Conversion RGB -> HSV
        minRGB = r
        If g < minRGB : minRGB = g : EndIf
        If b < minRGB : minRGB = b : EndIf
        
        maxRGB = r
        If g > maxRGB : maxRGB = g : EndIf
        If b > maxRGB : maxRGB = b : EndIf
        
        delta = maxRGB - minRGB
        
        ; Valeur (V)
        val = maxRGB / 255.0
        
        ; Saturation (S)
        If maxRGB > 0.0001
          sat = delta / maxRGB
        Else
          sat = 0.0
        EndIf
        
        ; Calcul de la teinte (H)
        If delta > 0.0001
          If maxRGB = r
            Protected h_temp.f = (g - b) / delta
            While h_temp >= 6.0 : h_temp - 6.0 : Wend
            While h_temp < 0.0 : h_temp + 6.0 : Wend
            hue = 60.0 * h_temp
          ElseIf maxRGB = g
            hue = 60.0 * (((b - r) / delta) + 2.0)
          Else
            hue = 60.0 * (((r - g) / delta) + 4.0)
          EndIf
          
          If hue < 0 : hue + 360.0 : EndIf
        Else
          hue = 0.0
        EndIf
        
        ; Réduit la saturation
        sat * (1.0 - desaturation * 0.7)
        If sat < 0.0 : sat = 0.0 : EndIf
        
        ; Conversion HSV -> RGB
        Protected c.f = val * sat
        Protected h_div_60.f = hue / 60.0
        Protected h_mod_2.f = h_div_60 - Int(h_div_60 / 2.0) * 2.0
        Protected x2.f = c * (1.0 - Abs(h_mod_2 - 1.0))
        Protected m.f = val - c
        
        Protected r1.f, g1.f, b1.f
        Protected h_sector = Int(hue / 60.0)
        If h_sector >= 6 : h_sector = 5 : EndIf
        If h_sector < 0 : h_sector = 0 : EndIf
        
        Select h_sector
          Case 0 : r1 = c : g1 = x2 : b1 = 0
          Case 1 : r1 = x2 : g1 = c : b1 = 0
          Case 2 : r1 = 0 : g1 = c : b1 = x2
          Case 3 : r1 = 0 : g1 = x2 : b1 = c
          Case 4 : r1 = x2 : g1 = 0 : b1 = c
          Case 5 : r1 = c : g1 = 0 : b1 = x2
        EndSelect
        
        r = Int((r1 + m) * 255.0)
        g = Int((g1 + m) * 255.0)
        b = Int((b1 + m) * 255.0)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 4 : ÉCLAIRCISSEMENT (Aspect crayeux)
      ; ------------------------------------------------------------------------
      ; Les pastels ont un aspect lumineux et crayeux
      
      If lighten > 0.01
        Protected lightenAmount.f = lighten * 0.5
        r = Int(r + (255 - r) * lightenAmount)
        g = Int(g + (255 - g) * lightenAmount)
        b = Int(b + (255 - b) * lightenAmount)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 5 : TEXTURE DU PAPIER
      ; ------------------------------------------------------------------------
      ; Simule la texture granuleuse du papier à pastel
      
      If paperGrain > 0.01
        ; Bruit de base pour le papier
        Protected seed1 = ((x / grainSize) * 12345 + (y / grainSize) * 67890) & $7FFFFFFF
        Protected noiseValue1 = (seed1 % 1000) - 500
        paperNoise = noiseValue1 / 500.0
        
        ; Bruit secondaire pour plus de naturel
        Protected seed2 = ((x / (grainSize * 2)) * 23456 + (y / (grainSize * 2)) * 78901) & $7FFFFFFF
        Protected noiseValue2 = (seed2 % 1000) - 500
        Protected paperNoise2.f = noiseValue2 / 500.0
        
        ; Combine les deux niveaux de bruit
        paperNoise = paperNoise * 0.6 + paperNoise2 * 0.4
        
        ; Ajuste selon le type de papier
        Select paperType
          Case 0  ; Papier fin - grain subtil
            paperNoise * 0.5
          Case 1  ; Papier moyen - grain normal
            paperNoise * 1.0
          Case 2  ; Papier rugueux - grain fort
            paperNoise * 1.5
          Case 3  ; Papier velours - grain très fin et dense
            Protected seed3 = (x * 34567 + y * 89012) & $7FFFFFFF
            Protected noiseValue3 = (seed3 % 1000) - 500
            Protected velvetNoise.f = noiseValue3 / 500.0
            paperNoise = paperNoise * 0.3 + velvetNoise * 0.7
            paperNoise * 0.7
        EndSelect
        
        Protected paperEffect.f = paperNoise * paperGrain * 35.0
        
        r + Int(paperEffect)
        g + Int(paperEffect)
        b + Int(paperEffect)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 6 : VARIATION DU TRAIT (Irrégularités du pastel)
      ; ------------------------------------------------------------------------
      ; Simule les variations d'application du crayon pastel
      
      Protected seed4 = (x * 45678 + y * 23456) & $7FFFFFFF
      Protected noiseValue4 = (seed4 % 1000) - 500
      chalkNoise = noiseValue4 / 500.0
      
      ; Variation subtile qui suit les structures de l'image
      Protected brightness.f = (r + g + b) / (3.0 * 255.0)
      Protected chalkVariation.f = chalkNoise * 0.15 * (1.0 - brightness * 0.5) * 20.0
      
      r + Int(chalkVariation)
      g + Int(chalkVariation * 0.9)
      b + Int(chalkVariation * 1.1)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 7 : EFFET DE SUPERPOSITION (Couches de pastel)
      ; ------------------------------------------------------------------------
      ; Simule les zones où plusieurs couches de pastel se superposent
      
      Protected layerSeed = ((x / 5) * 56789 + (y / 5) * 12345) & $7FFFFFFF
      Protected layerValue = (layerSeed % 1000) - 500
      Protected layerEffect.f = layerValue / 5000.0
      
      ; Les zones claires peuvent avoir un léger effet de superposition
      If brightness > 0.6
        Protected overlay.f = layerEffect * 8.0
        r + Int(overlay)
        g + Int(overlay)
        b + Int(overlay)
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 8 : DOUCEUR DES TRANSITIONS
      ; ------------------------------------------------------------------------
      ; Adoucit légèrement les transitions pour un aspect velouté
      
      Protected smoothR.f = 0.0, smoothG.f = 0.0, smoothB.f = 0.0
      Protected smoothCount.f = 0.0
      
      For i = -1 To 1
        For j = -1 To 1
          If i <> 0 Or j <> 0
            *src = *p\addr[0] + (((y + i) * w + (x + j)) << 2)
            GetARGB(*src\l, a, rN, gN, bN)
            
            smoothR + rN
            smoothG + gN
            smoothB + bN
            smoothCount + 1.0
          EndIf
        Next
      Next
      
      smoothR / smoothCount
      smoothG / smoothCount
      smoothB / smoothCount
      
      Protected smoothBlend.f = 0.15 * softness
      r = Int(r * (1.0 - smoothBlend) + smoothR * smoothBlend)
      g = Int(g * (1.0 - smoothBlend) + smoothG * smoothBlend)
      b = Int(b * (1.0 - smoothBlend) + smoothB * smoothBlend)
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 9 : CLAMPING (LIMITATION DES VALEURS)
      ; ------------------------------------------------------------------------
      
      If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 10 : ÉCRITURE DU PIXEL RÉSULTAT
      ; ------------------------------------------------------------------------
      
      *dst = *p\addr[1] + ((y * w + x) << 2)
      *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      
    Next  ; Pixel suivant (x)
  Next    ; Ligne suivante (y)
  
EndProcedure

; ==============================================================================
; PROCÉDURE D'INITIALISATION DU FILTRE
; ==============================================================================

Procedure pastel(*param.parametre)
  
  ; Si appelé en mode "info", on configure les paramètres de l'interface
  If *param\info_active
    
    ; --- Métadonnées du filtre ---
    *param\typ = #FilterType_Artistic         ; Catégorie : artistique
    *param\subtype = #Artistic_Material
    *param\name = "Pastel"                    ; Nom affiché
    *param\remarque = "Simule un dessin au pastel avec texture poudreuse et couleurs douces"
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 0 : DOUCEUR/DIFFUSION
    ; --------------------------------------------------------------------------
    *param\info[0] = "Douceur"
    *param\info_data(0, 0) = 0     ; Valeur minimale (net)
    *param\info_data(0, 1) = 100   ; Valeur maximale (très doux)
    *param\info_data(0, 2) = 50    ; Valeur par défaut (moyen)
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 1 : GRAIN DU PAPIER
    ; --------------------------------------------------------------------------
    *param\info[1] = "Grain papier"
    *param\info_data(1, 0) = 0     ; Min = lisse
    *param\info_data(1, 1) = 100   ; Max = très granuleux
    *param\info_data(1, 2) = 60    ; Défaut = granuleux
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 2 : DÉSATURATION
    ; --------------------------------------------------------------------------
    *param\info[2] = "Désaturation"
    *param\info_data(2, 0) = 0     ; Couleurs vives
    *param\info_data(2, 1) = 100   ; Très désaturé
    *param\info_data(2, 2) = 40    ; Défaut = légèrement désaturé
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 3 : ÉCLAIRCISSEMENT
    ; --------------------------------------------------------------------------
    *param\info[3] = "Éclaircissement"
    *param\info_data(3, 0) = 0     ; Aucun
    *param\info_data(3, 1) = 100   ; Maximum
    *param\info_data(3, 2) = 30    ; Défaut = léger
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 4 : TAILLE DU GRAIN
    ; --------------------------------------------------------------------------
    *param\info[4] = "Taille grain"
    *param\info_data(4, 0) = 1     ; Grain très fin
    *param\info_data(4, 1) = 8     ; Grain très gros
    *param\info_data(4, 2) = 3     ; Défaut = moyen
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 5 : TYPE DE PAPIER
    ; --------------------------------------------------------------------------
    *param\info[5] = "Papier (0=Fin/1=Moyen/2=Rugueux/3=Velours)"
    *param\info_data(5, 0) = 0     ; 0 = Papier fin
    *param\info_data(5, 1) = 3     ; 3 = Papier velours
    *param\info_data(5, 2) = 1     ; Défaut = Papier moyen
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 6 : MASQUE (standard)
    ; --------------------------------------------------------------------------
    *param\info[6] = "masque"
    *param\info_data(6, 0) = 0 
    *param\info_data(6, 1) = 2
    *param\info_data(6, 2) = 0
    
    ProcedureReturn  ; Sort sans lancer le traitement
  EndIf
  
  ; Si pas en mode "info", on lance le traitement multithreadé
  ; Paramètres : fonction worker, nombre de passes, nombre de buffers
  filter_start(@pastel_MT(), 3, 1)
  
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 344
; FirstLine = 342
; Folding = -
; EnableXP
; DPIAware