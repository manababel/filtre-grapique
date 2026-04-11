

; Procédure thread pour saturation
Procedure Saturation_MT(*p.parametre)
  Protected i, a.l ,r.l, g.l, b.l , gray
  ; Récupération du facteur de saturation fourni (0-255), 128 = neutre
  Protected intensity.i = *p\option[0]
  clamp( intensity , 0 , 255)
  ; Calcul de l'intensité inversée pour interpoler vers le gris
  Protected invIntensity.i = 256 - intensity  ; Complément : interpolation vers le gris
  Protected *srcPixel.Pixel32 ; Pointeur sur pixel source (ARGB)
  Protected *dstPixel.Pixel32 ; Pointeur sur pixel destination
  Protected totalPixels = *p\lg * *p\ht ; Nombre total de pixels à traiter
  ; Définition de la plage de pixels à traiter par ce thread (division équitable)
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  ; Boucle sur chaque pixel de la zone assignée à ce thread
  For i = startPos To endPos - 1
    *srcPixel = *p\source + (i << 2) ; Accès à l'adresse du pixel source (taille = 4 octets)
    *dstPixel = *p\cible + (i << 2)  ; Accès à l'adresse du pixel cible
    ; Décomposition ARGB du pixel source
    getargb(*srcPixel\l, a, r, g, b)
    ; Calcul de la luminance (gris) à partir des composantes RGB (pondération perceptuelle)
    gray = (r * 77 + g * 151 + b * 28) >> 8
    ; Interpolation entre couleur d’origine et gris selon l’intensité
    r = (r * intensity + gray * invIntensity) >> 8
    g = (g * intensity + gray * invIntensity) >> 8
    b = (b * intensity + gray * invIntensity) >> 8
    ; Clamp des valeurs RGB dans la plage 0–255 (fonction externe/macro)
    Clamp_RGB(r, g, b)
    ; Reconstruction du pixel final en ARGB et écriture dans l’image destination
    *dstPixel\l = (a << 24) + (r << 16) + (g << 8) + b
  Next
EndProcedure

; === Appel principal ===
Procedure Saturation(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorAdjustment
    param\name = "Saturation"
    param\remarque = ""
    param\info[0] = "saturation"
    param\info[1] = "Masque"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 512 : param\info_data(0,2) = 255
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf 
  filter_start(@Saturation_MT(), 3, 1)
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 44
; Folding = -
; EnableXP
; DPIAware