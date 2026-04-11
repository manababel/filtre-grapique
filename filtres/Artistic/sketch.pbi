Procedure sketch_MT(*p.parametre)
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
  
  ; --- Détection de contours ---
  Protected grayC.f                  ; Niveau de gris central
  Protected grayN.f                  ; Niveau de gris voisin
  Protected edgeH.f, edgeV.f        ; Contours horizontal et vertical
  Protected edgeD1.f, edgeD2.f      ; Contours diagonaux
  Protected edge.f                   ; Force totale du contour
  
  ; --- Hachures ---
  Protected hatchValue.f             ; Valeur des hachures
  Protected hatchPattern.f           ; Motif de hachures
  
  ; --- Texture ---
  Protected pencilNoise.f            ; Bruit du trait de crayon
  Protected paperNoise.f             ; Texture du papier
  
  ; --- Tons ---
  Protected tone.f                   ; Ton général (clair/foncé)
  Protected shading.f                ; Ombrage
  
  ; --- Pointeurs mémoire ---
  Protected *src.Pixel32            ; Pointeur vers pixel source (lecture)
  Protected *dst.Pixel32            ; Pointeur vers pixel destination (écriture)
  
  ; ============================================================================
  ; LECTURE DES PARAMÈTRES
  ; ============================================================================
  
  ; --- Paramètre 0 : Intensité des contours ---
  Protected edgeStrength.f = *p\option[0] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 1 : Densité des hachures ---
  Protected hatchDensity.f = *p\option[1] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 2 : Style de hachures ---
  Protected hatchStyle = *p\option[2]  ; 0=Aucune, 1=Simple, 2=Croisée, 3=Circulaire
  
  ; --- Paramètre 3 : Texture du crayon ---
  Protected pencilTexture.f = *p\option[3] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 4 : Grain du papier ---
  Protected paperGrain.f = *p\option[4] * 0.01  ; 0-100 -> 0-1.0
  
  ; --- Paramètre 5 : Contraste ---
  Protected contrast.f = *p\option[5] * 0.01  ; 50-200 -> 0.5-2.0
  
  ; ============================================================================
  ; CONFIGURATION MULTITHREADING
  ; ============================================================================
  
  Protected startY = (*p\thread_pos * h) / *p\thread_max
  Protected endY   = ((*p\thread_pos + 1) * h) / *p\thread_max
  
  ; --- Protection des bordures ---
  If startY < 2 : startY = 2 : EndIf
  If endY > h - 2 : endY = h - 2 : EndIf
  
  ; ============================================================================
  ; TRAITEMENT PRINCIPAL - BOUCLE SUR CHAQUE PIXEL
  ; ============================================================================
  
  For y = startY To endY - 1
    For x = 2 To w - 3
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 1 : LECTURE DU PIXEL CENTRAL ET CONVERSION EN NIVEAU DE GRIS
      ; ------------------------------------------------------------------------
      *src = *p\addr[0] + ((y * w + x) << 2)
      GetARGB(*src\l, a, rC, gC, bC)
      
      ; Conversion en niveau de gris (luminance)
      grayC = rC * 0.299 + gC * 0.587 + bC * 0.114
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 2 : DÉTECTION DE CONTOURS MULTI-DIRECTIONNELLE
      ; ------------------------------------------------------------------------
      ; Utilise un opérateur de Sobel étendu pour détecter les contours
      
      ; Contour HORIZONTAL
      *src = *p\addr[0] + ((y * w + (x - 1)) << 2)
      GetARGB(*src\l, a, rN, gN, bN)
      Protected grayL.f = rN * 0.299 + gN * 0.587 + bN * 0.114
      
      *src = *p\addr[0] + ((y * w + (x + 1)) << 2)
      GetARGB(*src\l, a, rN, gN, bN)
      Protected grayR.f = rN * 0.299 + gN * 0.587 + bN * 0.114
      
      edgeH = Abs(grayR - grayL)
      
      ; Contour VERTICAL
      *src = *p\addr[0] + (((y - 1) * w + x) << 2)
      GetARGB(*src\l, a, rN, gN, bN)
      Protected grayU.f = rN * 0.299 + gN * 0.587 + bN * 0.114
      
      *src = *p\addr[0] + (((y + 1) * w + x) << 2)
      GetARGB(*src\l, a, rN, gN, bN)
      Protected grayD.f = rN * 0.299 + gN * 0.587 + bN * 0.114
      
      edgeV = Abs(grayD - grayU)
      
      ; Contours DIAGONAUX
      *src = *p\addr[0] + (((y - 1) * w + (x - 1)) << 2)
      GetARGB(*src\l, a, rN, gN, bN)
      Protected grayUL.f = rN * 0.299 + gN * 0.587 + bN * 0.114
      
      *src = *p\addr[0] + (((y + 1) * w + (x + 1)) << 2)
      GetARGB(*src\l, a, rN, gN, bN)
      Protected grayDR.f = rN * 0.299 + gN * 0.587 + bN * 0.114
      
      edgeD1 = Abs(grayDR - grayUL)
      
      *src = *p\addr[0] + (((y - 1) * w + (x + 1)) << 2)
      GetARGB(*src\l, a, rN, gN, bN)
      Protected grayUR.f = rN * 0.299 + gN * 0.587 + bN * 0.114
      
      *src = *p\addr[0] + (((y + 1) * w + (x - 1)) << 2)
      GetARGB(*src\l, a, rN, gN, bN)
      Protected grayDL.f = rN * 0.299 + gN * 0.587 + bN * 0.114
      
      edgeD2 = Abs(grayDL - grayUR)
      
      ; Combine tous les contours
      edge = Sqr(edgeH * edgeH + edgeV * edgeV + edgeD1 * edgeD1 * 0.5 + edgeD2 * edgeD2 * 0.5)
      edge = edge / 255.0 * edgeStrength
      
      ; Limite les valeurs
      If edge > 1.0 : edge = 1.0 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 3 : CALCUL DU TON DE BASE (Inversé pour sketch)
      ; ------------------------------------------------------------------------
      ; Dans un sketch, les zones sombres = traits denses, zones claires = papier blanc
      
      tone = 1.0 - (grayC / 255.0)
      
      ; Application du contraste
      tone = 0.5 + (tone - 0.5) * contrast
      If tone < 0.0 : tone = 0.0 : EndIf
      If tone > 1.0 : tone = 1.0 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 4 : GÉNÉRATION DES HACHURES
      ; ------------------------------------------------------------------------
      ; Les hachures simulent les traits de crayon pour créer les ombres
      
      hatchValue = 0.0
      
      If hatchStyle > 0 And hatchDensity > 0.01
        
        Select hatchStyle
          
          Case 1  ; Hachures SIMPLES (lignes diagonales)
            Protected hatchSpacing1 = 3.0 + (1.0 - hatchDensity) * 5.0
            Protected hatchCoord1.f = (x + y) / hatchSpacing1
            Protected hatchFrac1.f = hatchCoord1 - Int(hatchCoord1)
            
            If hatchFrac1 < 0.3
              hatchValue = tone * 0.6
            EndIf
            
          Case 2  ; Hachures CROISÉES
            Protected hatchSpacing2 = 3.0 + (1.0 - hatchDensity) * 4.0
            
            ; Première série de hachures
            Protected hatchCoord2a.f = (x + y) / hatchSpacing2
            Protected hatchFrac2a.f = hatchCoord2a - Int(hatchCoord2a)
            
            ; Deuxième série de hachures (perpendiculaire)
            Protected hatchCoord2b.f = (x - y) / hatchSpacing2
            Protected hatchFrac2b.f = hatchCoord2b - Int(hatchCoord2b)
            
            If hatchFrac2a < 0.25 Or hatchFrac2b < 0.25
              hatchValue = tone * 0.7
            EndIf
            
          Case 3  ; Hachures CIRCULAIRES (suit les formes)
            ; Utilise le gradient local pour orienter les hachures
            Protected gradAngle.f = ATan2(edgeV, edgeH)
            Protected hatchSpacing3 = 4.0 + (1.0 - hatchDensity) * 4.0
            
            Protected hatchCoord3.f = (x * Cos(gradAngle) + y * Sin(gradAngle)) / hatchSpacing3
            Protected hatchFrac3.f = hatchCoord3 - Int(hatchCoord3)
            
            If hatchFrac3 < 0.3
              hatchValue = tone * 0.65
            EndIf
            
        EndSelect
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 5 : TEXTURE DU TRAIT DE CRAYON
      ; ------------------------------------------------------------------------
      ; Simule les irrégularités du graphite sur le papier
      
      If pencilTexture > 0.01
        Protected seed1 = (x * 23456 + y * 78901) & $7FFFFFFF
        Protected noiseVal1 = (seed1 % 1000) - 500
        pencilNoise = noiseVal1 / 500.0
        
        ; Le bruit suit la densité du trait
        pencilNoise = pencilNoise * pencilTexture * tone * 0.15
      Else
        pencilNoise = 0.0
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 6 : TEXTURE DU PAPIER
      ; ------------------------------------------------------------------------
      ; Grain du papier à dessin
      
      If paperGrain > 0.01
        Protected seed2 = ((x / 2) * 34567 + (y / 2) * 89012) & $7FFFFFFF
        Protected noiseVal2 = (seed2 % 1000) - 500
        paperNoise = noiseVal2 / 500.0
        
        ; Bruit secondaire plus fin
        Protected seed3 = (x * 45678 + y * 12345) & $7FFFFFFF
        Protected noiseVal3 = (seed3 % 1000) - 500
        Protected paperNoise2.f = noiseVal3 / 500.0
        
        paperNoise = paperNoise * 0.7 + paperNoise2 * 0.3
        paperNoise = paperNoise * paperGrain * 0.08
      Else
        paperNoise = 0.0
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 7 : OMBRAGE DOUX (entre les traits)
      ; ------------------------------------------------------------------------
      ; Crée un dégradé doux pour les zones sans hachures
      
      shading = tone * (1.0 - hatchDensity * 0.5) * 0.4
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 8 : COMPOSITION FINALE
      ; ------------------------------------------------------------------------
      ; Combine contours + hachures + ombrage + textures
      
      ; Commence avec un fond blanc
      Protected sketchValue.f = 1.0
      
      ; Applique les contours (traits noirs)
      sketchValue = sketchValue - edge
      
      ; Applique les hachures
      sketchValue = sketchValue - hatchValue
      
      ; Applique l'ombrage doux
      sketchValue = sketchValue - shading
      
      ; Ajoute les textures
      sketchValue = sketchValue + pencilNoise + paperNoise
      
      ; Limite les valeurs
      If sketchValue < 0.0 : sketchValue = 0.0 : EndIf
      If sketchValue > 1.0 : sketchValue = 1.0 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 9 : VARIATION DE PRESSION (zones plus ou moins appuyées)
      ; ------------------------------------------------------------------------
      ; Simule la pression variable du crayon
      
      Protected pressureSeed = ((x / 3) * 56789 + (y / 3) * 23456) & $7FFFFFFF
      Protected pressureVal = (pressureSeed % 1000) - 500
      Protected pressure.f = pressureVal / 5000.0
      
      ; Applique la variation de pression dans les zones de traits
      If sketchValue < 0.8
        sketchValue = sketchValue + pressure * (0.8 - sketchValue) * 0.3
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 10 : CONVERSION EN RGB (NUANCES DE GRIS)
      ; ------------------------------------------------------------------------
      
      Protected finalValue = Int(sketchValue * 255.0)
      
      r = finalValue
      g = finalValue
      b = finalValue
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 11 : LÉGÈRE TEINTE (optionnel - papier légèrement crème)
      ; ------------------------------------------------------------------------
      ; Ajoute une très légère teinte chaude pour simuler un papier crème
      
      If r > 240
        r = r - 3
        g = g - 1
        b = b - 5
      EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 12 : CLAMPING (LIMITATION DES VALEURS)
      ; ------------------------------------------------------------------------
      
      If r < 0 : r = 0 : EndIf : If r > 255 : r = 255 : EndIf
      If g < 0 : g = 0 : EndIf : If g > 255 : g = 255 : EndIf
      If b < 0 : b = 0 : EndIf : If b > 255 : b = 255 : EndIf
      
      ; ------------------------------------------------------------------------
      ; ÉTAPE 13 : ÉCRITURE DU PIXEL RÉSULTAT
      ; ------------------------------------------------------------------------
      
      *dst = *p\addr[1] + ((y * w + x) << 2)
      *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
      
    Next  ; Pixel suivant (x)
  Next    ; Ligne suivante (y)
  
