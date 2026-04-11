; ============================================================================
; FILTRE PENCIL (EFFET CRAYON/DESSIN)
; ============================================================================
; Ce filtre transforme une image en dessin au crayon avec plusieurs styles
; Technique : Sobel multi-directionnel + Color Dodge + flou gaussien

; ============================================================================
; MACROS POUR LE FLOU IIR (Infinite Impulse Response)
; ============================================================================
; Le flou IIR est une technique rapide de flou gaussien approximatif

Macro pencil_Blur_IIR_int(var)
  ; --- Déclaration des variables communes ---
  Protected *pix32.pixel32
  Protected *dst32.pixel32 = *param\addr[0]
  Protected lg       = *param\lg
  Protected ht       = *param\ht
  
  ; --- Calcul du coefficient alpha (contrôle l'intensité du flou) ---
  ; Formule : alpha = exp(-2.3 / rayon) × 256
  Protected alpha    = Int(Exp(-2.3 / *param\option[0]) * 256 + 0.5)
  Protected inv_alpha= 256 - alpha
  
  ; --- Variables de travail ---
  Protected x, y, pos, mem
  Protected r, g, b      ; Accumulateurs RGB
  Protected r1, g1, b1   ; Valeurs temporaires RGB
  
  ; --- Gestion multithreading ---
  Protected start = (*param\thread_pos * var) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * var) / *param\thread_max
  If start < 0 : start = 0 : EndIf
  If stop  > var : stop = var : EndIf
EndMacro

Macro pencil_Blur_IIR_sp0(r, g, b)
  ; Lecture d'un pixel et conversion en 16 bits pour précision
  *pix32 = *dst32 + (pos << 2)  ; Optimisation : pos * 4 → pos << 2
  getrgb(*pix32\l, r, g, b) 
  r << 8  ; Multiplication par 256 pour précision fixe
  g << 8
  b << 8
EndMacro

Macro pencil_Blur_IIR_sp1()
  ; Application du filtre IIR récursif
  pencil_Blur_IIR_sp0(r1, g1, b1)
  
  ; Formule IIR : nouveau = ancien × alpha + actuel × (1-alpha)
  r = (r * alpha + inv_alpha * r1) >> 8 
  g = (g * alpha + inv_alpha * g1) >> 8
  b = (b * alpha + inv_alpha * b1) >> 8
  
  ; Conversion vers 8 bits avec arrondi
  r1 = (r + 128) >> 8
  g1 = (g + 128) >> 8
  b1 = (b + 128) >> 8
  
  ; Écriture du résultat
  *pix32\l = (r1 << 16) | (g1 << 8) | b1
EndMacro

; ============================================================================
; FLOU IIR VERTICAL (HAUT-BAS puis BAS-HAUT)
; ============================================================================
Procedure pencil_Blur_IIR_y_MT(*param.parametre)
  pencil_Blur_IIR_int(*param\ht)
  
  For y = start To stop - 1
    pos = y * lg
    mem = pos 
    
    ; --- Passe gauche → droite ---
    pencil_Blur_IIR_sp0(r, g, b)
    For x = 1 To lg - 1
      pos = mem + x
      pencil_Blur_IIR_sp1()
    Next
    
    ; --- Passe droite → gauche (pour symétrie) ---
    pos = mem + (lg - 1)
    pencil_Blur_IIR_sp0(r, g, b)
    For x = lg - 2 To 0 Step -1
      pos = y * lg + x
      pencil_Blur_IIR_sp1()
    Next
  Next
EndProcedure

; ============================================================================
; FLOU IIR HORIZONTAL (GAUCHE-DROITE puis DROITE-GAUCHE)
; ============================================================================
Procedure pencil_Blur_IIR_x_MT(*param.parametre)
  pencil_Blur_IIR_int(*param\lg)
  
  For x = start To stop - 1
    ; --- Passe haut → bas ---
    pos = x 
    pencil_Blur_IIR_sp0(r, g, b)
    For y = 1 To ht - 1
      pos = y * lg + x
      pencil_Blur_IIR_sp1()
    Next
    
    ; --- Passe bas → haut (pour symétrie) ---
    pos = (ht - 1) * lg + x 
    pencil_Blur_IIR_sp0(r, g, b)
    For y = ht - 2 To 0 Step -1
      pos = y * lg + x
      pencil_Blur_IIR_sp1()
    Next
  Next
