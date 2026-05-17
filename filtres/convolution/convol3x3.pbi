; Sélection du noyau de convolution 3x3 selon l'option choisie
Procedure convolution3x3_set_Diviseur(opt.f)
  If opt = 0 : opt = 0.01 : EndIf
  FilterCtx\option[0] = opt
EndProcedure

Procedure convolution3x3_set_bias(opt.f)
  FilterCtx\option[1] = opt
EndProcedure

Procedure convolution3x3_set_matrix(opt1.i , opt2.f)
  clamp(opt1 , 0 , 8)
  FilterCtx\convol3[opt1] = opt2
EndProcedure

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

Procedure convolution3x3_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0]
    Protected *dst = \addr[1]
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]

    ; Pointeurs vers pixels source et destination de type Pixel32 (probablement 32 bits)
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    ; Variables temporaires pour les coordonnées et les composantes de couleur
    Protected x, y, i
    Protected r, g, b
    ; Tableaux pour stocker les composantes RGB des 9 pixels voisins
    Protected Dim r3(8)
    Protected Dim g3(8)
    Protected Dim b3(8)
    ; Tableau pour stocker les coefficients de convolution
    Protected Dim conv(8)
    ; Copie des coefficients de convolution depuis les paramètres
    For i = 0 To 8 : conv(i) = \convol3[i] : Next
    ; Calcul de la plage de traitement pour ce thread (portion de l'image en hauteur)
    macro_calul_tread(ht)
    ; Limitation des bornes pour ne pas dépasser les bords (bordure d’un pixel)
    If thread_start < 1 : thread_start = 1 : EndIf
    If thread_stop > (ht-2) : thread_stop = ht - 2 : EndIf
    ; Parcours de la portion d'image attribuée au thread
    For y = thread_start To thread_stop
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

        r = 0 : g = 0 : b = 0
        For i = 0 To 8
          r + r3(i) * conv(i)
          g + g3(i) * conv(i)
          b + b3(i) * conv(i)
        Next
        r = (r / \option[0])  + \option[1]
        g = (g / \option[0])  + \option[1]
        b = (b / \option[0])  + \option[1]
        Clamp_RGB(r, g, b)
        ; Écriture du pixel traité dans l'image destination
        *dstPixel = *dst + (y * lg + x) * 4
        *dstPixel\l = r<<16 +  g<<8  + b
      Next
    Next
  EndWith
EndProcedure


Procedure convolution3x3Ex(*FilterCtx.FilterParams)
  Restore convolution3x3_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@convolution3x3_MT())
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure convolution3x3(source , cible , mask , opt = -1)
  Protected i
  Protected nom.s
  
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    
    If opt > -1 And opt < 50
      convolution3x3_select(opt)
      Read.s nom
      For i = 0 To 8
        Read.f \convol3[i]
      Next
      For i = 0 To 1
        Read.f \option[i]
      Next
    EndIf
    convolution3x3Ex(FilterCtx)
  EndWith
EndProcedure

