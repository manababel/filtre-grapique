
Macro Bilateral_DomainTransform1D_declare(length)
  Protected *buf = param\addr[0]         ; pointeur vers l'image source
  Protected *temp = param\addr[1]        ; pointeur vers le buffer temporaire
  Protected *expLUT = param\addr[2]      ; pointeur vers la table exponentielle (LUT)
  Protected Dim domain.f(length)          ; tableau du domaine cumulatif
  Protected Dim dc.f(length)              ; tableau des différences de couleur
  Protected Dim color_diff.f(length)      ; tableau pour les différences de couleur (non utilisé ici)
  Protected Dim dataR.f(length)           ; tableau pour les valeurs rouge
  Protected Dim dataG.f(length)           ; tableau pour les valeurs vert
  Protected Dim dataB.f(length)           ; tableau pour les valeurs bleu
  Protected i.i, idx.i                    ; indices pour les boucles et LUT
  Protected diff_d.f, alpha.f, frac.f, a0.f, a1.f ; variables pour le calcul du filtre
  Protected pixel0.i, pixel1.i, r0, g0, b0, r1, g1, b1 ; pixels et composantes
  Protected *scr1.pixel32                 ; pointeur pixel courant
  Protected *scr2.pixel32                 ; pointeur pixel voisin
  Protected *dst.pixel32                  ; pointeur destination (non utilisé)
EndMacro

Macro Bilateral_DomainTransform1D_end()
  FreeArray(domain())
  FreeArray(dc())
  FreeArray(color_diff())
  FreeArray(dataR())
  FreeArray(dataG())
  FreeArray(dataB())
EndMacro

Macro Bilateral_DomainTransform1D_sp0(op)
  clamp(diff_d , 0 , 255)                 ; limiter la distance dans le domaine
  idx  = Int(diff_d)                      ; indice entier pour la LUT
  frac = diff_d - idx                     ; fraction pour interpolation
  a0   = PeekF(*expLUT + idx * 4)        ; valeur LUT pour idx
  a1   = PeekF(*expLUT + (Bool(idx < 255) * (idx + 1) + Bool(idx >= 255) * 255) * 4) ; valeur LUT suivante
  alpha = a0 + frac * (a1 - a0)          ; interpolation linéaire
  dataR(i) = dataR(i) + alpha * (dataR(i op 1) - dataR(i)) ; mise à jour rouge
  dataG(i) = dataG(i) + alpha * (dataG(i op 1) - dataG(i)) ; mise à jour vert
  dataB(i) = dataB(i) + alpha * (dataB(i op 1) - dataB(i)) ; mise à jour bleu
EndMacro

Macro Bilateral_DomainTransform1D_sp1(v1)
  *scr1 = *source + (i * v1)             ; pointeur pixel courant
  *scr2 = *scr1 + v1                     ; pointeur pixel suivant
  GetRGB(*scr1\l , r0, g0, b0)           ; récupérer RGB du pixel courant
  GetRGB(*scr2\l , r1, g1, b1)           ; récupérer RGB du pixel suivant
  dataR(i) = r0 : dataG(i) = g0 : dataB(i) = b0 ; initialiser les tableaux de couleurs
  ; Calcul de la différence de couleur en luminance perceptuelle
  dc(i) = Sqr(0.3 * ((r1 - r0) * (r1 - r0)) + 0.59 * ((g1 - g0) * (g1 - g0)) + 0.11 * ((b1 - b0) * (b1 - b0)))
  If dc(i) > 255 : dc(i) = 255 : EndIf     ; limiter à 255
EndMacro

Procedure Bilateral_DomainTransform1D_X(*param.parametre )
  Protected length = *param\lg
  Bilateral_DomainTransform1D_declare(length)       ; déclaration variables locales
  Protected y, pos, start, stop
  start = (*param\thread_pos * *param\ht) / *param\thread_max  ; début de ligne pour ce thread
  stop  = ((*param\thread_pos + 1) * *param\ht) / *param\thread_max ; fin
  If stop > *param\ht : stop = *param\ht : EndIf
  For y = start To stop - 1
    pos = y * length * 4
    Protected *source = *buf + pos
    ; calcul des différences de couleur horizontales
    For i = 0 To length - 2 : Bilateral_DomainTransform1D_sp1(4) : Next
    ; dernier pixel de la ligne
    i = length - 1
    pixel0 = PeekL(*source + (length - 1) * 4)
    GetRGB(pixel0, r0, g0, b0)
    dataR(i) = r0 : dataG(i) = g0 : dataB(i) = b0
    ; calcul du domaine cumulatif
    domain(0) = 0
    For i = 1 To length - 1
      domain(i) = domain(i - 1) + 1.0 + (*param\option[4] * dc(i - 1)) ; distance pondérée
      If domain(i) < domain(i-1) : domain(i) = domain(i-1) : EndIf
    Next
    ; filtrage récursif avant-arrière
    For i = 1 To length - 1   : diff_d = domain(i) - domain(i - 1) : Bilateral_DomainTransform1D_sp0(-) : Next
    For i = length - 2 To 0 Step -1 : diff_d = domain(i + 1) - domain(i) : Bilateral_DomainTransform1D_sp0(+) : Next

    ; stockage final dans le buffer temporaire
    For i = 0 To length - 1
      r0 = dataR(i) : g0 = dataG(i) : b0 = dataB(i)
      clamp_rgb(r0, g0, b0)                  ; clamp entre 0-255
      PokeL(*temp + pos + i * 4, (r0 << 16) | (g0 << 8) | b0) ; stockage BGR
    Next
  Next
  Bilateral_DomainTransform1D_end()
EndProcedure

Procedure Bilateral_DomainTransform1D_Y(*param.parametre )
  Protected length = *param\ht
  Bilateral_DomainTransform1D_declare(length)
  Protected stride = *param\lg * 4           ; pas pour passer d'une ligne à l'autre
  Protected start, stop, x
  start = (*param\thread_pos * *param\lg) / *param\thread_max
  stop  = ((*param\thread_pos + 1) * *param\lg) / *param\thread_max
  If stop > *param\lg : stop = *param\lg : EndIf
  For x = start To stop - 1
    Protected *source = *buf + x * 4
    ; calcul des différences de couleur verticales
    For i = 0 To length - 2 : Bilateral_DomainTransform1D_sp1(stride) : Next
    ; dernier pixel de la colonne
    i = length - 1
    pixel0 = PeekL(*source + (length - 1) * stride)
    GetRGB(pixel0, r0, g0, b0)
    dataR(i) = r0 : dataG(i) = g0 : dataB(i) = b0
    ; calcul du domaine cumulatif vertical
    domain(0) = 0
    For i = 1 To length - 1
      domain(i) = domain(i - 1) + 1.0 + (*param\option[4] * dc(i - 1))
      If domain(i) < domain(i-1) : domain(i) = domain(i-1) : EndIf
    Next
    ; filtrage récursif
    For i = 1 To length - 1   : diff_d = domain(i) - domain(i - 1) : Bilateral_DomainTransform1D_sp0(-) : Next
    For i = length - 2 To 0 Step -1 : diff_d = domain(i + 1) - domain(i) : Bilateral_DomainTransform1D_sp0(+) : Next
    ; stockage final
    For i = 0 To length - 1
      r0 = dataR(i) : g0 = dataG(i) : b0 = dataB(i)
      clamp_rgb(r0, g0, b0)
      PokeL(*temp + x * 4 + i * stride, (r0 << 16) | (g0 << 8) | b0)
    Next
  Next
  Bilateral_DomainTransform1D_end()
EndProcedure

Procedure Bilateral(*param.parametre)
  ; informations pour l'interface utilisateur
  If *param\info_active
    *param\name = "Bilateral"
    *param\typ = #Filter_Type_Blur
    *param\remarque = "adoucie tout en conservant les contours nets"
    *param\info[0] = "nb de passes"
    *param\info[1] = "sigma espace"
    *param\info[2] = "sigma couleur"
    *param\info[3] = "Masque binaire"
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 5   : *param\info_data(0,2) = 2
    *param\info_data(1,0) = 1 : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 40
    *param\info_data(2,0) = 1 : *param\info_data(2,1) = 100 : *param\info_data(2,2) = 30
    *param\info_data(3,0) = 0 : *param\info_data(3,1) = 2   : *param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  ; vérifier si les pointeurs source et cible sont valides
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  Protected pass          = *param\option[0]    ; nombre de passes
  Protected sigma_space.f = *param\option[1]    ; sigma spatial
  Protected sigma_color.f = *param\option[2]    ; sigma couleur
  Clamp(pass, 1, 5)
  Clamp(sigma_space, 1, 100)
  Clamp(sigma_color, 1, 255)
  ; ---- LUT exponentielle pour la couleur ----
  Protected *expLUT = AllocateMemory(256 * SizeOf(Float))
  If *expLUT = 0 : ProcedureReturn : EndIf 
  Protected d
  For d = 0 To 255 : PokeF(*expLUT + d * 4, Exp(-d / sigma_color)) : Next
  ; ---- Coefficient de domaine cumulatif ----
  *param\option[4] = sigma_space / sigma_color
  ; ---- Buffer temporaire pour stockage intermédiaire ----
  Protected *temp = AllocateMemory(*param\lg * *param\ht * 4)
  If *temp = 0 : FreeMemory(*expLUT) : ProcedureReturn : EndIf
  Protected *buf = *param\source
  *param\addr[2] = *expLUT  ; passer le pointeur LUT
  ; ---- Application du filtrage en passes ----
  For d = 0 To pass - 1
    *param\addr[0] = *buf
    *param\addr[1] = *temp
    MultiThread_MT(@Bilateral_DomainTransform1D_X())  ; filtrage horizontal
    *param\addr[0] = *temp
    *param\addr[1] = *param\cible
    MultiThread_MT(@Bilateral_DomainTransform1D_Y())  ; filtrage vertical
    *buf = *param\cible
  Next
  ; ---- Application du masque éventuel ----
  If *param\mask And *param\option[3] : *param\mask_type = *param\option[3] - 1 : MultiThread_MT(@_mask()) : EndIf
  ; ---- Libération de la mémoire ----
  FreeMemory(*expLUT)
  FreeMemory(*temp)
EndProcedure

;----------------

Macro BoxBlur_declare_variable(lenght)
  Protected *buf1 = *param\addr[0]       ; pointeur vers l'image source
  Protected *buf2 = *param\addr[1]       ; pointeur vers l'image destination
  Protected lg = *param\lg               ; largeur de l'image
  Protected ht = *param\ht               ; hauteur de l'image
  Protected blur = *param\option[5]      ; coefficient de normalisation du flou
  Protected a, r, g, b                   ; accumulation des composantes ARGB
  Protected a1, r1, g1, b1               ; composantes du pixel calculé
  Protected a2, r2, g2, b2               ; composantes du pixel suivant
  Protected x = 0, y = 0                 ; coordonnées dans l'image
  Protected index1, index2, color_32bits ; indices et couleur temporaire
  Protected start, stop, i               ; limites pour le multithreading
  Protected *scr1.Pixel32, *scr2.Pixel32, *scr3.Pixel32
  Protected *scr4.Pixel32, *scr5.Pixel32, *scr6.Pixel32 ; pointeurs temporaires
  Protected *dst.Pixel32                  ; pointeur vers pixel de sortie
  ; calcule la portion d'image à traiter pour chaque thread
  start = (lenght * *param\thread_pos) / *param\thread_max
  stop  = (lenght * (*param\thread_pos + 1)) / *param\thread_max
  If *param\thread_pos = (*param\thread_max - 1) : stop = lenght : EndIf
EndMacro

Macro BoxBlur_sp0(var) ; calcul du noyau
  a = 0 : r = 0 : g = 0 : b = 0
  For i = 0 To opt#var - 1
    *scr5 = *pz + (i << 2)                  ; récupération de l'index du pixel
    *scr6 = *ligne + (*scr5\l << 2)         ; adresse du pixel dans la ligne/colonne
    getargb(*scr6\l, a1, r1, g1, b1)       ; extrait ARGB du pixel
    a + a1 : r + r1 : g + g1 : b + b1      ; accumulation des composantes
  Next
  ; normalisation de la somme selon le facteur blur
  a1 = (a * blur) >> 16 : r1 = (r * blur) >> 16 : g1 = (g * blur) >> 16 : b1 = (b * blur) >> 16
EndMacro

Macro BoxBlur_sp1(var1, var2)
  *scr1 = *pz + (var1 << 2)               ; index du pixel sortant de la fenêtre
  *scr2 = *pz + ((var1 + var2) << 2)      ; index du pixel entrant dans la fenêtre
  *scr3 = *ligne + ((*scr1\l) << 2)       ; adresse du pixel sortant
  *scr4 = *ligne + ((*scr2\l) << 2)       ; adresse du pixel entrant
  getargb(*scr3\l, a1, r1, g1, b1)       ; extrait ARGB du pixel sortant
  getargb(*scr4\l, a2, r2, g2, b2)       ; extrait ARGB du pixel entrant
  a - a1 + a2 : r - r1 + r2 : g - g1 + g2 : b - b1 + b2 ; mise à jour de la somme
  ; calcul du pixel final normalisé
  a1 = (a * blur) >> 16 : r1 = (r * blur) >> 16 : g1 = (g * blur) >> 16 : b1 = (b * blur) >> 16
  *dst = *buf2 + (((lg * y) + x) << 2)   ; adresse du pixel de sortie
  *dst\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1 ; écriture ARGB
EndMacro

