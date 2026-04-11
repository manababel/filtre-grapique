;==============================================================================
; FLOWLIQUIFY - Filtre de déformation fluide avec bruit de Perlin
;==============================================================================
; Crée un effet de liquéfaction en déformant l'image selon un champ de vecteurs
; généré par du bruit de Perlin 2D
;==============================================================================

; Structure pour stocker les gradients de Perlin
Structure PerlinGradients
  x.f[16]  ; Composantes X des gradients
  y.f[16]  ; Composantes Y des gradients
EndStructure

; Normalise un vecteur 2D pour obtenir une longueur unitaire
Procedure NormalizeVector(*x.Float, *y.Float)
  Protected len.f = Sqr(*x\f * *x\f + *y\f * *y\f)
  If len <> 0
    *x\f = *x\f / len
    *y\f = *y\f / len
  EndIf
EndProcedure

; Configure les gradients selon différents motifs
; mode 0 = 8 directions classiques
; mode 1 = 16 directions radiales uniformes
; mode 2 = vecteurs verticaux modifiés
; mode 3 = croix (4 directions orthogonales)
; mode 4 = diagonales (4 directions)
; mode 5 = directions aléatoires normalisées
Procedure SetupPerlinGradients(*grad.PerlinGradients, mode)
  Protected i
  
  Select mode
    Case 0 ; Classique 8 directions (cardinales + diagonales)
      *grad\x[0] = 1  : *grad\y[0] = 0
      *grad\x[1] = -1 : *grad\y[1] = 0
      *grad\x[2] = 0  : *grad\y[2] = 1
      *grad\x[3] = 0  : *grad\y[3] = -1
      *grad\x[4] = 1  : *grad\y[4] = 1
      *grad\x[5] = -1 : *grad\y[5] = 1
      *grad\x[6] = 1  : *grad\y[6] = -1
      *grad\x[7] = -1 : *grad\y[7] = -1
      
    Case 1 ; 16 directions radiales uniformément réparties
      For i = 0 To 15
        *grad\x[i] = Cos(i * 2.0 * #PI / 16)
        *grad\y[i] = Sin(i * 2.0 * #PI / 16)
      Next
      
    Case 2 ; Vecteurs à dominante verticale
      *grad\x[0] = 0   : *grad\y[0] = 1
      *grad\x[1] = 0   : *grad\y[1] = -1
      *grad\x[2] = 0.3 : *grad\y[2] = 1
      *grad\x[3] = -0.3: *grad\y[3] = 1
      
    Case 3 ; Croix - 4 directions cardinales uniquement
      *grad\x[0] = 1  : *grad\y[0] = 0
      *grad\x[1] = -1 : *grad\y[1] = 0
      *grad\x[2] = 0  : *grad\y[2] = 1
      *grad\x[3] = 0  : *grad\y[3] = -1
      
    Case 4 ; Diagonales - 4 directions diagonales uniquement
      *grad\x[0] = 1  : *grad\y[0] = 1
      *grad\x[1] = -1 : *grad\y[1] = 1
      *grad\x[2] = 1  : *grad\y[2] = -1
      *grad\x[3] = -1 : *grad\y[3] = -1
      
    Case 5 ; Directions aléatoires normalisées
      For i = 0 To 15
        *grad\x[i] = Random(200) / 100.0 - 1.0
        *grad\y[i] = Random(200) / 100.0 - 1.0
        NormalizeVector(@*grad\x[i], @*grad\y[i])
      Next
  EndSelect
EndProcedure

; Fonction de lissage (fade) pour interpolation douce
; Utilise un polynôme 6t^5 - 15t^4 + 10t^3
Procedure.f PerlinFade(t.f)
  ProcedureReturn t * t * t * (t * (t * 6 - 15) + 10)
EndProcedure

; Interpolation linéaire entre deux valeurs
Procedure.f Lerp(a.f, b.f, t.f)
  ProcedureReturn a + t * (b - a)
EndProcedure

; Calcule le produit scalaire entre le gradient et le vecteur de distance
; Utilise un hash pseudo-aléatoire pour sélectionner le gradient
Procedure.f DotGridGradient(*grad.PerlinGradients, ix, iy, x.f, y.f)
  ; Hash pseudo-aléatoire pour indexer les gradients (utilise 8 gradients)
  Protected gradientIndex = ((ix * 1836311903) ! (iy * 2971215073)) & 7
  
  ; Récupération du gradient
  Protected gx.f = *grad\x[gradientIndex]
  Protected gy.f = *grad\y[gradientIndex]
  
  ; Vecteur de distance du point à la cellule
  Protected dx.f = x - ix
  Protected dy.f = y - iy
  
  ; Produit scalaire
  ProcedureReturn (dx * gx + dy * gy)
EndProcedure

; Génère une valeur de bruit de Perlin 2D normalisée entre 0 et 1
Procedure.f PerlinNoise2D(*grad.PerlinGradients, x.f, y.f)
  ; Coins de la cellule contenant le point
  Protected x0 = Int(x)
  Protected x1 = x0 + 1
  Protected y0 = Int(y)
  Protected y1 = y0 + 1
  
  ; Courbes d'interpolation
  Protected sx.f = PerlinFade(x - x0)
  Protected sy.f = PerlinFade(y - y0)
  
  ; Produits scalaires aux 4 coins
  Protected n0.f = DotGridGradient(*grad, x0, y0, x, y)
  Protected n1.f = DotGridGradient(*grad, x1, y0, x, y)
  Protected n2.f = DotGridGradient(*grad, x0, y1, x, y)
  Protected n3.f = DotGridGradient(*grad, x1, y1, x, y)
  
  ; Interpolation bilinéaire
  Protected ix0.f = Lerp(n0, n1, sx)
  Protected ix1.f = Lerp(n2, n3, sx)
  
  ; Normalisation dans [0, 1]
  ProcedureReturn Lerp(ix0, ix1, sy) * 0.5 + 0.5
EndProcedure

; Échantillonnage bilinéaire pour interpolation d'image
; Permet d'obtenir une couleur lissée entre 4 pixels
Procedure BilinearSample(*src, lg, ht, x.f, y.f)
  ; Coordonnées des 4 pixels voisins
  Protected x0 = Int(x)
  Protected y0 = Int(y)
  Protected x1 = x0 + 1
  Protected y1 = y0 + 1
  
  ; Clamping aux bords de l'image
  If x1 >= lg : x1 = lg - 1 : EndIf
  If y1 >= ht : y1 = ht - 1 : EndIf
  
  ; Poids d'interpolation
  Protected dx.f = x - x0
  Protected dy.f = y - y0
  
  ; Offsets mémoire des 4 pixels (ARGB = 4 octets par pixel)
  Protected offset00 = (y0 * lg + x0) << 2
  Protected offset10 = (y0 * lg + x1) << 2
  Protected offset01 = (y1 * lg + x0) << 2
  Protected offset11 = (y1 * lg + x1) << 2
  
  ; Lecture des couleurs ARGB
  Protected c00 = PeekL(*src + offset00)
  Protected c10 = PeekL(*src + offset10)
  Protected c01 = PeekL(*src + offset01)
  Protected c11 = PeekL(*src + offset11)
  
  ; Extraction des composantes ARGB (optimisé avec décalages binaires)
  Protected a00 = (c00 >> 24) & $FF
  Protected r00 = (c00 >> 16) & $FF
  Protected g00 = (c00 >> 8) & $FF
  Protected b00 = c00 & $FF
  
  Protected a10 = (c10 >> 24) & $FF
  Protected r10 = (c10 >> 16) & $FF
  Protected g10 = (c10 >> 8) & $FF
  Protected b10 = c10 & $FF
  
  Protected a01 = (c01 >> 24) & $FF
  Protected r01 = (c01 >> 16) & $FF
  Protected g01 = (c01 >> 8) & $FF
  Protected b01 = c01 & $FF
  
  Protected a11 = (c11 >> 24) & $FF
  Protected r11 = (c11 >> 16) & $FF
  Protected g11 = (c11 >> 8) & $FF
  Protected b11 = c11 & $FF
  
  ; Pré-calcul des poids pour éviter répétitions
  Protected w00.f = (1 - dx) * (1 - dy)
  Protected w10.f = dx * (1 - dy)
  Protected w01.f = (1 - dx) * dy
  Protected w11.f = dx * dy
  
  ; Interpolation bilinéaire de chaque composante
  Protected a = a00 * w00 + a10 * w10 + a01 * w01 + a11 * w11
  Protected r = r00 * w00 + r10 * w10 + r01 * w01 + r11 * w11
  Protected g = g00 * w00 + g10 * w10 + g01 * w01 + g11 * w11
  Protected b = b00 * w00 + b10 * w10 + b01 * w01 + b11 * w11
  
  ; Reconstruction de la couleur ARGB
  ProcedureReturn (Int(a) << 24) | (Int(r) << 16) | (Int(g) << 8) | Int(b)
EndProcedure

; Thread de traitement de la déformation fluide (multi-thread)
Procedure FlowLiquify_MT(*p.parametre)
  Protected *src = *p\addr[0]
  Protected *dst = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected intensity.f = *p\option[0]      ; Amplitude maximale du déplacement
  Protected scale.f = *p\option[1] / 1000.0 ; Échelle du bruit (fréquence)
  Protected gradMode = *p\option[2]          ; Mode de gradient
  
  ; Création locale des gradients pour ce thread
  Protected grad.PerlinGradients
  SetupPerlinGradients(@grad, gradMode)
  
  ; Calcul de la plage de lignes à traiter par ce thread
  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  If stopY > ht - 1 : stopY = ht - 1 : EndIf
  
  Protected x, y
  Protected srcX.f, srcY.f
  Protected offsetDst
  Protected angle.f, vx.f, vy.f
  
  ; Traitement de chaque pixel de la plage
  For y = startY To stopY
    For x = 0 To lg - 1
      ; Génération d'un angle de déformation via bruit de Perlin
      angle = PerlinNoise2D(@grad, x * scale, y * scale) * 2.0 * #PI
      
      ; Conversion en vecteur de déplacement
      vx = Cos(angle) * intensity
      vy = Sin(angle) * intensity
      
      ; Calcul de la position source (avec déformation)
      srcX = x + vx
      srcY = y + vy
      
      ; Clamping pour rester dans les limites de l'image
      If srcX < 0 : srcX = 0 : ElseIf srcX > lg - 1 : srcX = lg - 1 : EndIf
      If srcY < 0 : srcY = 0 : ElseIf srcY > ht - 1 : srcY = ht - 1 : EndIf
      
      ; Écriture du pixel interpolé dans la destination
      offsetDst = (y * lg + x) << 2
      PokeL(*dst + offsetDst, BilinearSample(*src, lg, ht, srcX, srcY))
    Next
  Next
EndProcedure


; Procédure principale du filtre FlowLiquify
Procedure FlowLiquify(*param.parametre)
  ; Mode information : définition des paramètres du filtre
  If *param\info_active
    *param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Other
    *param\name = "FlowLiquify"
    *param\remarque = "Effet de déformation fluide/liquide avec bruit de Perlin 2D"
    
    ; Définition des contrôles
    *param\info[0] = "Intensité"        ; Amplitude du déplacement
    *param\info[1] = "Échelle bruit"    ; Fréquence du bruit
    *param\info[2] = "Mode gradients"   ; Type de gradients (0-5)
    *param\info[3] = "Masque binaire"   ; Application du masque
    
    ; Plages de valeurs : [min, max, valeur_défaut]
    *param\info_data(0, 0) = 0  : *param\info_data(0, 1) = 50  : *param\info_data(0, 2) = 5
    *param\info_data(1, 0) = 0  : *param\info_data(1, 1) = 100 : *param\info_data(1, 2) = 10
    *param\info_data(2, 0) = 0  : *param\info_data(2, 1) = 5   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0  : *param\info_data(3, 1) = 1   : *param\info_data(3, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Lancement du traitement multi-thread
  ; 3 = nombre d'options, 1 = nécessite une copie de l'image source
  filter_start(@FlowLiquify_MT(), 3, 1)
EndProcedure

;==============================================================================
; FIN DU MODULE FLOWLIQUIFY
;==============================================================================
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 252
; FirstLine = 208
; Folding = --
; EnableXP
; DPIAware