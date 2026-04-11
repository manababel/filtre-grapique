; Sélection du noyau de convolution 3x3 selon l'option choisie
Procedure convolution3x3_select(opt)
  Select opt
      ;### Blur/smooth
    Case 0 : Restore K3x3_GAUSSIANBLUR_2
    Case 1 : Restore K3x3_GAUSSIANBLUR_3
    Case 2 : Restore K3x3_GAUSSIANBLUR_4
    Case 3 : Restore K3x3_GAUSSIANBLUR_6
    Case 4 : Restore K3x3_GAUSSIANBLUR_8
    Case 5 : Restore K3x3_GAUSSIANBLUR_10
    Case 6 : Restore K3x3_MOTIONBLUR
    Case 7 : Restore K3x3_MOTIONBLUR_RIGHT 
    Case 8 : Restore K3x3_MOTIONBLUR_LEFT
    Case 9 : Restore K3x3_SMOOTH_1
    Case 10 : Restore K3x3_SMOOTH_2
    Case 11 : Restore K3x3_SMOOTH_3
    Case 12 : Restore K3x3_SMOOTH_4
    Case 13 : Restore K3x3_MEANSMOOTH
      ;### Sharpen
    Case 14 : Restore K3x3_SHARPEN_15
    Case 15 : Restore K3x3_SHARPEN_20
    Case 16 : Restore K3x3_SHARPEN_30
    Case 17 : Restore K3x3_SHARPEN_50
    Case 18 : Restore K3x3_SHARPEN_MEANREMOVAL
      ;### Emboss/raise/extrude
      ;#K3x3_OUTLINE
    Case 19 : Restore K3x3_EMBOSS_v1
    Case 20 : Restore K3x3_EMBOSS_v2
    Case 21 : Restore K3x3_EMBOSS_v3
    Case 22 : Restore K3x3_EMBOSS_v4
    Case 23 :  Restore K3x3_RAISED
      ;### Edge detect/enhance
    Case 24 : Restore K3x3_EDGEDETECT_HV
    Case 25 : Restore K3x3_EDGEDETECT_H
    Case 26 : Restore K3x3_EDGEDETECT_V
    Case 27 : Restore K3x3_EDGEDETECT_DIFFERENTIAL
    Case 28 : Restore K3x3_EDGEENHANCE_H
    Case 29 : Restore K3x3_EDGEENHANCE_V
    Case 30 : Restore K3x3_PREWITT_H
    Case 31 : Restore K3x3_PREWITT_V
    Case 32 : Restore K3x3_SOBEL_H
    Case 33 : Restore K3x3_SOBEL_V
    Case 34 : Restore K3x3_SOBELFELDMAN_H
    Case 35 : Restore K3x3_SOBELFELDMAN_V
    Case 36 : Restore K3x3_LAPLACE
    Case 37 : Restore K3x3_LAPLACE_INV 
    Case 38 : Restore K3x3_LAPLACE_DIAGONAL
    Case 39 : Restore K3x3_SCHARR_H
    Case 40 : Restore K3x3_SCHARR_V
    Case 41 : Restore K3x3_EDGE360_KEYA 
    Case 42 : Restore K3x3_GRADIENTDETECT_V
    Case 43 : Restore K3x3_GRADIENTDETECT_H    
    Case 44 : Restore K3x3_EDGE_ENHANCE_MORE
    Case 45 : Restore K3x3_HIGHPASS
    Case 46 : Restore K3x3_EMBOSS_DIAGONAL
    Case 47 : Restore K3x3_SKETCH
    Case 48 : Restore K3x3_GLOW_EDGES  
    Case 49 : Restore K3x3_SHARPEN_EXTREME 
  EndSelect
EndProcedure