; Applique un flou horizontal
Procedure BoxBlur_X(*param.parametre) 
  BoxBlur_declare_variable(ht)
  Protected optx = *param\option[0]
  Protected *pz = *param\addr[2]
  optx = (optx * 2) + 1
  Protected *ligne = AllocateMemory(lg << 2, #PB_Memory_NoClear) 
  For y = start To stop - 1
    CopyMemory(*buf1 + ((lg * y) << 2), *ligne, lg << 2)
    BoxBlur_sp0(x) ; calcul du premier pixel
    *dst = *buf2 + (((lg * y) ) << 2)
    *dst\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
    For x = 1 To (lg - 1)
      BoxBlur_sp1((x-1) , optx)
    Next
  Next
  FreeMemory(*ligne)
EndProcedure

; Applique un flou vertical
Procedure BoxBlur_Y(*param.parametre) 
  BoxBlur_declare_variable(lg)
  Protected opty = *param\option[1]
  Protected *pz = *param\addr[3]
  opty = (opty * 2) + 1
  Protected *ligne = AllocateMemory(ht << 2, #PB_Memory_NoClear)
  For x = start To stop - 1
    For y = 0 To ht - 1 : PokeL(*ligne + (y << 2), PeekL(*buf1 + (((lg * y) + x) << 2))) : Next
    BoxBlur_sp0(y) ; calcul du premier pixel
    *dst = *buf2 + (x << 2)
    *dst\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
    For y = 1 To (ht - 1)
      BoxBlur_sp1((y-1) , opty)
    Next
  Next
  FreeMemory(*ligne)
EndProcedure

Procedure Blur_box( *param.parametre )
  ; Mode interface : renseigner les informations sur les options si demandé
  If param\info_active
    param\typ = #Filter_Type_Blur
    param\name = "Blur_box"
    param\remarque = "Blur Box bugger"
    param\info[0] = "Rayon X"           ; Rayon horizontal
    param\info[1] = "Rayon Y"           ; Rayon vertical
    param\info[2] = "Nombre de passe"   ; Nombre d’itérations du filtre
    param\info[3] = "bord"              ; Mode bord ou boucle
    param\info[4] = "Masque binaire"    ; Option masque binaire
    param\info_data(0,0) = 1 : param\info_data(0,1) = 100 : param\info_data(0,2) = 1
    param\info_data(1,0) = 1 : param\info_data(1,1) = 100 : param\info_data(1,2) = 1
    param\info_data(2,0) = 1 : param\info_data(2,1) = 3   : param\info_data(2,2) = 1
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  Protected i , boucle , e , ii , l , k
  Protected lg = *param\lg
  Protected ht = *param\ht
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  clamp(param\option[0] , 1 , 100)
  clamp(param\option[1] , 1 , 100)
  Protected optx = *param\option[0]
  Protected opty = *param\option[1]
  clamp(*param\option[2],1,3)
  Protected *tempo = AllocateMemory( lg * ht * 4 , #PB_Memory_NoClear) ; memoire tempon de l'image  
  If *tempo = 0 : ProcedureReturn : EndIf
  Protected *px = AllocateMemory((lg + 2 * (optx + 2)) * 4 , #PB_Memory_NoClear) ; pre-calcul des pixels en x pour gerer les bords de l'image
  Protected *py = AllocateMemory((ht + 2 * (opty + 2)) * 4 , #PB_Memory_NoClear) ; pre-calcul des pixels en y pour gerer les bords de l'image
  If *param\option[3]
    ; mode boucle : les pixels sortants "reviennent" à l'autre extrémité
    k = (optx + 1) * 0.5 : l = 2 * (optx + 1) : e = (lg - 1) - k : For i = 0 To (lg - 1) + l : PokeL(*px + (i << 2) , (i+e) % lg) : Next
    k = (opty + 1) * 0.5 : l = 2 * (opty + 1) : e = (ht - 1) - k : For i = 0 To (ht - 1) + l : PokeL(*py + (i << 2) , (i+e) % ht) : Next
  Else      
    ; mode bord : pixels répétés aux extrémités
    k = (optx + 1) * 0.5 : l = 2 * (optx + 1) : For i = 0 To lg + l : ii = i - k : If ii < 0 : ii = 0 : EndIf : If ii > (lg - 1) : ii = (lg - 1) : EndIf : PokeL(*px + (i << 2) , ii) : Next
    k = (opty + 1) * 0.5 : l = 2 * (opty + 1) : For i = 0 To ht + l : ii = i - k : If ii < 0 : ii = 0 : EndIf : If ii > (ht - 1) : ii = (ht - 1) : EndIf : PokeL(*py + (i << 2) , ii) : Next
  EndIf 
  *param\addr[2] = *px
  *param\addr[3] = *py
  Protected *buf = *param\source
  For boucle = 1 To *param\option[2] 
    param\addr[0] = *buf 
    param\addr[1] = *tempo
    param\option[5] = (65536 / (optx * 2 + 1)); facteur blur horizontal
    MultiThread_MT(@BoxBlur_X())
    param\addr[0] = *tempo 
    param\addr[1] = *param\cible
    param\option[5] = (65536 / (opty * 2 + 1)); facteur blur vertical
    MultiThread_MT(@BoxBlur_Y())
    *buf = *param\cible
  Next
  If *param\mask And *param\option[4] : *param\mask_type = *param\option[4] - 1 : MultiThread_MT(@_mask()) : EndIf
  FreeMemory(*px)
  FreeMemory(*py)
  FreeMemory(*tempo)
EndProcedure

;----------------

Macro MedianBlur_sp1(op)
  value = PeekL(*source + index)
  getargb(value,a,r,g,b)
  histA(a) op 1
  yl = (77 * R + 150 * G + 29 * B) >> 8
  histy(yl) op 1
EndMacro

Macro MedianBlur_sp2(var)
  sum = 0
  median#var = 0
  For i = 0 To 255
    sum + hist#var(i)
    If sum >= kernelArea_d2 : median#var = i : Break : EndIf
  Next
EndMacro

Procedure MedianBlur_sp(*param.parametre )
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf
  Protected kernelSize = param\option[0]
  If kernelSize < 1 :  kernelSize = 1 : EndIf
  kernelSize = (kernelSize * 2) + 1
  Protected half = kernelSize / 2
  Protected kernelArea_d2 = kernelSize * kernelSize * 0.5
  Dim histA.l(255)
  Dim histy.l(255)
  Protected x, y, dx, dy, px, py, index
  Protected value, r.l, g.l, b.l, a.l , i , sum , yl 
  Protected medianA , medianY
  Protected oldX, newX
  Protected cb.l, cr.l 
  Protected maskVal , invMask , a1.l ,r1.l , g1.l , b1.l 
  Protected start = (*param\ht * *param\thread_pos) / *param\thread_max
  Protected stop  = (*param\ht * (*param\thread_pos + 1)) / *param\thread_max
  If *param\thread_pos = (*param\thread_max - 1) : stop = *param\ht : EndIf 
  ;For y = 0 To ht - 1
  For y = start To stop - 1    
    ; Réinitialiser histogrammes
    FillMemory(@histA(),256*4,0)
    FillMemory(@histy(),256*4,0)
    ; Fenêtre initiale (colonne x = 0)
    For dy = -half To half
      py = y + dy
      Clamp(py, 0, (ht - 1))
      For dx = -half To half
        px = dx
        Clamp(px , 0, lg - 1)
        index = (py * lg + px) * 4
        MedianBlur_sp1(+)
      Next
    Next
    ; Parcours horizontal
    For x = 0 To lg - 1
      ; Médiane des canaux
      MedianBlur_sp2(a)
      MedianBlur_sp2(y)
      index = (y * lg + x) * 4
      value = PeekL(*source + index)
      getargb(value,a,r,g,b)
      cb = ((-43 * r - 85 * g + 128 * b) >> 8)
      cr = ((128 * r - 107 * g - 21 * b) >> 8)
      r = medianY + ((358 * cr) >> 8)
      g = medianY - ((88 * cb + 183 * cr) >> 8)
      b = medianY + ((454 * cb) >> 8)
      clamp_rgb(r,g,b)
      PokeL(*cible + (y * lg + x) * 4 , (mediana << 24) | (r << 16) | (g << 8) | b )  
      ; Mise à jour glissante : retirer ancienne colonne / ajouter nouvelle
      If x < lg - 1
        oldX = x - half
        Clamp(oldX, 0, lg - 1)
        newX = x + half + 1
        Clamp(newX, 0, lg - 1)
        For dy = -half To half
          py = y + dy
          Clamp(py, 0, ht - 1)
          ; Retirer ancienne colonne
          index = (py * lg + oldX) * 4
          MedianBlur_sp1(-)
          ; Ajouter nouvelle colonne
          index = (py * lg + newX) * 4
          MedianBlur_sp1(+)
        Next
      EndIf
    Next
  Next
  FreeArray(histA())
  FreeArray(histy())
EndProcedure

Procedure MedianBlur(*param.parametre )
  If param\info_active
    param\typ = #Filter_Type_Blur
    param\name = "MedianBlur"
    param\remarque = ""
    param\info[0] = "Rayon"           ; Rayon horizontal
    param\info[1] = "Masque binaire"    ; Option masque binaire
    param\info_data(0,0) = 1 : param\info_data(0,1) = 100 : param\info_data(0,2) = 1
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2   : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf
  If param\option[0] < 1 : param\option[0] = 1 : EndIf
  filter_start(@MedianBlur_sp() , 1)
EndProcedure

;----------------

Procedure RadialBlur_MT(*param.parametre)

  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected Radius = *param\option[0]
  If Radius < 1 : Radius = 1 : EndIf
  Protected cx = (*param\option[1] * lg) / 100
  Protected cy = (*param\option[2] * ht) / 100
  Protected rmax = (*param\option[3] * Sqr(lg*lg+ht*ht) )/ 100
  If rmax < 1 : rmax = 1 : EndIf

  Protected rmax2 = rmax * rmax
  Protected scale = 65536
  Protected samp = scale / (Radius + 1)
  
  Protected *scr1.Pixel32
  Protected *dst.Pixel32
  
  Protected startY = (ht * *param\thread_pos) / *param\thread_max
  Protected stopY  = (ht * (*param\thread_pos + 1)) / *param\thread_max
  If *param\thread_pos = (*param\thread_max - 1) : stopY = ht : EndIf

  ; Pré-calcule rmax2 pour éviter conditions multiples
  Protected x, y, i, sx, sy
  Protected dx, dy, fx, fy
  Protected r1, g1, b1, r, g, b
  Protected color
  Protected dist, force

  For y = startY To stopY - 1
    Protected rowOffset = y * lg * 4
    dy = y - cy
    For x = 0 To lg - 1
      dx = x - cx
      dist = dx*dx + dy*dy

      Protected pixelOffset = rowOffset + x * 4

      If dist > rmax2
        ; Pixel hors zone : copie rapide pixel original
        *scr1 = *source + pixelOffset
        *dst = *cible + pixelOffset
        *dst\l = *scr1\l
        Continue
      EndIf

      ; Force (fixed point 16.16)
      force = ((rmax2 - dist) << 16) / rmax2
      If force < 0 : force = 0 : EndIf

      ; Pré-calcul des incréments en fixed-point
      Protected dxStep = ((cx - x) * samp)
      Protected dyStep = ((cy - y) * samp)
      fx = x * scale
      fy = y * scale

      r = 0 : g = 0 : b = 0

      For i = 0 To Radius
        sx = fx >> 16
        sy = fy >> 16
        If sx >= 0 And sx < lg And sy >= 0 And sy < ht
          *scr1 = *source + (sy * lg + sx) * 4
          getrgb(*scr1\l, r1, g1, b1)
          r + r1
          g + g1
          b + b1
        EndIf
        fx + dxStep
        fy + dyStep
      Next

      ; Calcul de la moyenne et application de la force
      ; Évite division flottante: calcule en int puis ajuste
      r = (r * samp * force) >> 32;/ (scale * scale)
      g = (g * samp * force) >> 32;/ (scale * scale)
      b = (b * samp * force) >> 32;/ (scale * scale)

      ; Lecture pixel original pour mix
      *scr1 = *source + pixelOffset
      getrgb(*scr1\l , r1, g1, b1)

      ; Mix approximatif avec le pixel original selon la force
      r = (r * force + r1 * (scale - force)) >> 16
      g = (g * force + g1 * (scale - force)) >> 16
      b = (b * force + b1 * (scale - force)) >> 16

      ; Clamp branchless possible ici
      clamp_rgb(r, g, b)
      
      *dst = *cible + pixelOffset
      *dst\l = (r << 16) | (g << 8) | b
    Next
  Next

EndProcedure


Procedure RadialBlur( *param.parametre )
  ; Mode interface : renseigner les informations sur les options si demandé
  If param\info_active
    param\name = "RadialBlur"
    param\remarque = "Radial Blur linéaire"
    param\info[0] = "échantillonnage"          
    param\info[1] = "Pos X"           
    param\info[2] = "Pos Y"          
    param\info[3] = "Rayon Max"   
    param\info[4] = "Masque binaire"    
    param\info_data(0,0) = 1 : param\info_data(0,1) = 50 : param\info_data(0,2) = 25
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 0 : param\info_data(3,1) = 100 : param\info_data(3,2) = 50
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@RadialBlur_MT() , 4)
EndProcedure

;----------------

Procedure RadialBlur_IIR_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected Radius = *param\option[0]
  Protected cx = (*param\option[1] * lg) / 100
  Protected cy = (*param\option[2] * ht) / 100
  Protected pos , i , j
  Protected angle.f
  Protected cosA
  Protected sinA
  Protected maxRadius.f
  Protected r , g , b
  Protected firstPixel = #True
  Protected px , py
  Protected r1 ,g1 ,b1
  Protected Alpha , inv_Alpha
  Protected mul = 65536
  Protected mul2 = mul >> 1
  Protected quality = *param\option[3]
  Protected *scr.Pixel32
  Protected *dst.Pixel32
  Alpha = (Exp(-2.3 / (Radius + 1)))* mul
  inv_Alpha = mul - alpha
  maxRadius = Sqr(lg * lg + ht * ht)
  Protected tt = 360 * quality
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected startPos = (thread_pos * tt) / thread_max
  Protected endPos   = ((thread_pos + 1) * tt) / thread_max - 1
  ;For i = 0 To (360 * quality) - 1
  For i = startPos To endPos -1 
    cosA = PeekL(*param\addr[2] + i <<2)
    sinA = PeekL(*param\addr[3] + i <<2)
    ; Variables pour flou IIR
    r = 0 : g = 0 : b = 0
    firstPixel = #True
    For j = 0 To maxRadius
      ; Position en cartésien
      px = cx + (j * cosA) >> 16
      py = cy + (j * sinA) >> 16
      If px < 0 Or py < 0 Or px >= lg Or py >= ht : Continue : EndIf
      ; Lecture pixel depuis buffer source (nearest neighbor)
      pos = ((py) * lg + (px)) << 2
      *scr = *source + pos
      getrgb(*scr\l , r1 , g1 , b1)
      If firstPixel
        r = r1 * mul : g = g1 * mul : b = b1 * mul
        firstPixel = #False
      Else
        ; Application du flou IIR exponentiel
        r = (Alpha * r + inv_Alpha * (r1 * mul)) >> 16
        g = (Alpha * g + inv_Alpha * (g1 * mul)) >> 16
        b = (Alpha * b + inv_Alpha * (b1  *mul)) >> 16
      EndIf
      ; Écriture dans image temporaire
      r1 = (r + mul2) >> 16
      g1 = (g + mul2) >> 16
      b1 = (b + mul2) >> 16
      *dst = *cible + pos
      *dst\l = (r1 << 16) | (g1 << 8) | b1
    Next
  Next
EndProcedure

Procedure RadialBlur_IIR( *param.parametre )
  ; Mode interface : renseigner les informations sur les options si demandé
  If param\info_active
    param\typ = #Filter_Type_Blur
    param\name = "RadialBlur_IIR"
    param\remarque = ""
    param\info[0] = "Rayon"           ; Rayon horizontal
    param\info[1] = "pos X"       
    param\info[2] = "pos Y"  
    param\info[3] = "qualité" 
    param\info[4] = "Masque binaire"    ; Option masque binaire
    param\info_data(0,0) = 1 : param\info_data(0,1) = 1999 : param\info_data(0,2) = 100
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 16 : param\info_data(3,1) = 256   : param\info_data(3,2) = 32
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected total = *param\lg * *param\ht * 4
  If *param\source = *param\cible
    Protected *tempo = AllocateMemory(total)
    If Not *tempo : ProcedureReturn : EndIf
    CopyMemory(*param\source , *tempo , total)
    *param\addr[0] = *tempo
    *param\addr[1] = *param\cible    
  Else
    *param\addr[0] = *param\source
    *param\addr[1] = *param\cible
  EndIf
  
  Protected i , angle.f
  Protected quality = *param\option[3]
  Protected inv_quality.f = 1/quality
  Dim rc.l(360 * quality)
  Dim rs.l(360 * quality)
  For i = 0 To (360 * quality) - 1
    angle = Radian(i * inv_quality) 
    rc(i) = Cos(angle) * 65536
    rs(i) = Sin(angle) * 65536
  Next
  *param\addr[2] = @rc()
  *param\addr[3] = @rs()
  MultiThread_MT(@RadialBlur_IIR_MT())
  If *param\mask And *param\option[4] : *param\mask_type = *param\option[4] - 1 : MultiThread_MT(@_mask()) : EndIf
  FreeArray(rc())
  FreeArray(rs())
  If *tempo : FreeMemory(*tempo) : EndIf
EndProcedure

;----------------

Procedure SpiralBlur_IIR_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected Radius = *param\option[0]
  Protected cx.f = (*param\option[1] * lg) / 100
  Protected cy.f = (*param\option[2] * ht) / 100
  Protected force.i = *param\option[3]
  Protected quality = *param\option[4]
  Protected direction = *param\option[6]
  Protected pos, i, j
  
  direction = (direction * 2) - 1
  
  ; ACCUMULATEURS en 64-bit pour éviter overflow
  Protected r.q, g.q, b.q
  Protected firstPixel
  Protected px.f, py.f
  Protected col, r1.i, g1.i, b1.i

  ; Alpha en 64-bit aussi (sécurité)
  Protected Alpha.q, inv_Alpha.q
  Protected mul = 65536
  Protected mul2 = mul >> 1

  Protected maxRadiusInt.i
  maxRadiusInt = Max_4( Sqr(cx*cx + cy*cy), Sqr((lg - cx)*(lg - cx) + cy*cy), Sqr(cx*cx + (ht - cy)*(ht - cy)), Sqr((lg - cx)*(lg - cx) + (ht - cy)*(ht - cy)) )
  Protected activeRadius.f = (*param\option[5] * maxRadiusInt) / 100
  
  Protected angleCount = 360 * quality
  Protected forceMod = (force * direction) % angleCount   ; wrap optimisé
  If forceMod < 0 : forceMod + angleCount : EndIf

  ; garde de sécurité
  If angleCount <= 0 Or *source = 0 Or *cible = 0
    ProcedureReturn
  EndIf

  Alpha = Int(Exp(-2.3 / (Radius + 1)) * mul)
  inv_Alpha = mul - Alpha

  ; Utiliser .q pour stocker des adresses si PureBasic 64-bit
  Protected cosPtr = *param\addr[2]
  Protected sinPtr = *param\addr[3]
  
  Protected *scr.Pixel32
  Protected *dst.Pixel32
  
  If cosPtr = 0 Or sinPtr = 0 : ProcedureReturn : EndIf

  Protected angleStart = (*param\thread_pos * angleCount) / *param\thread_max
  Protected angleEnd = ((*param\thread_pos + 1) * angleCount) / *param\thread_max - 1

  For i = angleStart To angleEnd
    r = 0 : g = 0 : b = 0
    firstPixel = #True

    ; idx normalisé une seule fois
    Protected idx.i = i
    If idx >= angleCount
      idx = idx % angleCount
    EndIf

    For j = 0 To maxRadiusInt
      
      If j > 0
        idx + forceMod
        If idx >= angleCount
          idx - angleCount
        EndIf
      EndIf

      px = cx + j * PeekF(cosPtr + (idx << 2))
      py = cy + j * PeekF(sinPtr + (idx << 2))

      If px < 0 Or py < 0 Or px >= lg Or py >= ht : Continue : EndIf

      Protected ix.i = Int(px)
      Protected iy.i = Int(py)
      Protected rowBase.i = (iy * lg) << 2
      pos = rowBase + (ix << 2)

      ;col = PeekL(*source + pos)
      *scr = *source + pos
      getrgb(*scr\l , r1 , g1 , b1)
      
      If j < activeRadius 
      
      If firstPixel
        r = r1 << 16 : g = g1 << 16 : b = b1 << 16
        firstPixel = #False
      Else
        ; opérations en 64-bit (sécurité)
        r = (Alpha * r + inv_Alpha * (r1 << 16)) >> 16
        g = (Alpha * g + inv_Alpha * (g1 << 16)) >> 16
        b = (Alpha * b + inv_Alpha * (b1 << 16)) >> 16
      EndIf

      r1 = (r + mul2) >> 16
      g1 = (g + mul2) >> 16
      b1 = (b + mul2) >> 16
      
    EndIf
      
      ; clamp simple
      clamp_rgb(r1 , g1 , b1)
      *dst = *cible + pos
      *dst\l = (r1 << 16) | (g1 << 8) | b1
      ;PokeL(*cible + pos, (r1 << 16) | (g1 << 8) | b1)
    Next ; j
  Next ; i
EndProcedure


Procedure SpiralBlur_IIR( *param.parametre )
  ; Mode interface : renseigner les informations sur les options si demandé
  If param\info_active
    param\typ = #Filter_Type_Blur
    param\name = "SpiralBlur_IIR"
    param\remarque = "appliquer un filtre de flou en spirale"
    param\info[0] = "Rayon du filtre"          
    param\info[1] = "Pos X"           
    param\info[2] = "Pos Y"          
    param\info[3] = "Force de rotation"   
    param\info[4] = "Qualité" 
    param\info[5] = "Rayon actif"   
    param\info[6] = "sens"   
    param\info[7] = "Masque binaire"    
    param\info_data(0,0) = 1 : param\info_data(0,1) = 99 : param\info_data(0,2) = 50
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 0 : param\info_data(3,1) = 100 : param\info_data(3,2) = 10
    param\info_data(4,0) = 16 : param\info_data(4,1) = 64   : param\info_data(4,2) = 32
    param\info_data(5,0) = 0 : param\info_data(5,1) = 100   : param\info_data(5,2) = 100
    param\info_data(6,0) = 0 : param\info_data(6,1) = 1   : param\info_data(6,2) = 0
    param\info_data(7,0) = 0 : param\info_data(7,1) = 2   : param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected total = *param\lg * *param\ht * 4
  If *param\source = *param\cible
    Protected *tempo = AllocateMemory(total)
    If Not *tempo : ProcedureReturn : EndIf
    CopyMemory(*param\source , *tempo , total)
    *param\addr[0] = *tempo
    *param\addr[1] = *param\cible    
  Else
    *param\addr[0] = *param\source
    *param\addr[1] = *param\cible
  EndIf
  
  Protected i , angle.f
  Protected quality = *param\option[4]
  Protected inv_quality.f = 1.0 / quality
  Protected angleCount = 360 * quality
  Dim cosTable.f(angleCount)
  Dim sinTable.f(angleCount) 
  For i = 0 To angleCount - 1
    angle = Radian(i * inv_quality)
    cosTable(i) = Cos(angle)
    sinTable(i) = Sin(angle)
  Next
  *param\addr[2] = @cosTable()
  *param\addr[3] = @sinTable()
  MultiThread_MT(@SpiralBlur_IIR_MT())
  If *param\mask And *param\option[7] : *param\mask_type = *param\option[7] - 1 : MultiThread_MT(@_mask()) : EndIf
  FreeArray(cosTable())
  FreeArray(sinTable())
  If *tempo : FreeMemory(*tempo) : EndIf
EndProcedure

;----------------

Procedure DepthAwareBlur_garyscale_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *cible = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected total = lg * ht
  Protected *scr.pixel32                       
  Protected r ,g , b , gray , i
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  For i = start To stop - 1
    *scr = *source + (i << 2)
    getrgb( *scr\l , r , g , b)
    gray = (r * 1225 + g * 2405 + b * 466) >> 12
    PokeA(*cible + i , gray)
  Next
EndProcedure


Procedure GetGrayFromColor(col.l)
  Protected r, g, b
  getrgb(col, r, g, b)
  ProcedureReturn (r * 1225 + g * 2405 + b * 466) >> 12 ; pondération NTSC approx
EndProcedure

Procedure DepthAwareBlur_MT(*param.parametre)
  
  Protected *source = *param\addr[0]
  Protected *output = *param\addr[1]
  Protected *depthMap = *param\addr[2]
  Protected width   = *param\lg
  Protected height  = *param\ht
  
  Protected depthThreshold = *param\option[0]
  Protected radius         = *param\option[1]
  
  Protected x, y, dx, dy, r, g, b, count, col
  Protected r1 , g1 , b1
  Protected centerDepth, sampleDepth, centerGray, sampleGray, dr
  
  Protected start = (*param\thread_pos * height) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * height) / *param\thread_max
  
  For y = start To stop - 1
    For x = 0 To width - 1
      
      r = 0 : g = 0 : b = 0 : count = 0
      
      ; profondeur pixel central
      centerDepth = PeekA(*depthMap + (y * width + x))
      
      ; balayage voisinage
      For dy = -radius To radius
        Protected sy = y + dy
        If sy < 0 Or sy >= height : Continue : EndIf
        
        For dx = -radius To radius
          Protected sx = x + dx
          If sx < 0 Or sx >= width : Continue : EndIf
          
          sampleDepth = PeekA(*depthMap + (sy * width + sx))
          
          dr = Abs(sampleDepth - centerDepth)
          If dr > depthThreshold : Continue : EndIf
          
          ; couleur source
          col = PeekL(*source + (sy * width + sx) * 4)
          getrgb(col , r1 , g1 ,b1 )
          r + r1 : g + g1 : b + b1
          count + 1
        Next
      Next
      
      ; écriture pixel résultat
      If count > 0
        r / count : g / count : b / count
      EndIf
      PokeL(*output + (y * width + x) * 4, (r << 16) | (g << 8) | b)
      
    Next
  Next
EndProcedure

Procedure DepthAwareBlur(*param.parametre)
  If *param\info_active
    *param\name = "DepthAwareBlur"
    *param\typ = #Filter_Type_Blur
    *param\remarque = "adoucie tout en conservant les contours nets"
    *param\info[0] = "depthThreshold"
    *param\info[1] = "radius"
    *param\info[2] = "Masque binaire"
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 255 : *param\info_data(0,2) = 127
    *param\info_data(1,0) = 3 : *param\info_data(1,1) = 10  : *param\info_data(1,2) = 1
    *param\info_data(2,0) = 0 : *param\info_data(2,1) = 02   : *param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
 
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf

  Protected *tempo = AllocateMemory(*param\lg * *param\ht * 4)
  If Not *tempo : ProcedureReturn : EndIf
  CopyMemory(*param\source , *tempo , *param\lg * *param\ht * 4)
  
  Protected *depthMap = AllocateMemory(*param\lg * *param\ht)
  If Not *depthMap : ProcedureReturn : EndIf
  
  *param\addr[0] = *param\source
  *param\addr[1] = *depthMap
  MultiThread_MT(@DepthAwareBlur_garyscale_MT())
  

  *param\addr[0] = *tempo
  *param\addr[1] = *param\cible
  *param\addr[2] = *depthMap
  ; lancement multi-thread
  MultiThread_MT(@DepthAwareBlur_MT())
  
  ; application du masque si nécessaire
  If *param\mask And *param\option[2] : *param\mask_type = *param\option[2] - 1 : MultiThread_MT(@_mask()) : EndIf
  
  FreeMemory(*tempo)
  FreeMemory(*depthMap)
EndProcedure

;----------------

Procedure DirectionalBoxBlur_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *output = *param\addr[1]
  Protected width  = *param\lg
  Protected height = *param\ht
  Protected angle.f  = *param\option[0] * #PI / 180.0
  Protected radius   = *param\option[1]  ; longueur du flou

  Protected dx.f = Cos(angle)
  Protected dy.f = Sin(angle)

  Protected x, y, i
  Protected sx.f, sy.f
  Protected rSum.f, gSum.f, bSum.f
  Protected r, g, b, count
  Protected col, r1, g1, b1

  Protected start = (*param\thread_pos * height) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * height) / *param\thread_max

  For y = start To stop - 1
    For x = 0 To width - 1
      rSum = 0 : gSum = 0 : bSum = 0 : count = 0

      For i = -radius To radius
        sx = x + i * dx
        sy = y + i * dy
        If sx < 0 Or sx >= width Or sy < 0 Or sy >= height : Continue : EndIf

        col = PeekL(*source + (Int(sy) * width + Int(sx)) * 4)
        getrgb(col, r1, g1, b1)
        rSum + r1 : gSum + g1 : bSum + b1
        count + 1
      Next

      If count > 0
        r = rSum / count
        g = gSum / count
        b = bSum / count
      EndIf

      PokeL(*output + (y * width + x) * 4, (Int(r) << 16) | (Int(g) << 8) | Int(b))
    Next
  Next
EndProcedure


Procedure DirectionalBoxBlur(*param.parametre)
  If *param\info_active
    *param\name = "DirectionalBoxBlur"
    *param\typ = #Filter_Type_Blur
    *param\remarque = "Flou directionnel approximatif"
    *param\info[0] = "Angle (°)"
    *param\info[1] = "Radius"
    *param\info_data(0,0) = 0   : *param\info_data(0,1) = 360 : *param\info_data(0,2) = 0
    *param\info_data(1,0) = 1   : *param\info_data(1,1) = 100  : *param\info_data(1,2) = 8
    *param\info_data(2,0) = 1   : *param\info_data(2,1) = 2   : *param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@DirectionalBoxBlur_MT() , 2)
EndProcedure

;----------------

Procedure Edge_Aware_LoadImageToFloatArrays_MT(*param.parametre)
  Protected *source = *param\source
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected total = lg * ht
  Protected *scr.pixel32
  Protected r, g, b, gray, i
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  
  For i = start To stop - 1
    *scr = *source + (i << 2)
    getrgb(*scr\l, r, g, b)
    gray = (r * 1225 + g * 2405 + b * 466) >> 12 ; 0..255 entier
    
    PokeF(*param\addr[0] + i * 4, r / 255.0)
    PokeF(*param\addr[1] + i * 4, g / 255.0)
    PokeF(*param\addr[2] + i * 4, b / 255.0)
    PokeF(*param\addr[3] + i * 4, gray / 255.0)
  Next
EndProcedure

Procedure Edge_Aware_FloatArraysToLoadImage_MT(*param.parametre)
  Protected *source = *param\source
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected total = lg * ht
  Protected *dst.pixel32
  Protected r, g, b, gray, i
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  
  For i = start To stop - 1
    *dst = *param\cible + (i << 2)
    r = PeekF(*param\addr[0] + i * 4) * 255
    g = PeekF(*param\addr[1] + i * 4) * 255
    b = PeekF(*param\addr[2] + i * 4) * 255
    clamp_rgb(r , g , b)
    *dst\l = (r << 16) | (g << 8) | b
  Next
EndProcedure

Procedure Edge_Aware_UpdateLuma(*param.parametre)
  Protected w = *param\lg
  Protected h = *param\ht
  Protected total = w * h, i
  Protected r.f, g.f, b.f
  
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * total) / *param\thread_max
  
  For i = start To stop - 1
    r = PeekF(*param\addr[0] + i * 4)
    g = PeekF(*param\addr[1] + i * 4)
    b = PeekF(*param\addr[2] + i * 4)
    PokeF(*param\addr[3] + i * 4, 0.299*r + 0.587*g + 0.114*b)
  Next