EndProcedure

; ============================================================================
; CRÉATION DES TABLES DE LIMITES POUR BLUR BOX
; ============================================================================
; Pré-calcule les indices pour gérer les bordures d'image
; Mode clamp : répétition des pixels de bord

Procedure pencil_blur_box_create_limit(lg, ht, rx, ry, boucle)
  Protected i, ii, e
  Protected dx = lg - 1
  Protected dy = ht - 1
  
  ; === Limitation des rayons aux dimensions de l'image ===
  If rx > dx : rx = dx : EndIf
  If ry > dy : ry = dy : EndIf
  
  Protected nrx = rx + 1
  Protected nry = ry + 1
  Protected sizeX = (lg + 2 * nrx) << 2
  Protected sizeY = (ht + 2 * nry) << 2
  
  ; === Allocation d'un seul bloc mémoire pour les deux tables ===
  Global *blur_box_limit = AllocateMemory(sizeX + sizeY)
  If *blur_box_limit = 0 : ProcedureReturn 0 : EndIf
  
  Global *blur_box_limit_x = *blur_box_limit
  Global *blur_box_limit_y = *blur_box_limit + sizeX
  
  ; === Remplissage des tables d'indices ===
  If boucle
    ; Mode wrap (bouclage torique) - RAREMENT UTILISÉ
    e = dx - nrx / 2
    For i = 0 To dx + 2 * nrx
      PokeL(*blur_box_limit_x + (i << 2), (i + e) % (dx + 1))
    Next
    
    e = dy - nry / 2
    For i = 0 To dy + 2 * nry
      PokeL(*blur_box_limit_y + (i << 2), (i + e) % (dy + 1))
    Next
  Else
    ; Mode clamp (répétition des bords) - RECOMMANDÉ
    For i = 0 To dx + 2 * nrx
      ii = i - 1 - nrx / 2
      If ii < 0 : ii = 0 : ElseIf ii > dx : ii = dx : EndIf
      PokeL(*blur_box_limit_x + (i << 2), ii)
    Next
    
    For i = 0 To dy + 2 * nry
      ii = i - 1 - nry / 2
      If ii < 0 : ii = 0 : ElseIf ii > dy : ii = dy : EndIf
      PokeL(*blur_box_limit_y + (i << 2), ii)
    Next
  EndIf
  
  ProcedureReturn 1
EndProcedure

; ============================================================================
; CRÉATION DES TABLES DE LIMITES POUR BLUR BOX
; ============================================================================
; Pré-calcule les indices pour gérer les bordures (wrapping ou clamping)

Procedure pencil_blur_box_Guillossien_create_limit(lg, ht, rx, ry, boucle)
  Protected i, ii, e
  Protected dx = lg - 1
  Protected dy = ht - 1
  
  ; --- Limitation des rayons ---
  If rx > dx : rx = dx : EndIf
  If ry > dy : ry = dy : EndIf
  
  Protected nrx = rx + 1
  Protected nry = ry + 1
  Protected sizeX = (lg + 2 * nrx) << 2  ; Optimisation : * 4 → << 2
  Protected sizeY = (ht + 2 * nry) << 2
  
  ; --- Allocation d'un seul bloc mémoire ---
  Global *blur_box_limit = AllocateMemory(sizeX + sizeY)
  If *blur_box_limit = 0 : ProcedureReturn 0 : EndIf
  
  Global *blur_box_limit_x = *blur_box_limit
  Global *blur_box_limit_y = *blur_box_limit + sizeX
  
  ; --- Remplissage des tables ---
  If boucle
    ; Mode wrap (bouclage torique)
    e = dx - nrx / 2
    For i = 0 To dx + 2 * nrx
      PokeL(*blur_box_limit_x + (i << 2), (i + e) % (dx + 1))  ; Optimisation : i * 4 → i << 2
    Next
    
    e = dy - nry / 2
    For i = 0 To dy + 2 * nry
      PokeL(*blur_box_limit_y + (i << 2), (i + e) % (dy + 1))
    Next
  Else
    ; Mode clamp (répétition des bords)
    For i = 0 To dx + 2 * nrx
      ii = i - 1 - nrx / 2
      If ii < 0 : ii = 0 : ElseIf ii > dx : ii = dx : EndIf
      PokeL(*blur_box_limit_x + (i << 2), ii)
    Next
    
    For i = 0 To dy + 2 * nry
      ii = i - 1 - nry / 2
      If ii < 0 : ii = 0 : ElseIf ii > dy : ii = dy : EndIf
      PokeL(*blur_box_limit_y + (i << 2), ii)
    Next
  EndIf
  
  ProcedureReturn 1
