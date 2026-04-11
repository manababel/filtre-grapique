; ────────────────────────────────────────────────────────────────
; Procédure thread pour appliquer un effet "Hollow" ou "Ledge" sur une image ARGB 32 bits
;
; L'effet consiste à transformer chaque canal couleur via une fonction sinus,
; paramétrée par un angle donné (option[0], 0–360°) et un mode (option[1]) :
; - hollow = 1 : effet "creux" inversé
; - hollow = 0 : effet "bord" classique
;
; LUT (Look-Up Table) calculée une fois par thread pour optimiser la vitesse.
;
; Le masque alpha peut être appliqué en post-traitement (_mask).
; ────────────────────────────────────────────────────────────────
Procedure Hollow_MT(*p.parametre)
  Protected i, a, r, g, b, var
  Protected totalPixels = *p\lg * *p\ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32

  ; Détermination des plages de pixels à traiter selon le thread courant
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  
    *srcPixel = *p\addr[0] + (startPos << 2)  ; Adresse du pixel source (ARGB 32 bits)
    *dstPixel = *p\addr[1] + (startPos << 2)   ; Adresse du pixel destination
  ; Application de la transformation sur chaque pixel dans la plage du thread
  For i = startPos To endPos - 1
    var = *srcPixel\l                 ; Lecture de la couleur source
    getargb(var, a , r, g, b)              ; Extraction des composantes R, G, B
    ; Application de la LUT sur chaque canal couleur
    r = PeekA(*p\addr[2] + r)
    g = PeekA(*p\addr[2] + g)
    b = PeekA(*p\addr[2] + b)
    ; Reconstruction du pixel modifié dans la cible (alpha inchangé ici)
    *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    *srcPixel + 4
    *dstPixel + 4
  Next

EndProcedure


Procedure Hollow(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorEffect
    param\name = "Hollow"
    param\remarque = ""
    param\info[0] = "angle"
    param\info[1] = "Hollow/Ledge"
    param\info[2] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 360 : param\info_data(0,2) = 180
    param\info_data(1,1) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0
    param\info_data(2,1) = 0 : param\info_data(2,1) = 2  : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  
  Protected opt = *param\option[0]            ; Angle en degrés (0–360)
  Protected i , v.f, v1.f                     ; Variables flottantes pour calcul sinusoïdal

  ; Clamp de l'angle pour rester dans la plage valide
  clamp(opt, 0, 360)
  ; Conversion de l'angle en radians pour le calcul trigonométrique
  v = opt / 255.0 * #PI / 180.0
  ; Génération de la table de correspondance (LUT) pour la transformation des canaux couleur
  *param\addr[2] = AllocateMemory(256)
  For i = 0 To 255
    If Not *param\option[1]
      ; Mode hollow : fonction sinus inversée
      v1 = 255 * (1 - Sin(i * v))
    Else
      ; Mode ledge : fonction sinus classique
      v1 = 255 * (Sin(i * v))
    EndIf
    clamp(v1, 0, 255)
    PokeA(*param\addr[2] + i ,  v1)
  Next
  
  filter_start(@Hollow_MT(), 2, 1)
  FreeMemory(*param\addr[2]) 
EndProcedure


; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 65
; FirstLine = 11
; Folding = -
; EnableXP
; DPIAware