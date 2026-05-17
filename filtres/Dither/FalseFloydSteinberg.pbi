; ------------------------------------------------------------------------------
; Procédure : FalseFloydSteinberg
; Description :
;    Applique un filtre de dithering False Floyd-Steinberg sur une image.
;    Version simplifiée du Floyd-Steinberg qui diffuse l'erreur sur 3 pixels
;    au lieu de 4, ce qui est plus rapide mais légèrement moins précis.
;    Matrice de diffusion :
;        X   3/8
;   1/8  2/8
; ------------------------------------------------------------------------------

; Macro de diffusion d'erreur vers un pixel spécifique (couleur)
; mul  = coefficient de diffusion (1, 2 ou 3 pour division par 8)
; offset = décalage relatif par rapport au pixel courant
Macro FalseFloydSteinberg_diffuse(mul, offset)
  *dstPixel.Pixel32 = *FilterCtx\addr[1] + (currentPos + offset) << 2
  getrgb(*dstPixel\l, r, g, b)
  r + (errR * mul) >> 3
  g + (errG * mul) >> 3
  b + (errB * mul) >> 3
  clamp_RGB(r, g, b)
  *dstPixel\l = alphaValue | (r << 16) | (g << 8) | b
EndMacro

; Macro de diffusion d'erreur vers un pixel spécifique (noir et blanc)
Macro FalseFloydSteinberg_diffuse_gray(mul, offset)
  *dstPixel.Pixel32 = *FilterCtx\addr[1] + (currentPos + offset) << 2
  getargb(*dstPixel\l, a, r, g, b)
  ; Conversion en niveau de gris
  g = (r * 77 + g * 150 + b * 29) >> 8
  ; Application de l'erreur
  g + (errG * mul) >> 3
  clamp(g, 0, 255)
  ; Reconstruction du pixel en niveaux de gris
  *dstPixel\l = (a << 24) | g * $10101
EndMacro

Procedure FalseFloydSteinberg_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]                ; Largeur de l'image
    Protected ht = \image_ht[1]                ; Hauteur de l'image
    Protected i, x, y, currentPos
    Protected oldR, oldG, oldB               ; Valeurs RGB originales
    Protected newR, newG, newB               ; Valeurs RGB quantifiées
    Protected errR, errG, errB               ; Erreur entre original et quantifié
    Protected a, r, g, b                     ; Couleurs et alpha pour traitement
    Protected alphaValue                     ; Alpha sauvegardé
    Protected *dstPixel.Pixel32
    
    Protected var
    Protected levels = \option[0]
    Protected gray = \option[1]
    
    ; Validation du nombre de niveaux
    clamp(levels, 2, 64)
    
    ; Table de quantification précalculée
    Protected *ndc = AllocateMemory(256)
    If Not *ndc
      ProcedureReturn
    EndIf
    
    Protected Steping.f = 255.0 / (levels - 1)
    Protected reciprocal.f = 1.0 / Steping
    
    For i = 0 To 255
      var = Round(i * reciprocal, #PB_Round_Nearest)
      var = var * Steping
      clamp(var, 0, 255)
      PokeA(*ndc + i, var)
    Next
    
    macro_calul_tread((ht - 1))
    
    ; Calcule les lignes à traiter pour ce thread
    Protected startPos = thread_start
    Protected endPos = thread_stop - 1
    
    ; Sécurité : ne pas dépasser les bords
    If startPos < 0 : startPos = 0 : EndIf
    If endPos >= ht - 1 : endPos = ht - 2 : EndIf
    
    ; Parcours ligne par ligne, pixel par pixel (sauf bords)
    For y = startPos To endPos
      For x = 1 To lg - 2
        ; Position linéaire du pixel
        currentPos = y * lg + x
        *dstPixel = \addr[1] + currentPos << 2
        
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
          
          ; Diffusion de l'erreur vers les 3 voisins selon False Floyd-Steinberg
          ; Les coefficients sont : droite=3/8, bas-gauche=1/8, bas=2/8
          FalseFloydSteinberg_diffuse(3, 1)              ; Droite (x+1, y) = 3/8
          FalseFloydSteinberg_diffuse(1, (lg - 1))           ; Bas-gauche (x-1, y+1) = 1/8
          FalseFloydSteinberg_diffuse(2, lg)               ; Bas (x, y+1) = 2/8
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
          
          ; Diffusion de l'erreur vers les 3 voisins
          FalseFloydSteinberg_diffuse_gray(3, 1)              ; Droite (x+1, y) = 3/8
          FalseFloydSteinberg_diffuse_gray(1, (lg - 1))           ; Bas-gauche (x-1, y+1) = 1/8
          FalseFloydSteinberg_diffuse_gray(2, lg)               ; Bas (x, y+1) = 2/8
        EndIf
      Next
    Next
    
    ; Libération de la table de quantification
    FreeMemory(*ndc)
  EndWith
EndProcedure

Procedure FalseFloydSteinbergEx(*FilterCtx.FilterParams)
  Restore FalseFloydSteinberg_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Lancement du filtre (1 thread car False Floyd-Steinberg nécessite un ordre séquentiel)
    Create_MultiThread_MT(@FalseFloydSteinberg_MT(), 1)
    
    mask_update(*FilterCtx.FilterParams , last_data)
  EndWith
EndProcedure

Procedure FalseFloydSteinberg(source , cible , mask , levels , gray)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = levels
    \option[1] = gray
  EndWith
  FalseFloydSteinbergEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  FalseFloydSteinberg_data:
  Data.s "FalseFloydSteinberg"
  Data.s "Dithering False Floyd-Steinberg (3 pixels, plus rapide)"
  Data.i #FilterType_Dithering
  Data.i #Dither_ErrorDiffusion
  
  Data.s "Nb de niveaux"       
  Data.i 2,64,6
  Data.s "Noir et blanc"   
  Data.i 0,1,0
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 26
; FirstLine = 6
; Folding = -
; EnableXP
; DPIAware