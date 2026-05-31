; ------------------------------------------------------------------------------
; Macro : Atkinson_sp
; Description :
;   Diffuse l’erreur de quantification vers un pixel voisin,
;   selon la matrice d'Atkinson (diviseur 8).
; Paramètres :
;   mul = coefficient de pondération (toujours 1 ici)
;   pos = décalage mémoire du pixel cible en octets (<< 2 déjà appliqué)
; ------------------------------------------------------------------------------
Macro Atkinson_sp(mul , pos)
  *dstPixel = *cible + pos                        ; Pointeur vers le pixel cible
  getrgb(*dstPixel\l , r , g , b)                 ; Lecture des composantes RGB
  r + (errR * mul) / 8                            ; Application de l’erreur pondérée
  g + (errG * mul) / 8
  b + (errB * mul) / 8
  clamp_RGB(r, g, b)                              ; Clamp pour rester entre 0 et 255
  *dstPixel\l = a + (r << 16) | (g << 8) | b      ; Réécriture du pixel (alpha préservé)
EndMacro

Procedure AtkinsonDither_MT(*param.parametre)
  Protected *cible  = *param\cible
  Protected lg = *param\lg, ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB                      ; Couleurs originales
  Protected newR, newG, newB                      ; Couleurs quantifiées
  Protected errR, errG, errB                      ; Erreurs de quantification
  Protected a, r, g, b
  Protected *dstPixel.Pixel32
  Protected ndc = *param\addr[2]                  ; Table de quantification
  
  ; Définition des lignes à traiter (évite les 2 lignes du bas)
  Protected startPos = (*param\thread_pos * (ht - 3)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 3)) / *param\thread_max
  
  ; Parcours des pixels, évite 2 colonnes à gauche et droite
  For y = startPos To endPos
    For x = 2 To lg - 3
      i = y * lg + x
      *dstPixel = *cible + (i << 2)
      getargb(*dstPixel\l , a, oldR , oldG , oldB)
      
      ; Quantification des composantes
      newR = PeekA(ndc + oldR) : newG = PeekA(ndc + oldG) : newB = PeekA(ndc + oldB)
      errR = oldR - newR : errG = oldG - newG : errB = oldB - newB
      
      ; Mise à jour du pixel
      a = a << 24
      *dstPixel\l = a + (newR << 16) | (newG << 8) | newB
      
      ; Diffusion de l’erreur selon la matrice Atkinson :
      ; Ligne actuelle
      Atkinson_sp(1,  (( y    * lg + x+1) << 2))    ; x+1
      Atkinson_sp(1,  (( y    * lg + x+2) << 2))    ; x+2
                                                    ; Ligne y+1
      Atkinson_sp(1,  (((y+1) * lg + x-1) << 2))    ; x-1
      Atkinson_sp(1,  (((y+1) * lg + x  ) << 2))    ; x
      Atkinson_sp(1,  (((y+1) * lg + x+1) << 2))    ; x+1
                                                    ; Ligne y+2
      Atkinson_sp(1,  (((y+2) * lg + x  ) << 2))    ; x
    Next
  Next
EndProcedure

Procedure AtkinsonDither(*param.parametre)
  dither(@AtkinsonDither_MT() , "AtkinsonDither")
EndProcedure

;------------------------

Procedure AutoOtsuThreshold_MT(*param.parametre)
  
  Protected *source = *param\source
  Protected *cible  = *param\cible
  Protected *mask   = *param\mask
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected tmax = lg * ht
  Protected i, x, y, r, g, b, lum, var, alpha ,t
  Protected threshold
  
  Dim histo(255)
  Dim buffer(tmax)
  
  ; === Étape 1 : Calcul histogramme de luminance ===
  For i = 0 To tmax - 1
    var = PeekL(*source + i * 4)
    r = (var >> 16) & $FF
    g = (var >> 8)  & $FF
    b = var & $FF
    lum = (r * 54 + g * 183 + b * 18) >> 8  ; Rec.709
    buffer(i) = lum
    histo(lum) + 1
  Next
  
  ; === Étape 2 : Calcul du seuil optimal (Otsu) ===
  Protected total = tmax
  Protected sumAll = 0
  For i = 0 To 255 : sumAll + i * histo(i) : Next
  
  Protected sum = 0, wB = 0, wF, mB.f, mF.f
  Protected maxVar.f = -1.0
  threshold = 0
  
  For t = 0 To 255
    wB + histo(t)
    If wB = 0 : Continue : EndIf
    wF = total - wB
    If wF = 0 : Break : EndIf
    
    sum + t * histo(t)
    mB = sum / wB
    mF = (sumAll - sum) / wF
    
    Protected varBetween.f = wB * wF * (mB - mF) * (mB - mF)
    If varBetween > maxVar
      maxVar = varBetween
      threshold = t
    EndIf
  Next
  
  ; === Étape 3 : Binarisation ===
  For i = 0 To tmax - 1
    If *mask
      alpha = PeekA(*mask + i * 4)
      If alpha < 128
        var = PeekL(*source + i * 4)
        PokeL(*cible + i * 4, var)
        Continue
      EndIf
    EndIf
    
    If buffer(i) > threshold
      PokeL(*cible + i * 4, $FFFFFF)
    Else
      PokeL(*cible + i * 4, 0)
    EndIf
  Next
  
