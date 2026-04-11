; =============================================================================
; FILTRE MORPHOLOGIQUE "DILATE" POUR IMAGE ARGB 32 BITS
; =============================================================================
; Ce filtre applique une dilatation morphologique avec un noyau variable (3x3 à 11x11).
; La dilatation étend les zones claires en prenant les valeurs maximales
; des pixels voisins pour chaque canal (R, G, B, A).
; Optimisé pour traitement multithread.
; =============================================================================

; -----------------------------------------------------------------------------
; PROCÉDURE PRINCIPALE : DilateEffect_MT
; Applique la dilatation morphologique sur un segment d'image
; PARAMÈTRES :
;   - *p.parametre : Pointeur vers structure de paramètres contenant :
;       * addr[0] : Adresse du buffer source
;       * addr[1] : Adresse du buffer destination
;       * lg, ht : Largeur et hauteur de l'image
;       * option[0] : Taille du noyau (0=3x3, 1=5x5, 2=7x7, 3=9x9, 4=11x11)
;       * thread_pos, thread_max : Position et nombre total de threads
; ALGORITHME :
;   Pour chaque pixel, analyse les voisins dans le noyau (rayon variable)
;   et conserve la valeur maximale pour chaque canal ARGB
; -----------------------------------------------------------------------------
Procedure DilateEffect_MT(*p.parametre)
  Protected *src = *p\addr[0]
  Protected *dst = *p\addr[1]
  Protected lg = *p\lg
  Protected ht = *p\ht
  
  ; Calcul de la plage de lignes à traiter par ce thread
  Protected startY = (*p\thread_pos * ht) / *p\thread_max
  Protected stopY  = ((*p\thread_pos + 1) * ht) / *p\thread_max - 1
  
  ; Sécurité : ne pas dépasser la dernière ligne
  If stopY > ht - 1 : stopY = ht - 1 : EndIf
  
  ; Calcul du rayon du noyau basé sur option[0]
  ; option[0] : 0->1 (3x3), 1->2 (5x5), 2->3 (7x7), 3->4 (9x9), 4->5 (11x11)
  Protected radius = *p\option[0]
  clamp(radius , 0 , 4)
  radius = (*p\option[0] * 2) + 1
  
  Protected x, y, nx, ny
  Protected srcOffset, dstOffset
  Protected maxR, maxG, maxB, maxA
  Protected r, g, b, a
  Protected pix
  
  ; Précalcul des limites pour éviter les tests répétés
  Protected minY, maxY, minX, maxX
  Protected htMinus1 = ht - 1
  Protected lgMinus1 = lg - 1
  
  ; Parcours de chaque ligne assignée à ce thread
  For y = startY To stopY
    ; Calcul des limites Y du noyau (une seule fois par ligne)
    minY = y - radius
    maxY = y + radius
    If minY < 0 : minY = 0 : EndIf
    If maxY > htMinus1 : maxY = htMinus1 : EndIf
    
    For x = 0 To lgMinus1
      ; Calcul des limites X du noyau
      minX = x - radius
      maxX = x + radius
      If minX < 0 : minX = 0 : EndIf
      If maxX > lgMinus1 : maxX = lgMinus1 : EndIf
      
      ; Initialisation des valeurs maximales à 0
      maxR = 0
      maxG = 0
      maxB = 0
      maxA = 0
      
      ; -----------------------------------------------------------------------
      ; PARCOURS DU NOYAU CENTRÉ SUR LE PIXEL (x, y)
      ; Optimisé : limites précalculées, pas de test Continue
      ; -----------------------------------------------------------------------
      For ny = minY To maxY
        srcOffset = ny * lg  ; Précalcul de l'offset de ligne
        
        For nx = minX To maxX
          ; Lecture du pixel voisin (calcul d'offset optimisé)
          pix = PeekL(*src + ((srcOffset + nx) << 2))
          getargb(pix, a, r, g, b)
          
          ; Recherche des valeurs maximales pour chaque canal
          If r > maxR : maxR = r : EndIf
          If g > maxG : maxG = g : EndIf
          If b > maxB : maxB = b : EndIf
          If a > maxA : maxA = a : EndIf
        Next
      Next
      
      ; Écriture du pixel résultant avec les valeurs maximales trouvées
      dstOffset = (y * lg + x) << 2
      PokeL(*dst + dstOffset, (maxA << 24) | (maxR << 16) | (maxG << 8) | maxB)
    Next
  Next
EndProcedure

; -----------------------------------------------------------------------------
; FONCTION PRINCIPALE : Dilate
; Point d'entrée du filtre de dilatation morphologique
; PARAMÈTRES :
;   - *param.parametre : Structure de paramètres du filtre
; MODE INFO : Retourne les métadonnées du filtre
; MODE TRAITEMENT : Lance le traitement multithread
; -----------------------------------------------------------------------------
Procedure Dilate(*param.parametre)
  ; Mode information : retourne les paramètres du filtre
  If *param\info_active
    *param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Other
    *param\name = "Dilate"
    *param\remarque = "Dilatation morphologique - Étend les zones claires"
    
    ; Paramètre 0 : Taille du noyau (0=3x3 à 4=11x11)
    *param\info[0] = "Taille noyau (3x3 à 11x11)"
    *param\info_data(0, 0) = 0  ; Min
    *param\info_data(0, 1) = 4  ; Max
    *param\info_data(0, 2) = 0  ; Défaut (3x3)
    
    ; Paramètre 1 : Masque
    *param\info[1] = "Masque"
    *param\info_data(1, 0) = 0
    *param\info_data(1, 1) = 2
    *param\info_data(1, 2) = 0
    
    ProcedureReturn
  EndIf
  
  ; Mode traitement : lance le filtre avec 1 passe et 1 buffer temporaire
  filter_start(@DilateEffect_MT(), 1, 1)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 113
; FirstLine = 64
; Folding = -
; EnableXP
; DPIAware