Procedure convolution3x3Thread(*param.parametre)
  ; Récupération des pointeurs source et destination, ainsi que des dimensions de l'image
  Protected *src = *param\source
  Protected *dst = *param\cible
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected gray = *param\option[0]
  ; Récupération des coefficients de convolution, échelle et offset
  Protected scale.w = *param\convolution3[9]
  Protected offset.w = *param\convolution3[10]
  ; Si scale est différent de 0, calcul d'un facteur d'échelle
  If scale <> 0 : scale = 256 / scale : EndIf
  ; Récupération d'options diverses (ex : facteur de multiplication et alpha)
  Protected mul.f = *param\option[0] * 0.1
  Protected alpha = param\option[5]
  clamp(mul,0,100)
  Clamp(alpha,0,255)
  ; Pointeurs vers pixels source et destination de type Pixel32 (probablement 32 bits)
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  ; Variables temporaires pour les coordonnées et les composantes de couleur
  Protected x, y, i
  Protected r, g, b, p, px
  ; Tableaux pour stocker les composantes RGB des 9 pixels voisins
  Protected Dim r3(8)
  Protected Dim g3(8)
  Protected Dim b3(8)
  ; Tableau pour stocker les coefficients de convolution
  Protected Dim conv(8)
  ; Copie des coefficients de convolution depuis les paramètres
  For i = 0 To 8 : conv(i) = *param\convolution3[i] : Next
  ; Calcul de la plage de traitement pour ce thread (portion de l'image en hauteur)
  Protected startPos = (*param\thread_pos * ht) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * ht) / *param\thread_max
  ; Limitation des bornes pour ne pas dépasser les bords (bordure d’un pixel)
  If startPos < 1 : startPos = 1 : EndIf
  If endPos > (ht-2) : endPos = ht - 2 : EndIf
  ; Parcours de la portion d'image attribuée au thread
  For y = startPos To endPos
    For x = 1 To lg - 2
      ; Lecture des 9 pixels voisins (3x3 autour du pixel courant)
      *srcPixel = (*src + ((y + -1) * lg + (x + -1)) * 4)
      getrgb(*srcPixel\l , r3(0) , g3(0) , b3(0) )
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l , r3(1) , g3(1) , b3(1) )
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l , r3(2) , g3(2) , b3(2) )
      *srcPixel = (*src + ((y + 0) * lg + (x + -1)) * 4)
      getrgb(*srcPixel\l , r3(3) , g3(3) , b3(3) )
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l , r3(4) , g3(4) , b3(4) )
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l , r3(5) , g3(5) , b3(5) )
      *srcPixel = (*src + ((y + 1) * lg + (x + -1)) * 4)
      getrgb(*srcPixel\l , r3(6) , g3(6) , b3(6) )
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l , r3(7) , g3(7) , b3(7) )
      *srcPixel = *srcPixel + 4
      getrgb(*srcPixel\l , r3(8) , g3(8) , b3(8) )
      ; Initialisation des accumulations des composantes RGB
      r = 0 : g = 0 : b = 0
      ; Application du filtre convolutionnel (somme pondérée des voisins)
      For i = 0 To 8
        r + r3(i) * conv(i)
        g + g3(i) * conv(i)
        b + b3(i) * conv(i)
      Next
      ; Application de l'échelle et de l'offset, puis décalage pour normaliser
      r = (r * scale) >> 8 + offset
      g = (g * scale) >> 8 + offset
      b = (b * scale) >> 8 + offset
      ; Limitation des valeurs RGB dans la plage valide [0..255]
      Clamp_RGB(r, g, b)
      ; Écriture du pixel traité dans l'image destination
      *dstPixel = *dst + (y * lg + x) * 4
      If gray :
        r = (r+g+b)/3
        *dstPixel\l = r<<16 +  r<<8  + r
      Else
        *dstPixel\l = r<<16 +  g<<8  + b
      EndIf
      
    Next
  Next
EndProcedure