EndProcedure

Procedure AutoOtsuThreshold(*param.parametre)
  ; Affichage des informations si demandé
  If param\info_active
    param\typ = #Filter_Type_Dither
    param\name = "AutoOtsuThreshold"
    param\remarque = "Attention , fonction non threadée"
    param\info[0] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 2  : param\info_data(0,2) = 0
    ProcedureReturn
  EndIf
  Protected *source = *param\source        ; Image source (lecture)
  Protected *cible  = *param\cible         ; Image cible (écriture)
  Protected *mask   = *param\mask          ; Masque éventuel (optionnel)
  Protected lg = *param\lg                 ; Largeur
  Protected ht = *param\ht                 ; Hauteur
  Protected levels = *param\option[0]      ; Niveaux de quantification (1-8)
  Protected i
  ; Vérification de la validité des images source et cible
  If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf
  ; Détection du nombre de cœurs pour le traitement multi-threadé (limité de 1 à 128)
  Protected thread = 1 ; CountCPUs(#PB_System_CPUs)
  Protected Dim tr(thread) ; Tableau des threads (inutile ici car non utilisé ensuite)
                           ; Lancement du traitement Floyd-Steinberg en multi-thread
  MultiThread_MT(@AutoOtsuThreshold_MT())
  ; Si un masque est fourni, appliquer un post-traitement avec masque
  If *param\mask And *param\option[0] : *param\mask_type = *param\option[0] - 1 : MultiThread_MT(@_mask()) : EndIf
  ; Nettoyage mémoire (même si tr() n’est pas utilisé ici)
  FreeArray(tr())
EndProcedure

;------------------------

Macro Burkes_sp(mul , pos)
  *dstPixel = *cible + pos                        ; Pointeur vers le pixel cible
  getrgb(*dstPixel\l , r , g , b)                 ; Lecture des composantes RGB
  r + (errR * mul) >> 5                           ; Application de l’erreur pondérée (division par 32)
  g + (errG * mul) >> 5
  b + (errB * mul) >> 5
  clamp_RGB(r, g, b)                              ; Clamp pour rester entre 0 et 255
  *dstPixel\l = a + (r << 16) | (g << 8) | b      ; Écriture de la nouvelle couleur (alpha inchangé)
EndMacro

Procedure BurkesDither_MT(*param.parametre)
  Protected *cible  = *param\cible                ; Pointeur image destination
  Protected lg = *param\lg, ht = *param\ht        ; Dimensions de l’image
  Protected x, y, i
  Protected oldR, oldG, oldB                      ; Couleurs originales
  Protected newR, newG, newB                      ; Couleurs quantifiées
  Protected errR, errG, errB                      ; Erreur de quantification
  Protected a, r, g, b                            ; Composantes + alpha
  Protected *dstPixel.Pixel32
  Protected ndc = *param\addr[2]                  ; Table de quantification (non-dithered colors)
  
  ; Calcul de la plage de lignes à traiter (évite les bords du bas)
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max
  
  ; Balayage de l’image, en évitant les 2 colonnes latérales
  For y = startPos To endPos
    For x = 2 To lg - 3
      i = y * lg + x
      *dstPixel = *cible + (i << 2)
      getargb(*dstPixel\l , a, oldR , oldG , oldB)
      
      ; Quantification des couleurs via table
      newR = PeekA(ndc + oldR) : newG = PeekA(ndc + oldG) : newB = PeekA(ndc + oldB)
      
      ; Calcul de l’erreur
      errR = oldR - newR : errG = oldG - newG : errB = oldB - newB
      
      ; Mise à jour du pixel courant
      a = a << 24
      *dstPixel\l = a + (newR << 16) | (newG << 8) | newB
      
      ; Diffusion de l’erreur selon matrice de Burkes :
      ; Ligne actuelle
      Burkes_sp(8,  (( y    * lg + x+1) << 2))    ; x+1
      Burkes_sp(4,  (( y    * lg + x+2) << 2))    ; x+2
                                                  ; Ligne suivante (y+1)
      Burkes_sp(2,  (((y+1) * lg + x-2) << 2))    ; x-2
      Burkes_sp(4,  (((y+1) * lg + x-1) << 2))    ; x-1
      Burkes_sp(8,  (((y+1) * lg + x  ) << 2))    ; x
      Burkes_sp(4,  (((y+1) * lg + x+1) << 2))    ; x+1
      Burkes_sp(2,  (((y+1) * lg + x+2) << 2))    ; x+2
    Next
  Next
EndProcedure

Procedure BurkesDither(*param.parametre)
  dither(@BurkesDither_MT() , "BurkesDither")
EndProcedure

;------------------------

Macro FloydDither_sp(mul , pos)
  *dstPixel = *cible + pos                         ; Pointeur vers le pixel cible
  getrgb(*dstPixel\l , r , g , b)                  ; Lecture des composantes RGB
  r + (errR * mul) >> 4                            ; Application de l’erreur pondérée (division par 16)
  g + (errG * mul) >> 4
  b + (errB * mul) >> 4
  clamp_RGB(r, g, b)                               ; Clamp pour éviter dépassement de 0-255
  *dstPixel\l = a + (r << 16) | (g << 8) | b       ; Écriture du pixel modifié (avec alpha conservé)
EndMacro

Procedure FloydDither_MT(*param.parametre)
  Protected *cible  = *param\cible        ; Image cible à traiter
  Protected lg = *param\lg                ; Largeur de l'image
  Protected ht = *param\ht                ; Hauteur de l'image
  Protected i, x, y
  Protected oldR, oldG, oldB              ; Valeurs RGB originales
  Protected newR, newG, newB              ; Valeurs RGB quantifiées
  Protected errR, errG, errB              ; Erreur entre original et quantifié
  Protected a, r, g, b                    ; Couleurs et alpha pour traitement
  Protected *dstPixel.Pixel32
  Protected ndc = *param\addr[2]
  ; Calcule les lignes à traiter pour ce thread
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max
  ; Parcours ligne par ligne, pixel par pixel (sauf bords)
  For y = startPos To endPos
    For x = 1 To lg - 2
      i = y * lg + x
      *dstPixel = *cible + (y * lg + x) << 2
      getargb(*dstPixel\l , a, oldR , oldG , oldB)
      ; Quantification RGB à l'aide de la table
      newR = PeekA(ndc + oldR) : newG = PeekA(ndc + oldG) : newB = PeekA(ndc + oldB)
      errR = oldR - newR : errG = oldG - newG : errB = oldB - newB
      a = a << 24
      ; Mise à jour du pixel courant avec valeur quantifiée
      *dstPixel\l = a + (newR << 16) | (newG << 8) | newB
      ; Diffusion de l'erreur vers les 4 voisins selon Floyd-Steinberg
      FloydDither_sp( 7 , ((y * lg + (x + 1)) << 2) )         ; Droite
      FloydDither_sp( 3 , (((y + 1) * lg + (x - 1)) << 2) )   ; Bas-gauche
      FloydDither_sp( 5 , (((y + 1) * lg + x) << 2) )         ; Bas
      FloydDither_sp( 1 , (((y + 1) * lg + (x + 1)) << 2) )   ; Bas-droite
    Next
  Next
EndProcedure

Procedure FloydDither(*param.parametre)
  dither(@FloydDither_MT() , "FloydDither")
EndProcedure

;------------------------

Macro JJN_sp(mul , pos)
  *dstPixel = *cible + pos                        ; Pointeur vers le pixel cible
  getrgb(*dstPixel\l , r , g , b)                 ; Lecture des composantes RGB
  r + (errR * mul) / 48                           ; Application de l’erreur pondérée
  g + (errG * mul) / 48
  b + (errB * mul) / 48
  clamp_RGB(r, g, b)                              ; Clamp pour rester dans [0..255]
  *dstPixel\l = a + (r << 16) | (g << 8) | b      ; Réécriture du pixel (alpha préservé)
EndMacro

Procedure JJNDither_MT(*param.parametre)
  Protected *cible  = *param\cible
  Protected lg = *param\lg, ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB                      ; Couleurs originales
  Protected newR, newG, newB                      ; Couleurs quantifiées
  Protected errR, errG, errB                      ; Erreurs de quantification
  Protected a, r, g, b
  Protected *dstPixel.Pixel32
  Protected ndc = *param\addr[2]                  ; Table de quantification
  
  ; Définition des lignes à traiter (évite les 2 lignes du bas)
  Protected startPos = (*param\thread_pos * (ht - 3)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 3)) / *param\thread_max
  
  ; Parcours des pixels, évite 2 colonnes à gauche et droite
  For y = startPos To endPos
    For x = 2 To lg - 3
      i = y * lg + x
      *dstPixel = *cible + (i << 2)
      getargb(*dstPixel\l , a, oldR , oldG , oldB)
      
      ; Quantification des composantes
      newR = PeekA(ndc + oldR) : newG = PeekA(ndc + oldG) : newB = PeekA(ndc + oldB)
      errR = oldR - newR : errG = oldG - newG : errB = oldB - newB
      
      ; Mise à jour du pixel
      a = a << 24
      *dstPixel\l = a + (newR << 16) | (newG << 8) | newB
      
      ; Diffusion de l’erreur selon la matrice JJN (2 lignes)
      ; Ligne actuelle
      JJN_sp(7,  (( y    * lg + x+1) << 2))
      JJN_sp(5,  (( y    * lg + x+2) << 2))
      ; Ligne y+1
      JJN_sp(3,  (((y+1) * lg + x-2) << 2))
      JJN_sp(5,  (((y+1) * lg + x-1) << 2))
      JJN_sp(7,  (((y+1) * lg + x  ) << 2))
      JJN_sp(5,  (((y+1) * lg + x+1) << 2))
      JJN_sp(3,  (((y+1) * lg + x+2) << 2))
      ; Ligne y+2
      JJN_sp(1,  (((y+2) * lg + x-2) << 2))
      JJN_sp(3,  (((y+2) * lg + x-1) << 2))
      JJN_sp(5,  (((y+2) * lg + x  ) << 2))
      JJN_sp(3,  (((y+2) * lg + x+1) << 2))
      JJN_sp(1,  (((y+2) * lg + x+2) << 2))
    Next
  Next