EndProcedure

; ============================================================================
; FLOU BOX GAUSSIEN (Algorithme de Guillossien)
; ============================================================================
; Implémentation optimisée du flou rectangulaire (box blur)
; Complexité : O(n) au lieu de O(n × rayon²)

Procedure pencil_Guillossien_MT(*param.parametre)
  ; --- Déclaration des pointeurs ---
  Protected *srcPixel1.Pixel32
  Protected *srcPixel2.Pixel32
  Protected *dstPixel.Pixel32
  
  ; --- Accumulateurs ARGB ---
  Protected ax1, rx1, gx1, bx1
  Protected a1.l, r1.l, b1.l, g1.l
  Protected a2.l, r2.l, b2.l, g2.l
  
  ; --- Variables d'index ---
  Protected j, i, p1, p2
  
  ; --- Paramètres de l'image ---
  Protected *cible = *param\cible
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected *tempo = *param\addr[0]
  Protected lx = *param\addr[1]
  Protected ly = *param\addr[2]
  
  ; --- Paramètres du filtre ---
  Protected nrx = *param\option[17]  ; Rayon X
  Protected nry = *param\option[18]  ; Rayon Y
  Protected div = *param\option[19]  ; Diviseur pré-calculé : 65536 / (nrx × nry)
  
  ; --- Gestion multithreading ---
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected startPos = (thread_pos * ht) / thread_max
  Protected endPos   = ((thread_pos + 1) * ht) / thread_max - 1
  
  ; --- Buffers pour sommes cumulatives par colonne ---
  Protected Dim a.l(lg)
  Protected Dim r.l(lg)
  Protected Dim g.l(lg)
  Protected Dim b.l(lg)
  
  ; --- Initialisation ---
  FillMemory(@a(), lg << 2, 0)  ; Optimisation : lg * 4 → lg << 2
  FillMemory(@r(), lg << 2, 0)
  FillMemory(@g(), lg << 2, 0)
  FillMemory(@b(), lg << 2, 0)
  
  ; ============================================================================
  ; ÉTAPE 1 : ACCUMULATION VERTICALE INITIALE
  ; ============================================================================
  ; Construit les sommes verticales pour les premières lignes
  
  For j = 0 To nry - 1
    p1 = PeekL(ly + ((j + startPos) << 2))
    *srcPixel1 = *cible + ((p1 * lg) << 2)
    
    For i = 0 To lg - 1
      getargb(*srcPixel1\l, a1, r1, g1, b1)
      a(i) + a1 : r(i) + r1 : g(i) + g1 : b(i) + b1
      *srcPixel1 + 4
    Next
  Next
  
  ; ============================================================================
  ; ÉTAPE 2 : TRAITEMENT LIGNE PAR LIGNE
  ; ============================================================================
  
  For j = startPos To endPos
    ; --- Mise à jour glissante des colonnes ---
    ; On retire la ligne supérieure et ajoute la nouvelle ligne inférieure
    
    p1 = PeekL(ly + ((nry + j) << 2))
    p2 = PeekL(ly + (j << 2))
    *srcPixel1 = *cible + ((p1 * lg) << 2)
    *srcPixel2 = *cible + ((p2 * lg) << 2)
    
    For i = 0 To lg - 1
      getargb(*srcPixel1\l, a1, r1, g1, b1)
      getargb(*srcPixel2\l, a2, r2, g2, b2)
      
      ; Somme glissante : ajoute nouveau - enlève ancien
      a(i) + a1 - a2
      r(i) + r1 - r2
      g(i) + g1 - g2
      b(i) + b1 - b2
      
      *srcPixel1 + 4
      *srcPixel2 + 4
    Next
    
    ; --- Application du filtre horizontal ---
    ax1 = 0 : rx1 = 0 : gx1 = 0 : bx1 = 0
    
    ; Accumulation initiale horizontale
    For i = 0 To nrx - 1
      p1 = PeekL(lx + (i << 2))
      ax1 + a(p1) : rx1 + r(p1) : gx1 + g(p1) : bx1 + b(p1)
    Next
    
    ; --- Balayage horizontal avec fenêtre glissante ---
    For i = 0 To lg - 1
      p1 = PeekL(lx + ((nrx + i) << 2))
      p2 = PeekL(lx + (i << 2))
      
      ; Fenêtre glissante horizontale
      ax1 + a(p1) - a(p2)
      rx1 + r(p1) - r(p2)
      gx1 + g(p1) - g(p2)
      bx1 + b(p1) - b(p2)
      
      ; --- Calcul final avec normalisation ---
      ; Division rapide par multiplication pré-calculée : (valeur × div) >> 16
      a1 = (ax1 * div) >> 16
      r1 = (rx1 * div) >> 16
      g1 = (gx1 * div) >> 16
      b1 = (bx1 * div) >> 16
      
      ; --- Écriture du pixel résultat ---
      *dstPixel = *tempo + ((j * lg + i) << 2)
      *dstPixel\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
    Next
  Next
  
  ; --- Libération des tableaux ---
  FreeArray(a())
  FreeArray(r())
  FreeArray(g())
  FreeArray(b())