EndProcedure


Procedure Edge_Aware_RecursiveEdgeAware1D(*param.parametre)
  Protected sigma_s.f = *param\option[0]
  Protected sigma_r.f = *param\option[1]
  Protected sigmaH.f  = *param\option[5]      ; <— fourni par l’appelant
  Protected direction.i = *param\option[6]    ; 0 = horizontal, 1 = vertical
  
  Protected w = *param\lg
  Protected h = *param\ht
  Protected x, y, i, N, idx, prevIdx
  Protected scale.f = sigma_s / sigma_r
  Protected sq2.f = Sqr(2.0)
  Protected lines, lineN
  
  If direction = 0 : lineN = w : lines = h : Else : lineN = h : lines = w : EndIf
  
  ; Tampons temporaires par ligne
  Protected *a  = AllocateMemory(4 * lineN)
  Protected *tr = AllocateMemory(4 * lineN)
  Protected *tg = AllocateMemory(4 * lineN)
  Protected *tb = AllocateMemory(4 * lineN)
  
  Protected start = (*param\thread_pos * lines) / *param\thread_max
  Protected stop  = ((*param\thread_pos + 1) * lines) / *param\thread_max
  
  For i = start To stop - 1
    ; Charger la ligne et calculer a[j]
    For N = 0 To lineN - 1
      If direction = 0 : x = N : y = i : Else : x = i : y = N : EndIf
      idx = y * w + x
      
      PokeF(*tr + N * 4, PeekF(*param\addr[0] + idx * 4))
      PokeF(*tg + N * 4, PeekF(*param\addr[1] + idx * 4))
      PokeF(*tb + N * 4, PeekF(*param\addr[2] + idx * 4))
      
      If N = 0
        PokeF(*a + N * 4, 0.0)
      Else
        If direction = 0
          prevIdx = y * w + (x - 1)
        Else
          prevIdx = (y - 1) * w + x
        EndIf
        Protected gi.f  = PeekF(*param\addr[3] + idx     * 4)
        Protected gip.f = PeekF(*param\addr[3] + prevIdx * 4)
        Protected di.f  = 1.0 + scale * Abs(gi - gip)
        Protected aVal.f = Exp(-(sq2 * di) / sigmaH)
        PokeF(*a + N * 4, aVal)
      EndIf
    Next
    
    ; Gauche -> Droite
    For N = 1 To lineN - 1
      Protected aN.f = PeekF(*a + N * 4)
      PokeF(*tr + N * 4, PeekF(*tr + (N-1) * 4) + aN * (PeekF(*tr + N * 4) - PeekF(*tr + (N-1) * 4)))
      PokeF(*tg + N * 4, PeekF(*tg + (N-1) * 4) + aN * (PeekF(*tg + N * 4) - PeekF(*tg + (N-1) * 4)))
      PokeF(*tb + N * 4, PeekF(*tb + (N-1) * 4) + aN * (PeekF(*tb + N * 4) - PeekF(*tb + (N-1) * 4)))
    Next
    
    ; Droite -> Gauche
    For N = lineN - 2 To 0 Step -1
      Protected aNp1.f = PeekF(*a + (N+1) * 4)
      PokeF(*tr + N * 4, PeekF(*tr + (N+1) * 4) + aNp1 * (PeekF(*tr + N * 4) - PeekF(*tr + (N+1) * 4)))
      PokeF(*tg + N * 4, PeekF(*tg + (N+1) * 4) + aNp1 * (PeekF(*tg + N * 4) - PeekF(*tg + (N+1) * 4)))
      PokeF(*tb + N * 4, PeekF(*tb + (N+1) * 4) + aNp1 * (PeekF(*tb + N * 4) - PeekF(*tb + (N+1) * 4)))
    Next
    
    ; Écrire la ligne filtrée dans les buffers r/g/b
    For N = 0 To lineN - 1
      If direction = 0 : x = N : y = i : Else : x = i : y = N : EndIf
      idx = y * w + x
      Protected r.f = (PeekF(*tr + N * 4))
      Protected g.f = (PeekF(*tg + N * 4))
      Protected b.f = (PeekF(*tb + N * 4))
      clamp(r , 0 , 1)
      clamp(g , 0 , 1)
      clamp(b , 0 , 1)
      
      PokeF(*param\addr[0] + idx * 4, r)
      PokeF(*param\addr[1] + idx * 4, g)
      PokeF(*param\addr[2] + idx * 4, b)
    Next
  Next
  
  FreeMemory(*a)  : FreeMemory(*tr)
  FreeMemory(*tg) : FreeMemory(*tb)