EndProcedure

Procedure JJNDither(*param.parametre)
  dither(@JJNDither_MT() , "JJNDither")
EndProcedure

;------------------------

Procedure RandomDither_MT(*param.parametre)
  Protected *cible = *param\cible
  Protected lg = *param\lg, ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB
  Protected newR, newG, newB
  Protected a, r, g, b
  Protected *dstPixel.Pixel32
  Protected ndc = *param\addr[2]
  
  ; Evite bordures (pas obligatoire ici mais mieux)
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * ht) / *param\thread_max
  
  For y = startPos To endPos - 1
    For x = 0 To lg - 1
      i = y * lg + x
      *dstPixel = *cible + (i << 2)
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      
      ; Ajout bruit aléatoire dans [-0.5, +0.5] sur [0..255]
      ; On ajuste amplitude du bruit selon quantification
      Protected noiseR = Random(255) - 128
      Protected noiseG = Random(255) - 128
      Protected noiseB = Random(255) - 128
      
      ; Ajuste la valeur avec bruit avant quantification
      r = oldR + noiseR >> 3
      g = oldG + noiseG >> 3
      b = oldB + noiseB >> 3
      clamp_rgb(r,g,b)
      
      ; Quantification avec table ndc
      newR = PeekA(ndc + r)
      newG = PeekA(ndc + g)
      newB = PeekA(ndc + b)
      
      a = a << 24
      *dstPixel\l = a + (newR << 16) | (newG << 8) | newB
    Next
  Next