EndProcedure

; ============================================================================
; MACRO POUR DÉTECTION DE CONTOURS SOBEL
; ============================================================================
; Lit 3 pixels consécutifs et calcule leur luminance

Macro pencil_sobel_4d_sp(i)
  ; Pixel 1
  getrgb(PeekL(pos + 0), r, g, b)
  p(i + 0) = ((r * 76 + g * 150 + b * 30) >> 8)  ; Formule ITU-R BT.601
  
  ; Pixel 2
  getrgb(PeekL(pos + 4), r, g, b)
  p(i + 1) = ((r * 76 + g * 150 + b * 30) >> 8)
  
  ; Pixel 3
  getrgb(PeekL(pos + 8), r, g, b)
  p(i + 2) = ((r * 76 + g * 150 + b * 30) >> 8)
EndMacro

; ============================================================================
; DÉTECTION DE CONTOURS SOBEL MULTI-DIRECTIONNEL
; ============================================================================
; Applique le filtre de Sobel dans 4 directions (0°, 45°, 90°, 135°)
; et garde la magnitude maximale pour une détection robuste

Procedure pencil_sobel_4d_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected mul.f = *param\option[3]
  Protected pos, f
  Protected r, g, b
  Protected c0, c45, c90, c135          ; Magnitudes des gradients
  Protected cx0, cx45, cx90, cx135      ; Composantes X
  Protected cy0, cy45, cy90, cy135      ; Composantes Y
  
  ; --- Normalisation de l'intensité ---
  clamp(mul, 0, 100)
  mul * 0.1
  
  Protected x, y
  Protected Dim p(8)  ; Matrice 3×3 = 9 pixels
  
  ; --- Gestion multithreading ---
  Protected startPos = (*param\thread_pos * (ht - 2)) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * (ht - 2)) / *param\thread_max
  If startPos < 1 : startPos = 1 : EndIf
  
  ; ============================================================================
  ; BOUCLE PRINCIPALE SUR TOUS LES PIXELS
  ; ============================================================================
  
  For y = startPos To endPos
    For x = 1 To lg - 2
      
      ; --- Lecture de la matrice 3×3 ---
      ; Layout :
      ; p(0) p(1) p(2)
      ; p(3) p(4) p(5)
      ; p(6) p(7) p(8)
      
      pos = *source + (((y - 1) * lg + (x - 1)) << 2)
      pencil_sobel_4d_sp(0)  ; Ligne supérieure
      
      pos = *source + ((y * lg + (x - 1)) << 2)
      pencil_sobel_4d_sp(3)  ; Ligne centrale
      
      pos = *source + (((y + 1) * lg + (x - 1)) << 2)
      pencil_sobel_4d_sp(6)  ; Ligne inférieure
      
      ; ============================================================================
      ; CALCUL DES GRADIENTS SOBEL DANS 4 DIRECTIONS
      ; ============================================================================
      
      ; --- Sobel 0° (horizontal) ---
      ; Noyau X : [-1  0  +1]    Noyau Y : [+1 +2 +1]
      ;           [-2  0  +2]              [ 0  0  0]
      ;           [-1  0  +1]              [-1 -2 -1]
      cx0 = p(2) + 2 * p(5) + p(8) - (p(0) + 2 * p(3) + p(6))
      cy0 = p(0) + 2 * p(1) + p(2) - (p(6) + 2 * p(7) + p(8))
      
      ; --- Sobel 45° (diagonal ↗) ---
      cx45 = p(0) + 2 * p(1) + p(2) - (p(6) + 2 * p(7) + p(8))
      cy45 = p(2) + 2 * p(5) + p(8) - (p(0) + 2 * p(3) + p(6))
      
      ; --- Sobel 90° (vertical) ---
      cx90 = p(6) + 2 * p(7) + p(8) - (p(0) + 2 * p(1) + p(2))
      cy90 = p(2) + 2 * p(5) + p(8) - (p(0) + 2 * p(3) + p(6))
      
      ; --- Sobel 135° (diagonal ↖) ---
      cx135 = p(6) + 2 * p(3) + p(0) - (p(8) + 2 * p(5) + p(2))
      cy135 = p(0) + 2 * p(3) + p(6) - (p(2) + 2 * p(5) + p(8))
      
      ; --- Calcul des magnitudes (norme euclidienne) ---
      c0   = Sqr(cx0   * cx0   + cy0   * cy0)
      c45  = Sqr(cx45  * cx45  + cy45  * cy45)
      c90  = Sqr(cx90  * cx90  + cy90  * cy90)
      c135 = Sqr(cx135 * cx135 + cy135 * cy135)
      
      ; --- Sélection du maximum ---
      max4(f, c0, c45, c90, c135)
      f * mul
      clamp(f, 0, 255)
      
      ; --- Inversion (blanc = pas de contour, noir = contour) ---
      PokeL(*cible + ((y * lg + x) << 2), (255 - f) * $010101)
      
    Next
  Next
  
  FreeArray(p())