; ----------------------------------------------------------------------------------
; Macro multithread pour lancer la procédure donnée sur N threads
Macro convolution3x3_MT(proc)
  For i = 0 To thread - 1 : tr(i) = 0 : Next
  For i = 0 To thread - 1
    CopyStructure(@param, @dim_param(i), parametre)
    dim_param(i)\thread_pos = i
    dim_param(i)\thread_max = thread
    While tr(i) = 0 : tr(i) = CreateThread(proc, @dim_param(i)) : Wend
  Next
  For i = 0 To thread - 1 : If IsThread(tr(i)) > 0 : WaitThread(tr(i)) : EndIf : Next
EndMacro

; Procédure principale pour appliquer un effet de balance RGB sur une image ARGB 32 bits
Procedure convolution3x3(*param.parametre)
  ; Récupération des pointeurs vers les buffers source, destination, et masque
  Protected *source = *param\source
  Protected *cible  = *param\cible
  Protected *mask   = *param\mask
  Protected i
  ; Gestion des informations d’aide / description de l’effet
  If *param\info_active
    If *param\info_active = 1
      *param\typ = #Filter_Type_Convolution
      ; Remplissage des informations descriptives pour l'interface utilisateur ou documentation
      *param\name = "convolution3x3"
      param\info[0] = "Balance RGB"
      param\info[1] = "\option[0] : Rouge (0-255)"
      param\info[2] = "\option[1] : Vert (0-255)"
      param\info[3] = "\option[2] : Bleu (0-255)"
      param\info[4] = "\option[3] : Masque (0 = progressif, 1 = binaire)"
      ProcedureReturn
    ; Si on reçoit un code inférieur à 52, sélectionne un filtre prédéfini et charge ses paramètres
    ElseIf *param\info_active < 52
      convolution3x3_select(*param\info_active - 2)
      Read.s *param\name
      For i = 0 To 10
        Read.w *param\convolution3[i]
      Next
    Else
      ; Cas par défaut : on vide le nom du filtre (pas d’info)
      *param\name = ""
    EndIf
    ProcedureReturn
  EndIf
  ; Vérification de la validité des pointeurs source et destination
  If *source = 0 Or *cible = 0 : ProcedureReturn : EndIf
  ; Détermination du nombre de threads à utiliser en fonction du nombre de CPU disponibles
  Protected thread = CountCPUs(#PB_System_CPUs)
  ; Clamp entre 1 et 128 threads maximum
  If thread < 1 : thread = 1
  ElseIf thread > 128 : thread = 128
  EndIf
  ; Allocation d’un tableau pour gérer les threads (même si non utilisé ici explicitement)
  Protected Dim tr(thread)
  ; 1) Appliquer la convolution RGB (balance) en mode multithread
  convolution3x3_MT(@convolution3x3Thread())
  ; 2) Si un masque est actif, applique le masque en mode multithread avec une autre procédure
  If *mask <> 0
    ; Type de masque : progressif ou binaire, défini par option[3]
    *param\mask_type = *param\option[1]
    convolution3x3_MT(@_mask())
  EndIf
  ; Libération du tableau de threads
  FreeArray(tr())
EndProcedure