EndProcedure

Procedure RandomDither(*param.parametre)
  dither(@RandomDither_MT() , "RandomDither")
EndProcedure

;------------------------

Macro Sierra_sp(mul , pos)
  *dstPixel = *cible + pos                        ; Pointeur pixel cible
  getrgb(*dstPixel\l , r , g , b)                 ; Lecture composantes RGB
  r + (errR * mul) / 32                           ; Application erreur pondérée
  g + (errG * mul) / 32
  b + (errB * mul) / 32
  clamp_RGB(r, g, b)                             ; Clamp [0..255]
  *dstPixel\l = a + (r << 16) | (g << 8) | b     ; Réécriture pixel (alpha préservé)
EndMacro

Procedure SierraDither_MT(*param.parametre)
  Protected *cible = *param\cible
  Protected lg = *param\lg, ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB
  Protected newR, newG, newB
  Protected errR, errG, errB
  Protected a, r, g, b
  Protected *dstPixel.Pixel32
  Protected ndc = *param\addr[2]
  
  ; Eviter bord bas et colonnes extrêmes (bordures)
  Protected startPos = (*param\thread_pos * (ht - 3)) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * (ht - 3)) / *param\thread_max
  
  For y = startPos To endPos
    For x = 2 To lg - 3
      i = y * lg + x
      *dstPixel = *cible + (i << 2)
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      
      ; Quantification des composantes
      newR = PeekA(ndc + oldR) : newG = PeekA(ndc + oldG) : newB = PeekA(ndc + oldB)
      
      ; Calcul erreur
      errR = oldR - newR : errG = oldG - newG : errB = oldB - newB
      
      ; Mise à jour pixel
      a = a << 24
      *dstPixel\l = a + (newR << 16) | (newG << 8) | newB
      
      ; Diffusion erreur selon matrice Sierra
      ; Ligne y
      Sierra_sp(5,  ((y    * lg + x+1) << 2))
      Sierra_sp(3,  ((y    * lg + x+2) << 2))
      ; Ligne y+1
      Sierra_sp(2,  (((y+1) * lg + x-2) << 2))
      Sierra_sp(4,  (((y+1) * lg + x-1) << 2))
      Sierra_sp(5,  (((y+1) * lg + x  ) << 2))
      Sierra_sp(4,  (((y+1) * lg + x+1) << 2))
      Sierra_sp(2,  (((y+1) * lg + x+2) << 2))
      ; Ligne y+2
      Sierra_sp(2,  (((y+2) * lg + x-1) << 2))
      Sierra_sp(3,  (((y+2) * lg + x  ) << 2))
      Sierra_sp(2,  (((y+2) * lg + x+1) << 2))
    Next
  Next