EndProcedure

; ==============================================================================
; PROCÉDURE D'INITIALISATION DU FILTRE
; ==============================================================================

Procedure sketch(*param.parametre)
  
  ; Si appelé en mode "info", on configure les paramètres de l'interface
  If *param\info_active
    
    ; --- Métadonnées du filtre ---
    *param\typ = #FilterType_Artistic         ; Catégorie : artistique
    *param\subtype = #Artistic_Material
    *param\name = "Sketch / Pencil"           ; Nom affiché
    *param\remarque = "Transforme l'image en dessin au crayon avec hachures et textures"
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 0 : INTENSITÉ DES CONTOURS
    ; --------------------------------------------------------------------------
    *param\info[0] = "Contours"
    *param\info_data(0, 0) = 0     ; Valeur minimale (pas de contours)
    *param\info_data(0, 1) = 100   ; Valeur maximale (contours forts)
    *param\info_data(0, 2) = 70    ; Valeur par défaut (bien visible)
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 1 : DENSITÉ DES HACHURES
    ; --------------------------------------------------------------------------
    *param\info[1] = "Densité hachures"
    *param\info_data(1, 0) = 0     ; Min = aucune hachure
    *param\info_data(1, 1) = 100   ; Max = très dense
    *param\info_data(1, 2) = 50    ; Défaut = moyen
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 2 : STYLE DE HACHURES
    ; --------------------------------------------------------------------------
    *param\info[2] = "Style (0=Aucun/1=Simple/2=Croisé/3=Circulaire)"
    *param\info_data(2, 0) = 0     ; 0 = Aucune hachure
    *param\info_data(2, 1) = 3     ; 3 = Hachures circulaires
    *param\info_data(2, 2) = 2     ; Défaut = Hachures croisées
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 3 : TEXTURE DU CRAYON
    ; --------------------------------------------------------------------------
    *param\info[3] = "Texture crayon"
    *param\info_data(3, 0) = 0     ; Lisse
    *param\info_data(3, 1) = 100   ; Très texturé
    *param\info_data(3, 2) = 40    ; Défaut = légèrement texturé
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 4 : GRAIN DU PAPIER
    ; --------------------------------------------------------------------------
    *param\info[4] = "Grain papier"
    *param\info_data(4, 0) = 0     ; Papier lisse
    *param\info_data(4, 1) = 100   ; Papier très granuleux
    *param\info_data(4, 2) = 30    ; Défaut = léger grain
    
    ; --------------------------------------------------------------------------
    ; PARAMÈTRE 5 : CONTRASTE
    ; --------------------------------------------------------------------------
    *param\info[5] = "Contraste (100=normal)"
    *param\info_data(5, 0) = 50    ; Faible contraste
    *param\info_data(5, 1) = 200   ; Contraste élevé
    *param\info_data(5, 2) = 120   ; Défaut = légèrement boosté
    
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
  filter_start(@sketch_MT(), 3, 1)
  
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 339
; FirstLine = 333
; Folding = -
; EnableXP
; DPIAware