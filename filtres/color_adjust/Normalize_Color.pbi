; -----------------------------------------------------------------------------
; Procedure Normalize_Color
; -------------------------
; Effectue la normalisation des couleurs sur une portion d'image
; en fonction des indices thread_pos et thread_max (gestion multi-thread)
;
; Paramètres (dans *p) :
; - source : pointeur vers le buffer source ARGB 32 bits
; - cible  : pointeur vers le buffer cible ARGB 32 bits
; - lg     : largeur image
; - ht     : hauteur image
; - thread_pos : index du thread courant
; - thread_max : nombre total de threads
; -----------------------------------------------------------------------------
Procedure Normalize_Color_MT(*p.parametre)
  Protected start, stop, i
  Protected var.l
  Protected r, g, b
  Protected rmin = 255, gmin = 255, bmin = 255
  Protected rmax = 0, gmax = 0, bmax = 0
  Protected rangeR, rangeG, rangeB
  Protected pixelCount = *p\lg * *p\ht
  Protected *source = *p\source
  Protected *cible = *p\cible

  ; Délimitation de la portion à traiter selon thread
  start = ( *p\thread_pos * pixelCount ) / *p\thread_max
  stop  = ( (*p\thread_pos + 1) * pixelCount ) / *p\thread_max - 1

  ; --- Recherche des min/max par canal sur la portion ---
  For i = start To stop
    var = PeekL(*source + i * 4)
    getrgb(var, r, g, b)

    If r < rmin : rmin = r : EndIf
    If g < gmin : gmin = g : EndIf
    If b < bmin : bmin = b : EndIf

    If r > rmax : rmax = r : EndIf
    If g > gmax : gmax = g : EndIf
    If b > bmax : bmax = b : EndIf
  Next

  ; Synchronisation entre threads (à implémenter si multi-thread complet)

  ; Calcul des plages, protection division zéro
  rangeR = rmax - rmin
  rangeG = gmax - gmin
  rangeB = bmax - bmin
  If rangeR = 0 : rangeR = 1 : EndIf
  If rangeG = 0 : rangeG = 1 : EndIf
  If rangeB = 0 : rangeB = 1 : EndIf

  ; --- Normalisation des pixels ---
  For i = start To stop
    var = PeekL(*source + i * 4)
    getrgb(var, r, g, b)

    r = ((r - rmin) * 255) / rangeR
    g = ((g - gmin) * 255) / rangeG
    b = ((b - bmin) * 255) / rangeB

    Clamp_rgb(r, g, b)

    PokeL(*cible + i * 4, (var & $FF000000) | (r << 16) | (g << 8) | b)
  Next
EndProcedure


; -----------------------------------------------------------------------------
; Procedure Normalize_Color_Filter
; -------------------------------
; Wrapper filtre compatible avec système de paramètres multi-thread
; -----------------------------------------------------------------------------
Procedure Normalize_Color(*param.parametre)
  If param\info_active
    param\typ = #FilterType_ColorAdjustment
    param\name = "Normalize_Color"
    param\remarque = ""
    param\info[0] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 1 : param\info_data(0,2) = 0
    ProcedureReturn
  EndIf

  filter_start(@Normalize_Color_MT(), 0, 1)
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 84
; FirstLine = 25
; Folding = -
; EnableXP
; DPIAware