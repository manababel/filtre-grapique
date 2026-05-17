Procedure convolution7x7_select(opt)
  Select opt
    Case 0 : Restore K7x7_GAUSSIAN_LARGE
    Case 1 : Restore K7x7_SHARPEN_MAX
    Case 2 : Restore K7x7_GAUSSIAN_SOFT   ; Flou doux large
    Case 3 : Restore K7x7_GAUSSIAN_HEAVY  ; Flou très prononcé
    Case 4 : Restore K7x7_SHARPEN         ; Netteté équilibrée
    Case 5 : Restore K7x7_SHARPEN_HARD    ; Netteté forte
    Case 6 : Restore K7x7_MEAN_BLUR       ; Flou artistique (Box)
    Case 7 : Restore K7x7_EMBOSS          ; Relief large
    Case 8 : Restore K7x7_MOTION_H        ; Flou de mouvement horizontal
    Case 9 : Restore K7x7_MOTION_V        ; Flou de mouvement vertical
    Case 10 : Restore K7x7_LAPLACIAN       ; Détection de contours fine
    Case 11 : Restore K7x7_DISCRETE_APPROX ; Filtre passe-bas lissant
  EndSelect
EndProcedure

Procedure convolution7x7_set_Diviseur(opt.f)
  If opt = 0 : opt = 0.01 : EndIf
  FilterCtx\option[0] = opt
EndProcedure

Procedure convolution7x7_set_bias(opt.f)
  FilterCtx\option[1] = opt
EndProcedure

Procedure convolution7x7_set_matrix(opt1.i , opt2.f)
  ; 7x7 = 49 coefficients (0 à 48)
  If opt1 >= 0 And opt1 <= 48
    FilterCtx\convol7[opt1] = opt2
  EndIf
EndProcedure

Procedure convolution7x7_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0], *dst = \addr[1]
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected x, y, i, r, g, b, ky, kx
    
    macro_calul_tread(ht)
    
    ; Marge de sécurité de 3 pixels pour le 7x7
    If thread_start < 3 : thread_start = 3 : EndIf
    If thread_stop > (ht-4) : thread_stop = ht - 4 : EndIf

    For y = thread_start To thread_stop
      For x = 3 To lg - 4
        r = 0 : g = 0 : b = 0
        i = 0 ; Index du coefficient dans convol7[49]
        
        For ky = -3 To 3
          ; On pointe sur le premier pixel de la ligne du voisinage
          Protected *row.Pixel32 = *src + ((y + ky) * lg + (x - 3)) * 4
          
          For kx = 0 To 6
            ; Calcul direct pour éviter les appels de fonctions
            r + ((*row\l >> 16) & $FF) * \convol7[i]
            g + ((*row\l >> 8) & $FF) * \convol7[i]
            b + (*row\l & $FF) * \convol7[i]
            
            *row + 4
            i + 1
          Next
        Next

        r = (r / \option[0]) + \option[1]
        g = (g / \option[0]) + \option[1]
        b = (b / \option[0]) + \option[1]
        
        Clamp_RGB(r, g, b)
        
        Protected *dstPixel.Pixel32 = *dst + (y * lg + x) * 4
        *dstPixel\l = (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
  EndWith
EndProcedure

Procedure convolution7x7Ex(*FilterCtx.FilterParams)
  Restore convolution7x7_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@convolution7x7_MT())
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure convolution7x7(source, cible, mask, opt = -1)
  Protected i, nom.s
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  
  With FilterCtx
    If opt > -1
      convolution7x7_select(opt)
      Read.s nom
      For i = 0 To 49 
        Read.f \convol7[i]
      Next
      Read.f \option[0] ; Diviseur
      Read.f \option[1] ; Bias
    EndIf
    ; Appel de la version 5x5
    convolution7x7Ex(FilterCtx)
  EndWith
EndProcedure