;-data convolution
DataSection
  
  convolution3x3_Data:
  Data.s "Convolution 3x3"
  Data.s ""
  Data.i #FilterType_Convolution
  Data.i 0
  Data.s "Diviseur"
  Data.i 1, 255, 9
  Data.s "Bias"
  Data.i 0, 255, 0
  Data.s "XXX"
  
  K3x3_GAUSSIANBLUR_2:
  Data.s "GAUSSIANBLUR_2"
  Data.f 1, 2, 1
  Data.f 2, 2, 2
  Data.f 1, 2, 1
  Data.f 14
  Data.f 0
  K3x3_GAUSSIANBLUR_3:
  Data.s "GAUSSIANBLUR_3"
  Data.f 1, 2, 1
  Data.f 2, 3, 2
  Data.f 1, 2, 1
  Data.f 15
  Data.f 0
  K3x3_GAUSSIANBLUR_4: ;Standard 3x3 gaussian model
  Data.s "GAUSSIANBLUR_4"
  Data.f 1, 2, 1
  Data.f 2, 4, 2
  Data.f 1, 2, 1
  Data.f 16
  Data.f 0
  K3x3_GAUSSIANBLUR_6:
  Data.s "GAUSSIANBLUR_6"
  Data.f 1, 2, 1
  Data.f 2, 6, 2
  Data.f 1, 2, 1
  Data.f 18
  Data.f 0
  K3x3_GAUSSIANBLUR_8:
  Data.s "GAUSSIANBLUR_8"
  Data.f 1, 2, 1
  Data.f 2, 8, 2
  Data.f 1, 2, 1
  Data.f 20
  Data.f 0
  K3x3_GAUSSIANBLUR_10:
  Data.s "GAUSSIANBLUR_10"
  Data.f 1, 2,  1
  Data.f 2, 10, 2
  Data.f 1, 2,  1
  Data.f 22
  Data.f 0   
  K3x3_MOTIONBLUR_RIGHT:
  Data.s "MOTIONBLUR_RIGHT"
  Data.f 0, 0, 1
  Data.f 0, 0, 0
  Data.f 1, 0, 0
  Data.f 2
  Data.f 0
  K3x3_MOTIONBLUR_LEFT:
  Data.s "MOTIONBLUR_LEFT"
  Data.f 1, 0, 0
  Data.f 0, 0, 0
  Data.f 0, 0, 1
  Data.f 2
  Data.f 0
  K3x3_MOTIONBLUR:
  Data.s "MOTIONBLUR"
  Data.f 1, 0, 0
  Data.f 0, 1, 0
  Data.f 0, 0, 1
  Data.f 3
  Data.f 0
  K3x3_SMOOTH_1:
  Data.s "SMOOTH_1"
  Data.f 1,   1,    1
  Data.f 1,   5,    1
  Data.f 1,   1,    1
  Data.f 13
  Data.f 0
  K3x3_SMOOTH_2:
  Data.s "SMOOTH_2"
  Data.f 1,   1,    1
  Data.f 1,   4,    1
  Data.f 1,   1,    1
  Data.f 12
  Data.f 0 
  K3x3_SMOOTH_3:
  Data.s "SMOOTH_3"
  Data.f 1,   1,    1
  Data.f 1,   3,    1
  Data.f 1,   1,    1
  Data.f 11
  Data.f 0 
  K3x3_SMOOTH_4:
  Data.s "SMOOTH_4"
  Data.f 1,   1,    1
  Data.f 1,   2,    1
  Data.f 1,   1,    1
  Data.f 10
  Data.f 0
  K3x3_MEANSMOOTH: ;aka Average/Mean/Box Blur
  Data.s "MEANSMOOTH"
  Data.f 1,   1,    1
  Data.f 1,   1,    1
  Data.f 1,   1,    1
  Data.f 9
  Data.f 0
  ;### Sharpen
  K3x3_SHARPEN_15:
  Data.s "SHARPEN_15"
  Data.f  0,   -1,   0
  Data.f -1,  5,    -1
  Data.f  0,   -1,   0
  Data.f 1
  Data.f 0
  K3x3_SHARPEN_20:
  Data.s "SHARPEN_20"
  Data.f  0,   1,   0
  Data.f 1,   -3   ,1
  Data.f  0,   1,   0
  Data.f 1
  Data.f 0
  K3x3_SHARPEN_30:
  Data.s "SHARPEN_30"
  Data.f  -1,  -1,   -1
  Data.f -1,   9,  -1
  Data.f  -1,  -1,   -1
  Data.f 1
  Data.f 0 
  K3x3_SHARPEN_50:
  Data.s "SHARPEN_50"
  Data.f  1,  -2,   1
  Data.f -2,   5,  -2
  Data.f  1,  -2,   1
  Data.f 1
  Data.f 0
  K3x3_SHARPEN_MEANREMOVAL:      ;aka Mean Removal
  Data.s "SHARPEN_MEANREMOVAL"
  Data.f -1,  -1, -1
  Data.f -1,   9, -1
  Data.f -1,  -1, -1
  Data.f 1
  Data.f 0 
  ;### Emboss/raise/extrude
  K3x3_EXTRUDE:
  Data.s "EXTRUDE"
  Data.f 1,   1,    1
  Data.f 1,   -7,    1
  Data.f 1,   1,    1
  Data.f 1
  Data.f 0   
  K3x3_EMBOSS_v1:
  Data.s "EMBOSS_v1"
  Data.f -1,  -1,  0
  Data.f -1,   0,  1
  Data.f  0,   1,  1
  Data.f 9
  Data.f 128
  K3x3_EMBOSS_v2:
  Data.s "EMBOSS_v2"
  Data.f  0, 0, 0
  Data.f -1, 0, 1
  Data.f  0, 0, 0
  Data.f 9
  Data.f 128
  K3x3_EMBOSS_v3:
  Data.s "EMBOSS_v3"
  Data.f -1, -1,  0
  Data.f -1,  0,  1
  Data.f  0,  1,  1
  Data.f 9
  Data.f 128
  K3x3_EMBOSS_v4:
  Data.s "EMBOSS_v4"
  Data.f -2, -1,  0
  Data.f -1,  1,  1
  Data.f 0,  1,  2
  Data.f 9
  Data.f 128   
  K3x3_RAISED:
  Data.s "RAISED"
  Data.f 0, 0, -2
  Data.f 0, 2, 0
  Data.f 1, 0, 0
  Data.f 1
  Data.f 0
  ;### Edge detect/enhance
  K3x3_EDGEDETECT_HV:  
  Data.s "EDGEDETECT_HV"
  Data.f 0,  1,  0
  Data.f 1, -4,  1
  Data.f 0,  1,  0
  Data.f 1
  Data.f 0
  K3x3_EDGEDETECT_H:
  Data.s "EDGEDETECT_H"
  Data.f  0,  0,  0
  Data.f -1,  2, -1
  Data.f 0,  0,  0
  Data.f 1
  Data.f 0
  K3x3_EDGEDETECT_V:
  Data.s "EDGEDETECT_V"
  Data.f 0, -1, 0
  Data.f 0,  2, 0
  Data.f 0, -1, 0
  Data.f 1
  Data.f 0
  K3x3_EDGEDETECT_DIFFERENTIAL:
  Data.s "EDGEDETECT_DIFFERENTIAL"
  Data.f -1, 0,  1
  Data.f 0,  0,  0
  Data.f 1, 0, 1
  Data.f 1
  Data.f 0
  K3x3_EDGEENHANCE_H:
  Data.s "EDGEENHANCE_H"
  Data.f  0, 0, 0
  Data.f -1, 1, 0
  Data.f  0, 0, 0
  Data.f 1
  Data.f 0
  K3x3_EDGEENHANCE_V:
  Data.s "EDGEENHANCE_V"
  Data.f  0,-1, 0
  Data.f  0, 1, 0
  Data.f  0, 0, 0
  Data.f 1
  Data.f 0
  K3x3_PREWITT_H:
  Data.s "PREWITT_H"
  Data.f 1, 0, -1
  Data.f 1, 0, -1
  Data.f 1, 0, -1
  Data.f 1
  Data.f 0
  K3x3_PREWITT_V:
  Data.s "PREWITT_V"
  Data.f  1,  1,  1
  Data.f  0,  0,  0
  Data.f -1, -1, -1
  Data.f 1
  Data.f 0
  K3x3_SOBEL_H:
  Data.s "SOBEL_H"
  Data.f -1, 0, 1
  Data.f -2, 0, 2
  Data.f -1, 0, 1
  Data.f 1
  Data.f 0
  K3x3_SOBEL_V:
  Data.s "SOBEL_V"
  Data.f  1,  2,  1
  Data.f  0,  0,  0
  Data.f -1, -2, -1
  Data.f 1
  Data.f 0
  K3x3_SOBELFELDMAN_H:
  Data.s "SOBELFELDMAN_H"
  Data.f 3,  0,  -3
  Data.f 10, 0, -10
  Data.f  3, 0,  -3
  Data.f 1
  Data.f 0
  K3x3_SOBELFELDMAN_V:
  Data.s "SOBELFELDMAN_V"
  Data.f  3,  10,  3
  Data.f  0,  0,   0
  Data.f -3, -10, -3
  Data.f 1
  Data.f 0
  K3x3_LAPLACE:
  Data.s "LAPLACE"
  Data.f 0,  1, 0
  Data.f 1, -4, 1
  Data.f 0,  1, 0
  Data.f 1
  Data.f 0 
  K3x3_LAPLACE_INV:
  Data.s "LAPLACE_INV"
  Data.f  0, -1,  0
  Data.f -1,  4, -1
  Data.f  0, -1,  0
  Data.f 1
  Data.f 0
  K3x3_LAPLACE_DIAGONAL:
  Data.s "LAPLACE_DIAGONAL"
  Data.f 1,   2, 1
  Data.f 2, -12, 2
  Data.f 1,   2, 1
  Data.f 1
  Data.f 0
  K3x3_SCHARR_H:
  Data.s "SCHARR_H"
  Data.f  3,  10,  3
  Data.f  0,   0,  0
  Data.f -3, -10, -3
  Data.f 1
  Data.f 0
  K3x3_SCHARR_V:
  Data.s "SCHARR_V"
  Data.f -3, -10, -3
  Data.f  0,   0,  0
  Data.f  3,  10,  3
  Data.f 1
  Data.f 0
  K3x3_EDGE360_KEYA:
  Data.s "EDGE360_KEYA"
  Data.f -1, -1, -1
  Data.f -1,  8, -1
  Data.f -1, -1, -1
  Data.f 1
  Data.f 0 
  K3x3_GRADIENTDETECT_V:
  Data.s "GRADIENTDETECT_V"
  Data.f -1, -1, -1
  Data.f  0,  0,  0
  Data.f  1,  1,  1
  Data.f 1
  Data.f 0
  K3x3_GRADIENTDETECT_H:
  Data.s "GRADIENTDETECT_H"
  Data.f -1, 0, 1
  Data.f -1, 0, 1
  Data.f -1, 0, 1
  Data.f 1
  Data.f 0 