EndProcedure

Procedure Edge_Aware(*param.parametre)
  If *param\info_active
    *param\name = "Edge_Aware"
    *param\typ = #Filter_Type_Blur
    *param\remarque = "lisser sans casser les bords"
    *param\info[0] = "flou large/fin"
    *param\info[1] = "flou contours"
    *param\info[2] = "nombre de passe"
    *param\info[3] = "fixe/line/expo"
    *param\info[4] = "Masque binaire"
    *param\info_data(0,0) = 1  : *param\info_data(0,1) = 128   : *param\info_data(0,2) = 32
    *param\info_data(1,0) = 1  : *param\info_data(1,1) = 1000 : *param\info_data(1,2) = 5
    *param\info_data(2,0) = 1  : *param\info_data(2,1) = 10    : *param\info_data(2,2) = 4
    *param\info_data(3,0) = 0  : *param\info_data(3,1) = 2     : *param\info_data(3,2) = 0
    *param\info_data(4,0) = 0  : *param\info_data(4,1) = 2     : *param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected size = lg * ht * 4
  Protected iters = *param\option[2]
  *param\addr[0] = AllocateMemory(size)
  *param\addr[1] = AllocateMemory(size)
  *param\addr[2] = AllocateMemory(size)
  *param\addr[3] = AllocateMemory(size)
  If *param\addr[0] = 0 Or *param\addr[1] = 0 Or *param\addr[2] = 0 Or *param\addr[3] = 0
    Debug "Erreur allocation mémoire"
    If *param\addr[0] : FreeMemory(*param\addr[0]) : EndIf
    If *param\addr[1] : FreeMemory(*param\addr[1]) : EndIf
    If *param\addr[2] : FreeMemory(*param\addr[2]) : EndIf
    If *param\addr[3] : FreeMemory(*param\addr[3]) : EndIf
    ProcedureReturn
  EndIf
  
  ; Charger en floats normalisés
  MultiThread_MT(@Edge_Aware_LoadImageToFloatArrays_MT())
  
  *param\option[1] = *param\option[1] / 100
  ; Itérations
  Protected i, K = *param\option[2]      ; iters
  Protected sigma_s.f = *param\option[0]
  Protected sigma_r.f = *param\option[1]
  Protected sigma_s_i.f
  
  For i = 0 To K - 1
    
    Select *param\option[3]
      Case 0 : sigma_s_i = sigma_s                    ; fixe
      Case 1 : sigma_s_i = sigma_s * (1.0 - i / (K-1)); linéaire
      Case 2 : sigma_s_i = sigma_s * Pow(0.5, i)      ; exponentiel (actuel)
    EndSelect
    
    Protected numerator.f = Pow(2.0, K - i - 1)
    Protected denom.f = Sqr(Pow(4.0, K) - 1.0)
    
    *param\option[5] = sigma_s_i * Sqr(3.0) * numerator / denom
    
    *param\option[6] = 0   ; horizontal
    MultiThread_MT(@Edge_Aware_RecursiveEdgeAware1D())
    MultiThread_MT(@Edge_Aware_UpdateLuma())
    
    *param\option[6] = 1   ; vertical
    MultiThread_MT(@Edge_Aware_RecursiveEdgeAware1D())
    MultiThread_MT(@Edge_Aware_UpdateLuma())
  Next
  

  MultiThread_MT(@Edge_Aware_FloatArraysToLoadImage_MT())
  
  ; Appliquer le masque si nécessaire
  If *param\mask And *param\option[4] : *param\mask_type = *param\option[4] - 1 : MultiThread_MT(@_mask()) : EndIf
  
  FreeMemory(*param\addr[0])
  FreeMemory(*param\addr[1])
  FreeMemory(*param\addr[2])
  FreeMemory(*param\addr[3])
  
EndProcedure

;----------------

Procedure StackBlur_Horizontal_MT(*param.parametre)
  Protected *source = *param\addr[0]
  Protected *temp   = *param\addr[1]  ; image tampon
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radiusX = *param\option[0]
  If radiusX <= 0 Or *source = 0 Or *temp = 0 : ProcedureReturn : EndIf
  Protected x , y , i
  Protected r , g , b
  
  Protected yStart = (*param\thread_pos * ht) / *param\thread_max
  Protected yEnd   = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  Protected div = radiusX * 2 + 1
  Protected wm = lg - 1
  Protected *stack = AllocateMemory(div * 3 * SizeOf(Long))
  If *stack = 0 : ProcedureReturn : EndIf
  
   Protected *scr.Pixel32
   
  For y = yStart To yEnd
    Protected rSum, gSum, bSum
    rSum = 0
    gSum = 0
    bSum = 0

    For i = -radiusX To radiusX
      Protected px = i
      Clamp(px, 0, wm)
      *scr = *source + ((y * lg + px) << 2)
      getrgb(*scr\l , r , g , b )
      Protected idx = (i + radiusX) * 3
      PokeL(*stack + idx * 4, r)
      PokeL(*stack + (idx + 1) * 4, g)
      PokeL(*stack + (idx + 2) * 4, b)
      rSum + r : gSum + g : bSum + b
    Next

    For x = 0 To lg - 1
      Protected rAvg = rSum / div
      Protected gAvg = gSum / div
      Protected bAvg = bSum / div
      PokeL(*temp + ((y * lg + x) << 2), (rAvg << 16) | (gAvg << 8) | bAvg)

      Protected outIdx = ((x - radiusX + div) % div) * 3
      rSum - PeekL(*stack + outIdx * 4)
      gSum - PeekL(*stack + (outIdx + 1) * 4)
      bSum - PeekL(*stack + (outIdx + 2) * 4)

      Protected nextX = x + radiusX + 1
      Clamp(nextX, 0, wm)
      *scr = *source + ((y * lg + nextX) << 2)
      getrgb(*scr\l , r , g , b )
      Protected inIdx = ((x + radiusX + 1) % div) * 3
      PokeL(*stack + inIdx * 4, r)
      PokeL(*stack + (inIdx + 1) * 4, g)
      PokeL(*stack + (inIdx + 2) * 4, b)
      rSum + r : gSum + g : bSum + b
    Next
  Next

  FreeMemory(*stack)
EndProcedure