EndProcedure

Procedure SierraDither(*param.parametre)
  dither(@SierraDither_MT() , "SierraDither")
EndProcedure

;------------------------

Macro SierraLite_sp(mul , pos)
  *dstPixel = *cible + pos                        ; Pointeur vers le pixel cible
  getrgb(*dstPixel\l , r , g , b)                 ; Lecture RGB
  r + (errR * mul) / 16                           ; Application erreur pondérée
  g + (errG * mul) / 16
  b + (errB * mul) / 16
  clamp_RGB(r, g, b)                              ; Clamp [0..255]
  *dstPixel\l = a + (r << 16) | (g << 8) | b      ; Réécriture pixel (alpha conservé)
EndMacro

Procedure SierraLiteDither_MT(*param.parametre)
  Protected *cible = *param\cible
  Protected lg = *param\lg, ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB
  Protected newR, newG, newB
  Protected errR, errG, errB
  Protected a, r, g, b
  Protected *dstPixel.Pixel32
  Protected ndc = *param\addr[2]  ; Table de quantification
  
  ; Définir plage lignes à traiter (éviter bord bas)
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max
  
  ; Parcours pixels (éviter 2 colonnes bord gauche/droite)
  For y = startPos To endPos
    For x = 2 To lg - 3
      i = y * lg + x
      *dstPixel = *cible + (i << 2)
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      
      ; Quantification
      newR = PeekA(ndc + oldR) : newG = PeekA(ndc + oldG) : newB = PeekA(ndc + oldB)
      
      ; Calcul erreur
      errR = oldR - newR : errG = oldG - newG : errB = oldB - newB
      
      ; Mise à jour pixel
      a = a << 24
      *dstPixel\l = a + (newR << 16) | (newG << 8) | newB
      
      ; Diffusion erreur Sierra Lite
      SierraLite_sp(2, ((y    * lg + x+1) << 2))    ; x+1, y
      SierraLite_sp(1, ((y    * lg + x+2) << 2))    ; x+2, y
      SierraLite_sp(1, (((y+1) * lg + x-1) << 2))   ; x-1, y+1
      SierraLite_sp(1, (((y+1) * lg + x  ) << 2))   ; x, y+1
    Next
  Next