EndProcedure

; ============================================================================
; COLOR DODGE (TECHNIQUE DE MÉLANGE)
; ============================================================================
; Formule : Résultat = Base / (1 - Blend)
; Crée un effet de dessin lumineux

Procedure pencil_color_dodge(*param.parametre)
  Protected *dodge = *param\addr[0]  ; Image de contours
  Protected *blur  = *param\addr[1]  ; Image floutée
  Protected *cible = *param\addr[2]  ; Image résultat
  Protected lg     = *param\lg
  Protected ht     = *param\ht
  Protected total  = lg * ht
  
  ; --- Paramètres ---
  Protected intensity = (*param\option[1] * 255) / 100
  Protected gamma.f   = *param\option[2] * 0.1
  
  ; --- Gestion multithreading ---
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  If stop > total : stop = total : EndIf
  
  Protected i, pos
  Protected r, g, b
  Protected r1, g1, b1  ; Contours
  Protected r2, g2, b2  ; Flou
  Protected r3, g3, b3  ; Inversé
  
  ; --- Pré-calcul de la LUT gamma ---
  Protected Dim GammaLUT(255)
  For i = 0 To 255
    GammaLUT(i) = Int(255.0 * Pow(i / 255.0, gamma))
    clamp(GammaLUT(i), 0, 255)
  Next
  
  ; ============================================================================
  ; BOUCLE PRINCIPALE : COLOR DODGE
  ; ============================================================================
  
  For i = start To stop - 1
    pos = i << 2
    
    ; --- Lecture des pixels ---
    getrgb(PeekL(*dodge + pos), r1, g1, b1)
    getrgb(PeekL(*blur  + pos), r2, g2, b2)
    
    ; --- Inversion du canal dodge ---
    r3 = 255 - r1 : If r3 < 1 : r3 = 1 : EndIf  ; Évite division par zéro
    g3 = 255 - g1 : If g3 < 1 : g3 = 1 : EndIf
    b3 = 255 - b1 : If b3 < 1 : b3 = 1 : EndIf
    
    ; --- Formule Color Dodge : (blur << 8) / (255 - dodge) ---
    r = (r2 << 8) / r3
    g = (g2 << 8) / g3
    b = (b2 << 8) / b3
    
    ; --- Application de l'intensité ---
    r = (r * intensity) >> 8
    g = (g * intensity) >> 8
    b = (b * intensity) >> 8
    
    clamp_rgb(r, g, b)
    
    ; --- Application de la correction gamma (via LUT) ---
    r = GammaLUT(r)
    g = GammaLUT(g)
    b = GammaLUT(b)
    
    ; --- Écriture du résultat ---
    PokeL(*cible + pos, (r << 16) | (g << 8) | b)
  Next
  
  FreeArray(GammaLUT())