DataSection
  convolution7x7_Data:
  Data.s "Convolution 7x7"
  Data.s ""
  Data.i #FilterType_Convolution
  Data.i 0
  
  Data.s "Diviseur"
  Data.i 1, 1000, 1
  Data.s "Bias"
  Data.i 0, 255, 0
  Data.s "XXX"

  K7x7_GAUSSIAN_LARGE:
  Data.s "Gaussian Blur 7x7"
  Data.f  0,  0,  1,  2,  1,  0,  0
  Data.f  0,  3, 13, 22, 13,  3,  0
  Data.f  1, 13, 59, 97, 59, 13,  1
  Data.f  2, 22, 97,159, 97, 22,  2
  Data.f  1, 13, 59, 97, 59, 13,  1
  Data.f  0,  3, 13, 22, 13,  3,  0
  Data.f  0,  0,  1,  2,  1,  0,  0
  Data.f 1000, 0 ; Diviseur ~1000 pour ce kernel

  K7x7_SHARPEN_MAX:
  Data.s "Sharpen 7x7 Extreme"
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f -1, -1,  8,  8,  8, -1, -1
  Data.f -1, -1,  8, 25,  8, -1, -1
  Data.f -1, -1,  8,  8,  8, -1, -1
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f 25, 0
  
 K7x7_GAUSSIAN_SOFT:
  Data.s "Gaussian Soft 7x7"
  Data.f 0,  0,  1,  2,  1,  0,  0
  Data.f 0,  3, 13, 22, 13,  3,  0
  Data.f 1, 13, 59, 97, 59, 13,  1
  Data.f 2, 22, 97,159, 97, 22,  2
  Data.f 1, 13, 59, 97, 59, 13,  1
  Data.f 0,  3, 13, 22, 13,  3,  0
  Data.f 0,  0,  1,  2,  1,  0,  0
  Data.f 1000, 0

  ;  GAUSSIAN_HEAVY : Très grande dispersion
  K7x7_GAUSSIAN_HEAVY:
  Data.s "Gaussian Heavy 7x7"
  Data.f 1, 1, 2, 2, 2, 1, 1
  Data.f 1, 2, 2, 4, 2, 2, 1
  Data.f 2, 2, 4, 8, 4, 2, 2
  Data.f 2, 4, 8,16, 8, 4, 2
  Data.f 2, 2, 4, 8, 4, 2, 2
  Data.f 1, 2, 2, 4, 2, 2, 1
  Data.f 1, 1, 2, 2, 2, 1, 1
  Data.f 140, 0

  ; SHARPEN : Améliore la clarté sans trop de grain
  K7x7_SHARPEN:
  Data.s "Sharpen 7x7"
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f -1, -1, -1, 50, -1, -1, -1
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f 2, 0

  ;  SHARPEN_HARD : Pour les images floues à l'origine
  K7x7_SHARPEN_HARD:
  Data.s "Sharpen Hard 7x7"
  Data.f  0, -1, -1, -1, -1, -1,  0
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f -1, -1,  1,  2,  1, -1, -1
  Data.f -1, -1,  2, 15,  2, -1, -1
  Data.f -1, -1,  1,  2,  1, -1, -1
  Data.f -1, -1, -1, -1, -1, -1, -1
  Data.f  0, -1, -1, -1, -1, -1,  0
  Data.f 1, 0

  ;  MEAN_BLUR (BOX) : Uniformise les textures
  K7x7_MEAN_BLUR:
  Data.s "Mean Blur 7x7"
  Data.f 1,1,1,1,1,1,1, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1, 1,1,1,1,1,1,1
  Data.f 49, 0

  ;  EMBOSS : Effet de sculpture profonde
  K7x7_EMBOSS:
  Data.s "Emboss 7x7"
  Data.f -1, -1, -1, -1, -1, -1,  0
  Data.f -1, -1, -1, -1, -1,  0,  1
  Data.f -1, -1, -1, -1,  0,  1,  1
  Data.f -1, -1, -1,  0,  1,  1,  1
  Data.f -1, -1,  0,  1,  1,  1,  1
  Data.f -1,  0,  1,  1,  1,  1,  1
  Data.f  0,  1,  1,  1,  1,  1,  1
  Data.f 1, 128

  ;  MOTION_H : Flou de bougé horizontal large
  K7x7_MOTION_H:
  Data.s "Motion Horizontal 7x7"
  Data.f 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 1,1,1,1,1,1,1, 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0,0,0,0,0,0,0
  Data.f 7, 0

  ;  MOTION_V : Flou de bougé vertical large
  K7x7_MOTION_V:
  Data.s "Motion Vertical 7x7"
  Data.f 0,0,0,1,0,0,0, 0,0,0,1,0,0,0, 0,0,0,1,0,0,0, 0,0,0,1,0,0,0, 0,0,0,1,0,0,0, 0,0,0,1,0,0,0, 0,0,0,1,0,0,0
  Data.f 7, 0

  ;  LAPLACIAN : Extraction de contours très fine
  K7x7_LAPLACIAN:
  Data.s "Laplacian 7x7"
  Data.f -1,-1,-1,-1,-1,-1,-1
  Data.f -1,-1,-1,-1,-1,-1,-1
  Data.f -1,-1,-1,-1,-1,-1,-1
  Data.f -1,-1,-1,48,-1,-1,-1
  Data.f -1,-1,-1,-1,-1,-1,-1
  Data.f -1,-1,-1,-1,-1,-1,-1
  Data.f -1,-1,-1,-1,-1,-1,-1
  Data.f 1, 0

  ;  DISCRETE_APPROX : Lissage préservant mieux les masses
  K7x7_DISCRETE_APPROX:
  Data.s "Discrete Approx 7x7"
  Data.f 1, 1, 1, 1, 1, 1, 1
  Data.f 1, 2, 2, 2, 2, 2, 1
  Data.f 1, 2, 3, 3, 3, 2, 1
  Data.f 1, 2, 3, 5, 3, 2, 1
  Data.f 1, 2, 3, 3, 3, 2, 1
  Data.f 1, 2, 2, 2, 2, 2, 1
  Data.f 1, 1, 1, 1, 1, 1, 1
  Data.f 85, 0
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 23
; FirstLine = 168
; Folding = --
; EnableXP
; DPIAware