EndProcedure

Procedure SierraLiteDither(*param.parametre)
  dither(@SierraLiteDither_MT() , "SierraLiteDither")
EndProcedure

;------------------------

Macro Stucki_sp(mul , pos)
  *dstPixel = *cible + pos                           ; Pointeur vers le pixel voisin
  getrgb(*dstPixel\l , r , g , b)                    ; Lecture des composantes RGB
  r + (errR * mul) / 42                              ; Application de l’erreur pondérée
  g + (errG * mul) / 42
  b + (errB * mul) / 42
  clamp_RGB(r, g, b)                                 ; Clamp pour rester dans [0..255]
  *dstPixel\l = a + (r << 16) | (g << 8) | b         ; Écriture du pixel corrigé
EndMacro

Procedure StuckiDither_MT(*param.parametre)
  Protected *cible  = *param\cible        ; Image cible à traiter
  Protected lg = *param\lg                ; Largeur de l'image
  Protected ht = *param\ht                ; Hauteur de l'image
  Protected i, x, y
  Protected oldR, oldG, oldB              ; Composantes originales du pixel
  Protected newR, newG, newB              ; Composantes quantifiées
  Protected errR, errG, errB              ; Erreur de quantification
  Protected a, r, g, b                    ; Couleurs et alpha
  Protected *dstPixel.Pixel32
  Protected ndc = *param\addr[2]          ; Table de quantification
  
  ; Calcule la plage de lignes à traiter pour ce thread (évite les bords)
  Protected startPos = (*param\thread_pos * (ht - 3)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 3)) / *param\thread_max
  
  ; Parcours ligne par ligne et pixel par pixel (en évitant les bords horizontaux)
  For y = startPos To endPos
    For x = 2 To lg - 3
      i = y * lg + x
      *dstPixel = *cible + (i << 2)
      getargb(*dstPixel\l , a, oldR , oldG , oldB)
      newR = PeekA(ndc + oldR) : newG = PeekA(ndc + oldG) : newB = PeekA(ndc + oldB)
      errR = oldR - newR : errG = oldG - newG : errB = oldB - newB
      a = a << 24
      *dstPixel\l = a + (newR << 16) | (newG << 8) | newB
      
      ; Diffusion de l'erreur vers les 12 voisins selon la matrice Stucki
      Stucki_sp(8,  ((y   * lg + x+1) << 2)) ; droite
      Stucki_sp(4,  ((y   * lg + x+2) << 2)) ; droite+1
      Stucki_sp(2,  (((y+1) * lg + x-2) << 2)) ; ligne+1 gauche+2
      Stucki_sp(4,  (((y+1) * lg + x-1) << 2)) ; ligne+1 gauche+1
      Stucki_sp(8,  (((y+1) * lg + x  ) << 2)) ; ligne+1 centre
      Stucki_sp(4,  (((y+1) * lg + x+1) << 2)) ; ligne+1 droite+1
      Stucki_sp(2,  (((y+1) * lg + x+2) << 2)) ; ligne+1 droite+2
      Stucki_sp(1,  (((y+2) * lg + x-2) << 2)) ; ligne+2 gauche+2
      Stucki_sp(2,  (((y+2) * lg + x-1) << 2)) ; ligne+2 gauche+1
      Stucki_sp(4,  (((y+2) * lg + x  ) << 2)) ; ligne+2 centre
      Stucki_sp(2,  (((y+2) * lg + x+1) << 2)) ; ligne+2 droite+1
      Stucki_sp(1,  (((y+2) * lg + x+2) << 2)) ; ligne+2 droite+2
    Next
  Next
EndProcedure

Procedure StuckiDither(*param.parametre)
  dither(@StuckiDither_MT() , "StuckiDither")
EndProcedure

;------------------------

Macro BayerThreshold(x, y, levels)
  Bayer4x4((y) & 3, (x) & 3) * 255 / (levels - 1)
EndMacro