EndProcedure

; ============================================================================
; CONVERSION EN NIVEAUX DE GRIS
; ============================================================================

Procedure pencil_gray_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg      = *param\lg
  Protected ht      = *param\ht
  Protected total   = lg * ht
  
  ; --- Gestion multithreading ---
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  If stop > total : stop = total : EndIf
  
  Protected i, lum, a, r, g, b
  
  ; --- Conversion RGB → Luminance (ITU-R BT.601) ---
  For i = start To stop - 1
    getargb(PeekL(*source + (i << 2)), a, r, g, b)
    lum = ((r * 76 + g * 150 + b * 30) >> 8)  ; 0.299R + 0.587G + 0.114B
    PokeL(*cible + (i << 2), lum * $010101)   ; R=G=B=lum
  Next
EndProcedure

Procedure pencil( *param.parametre )
  ; Mode interface : renseigner les informations sur les options si demandé
  
  If *param\info_active
    *param\typ = #FilterType_Artistic
    *param\subtype = #Artistic_Material
    *param\name = "Pencil (Crayon)"
    *param\remarque = "Effet dessin au crayon avec styles variés"
    
    ; --- Paramètre 0 : Rayon de flou initial ---
    *param\info[0] = "Rayon flou"
    *param\info_data(0, 0) = 1
    *param\info_data(0, 1) = 80
    *param\info_data(0, 2) = 3
    
    ; --- Paramètre 1 : Intensité du mélange ---
    *param\info[1] = "Intensité mélange"
    *param\info_data(1, 0) = 1
    *param\info_data(1, 1) = 100
    *param\info_data(1, 2) = 50  ; Correction : valeur par défaut plus équilibrée
    
    ; --- Paramètre 2 : Gamma (contraste) ---
    *param\info[2] = "Gamma"
    *param\info_data(2, 0) = 1
    *param\info_data(2, 1) = 100
    *param\info_data(2, 2) = 10
    
    ; --- Paramètre 3 : Intensité des contours ---
    *param\info[3] = "Intensité contours"
    *param\info_data(3, 0) = 1
    *param\info_data(3, 1) = 100
    *param\info_data(3, 2) = 10
    
    ; --- Paramètre 4 : Style de rendu ---
    *param\info[4] = "Style (0-9)"
    *param\info_data(4, 0) = 0
    *param\info_data(4, 1) = 9
    *param\info_data(4, 2) = 0
    
    ; --- Paramètre 5 : Masque binaire ---
    *param\info[5] = "Masque binaire"
    *param\info_data(5, 0) = 0
    *param\info_data(5, 1) = 1
    *param\info_data(5, 2) = 0
    
    ProcedureReturn
  EndIf
  
    ; ============================================================================
  ; MODE TRAITEMENT : INITIALISATION
  ; ============================================================================
  
  Protected i 
  Protected *source = *param\source
  Protected *cible = *param\cible
  Protected *mask = *param\mask
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  ; === Vérification des paramètres obligatoires ===
  If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf
  
  ; === Allocation des buffers de travail ===
  Protected *gray = AllocateMemory(lg * ht * 4)
  Protected *blur = AllocateMemory(lg * ht * 4)
  Protected *sobel = AllocateMemory(lg * ht * 4)
  Protected *tmp = AllocateMemory(lg * ht * 4)
  
  ; FIX : Vérification des allocations mémoire
  If *gray = 0 Or *blur = 0 Or *sobel = 0 Or *tmp = 0
    If *gray : FreeMemory(*gray) : EndIf
    If *blur : FreeMemory(*blur) : EndIf
    If *sobel : FreeMemory(*sobel) : EndIf
    If *tmp : FreeMemory(*tmp) : EndIf
    ProcedureReturn
  EndIf
  
  ; === Configuration multithreading ===
  Protected thread = CountCPUs(#PB_System_CPUs)
  clamp(thread, 1, 128)
  Protected Dim tr(thread)
  
  ; ============================================================================
  ; ÉTAPE 1 : CONVERSION EN NIVEAUX DE GRIS
  ; ============================================================================
  
  *param\addr[0] = *source
  *param\addr[1] = *gray
  MultiThread_MT(@pencil_gray_MT())
  
  ; ============================================================================
  ; ÉTAPE 2 : PRÉ-FILTRAGE OPTIONNEL (BLUR BOX 2 PASSES)
  ; ============================================================================
  ; Réduit le bruit avant la détection de contours
  
  If pencil_blur_box_create_limit(lg, ht, 3, 3, 0)
    Protected *tempo = AllocateMemory(lg * ht * 4)
    
    If *tempo  ; FIX : Vérification allocation
      ; Configuration des paramètres du blur box
      *param\addr[0] = *tempo
      *param\addr[1] = *blur_box_limit_x
      *param\addr[2] = *blur_box_limit_y
      *param\option[17] = 3
      *param\option[18] = 3
      *param\option[19] = Int(65536 / (3 * 3))  ; Facteur normalisation
      
      ; Deux passes de flou pour meilleur lissage
      Protected passe
      For passe = 1 To 2
        MultiThread_MT(@pencil_Guillossien_MT())
        CopyMemory(*tempo, *cible, lg * ht * 4)
      Next
      
      FreeMemory(*tempo)
    EndIf
    
    ; FIX : Libération de la mémoire des tables de limites
    If *blur_box_limit
      FreeMemory(*blur_box_limit)
      *blur_box_limit = 0
      *blur_box_limit_x = 0
      *blur_box_limit_y = 0
    EndIf
  EndIf
  
  ; ============================================================================
  ; ÉTAPE 3 : FLOU GAUSSIEN IIR (HORIZONTAL + VERTICAL)
  ; ============================================================================
  
  CopyMemory(*gray, *blur, lg * ht * 4)
  *param\addr[0] = *blur
  MultiThread_MT(@pencil_Blur_IIR_y_MT())  ; Passe horizontale
  MultiThread_MT(@pencil_Blur_IIR_x_MT())  ; Passe verticale
  
  ; ============================================================================
  ; ÉTAPE 4 : DÉTECTION DE CONTOURS SOBEL MULTI-DIRECTIONNEL
  ; ============================================================================
  
  *param\addr[0] = *blur
  *param\addr[1] = *sobel
  MultiThread_MT(@pencil_sobel_4d_MT())
  
  ; ============================================================================
  ; ÉTAPE 5 : APPLICATION DU STYLE SÉLECTIONNÉ
  ; ============================================================================
  
  Select *param\option[4]
    
    ; === STYLE 0 : Par défaut (Color Dodge classique) ===
    Case 0
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
    
    ; === STYLE 1 : Contour seul (Line Art) ===
    Case 1
      *param\addr[0] = *gray
      *param\addr[1] = *cible
      MultiThread_MT(@pencil_sobel_4d_MT())
    
    ; === STYLE 2 : Crayon sombre (inversé) ===
    Case 2
      ; FIX : Inversion des canaux pour effet sombre
      *param\addr[0] = *blur
      *param\addr[1] = *sobel
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
    
    ; === STYLE 3 : Crayon doux (moins de contours) ===
    Case 3
      ; FIX : Réduction de l'intensité des contours
      Protected old_intensity = *param\option[3]
      *param\option[3] = old_intensity / 2
      
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
      
      *param\option[3] = old_intensity  ; Restauration
    
    ; === STYLE 4 : Crayon esquissé (avec bruit léger) ===
    Case 4
      ; Ajout de bruit aléatoire pour effet esquisse
      For i = 0 To (lg * ht - 1)
        Protected val = PeekL(*blur + (i << 2)) & $FF  ; FIX : extraction canal R
        val + Random(10) - 5
        clamp(val, 0, 255)
        PokeL(*blur + (i << 2), val * $010101)
      Next
      
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
    
    ; === STYLE 5 : Charbon (Charcoal) ===
    Case 5
      ; Accentue les contours et obscurcit l'image
      For i = 0 To (lg * ht - 1)
        Protected v = PeekL(*sobel + (i << 2)) & $FF
        Protected blur_val = PeekL(*blur + (i << 2)) & $FF
        v = v + ((255 - blur_val) >> 1)
        clamp(v, 0, 255)
        PokeL(*sobel + (i << 2), v * $010101)
      Next
      
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
    
    ; === STYLE 6 : Estampe (High Contrast) ===
    Case 6
      ; Seuillage binaire pour effet estampe
      For i = 0 To (lg * ht - 1)
        v = PeekL(*sobel + (i << 2)) & $FF
        If v > 128
          PokeL(*sobel + (i << 2), $FFFFFF)
        Else
          PokeL(*sobel + (i << 2), $000000)
        EndIf
      Next
      
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
    
    ; === STYLE 7 : Peinture crayonnée ===
    Case 7
      ; Mélange niveaux de gris et flou (75% gray / 25% blur)
      For i = 0 To (lg * ht - 1)
        Protected v1 = PeekL(*gray + (i << 2)) & $FF
        Protected v2 = PeekL(*blur + (i << 2)) & $FF
        Protected mix = (v1 * 3 + v2) >> 2
        PokeL(*blur + (i << 2), mix * $010101)
      Next
      
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
    
    ; === STYLE 8 : Pastel doux ===
    Case 8
      ; Mélange inversé (25% gray / 75% blur) pour douceur
      For i = 0 To (lg * ht - 1)
        v1 = PeekL(*gray + (i << 2)) & $FF  ; FIX : ajout décalage
        v2 = PeekL(*blur + (i << 2)) & $FF  ; FIX : ajout décalage
        mix = (v1 + v2 * 3) >> 2
        PokeL(*blur + (i << 2), mix * $010101)
      Next
      
      *param\addr[0] = *sobel
      *param\addr[1] = *blur
      *param\addr[2] = *cible
      MultiThread_MT(@pencil_color_dodge())
    
    ; === STYLE 9 : Cartoon (Posterisation + Contours) ===
    Case 9
      ; Détection des contours sur image grise
      *param\addr[0] = *gray
      *param\addr[1] = *tmp
      MultiThread_MT(@pencil_sobel_4d_MT())
      
      ; Posterisation en 4 niveaux
      For i = 0 To (lg * ht - 1)
        Protected lum = PeekL(*gray + (i << 2)) & $FF
        Protected steps = 4
        Protected level = (lum * steps) / 256
        
        ; FIX : Protection contre division par zéro
        If steps > 1
          lum = (255 * level) / (steps - 1)
        Else
          lum = 255
        EndIf
        
        clamp(lum, 0, 255)
        PokeL(*gray + (i << 2), lum * $010101)
      Next
      
      ; Mélange image posterisée et contours
      For i = 0 To (lg * ht - 1)
        Protected edge = PeekL(*tmp + (i << 2)) & $FF
        Protected base = PeekL(*gray + (i << 2)) & $FF
        Protected final = base - (edge >> 1)
        clamp(final, 0, 255)
        PokeL(*cible + (i << 2), final * $010101)  ; FIX : i << 2 au lieu de i * 4
      Next
      
  EndSelect
  
  ; ============================================================================
  ; ÉTAPE 6 : APPLICATION DU MASQUE (SI PRÉSENT)
  ; ============================================================================
  
  If *mask
    *param\mask_type = *param\option[5]
    MultiThread_MT(@_mask())
  EndIf
  
  ; ============================================================================
  ; NETTOYAGE MÉMOIRE
  ; ============================================================================
  
  FreeArray(tr())
  FreeMemory(*gray)
  FreeMemory(*blur)
  FreeMemory(*sobel)
  FreeMemory(*tmp)
EndProcedure

; ============================================================================
; RÉSUMÉ DES 10 STYLES DISPONIBLES
; ============================================================================
; 
; Style 0 : Par défaut - Color Dodge classique
; Style 1 : Line Art - Contours seuls sans remplissage
; Style 2 : Crayon sombre - Inversion des canaux
; Style 3 : Crayon doux - Contours atténués (50%)
; Style 4 : Esquisse - Ajout de bruit aléatoire ±5
; Style 5 : Charbon - Contours accentués + obscurcissement
; Style 6 : Estampe - Seuillage binaire (noir/blanc)
; Style 7 : Peinture - Mix 75% gris / 25% flou
; Style 8 : Pastel - Mix 25% gris / 75% flou (très doux)
; Style 9 : Cartoon - Posterisation 4 niveaux + contours
; 
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 582
; FirstLine = 577
; Folding = ---
; EnableXP
; DPIAware
; DisableDebugger