Procedure StackBlur_Vertical_MT(*param.parametre)
  Protected *temp   = *param\addr[0]  ; image temp
  Protected *cible  = *param\addr[1]
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radiusY = *param\option[1]
  If radiusY <= 0 Or *temp = 0 Or *cible = 0 : ProcedureReturn : EndIf
  Protected x , y , i
  Protected r , g , b
  
  Protected xStart = (*param\thread_pos * lg) / *param\thread_max
  Protected xEnd   = ((*param\thread_pos + 1) * lg) / *param\thread_max - 1
  Protected div = radiusY * 2 + 1
  Protected hm = ht - 1
  Protected *stack = AllocateMemory(div * 3 * SizeOf(Long))
  If *stack = 0 : ProcedureReturn : EndIf
  
   Protected *scr.Pixel32
   
  For x = xStart To xEnd
    Protected rSum, gSum, bSum
    rSum = 0
    gSum = 0
    bSum = 0

    For i = -radiusY To radiusY
      Protected py = i
      Clamp(py, 0, hm)
      *scr = *temp + ((py * lg + x) << 2)
      getrgb(*scr\l , r , g , b )
      Protected idx = (i + radiusY) * 3
      PokeL(*stack + idx * 4, r)
      PokeL(*stack + (idx + 1) * 4, g)
      PokeL(*stack + (idx + 2) * 4, b)
      rSum + r : gSum + g : bSum + b
    Next

    For y = 0 To ht - 1
      Protected rAvg = rSum / div
      Protected gAvg = gSum / div
      Protected bAvg = bSum / div
      PokeL(*cible + ((y * lg + x) << 2), (rAvg << 16) | (gAvg << 8) | bAvg)

      Protected outIdx = ((y - radiusY + div) % div) * 3
      rSum - PeekL(*stack + outIdx * 4)
      gSum - PeekL(*stack + (outIdx + 1) * 4)
      bSum - PeekL(*stack + (outIdx + 2) * 4)

      Protected nextY = y + radiusY + 1
      Clamp(nextY, 0, hm)
      *scr = *temp + ((nextY * lg + x) << 2)
      getrgb(*scr\l , r , g , b )
      Protected inIdx = ((y + radiusY + 1) % div) * 3
      PokeL(*stack + inIdx * 4, r)
      PokeL(*stack + (inIdx + 1) * 4, g)
      PokeL(*stack + (inIdx + 2) * 4, b)
      rSum + r : gSum + g : bSum + b
    Next
  Next

  FreeMemory(*stack)
EndProcedure

Procedure StackBlur(*param.parametre)
  If *param\info_active
    *param\typ = #Filter_Type_Blur
    *param\name = "StackBlur"
    *param\remarque = "Flou rapide par empilement (2 passes)"
    *param\info[0] = "Radius X"
    *param\info[1] = "Radius Y"
    *param\info[2] = "Masque binaire"
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 100 : *param\info_data(0,2) = 5
    *param\info_data(1,0) = 1 : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 5
    *param\info_data(2,0) = 0 : *param\info_data(2,1) = 2   : *param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected *temp = AllocateMemory(*param\lg * *param\ht * 4)
  If *temp = 0 : ProcedureReturn : EndIf
  
  ; Passe 1 : Horizontal
  *param\addr[0] = *param\source
  *param\addr[1] = *temp
  MultiThread_MT(@StackBlur_Horizontal_MT())
  
  ; Passe 2 : Vertical
  *param\addr[0] = *temp
  *param\addr[1] = *param\cible
  ;*param\cible = *param\cible_final ; valeur initiale
  MultiThread_MT(@StackBlur_Vertical_MT())
  If *param\mask And *param\option[2] : *param\mask_type = *param\option[2] - 1 : MultiThread_MT(@_mask()) : EndIf
  FreeMemory(*temp)
  
EndProcedure

;----------------

Procedure blur_box_create_limit(lg, ht, rx, ry, loop)
    Protected i, ii, e
    clamp(rx, 1, 100)
    clamp(ry, 1, 100)
    Protected dx = lg - 1
    Protected dy = ht - 1
    If rx > dx : rx = dx : EndIf
    If ry > dy : ry = dy : EndIf
    Protected nrx = rx + 1
    Protected nry = ry + 1
    Protected sizeX = (lg + 2 * nrx) * 4
    Protected sizeY = (ht + 2 * nry) * 4
    ; Allocation d’un seul bloc
    Global *blur_box_limit = AllocateMemory(sizeX + sizeY)
    If *blur_box_limit = 0 : ProcedureReturn 0 : EndIf
    Global *blur_box_limit_x = *blur_box_limit
    Global *blur_box_limit_y = *blur_box_limit + sizeX
    ; Remplissage des tables
    If loop
      e = dx - nrx / 2 : For i = 0 To dx + 2 * nrx : PokeL(*blur_box_limit_x + i * 4, (i + e) % (dx + 1)) : Next
      e = dy - nry / 2 : For i = 0 To dy + 2 * nry : PokeL(*blur_box_limit_y + i * 4, (i + e) % (dy + 1)) : Next
    Else
      For i = 0 To dx + 2 * nrx : ii = i - 1 - nrx / 2 : If ii < 0 : ii = 0 : ElseIf ii > dx : ii = dx : EndIf : PokeL(*blur_box_limit_x + i * 4, ii) : Next
      For i = 0 To dy + 2 * nry : ii = i - 1 - nry / 2 : If ii < 0 : ii = 0 : ElseIf ii > dy : ii = dy : EndIf : PokeL(*blur_box_limit_y + i * 4, ii) : Next
    EndIf
    ProcedureReturn 1
  EndProcedure
  
  Procedure blur_box_free_limit()
    If *blur_box_limit
      FreeMemory(*blur_box_limit)
      *blur_box_limit      = 0
      *blur_box_limit_x    = 0
      *blur_box_limit_y    = 0
    EndIf
  EndProcedure
  
  Procedure blur_box_Guillossien_MT(*param.parametre)
    ; Déclarations de pointeurs pixel source/destination
    Protected *srcPixel1.Pixel32
    Protected *srcPixel2.Pixel32
    Protected *dstPixel.Pixel32
    ; Accumulateurs pour composantes ARGB
    Protected ax1, rx1, gx1, bx1
    Protected a1.l, r1.l, b1.l, g1.l
    Protected a2.l, r2.l, b2.l, g2.l
    ; Index temporaires
    Protected j, i, p1, p2
    ; Paramètres de l’image
    Protected lx = *blur_box_limit_x
    Protected ly = *blur_box_limit_y
    Protected lg = *param\lg
    Protected ht = *param\ht
    ; Paramètres du filtre
    Protected nrx = *param\option[0] + 1
    Protected nry = *param\option[1] + 1
    Protected div = Int($800000 / (nrx * nry))  ; Pow(2,23) = $800000
    Protected thread_pos = *param\thread_pos
    Protected thread_max = *param\thread_max
    Protected startPos = (thread_pos * ht) / thread_max
    Protected endPos   = ((thread_pos + 1) * ht) / thread_max - 1
    ; Buffers pour accumuler les sommes par colonne
    Protected Dim a.l(lg) , Dim r.l(lg) , Dim g.l(lg) , Dim b.l(lg)
    ; Initialisation des buffers
    FillMemory(@a(), lg * 4, 0) : FillMemory(@r(), lg * 4, 0) : FillMemory(@g(), lg * 4, 0) : FillMemory(@b(), lg * 4, 0)
    ; === Étape 1 : Accumule les lignes verticales pour démarrer ===
    For j = 0 To nry - 1
      p1 = PeekL(ly + (j + startPos) << 2)
      *srcPixel1 = *param\addr[1] + ((p1 * lg) << 2)
      For i = 0 To lg - 1
        getargb(*srcPixel1\l, a1, r1, g1, b1)
        a(i) + a1 : r(i) + r1 : g(i) + g1 : b(i) + b1
        *srcPixel1 + 4
      Next
    Next
    ; === Étape 2 : Application du filtre pour chaque ligne ===
    For j = startPos To endPos
      ; Mise à jour du buffer colonne (soustraction d’une ancienne ligne et ajout d’une nouvelle)
      p1 = PeekL(ly + (nry + j) << 2)
      p2 = PeekL(ly + (j << 2))
      *srcPixel1 = *param\addr[1] + (p1 * lg) << 2
      *srcPixel2 = *param\addr[1] + (p2 * lg) << 2
      For i = 0 To lg - 1
        getargb(*srcPixel1\l, a1, r1, g1, b1)
        getargb(*srcPixel2\l, a2, r2, g2, b2)
        a(i) + a1 - a2
        r(i) + r1 - r2
        g(i) + g1 - g2
        b(i) + b1 - b2
        *srcPixel1 + 4
        *srcPixel2 + 4
      Next
      ; Application du filtre horizontal
      ax1 = 0 : rx1 = 0 : gx1 = 0 : bx1 = 0
      For i = 0 To nrx - 1
        p1 = PeekL(lx + (i << 2))
        ax1 + a(p1)
        rx1 + r(p1)
        gx1 + g(p1)
        bx1 + b(p1)
      Next
      ; Boucle de sortie pour chaque pixel de la ligne
      For i = 0 To lg - 1
        p1 = PeekL(lx + (nrx + i) << 2)
        p2 = PeekL(lx + (i << 2))
        ax1 + a(p1) - a(p2)
        rx1 + r(p1) - r(p2)
        gx1 + g(p1) - g(p2)
        bx1 + b(p1) - b(p2)
        ; Calcul final avec facteur de division
        a1 = (ax1 * div) >> 23
        r1 = (rx1 * div) >> 23
        g1 = (gx1 * div) >> 23
        b1 = (bx1 * div) >> 23
        ; Écriture dans le buffer temporaire
        *dstPixel = *param\addr[0] + ((j * lg + i) << 2)
        *dstPixel\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
      Next
    Next
    ; Libération des tableaux
    FreeArray(a())
    FreeArray(r())
    FreeArray(g())
    FreeArray(b())
  EndProcedure
  
  Procedure blur_box_Guillossien(*param.parametre)
    *param\addr[0] = *param\source
    *param\addr[1] = *param\cible
    If *param\addr[0] = 0 Or *param\addr[1] = 0 : ProcedureReturn : EndIf
    clamp(*param\option[0], 1, 63)
    clamp(*param\option[1], 1, 63)
    clamp(*param\option[2], 1, 3)
    clamp(*param\option[3], 0, 1)
    clamp(*param\option[4], 0, 1)
    CopyMemory(*param\addr[0], *param\addr[1], *param\lg * *param\ht * 4)
    If blur_box_create_limit(*param\lg, *param\ht, *param\option[0], *param\option[1], *param\option[3])
      Protected *tempo = AllocateMemory(*param\lg * *param\ht * 4)
      If *tempo
        param\addr[0] = *tempo
        Protected passe = *param\option[2] - 1
        For passe = 0 To *param\option[2]
          MultiThread_MT(@blur_box_Guillossien_MT())
          CopyMemory(param\addr[0], param\addr[1], (*param\lg) * (*param\ht) * 4)
        Next
        FreeMemory(*tempo)
        If *param\mask And *param\option[4] : *param\mask_type = *param\option[4] - 1 : MultiThread_MT(@_mask()) : EndIf
      EndIf
      blur_box_free_limit()
    EndIf
  EndProcedure
  