;-data convolution
DataSection
  K3x3_GAUSSIANBLUR_2:
  Data.s "GAUSSIANBLUR_2"
  Data.w 1, 2, 1
  Data.w 2, 2, 2
  Data.w 1, 2, 1
  Data.w 14
  Data.w 0
  K3x3_GAUSSIANBLUR_3:
  Data.s "GAUSSIANBLUR_3"
  Data.w 1, 2, 1
  Data.w 2, 3, 2
  Data.w 1, 2, 1
  Data.w 15
  Data.w 0
  K3x3_GAUSSIANBLUR_4: ;Standard 3x3 gaussian model
  Data.s "GAUSSIANBLUR_4"
  Data.w 1, 2, 1
  Data.w 2, 4, 2
  Data.w 1, 2, 1
  Data.w 16
  Data.w 0
  K3x3_GAUSSIANBLUR_6:
  Data.s "GAUSSIANBLUR_6"
  Data.w 1, 2, 1
  Data.w 2, 6, 2
  Data.w 1, 2, 1
  Data.w 18
  Data.w 0
  K3x3_GAUSSIANBLUR_8:
  Data.s "GAUSSIANBLUR_8"
  Data.w 1, 2, 1
  Data.w 2, 8, 2
  Data.w 1, 2, 1
  Data.w 20
  Data.w 0
  K3x3_GAUSSIANBLUR_10:
  Data.s "GAUSSIANBLUR_10"
  Data.w 1, 2,  1
  Data.w 2, 10, 2
  Data.w 1, 2,  1
  Data.w 22
  Data.w 0   
  K3x3_MOTIONBLUR_RIGHT:
  Data.s "MOTIONBLUR_RIGHT"
  Data.w 0, 0, 1
  Data.w 0, 0, 0
  Data.w 1, 0, 0
  Data.w 2
  Data.w 0
  K3x3_MOTIONBLUR_LEFT:
  Data.s "MOTIONBLUR_LEFT"
  Data.w 1, 0, 0
  Data.w 0, 0, 0
  Data.w 0, 0, 1
  Data.w 2
  Data.w 0
  K3x3_MOTIONBLUR:
  Data.s "MOTIONBLUR"
  Data.w 1, 0, 0
  Data.w 0, 1, 0
  Data.w 0, 0, 1
  Data.w 3
  Data.w 0
  K3x3_SMOOTH_1:
  Data.s "SMOOTH_1"
  Data.w 1,   1,    1
  Data.w 1,   5,    1
  Data.w 1,   1,    1
  Data.w 13
  Data.w 0
  K3x3_SMOOTH_2:
  Data.s "SMOOTH_2"
  Data.w 1,   1,    1
  Data.w 1,   4,    1
  Data.w 1,   1,    1
  Data.w 12
  Data.w 0 
  K3x3_SMOOTH_3:
  Data.s "SMOOTH_3"
  Data.w 1,   1,    1
  Data.w 1,   3,    1
  Data.w 1,   1,    1
  Data.w 11
  Data.w 0 
  K3x3_SMOOTH_4:
  Data.s "SMOOTH_4"
  Data.w 1,   1,    1
  Data.w 1,   2,    1
  Data.w 1,   1,    1
  Data.w 10
  Data.w 0
  K3x3_MEANSMOOTH: ;aka Average/Mean/Box Blur
  Data.s "MEANSMOOTH"
  Data.w 1,   1,    1
  Data.w 1,   1,    1
  Data.w 1,   1,    1
  Data.w 9
  Data.w 0
  ;### Sharpen
  K3x3_SHARPEN_15:
  Data.s "SHARPEN_15"
  Data.w  0,   -1,   0
  Data.w -1,  5,    -1
  Data.w  0,   -1,   0
  Data.w 1
  Data.w 0
  K3x3_SHARPEN_20:
  Data.s "SHARPEN_20"
  Data.w  0,   1,   0
  Data.w 1,   -3   ,1
  Data.w  0,   1,   0
  Data.w 1
  Data.w 0
  K3x3_SHARPEN_30:
  Data.s "SHARPEN_30"
  Data.w  -1,  -1,   -1
  Data.w -1,   9,  -1
  Data.w  -1,  -1,   -1
  Data.w 1
  Data.w 0 
  K3x3_SHARPEN_50:
  Data.s "SHARPEN_50"
  Data.w  1,  -2,   1
  Data.w -2,   5,  -2
  Data.w  1,  -2,   1
  Data.w 1
  Data.w 0
  K3x3_SHARPEN_MEANREMOVAL:      ;aka Mean Removal
  Data.s "SHARPEN_MEANREMOVAL"
  Data.w -1,  -1, -1
  Data.w -1,   9, -1
  Data.w -1,  -1, -1
  Data.w 1
  Data.w 0 
  ;### Emboss/raise/extrude
  K3x3_EXTRUDE:
  Data.s "EXTRUDE"
  Data.w 1,   1,    1
  Data.w 1,   -7,    1
  Data.w 1,   1,    1
  Data.w 1
  Data.w 0   
  K3x3_EMBOSS_v1:
  Data.s "EMBOSS_v1"
  Data.w -1,  -1,  0
  Data.w -1,   0,  1
  Data.w  0,   1,  1
  Data.w 9
  Data.w 128
  K3x3_EMBOSS_v2:
  Data.s "EMBOSS_v2"
  Data.w  0, 0, 0
  Data.w -1, 0, 1
  Data.w  0, 0, 0
  Data.w 9
  Data.w 128
  K3x3_EMBOSS_v3:
  Data.s "EMBOSS_v3"
  Data.w -1, -1,  0
  Data.w -1,  0,  1
  Data.w  0,  1,  1
  Data.w 9
  Data.w 128
  K3x3_EMBOSS_v4:
  Data.s "EMBOSS_v4"
  Data.w -2, -1,  0
  Data.w -1,  1,  1
  Data.w 0,  1,  2
  Data.w 9
  Data.w 128   
  K3x3_RAISED:
  Data.s "RAISED"
  Data.w 0, 0, -2
  Data.w 0, 2, 0
  Data.w 1, 0, 0
  Data.w 1
  Data.w 0
  ;### Edge detect/enhance
  K3x3_EDGEDETECT_HV:  
  Data.s "EDGEDETECT_HV"
  Data.w 0,  1,  0
  Data.w 1, -4,  1
  Data.w 0,  1,  0
  Data.w 1
  Data.w 0
  K3x3_EDGEDETECT_H:
  Data.s "EDGEDETECT_H"
  Data.w  0,  0,  0
  Data.w -1,  2, -1
  Data.w 0,  0,  0
  Data.w 1
  Data.w 0
  K3x3_EDGEDETECT_V:
  Data.s "EDGEDETECT_V"
  Data.w 0, -1, 0
  Data.w 0,  2, 0
  Data.w 0, -1, 0
  Data.w 1
  Data.w 0
  K3x3_EDGEDETECT_DIFFERENTIAL:
  Data.s "EDGEDETECT_DIFFERENTIAL"
  Data.w -1, 0,  1
  Data.w 0,  0,  0
  Data.w 1, 0, 1
  Data.w 1
  Data.w 0
  K3x3_EDGEENHANCE_H:
  Data.s "EDGEENHANCE_H"
  Data.w  0, 0, 0
  Data.w -1, 1, 0
  Data.w  0, 0, 0
  Data.w 1
  Data.w 0
  K3x3_EDGEENHANCE_V:
  Data.s "EDGEENHANCE_V"
  Data.w  0,-1, 0
  Data.w  0, 1, 0
  Data.w  0, 0, 0
  Data.w 1
  Data.w 0
  K3x3_PREWITT_H:
  Data.s "PREWITT_H"
  Data.w 1, 0, -1
  Data.w 1, 0, -1
  Data.w 1, 0, -1
  Data.w 1
  Data.w 0
  K3x3_PREWITT_V:
  Data.s "PREWITT_V"
  Data.w  1,  1,  1
  Data.w  0,  0,  0
  Data.w -1, -1, -1
  Data.w 1
  Data.w 0
  K3x3_SOBEL_H:
  Data.s "SOBEL_H"
  Data.w -1, 0, 1
  Data.w -2, 0, 2
  Data.w -1, 0, 1
  Data.w 1
  Data.w 0
  K3x3_SOBEL_V:
  Data.s "SOBEL_V"
  Data.w  1,  2,  1
  Data.w  0,  0,  0
  Data.w -1, -2, -1
  Data.w 1
  Data.w 0
  K3x3_SOBELFELDMAN_H:
  Data.s "SOBELFELDMAN_H"
  Data.w 3,  0,  -3
  Data.w 10, 0, -10
  Data.w  3, 0,  -3
  Data.w 1
  Data.w 0
  K3x3_SOBELFELDMAN_V:
  Data.s "SOBELFELDMAN_V"
  Data.w  3,  10,  3
  Data.w  0,  0,   0
  Data.w -3, -10, -3
  Data.w 1
  Data.w 0
  K3x3_LAPLACE:
  Data.s "LAPLACE"
  Data.w 0,  1, 0
  Data.w 1, -4, 1
  Data.w 0,  1, 0
  Data.w 1
  Data.w 0 
  K3x3_LAPLACE_INV:
  Data.s "LAPLACE_INV"
  Data.w  0, -1,  0
  Data.w -1,  4, -1
  Data.w  0, -1,  0
  Data.w 1
  Data.w 0
  K3x3_LAPLACE_DIAGONAL:
  Data.s "LAPLACE_DIAGONAL"
  Data.w 1,   2, 1
  Data.w 2, -12, 2
  Data.w 1,   2, 1
  Data.w 1
  Data.w 0
  K3x3_SCHARR_H:
  Data.s "SCHARR_H"
  Data.w  3,  10,  3
  Data.w  0,   0,  0
  Data.w -3, -10, -3
  Data.w 1
  Data.w 0
  K3x3_SCHARR_V:
  Data.s "SCHARR_V"
  Data.w -3, -10, -3
  Data.w  0,   0,  0
  Data.w  3,  10,  3
  Data.w 1
  Data.w 0
  K3x3_EDGE360_KEYA:
  Data.s "EDGE360_KEYA"
  Data.w -1, -1, -1
  Data.w -1,  8, -1
  Data.w -1, -1, -1
  Data.w 1
  Data.w 0 
  K3x3_GRADIENTDETECT_V:
  Data.s "GRADIENTDETECT_V"
  Data.w -1, -1, -1
  Data.w  0,  0,  0
  Data.w  1,  1,  1
  Data.w 1
  Data.w 0
  K3x3_GRADIENTDETECT_H:
  Data.s "GRADIENTDETECT_H"
  Data.w -1, 0, 1
  Data.w -1, 0, 1
  Data.w -1, 0, 1
  Data.w 1
  Data.w 0 
