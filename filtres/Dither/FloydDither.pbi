; ------------------------------------------------------------------------------
; Procédure : FloydDither
; Description :
;   Applique un filtre de dithering de Floyd-Steinberg sur une image.
;   Ce filtre réduit le nombre de couleurs en conservant un rendu visuel
;   agréable grâce à une diffusion de l'erreur de quantification vers les pixels voisins.
; ------------------------------------------------------------------------------

; Macro de diffusion d'erreur vers un pixel spécifique (couleur)
; mul  = coefficient de diffusion (1, 3, 5 ou 7)
; offset = décalage relatif par rapport au pixel courant
Macro FloydDither_diffuse(mul, offset)
  *dstPixel.Pixel32 = *param\addr[1] + (currentPos + offset) << 2
  getrgb(*dstPixel\l, r, g, b)
  r + (errR * mul) >> 4
  g + (errG * mul) >> 4
  b + (errB * mul) >> 4
  clamp_RGB(r, g, b)
  *dstPixel\l = alphaValue | (r << 16) | (g << 8) | b
EndMacro

; Macro de diffusion d'erreur vers un pixel spécifique (noir et blanc)
Macro FloydDither_diffuse_gray(mul, offset)
  *dstPixel.Pixel32 = *param\addr[1] + (currentPos + offset) << 2
  getargb(*dstPixel\l, a, r, g, b)
  ; Conversion en niveau de gris
  g = (r * 77 + g * 150 + b * 29) >> 8
  ; Application de l'erreur
  g + (errG * mul) >> 4
  clamp(g, 0, 255)
  ; Reconstruction du pixel en niveaux de gris
  *dstPixel\l = (a << 24) | g * $10101
EndMacro
  
Procedure FloydDither_MT(*param.parametre)
  Protected lg = *param\lg                ; Largeur de l'image
  Protected ht = *param\ht                ; Hauteur de l'image
  Protected i, x, y, currentPos
  Protected oldR, oldG, oldB              ; Valeurs RGB originales
  Protected newR, newG, newB              ; Valeurs RGB quantifiées
  Protected errR, errG, errB              ; Erreur entre original et quantifié
  Protected a, r, g, b                    ; Couleurs et alpha pour traitement
  Protected alphaValue                    ; Alpha sauvegardé
  Protected *dstPixel.Pixel32
  
  Protected var
  Protected levels = *param\option[0]
  Protected gray = *param\option[1]
  
  ; Validation du nombre de niveaux
  clamp(levels, 2, 64)
  
  ; Table de quantification précalculée
  Protected *ndc = AllocateMemory(256)
  If Not *ndc : ProcedureReturn : EndIf
  
  Protected Steping.f = 255.0 / (levels - 1)
  Protected reciprocal.f = 1.0 / Steping
  
  For i = 0 To 255
    var = Round(i * reciprocal, #PB_Round_Nearest)
    var = var * Steping
    clamp(var, 0, 255)
    PokeA(*ndc + i, var)
  Next
  
  ; Calcule les lignes à traiter pour ce thread
  Protected startPos = (*param\thread_pos * (ht - 1)) / *param\thread_max
  Protected endPos = ((*param\thread_pos + 1) * (ht - 1)) / *param\thread_max - 1
  
  ; Sécurité : ne pas dépasser les bords
  If startPos < 0 : startPos = 0 : EndIf
  If endPos >= ht - 1 : endPos = ht - 2 : EndIf
  
  ; Parcours ligne par ligne, pixel par pixel (sauf bords)
  For y = startPos To endPos
    For x = 1 To lg - 2
      ; Position linéaire du pixel
      currentPos = y * lg + x
      *dstPixel = *param\addr[1] + currentPos << 2
      
      ; Lecture ARGB du pixel
      getargb(*dstPixel\l, a, oldR, oldG, oldB)
      
      ; Conservation de l'alpha
      alphaValue = a << 24
      
      If Not gray
        ; === MODE COULEUR ===
        ; Quantification RGB à l'aide de la table précalculée
        newR = PeekA(*ndc + oldR)
        newG = PeekA(*ndc + oldG)
        newB = PeekA(*ndc + oldB)
        
        ; Calcul de l'erreur de quantification
        errR = oldR - newR
        errG = oldG - newG
        errB = oldB - newB
        
        ; Mise à jour du pixel courant avec valeur quantifiée
        *dstPixel\l = alphaValue | (newR << 16) | (newG << 8) | newB
        
        ; Diffusion de l'erreur vers les 4 voisins selon Floyd-Steinberg
        ; Les coefficients sont : droite=7/16, bas-gauche=3/16, bas=5/16, bas-droite=1/16
        FloydDither_diffuse(7, 1)              ; Droite (x+1, y)
        FloydDither_diffuse(3, lg - 1)         ; Bas-gauche (x-1, y+1)
        FloydDither_diffuse(5, lg)             ; Bas (x, y+1)
        FloydDither_diffuse(1, lg + 1)         ; Bas-droite (x+1, y+1)
      Else
        ; === MODE NOIR ET BLANC ===
        ; Conversion en niveau de gris (formule ITU-R BT.601)
        g = (oldR * 77 + oldG * 150 + oldB * 29) >> 8
        
        ; Quantification du niveau de gris
        newG = PeekA(*ndc + g)
        
        ; Calcul de l'erreur de quantification
        errG = g - newG
        
        ; Mise à jour du pixel courant en niveaux de gris
        *dstPixel\l = alphaValue | newG * $10101
        
        ; Diffusion de l'erreur vers les 4 voisins
        FloydDither_diffuse_gray(7, 1)              ; Droite (x+1, y)
        FloydDither_diffuse_gray(3, lg - 1)         ; Bas-gauche (x-1, y+1)
        FloydDither_diffuse_gray(5, lg)             ; Bas (x, y+1)
        FloydDither_diffuse_gray(1, lg + 1)         ; Bas-droite (x+1, y+1)
      EndIf
    Next
  Next
  
  ; Libération de la table de quantification
  FreeMemory(*ndc)
EndProcedure

Procedure FloydDither(*param.parametre)
  ; Affichage des informations de configuration si demandé
  If *param\info_active
    *param\typ = #FilterType_Dithering
    *param\subtype = #Dither_ErrorDiffusion
    *param\name = "FloydDither"
    *param\remarque = "Filtre de dithering Floyd-Steinberg (séquentiel)"
    *param\info[0] = "Nb de niveaux"
    *param\info[1] = "Noir et blanc"
    *param\info[2] = "Masque"
    *param\info_data(0, 0) = 2   : *param\info_data(0, 1) = 64  : *param\info_data(0, 2) = 6
    *param\info_data(1, 0) = 0   : *param\info_data(1, 1) = 1   : *param\info_data(1, 2) = 0
    *param\info_data(2, 0) = 0   : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Lancement du filtre (1 thread car Floyd-Steinberg nécessite un ordre séquentiel)
  filter_start(@FloydDither_MT(), 2, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 139
; FirstLine = 93
; Folding = -
; EnableXP
; DPIAware
; Compiler = PureBasic 6.21 - C Backend (Windows - x64)