Procedure Guillossien(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Blur
    param\name = "Guillossien"
    param\remarque = "Blur Box optimise"
    param\info[0] = "Rayon X"           ; Rayon horizontal
    param\info[1] = "Rayon Y"           ; Rayon vertical
    param\info[2] = "Nombre de passe"   ; Nombre d’itérations du filtre
    param\info[3] = "bord"              ; Mode bord ou boucle
    param\info[4] = "Masque binaire"    ; Option masque binaire
    param\info_data(0,0) = 1 : param\info_data(0,1) = 63 : param\info_data(0,2) = 1
    param\info_data(1,0) = 1 : param\info_data(1,1) = 63 : param\info_data(1,2) = 1
    param\info_data(2,0) = 1 : param\info_data(2,1) = 3   : param\info_data(2,2) = 1
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  blur_box_Guillossien(*param.parametre)
EndProcedure

;----------------

; ---------------------------------------------------
; Flou exponentiel (IIR) sur image ARGB32
; Implémentation 2 passes : horizontale + verticale
; Avec gestion multithread et passes multiples
; ---------------------------------------------------

; --- Extraction des canaux ARGB à partir d’un pixel 32 bits
; Chaque canal est décalé pour garder une précision sur 16 bits
Macro Blur_IIR_get_rgb_32(a,r,g,b)
  *pix32 = *dst32 + (pos * 4)        ; Position mémoire du pixel (ARGB32)
  a = (*pix32\l >> 16) & $ff00       ; Alpha
  r = (*pix32\l >>  8) & $ff00       ; Rouge
  g = (*pix32\l      ) & $ff00       ; Vert
  b = (*pix32\l <<  8) & $ff00       ; Bleu
EndMacro

; --- Mélange entre la valeur précédente et la valeur courante
; (Filtre IIR : valeur[n] = alpha*val[n] + (1-alpha)*val[n-1])
; Puis réécriture dans le pixel
Macro Blur_IIR_sp1_32()
  Blur_IIR_get_rgb_32(a1,r1,g1,b1)   ; Charger le pixel courant
  ; Mélange exponentiel
  a = (a * alpha + inv_alpha * a1) >> 8
  r = (r * alpha + inv_alpha * r1) >> 8
  g = (g * alpha + inv_alpha * g1) >> 8
  b = (b * alpha + inv_alpha * b1) >> 8
  ; Conversion en 8 bits par canal (avec arrondi)
  a1 = (a + 128 ) >> 8
  r1 = (r + 128 ) >> 8
  g1 = (g + 128 ) >> 8
  b1 = (b + 128 ) >> 8
  ; Reconstruction du pixel ARGB32
  *pix32\l = (a1 << 24) + (r1 << 16) + (g1 << 8) + b1
EndMacro

; --- Passe horizontale : balayage gauche→droite puis droite→gauche
Macro Blur_IIR_blurH()
  alpha = alphax : inv_alpha = inv_alphax 
  For y = start To stop - 1 
    pos = (y * w)                        ; Début de ligne
    mem = pos
    Blur_IIR_get_rgb_32(a, r, g, b)      ; Initialiser avec le 1er pixel
    ; Gauche → droite
    For x = 1 To w - 1 : pos = (mem + x) : Blur_IIR_sp1_32() : Next 
    ; Droite → gauche
    pos = (mem + (w - 1))
    Blur_IIR_get_rgb_32(a, r, g, b)
    For x = w - 2 To 0 Step -1 : pos = (y * w + x) : Blur_IIR_sp1_32() : Next
  Next
EndMacro

; --- Passe verticale : balayage haut→bas puis bas→haut
Macro Blur_IIR_blurV()
  alpha = alphay : inv_alpha = inv_alphay 
  For x = start To stop - 1 
    pos = x
    Blur_IIR_get_rgb_32(a, r, g, b)      ; Initialiser avec le 1er pixel
    ; Haut → bas
    For y = 1 To h - 1 : pos = (y * w + x) : Blur_IIR_sp1_32() : Next 
    ; Bas → haut
    pos = ((h - 1) * w + x)
    Blur_IIR_get_rgb_32(a, r, g, b)
    For y = h - 2 To 0 Step -1 : pos = (y * w + x) : Blur_IIR_sp1_32() : Next
  Next
EndMacro

; --- Initialisation commune à chaque passe (H ou V)
Macro Blur_IIR_sp_001(var,opt,opt2)
  Protected *cible  = *param\addr[1]           ; Image destination
  Protected w = *param\lg, h = *param\ht
  Protected a, r, g, b, a1, r1, g1.l, b1
  Protected alpha, inv_alpha, alphaX, inv_alphaX, alphaY, inv_alphaY
  Protected x, y, mem, start, stop, pos
  Protected *dst32.pixel32 = *cible
  Protected *pix32.pixel32
  ; Découpe du traitement en bandes selon le numéro de thread
  start = (var * *param\thread_pos) / *param\thread_max
  stop  = (var * (*param\thread_pos + 1)) / *param\thread_max
  If *param\thread_pos = (*param\thread_max - 1) : stop = var : EndIf
  ; Calcul des coefficients alpha pour le filtre IIR
  alpha#opt = Int((Exp(-2.3 / (*param\option[opt2] + 1.0))) * 256)
  inv_alpha#opt = 256 - alpha#opt
EndMacro

; --- Passe horizontale (appelée par un thread)
Procedure Blur_IIR_sp1(*param.parametre)
  Blur_IIR_sp_001(h, x , 0) ; Initialise pour horizontal
  Blur_IIR_blurh()          ; Exécute la passe horizontale
EndProcedure

; --- Passe verticale (appelée par un thread)
Procedure Blur_IIR_sp2(*param.parametre)
  Blur_IIR_sp_001(w, y , 1) ; Initialise pour vertical
  Blur_IIR_blurv()          ; Exécute la passe verticale
EndProcedure

; --- Gestion complète d’une séquence de flou
Procedure Blur_IIR_sp0(*param.parametre)
  *param\addr[0] = *param\source
  *param\addr[1] = *param\cible
  If *param\addr[0] = 0 Or *param\addr[1] = 0 : ProcedureReturn : EndIf
  clamp(*param\option[2], 1, 3) ; Nombre de passes limité à 1..3
  ; Copier l’image source → destination
  CopyMemory(*param\addr[0], *param\addr[1], (*param\lg * *param\ht * 4))
  Protected passe
  ; Boucle sur le nombre de passes
  For passe = 0 To *param\option[2] - 1
    MultiThread_MT(@Blur_IIR_sp1()) ; Passe horizontale multithreadée
    MultiThread_MT(@Blur_IIR_sp2()) ; Passe verticale multithreadée
  Next
  ; Application éventuelle d’un masque
  If *param\mask And *param\option[3] 
    *param\mask_type = *param\option[3] - 1
    MultiThread_MT(@_mask())
  EndIf
EndProcedure

; --- Interface avec le moteur de filtres
Procedure Blur_IIR(*param.parametre)
  If param\info_active
    ; Remplissage des infos du filtre (interface utilisateur)
    param\typ = #Filter_Type_Blur
    param\name = "Blur_IIR"
    param\remarque = "flou efficace et léger"
    param\info[0] = "Rayon X"        ; Rayon horizontal
    param\info[1] = "Rayon Y"        ; Rayon vertical
    param\info[2] = "Nombre de passe"; Nombre d’itérations
    param\info[3] = "Masque off/alpha/bin" ; Optionnel : appliquer un masque
    ; Valeurs min/max par option
    param\info_data(0,0) = 0 : param\info_data(0,1) = 100 : param\info_data(0,2) = 10
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 10
    param\info_data(2,0) = 1 : param\info_data(2,1) = 3   : param\info_data(2,2) = 1
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2   : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  ; Sinon → exécution réelle du filtre
  Blur_IIR_sp0(*param.parametre)
EndProcedure

;----------------

Procedure GaussianBlur_Conv_H_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected w = *param\lg
  Protected h = *param\ht
  Protected radius = *param\option[0]
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected yStart = (thread_pos * h) / thread_max
  Protected yEnd = ((thread_pos + 1) * h) / thread_max - 1
  Protected x, y, k, i, pos
  Protected r.f, g.f, b.f
  Protected r1, g1, b1, var.f
  Protected *srcPix.Pixel32, *dstPix.Pixel32
  Protected *kernel = *param\addr[2]
  Protected half = radius

  For y = yStart To yEnd
    For x = 0 To w - 1
      r = 0 : g = 0 : b = 0
      For k = -half To half
        i = x + k
        If i < 0 : i = 0 : ElseIf i >= w : i = w - 1 : EndIf
        pos = (y * w + i) << 2
        *srcPix = *src + pos
        getrgb(*srcPix\l, r1, g1, b1)
        var = PeekF(*kernel + (k + half) * SizeOf(Float))
        r + r1 * var
        g + g1 * var
        b + b1 * var
      Next
      pos = (y * w + x) << 2
      *dstPix = *dst + pos
      *dstPix\l = RGB(Int(r), Int(g), Int(b))
    Next
  Next
EndProcedure

Procedure GaussianBlur_Conv_V_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected w = *param\lg
  Protected h = *param\ht
  Protected radius = *param\option[0]
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected yStart = (thread_pos * h) / thread_max
  Protected yEnd = ((thread_pos + 1) * h) / thread_max - 1
  Protected x, y, k, i, pos
  Protected r.f, g.f, b.f
  Protected r1, g1, b1, var.f
  Protected *srcPix.Pixel32, *dstPix.Pixel32
  Protected *kernel = *param\addr[2]
  Protected half = radius

  For y = yStart To yEnd
    For x = 0 To w - 1
      r = 0 : g = 0 : b = 0
      For k = -half To half
        i = y + k
        If i < 0 : i = 0 : ElseIf i >= h : i = h - 1 : EndIf
        pos = (i * w + x) << 2
        *srcPix = *src + pos
        getrgb(*srcPix\l, r1, g1, b1)
        var = PeekF(*kernel + (k + half) * SizeOf(Float))
        r + r1 * var
        g + g1 * var
        b + b1 * var
      Next
      pos = (y * w + x) << 2
      *dstPix = *dst + pos
      *dstPix\l = RGB(Int(r), Int(g), Int(b))
    Next
  Next
EndProcedure

Procedure GaussianBlur_Conv(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Blur
    param\name = "GaussianBlur_Conv"
    param\remarque = "Gaussian Blur (convolution, séparable)"
    param\info[0] = "Rayon"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 50 : param\info_data(0,2) = 5
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2  : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf

  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf

  Protected total = *param\lg * *param\ht * 4
  Protected *tempo = AllocateMemory(total)
  If Not *tempo : ProcedureReturn : EndIf

  ; Générer le noyau
  Protected radius = *param\option[0]
  If radius < 1 : radius = 1 : EndIf
  Protected sigma.f = radius / 2.0
  Protected size = (radius * 2) + 1
  Protected *kernel = AllocateMemory(size * SizeOf(Float))
  If Not *kernel : FreeMemory(*tempo) : ProcedureReturn : EndIf

  Protected i, x
  Protected var.f, sum.f = 0.0
  For i = 0 To size - 1
    x = i - radius
    var = Exp(-x * x / (2 * sigma * sigma))
    PokeF(*kernel + i * SizeOf(Float), var)
    sum + var
  Next

  For i = 0 To size - 1
    var = PeekF(*kernel + i * SizeOf(Float))
    PokeF(*kernel + i * SizeOf(Float), var / sum)
  Next

  ; === Passe horizontale ===
  *param\addr[0] = *param\source  ; src
  *param\addr[1] = *tempo         ; dst temporaire
  *param\addr[2] = *kernel
  MultiThread_MT(@GaussianBlur_Conv_H_MT())

  ; === Passe verticale ===
  *param\addr[0] = *tempo         ; src temporaire
  *param\addr[1] = *param\cible   ; dst final
  MultiThread_MT(@GaussianBlur_Conv_V_MT())
  If *param\mask And *param\option[2] : *param\mask_type = *param\option[2] - 1 : MultiThread_MT(@_mask()) : EndIf
  ; Nettoyage
  FreeMemory(*tempo)
  FreeMemory(*kernel)
EndProcedure

;----------------

; ===== Motion Blur orienté (multithread) =====
Procedure MotionBlur_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected w = *param\lg
  Protected h = *param\ht
  Protected radius = *param\option[0]
  Protected angle.f = *param\option[1] * #PI / 180.0   ; option[1] = angle en degrés
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected yStart = (thread_pos * h) / thread_max
  Protected yEnd = ((thread_pos + 1) * h) / thread_max - 1
  If yStart > yEnd : ProcedureReturn : EndIf

  Protected x, y, k, xi, yi, pos
  Protected r.f, g.f, b.f
  Protected r1, g1, b1
  Protected *srcPix.Pixel32, *dstPix.Pixel32

  Protected dx.f = Cos(angle)
  Protected dy.f = Sin(angle)
  Protected size = (radius * 2) + 1
  Protected coeff.f = 1.0 / size

  For y = yStart To yEnd
    For x = 0 To w - 1
      r = 0 : g = 0 : b = 0
      For k = -radius To radius
        xi = Round(x + dx * k , #PB_Round_Nearest)
        yi = Round(y + dy * k , #PB_Round_Nearest)
        If xi < 0 : xi = 0 : ElseIf xi >= w : xi = w - 1 : EndIf
        If yi < 0 : yi = 0 : ElseIf yi >= h : yi = h - 1 : EndIf
        pos = (yi * w + xi) << 2
        *srcPix = *src + pos
        getrgb(*srcPix\l, r1, g1, b1)
        r + r1 * coeff
        g + g1 * coeff
        b + b1 * coeff
      Next
      pos = (y * w + x) << 2
      *dstPix = *dst + pos
      *dstPix\l = (Int(r) << 16) | (Int(g) << 8) | Int(b)
    Next
  Next
EndProcedure

; ===== Procédure principale Motion Blur orienté =====
Procedure MotionBlur(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Blur
    param\name = "MotionBlur"
    param\remarque = "Flou directionnel"
    param\info[0] = "Rayon"
    param\info[1] = "Angle"
    param\info[2] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 100 : param\info_data(0,2) = 10
    param\info_data(1,0) = 0 : param\info_data(1,1) = 360 : param\info_data(1,2) = 0
    param\info_data(2,0) = 0 : param\info_data(2,1) = 2 : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@MotionBlur_MT() , 2)
EndProcedure

;----------------

; ===== Anisotropic Blur orienté (multithread) =====
Procedure AnisotropicBlur_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected w = *param\lg
  Protected h = *param\ht
  Protected radius = *param\option[0]   ; longueur du blur (axe principal)
  Protected angle.f = *param\option[1] * #PI / 180.0
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected yStart = (thread_pos * h) / thread_max
  Protected yEnd = ((thread_pos + 1) * h) / thread_max - 1
  If yStart > yEnd : ProcedureReturn : EndIf

  Protected dx.f = Cos(angle)
  Protected dy.f = Sin(angle)

  Protected x, y, k, xi, yi, pos
  Protected r.f, g.f, b.f
  Protected r1, g1, b1
  Protected *srcPix.Pixel32, *dstPix.Pixel32

  Protected steps = radius * 2 + 1
  Protected coeff.f = 1.0 / steps

  For y = yStart To yEnd
    For x = 0 To w - 1
      r = 0 : g = 0 : b = 0
      For k = -radius To radius
        xi = Round(x + dx * k, #PB_Round_Nearest)
        yi = Round(y + dy * k, #PB_Round_Nearest)

        If xi < 0 : xi = 0 : ElseIf xi >= w : xi = w - 1 : EndIf
        If yi < 0 : yi = 0 : ElseIf yi >= h : yi = h - 1 : EndIf

        pos = (yi * w + xi) << 2
        *srcPix = *src + pos
        getrgb(*srcPix\l, r1, g1, b1)

        r + r1
        g + g1
        b + b1
      Next

      r * coeff : g * coeff : b * coeff
      clamp_rgb(r,g,b)

      pos = (y * w + x) << 2
      *dstPix = *dst + pos
      *dstPix\l = (Int(r) << 16) | (Int(g) << 8) | Int(b)
    Next
  Next
EndProcedure


; ===== Procédure principale =====
Procedure AnisotropicBlur(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Blur
    param\name = "AnisotropicBlur"
    param\remarque = "Gaussian anisotrope orienté (ellipse pivotée) Flou directionnel"
    param\info[0] = "Rayon"
    param\info[1] = "Angle"
    param\info[2] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 50 : param\info_data(0,2) = 5
    param\info_data(1,0) = 1 : param\info_data(1,1) = 180 : param\info_data(1,2) = 5
    param\info_data(2,0) = 0 : param\info_data(2,1) = 2 : param\info_data(2,2) = 0
    ProcedureReturn
  EndIf
  filter_start(@AnisotropicBlur_MT() , 2)
EndProcedure

;----------------

Procedure KuwaharaBlur_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected w = *param\lg
  Protected h = *param\ht
  Protected radius = *param\option[0]
  Protected sharpness.f = *param\option[1]/100.0
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected yStart = (thread_pos * h) / thread_max
  Protected yEnd = ((thread_pos + 1) * h) / thread_max - 1

  Protected x, y, k, minIndex
  Protected r.f, g.f, b.f, v, minVar

  ; --- summed-area tables pré-calculées pour l'itération ---
  Protected Dim sumR.f(w*h-1)
  Protected Dim sumG.f(w*h-1)
  Protected Dim sumB.f(w*h-1)
  Protected Dim sumSq.f(w*h-1)
  Protected *srcPix.Pixel32
  Protected r1, g1, b1

  ; --- calcul des tables cumulées une seule fois ---
  For y = 0 To h-1
    For x = 0 To w-1
      *srcPix = *src + ((y*w+x)<<2)
      getrgb(*srcPix\l, r1, g1, b1)
      If x=0 And y=0
        sumR(y*w+x)=r1 : sumG(y*w+x)=g1 : sumB(y*w+x)=b1 : sumSq(y*w+x)=r1*r1+g1*g1+b1*b1
      ElseIf x=0
        sumR(y*w+x)=sumR((y-1)*w+x)+r1
        sumG(y*w+x)=sumG((y-1)*w+x)+g1
        sumB(y*w+x)=sumB((y-1)*w+x)+b1
        sumSq(y*w+x)=sumSq((y-1)*w+x)+r1*r1+g1*g1+b1*b1
      ElseIf y=0
        sumR(y*w+x)=sumR(y*w+x-1)+r1
        sumG(y*w+x)=sumG(y*w+x-1)+g1
        sumB(y*w+x)=sumB(y*w+x-1)+b1
        sumSq(y*w+x)=sumSq(y*w+x-1)+r1*r1+g1*g1+b1*b1
      Else
        sumR(y*w+x)=sumR(y*w+x-1)+sumR((y-1)*w+x)-sumR((y-1)*w+x-1)+r1
        sumG(y*w+x)=sumG(y*w+x-1)+sumG((y-1)*w+x)-sumG((y-1)*w+x-1)+g1
        sumB(y*w+x)=sumB(y*w+x-1)+sumB((y-1)*w+x)-sumB((y-1)*w+x-1)+b1
        sumSq(y*w+x)=sumSq(y*w+x-1)+sumSq((y-1)*w+x)-sumSq((y-1)*w+x-1)+r1*r1+g1*g1+b1*b1
      EndIf
    Next
  Next

  Dim quadrant.f(4*5-1)
  Protected *dstPix.Pixel32

  ; --- traitement pixel par pixel ---
  For y=yStart To yEnd
    For x=0 To w-1
      For k=0 To 4*5-1 : quadrant(k)=0 : Next

      For k=0 To 3
        Protected x0,y0,x1,y1,count.f
        Protected sR0,sR1,sR2,sR3,sG0,sG1,sG2,sG3,sB0,sB1,sB2,sB3,sS0,sS1,sS2,sS3.f

        Select k
          Case 0
            x0 = Max_2(x-radius,0) : y0 = Max_2(y-radius,0) : x1=x : y1=y
          Case 1
            x0=x : y0 = Max_2(y-radius,0) : x1=Min_2(x+radius,w-1) : y1=y
          Case 2
            x0 = Max_2(x-radius,0) : y0=y : x1=x : y1=Min_2(y+radius,h-1)
          Case 3
            x0=x : y0=y : x1=Min_2(x+radius,w-1) : y1=Min_2(y+radius,h-1)
        EndSelect

        count=(x1-x0+1)*(y1-y0+1)

        sR0=sumR(y1*w+x1) : sG0=sumG(y1*w+x1) : sB0=sumB(y1*w+x1) : sS0=sumSq(y1*w+x1)
        sR1=0 : sG1=0 : sB1=0 : sS1=0
        sR2=0 : sG2=0 : sB2=0 : sS2=0
        sR3=0 : sG3=0 : sB3=0 : sS3=0
        If y0>0 : sR1=sumR((y0-1)*w+x1) : sG1=sumG((y0-1)*w+x1) : sB1=sumB((y0-1)*w+x1) : sS1=sumSq((y0-1)*w+x1) : EndIf
        If x0>0 : sR2=sumR(y1*w+(x0-1)) : sG2=sumG(y1*w+(x0-1)) : sB2=sumB(y1*w+(x0-1)) : sS2=sumSq(y1*w+(x0-1)) : EndIf
        If x0>0 And y0>0 : sR3=sumR((y0-1)*w+(x0-1)) : sG3=sumG((y0-1)*w+(x0-1)) : sB3=sumB((y0-1)*w+(x0-1)) : sS3=sumSq((y0-1)*w+(x0-1)) : EndIf

        quadrant(k*5+0)=sR0-sR1-sR2+sR3
        quadrant(k*5+1)=sG0-sG1-sG2+sG3
        quadrant(k*5+2)=sB0-sB1-sB2+sB3
        quadrant(k*5+3)=sS0-sS1-sS2+sS3
        quadrant(k*5+4)=count
      Next

      ; calcul variance et choix du quadrant
      minIndex=0
      minVar=quadrant(0*5+3)/quadrant(0*5+4)-Pow((quadrant(0*5+0)+quadrant(0*5+1)+quadrant(0*5+2))/quadrant(0*5+4),2)
      For k=1 To 3
        v=quadrant(k*5+3)/quadrant(k*5+4)-Pow((quadrant(k*5+0)+quadrant(k*5+1)+quadrant(k*5+2))/quadrant(k*5+4),2)
        If v<minVar : minVar=v : minIndex=k : EndIf
      Next

      ; interpolation sharpness
      *srcPix = *src + ((y*w+x)<<2)
      getrgb(*srcPix\l, r1, g1, b1)
      r = ((quadrant(minIndex*5+0)/quadrant(minIndex*5+4))*sharpness + r1*(1-sharpness))
      g = ((quadrant(minIndex*5+1)/quadrant(minIndex*5+4))*sharpness + g1*(1-sharpness))
      b = ((quadrant(minIndex*5+2)/quadrant(minIndex*5+4))*sharpness + b1*(1-sharpness))
      clamp_rgb(r,g,b)

      *dstPix = *dst + ((y*w+x)<<2)
      *dstPix\l = (Int(r)<<16) | (Int(g)<<8) | Int(b)
    Next
  Next
EndProcedure

Procedure KuwaharaBlur(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Blur
    param\name = "KuwaharaBlurFast"
    param\remarque = "Kuwahara blur non linéaire optimisé"

    ; --- Paramètre 0 : Rayon ---
    param\info[0] = "Rayon"
    param\info[1] = "Netteté des bords"
    param\info[2] = "Itérations"
    param\info[3] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 50  : param\info_data(0,2) = 2
    param\info_data(1,0) = 0 : param\info_data(1,1) = 100 : param\info_data(1,2) = 50
    param\info_data(2,0) = 1 : param\info_data(2,1) = 5   : param\info_data(2,2) = 1
    param\info_data(3,0) = 0 : param\info_data(3,1) = 2   : param\info_data(3,2) = 0
    ProcedureReturn
  EndIf

  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected iterations = *param\option[2]
  
  Protected *tempo , tmpSrc , tmpDst , i
  tmpDst = *param\cible
  If *param\source = *param\cible
    *tempo = AllocateMemory(*param\lg * *param\ht * 4)
    If Not *tempo : ProcedureReturn : EndIf
    CopyMemory(*param\source , *tempo , *param\lg * *param\ht * 4)
    tmpSrc = *tempo 
  Else
    tmpSrc = *param\source
  EndIf
  
  For i = 1 To iterations
    *param\addr[0] = tmpSrc
    *param\addr[1] = tmpDst
    MultiThread_MT(@KuwaharaBlur_MT())
    
    ; swap pour la prochaine itération
    If i < iterations
      Swap tmpSrc, tmpDst
    EndIf
  Next
  If *param\mask And *param\option[2] : *param\mask_type = *param\option[2] - 1 : MultiThread_MT(@_mask()) : EndIf
  If *tempo : FreeMemory(*tempo) : EndIf
EndProcedure

;----------------

; ===== Poisson Disk Blur multithread avec itérations et sharpness =====
Procedure PoissonDiskBlur_MT(*param.parametre)
  Protected *src = *param\addr[0]
  Protected *dst = *param\addr[1]
  Protected w = *param\lg
  Protected h = *param\ht
  Protected radius.f = *param\option[0]
  Protected samples = *param\option[1]
  Protected sharpness.f = *param\option[2]/100.0
  Protected thread_pos = *param\thread_pos
  Protected thread_max = *param\thread_max
  Protected yStart = (thread_pos * h) / thread_max
  Protected yEnd = ((thread_pos + 1) * h) / thread_max - 1

  Protected x, y, s, xi, yi, pos
  Protected r.f, g.f, b.f, r1, g1, b1
  Protected *srcPix.Pixel32, *dstPix.Pixel32

  ; Initialisation du générateur aléatoire pour ce thread
  Random((thread_pos+1)*1000)

  For y = yStart To yEnd
    For x = 0 To w-1
      r = 0 : g = 0 : b = 0

      For s = 0 To samples-1
        ; angle aléatoire en radians
        Protected angle.f = Random(360)*#PI/180.0
        ; distance aléatoire en flottant
        Protected dist.f = Random(radius)

        xi = x + Cos(angle) * dist
        yi = y + Sin(angle) * dist

        Clamp(xi, 0, w-1)
        Clamp(yi, 0, h-1)

        pos = (Int(yi)*w + Int(xi))<<2
        *srcPix = *src + pos
        getrgb(*srcPix\l, r1, g1, b1)
        r + r1 : g + g1 : b + b1
      Next

      r / samples : g / samples : b / samples

      ; interpolation sharpness
      *srcPix = *src + ((y*w+x)<<2)
      getrgb(*srcPix\l, r1, g1, b1)
      r = r*sharpness + r1*(1-sharpness)
      g = g*sharpness + g1*(1-sharpness)
      b = b*sharpness + b1*(1-sharpness)
      clamp_rgb(r,g,b)

      pos = (y*w + x)<<2
      *dstPix = *dst + pos
      *dstPix\l = (Int(r)<<16) | (Int(g)<<8) | Int(b)
    Next
  Next
EndProcedure

; ===== Procédure principale =====
Procedure PoissonDiskBlur(*param.parametre)
  If param\info_active
    param\typ = #Filter_Type_Blur
    param\name = "PoissonDiskBlur"
    param\remarque = "Flou Poisson Disk"

    param\info[0] = "Rayon"
    param\info[1] = "Échantillons"
    param\info[2] = "Force (sharpness)"
    param\info[3] = "Itérations"
    param\info[4] = "Masque binaire"
    param\info_data(0,0) = 1 : param\info_data(0,1) = 100 : param\info_data(0,2) = 5
    param\info_data(1,0) = 1 : param\info_data(1,1) = 64  : param\info_data(1,2) = 16
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100 : param\info_data(2,2) = 50
    param\info_data(3,0) = 1 : param\info_data(3,1) = 10  : param\info_data(3,2) = 1
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf

  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf

  Protected iterations = *param\option[3]
  
  Protected *tempo , tmpSrc , tmpDst , i
  tmpDst = *param\cible
  If *param\source = *param\cible
    *tempo = AllocateMemory(*param\lg * *param\ht * 4)
    If Not *tempo : ProcedureReturn : EndIf
    CopyMemory(*param\source , *tempo , *param\lg * *param\ht * 4)
    tmpSrc = *tempo 
  Else
    tmpSrc = *param\source
  EndIf
  
  For i = 1 To iterations
    *param\addr[0] = tmpSrc
    *param\addr[1] = tmpDst
    MultiThread_MT(@PoissonDiskBlur_MT())

    ; swap pour la prochaine itération
    If i < iterations
      Swap tmpSrc, tmpDst
    EndIf
  Next
  
  If *param\mask And *param\option[4] : *param\mask_type = *param\option[4] - 1 : MultiThread_MT(@_mask()) : EndIf
  If *tempo : FreeMemory(*tempo) : EndIf
EndProcedure

;----------------

; ======================================================
; Guided Filter Couleur simplifié (auto-guided, intégrales)
; ======================================================

; --- Integral image pour un canal (entier) ---
Procedure ComputeIntegral(*src, *integral, lg, ht)
  Protected x, y, pos, val, top, left, topleft
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      pos = (y * lg + x) * 4
      val = PeekL(*src + pos) & $FF
      top = 0 : left = 0 : topleft = 0
      If y>0 : top  = PeekL(*integral + ((y-1) * lg + x) *4 ) : EndIf
      If x>0 : left = PeekL(*integral + (y * lg + x - 1) *4 ) : EndIf
      If x>0 And y>0 : topleft = PeekL(*integral + ((y - 1)*lg + x - 1) * 4) : EndIf
      PokeL(*integral + pos, val + top + left - topleft)
    Next
  Next
EndProcedure

; --- Somme d'une fenêtre avec intégrale (entier) ---
Procedure.l BoxSum(*integral, lg, ht, x, y, r)
  Protected x0 = Max_2(0, x-r) - 1
  Protected y0 = Max_2(0, y-r) - 1
  Protected x1 = Min_2(lg-1, x+r)
  Protected y1 = Min_2(ht-1, y+r)
  Protected A.l=0, B.l=0, C.l=0, D.l=0
  If x0>=0 And y0>=0 : A = PeekL(*integral + (y0*lg+x0)*4) : EndIf
  If x0>=0           : B = PeekL(*integral + (y1*lg+x0)*4) : EndIf
  If y0>=0           : C = PeekL(*integral + (y0*lg+x1)*4) : EndIf
  D = PeekL(*integral + (y1*lg+x1)*4)
  ProcedureReturn D-B-C+A
EndProcedure

; --- Integral float pour I² ou a/b ---
Procedure ComputeIntegralFloat(*src, *integral, lg, ht)
  Protected x, y, pos
  Protected rowSum.f
  For y = 0 To ht-1
    rowSum = 0.0
    For x = 0 To lg-1
      pos = (y*lg + x)*4
      rowSum + PeekF(*src+pos)
      If y=0
        PokeF(*integral+pos, rowSum)
      Else
        PokeF(*integral+pos, rowSum + PeekF(*integral+pos-(lg<<2)))
      EndIf
    Next
  Next
EndProcedure

Procedure.f SumWindowFloat(*integral, lg, ht, x, y, r)
  Protected x0 = x-r-1, y0 = y-r-1, x1 = x+r, y1 = y+r
  If x0<0 : x0=-1 : EndIf
  If y0<0 : y0=-1 : EndIf
  If x1>lg-1 : x1=lg-1 : EndIf
  If y1>ht-1 : y1=ht-1 : EndIf
  Protected A.f=0.0, B.f=0.0, C.f=0.0, D.f=0.0
  If x0>=0 And y0>=0 : A=PeekF(*integral + (y0*lg+x0)*4) : EndIf
  If x0>=0           : B=PeekF(*integral + (y1*lg+x0)*4) : EndIf
  If y0>=0           : C=PeekF(*integral + (y0*lg+x1)*4) : EndIf
  D = PeekF(*integral + (y1*lg+x1)*4)
  ProcedureReturn D-B-C+A
EndProcedure


Macro GuidedFilterColor_SP1_MT(col1 , col2 , var)
      meanI  = BoxSum(*int#col1, lg, ht, x, y, radius)*invArea
      meanII = SumWindowFloat(*int#col2, lg, ht, x, y, radius)*invArea
      varI = meanII - meanI*meanI
      If varI < 0 : varI = 0 : EndIf
      a = varI / (varI + eps)
      b = meanI - a * meanI
      val = PeekL(*I_#col1 + pos) & $FF
      var = a * val + b
EndMacro

Procedure GuidedFilterColor_SP2_MT(*param.parametre)
  Protected lg  = *param\lg
  Protected ht  = *param\ht
  Protected thread_start = (*param\thread_pos * ht) / *param\thread_max
  Protected thread_stop = (((*param\thread_pos + 1) * ht) / *param\thread_max) - 1
  If thread_stop >= ht : thread_stop = ht - 1 : EndIf
  Protected *I_R = *param\addr[3]
  Protected *I_G = *param\addr[4]
  Protected *I_B = *param\addr[5]
  Protected *tmpR = *param\addr[12]
  Protected *tmpG = *param\addr[13]
  Protected *tmpB = *param\addr[14]
  Protected x , y , pos , var
  For y = thread_start To thread_stop
    For x = 0 To lg - 1
      pos = (y * lg + x) * 4
      var = PeekL(*I_R + pos) & $FF
      PokeF(*tmpR + pos, var * var)
      var = PeekL(*I_G + pos) & $FF
      PokeF(*tmpG + pos, var * var)
      var = PeekL(*I_B + pos) & $FF
      PokeF(*tmpB + pos, var * var)
    Next
  Next
EndProcedure


; --- Guided Filter couleur simplifié ---
Procedure GuidedFilterColor_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]
  Protected eps.f = *param\option[1]
  Protected invArea.f = 1.0 / ((2 * radius + 1) * (2 * radius + 1))
  Protected x, y, pos
  Protected meanI.f, meanII.f, varI.f, a.f, b.f, q.f
  Protected rc, gc, bc
  Protected val.l , var

  ; Pointeurs
  Protected *I_R   = *param\addr[3], *I_G   = *param\addr[4] , *I_B   = *param\addr[5]
  Protected *intR  = *param\addr[6], *intG  = *param\addr[7] , *intB  = *param\addr[8]
  Protected *intRR = *param\addr[9], *intGG = *param\addr[10], *intBB = *param\addr[11]
  
    Protected thread_start = (*param\thread_pos * ht) / *param\thread_max
    Protected thread_stop = (((*param\thread_pos + 1) * ht) / *param\thread_max) - 1
    
  ; 3) calcul final q = a*I + b (auto-guided)
  For y = thread_start To thread_stop
    For x = 0 To lg - 1
      pos=(y * lg + x) * 4
      GuidedFilterColor_SP1_MT(r , rr , rc)
      GuidedFilterColor_SP1_MT(g , gg , gc)
      GuidedFilterColor_SP1_MT(b , bb , bc)
      clamp_rgb(rc , gc, bc)
      PokeL(*param\addr[1] + pos, (rc<<16)|(gc<<8)|bc)
    Next
  Next
EndProcedure

; --- Split canaux ---
Procedure GuidedFilterColor_SP0_MT(*param.parametre)
  Protected *source.Pixel32
  Protected total=*param\lg * *param\ht
  Protected start = (*param\thread_pos * total) / *param\thread_max
  Protected stop = (((*param\thread_pos + 1) * total) / *param\thread_max) - 1
  Protected i , pos , r , g , b
  For i = start To stop
    pos = i << 2
    *source =*param\addr[0] + pos
    getrgb( *source\l , r , g , b)
    PokeA(*param\addr[3] + pos , r)
    PokeA(*param\addr[4] + pos , g)
    PokeA(*param\addr[5] + pos , b)
  Next
EndProcedure

; --- Wrapper ---
Procedure GuidedFilterColor(*param.parametre)
  If *param\info_active
    *param\name="GuidedFilterColor"
    *param\typ=#Filter_Type_Blur
    *param\remarque="Guided Filter couleur (exact)"
    *param\info[0]="Radius"
    *param\info[1]="Epsilon"
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 50   : *param\info_data(0,2) = 4
    *param\info_data(1,0) = 1 : *param\info_data(1,1) = 1000 : *param\info_data(1,2) = 50
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected lg = *param\lg
  Protected ht = *param\ht
  
  Protected size = lg * ht * 4
  Protected i , err = 0
  For i = 3 To 11 : *param\addr[i] = AllocateMemory(size) : If Not *param\addr[i] : err = 1 : EndIf : Next
  If err = 1 : For i = 3 To 11 : If *param\addr[i] : FreeMemory(*param\addr[i]) : EndIf : Next : ProcedureReturn : EndIf
  
  *param\addr[0] = *param\source
  MultiThread_MT(@GuidedFilterColor_SP0_MT())
  
  ; Pointeurs
  Protected *I_R   = *param\addr[3], *I_G   = *param\addr[4] , *I_B   = *param\addr[5]
  Protected *intR  = *param\addr[6], *intG  = *param\addr[7] , *intB  = *param\addr[8]
  Protected *intRR = *param\addr[9], *intGG = *param\addr[10], *intBB = *param\addr[11]
  
  ; 1) intégrales I
  ComputeIntegral(*I_R, *intR, lg, ht)
  ComputeIntegral(*I_G, *intG, lg, ht)
  ComputeIntegral(*I_B, *intB, lg, ht)
  
  ; 2) intégrales float I²  
  *param\addr[12] = AllocateMemory(size)
  *param\addr[13] = AllocateMemory(size)
  *param\addr[14] = AllocateMemory(size)
  MultiThread_MT(@GuidedFilterColor_SP2_MT())
  ComputeIntegralFloat(*param\addr[12], *intRR, lg, ht)
  ComputeIntegralFloat(*param\addr[13], *intGG, lg, ht)
  ComputeIntegralFloat(*param\addr[14], *intBB, lg, ht)
  FreeMemory(*param\addr[12])
  FreeMemory(*param\addr[13])
  FreeMemory(*param\addr[14])
  
  
  *param\addr[0] = *param\source 
  *param\addr[1] = *param\cible    
  MultiThread_MT(@GuidedFilterColor_MT())
  ;filter_start(@GuidedFilterColor_MT() , 2)
  
  For i = 3 To 11 : FreeMemory(*param\addr[i]) : Next
EndProcedure

;----------------

Macro HeatDiffusionAnisoBlur_sp1(var)
  cN = PeekF(*addr3 + Abs(N#var - var) * 4)
  cS = PeekF(*addr3 + Abs(S#var - var) * 4)
  cW = PeekF(*addr3 + Abs(W#var - var) * 4)
  cE = PeekF(*addr3 + Abs(E#var - var) * 4)
  var + lambda * (cN * (N#var - var) + cS * (S#var - var) + cW * (W#var - var) + cE * (E#var - var))
EndMacro

Procedure HeatDiffusionAnisoBlur(*param.parametre)
  Protected *source.Pixel32
  Protected *cible.Pixel32 
  Protected *addr0 = *param\addr[0]
  Protected *addr1 = *param\addr[1]
  Protected *addr3 = *param\addr[3]
  Protected lg  = *param\lg
  Protected ht = *param\ht
  Protected lambda.f = 0.2
  Protected k.f = 10.0
  If *param\option[1] > 0 : k = *param\option[1] : EndIf
  If *param\option[2] > 0 : lambda = *param\option[2]/100.0 : EndIf
  Protected x, y, r, g, b , pos , pos1
  Protected Nr , Ng ,Nb , Sr , Sg , Sb , Wr , Wg , Wb , Er , Eg , Eb 
  Protected cN.f, cS.f, cW.f, cE.f
  Protected startY = (*param\thread_pos * ht) / *param\thread_max
  Protected stopY  = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  If stopY >= ht : stopY = ht - 1 : EndIf
  For y = startY To stopY
    For x = 0 To lg - 1
      pos = (y * lg + x) << 2
      pos1 = *addr0 + pos
      *source = pos1
      getrgb(*source\l, r, g, b)
      If y > 0 : *source = pos1 - lg * 4 : getrgb(*source\l, nr, ng, nb) : Else : nr = r : ng = g : nb =b : EndIf
      If y < ht - 1 : *source = pos1 + lg * 4 : getrgb(*source\l, sr, sg, sb) : Else : sr = r : sg = g : sb =b : EndIf
      If x > 0 : *source = pos1 - 4 : getrgb(*source\l, wr, wg, wb) : Else : wr = r : wg = g : wb =b : EndIf
      If x < lg - 1 : *source = pos1 + 4 : getrgb(*source\l, er, eg, eb) : Else : er = r : eg = g : eb =b : EndIf
      ; === DIFFUSION ANISOTROPE ===
      HeatDiffusionAnisoBlur_sp1(r)
      HeatDiffusionAnisoBlur_sp1(g)
      HeatDiffusionAnisoBlur_sp1(b)
      clamp_rgb(r, g, b)
      *cible = *addr1 + pos
      *cible\l = (r << 16) | (g << 8) | b
    Next
  Next
EndProcedure

Procedure HeatDiffusionBlur(*param.parametre)
  If *param\info_active
    *param\name = "HeatDiffusionAnisotropic"
    *param\typ = #Filter_Type_Blur
    *param\remarque = "Flou anisotrope (Perona-Malik)"
    *param\info[0] = "Iterations"
    *param\info[1] = "Contraste K"
    *param\info[2] = "Lambda (%)"
    *param\info[3] = "Masque binaire"
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 50  : *param\info_data(0,2) = 50
    *param\info_data(1,0) = 1 : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 20
    *param\info_data(2,0) = 1 : *param\info_data(2,1) = 25  : *param\info_data(2,2) = 25
    *param\info_data(3,0) = 0 : *param\info_data(3,1) = 2   : *param\info_data(3,2) = 0
    ProcedureReturn
  EndIf
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  Protected *tempo = AllocateMemory(*param\lg * *param\ht * 4)
  If Not *tempo : ProcedureReturn : EndIf
  *param\addr[3] = AllocateMemory(*param\lg * *param\ht * 4)
  If Not *param\addr[3] : ProcedureReturn : EndIf
  Protected i , var.f
  For i = 0 To 255
    var = Exp( - Pow(i / *param\option[1], 2))
    PokeF(*param\addr[3] + i * 4 , var)
  Next
  CopyMemory(*param\source, *tempo, *param\lg * *param\ht * 4)
  *param\addr[0] = *tempo
  *param\addr[1] = *param\cible
  For i = 1 To *param\option[0]
    MultiThread_MT(@HeatDiffusionAnisoBlur())
    Swap *param\addr[0], *param\addr[1]
  Next
  If *param\mask And *param\option[3] : *param\mask_type = *param\option[3] - 1 : MultiThread_MT(@_mask()) : EndIf
  If *tempo : FreeMemory(*tempo) : EndIf
  If *param\addr[3] : FreeMemory(*param\addr[3]) : EndIf
EndProcedure

;----------------

Procedure OpticalBlur_MT(*param.parametre)
  Protected *source.Pixel32
  Protected *cible.Pixel32 
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected radius = *param\option[0]
  Protected x , y , ix , iy
  Protected rSum , gSum , bSum
  Protected count
  Protected pos , r , g , b , r1 , g1 , b1
  Protected dx , dy
  Protected thread_startY = (*param\thread_pos * ht) / *param\thread_max
  Protected thread_stopY  = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  If thread_stopY >= ht : thread_stopY = ht - 1 : EndIf
  For y = thread_startY To thread_stopY
    For x = 0 To lg - 1
      rSum=0 : gSum=0 : bSum=0 : count=0
      pos = (y * lg + x) * 4
      For iy = -radius To radius
        For ix = -radius To radius
          dx = ix : dy = iy
          If dx * dx + dy * dy <= radius * radius
            If (x + ix) >= 0 And (x + ix) < lg And (y + iy) >= 0 And (y + iy) < ht
              *source = *param\addr[0] + ((y + iy) * lg + (x + ix)) * 4
              getrgb(*source\l , r1 , g1 , b1)
              rSum + r1 : gSum + g1 : bSum + b1
              count + 1
            EndIf
          EndIf
        Next
      Next
      If count>0
        r = rSum / count
        g = gSum / count
        b = bSum / count
      Else
        *source = *param\addr[0] + pos
        getrgb(*source\l , r1 , g1 , b1)
      EndIf
      *cible = *param\addr[1] + pos
      *cible\l = (r << 16) | (g << 8) | b
    Next
  Next
EndProcedure

Procedure OpticalBlur(*param.parametre)
  If *param\info_active
    *param\name = "OpticalBlur"
    *param\typ = #Filter_Type_Blur
    *param\remarque = "Flou optique simulant un objectif"
    *param\info[0] = "Radius"
    *param\info[1] = "Nombre de passe"
    *param\info[2] = "Masque binaire"
    *param\info_data(0,0)=1 : *param\info_data(0,1)=10 : *param\info_data(0,2)=1
    *param\info_data(1,0)=1 : *param\info_data(1,1)=10 : *param\info_data(1,2)=1
    *param\info_data(2,0)=0 : *param\info_data(2,1)=2  : *param\info_data(2,2)=0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  Protected *tempo = AllocateMemory(*param\lg * *param\ht * 4)
  If Not *tempo : ProcedureReturn : EndIf
  
  CopyMemory(*param\source, *tempo, *param\lg * *param\ht * 4)
  *param\addr[0] = *tempo
  *param\addr[1] = *param\cible
  Protected i
  For i = 1 To *param\option[1]
    MultiThread_MT(@OpticalBlur_MT())
    Swap *param\addr[0], *param\addr[1]
  Next
  If *param\mask And *param\option[2] : *param\mask_type = *param\option[2] - 1 : MultiThread_MT(@_mask()) : EndIf
  If *tempo : FreeMemory(*tempo) : EndIf
  
EndProcedure

;----------------


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 949
; FirstLine = 931
; Folding = -------------
; EnableXP
; DPIAware