Procedure BayerDither_MT(*param.parametre)
  
  Protected Dim Bayer4x4(3,3)
  Bayer4x4(0,0) =  0 : Bayer4x4(0,1) =  8 : Bayer4x4(0,2) =  2 : Bayer4x4(0,3) = 10
  Bayer4x4(1,0) = 12 : Bayer4x4(1,1) =  4 : Bayer4x4(1,2) = 14 : Bayer4x4(1,3) =  6
  Bayer4x4(2,0) =  3 : Bayer4x4(2,1) = 11 : Bayer4x4(2,2) =  1 : Bayer4x4(2,3) =  9
  Bayer4x4(3,0) = 15 : Bayer4x4(3,1) =  7 : Bayer4x4(3,2) = 13 : Bayer4x4(3,3) =  5
  
  Protected *cible = *param\cible
  Protected lg = *param\lg, ht = *param\ht
  Protected x, y, i
  Protected r, g, b, a, gray
  Protected *dstPixel.Pixel32
  Protected levels = *param\option[0]
  Protected *ndc = *param\addr[2]   ; LUT déjà préparée
  
  If levels < 2 : levels = 2 : EndIf
  Protected Steping.f = 255.0 / (levels - 1) ; taille d’un pas (float)
  Protected offset.f, rf.f, gf.f, bf.f
  
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      i = y * lg + x
      *dstPixel = *cible + (i << 2)
      getargb(*dstPixel\l, a, r, g, b)
      
      ; offset normalisé = ((BayerValue + 0.5)/16 - 0.5) * Steping
      ; => range ≈ [-0.5*Steping, +0.5*Steping)
      offset = ((Bayer4x4((y) & 3, (x) & 3) + 0.5) * Steping / 16.0) - (Steping / 2.0)
      
      If *param\option[1] ; N&B : travailler sur la luminance
        gray = (r * 54 + g * 183 + b * 18) >> 8
        gray = gray + offset
        If gray < 0 : gray = 0 : EndIf
        If gray > 255 : gray = 255 : EndIf
        ; quantification via LUT
        r = PeekA(*ndc + Int(gray + 0.5))
        g = r
        b = r
      Else
        ; application par canal (offset identique pour les 3 canaux)
        rf = r + offset : gf = g + offset : bf = b + offset
        If rf < 0 : rf = 0 : EndIf
        If rf > 255 : rf = 255 : EndIf
        If gf < 0 : gf = 0 : EndIf
        If gf > 255 : gf = 255 : EndIf
        If bf < 0 : bf = 0 : EndIf
        If bf > 255 : bf = 255 : EndIf
        
        r = PeekA(*ndc + Int(rf + 0.5))
        g = PeekA(*ndc + Int(gf + 0.5))
        b = PeekA(*ndc + Int(bf + 0.5))
      EndIf
      
      a = a << 24
      *dstPixel\l = a | (r << 16) | (g << 8) | b
    Next
  Next
EndProcedure

Procedure BayerDither(*param.parametre)
  dither(@BayerDither_MT(), "BayerDither")
EndProcedure

;------------------------

Macro SF_sp(mul, xx, yy)
  If xx >= 0 And xx < lg And yy >= 0 And yy < ht
    *dstPixel = *cible + ((yy * lg + xx) << 2)
    getrgb(*dstPixel\l, r, g, b)
    r + (errR * mul) / 32
    g + (errG * mul) / 32
    b + (errB * mul) / 32
    clamp_RGB(r, g, b)
    *dstPixel\l = a + (r << 16) | (g << 8) | b
  EndIf
EndMacro

Procedure ShiauFanDither_MT(*param.parametre)
  Protected *cible = *param\cible
  Protected lg = *param\lg, ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB
  Protected newR, newG, newB
  Protected errR, errG, errB
  Protected a, r, g, b
  Protected *dstPixel.Pixel32
  Protected *ndc = *param\addr[2]
  
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      i = y * lg + x
      *dstPixel = *cible + (i << 2)
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      
      ; Quantification via LUT
      newR = PeekA(*ndc + oldR)
      newG = PeekA(*ndc + oldG)
      newB = PeekA(*ndc + oldB)
      
      errR = oldR - newR
      errG = oldG - newG
      errB = oldB - newB
      
      a = a << 24
      *dstPixel\l = a + (newR << 16) | (newG << 8) | newB
      
      ; Diffusion selon Shiau–Fan
      ; Ligne y
      SF_sp(8, x+1, y)
      SF_sp(4, x+2, y)
      
      ; Ligne y+1
      SF_sp(2, x-2, y+1)
      SF_sp(4, x-1, y+1)
      SF_sp(8, x,   y+1)
      SF_sp(4, x+1, y+1)
      SF_sp(2, x+2, y+1)
    Next
  Next