K3x3_EDGE_ENHANCE_MORE:
  Data.s "EDGE_ENHANCE_MORE"
  Data.w 0, -1,  0
  Data.w -1, 5, -1
  Data.w 0, -1,  0
  Data.w 1
  Data.w 0
K3x3_HIGHPASS:
  Data.s "HIGHPASS"
  Data.w -1, -1, -1
  Data.w -1,  8, -1
  Data.w -1, -1, -1
  Data.w 1
  Data.w 128  ; Recentre l’image autour de la valeur moyenne
K3x3_EMBOSS_DIAGONAL:
  Data.s "EMBOSS_DIAGONAL"
  Data.w -2, -1, 0
  Data.w -1,  1, 1
  Data.w  0,  1, 2
  Data.w 1
  Data.w 128
K3x3_SKETCH:
  Data.s "SKETCH"
  Data.w 1,  1,  1
  Data.w 1, -8,  1
  Data.w 1,  1,  1
  Data.w 1
  Data.w 128
K3x3_GLOW_EDGES:
  Data.s "GLOW_EDGES"
  Data.w -1, -1, -1
  Data.w -1,  9, -1
  Data.w -1, -1, -1
  Data.w 1
  Data.w 64
K3x3_SHARPEN_EXTREME:
  Data.s "SHARPEN_EXTREME"
  Data.w  1, -4,  1
  Data.w -4, 13, -4
  Data.w  1, -4,  1
  Data.w 1
  Data.w 0
EndDataSection
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 170
; FirstLine = 133
; Folding = -
; EnableXP
; DPIAware