K3x3_EDGE_ENHANCE_MORE:
  Data.s "EDGE_ENHANCE_MORE"
  Data.f 0, -1,  0
  Data.f -1, 5, -1
  Data.f 0, -1,  0
  Data.f 1
  Data.f 0
K3x3_HIGHPASS:
  Data.s "HIGHPASS"
  Data.f -1, -1, -1
  Data.f -1,  8, -1
  Data.f -1, -1, -1
  Data.f 1
  Data.f 128  ; Recentre l’image autour de la valeur moyenne
K3x3_EMBOSS_DIAGONAL:
  Data.s "EMBOSS_DIAGONAL"
  Data.f -2, -1, 0
  Data.f -1,  1, 1
  Data.f  0,  1, 2
  Data.f 1
  Data.f 128
K3x3_SKETCH:
  Data.s "SKETCH"
  Data.f 1,  1,  1
  Data.f 1, -8,  1
  Data.f 1,  1,  1
  Data.f 1
  Data.f 128
K3x3_GLOW_EDGES:
  Data.s "GLOW_EDGES"
  Data.f -1, -1, -1
  Data.f -1,  9, -1
  Data.f -1, -1, -1
  Data.f 1
  Data.f 64
K3x3_SHARPEN_EXTREME:
  Data.s "SHARPEN_EXTREME"
  Data.f  1, -4,  1
  Data.f -4, 13, -4
  Data.f  1, -4,  1
  Data.f 1
  Data.f 0
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 26
; FirstLine = 90
; Folding = --
; EnableXP
; DPIAware