EndProcedure

Procedure ShiauFanDither(*param.parametre)
  dither(@ShiauFanDither_MT(), "ShiauFanDither")
EndProcedure

;------------------------

Macro Kite_sp(mul, xx, yy)
  If xx >= 0 And xx < lg And yy >= 0 And yy < ht
    *dstPixel = *cible + ((yy * lg + xx) << 2)
    getrgb(*dstPixel\l, r, g, b)
    r + (errR * mul) / 32
    g + (errG * mul) / 32
    b + (errB * mul) / 32
    clamp_RGB(r, g, b)
    *dstPixel\l = a + (r << 16) | (g << 8) | b
  EndIf
EndMacro

Procedure KiteDither_MT(*param.parametre)
  Protected *cible = *param\cible
  Protected lg = *param\lg, ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB
  Protected newR, newG, newB
  Protected errR, errG, errB
  Protected a, r, g, b
  Protected *dstPixel.Pixel32
  Protected *ndc = *param\addr[2]

  For y = 0 To ht - 1
    For x = 0 To lg - 1
      i = y * lg + x
      *dstPixel = *cible + (i << 2)
      getargb(*dstPixel\l, a, oldR, oldG, oldB)

      ; Quantification via LUT
      newR = PeekA(*ndc + oldR)
      newG = PeekA(*ndc + oldG)
      newB = PeekA(*ndc + oldB)

      errR = oldR - newR
      errG = oldG - newG
      errB = oldB - newB

      a = a << 24
      *dstPixel\l = a + (newR << 16) | (newG << 8) | newB

      ; Diffusion Kite (cerf-volant)
      ; Ligne y
      Kite_sp(7, x+1, y)
      Kite_sp(5, x+2, y)
      ; Ligne y+1
      Kite_sp(3, x-2, y+1)
      Kite_sp(5, x-1, y+1)
      Kite_sp(7, x,   y+1)
      Kite_sp(5, x+1, y+1)
      Kite_sp(3, x+2, y+1)
    Next
  Next
EndProcedure

Procedure KiteDither(*param.parametre)
  dither(@KiteDither_MT(), "KiteDither")
EndProcedure

;------------------------

Macro FL_sp(mul, xx, yy)
  If xx >= 0 And xx < lg And yy >= 0 And yy < ht
    *dstPixel = *cible + ((yy * lg + xx) << 2)
    getrgb(*dstPixel\l, r, g, b)
    r + (errR * mul) / 2
    g + (errG * mul) / 2
    b + (errB * mul) / 2
    clamp_RGB(r, g, b)
    *dstPixel\l = a + (r << 16) | (g << 8) | b
  EndIf
EndMacro

Procedure FilterLiteDither_MT(*param.parametre)
  Protected *cible = *param\cible
  Protected lg = *param\lg, ht = *param\ht
  Protected x, y, i
  Protected oldR, oldG, oldB
  Protected newR, newG, newB
  Protected errR, errG, errB
  Protected a, r, g, b
  Protected *dstPixel.Pixel32
  Protected *ndc = *param\addr[2]

  For y = 0 To ht - 1
    For x = 0 To lg - 1
      i = y * lg + x
      *dstPixel = *cible + (i << 2)
      getargb(*dstPixel\l, a, oldR, oldG, oldB)

      ; Quantification via LUT
      newR = PeekA(*ndc + oldR)
      newG = PeekA(*ndc + oldG)
      newB = PeekA(*ndc + oldB)

      errR = oldR - newR
      errG = oldG - newG
      errB = oldB - newB

      a = a << 24
      *dstPixel\l = a + (newR << 16) | (newG << 8) | newB

      ; Diffusion minimaliste FilterLite
      FL_sp(1, x+1, y)   ; pixel de droite
      FL_sp(1, x,   y+1) ; pixel dessous
    Next
  Next
EndProcedure

Procedure LiteDither(*param.parametre)
  dither(@FilterLiteDither_MT(), "LiteDither")
EndProcedure




; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 796
; FirstLine = 763
; Folding = -------
; EnableXP
; DPIAware